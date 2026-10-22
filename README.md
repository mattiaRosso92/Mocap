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
  FREQNESS_Startup_Mocap.m     Toolbox initialization and dataset loading
  FREQNESS_MainPipeline_Mocap.m General block-based MATLAB workflow
  FREQNESS_Functions/          Reusable MATLAB toolbox functions
    Analysis/                 Network and coordination analyses
      private/                Internal temporal-coordination implementations
    Visualization/            Visualizer only
    Supporting/               Signal-processing and analysis helpers
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
2. `FREQNESS_EffectDim_Mocap` and `FREQNESS_Visualizer_Mocap` provide
   second-order characterization of the effective dimensionality, estimated
   network landscape, and bodily activation patterns.
3. `FREQNESS_TimeCoord_Mocap` and `FREQNESS_SpaceCoord_Mocap` provide
   third-order temporal and spatial coordination analyses. TimeCoord defaults
   to phase-space RQA on non-standardized time series; JRQA is selected with
   `'method','jrqa'`. Normalization is optional through `'standardize',true`.
   JRQA supports a validated route
   with explicit anti-alias filtering, delay-embedding, recurrence threshold,
   Theiler exclusion, and complete provenance, while its former behavior is
   retained through an explicit legacy-compatible option.

## Reference test case

`Rosso_et_al_Dance_inPreparation` is the current priority and the first
reference application of the toolbox. It is based on the openly available
dyadic dance dataset introduced by Bigand et al. (2024).

The remaining study directories are retained as separate work areas so their
pipelines, outputs, and statistical analyses do not become part of the reusable
toolbox API.
