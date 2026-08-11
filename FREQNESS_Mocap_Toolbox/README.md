# FREQ-NESS MoCap Toolbox

This directory contains reusable FREQ-NESS MoCap code. Project-specific data
loading, experimental contrasts, statistics, and manuscript figure generation
belong in the study directories at the repository root.

## Contents

- `FREQNESS_Startup_Mocap.m`: initializes the toolbox and loads datasets from
  `FREQNESS_Data`.
- `FREQNESS_MainPipeline_Mocap.m`: general block-based MATLAB workflow for the
  available participant-, visualization-, and group-level functions.
- `FREQNESS_Functions`: MATLAB implementations of the core, second-order, and
  third-order analyses.
- `FREQNESS_ExampleScripts`: dataset-independent examples demonstrating the
  public toolbox workflow.
- `FREQNESS_Data`: small distributable example or reference data. Raw and
  derived study data should remain outside the repository.
- `FREQNESS_ExternalFunctions`: third-party MATLAB dependencies, accompanied
  by their source, version, and licence information when redistribution is
  permitted.
- `python`: the future Python package and its tests.

The third-order analysis layer is specific to the MoCap framework: it operates
across corresponding participant-level FREQ-NESS outputs to characterize
interaction within dyads or larger groups.

## External dependencies

- `filterFGx.m` and its FREQ-NESS helper `FREQNESS_AnalyticSignal.m` are
  required by `FREQNESS_NetworkEstimation_Mocap`.
- `RPparam.m` and `jrqa.m` from the CRP Toolbox are required by
  `FREQNESS_GroupAnalyses_Mocap`.

Place third-party functions, together with their upstream licence and
documentation, in `FREQNESS_ExternalFunctions`. `FREQNESS_AnalyticSignal.m`
may instead remain in `FREQNESS_Functions` because it is a FREQ-NESS helper.
