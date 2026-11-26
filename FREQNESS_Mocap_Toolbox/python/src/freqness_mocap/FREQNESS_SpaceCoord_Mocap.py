"""Spatial pattern-magnitude similarity. Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
import numpy as np
from ._utils import field, shaped, frequencies, per_participant, positive_vector, scalar, logical, nearest


def FREQNESS_SpaceCoord_Mocap(FREQ, target_frex, *, component=1, metric_levels=1, Fisher=False):
    """Return one correlation per level; optional Fisher=True returns atanh(r).

    Exactly two participants. Matches MATLAB's explicit shared-bin convention:
    the last participant's selected index is applied to BOTH patterns.
    No extra raw/transformed output is created. Perfect r maps to +/-Inf.
    """
    pats = shaped(field(FREQ, "pats"), "FREQ.pats", 4, finite=False)
    if pats.shape[3] != 2:
        raise ValueError("SpaceCoord requires exactly two participants")
    frex = frequencies(field(FREQ, "frex"), pats.shape[2], 2)
    target = per_participant(target_frex, 2, "target_frex", broadcast=False)
    component = scalar(component, "component", integer=True)
    if component > pats.shape[1]:
        raise ValueError("component exceeds FREQ.pats")
    levels = positive_vector(metric_levels, "metric_levels")
    logical(Fisher, "Fisher")
    indices = nearest(frex[:, 1], target[1] * levels)
    with np.errstate(invalid="ignore", divide="ignore"):
        values = np.array([np.corrcoef(abs(pats[:, component - 1, idx, 0]),
                                      abs(pats[:, component - 1, idx, 1]))[0, 1] for idx in indices])
        return np.arctanh(values) if Fisher else values
