"""Run against generate_matlab_reference.m output, never an unverified mock.

Set FREQNESS_MATLAB_REFERENCE to the generated .mat path. Without MATLAB
reference data these tests explicitly SKIP, not silently pass.
"""
import os
from pathlib import Path
import numpy as np
import pytest
from scipy.io import loadmat
from numpy.testing import assert_allclose, assert_array_equal
from freqness_mocap import *


@pytest.fixture(scope="module")
def ref():
    path = os.environ.get("FREQNESS_MATLAB_REFERENCE")
    if not path or not Path(path).is_file():
        pytest.skip("Generate MATLAB reference and set FREQNESS_MATLAB_REFERENCE")
    return loadmat(path, simplify_cells=True)


def test_filter(ref):
    actual = filterFGx(ref["data"][:, :, 0], 50, 1.2, .3)
    for value, name in zip(actual, ("filtered", "empirical", "kernel")):
        assert_allclose(value, ref[name], rtol=1e-10, atol=1e-10)
    assert_allclose(FREQNESS_ComputeFilterWidths_Mocap(ref["frex"]), ref["physical"], rtol=1e-13)
    assert_allclose(FREQNESS_ComputeLegacyFilterWidths_Mocap(ref["frex"]), ref["legacy"], rtol=1e-13)


@pytest.mark.parametrize("name,options", [("ged", {}), ("pca", {"method":"pca"}),
    ("velocity", {"kinematics":"velocity"}), ("gap", {"kinematics":"velocity", "maximum_reconstructed_gap":.12,"bad_segments":[211,212]})])
def test_network(ref, name, options):
    actual = FREQNESS_NetworkEstimation_Mocap(ref["gap_data"] if name == "gap" else ref["data"], ref["frex"], 50, ncomps=6 if name=="pca" else 3, **options)
    expected = ref[name]
    for key in ("evals", "frex", "fwhm", "sample_offset", "input_n_samples", "bad_segments"):
        assert_allclose(np.asarray(getattr(actual, key)).reshape(-1), np.asarray(expected[key]).reshape(-1), rtol=2e-7, atol=2e-8, err_msg=key)
    # Align ONE arbitrary sign per component, reused for its vector and scores.
    signs = np.sign(np.sum(actual.evecs * expected["evecs"], axis=0))
    for s in range(2):
        for f in range(len(ref["frex"])):
            eigenvalues = expected["evals"][:,f,s]
            clusters = np.split(np.arange(len(eigenvalues)),np.flatnonzero(abs(np.diff(eigenvalues))>1e-9*max(eigenvalues))+1)
            for cluster in clusters:
                retained = cluster[cluster < actual.evecs.shape[1]]
                if not retained.size:
                    continue
                if len(cluster)>1 and len(retained)==len(cluster):
                    # Repeated PCA eigenvalues determine a subspace, not a basis.
                    a = actual.evecs[:,retained,f,s]; b = expected["evecs"][:,retained,f,s]
                    assert_allclose(a@a.T,b@b.T,atol=2e-7)
                    assert_allclose(a@actual.ts[retained,:,f,s],b@expected["ts"][retained,:,f,s],atol=2e-7)
                else:
                    assert_allclose(actual.evecs[:,retained,f,s]*signs[retained,f,s],expected["evecs"][:,retained,f,s],rtol=2e-7,atol=2e-8)
                    assert_allclose(actual.ts[retained,:,f,s]*signs[retained,f,s,None],expected["ts"][retained,:,f,s],rtol=2e-7,atol=2e-8)
                    assert_allclose(actual.pats[:,retained,f,s],expected["pats"][:,retained,f,s],rtol=2e-7,atol=2e-8)
    assert_allclose(actual.evals.sum(axis=0), 100, atol=1e-12)


