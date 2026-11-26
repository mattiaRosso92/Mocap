"""Eight RQA measures, preserving bundled CRP dl/tt conventions.

Line extraction adapted from Norbert Marwan's dl.m (2016), tt.m (2017),
GPL-2.0-or-later; see THIRD_PARTY.md. Toolbox: Rosso, Bigand, Bonetti.
"""
import numpy as np
from ._utils import Struct, array, scalar, runs


def diagonal_lengths(rp):
    # MATLAB spdiags packs lower diagonals at the TOP, upper at the BOTTOM.
    # Its column-major flattening can join boundary runs. Preserve that
    # documented external-routine convention, rather than silently fixing it.
    n = len(rp)
    packed = []
    for offset in range(-n + 1, n):
        diagonal = np.diag(rp, k=offset)
        if not diagonal.any():
            continue
        padding = np.zeros(abs(offset), bool)
        packed.append(np.r_[diagonal, padding] if offset < 0 else np.r_[padding, diagonal])
    if not packed:
        return np.array([], int)
    start, end = runs(np.concatenate(packed))
    return np.sort(end - start)


def vertical_lengths(rp):
    # tt catches errors from the subsequent white-line computation, returning
    # NaN even for black lines. In particular, all-recurrent matrices do so.
    white = rp.copy()
    np.fill_diagonal(white, True)
    for i in range(len(rp)):
        indices = np.flatnonzero(white[:, i])
        white[:indices[0] + 1, i] = True
        white[indices[-1]:, i] = True
    if white.all():
        return np.array([], int)
    packed = np.vstack([rp, np.zeros((1, len(rp)), bool)]).ravel(order="F")
    # tt also fails when no rising edge exists (one run starting at index 1).
    if not np.any(np.diff(packed.astype(int)) == 1):
        return np.array([], int)
    start, end = runs(packed)
    return np.sort(end - start)


def FREQNESS_RQA_Mocap(recurrence_plot, lmin=2, vmin=2):
    """Return rr, det, l, entr, lam, tt, vmax, div; no embedding or masking.

    RR uses all entries. Callers with excluded pairs must replace its denominator.
    Entropy uses natural logarithms; divergence omits one longest diagonal.
    """
    rp = array(recurrence_plot, "recurrence_plot", ndim=2)
    if rp.ndim != 2 or rp.shape[0] != rp.shape[1] or not np.isin(rp, [0, 1]).all():
        raise ValueError("recurrence_plot must be a non-empty square binary matrix")
    lmin = scalar(2 if lmin is None else lmin, "lmin", integer=True)
    vmin = scalar(2 if vmin is None else vmin, "vmin", integer=True)
    rp = rp.astype(bool)
    nrecurrences = rp.sum()
    output = Struct(rr=nrecurrences / rp.size, det=np.nan, l=np.nan, entr=np.nan,
                    lam=np.nan, tt=np.nan, vmax=np.nan, div=np.nan)
    if not nrecurrences:
        return output
    diag = diagonal_lengths(rp)
    diag = diag[diag >= lmin]
    vert = vertical_lengths(rp)
    vert = vert[vert >= vmin]
    output.det = diag.sum() / nrecurrences
    output.lam = vert.sum() / nrecurrences
    if diag.size:
        output.l = diag.mean()
        # MATLAB hist centres 1:n absorb overlong lines into the final bin.
        counts = np.bincount(np.minimum(diag, len(rp)), minlength=len(rp) + 1)[1:]
        p = counts[counts > 0] / counts.sum()
        output.entr = -np.sum(p * np.log(p))
        output.div = 1 / (diag[:-1].max() if len(diag) >= 2 else diag[0])
    if vert.size:
        output.tt = vert.mean()
        output.vmax = vert.max()
    return output
