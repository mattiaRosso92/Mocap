"""Bodily landscapes, spatial patterns and animations, matching MATLAB quantities.

Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti. Matplotlib is optional.
"""
import numpy as np
from ._utils import Struct, field, shaped, array, empty, logical, scalar, positive_vector, nearest
from ._plotting import plot_landscape, style
from .FREQNESS_InterpolateGaps_Mocap import FREQNESS_InterpolateGaps_Mocap


def _bones(nmarkers):
    return np.array([[1,2],[1,4],[2,3],[3,4],[5,6],[5,7],[6,7],[6,8],[8,9],[9,10],
        [7,11],[11,12],[12,13],[14,15],[14,16],[15,16],[15,17],[17,18],[18,19],
        [16,20],[20,21],[21,22]],int)-1 if nmarkers == 22 else np.empty((0,2),int)


def _skeleton_axes(ax, data):
    xy, z = data.reshape(-1,3,*data.shape[1:])[:,:2].ravel(), data[2::3].ravel()
    xy_pad, z_pad = max(np.ptp(xy)*.04,np.finfo(float).eps), max(np.ptp(z)*.04,np.finfo(float).eps)
    ax.set(xlim=(xy.min()-xy_pad,xy.max()+xy_pad),ylim=(xy.min()-xy_pad,xy.max()+xy_pad),
           zlim=(z.min()-z_pad,z.max()+z_pad),xlabel="X",ylabel="Y",zlabel="Z")
    ax.set_box_aspect((np.ptp(xy)+2*xy_pad,np.ptp(xy)+2*xy_pad,np.ptp(z)+2*z_pad))
    # MATLAB view azimuth=60 is measured from -Y, Matplotlib from +X.
    ax.view_init(elev=30,azim=-30)


def _draw_bones(ax, xyz, bones):
    return [ax.plot(*xyz[pair].T,color="k",linewidth=2.6)[0] for pair in bones]


