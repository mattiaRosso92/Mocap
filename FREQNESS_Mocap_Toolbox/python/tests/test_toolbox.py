"""Public contracts, invariants and edge cases independent of MATLAB availability."""
from dataclasses import replace
import numpy as np
import pytest
from numpy.testing import assert_allclose, assert_array_equal
from scipy.io import savemat
from freqness_mocap import *


@pytest.fixture
def data():
    return np.random.default_rng(23).normal(size=(6,240,2))


@pytest.fixture
def freq(data):
    return FREQNESS_NetworkEstimation_Mocap(data,[1,2,4],50,ncomps=2,fwidth=.8)


@pytest.mark.parametrize('method',['ged','pca'])
@pytest.mark.parametrize('kinematics',['position','velocity'])
@pytest.mark.parametrize('nsubs',[1,2,3])
def test_core_shape_and_reconstruction(data,method,kinematics,nsubs):
    values = np.repeat(data[:,:,:1],nsubs,axis=2)
    result = FREQNESS_NetworkEstimation_Mocap(values,[1,2],50,ncomps=3,method=method,kinematics=kinematics)
    ntime = 239 if kinematics=='velocity' else 240
    assert result.evals.shape==(6,2,nsubs)
    assert result.ts.shape==(3,ntime,2,nsubs)
    assert result.evecs.shape==(6,3,2,nsubs)
    assert_allclose(result.evals.sum(axis=0),100)
    broad = np.diff(values,axis=1)*50 if kinematics=='velocity' else values
    assert_allclose(result.ts[:,:,0,0],result.evecs[:,:,0,0].T@broad[:,:,0])
    assert result.method==method and result.kinematics==kinematics


@pytest.mark.parametrize('option,value',[('method','old'),('kinematics','acceleration'),('ncomps',7),('ncomps',1.2),
    ('regularisation',1),('filter','invalid'),('duration',.013),('duration',10),('bad_segments',[0]),
    ('bad_segments',[241]),('interpolate_gaps',1),('fwidth',[-1,.1,.2])])
def test_core_rejects_invalid(data,option,value):
    options = dict(ncomps=2); options[option]=value
    with pytest.raises((ValueError,TypeError)):
        FREQNESS_NetworkEstimation_Mocap(data,[1,2,3],50,**options)


@pytest.mark.parametrize('width',[.2,[.2,.3,.4],[[.2,.3],[.3,.4],[.4,.5]]])
def test_width_shapes(data,width):
    result = FREQNESS_NetworkEstimation_Mocap(data,[[1,1.1],[2,2.2],[4,4.4]],50,ncomps=2,fwidth=width)
    assert result.fwhm.shape==(3,2)


def test_gaps_and_boundary(data):
    values = data.copy(); values[0,40:42,0]=np.nan
    filled,bad,info = FREQNESS_InterpolateGaps_Mocap(values,50)
    assert_array_equal(bad,[41,42])
    assert_allclose(filled[~np.isnan(values)],values[~np.isnan(values)])
    assert_array_equal(info.bad_segments_by_participant[1],[])
    velocity = FREQNESS_NetworkEstimation_Mocap(values,[1],50,ncomps=1,kinematics='velocity')
    assert_array_equal(velocity.bad_segments,[40,41,42])
    values[0,0,0]=np.nan
    with pytest.raises(ValueError): FREQNESS_InterpolateGaps_Mocap(values,50)
    filled,_,_ = FREQNESS_InterpolateGaps_Mocap(values,50,boundary_method='nearest')
    assert filled[0,0,0]==values[0,1,0]


def test_entropy_edge_cases():
    H2,ED = FREQNESS_EffectDim_Mocap(Struct(evals=np.ones((4,3,2))),figure=False)
    assert_allclose(ED,4); assert_allclose(H2,np.log(4))
    H2,ED = FREQNESS_EffectDim_Mocap(Struct(evals=np.zeros((4,3,2))),figure=False)
    assert np.isinf(H2).all(); assert_allclose(ED,0)
    H2,ED = FREQNESS_EffectDim_Mocap(Struct(evals=[2]),figure=False)
    assert H2==0 and ED==1


