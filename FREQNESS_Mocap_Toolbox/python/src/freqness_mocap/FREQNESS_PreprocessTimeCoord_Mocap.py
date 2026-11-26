"""Matched JRQA preprocessing. Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
import numpy as np
from scipy.signal import butter, filtfilt
from ._utils import Struct, array, scalar, logical, empty, interval


def FREQNESS_PreprocessTimeCoord_Mocap(time_series, srate, *, target_srate=None,
                                     lowpass_cutoff=None, filter_order=4, duration=None,
                                     standardize=False):
    """Filter BEFORE decimation, select interval, optionally z-score (sample SD).

    Input/output time x series. Selected index metadata remains one-based.
    An empty cutoff means no filtering; no unrequested anti-alias filter is added.
    """
    values = array(time_series, "time_series", ndim=2)
    values = values.reshape(-1, 1) if values.ndim < 2 or min(values.shape) == 1 else values
    if len(values) < 4:
        raise ValueError("At least four time points are required")
    srate = scalar(srate, "srate")
    target_srate = srate if empty(target_srate) else scalar(target_srate, "target_srate")
    factor = srate / target_srate
    if factor < 1 or abs(factor - round(factor)) > 100 * np.spacing(max(srate, target_srate)):
        raise ValueError("srate/target_srate must be a positive integer")
    factor = int(round(factor))
    filter_order = scalar(filter_order, "filter_order", integer=True)
    logical(standardize, "standardize")
    cutoff = None
    if not empty(lowpass_cutoff):
        lowpass_cutoff = scalar(lowpass_cutoff, "lowpass_cutoff")
        if lowpass_cutoff >= target_srate / 2:
            raise ValueError("lowpass_cutoff must be below target Nyquist")
        cutoff = lowpass_cutoff / (srate / 2)
        b, a = butter(filter_order, cutoff)
        # MATLAB filtfilt uses 3*(max(len(a),len(b))-1) reflected samples.
        values = filtfilt(b, a, values, axis=0, padlen=3 * (max(len(a), len(b)) - 1))
    original_indices = np.arange(0, len(values), factor)
    first, last = interval(duration, len(original_indices))
    if last - first < 4:
        raise ValueError("Fewer than four samples remain after selection")
    selected = values[original_indices[first:last]].copy()
    mean = np.zeros(selected.shape[1])
    sd = np.ones(selected.shape[1])
    if standardize:
        mean, sd = selected.mean(axis=0), selected.std(axis=0, ddof=1)
        if np.any(sd == 0) or not np.isfinite(sd).all():
            raise ValueError("Cannot standardize a constant or non-finite series")
        selected = (selected - mean) / sd
    metadata = Struct(OriginalSamplingRate=srate, TargetSamplingRate=target_srate,
                      DecimationFactor=factor, LowpassCutoffHz=lowpass_cutoff,
                      NormalizedLowpassCutoff=cutoff, FilterOrder=filter_order,
                      ZeroPhaseFiltering=cutoff is not None,
                      Duration=np.array([0, 1]) if empty(duration) else np.asarray(duration),
                      OriginalSampleCount=len(values), DownsampledSampleCount=len(original_indices),
                      SelectedSampleCount=len(selected), SelectedDownsampledIndices=np.arange(first, last) + 1,
                      SelectedOriginalIndices=original_indices[first:last] + 1,
                      Standardized=standardize, SeriesMean=mean, SeriesSD=sd)
    return selected, metadata
