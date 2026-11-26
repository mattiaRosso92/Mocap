"""Private shared recurrence geometry; no study-specific tuning or pooling."""
import numpy as np
from ._utils import field, shaped, frequencies, per_participant, positive_vector, nearest, scalar


def inputs(FREQ, target_frex, component, metric_levels, *, joint=False):
    ts = shaped(field(FREQ, "ts"), "FREQ.ts", 4)
    ncomps, ntime, nfrex, nsubs = ts.shape
    if nsubs < 2 or (joint and nsubs != 2):
        raise ValueError("Temporal coordination requires at least two participants; JRQA requires exactly two")
    frex = frequencies(field(FREQ, "frex"), nfrex, nsubs)
    anchors = per_participant(target_frex, nsubs, "target_frex", broadcast=not joint)
    if joint:
        scalar(component, "component", integer=True)
    components = per_participant(component, nsubs, "component", integer=True)
    if np.any(components > ncomps):
        raise ValueError("component exceeds FREQ.ts")
    levels = positive_vector(metric_levels, "metric_levels")
    idx = np.stack([nearest(frex[:, s], anchors[s] * levels) for s in range(nsubs)])
    selected = np.stack([frex[idx[s], s] for s in range(nsubs)])
    return ts, components, levels, idx, selected


def distances(states):
    squared_norm = np.sum(states ** 2, axis=1)
    return np.sqrt(np.maximum(squared_norm[:, None] + squared_norm[None, :] - 2 * (states @ states.T), 0))


def embed(signal, m, tau):
    nstates = len(signal) - (m - 1) * tau
    if nstates < 1:
        raise ValueError("Embedding leaves no states")
    return np.column_stack([signal[i * tau:i * tau + nstates] for i in range(m)])


def eligible_pairs(n, theiler_window, valid=None):
    if valid is None:
        valid = np.ones(n, bool)
    eligible = valid[:, None] & valid[None, :]
    if theiler_window > 0:
        eligible &= abs(np.arange(n)[:, None] - np.arange(n)[None, :]) > theiler_window
    if not eligible.any():
        raise ValueError("No eligible pairs remain after exclusions")
    return eligible


def fraction(value):
    value = scalar(value, "threshold")
    if value >= 1:
        raise ValueError("threshold must be strictly between zero and one")
    return value


def fixed_threshold(distance, eligible, threshold):
    values = np.sort(distance[np.triu(eligible, 1)])
    if not values.size:
        raise ValueError("No unique eligible state pairs remain")
    return values[max(0, min(len(values) - 1, int(np.ceil(threshold * len(values))) - 1))]
