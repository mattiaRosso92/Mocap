"""Editable general MoCap pipeline, analogous to the brain Python entry script.

Run from an installed environment; set PATH_HOME to the MATLAB/Python toolbox
directory containing FREQNESS_Data. No study data or acquisition settings are
hard-coded into the reusable functions. Outputs remain in memory by default.
"""
from pathlib import Path
import numpy as np
from freqness_mocap import (
    FREQNESS_Startup_Mocap, FREQNESS_MainPipeline_Mocap, FREQNESSPipelineConfig,
)

# USER SETTINGS — the same defaults as the general MATLAB pipeline.
PATH_HOME = Path(__file__).resolve().parents[1]
CFG = FREQNESSPipelineConfig(
    frex=np.arange(1, 101) / 10,
    srate=250,
    network={"method": "ged", "kinematics": "position", "ncomps": 4},
    run_effect_dim=True,
    effect_dim={"figure": True, "plot_all": False},
    run_metric_prominence=False,
    run_visualizer=False,
    run_landscape_similarity=False,
    run_phase_rqa=False,
    run_time_coord=False,
    run_space_coord=False,
)

if __name__ == "__main__":
    # Startup: one group file or one participant file per dataset folder.
    allData, dataLabels, path_home = FREQNESS_Startup_Mocap(PATH_HOME)
    # Blocks 1–8: core, ED, prominence, visualization, similarity, RQA, space.
    RESULTS = FREQNESS_MainPipeline_Mocap(allData, CFG, dataLabels)
    import matplotlib.pyplot as plt
    plt.show()
