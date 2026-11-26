"""Shared MoCap plot aesthetics, with lazy optional Matplotlib imports."""
import warnings
import numpy as np
from ._utils import Struct


def style(ax):
    ax.grid(True, alpha=.18)
    ax.tick_params(labelsize=12)
    for spine in ax.spines.values():
        spine.set_linewidth(1.2)


def frequency_axis(ax, frex):
    frex = np.asarray(frex)
    if frex.size == 1:
        ax.set_xlim(np.log2(frex[0])-.5, np.log2(frex[0])+.5)
        ax.set_xticks(np.log2(frex), [f"{x:g}" for x in frex])
    else:
        ticks = 2. ** np.arange(-6, 9)
        ticks = ticks[(ticks >= frex.min()) & (ticks <= frex.max())]
        if len(ticks) >= 2:
            ax.set_xticks(np.log2(ticks), [f"{x:g}" for x in ticks], rotation=45)
        ax.set_xlim(np.log2(frex.min()), np.log2(frex.max()))


def component_colors(n):
    import matplotlib.pyplot as plt
    colors = np.array([[.90,.22,.16],[.36,.69,.88],[.22,.45,.78],[.12,.25,.55]])
    if n > 4:
        colors = np.vstack([colors, .8 * plt.get_cmap("viridis")(np.linspace(0,1,n-4))[:, :3]])
    return colors[:n]


def plot_landscape(frex, evals, sem, xlabel, title, method):
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(8.8,5.9), layout="constrained")
    x = np.geomspace(frex.min(), frex.max(), 200) if len(frex) > 1 else frex
    upper = 0
    for compi, color in enumerate(component_colors(len(evals))):
        y = np.interp(x, frex, evals[compi])
        se = np.zeros_like(y) if sem is None else np.interp(x, frex, sem[compi])
        if sem is not None:
            ax.fill_between(np.log2(x), y-se, y+se, color=color, alpha=.22, linewidth=0)
        ax.plot(np.log2(x), y, color=color, linewidth=2.5, label=f"{method} #{compi+1}")
        upper = max(upper, np.nanmax(y+se))
    frequency_axis(ax, frex)
    ax.set_ylim(0, min(100, max(10, np.ceil(1.1*upper/10)*10)))
    ax.set_xlabel(xlabel, fontsize=14, fontweight="bold")
    ax.set_ylabel("Narrowband variance (%)" if method == "PCA" else "Relative eigenvalue contribution (%)", fontsize=14, fontweight="bold")
    ax.set_title(title, fontsize=16, fontweight="bold")
    ax.legend(loc="upper right", fontsize=11)
    style(ax)
    return fig


def plot_ed(ED, frex, plot_all):
    import matplotlib.pyplot as plt
    nfrex, nsubs = ED.shape
    frex = np.asarray(frex) if frex is not None else np.array([])
    valid_frex = frex.size == nfrex and (frex.ndim < 2 or min(frex.shape) == 1) and np.isfinite(frex).all()
    x = frex.reshape(-1) if valid_frex else np.arange(1,nfrex+1)
    logarithmic = valid_frex and np.all(x > 0)
    xp = np.log2(x) if logarithmic else x
    avg = np.nanmean(ED, axis=1)
    sem = np.nanstd(ED, axis=1, ddof=1)/np.sqrt(nsubs) if nsubs > 1 else None
    cases = [(avg, sem, "Grand Average")]
    if plot_all:
        cases.extend((ED[:,s],None,f"Participant #{s+1}") for s in range(nsubs))
    figures = []
    for value, error, title in cases:
        fig, ax = plt.subplots(figsize=(6,6), layout="constrained")
        color = [.90,.22,.16]
        if error is not None:
            ax.fill_between(xp,value-error,value+error,color=color,alpha=.22,linewidth=0)
        ax.plot(xp,value,color=color,linewidth=2.5)
        ax.set_xlabel("Frequency (Hz)" if valid_frex else "Frequency index",fontsize=14,fontweight="bold")
        ax.set_ylabel("Effective dimensionality",fontsize=14,fontweight="bold")
        ax.set_title(f"Effective Dimensionality - {title}",fontsize=16,fontweight="bold")
        if logarithmic:
            frequency_axis(ax,x)
        style(ax)
        figures.append(fig)
    return figures


