"""General eight-block MoCap workflow, not a translation of any study pipeline."""
from dataclasses import dataclass, field as config_field
import numpy as np
from ._utils import Struct
from .FREQNESS_NetworkEstimation_Mocap import FREQNESS_NetworkEstimation_Mocap
from .FREQNESS_EffectDim_Mocap import FREQNESS_EffectDim_Mocap
from .FREQNESS_MetricProminence_Mocap import FREQNESS_MetricProminence_Mocap
from .FREQNESS_Visualizer_Mocap import FREQNESS_Visualizer_Mocap
from .FREQNESS_LandscapeSimilarity import FREQNESS_LandscapeSimilarity
from .FREQNESS_TimeCoord_Mocap import FREQNESS_TimeCoord_Mocap
from .FREQNESS_JRQASurrogates_Mocap import FREQNESS_JRQASurrogates_Mocap
from .FREQNESS_SpaceCoord_Mocap import FREQNESS_SpaceCoord_Mocap


@dataclass
class FREQNESSPipelineConfig:
    """General MATLAB pipeline defaults; scientific function options stay visible.

    Each options dictionary is passed directly to the corresponding function.
    per_dataset_frex/targets/anchors override shared inputs explicitly, avoiding
    ambiguity between participant-wise frequency matrices and dataset lists.
    """
    frex: object = config_field(default_factory=lambda: np.arange(1,101)/10)
    srate: float = 250
    network: dict = config_field(default_factory=lambda: {"ncomps":4})
    run_effect_dim: bool = True
    run_metric_prominence: bool = False
    run_visualizer: bool = False
    run_landscape_similarity: bool = False
    run_phase_rqa: bool = False
    run_time_coord: bool = False
    run_space_coord: bool = False
    effect_dim: dict = config_field(default_factory=lambda: {"figure":True,"plot_all":False})
    metric_anchor_frex: object = None
    metric_prominence: dict = config_field(default_factory=dict)
    Landscape: object = None
    Patterns: object = None
    visualizer: dict = config_field(default_factory=dict)
    landscape_similarity: dict = config_field(default_factory=dict)
    target_frex: object = None
    phase_rqa: dict = config_field(default_factory=lambda: {"metric_levels":[.25,.5,1,2],"duration":[.15,.85]})
    JRQA: object = None
    time_coord: dict = config_field(default_factory=lambda: {"metric_levels":[.25,.5,1,2],"duration":[.15,.85]})
    n_surrogates: int = 0
    surrogates: dict = config_field(default_factory=dict)
    space_coord: dict = config_field(default_factory=lambda: {"metric_levels":[.25,.5,1,2]})
    per_dataset_frex: object = None
    per_dataset_targets: object = None
    per_dataset_anchors: object = None


def FREQNESS_MainPipeline_Mocap(allData, CFG=None, dataLabels=None):
    """Run enabled blocks, returning one named result per dataset, without saving.

    Nothing is written or overwritten. Network estimation always runs, matching
    MATLAB. JRQA parameters must be selected explicitly; no automatic pooling.
    Participant-specific frequency grids are not silently relabelled for plots
    or landscape similarity. Supply an already aligned plotting grid separately
    when using those functions directly.
    """
    CFG = FREQNESSPipelineConfig() if CFG is None else CFG
    if not isinstance(CFG,FREQNESSPipelineConfig):
        raise TypeError("CFG must be FREQNESSPipelineConfig")
    if isinstance(allData,np.ndarray):
        allData = [allData]
    labels = [f"Dataset #{i+1}" for i in range(len(allData))] if dataLabels is None else list(dataLabels)
    if len(labels)!=len(allData):
        raise ValueError("dataLabels must match allData")
    for values in (CFG.per_dataset_frex,CFG.per_dataset_targets,CFG.per_dataset_anchors):
        if values is not None and len(values)!=len(allData):
            raise ValueError("Per-dataset settings must match allData")
    output = []
    for datai,data in enumerate(allData):
        if data is None or not np.size(data):
            output.append(None)
            continue
        frex = CFG.frex if CFG.per_dataset_frex is None else CFG.per_dataset_frex[datai]
        target = CFG.target_frex if CFG.per_dataset_targets is None else CFG.per_dataset_targets[datai]
        anchor = CFG.metric_anchor_frex if CFG.per_dataset_anchors is None else CFG.per_dataset_anchors[datai]
        result = Struct(Label=labels[datai],FREQ=None,H2=None,ED=None,METER=None,figures=None,
                        LandscapeSimilarity=None,PhaseSpaceRQA=None,JRQA=None,Surrogates=None,SpaceCoord=None)
        # BLOCK 1 — core network estimation (all eigenvalues retained).
        result.FREQ = FREQNESS_NetworkEstimation_Mocap(data,frex,CFG.srate,**CFG.network)
        # BLOCK 2 — effective dimensionality.
        if CFG.run_effect_dim:
            result.H2,result.ED = FREQNESS_EffectDim_Mocap(result.FREQ,**CFG.effect_dim)
        # BLOCK 3 — metric prominence.
        if CFG.run_metric_prominence:
            result.METER = FREQNESS_MetricProminence_Mocap(result.FREQ,anchor,**CFG.metric_prominence)
        # BLOCK 4 — visualization; user supplies acquisition-specific markers.
        if CFG.run_visualizer:
            landscape = CFG.Landscape if CFG.Landscape is not None else Struct(frex=result.FREQ.frex,ncomps=min(10,result.FREQ.evals.shape[0]))
            result.figures = FREQNESS_Visualizer_Mocap(result.FREQ,landscape,CFG.Patterns,**CFG.visualizer)
        # BLOCK 5 — landscape similarity (requires a shared frequency grid).
        if CFG.run_landscape_similarity:
            result.LandscapeSimilarity = FREQNESS_LandscapeSimilarity(result.FREQ,**CFG.landscape_similarity)
        # BLOCK 6 — group-state phase-space RQA, no implicit low-pass filtering.
        if CFG.run_phase_rqa:
            options = {"srate":CFG.srate,**CFG.phase_rqa}
            result.PhaseSpaceRQA = FREQNESS_TimeCoord_Mocap(result.FREQ,target,method="phase_space",**options)
        # BLOCK 7 — corrected JRQA and optional circular-shift null.
        if CFG.run_time_coord:
            options = {"srate":CFG.srate,**CFG.time_coord}
            if CFG.n_surrogates:
                result.JRQA,result.Surrogates = FREQNESS_JRQASurrogates_Mocap(result.FREQ,CFG.JRQA,target,
                    n_surrogates=CFG.n_surrogates,**CFG.surrogates,**options)
            else:
                result.JRQA = FREQNESS_TimeCoord_Mocap(result.FREQ,target,method="jrqa",parameters=CFG.JRQA,**options)
        # BLOCK 8 — spatial pattern-magnitude coordination.
        if CFG.run_space_coord:
            result.SpaceCoord = FREQNESS_SpaceCoord_Mocap(result.FREQ,target,**CFG.space_coord)
        output.append(result)
    return output
