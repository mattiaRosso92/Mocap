"""Corrected embedding tuning. Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
import numpy as np
from ._utils import Struct, scalar, per_participant
from ._recurrence import inputs, embed, distances, fraction
from ._embedding import mutual, false_nearest
from .FREQNESS_PreprocessTimeCoord_Mocap import FREQNESS_PreprocessTimeCoord_Mocap


def FREQNESS_JRQAParameters_Mocap(FREQ, target_frex, srate, *, metric_levels=1, component=1,
                                duration=None, target_srate=None, lowpass_cutoff=None, filter_order=4,
                                standardize=False, maximum_lag=20, maximum_dimension=5,
                                fnn_threshold=.1, radius_fraction=.1):
    """Estimate participant x level tau/m/ps, with AMI/FNN diagnostics and provenance.

    First positive-lag local AMI minimum; first FNN fraction <= criterion.
    Fallbacks choose the minimum measured AMI/FNN. Radius is fraction of the
    Euclidean embedded diameter. Pooling across observations remains external.
    """
    ts, components, levels, idx, selected = inputs(FREQ, target_frex, component, metric_levels, joint=True)
    maximum_lag = scalar(maximum_lag, "maximum_lag", integer=True)
    maximum_dimension = scalar(maximum_dimension, "maximum_dimension", integer=True)
    fnn_threshold, radius_fraction = fraction(fnn_threshold), fraction(radius_fraction)
    shape = (2, len(levels))
    tau, m, ps = np.zeros(shape, int), np.zeros(shape, int), np.zeros(shape)
    tau_fallback, m_fallback = np.zeros(shape, bool), np.zeros(shape, bool)
    mi_curves, fnn_curves, preprocessing = (np.empty(shape, object) for _ in range(3))
    for subi in range(2):
        for leveli in range(len(levels)):
            values, metadata = FREQNESS_PreprocessTimeCoord_Mocap(
                ts[components[subi]-1, :, idx[subi, leveli], subi], srate,
                target_srate=target_srate, lowpass_cutoff=lowpass_cutoff, filter_order=filter_order,
                duration=duration, standardize=standardize)
            signal = values[:, 0]
            mi = mutual(signal, min(maximum_lag, len(signal)-1))
            minima = np.flatnonzero((mi[1:-1] <= mi[:-2]) & (mi[1:-1] < mi[2:])) + 1
            tau_fallback[subi, leveli] = not minima.size
            delay = int(minima[0] if minima.size else np.argmin(mi[1:]) + 1)
            max_dimension = min(maximum_dimension, (len(signal)-2) // delay + 1)
            fnn = false_nearest(signal, max_dimension, delay)
            acceptable = np.flatnonzero(np.isfinite(fnn) & (fnn <= fnn_threshold))
            m_fallback[subi, leveli] = not acceptable.size
            dimension = int(acceptable[0] + 1 if acceptable.size else np.nanargmin(fnn) + 1)
            tau[subi, leveli], m[subi, leveli] = delay, dimension
            ps[subi, leveli] = radius_fraction * distances(embed(signal, dimension, delay)).max()
            mi_curves[subi, leveli], fnn_curves[subi, leveli] = mi, fnn
            preprocessing[subi, leveli] = metadata
    return Struct(tau=tau, m=m, ps=ps, SelectedFrequencies=selected, MetricLevels=levels,
                  Component=component, TargetFrequencies=per_participant(target_frex, 2, "target_frex", broadcast=False),
                  MutualInformation=mi_curves, FalseNearestFraction=fnn_curves, TauFallback=tau_fallback,
                  DimensionFallback=m_fallback, Preprocessing=preprocessing, MaximumLag=maximum_lag,
                  MaximumDimension=maximum_dimension, FNNThreshold=fnn_threshold, RadiusFraction=radius_fraction,
                  DelayRule="first_local_mutual_information_minimum", DimensionRule="first_fnn_at_or_below_threshold",
                  Distance="euclidean", Version="validated-v1")
