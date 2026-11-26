"""Mike X Cohen's frequency-domain Gaussian, matching the MoCap MATLAB version.

Original function: Mike X Cohen, mikexcohen@gmail.com. Adapted for FREQ-NESS.
"""
import numpy as np
from ._utils import array, scalar
from .FREQNESS_AnalyticSignal import FREQNESS_AnalyticSignal


def filterFGx(data, srate, f, fwhm, showplot=False):
    """Return filtered channels-by-time data, empirical widths, and FFT kernel."""
    data = array(data, "data", ndim=2)
    vector = data.ndim == 1
    data = np.atleast_2d(data)
    if data.shape[1] < 2 or data.shape[0] > data.shape[1]:
        raise ValueError("data must be channels by time, with at least two samples")
    srate = scalar(srate, "srate")
    f = scalar(f, "f")
    fwhm = scalar(fwhm, "fwhm")
    if f >= srate / 2:
        raise ValueError("f must be below Nyquist")
    ntime = data.shape[1]
    hz = np.linspace(0, srate, ntime)
    s = fwhm * (2 * np.pi - 1) / (4 * np.pi)
    fx = np.exp(-.5 * ((hz - f) / s) ** 2)
    fx = fx / np.max(fx)
    filtered = 2 * np.fft.ifft(np.fft.fft(data, axis=1) * fx, axis=1).real
    idx = np.argmin(abs(hz - f))
    low = np.argmin(abs(fx[:idx + 1] - .5))
    high = idx + np.argmin(abs(fx[idx:] - .5))
    envelope = abs(FREQNESS_AnalyticSignal(np.fft.fftshift(np.fft.ifft(fx)).real))
    envelope /= envelope.max()
    peak = envelope.argmax()
    t_low = np.argmin(abs(envelope[:peak + 1] - .5))
    t_high = peak + np.argmin(abs(envelope[peak:] - .5))
    empirical = np.array([hz[idx], hz[high] - hz[low], (t_high - t_low) / srate * 1000])
    if showplot:
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots()
        ax.plot(hz, fx, "k", linewidth=1.3)
        ax.set(xlim=(max(f - 10, 0), f + 10), xlabel="Frequency (Hz)", ylabel="Filter gain")
    return (filtered[0] if vector else filtered), empirical, fx