def test_space_sign_and_fisher(freq):
    raw = FREQNESS_SpaceCoord_Mocap(freq,[2,2])
    changed = replace(freq,pats=freq.pats*np.array([1,-1]))
    assert_allclose(FREQNESS_SpaceCoord_Mocap(changed,[2,2]),raw)
    assert_allclose(FREQNESS_SpaceCoord_Mocap(freq,[2,2],Fisher=True),np.arctanh(raw))


def test_phase_selection_gaps_and_signs(freq):
    result = FREQNESS_TimeCoord_Mocap(freq,[1,2],component=[1,2],downsample=3,bad_segments=[1,4],store_matrices=True)[0]
    assert_array_equal(result.SelectedFrequencies,[1,2])
    assert_array_equal(result.SelectedComponents,[1,2])
    assert not result.ValidSampleMask[:2].any()
    assert np.isnan(result.PhaseSpace[:2]).all()
    assert not result.RecurrencePlot[:2].any()
    assert result.EligiblePairCount==result.ValidSampleCount**2
    other = FREQNESS_TimeCoord_Mocap(replace(freq,ts=-freq.ts),[1,2],component=[1,2],downsample=3,bad_segments=[1,4],store_matrices=True)[0]
    assert_array_equal(result.RecurrencePlot,other.RecurrencePlot)


@pytest.mark.parametrize('method',['phase_space','jrqa'])
def test_normalization_is_optional(freq,method):
    kwargs = dict(method=method)
    if method=='jrqa': kwargs.update(parameters=Struct(m=2,tau=2,ps=1))
    raw = FREQNESS_TimeCoord_Mocap(freq,[2,2],**kwargs)[0]
    norm = FREQNESS_TimeCoord_Mocap(freq,[2,2],standardize=True,store_matrices=True,**kwargs)[0]
    if method=='phase_space':
        assert raw.Standardized is False
        assert_allclose(norm.PhaseSpace.std(axis=0,ddof=1),1)
    else:
        assert raw.Preprocessing.Standardized is False
        assert norm.Preprocessing.Standardized is True


def test_method_guards(freq):
    with pytest.raises(ValueError): FREQNESS_TimeCoord_Mocap(freq,1,parameters=Struct(m=2,tau=2))
    with pytest.raises(ValueError): FREQNESS_TimeCoord_Mocap(freq,[1,1],method='jrqa')
    with pytest.raises(TypeError): FREQNESS_TimeCoord_Mocap(freq,[1,1],implementation='legacy')
    with pytest.raises(ValueError): FREQNESS_TimeCoord_Mocap(replace(freq,ts=np.zeros((1,10001,1,2)),frex=[1]),1)
    with pytest.raises(ValueError): FREQNESS_TimeCoord_Mocap(replace(freq,bad_segments=[5]),[1,1],method='jrqa',parameters=Struct(m=2,tau=2,ps=1))


def test_tuning_and_surrogates(freq):
    tuned = FREQNESS_JRQAParameters_Mocap(freq,[2,2],50,maximum_lag=8,maximum_dimension=3)
    assert tuned.m.shape==tuned.tau.shape==tuned.ps.shape==(2,1)
    state = np.random.get_state()
    _,first = FREQNESS_JRQASurrogates_Mocap(freq,Struct(m=2,tau=2,ps=1),[2,2],n_surrogates=5)
    _,second = FREQNESS_JRQASurrogates_Mocap(freq,Struct(m=2,tau=2,ps=1),[2,2],n_surrogates=5)
    assert_array_equal(first[0].Shifts,second[0].Shifts)
    assert_array_equal(np.random.get_state()[1],state[1])


