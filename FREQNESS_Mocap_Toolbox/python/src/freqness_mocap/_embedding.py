"""AMI/FNN adaptation of Hui Yang's bundled routines; BSD-3-Clause.

References: Yang (2011), doi:10.1109/TBME.2010.2063704; Chen & Yang (2012),
doi:10.1016/j.chaos.2012.03.013. See THIRD_PARTY.md and bundled licences.
The original FNN search, max norm and NEXT-SAMPLE criterion are preserved.
"""
import numpy as np


def mutual(signal, maximum_lag, partitions=16):
    span = np.ptp(signal)
    normalized = (signal - signal.min()) / span if span else np.zeros_like(signal)
    bins = np.maximum(1, np.ceil(normalized * partitions)).astype(int) - 1
    mi = np.empty(maximum_lag + 1)
    for lag in range(maximum_lag + 1):
        joint = np.zeros((partitions, partitions))
        np.add.at(joint, (bins[:len(bins)-lag], bins[lag:]), 1)
        joint /= len(bins) - lag
        independent = joint.sum(axis=1)[:, None] * joint.sum(axis=0)[None, :]
        mask = joint > 0
        mi[lag] = np.sum(joint[mask] * np.log(joint[mask] / independent[mask]))
    return mi


def false_nearest(signal, maximum_dimension, tau):
    span = np.ptp(signal)
    if not span:
        return np.zeros(maximum_dimension)
    signal = (signal - signal.min()) / span
    variance = signal.std(ddof=1)
    eps0, rt = .001, 10.
    fractions = np.zeros(maximum_dimension)
    for dim in range(1, maximum_dimension + 1):
        times = np.arange((dim - 1) * tau, len(signal) - 1)
        vectors = signal[times[:, None] - np.arange(dim)[None, :] * tau]
        done = np.zeros(len(times), bool)
        too_large = 0
        epsilon = eps0
        while not done.all() and epsilon < 2 * variance / rt:
            boxes = {}
            cells = np.ceil(vectors[:, [dim-1, 0]] / epsilon).astype(int) & 1023
            cells[cells == 0] = 1
            for i, cell in enumerate(cells):
                boxes.setdefault(tuple(cell), []).append(i)
            for i in np.flatnonzero(~done):
                mindx, which = 1.1, -1
                for x1 in range(cells[i, 0] - 1, cells[i, 0] + 2):
                    if x1 == 0:
                        continue
                    for y1 in range(cells[i, 1] - 1, cells[i, 1] + 2):
                        if y1 == 0:
                            continue
                        # Linked lists in MATLAB visit most recently inserted first.
                        for j in reversed(boxes.get((x1 & 1023, y1 & 1023), [])):
                            if i == j:
                                continue
                            distance = np.max(abs(vectors[i] - vectors[j]))
                            if 0 < distance < mindx:
                                mindx, which = distance, j
                if which != -1 and mindx <= epsilon and mindx <= variance / rt:
                    too_large += abs(signal[times[i] + 1] - signal[times[which] + 1]) / mindx > rt
                    done[i] = True
            epsilon *= np.sqrt(2.)
            if not done.any():
                eps0 = epsilon
        fractions[dim - 1] = too_large / done.sum() if done.any() else 0
    return fractions