def FREQNESS_Visualizer_Mocap(FREQ, Landscape=None, Patterns=None, *, plot_all=False):
    """Return named lists of figure handles: landscape, pattern_matrix, patterns, animation.

    Landscape requires frex/ncomps; optional sem/xlabel/title. Patterns requires
    frex/labels/markerData/comp/srate/start. Optional bones (one-based), plot_bones,
    plot_matrix, frequency_unit, animate and animation_duration mirror MATLAB.
    Set animate explicitly for automation; omission retains MATLAB's prompt.
    Shared plotting grids only: align participant-specific grids explicitly.
    """
    import matplotlib.pyplot as plt
    from matplotlib.colors import ListedColormap, Normalize
    from matplotlib.cm import ScalarMappable
    logical(plot_all,"plot_all")
    values = shaped(field(FREQ,"evals"),"FREQ.evals",3)
    frex = positive_vector(field(FREQ,"frex"),"FREQ.frex")
    if len(frex) != values.shape[1]:
        raise ValueError("Visualizer requires one shared plotting frequency vector")
    figures = Struct(landscape=[],pattern_matrix=[],patterns=[],animation=[])
    if not empty(Landscape):
        requested = np.sort(positive_vector(field(Landscape,"frex"),"Landscape.frex"))
        ncomps = scalar(field(Landscape,"ncomps"),"Landscape.ncomps",integer=True)
        if ncomps > values.shape[0]:
            raise ValueError("Landscape.ncomps exceeds the eigenspectrum")
        idx = nearest(frex,requested,warn=True)
        xlabel = field(Landscape,"xlabel","Frequency (Hz)")
        title = field(Landscape,"title","Bodily network landscape")
        method = str(field(FREQ,"method","FREQ")).upper()
        external_sem = field(Landscape,"sem")
        if not empty(external_sem):
            external_sem = array(external_sem,"Landscape.sem",ndim=2)
            if external_sem.ndim != 2 or external_sem.shape[0] < ncomps or external_sem.shape[1] != len(frex) or np.any(external_sem < 0):
                raise ValueError("Landscape.sem must be non-negative components x frequencies")
        else:
            external_sem = None
        nsubs = values.shape[2]
        if plot_all or nsubs == 1:
            for subi in range(nsubs):
                sem = external_sem[:ncomps,idx] if nsubs == 1 and external_sem is not None else None
                figures.landscape.append(plot_landscape(frex[idx],values[:ncomps,idx,subi],sem,xlabel,
                    title if nsubs == 1 else f"{title} - Participant #{subi+1}",method))
        if nsubs > 1:
            selected = values[:ncomps,idx,:]
            figures.landscape.append(plot_landscape(frex[idx],selected.mean(axis=2),selected.std(axis=2,ddof=1)/np.sqrt(nsubs),xlabel,title+" - Grand average",method))
    if empty(Patterns):
        return figures
    pats = shaped(field(FREQ,"pats"),"FREQ.pats",4,finite=False)
    marker = shaped(field(Patterns,"markerData"),"Patterns.markerData",3,finite=False)
    if np.isinf(pats).any() or np.isinf(marker).any():
        raise ValueError("Patterns and marker data cannot contain Inf")
    srate = scalar(field(Patterns,"srate"),"Patterns.srate")
    ts = field(FREQ,"ts")
    if not empty(ts):
        ts = shaped(ts,"FREQ.ts",4,finite=False)
        marker = marker[:,:min(marker.shape[1],ts.shape[1]),:]
    if np.isnan(marker).any():
        info = field(FREQ,"gap_info")
        marker,_,_ = FREQNESS_InterpolateGaps_Mocap(marker,srate,
            maximum_interpolated_gap=field(info,"maximum_interpolated_gap_seconds",.05),
            maximum_reconstructed_gap=field(info,"maximum_reconstructed_gap_seconds"))
    ncoords,_,nsubs = marker.shape
    nmarkers = ncoords//3
    labels = np.asarray(field(Patterns,"labels")).reshape(-1)
    if ncoords%3 or pats.shape[0] != ncoords or pats.shape[2] != len(frex) or pats.shape[3] != nsubs or len(labels) != nmarkers:
        raise ValueError("Patterns require matching XYZ coordinates, labels, frequencies and participants")
    comp = scalar(field(Patterns,"comp"),"Patterns.comp",integer=True)
    if comp > pats.shape[1]:
        raise ValueError("Patterns.comp exceeds retained components")
    start = scalar(field(Patterns,"start"),"Patterns.start",strict=False)
    if start > 1:
        raise ValueError("Patterns.start must be within [0,1]")
    idx = nearest(frex,np.sort(positive_vector(field(Patterns,"frex"),"Patterns.frex")),warn=True)
    plot_matrix = logical(field(Patterns,"plot_matrix",True),"Patterns.plot_matrix")
    plot_bones = logical(field(Patterns,"plot_bones",True),"Patterns.plot_bones")
    bones = _bones(nmarkers) if empty(field(Patterns,"bones")) else array(field(Patterns,"bones"),"Patterns.bones")-1
    if not plot_bones:
        bones = np.empty((0,2),int)
    if bones.ndim != 2 or bones.shape[1] != 2 or np.any(bones<0) or np.any(bones>=nmarkers) or np.any(bones!=np.floor(bones)):
        raise ValueError("Patterns.bones must contain one-based marker pairs")
    bones = bones.astype(int)
    cmap = ListedColormap(.95*plt.get_cmap("jet")(np.linspace(0,1,1000))[:,:3])
    unit = field(Patterns,"frequency_unit","Hz")
    for frexi in idx:
        patterns = pats[:,comp-1,frexi,:]
        if plot_matrix:
            fig, axes = plt.subplots(nsubs,3,squeeze=False,figsize=(10.5,max(4.3,3.4*nsubs)),layout="constrained")
            max_abs = np.nanmax(abs(patterns))
            max_abs = max_abs if np.isfinite(max_abs) and max_abs > 0 else 1
            for subi in range(nsubs):
                for dimi in range(3):
                    ax = axes[subi,dimi]
                    artist = ax.imshow(patterns[dimi::3,subi,None],aspect="auto",cmap=cmap,vmin=-max_abs,vmax=max_abs)
                    ax.set_xticks([])
                    ax.set_yticks(range(nmarkers),labels if dimi==0 else [""]*nmarkers)
                    ax.tick_params(labelsize=8.5)
                    ax.set_title(f"Participant #{subi+1} - {'XYZ'[dimi]}",fontsize=10,fontweight="bold")
            fig.colorbar(artist,ax=axes.ravel().tolist(),label="Activation weight",shrink=.8)
            fig.suptitle(f"Labelled activation patterns | Component #{comp} | Frequency = {frex[frexi]:.3g} {unit}",fontweight="bold")
            figures.pattern_matrix.append(fig)
        valid = patterns[np.isfinite(patterns)]
        maximum = valid.max() if valid.size else 1
        if maximum <= 0:
            maximum = max(np.max(abs(valid)),1e-300)
        normalized = patterns/maximum
        fig = plt.figure(figsize=(14.6,8))
        for dimi in range(3):
            ax = fig.add_subplot(3,3,1+dimi*4,projection="3d")
            for subi in range(nsubs):
                xyz = marker[:,0,subi].reshape(nmarkers,3)
                ax.scatter(*xyz.T,s=95,c=normalized[dimi::3,subi],cmap=cmap,vmin=-1,vmax=1,edgecolors="k",linewidths=.6)
                _draw_bones(ax,xyz,bones)
            _skeleton_axes(ax,marker)
            ax.set_title(f"{'XYZ'[dimi]}-axis activation",fontsize=13,fontweight="bold")
        cax = fig.add_axes([.945,.16,.014,.68])
        fig.colorbar(ScalarMappable(norm=Normalize(-1,1),cmap=cmap),cax=cax,label="Normalized activation")
        fig.suptitle(f"Bodily activation pattern | Component #{comp} | Frequency = {frex[frexi]:.3g} {unit}",fontsize=16,fontweight="bold")
        figures.patterns.append(fig)
    animate = field(Patterns,"animate")
    if empty(animate):
        animate = bool(int(input("Visualize the animation? (0 or 1): ")))
    logical(animate,"Patterns.animate")
    if animate:
        if str(field(FREQ,"kinematics","")).lower() == "velocity":
            raise ValueError("Velocity-derived components cannot be animated as positions")
        if len(idx)!=1 or empty(ts):
            raise ValueError("Animation requires FREQ.ts and exactly one selected frequency")
        duration = field(Patterns,"animation_duration",np.inf)
        if not np.isscalar(duration) or np.isnan(duration) or duration <= 0:
            raise ValueError("Patterns.animation_duration must be positive")
        figures.animation.append(_animate(marker,pats[:,:,idx[0],:],ts[:,:,idx[0],:],comp,srate,start,duration,bones,frex[idx[0]],unit))
    return figures


