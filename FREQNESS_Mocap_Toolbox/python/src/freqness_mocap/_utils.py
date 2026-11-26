"""Shared validation and structure access; no study-specific configuration."""
from types import SimpleNamespace
import warnings
import numpy as np


class Struct(SimpleNamespace):
    """MATLAB-style named fields, also accepting dictionary inputs at boundaries."""
    def __getitem__(self, key):
        return getattr(self, key)


def field(value, name, default=None):
    return value.get(name, default) if isinstance(value, dict) else getattr(value, name, default)


def array(value, name, *, finite=True, ndim=None):
    raw = np.asarray(value)
    if raw.dtype.kind not in "bifu" or np.iscomplexobj(raw) or not raw.size:
        raise ValueError(f"{name} must be a non-empty real numeric array")
    out = raw.astype(float)
    if finite and not np.isfinite(out).all():
        raise ValueError(f"{name} must contain finite values")
    if ndim is not None and out.ndim > ndim:
        raise ValueError(f"{name} must have at most {ndim} dimensions")
    return out


def scalar(value, name, *, minimum=0, integer=False, strict=True):
    out = array(value, name)
    if out.size != 1:
        raise ValueError(f"{name} must be a scalar")
    out = float(out.reshape(-1)[0])
    if (out <= minimum if strict else out < minimum) or (integer and out != np.floor(out)):
        raise ValueError(f"{name} is outside its valid range")
    return int(out) if integer else out


def logical(value, name):
    if not isinstance(value, (bool, np.bool_)):
        raise ValueError(f"{name} must be Boolean")
    return bool(value)


def choice(value, choices, name):
    if not isinstance(value, str) or value.lower() not in choices:
        raise ValueError(f"{name} must be one of {choices}")
    return value.lower()


def empty(value):
    return value is None or np.size(value) == 0


def shaped(value, name, ndim, *, finite=True):
    out = array(value, name, finite=finite, ndim=ndim)
    return out.reshape(out.shape + (1,) * (ndim - out.ndim))


def positive_vector(value, name):
    out = array(value, name)
    if out.ndim > 2 or (out.ndim == 2 and min(out.shape) > 1) or np.any(out <= 0):
        raise ValueError(f"{name} must be a positive vector")
    return out.reshape(-1)


def per_participant(value, nsubs, name, *, integer=False, broadcast=True):
    out = positive_vector(value, name)
    if broadcast and out.size == 1:
        out = np.repeat(out, nsubs)
    if out.size != nsubs or (integer and np.any(out != np.floor(out))):
        raise ValueError(f"{name} must contain {'integer ' if integer else ''}values for {nsubs} participants")
    return out.astype(int) if integer else out


def frequencies(value, nfrex, nsubs):
    out = array(value, "FREQ.frex", ndim=2)
    if np.any(out <= 0):
        raise ValueError("FREQ.frex must be positive")
    if out.size == nfrex and (out.ndim < 2 or min(out.shape) == 1):
        return np.repeat(out.reshape(-1, 1), nsubs, axis=1)
    if out.shape != (nfrex, nsubs):
        raise ValueError("FREQ.frex must be shared or [nFrex x nParticipants]")
    return out


def sample_indices(value, nsamples, name="bad_segments"):
    if empty(value):
        return np.empty(0, dtype=int)
    out = positive_vector(value, name)
    if np.any(out != np.floor(out)) or np.any(out > nsamples):
        raise ValueError(f"{name} must contain valid one-based sample indices")
    return np.unique(out.astype(int))


def interval(duration, nsamples):
    if empty(duration):
        return 0, nsamples
    duration = array(duration, "duration").reshape(-1)
    if duration.size != 2 or not 0 <= duration[0] < duration[1] <= 1:
        raise ValueError("duration must be an increasing interval within [0, 1]")
    # MATLAB round uses half away from zero, unlike numpy's ties-to-even.
    bounds = np.floor(duration * nsamples + .5).astype(int)
    return max(1, bounds[0]) - 1, min(nsamples, bounds[1])


def runs(mask):
    changes = np.diff(np.r_[False, mask, False].astype(int))
    return np.flatnonzero(changes == 1), np.flatnonzero(changes == -1)


def nearest(frex, targets, *, warn=False):
    idx = np.argmin(np.abs(np.asarray(frex)[:, None] - np.asarray(targets).reshape(1, -1)), axis=0)
    if warn and not np.allclose(np.asarray(frex)[idx], targets, rtol=1e-10, atol=1e-12):
        warnings.warn("Requested frequencies matched to nearest stored bins", RuntimeWarning, stacklevel=2)
    return idx

