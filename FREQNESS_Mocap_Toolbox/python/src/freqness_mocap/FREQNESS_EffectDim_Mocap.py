"""Quadratic Renyi entropy and effective dimensionality (Pirk; Del Giudice).

Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti.
"""
import numpy as np
from ._utils import field, array, logical


def FREQNESS_EffectDim_Mocap(FREQ, *, figure=True, plot_all=False):
    """Return (H2, ED), each frequency x participant, from the FULL spectrum.

    H2=-log(sum(p**2)); ED=sum(lambda)**2/sum(lambda**2). Zero spectra
    give H2=Inf, ED=0; NaNs propagate, as in MATLAB. Scalar cases return scalars.
    """
    logical(figure, "figure")
    logical(plot_all, "plot_all")
    eigenspectrum = array(field(FREQ, "evals"), "FREQ.evals", finite=False, ndim=3)
    if np.isinf(eigenspectrum).any() or np.any(eigenspectrum < 0):
        raise ValueError("FREQ.evals must contain non-negative eigenvalues without Inf")
    if eigenspectrum.ndim == 1 or (eigenspectrum.ndim == 2 and min(eigenspectrum.shape) == 1):
        eigenspectrum = eigenspectrum.reshape(-1, 1)
    eigenspectrum = eigenspectrum.reshape(eigenspectrum.shape + (1,) * (3 - eigenspectrum.ndim))
    total = eigenspectrum.sum(axis=0)
    with np.errstate(divide="ignore", invalid="ignore"):
        p = eigenspectrum / np.maximum(total, np.finfo(float).tiny)
        H2 = -np.log((p ** 2).sum(axis=0))
        ED = total ** 2 / np.maximum((eigenspectrum ** 2).sum(axis=0), np.finfo(float).tiny)
    if figure:
        from ._plotting import plot_ed
        plot_ed(ED, field(FREQ, "frex"), plot_all)
    return (H2.item(), ED.item()) if H2.size == 1 else (H2, ED)
