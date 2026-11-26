"""FREQ-NESS MoCap: MATLAB-compatible frequency-resolved bodily networks.

Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti.
Mattia: mattia.rosso@clin.au.dk (Center for Music in the Brain, Aarhus University).
Felix: felix.bigand@iit.it (Neuroscience of Perception & Action Lab, IIT).
Leonardo: leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
(Aarhus University; Centre for Eudaimonia and Human Flourishing, Oxford).

For the foundational method cite Rosso et al. (2025), FREQ-NESS Reveals the
Dynamic Reconfiguration of Frequency-Resolved Brain Networks During Auditory
Stimulation, Advanced Science, 2413195. https://doi.org/10.1002/advs.202413195
No publication details are implied here for the in-preparation MoCap studies.
"""
from ._version import __version__
from ._utils import Struct
from .FREQNESS_NetworkEstimation_Mocap import FREQNESS_NetworkEstimation_Mocap, FREQNESSResult
from .FREQNESS_ComputeFilterWidths_Mocap import FREQNESS_ComputeFilterWidths_Mocap
from .FREQNESS_ComputeLegacyFilterWidths_Mocap import FREQNESS_ComputeLegacyFilterWidths_Mocap
from .FREQNESS_AnalyticSignal import FREQNESS_AnalyticSignal
from .FREQNESS_InterpolateGaps_Mocap import FREQNESS_InterpolateGaps_Mocap
from .FREQNESS_EffectDim_Mocap import FREQNESS_EffectDim_Mocap
from .FREQNESS_MetricProminence_Mocap import FREQNESS_MetricProminence_Mocap
from .FREQNESS_LandscapeSimilarity import FREQNESS_LandscapeSimilarity
from .FREQNESS_SpaceCoord_Mocap import FREQNESS_SpaceCoord_Mocap
from .FREQNESS_RQA_Mocap import FREQNESS_RQA_Mocap
from .FREQNESS_TimeCoord_Mocap import FREQNESS_TimeCoord_Mocap
from .FREQNESS_PreprocessTimeCoord_Mocap import FREQNESS_PreprocessTimeCoord_Mocap
from .FREQNESS_JRQAParameters_Mocap import FREQNESS_JRQAParameters_Mocap
from .FREQNESS_JRQASurrogates_Mocap import FREQNESS_JRQASurrogates_Mocap
from .filterFGx import filterFGx
from .FREQNESS_Visualizer_Mocap import FREQNESS_Visualizer_Mocap
from .FREQNESS_Startup_Mocap import FREQNESS_Startup_Mocap
from .FREQNESS_MainPipeline_Mocap import FREQNESS_MainPipeline_Mocap, FREQNESSPipelineConfig

estimate_networks = FREQNESS_NetworkEstimation_Mocap
effective_dimensionality = FREQNESS_EffectDim_Mocap
space_coordination = FREQNESS_SpaceCoord_Mocap
time_coordination = FREQNESS_TimeCoord_Mocap
visualize = FREQNESS_Visualizer_Mocap
main_pipeline = FREQNESS_MainPipeline_Mocap