def test_downstream(ref):
    H2, ED = FREQNESS_EffectDim_Mocap(ref["ged"], figure=False)
    assert_allclose(H2, ref["H2"], atol=1e-13)
    assert_allclose(ED, ref["ED"], atol=1e-13)
    for fisher, name in ((False,"space"),(True,"fisher")):
        assert_allclose(FREQNESS_SpaceCoord_Mocap(ref["ged"], [1,1.2], metric_levels=[.5,1,2], Fisher=fisher), ref[name], atol=1e-12)
    aligned = dict(ref["ged"], frex=ref["frex"][:,0])
    result = FREQNESS_LandscapeSimilarity(aligned)
    for value, name in zip(result, ("landscape_comp","landscape_entropy","selected_frex")):
        assert_allclose(value, ref[name], atol=1e-12)
    result = FREQNESS_MetricProminence_Mocap(ref["dense"], 1, metric_levels=[.25,.5,1,2])
    for name in vars(result):
        assert_allclose(getattr(result, name), ref["meter"][name], atol=1e-12)


def test_preprocess(ref):
    result, metadata = FREQNESS_PreprocessTimeCoord_Mocap(ref["data"][:2,:,0].T,50,
        target_srate=10,lowpass_cutoff=4,duration=[.1,.9],standardize=True)
    assert_allclose(result, ref["processed"], atol=2e-10)
    assert_array_equal(metadata.SelectedOriginalIndices, ref["preprocessing"]["SelectedOriginalIndices"])


@pytest.mark.parametrize("name,options", [("phase", dict(downsample=5,metric_levels=[.5,1])),
    ("phase_gap", dict(downsample=5,bad_segments=[11,16,21],standardize=True,threshold_method="fixed_rr",threshold=.2,theiler_window=2)),
    ("joint", dict(method="jrqa",srate=50,target_srate=10,lowpass_cutoff=4,standardize=True,threshold_method="adaptive_max_radius")),
    ("joint_fixed", dict(method="jrqa",srate=50,target_srate=10,lowpass_cutoff=4,threshold_method="fixed_rr",threshold=.2,theiler_window=2))])
def test_coordination(ref, name, options):
    if options.get("method") == "jrqa":
        options = dict(options, parameters=ref["parameters"])
    actual = FREQNESS_TimeCoord_Mocap(ref["ged"], [1,1.2], store_matrices=True, **options)
    expected = ref[name] if isinstance(ref[name], list) else [ref[name]]
    for value, target in zip(actual, expected):
        for key in ("RR","DET","L","ENTR","LAM","TT","Vmax"):
            assert_allclose(getattr(value,key), target[key], atol=1e-12, equal_nan=True, err_msg=key)
        for key in ("RecurrencePlot","JointRecurrencePlot","EligiblePairMask"):
            if key in target:
                assert_array_equal(getattr(value,key), target[key])


def test_rqa(ref):
    for rp, expected in zip(ref["plots"], ref["rqa"]):
        actual = FREQNESS_RQA_Mocap(rp)
        for key in vars(actual):
            assert_allclose(getattr(actual,key), expected[key], atol=1e-12, equal_nan=True, err_msg=key)


def test_tuning(ref):
    actual = FREQNESS_JRQAParameters_Mocap(ref["ged"],[1,1.2],50,target_srate=10,
        lowpass_cutoff=4,maximum_lag=12,maximum_dimension=4)
    for key in ("m","tau","ps","TauFallback","DimensionFallback"):
        assert_allclose(np.asarray(getattr(actual,key)).ravel(), np.asarray(ref["tuned"][key]).ravel(), atol=1e-10, err_msg=key)


def test_surrogates(ref):
    _, actual = FREQNESS_JRQASurrogates_Mocap(ref["ged"],ref["parameters"],[1,1.2],srate=50,
        target_srate=10,lowpass_cutoff=4,threshold_method="adaptive_max_radius",n_surrogates=7,random_seed=1)
    for key in ("Shifts","RR","DET","PValueRR","PValueDET","ZScoreRR","ZScoreDET"):
        assert_allclose(getattr(actual[0],key),ref["surrogates"][key],atol=1e-12, equal_nan=True, err_msg=key)
