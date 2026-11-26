"""XYZ gap reconstruction. Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
import warnings
import numpy as np
from scipy.interpolate import CubicSpline
from ._utils import Struct, array, scalar, choice, empty, sample_indices, runs


def FREQNESS_InterpolateGaps_Mocap(data, srate, *, maximum_interpolated_gap=.05,
                                maximum_reconstructed_gap=None, required_samples=None,
                                boundary_method="reject"):
    """Fill short NaN gaps without changing observed values.

    Input: XYZ coordinates x time x participants (or 2-D). Return filled data,
    shared one-based excluded indices, and QC metadata. Reconstruction supports
    filtering only: every affected marker sample remains excluded from covariance.
    Spline and nearest-boundary reconstruction are opt-in, exactly as in MATLAB.
    """
    data = array(data, "data", finite=False, ndim=3)
    if data.ndim < 2 or data.shape[0] % 3 or data.shape[1] < 2 or np.isinf(data).any():
        raise ValueError("data must contain complete XYZ triplets and at least two time samples, without Inf")
    input_2d = data.ndim == 2
    values = data[..., None] if input_2d else data.copy()
    srate = scalar(srate, "srate")
    maximum_interpolated_gap = scalar(maximum_interpolated_gap, "maximum_interpolated_gap")
    nlinear = int(np.floor(maximum_interpolated_gap * srate + 1e-9))
    nspline = nlinear
    if not empty(maximum_reconstructed_gap):
        maximum_reconstructed_gap = scalar(maximum_reconstructed_gap, "maximum_reconstructed_gap")
        if maximum_reconstructed_gap < maximum_interpolated_gap:
            raise ValueError("maximum_reconstructed_gap must be >= maximum_interpolated_gap")
        nspline = int(np.floor(maximum_reconstructed_gap * srate + 1e-9))
    boundary_method = choice(boundary_method, ("reject", "nearest"), "boundary_method")
    ncoordinates, nsamples, nsubs = values.shape
    nmarkers = ncoordinates // 3
    required = np.arange(1, nsamples + 1) if empty(required_samples) else sample_indices(required_samples, nsamples, "required_samples")
    missing = np.isnan(values)
    marker_missing = missing.reshape(nmarkers, 3, nsamples, nsubs).any(axis=1)
    bad_by_sub = [np.flatnonzero(marker_missing[:, :, subi].any(axis=0)) + 1 for subi in range(nsubs)]
    bad = np.flatnonzero(marker_missing.any(axis=(0, 2))) + 1
    interpolated = np.zeros_like(marker_missing)
    reconstructed = np.zeros_like(marker_missing)
    unresolved = np.zeros_like(marker_missing)
    filled = values.copy()

    def fill(marker, indices, method):
        candidate = marker.copy()
        for coordi, row in enumerate(marker):
            targets = indices[np.isnan(row[indices])]
            if not targets.size:
                continue
            observed = np.flatnonzero(np.isfinite(row))
            minimum = {"linear": 2, "spline": 4, "nearest": 1}[method]
            if observed.size < minimum or (method != "nearest" and (targets[0] <= observed[0] or targets[-1] >= observed[-1])):
                return marker, False
            if method == "nearest":
                candidate[coordi, targets] = row[observed[np.argmin(abs(observed[:, None] - targets), axis=0)]]
            elif method == "linear":
                candidate[coordi, targets] = np.interp(targets, observed, row[observed])
            else:
                candidate[coordi, targets] = CubicSpline(observed, row[observed])(targets)
        return candidate, True

    for subi in range(nsubs):
        for marki in range(nmarkers):
            coords = slice(3 * marki, 3 * marki + 3)
            for start, end in zip(*runs(marker_missing[marki, :, subi])):
                indices = np.arange(start, end)
                if start == 0 or end == nsamples or len(indices) > nspline:
                    unresolved[marki, indices, subi] = True
                    continue
                method = "linear" if len(indices) <= nlinear else "spline"
                candidate, success = fill(filled[coords, :, subi], indices, method)
                if success:
                    filled[coords, :, subi] = candidate
                    (interpolated if method == "linear" else reconstructed)[marki, indices, subi] = True
                else:
                    unresolved[marki, indices, subi] = True
    if boundary_method == "nearest":
        required_mask = np.zeros(nsamples, bool)
        required_mask[required - 1] = True
        for subi in range(nsubs):
            for marki in range(nmarkers):
                coords = slice(3 * marki, 3 * marki + 3)
                for start, end in zip(*runs(unresolved[marki, :, subi] & required_mask)):
                    indices = np.arange(start, end)
                    if (start != required[0] - 1 and end != required[-1]) or len(indices) > nspline:
                        continue
                    candidate, success = fill(filled[coords, :, subi], indices, "nearest")
                    if success:
                        filled[coords, :, subi] = candidate
                        unresolved[marki, indices, subi] = False
                        (interpolated if len(indices) <= nlinear else reconstructed)[marki, indices, subi] = True
    if unresolved[:, required - 1, :].any():
        raise ValueError("Required marker samples remain unresolved: boundary, gap limit or insufficient observations")
    info = Struct(original_missing_coordinate_mask=missing, bad_marker_sample_mask=marker_missing,
                  interpolated_marker_sample_mask=interpolated, reconstructed_marker_sample_mask=reconstructed,
                  unresolved_marker_sample_mask=unresolved, bad_segments=bad, bad_segments_by_participant=bad_by_sub,
                  maximum_interpolated_gap_seconds=maximum_interpolated_gap, maximum_interpolated_gap_frames=nlinear,
                  maximum_reconstructed_gap_seconds=maximum_reconstructed_gap, maximum_reconstructed_gap_frames=nspline,
                  required_samples=required, boundary_method=boundary_method,
                  missing_coordinate_sample_count=int(missing.sum()), affected_marker_sample_count=int(marker_missing.sum()),
                  affected_timepoint_count=len(bad), participant_count=nsubs, has_gaps=bool(bad.size))
    if bad.size:
        warnings.warn(f"Reconstructed gaps affect {len(bad)} shared samples; retain bad_segments exclusions", RuntimeWarning, stacklevel=2)
    if input_2d:
        filled = filled[:, :, 0]
        for name in ("original_missing_coordinate_mask", "bad_marker_sample_mask", "interpolated_marker_sample_mask", "reconstructed_marker_sample_mask", "unresolved_marker_sample_mask"):
            setattr(info, name, getattr(info, name)[:, :, 0])
    return filled, bad, info