def plot_phase_space(phase, distance, rp, time, time_label, level, threshold, figure, animate, pause):
    import matplotlib.pyplot as plt
    from matplotlib.colors import ListedColormap
    from matplotlib.animation import FuncAnimation
    from matplotlib.collections import LineCollection
    from mpl_toolkits.mplot3d.art3d import Line3DCollection
    figures = Struct(phase_space=[], distance_matrix=[], recurrence_plot=[], animation=[])
    nsubs = phase.shape[1]
    def segments(values):
        trajectory = np.stack([values[:-1],values[1:]],axis=1)
        valid = np.isfinite(trajectory).all(axis=(1,2))
        return trajectory[valid], valid
    def trajectory_artist(ax, values):
        trajectory, valid = segments(values)
        cls = Line3DCollection if nsubs == 3 else LineCollection
        artist = cls(trajectory,cmap="jet",linewidths=1.5)
        artist.set_clim(time[0],time[-1])
        artist.set_array(((time[:-1]+time[1:])/2)[:len(valid)][valid])
        ax.add_collection(artist)
        if nsubs == 3:
            ax.auto_scale_xyz(phase[:,0],phase[:,1],phase[:,2])
        else:
            ax.update_datalim(phase[np.isfinite(phase).all(axis=1)])
            ax.autoscale_view()
        return artist
    def phase_axes():
        fig = plt.figure(figsize=(7.6,6.5), layout="constrained")
        ax = fig.add_subplot(projection="3d" if nsubs == 3 else None)
        ax.set_xlabel("Participant #1 network score",fontweight="bold")
        ax.set_ylabel("Participant #2 network score",fontweight="bold")
        if nsubs == 3:
            ax.set_zlabel("Participant #3 network score",fontweight="bold")
            ax.view_init(elev=25,azim=-45)
        else:
            ax.set_box_aspect(1)
        style(ax)
        return fig, ax
    if figure:
        fig, ax = phase_axes()
        if nsubs <= 3:
            artist = trajectory_artist(ax,phase)
            fig.colorbar(artist,ax=ax,label=time_label)
        else:
            artist = ax.imshow(phase.T,aspect="auto",extent=[time[0],time[-1],nsubs+.5,.5],cmap="jet")
            ax.set(xlabel=time_label,ylabel="Participant")
            fig.colorbar(artist,ax=ax,label="Network score")
        ax.set_title(f"Group phase space | Metric level = {level:g}",fontweight="bold")
        figures.phase_space.append(fig)
        for values, cmap, title, name in (
            (distance,"viridis_r",f"Phase-space distance matrix | Metric level = {level:g}","distance_matrix"),
            (rp,ListedColormap([[1,1,1],[.10,.32,.65]]),f"Recurrence plot | Metric level = {level:g} | threshold = {threshold:.3g}","recurrence_plot")):
            fig, ax = plt.subplots(figsize=(7,6.2),layout="constrained")
            artist = ax.imshow(values,origin="lower",extent=[time[0],time[-1],time[0],time[-1]],cmap=cmap,interpolation="nearest")
            ax.set(xlabel=time_label,ylabel=time_label,title=title)
            style(ax)
            if name == "distance_matrix":
                fig.colorbar(artist,ax=ax,label="Euclidean distance")
            getattr(figures,name).append(fig)
    if animate:
        if nsubs > 3:
            warnings.warn("Phase-space animation requires two or three participants",RuntimeWarning)
        else:
            fig, ax = phase_axes()
            ax.set_xlim(np.nanmin(phase[:,0]),np.nanmax(phase[:,0]))
            ax.set_ylim(np.nanmin(phase[:,1]),np.nanmax(phase[:,1]))
            if nsubs == 3:
                ax.set_zlim(np.nanmin(phase[:,2]),np.nanmax(phase[:,2]))
            artist = trajectory_artist(ax,phase[:1])
            def update(i):
                trajectory, valid = segments(phase[:i+1])
                artist.set_segments(trajectory)
                artist.set_array(((time[:-1]+time[1:])/2)[:i][valid])
                return (artist,)
            fig._freqness_animation = FuncAnimation(fig,update,frames=range(0,len(phase),max(1,int(np.ceil(len(phase)/1000)))),interval=max(1,pause*1000),repeat=False)
            figures.animation.append(fig)
    return figures
