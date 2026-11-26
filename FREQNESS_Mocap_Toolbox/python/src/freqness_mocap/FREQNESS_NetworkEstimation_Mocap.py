"""Frequency-resolved bodily networks: Mattia Rosso, Felix Bigand, Leonardo Bonetti.

GED follows Mike X Cohen (2022). The current MoCap MATLAB implementation is
the numerical reference, including signed, unscaled activation patterns.
"""
from dataclasses import dataclass
import numpy as np
from scipy.linalg import eigh
from ._utils import Struct, array, scalar, logical, choice, empty, sample_indices
from .FREQNESS_ComputeFilterWidths_Mocap import FREQNESS_ComputeFilterWidths_Mocap
from .FREQNESS_InterpolateGaps_Mocap import FREQNESS_InterpolateGaps_Mocap
from .filterFGx import filterFGx


@dataclass
class FREQNESSResult:
    evals: np.ndarray
    evecs: np.ndarray
    pats: np.ndarray
    ts: np.ndarray
    frex: np.ndarray
    fwhm: np.ndarray
    srate: float
    duration: float
    bad_segments: np.ndarray
    bad_segments_by_participant: list
    gap_info: Struct
    regularisation: float
    method: str
    kinematics: str
    input_n_samples: int
    sample_offset: float


