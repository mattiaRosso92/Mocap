"""Explicit historical width schedule, for reproducibility only."""
import numpy as np
from ._utils import array, choice


def FREQNESS_ComputeLegacyFilterWidths_Mocap(frex, filter="logarithmic"):
    """Reproduce the bin-count-dependent MATLAB schedule, never the default."""
    frex = array(frex, "frex", ndim=2)
    values = frex.reshape(-1, 1) if frex.ndim < 2 else frex
    if np.any(values <= 0) or np.any(np.diff(values, axis=0) < 0):
        raise ValueError("frex columns must be positive and ascending")
    filter = choice(filter, ("logarithmic", "linear"), "filter")
    widths = np.empty_like(values)
    reference = np.linspace(.1, 10, 100)
    reference_widths = np.logspace(-2, 0, 100)
    for subi in range(values.shape[1]):
        start = reference_widths[np.argmin(np.abs(reference - values[0, subi]))]
        nfrex = len(values)
        widths[:, subi] = (np.geomspace(start, start * nfrex, nfrex) if filter == "logarithmic"
                           else np.linspace(start, start * nfrex, nfrex))
    return widths.reshape(frex.shape)