def _animate(marker,pats,ts,comp,srate,start,duration,bones,frex,unit):
    import matplotlib.pyplot as plt
    from matplotlib.animation import FuncAnimation
    nsubs = marker.shape[2]
    ntime = min(marker.shape[1],ts.shape[1])
    scores = 10*(ts[comp-1,:ntime,:]-np.nanmean(ts[comp-1,:ntime,:],axis=0))
    reconstruction = pats[:,comp-1,None,:]*scores[None,:,:]+np.nanmean(marker[:,:ntime,:],axis=1,keepdims=True)
    stride = 10+5*nsubs
    indices = np.arange(0,ntime,stride)
    time = np.arange(len(indices))/(srate/stride)
    first = min(len(indices)-1,int(np.floor(start*len(indices)+.5)))
    last = len(indices) if not np.isfinite(duration) else min(len(indices),first+int(np.floor(duration*srate/stride+.5)))
    colors = np.array([[0,0,1],[1,0,0],[.929,.694,.125],[.494,.184,.556],[.466,.674,.188],[.301,.745,.933],[.635,.078,.184]])
    fig = plt.figure(figsize=(12.8,7.8),layout="constrained")
    grid = fig.add_gridspec(2,2)
    ax_time = fig.add_subplot(grid[0,:]); ax_comp = fig.add_subplot(grid[1,0],projection="3d"); ax_raw = fig.add_subplot(grid[1,1],projection="3d")
    cursors, artists, links = [], [], []
    for subi in range(nsubs):
        color = colors[subi%len(colors)]
        ax_time.plot(time,scores[indices,subi],color=color,linewidth=2,label=f"Participant #{subi+1}")
        cursors.append(ax_time.plot([],[],"o",color=color,markeredgecolor="k")[0])
        for ax, data in ((ax_comp,reconstruction),(ax_raw,marker)):
            xyz = data[:,indices[first],subi].reshape(-1,3)
            artists.append(ax.scatter(*xyz.T,color=color,s=95,edgecolors="k",linewidths=.6))
            links.append(_draw_bones(ax,xyz,bones))
    for ax,title in ((ax_comp,"Component backprojection"),(ax_raw,"Original movement")):
        _skeleton_axes(ax,marker); ax.set_title(title,fontweight="bold")
    ax_time.set(xlabel="Time (s)",ylabel="Component scores (a.u.)",title=f"Component #{comp} activation at {frex:.3g} {unit}")
    ax_time.legend(); style(ax_time)
    def update(frame):
        for subi in range(nsubs):
            cursors[subi].set_data([time[frame]],[scores[indices[frame],subi]])
            for j,data in enumerate((reconstruction,marker)):
                xyz = data[:,indices[frame],subi].reshape(-1,3)
                artists[2*subi+j]._offsets3d = tuple(xyz.T)
                for line,pair in zip(links[2*subi+j],bones):
                    line.set_data_3d(*xyz[pair].T)
        return tuple(cursors+artists)
    update(first)
    fig._freqness_animation = FuncAnimation(fig,update,frames=range(first,last),interval=30,repeat=False)
    return fig
