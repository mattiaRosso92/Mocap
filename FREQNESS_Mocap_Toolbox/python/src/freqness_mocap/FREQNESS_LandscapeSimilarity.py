"""Between-participant component and H2 landscape correlations."""
import warnings
import numpy as np
from ._utils import field, shaped, frequencies, empty, array, scalar, nearest
from .FREQNESS_EffectDim_Mocap import FREQNESS_EffectDim_Mocap


def FREQNESS_LandscapeSimilarity(FREQ, *, component=1, frequency_range=None):
    """Return component similarity, entropy similarity and selected frequencies.

    Dyads return scalar correlations, larger groups return square matrices.
    Participant grids must already agree; no implicit beat alignment is done.
    """
    values = shaped(field(FREQ, "evals"), "FREQ.evals", 3)
    if np.any(values < 0):
        raise ValueError("FREQ.evals must be non-negative")
    nvals, nfrex, nsubs = values.shape
    if nsubs < 2:
        warnings.warn("Landscape similarity requires at least two participants", RuntimeWarning)
        return np.array([]), np.array([]), np.array([])
    component = scalar(component, "component", integer=True)
    if component > nvals or np.any(values.sum(axis=0) <= 0):
        raise ValueError("Invalid component or non-positive eigenspectrum sum")
    frex = frequencies(field(FREQ, "frex"), nfrex, nsubs)
    if not np.all(frex == frex[:, :1]):
        raise ValueError("Landscape similarity requires identical participant grids")
    selected = np.arange(nfrex)
    if not empty(frequency_range):
        bounds = array(frequency_range, "frequency_range").reshape(-1)
        if bounds.size != 2 or np.any(bounds <= 0) or bounds[0] > bounds[1] or np.any(np.diff(frex[:, 0]) <= 0):
            raise ValueError("frequency_range must be [low high] on a strictly increasing grid")
        low, high = nearest(frex[:, 0], bounds)
        selected = np.arange(low, high + 1)
    if len(selected) < 2:
        raise ValueError("At least two frequencies must be selected")
    H2, _ = FREQNESS_EffectDim_Mocap(FREQ, figure=False)
    def correlate(x):
        if np.any(np.std(x, axis=0, ddof=1) == 0):
            warnings.warn("Constant landscape: correlation is undefined", RuntimeWarning)
        with np.errstate(divide="ignore", invalid="ignore"):
            r = np.corrcoef(x, rowvar=False)
        return r[0, 1] if nsubs == 2 else r
    return correlate(values[component - 1, selected, :]), correlate(H2[selected]), frex[selected, 0]