def FREQNESS_NetworkEstimation_Mocap(data, frex, srate, *, method="ged", kinematics="position",
                                   duration=None, fwidth=None, filter="logarithmic", regularisation=.01,
                                   ncomps=30, bad_segments=None, interpolate_gaps=True,
                                   maximum_interpolated_gap=.05, maximum_reconstructed_gap=None):
    """Estimate GED (default) or narrowband PCA from XYZ x time x participants.

    frex is shared or [nFrex x nParticipants]. All eigenvalues are retained and
    sum to 100 per spectrum; evecs/pats are coordinates x ncomps x frex x subs,
    ts is ncomps x time x frex x subs. Singleton participant axes are retained.
    Optional velocity is diff(positions)*srate, with midpoint timing and
    exclusions propagated to both intervals touching a bad position sample.
    Explicit sample indices remain one-based, as in the brain Python package.
    """
    data = array(data, "data", finite=False, ndim=3)
    if data.ndim < 2 or np.isinf(data).any():
        raise ValueError("data must be coordinates x time x participants without Inf")
    data = data[:, :, None] if data.ndim == 2 else data
    srate = scalar(srate, "srate")
    method = choice(method, ("ged", "pca"), "method")
    kinematics = choice(kinematics, ("position", "velocity"), "kinematics")
    filter = choice(filter, ("logarithmic", "linear"), "filter")
    regularisation = scalar(regularisation, "regularisation", strict=False)
    if regularisation >= 1:
        raise ValueError("regularisation must be in [0, 1)")
    ncomps = scalar(ncomps, "ncomps", integer=True)
    if ncomps > data.shape[0]:
        raise ValueError("ncomps cannot exceed the number of coordinates")
    logical(interpolate_gaps, "interpolate_gaps")
    duration = data.shape[1] / srate if empty(duration) else scalar(duration, "duration")
    nsamples = duration * srate
    if abs(nsamples - round(nsamples)) > np.spacing(max(1., nsamples)):
        raise ValueError("duration*srate must define an integer sample count")
    nsamples = int(round(nsamples))
    if nsamples > data.shape[1] or nsamples < (3 if kinematics == "velocity" else 2):
        raise ValueError("Requested duration is outside the input sample range")
    supplied_bad = sample_indices(bad_segments, nsamples)
    values = data[:, :nsamples, :]
    if not interpolate_gaps and np.isnan(values).any():
        raise ValueError("NaN gaps require interpolate_gaps=True")
    values, detected_bad, gap_info = FREQNESS_InterpolateGaps_Mocap(
        values, srate, maximum_interpolated_gap=maximum_interpolated_gap,
        maximum_reconstructed_gap=maximum_reconstructed_gap)
    bad = np.union1d(supplied_bad, detected_bad)
    gap_info.detected_bad_segments = detected_bad
    gap_info.supplied_bad_segments = supplied_bad
    gap_info.has_detected_gaps = gap_info.has_gaps
    gap_info.detected_affected_timepoint_count = gap_info.affected_timepoint_count
    gap_info.bad_segments = bad
    gap_info.has_gaps = bool(bad.size)
    gap_info.affected_timepoint_count = len(bad)
    gap_info.bad_segments_by_participant = [np.union1d(x, supplied_bad) for x in gap_info.bad_segments_by_participant]
    bad_by_sub = list(gap_info.bad_segments_by_participant)
    sample_offset = 0.
    if kinematics == "velocity":
        values = np.diff(values, axis=1) * srate
        def remap(indices):
            indices = np.union1d(indices, indices - 1)
            return indices[(indices >= 1) & (indices < nsamples)]
        bad = remap(bad)
        bad_by_sub = [remap(x) for x in bad_by_sub]
        sample_offset = .5 / srate
        gap_info.sample_domain = "input_position"
    good = np.setdiff1d(np.arange(values.shape[1]), bad - 1)
    if good.size < 2:
        raise ValueError("Fewer than two samples remain for covariance estimation")
    frex = array(frex, "frex", ndim=2)
    if np.any((frex <= 0) | (frex >= srate / 2)):
        raise ValueError("frex must be positive and below Nyquist")
    ncoords, ntime, nsubs = values.shape
    shared = frex.ndim < 2 or min(frex.shape) == 1
    if shared:
        frex = np.sort(frex.reshape(-1))
        all_frex = np.repeat(frex[:, None], nsubs, axis=1)
    elif frex.shape[1] == nsubs:
        frex = np.sort(frex, axis=0)
        all_frex = frex
    else:
        raise ValueError("frex must be shared or [nFrex x nParticipants]")
    nfrex = len(all_frex)
    if empty(fwidth):
        widths = FREQNESS_ComputeFilterWidths_Mocap(all_frex, filter)
    else:
        widths = array(fwidth, "fwidth", ndim=2)
        if np.any(widths <= 0):
            raise ValueError("fwidth must be positive")
        if widths.size == 1:
            widths = np.full((nfrex, nsubs), widths.item())
        elif widths.size == nfrex and (widths.ndim < 2 or min(widths.shape) == 1):
            widths = np.repeat(widths.reshape(-1, 1), nsubs, axis=1)
        elif widths.shape != (nfrex, nsubs):
            raise ValueError("fwidth must be scalar, shared vector, or [nFrex x nParticipants]")
    evals = np.empty((ncoords, nfrex, nsubs))
    evecs = np.empty((ncoords, ncomps, nfrex, nsubs))
    pats = np.empty_like(evecs)
    ts = np.empty((ncomps, ntime, nfrex, nsubs))
    for subi in range(nsubs):
        print(f"FREQNESS Network Estimation: participant #{subi + 1}")
        broadData = values[:, :, subi]
        covR = None
        if method == "ged":
            covR = np.atleast_2d(np.cov(broadData[:, good], ddof=1))
            covR = (1 - regularisation) * covR + regularisation * np.linalg.eigvalsh(covR).mean() * np.eye(ncoords)
        for frexi in range(nfrex):
            narrowData, _, _ = filterFGx(broadData, srate, all_frex[frexi, subi], widths[frexi, subi])
            covS = np.atleast_2d(np.cov(narrowData[:, good], ddof=1)) + 1e-6 * np.eye(ncoords)
            eigenvalues, eigenvectors = eigh(covS, covR, driver="gvd" if method == "ged" else "evd")
            order = np.argsort(eigenvalues)[::-1]
            eigenvalues = eigenvalues[order]
            if not np.isfinite(eigenvalues.sum()) or abs(eigenvalues.sum()) < np.finfo(float).tiny:
                raise ValueError("Eigenvalues cannot be normalized")
            vectors = eigenvectors[:, order[:ncomps]]
            evals[:, frexi, subi] = eigenvalues * 100 / eigenvalues.sum()
            evecs[:, :, frexi, subi] = vectors
            patterns = covS @ vectors
            signs = np.sign(patterns[np.argmax(abs(patterns), axis=0), np.arange(ncomps)])
            pats[:, :, frexi, subi] = patterns * signs
            ts[:, :, frexi, subi] = vectors.T @ broadData
    return FREQNESSResult(evals, evecs, pats, ts, frex, widths, srate, ntime / srate,
                         bad, bad_by_sub, gap_info, regularisation, method, kinematics,
                         nsamples, sample_offset)
