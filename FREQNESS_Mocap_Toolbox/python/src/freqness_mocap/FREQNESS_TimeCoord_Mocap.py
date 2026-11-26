"""Temporal coordination. Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
from ._utils import choice, empty
from ._phase_space_rqa import compute_phase_space_rqa
from ._joint_rqa import compute_joint_rqa


def FREQNESS_TimeCoord_Mocap(FREQ, target_frex, *, method="phase_space", parameters=None, **kwargs):
    """One interface for group-state phase-space RQA (default) and corrected JRQA.

    Both default to non-standardized signals. Common options: component=1,
    metric_levels=1, duration=None, standardize=False, theiler_window=0,
    lmin=vmin=2, store_matrices=False, srate=None.

    Phase space: scalar or participant-wise anchors/components; threshold=.1,
    threshold_method='max_fraction' or 'fixed_rr'; downsample=1 (stride only,
    NOT anti-alias filtering), bad_segments=None, figure=False, animate=False,
    animation_pause=.01. No parameters structure is used. Static/animated 2-D
    and 3-D phase spaces are time-coloured trajectories, broken at excluded rows.

    JRQA: exactly two anchors, scalar component, final parameters.m/tau;
    threshold_method='radius' (default), 'adaptive_max_radius', or 'fixed_rr';
    threshold=None uses parameters.ps or parameters.RadiusFraction. Optional
    target_srate, lowpass_cutoff, filter_order=4 are passed to preprocessing.
    Fixed RR targets the GROUP RP in phase space, MARGINAL RPs in JRQA.

    Return a list-like record per metric level, retaining MATLAB field names.
    Figure handles are attached as output.figures. No study-level pooling or
    old JRQA signature/implementation is accepted. Unknown options raise errors.
    """
    method = choice(method, ("phase_space", "jrqa"), "method")
    if method == "phase_space":
        if not empty(parameters):
            raise ValueError("parameters is only valid for method='jrqa'")
        return compute_phase_space_rqa(FREQ, target_frex, **kwargs)
    if parameters is None:
        raise ValueError("JRQA requires parameters with final scalar m and tau")
    return compute_joint_rqa(FREQ, target_frex, parameters, **kwargs)
