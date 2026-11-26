"""Corrected joint recurrence only; historical inconsistent tuning is absent."""
import numpy as np
from ._utils import Struct, field, scalar, logical, choice, empty, per_participant
from ._recurrence import inputs, distances, embed, eligible_pairs, fixed_threshold, fraction
from ._phase_space_rqa import FREQNESSCoordinationResult
from .FREQNESS_PreprocessTimeCoord_Mocap import FREQNESS_PreprocessTimeCoord_Mocap
from .FREQNESS_RQA_Mocap import FREQNESS_RQA_Mocap, diagonal_lengths


def compute_joint_rqa(FREQ, target_frex, parameters, *, component=1, metric_levels=1, duration=None,
                      srate=None, target_srate=None, lowpass_cutoff=None, filter_order=4,
                      standardize=False, threshold_method="radius", threshold=None,
                      theiler_window=0, lmin=2, vmin=2, store_matrices=False):
    ts, components, levels, idx, selected = inputs(FREQ, target_frex, component, metric_levels, joint=True)
    if not empty(field(FREQ, "bad_segments")):
        raise ValueError("JRQA requires a common contiguous time grid without marked gaps")
    m = scalar(field(parameters, "m"), "parameters.m", integer=True)
    tau = scalar(field(parameters, "tau"), "parameters.tau", integer=True)
    threshold_method = choice(threshold_method, ("radius", "adaptive_max_radius", "fixed_rr"), "threshold_method")
    theiler_window = scalar(theiler_window, "theiler_window", strict=False, integer=True)
    scalar(lmin, "lmin", integer=True); scalar(vmin, "vmin", integer=True)
    logical(store_matrices, "store_matrices"); logical(standardize, "standardize")
    if empty(srate) and (not empty(target_srate) or not empty(lowpass_cutoff)):
        raise ValueError("srate is required for filtering or decimation")
    output = FREQNESSCoordinationResult()
    for leveli, level in enumerate(levels):
        series = np.column_stack([ts[components[s] - 1, :, idx[s, leveli], s] for s in range(2)])
        processed, preprocessing = FREQNESS_PreprocessTimeCoord_Mocap(
            series, 1 if empty(srate) else srate, target_srate=target_srate,
            lowpass_cutoff=lowpass_cutoff, filter_order=filter_order, duration=duration, standardize=standardize)
        if empty(srate):
            preprocessing.OriginalSamplingRate = None
            preprocessing.TargetSamplingRate = None
        nstates = len(processed) - (m - 1) * tau
        if nstates < 4:
            raise ValueError("Embedding leaves fewer than four reconstructed states")
        phase = [embed(processed[:, s], m, tau) for s in range(2)]
        distance = [distances(x) for x in phase]
        eligible = eligible_pairs(nstates, theiler_window)
        estimates, radius_fraction = np.array([]), None
        if threshold_method == "radius":
            thresholds = per_participant(field(parameters, "ps") if empty(threshold) else threshold, 2, "threshold")
        elif threshold_method == "adaptive_max_radius":
            radius_fraction = fraction(field(parameters, "RadiusFraction") if empty(threshold) else threshold)
            estimates = radius_fraction * np.array([x.max() for x in distance])
            thresholds = np.repeat(estimates.max(), 2)
        else:
            thresholds = np.array([fixed_threshold(x, eligible, fraction(threshold)) for x in distance])
        participant_rp = np.stack([(distance[s] < thresholds[s]) & eligible for s in range(2)], axis=2)
        marginal = participant_rp.sum(axis=(0, 1)) / eligible.sum()
        rp = participant_rp.all(axis=2)
        rqa = FREQNESS_RQA_Mocap(rp, lmin, vmin)
        diag = diagonal_lengths(rp)
        diag = diag[diag >= lmin]
        times1, times2 = [], []
        for columni in range(nstates):
            times1.extend(np.diff(np.flatnonzero(rp[:, columni])))
            times2.extend(np.diff(np.flatnonzero(np.diff(rp[:, columni].astype(int)) == 1)))
        rr = rp.sum() / eligible.sum()
        output.append(Struct(RR=rr, DET=rqa.det, L=rqa.l, Lmax=diag.max() if diag.size else 0,
                             ENTR=rqa.entr, LAM=rqa.lam, TT=rqa.tt, Vmax=rqa.vmax,
                             T1=np.mean(times1) if times1 else np.nan, T2=np.mean(times2) if times2 else np.nan,
                             SelectedFrequencies=selected[:, leveli], MetricLevel=level, Component=component,
                             Implementation="validated", Thresholds=thresholds, ThresholdMethod=threshold_method,
                             ParticipantRadiusEstimates=estimates, RadiusFraction=radius_fraction,
                             MarginalRR=marginal, ExpectedJointRR=marginal.prod(), ExcessJointRR=rr-marginal.prod(),
                             EmbeddingDimension=m, Delay=tau, TheilerWindow=theiler_window,
                             EffectiveStateCount=nstates, EligiblePairCount=int(eligible.sum()), Lmin=lmin, Vmin=vmin,
                             Preprocessing=preprocessing,
                             ParticipantRecurrencePlots=participant_rp if store_matrices else np.array([]),
                             JointRecurrencePlot=rp if store_matrices else np.array([]),
                             EligiblePairMask=eligible if store_matrices else np.array([]),
                             PhaseSpace=phase if store_matrices else [], Method="jrqa"))
    return output
