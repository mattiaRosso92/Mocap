"""FFT analytic signal, without a MATLAB Signal Processing Toolbox dependency."""
import numpy as np
from scipy.signal import hilbert
from ._utils import array


def FREQNESS_AnalyticSignal(data):
    """Transform time along axis 0, preserving a supplied row-vector shape."""
    data = array(data, "data", ndim=2)
    axis = 1 if data.ndim == 2 and data.shape[0] == 1 else 0
    if data.ndim == 0 or data.shape[axis] < 2:
        raise ValueError("data must contain at least two time samples")
    return hilbert(data, axis=axis)
