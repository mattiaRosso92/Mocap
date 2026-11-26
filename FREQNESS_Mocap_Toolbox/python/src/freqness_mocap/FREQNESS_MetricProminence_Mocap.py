"""Metric/nonmetric landscape ratios. Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
import warnings
import numpy as np
from ._utils import Struct, field, shaped, frequencies, scalar, empty, per_participant, positive_vector, nearest


def FREQNESS_MetricProminence_Mocap(FREQ, anchor_frex=None, *, component=1,
                                  metric_levels=None, global_metric_levels=None):
    """Return METER fields matching MATLAB; metric output is levels x participants.

    Global and level-wise prominence divide by the mean nonmetric eigenvalue.
    The global metric set includes requested levels, so none enter the baseline.
    """
    values = shaped(field(FREQ, "evals"), "FREQ.evals", 3)
    nvals, nfrex, nsubs = values.shape
    component = scalar(component, "component", integer=True)
    if nfrex < 2 or component > nvals or np.any(values[component - 1] < 0):
        raise ValueError("Invalid component or spectrum; at least two frequencies are required")
    if np.any(abs(values.sum(axis=0) - 100) > 1e-3):
        raise ValueError("FREQ.evals must be normalized to percentages")
    frex = frequencies(field(FREQ, "frex"), nfrex, nsubs)
    if np.any(np.diff(frex, axis=0) <= 0):
        raise ValueError("Frequency grids must be strictly increasing")
    landscape = values[component - 1]
    inferred = empty(anchor_frex)
    if inferred:
        idx_anchor = np.argmax(landscape, axis=0)
        anchors = frex[idx_anchor, np.arange(nsubs)]
        warnings.warn("Anchor inferred from the selected component's maximum", RuntimeWarning)
    else:
        anchors = per_participant(anchor_frex, nsubs, "anchor_frex")
        if np.any(anchors < frex[0]) or np.any(anchors > frex[-1]):
            raise ValueError("Anchor frequencies must lie inside each participant grid")
        idx_anchor = np.array([nearest(frex[:, s], [anchors[s]])[0] for s in range(nsubs)])
    max_sub = int(np.floor(np.min(anchors / frex.min(axis=0))))
    max_harm = int(np.floor(np.min(frex.max(axis=0) / anchors)))
    candidates = np.unique(np.r_[1 / np.arange(max_sub, 1, -1), np.arange(1, max_harm + 1)])
    mappings = np.column_stack([nearest(frex[:, s], anchors[s] * candidates) for s in range(nsubs)])
    errors = np.column_stack([abs(frex[mappings[:, s], s] - anchors[s] * candidates) / (anchors[s] * candidates) for s in range(nsubs)])
    groups = {}
    for i, row in enumerate(mappings):
        groups.setdefault(tuple(row), []).append(i)
    keep = sorted(min(indices, key=lambda i: errors[i].mean()) for indices in groups.values())
    available = candidates[keep]
    levels = available if empty(metric_levels) else np.unique(positive_vector(metric_levels, "metric_levels"))
    global_levels = available if empty(global_metric_levels) else np.unique(positive_vector(global_metric_levels, "global_metric_levels"))
    global_levels = np.union1d(global_levels, levels)
    def map_levels(levels):
        indices = np.zeros((len(levels), nsubs), int)
        actual = np.empty(indices.shape)
        for s in range(nsubs):
            targets = anchors[s] * levels
            if np.any(targets < frex[0, s]) or np.any(targets > frex[-1, s]):
                raise ValueError("Every metric frequency must lie inside each participant grid")
            indices[:, s] = nearest(frex[:, s], targets)
            if np.unique(indices[:, s]).size != len(levels):
                raise ValueError("Multiple metric levels map onto the same bin")
            actual[:, s] = frex[indices[:, s], s]
        return indices, actual
    indices, actual = map_levels(levels)
    global_indices, global_actual = map_levels(global_levels)
    if len(global_levels) >= nfrex:
        raise ValueError("At least one nonmetric frequency is required")
    baseline = np.array([landscape[np.setdiff1d(np.arange(nfrex), global_indices[:, s]), s].mean() for s in range(nsubs)])
    ratios = landscape[indices, np.arange(nsubs)] / baseline
    global_ratio = landscape[global_indices, np.arange(nsubs)].mean(axis=0) / baseline
    if np.any(baseline <= 0) or np.any(ratios <= 0) or np.any(global_ratio <= 0):
        raise ValueError("Baseline and prominence ratios must be positive")
    return Struct(GlobalProminence=global_ratio, MetricProminence=ratios, Component=component,
                  AnchorFrequency=frex[idx_anchor, np.arange(nsubs)], AnchorInferred=inferred,
                  MetricLevels=levels, MetricFrequencies=actual, GlobalMetricLevels=global_levels,
                  GlobalFrequencies=global_actual)
