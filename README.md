# FREQ-NESS MoCap

Private development repository for the motion-capture extension of FREQ-NESS.
The repository is not yet intended for public release.

FREQ-NESS MoCap applies frequency-resolved network estimation to multivariate
full-body kinematics. It is designed to support analysis of single participants
and interaction analyses involving dyads and, in future developments, larger
groups.

## Repository structure

```text
FREQNESS_Mocap_Toolbox/
  FREQNESS_Functions/          Reusable MATLAB toolbox functions
  FREQNESS_ExampleScripts/     Dataset-independent usage examples
  FREQNESS_Data/               Small example or reference data only
  FREQNESS_ExternalFunctions/  Documented third-party MATLAB dependencies
  python/                      Future Python implementation and tests

Rosso_et_al_Dance_inPreparation/
Rosso_et_al_EmpaticMirroring_inPreparation/
Rosso_et_al_Orchestra_inPreparation/
                               Study-specific pipelines and analyses
```

This mirrors the public MEEG FREQ-NESS repository by separating reusable
toolbox code from study-specific analysis code. Study folders may depend on the
toolbox, but reusable toolbox code should not depend on a particular study.

## Analysis levels

The MATLAB toolbox currently contains three levels of analysis:

1. `FREQNESS_NetworkEstimation_Mocap` performs the core participant-level
   frequency-resolved decomposition.
2. `FREQNESS_Visualizer_Mocap` provides second-order visualization of the
   estimated network landscape and bodily activation patterns.
3. `FREQNESS_GroupAnalyses_Mocap` provides third-order interaction analyses
   across multiple participants.

## Reference test case

`Rosso_et_al_Dance_inPreparation` is the current priority and the first
reference application of the toolbox. It is based on the openly available
dyadic dance dataset introduced by Bigand et al. (2024).

The remaining study directories are retained as separate work areas so their
pipelines, outputs, and statistical analyses do not become part of the reusable
toolbox API.