def test_startup_v7_and_v73(tmp_path,data):
    import h5py
    directory = tmp_path/'FREQNESS_Data'
    (directory/'b_group').mkdir(parents=True)
    (directory/'A_pair').mkdir()
    savemat(directory/'A_pair'/'right.mat',{'data':data[:,:,1]})
    savemat(directory/'A_pair'/'left.mat',{'data':data[:,:,0]})
    # True MATLAB v7.3 header: scipy delegates HDF5 only when version==2.
    path = directory/'b_group'/'group.mat'
    with h5py.File(path,'w',userblock_size=512) as handle:
        handle.create_dataset('data',data=data.transpose())
    with path.open('r+b') as handle:
        handle.write(b'MATLAB 7.3 MAT-file'.ljust(124,b' ')+b'\x00\x02IM')
    loaded,labels,root = FREQNESS_Startup_Mocap(tmp_path)
    assert labels==['A_pair','b_group']
    for result in loaded: assert_array_equal(result,data)


def test_main_pipeline(data):
    cfg = FREQNESSPipelineConfig(frex=[1,2,4],srate=50,network={'ncomps':2},effect_dim={'figure':False},
        run_phase_rqa=True,phase_rqa={'metric_levels':[1],'downsample':4},target_frex=[2,2],run_space_coord=True,
        space_coord={'metric_levels':[1]},run_landscape_similarity=True)
    result = FREQNESS_MainPipeline_Mocap([data],cfg,['test'])[0]
    assert result.Label=='test' and result.FREQ.method=='ged'
    assert result.ED.shape==(3,2) and len(result.PhaseSpaceRQA)==1


@pytest.mark.parametrize('nsubs',[1,2,3])
def test_visualizer(data,nsubs):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    values = np.repeat(data[:,:,:1],nsubs,axis=2)
    freq = FREQNESS_NetworkEstimation_Mocap(values,[1,2,4],50,ncomps=2)
    patterns = Struct(frex=2,labels=['A','B'],markerData=values,comp=1,srate=50,start=0,animate=False)
    figs = FREQNESS_Visualizer_Mocap(freq,Struct(frex=[1,2,4],ncomps=2),patterns,plot_all=True)
    assert len(figs.landscape)==(1 if nsubs==1 else nsubs+1)
    assert len(figs.patterns)==len(figs.pattern_matrix)==1
    FREQNESS_EffectDim_Mocap(freq,plot_all=True)
    plt.close('all')


def test_animation_guards_and_frame(freq,data):
    import matplotlib.pyplot as plt
    patterns = Struct(frex=2,labels=['A','B'],markerData=data,comp=1,srate=50,start=0,
                      animate=True,animation_duration=.5)
    figs = FREQNESS_Visualizer_Mocap(freq,None,patterns)
    animation = figs.animation[0]._freqness_animation
    animation._func(1); animation._draw_was_started=True
    with pytest.raises(ValueError): FREQNESS_Visualizer_Mocap(replace(freq,kinematics='velocity'),None,patterns)
    phase = FREQNESS_TimeCoord_Mocap(freq,2,downsample=4,animate=True,figure=True)
    phase.figures.animation[0]._freqness_animation._func(1)
    phase.figures.animation[0]._freqness_animation._draw_was_started=True
    plt.close('all')


@pytest.mark.parametrize('nsubs',[2,3])
def test_phase_lines_preserve_gaps(nsubs):
    from matplotlib.collections import LineCollection, PathCollection
    from mpl_toolkits.mplot3d.art3d import Line3DCollection
    import matplotlib.pyplot as plt
    values = np.random.default_rng(4).normal(size=(1,20,1,nsubs))
    output = FREQNESS_TimeCoord_Mocap(Struct(ts=values,frex=[1]),1,bad_segments=[5],figure=True,animate=True)
    ax = output.figures.phase_space[0].axes[0]
    assert not any(isinstance(x,PathCollection) for x in ax.collections)
    artist = ax.collections[0]
    assert isinstance(artist,(LineCollection,Line3DCollection))
    segments = artist._segments3d if nsubs==3 else artist.get_segments()
    assert len(segments)==17  # 19 adjacent pairs minus both touching sample 5.
    animation = output.figures.animation[0]._freqness_animation
    animation._func(8); animation._draw_was_started=True
    plt.close('all')
