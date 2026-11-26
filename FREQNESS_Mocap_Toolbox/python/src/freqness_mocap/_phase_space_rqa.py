"""Group-state phase-space RQA implementation, behind the TimeCoord interface."""
import warnings
import numpy as np
from ._utils import Struct, field, sample_indices, interval, scalar, logical, choice, empty
from ._recurrence import inputs, distances, eligible_pairs, fixed_threshold, fraction
from .FREQNESS_RQA_Mocap import FREQNESS_RQA_Mocap


class FREQNESSCoordinationResult(list):
    """One record per metric level, with generated figure handles in .figures."""
    def __init__(self):
        super().__init__()
        self.figures = Struct(phase_space=[], distance_matrix=[], recurrence_plot=[], animation=[])


def compute_phase_space_rqa(FREQ, target_frex, *, component=1, metric_levels=1, duration=None,
                            downsample=1, standardize=False, threshold_method="max_fraction", threshold=.1,
                            theiler_window=0, lmin=2, vmin=2, store_matrices=False, bad_segments=None,
                            figure=False, animate=False, srate=None, animation_pause=.01):
    ts, components, levels, idx, selected = inputs(FREQ, target_frex, component, metric_levels)
    ntime_original, nsubs = ts.shape[1], ts.shape[3]
    downsample = scalar(downsample, "downsample", integer=True)
    theiler_window = scalar(theiler_window, "theiler_window", strict=False, integer=True)
    scalar(lmin, "lmin", integer=True); scalar(vmin, "vmin", integer=True)
    for name, value in (("standardize", standardize), ("store_matrices", store_matrices), ("figure", figure), ("animate", animate)):
        logical(value, name)
    threshold_method = choice(threshold_method, ("max_fraction", "fixed_rr"), "threshold_method")
    threshold = fraction(threshold)
    animation_pause = scalar(animation_pause, "animation_pause", strict=False)
    if not empty(srate):
        srate = scalar(srate, "srate")
    stored = sample_indices(field(FREQ, "bad_segments"), ntime_original, "FREQ.bad_segments")
    supplied = sample_indices(bad_segments, ntime_original)
    bad = np.r_[stored, supplied[~np.isin(supplied, stored)]]
    first, last = interval(duration, ntime_original)
    indices = np.arange(first, last, downsample)
    ntime = len(indices)
    if ntime < 3 or ntime > 10000:
        raise ValueError("Phase-space RQA requires 3–10000 selected samples; change duration or downsample")
    valid = ~np.isin(indices + 1, bad)
    if valid.sum() < 3:
        raise ValueError("Fewer than three valid samples remain")
    time = indices + 1 if empty(srate) else indices / srate
    output = FREQNESSCoordinationResult()
    eligible = eligible_pairs(ntime, theiler_window, valid)
    for leveli, level in enumerate(levels):
        phase = np.full((ntime, nsubs), np.nan)
        for subi in range(nsubs):
            phase[valid, subi] = ts[components[subi] - 1, indices[valid], idx[subi, leveli], subi]
        if standardize:
            mean, sd = phase[valid].mean(axis=0), phase[valid].std(axis=0, ddof=1)
            if np.any(sd == 0):
                raise ValueError("Cannot standardize a constant time series")
            phase[valid] = (phase[valid] - mean) / sd
        distance = np.full((ntime, ntime), np.nan)
        distance[np.ix_(valid, valid)] = distances(phase[valid])
        radius = (distance[eligible].max() * threshold if threshold_method == "max_fraction"
                  else fixed_threshold(distance, eligible, threshold))
        rp = (distance < radius) & eligible
        rqa = FREQNESS_RQA_Mocap(rp, lmin, vmin)
        rr = rp.sum() / eligible.sum()
        output.append(Struct(RR=rr, L=rqa.l, DET=rqa.det, ENTR=rqa.entr, TT=rqa.tt,
                             LAM=rqa.lam, Vmax=rqa.vmax, DIV=rqa.div, PhaseSpace=phase,
                             SelectedFrequencies=selected[:, leveli], SelectedComponents=components.copy(),
                             MetricLevel=level, Threshold=radius, ThresholdMethod=threshold_method,
                             ActualRR=rr, Time=time.copy(), BadSegments=bad.copy(),
                             SelectedSampleIndices=indices + 1, ValidSampleMask=valid.copy(),
                             ValidSampleCount=int(valid.sum()), ExcludedSampleCount=int((~valid).sum()),
                             EligiblePairCount=int(eligible.sum()), EligiblePairFraction=eligible.mean(),
                             DistanceMatrix=distance if store_matrices else np.array([]),
                             RecurrencePlot=rp if store_matrices else np.array([]),
                             EligiblePairMask=eligible.copy() if store_matrices else np.array([]),
                             Method="phase_space", Standardized=standardize))
        if figure or animate:
            from ._plotting import plot_phase_space
            handles = plot_phase_space(phase, distance, rp, time, "Sample" if empty(srate) else "Time (s)",
                                       level, radius, figure, animate, animation_pause)
            for name in vars(output.figures):
                getattr(output.figures, name).extend(getattr(handles, name))
    return output
