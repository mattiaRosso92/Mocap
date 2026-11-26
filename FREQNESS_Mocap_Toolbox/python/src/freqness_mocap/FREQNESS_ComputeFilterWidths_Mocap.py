"""Physical FWHM schedule. Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
import numpy as np
from ._utils import array, choice


def FREQNESS_ComputeFilterWidths_Mocap(frex, filter="logarithmic"):
    """Return Hz widths with the input shape; 1-D input is a frequency column.

    Logarithmic Q decreases from 7 to 3.5 per participant's frequency range;
    linear uses Q=5. A singleton range uses sqrt(7*3.5).
    """
    frex = array(frex, "frex", ndim=2)
    if np.any(frex <= 0):
        raise ValueError("frex must be positive")
    filter = choice(filter, ("logarithmic", "linear"), "filter")
    if filter == "linear":
        return frex / 5
    values = frex.reshape(-1, 1) if frex.ndim < 2 else frex
    widths = np.empty_like(values)
    for subi in range(values.shape[1]):
        x = values[:, subi]
        q = np.sqrt(7 * 3.5) if x.min() == x.max() else 7 * .5 ** (np.log(x / x.min()) / np.log(x.max() / x.min()))
        widths[:, subi] = x / q
    return widths.reshape(frex.shape)
