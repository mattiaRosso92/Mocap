# FREQ-NESS MoCap Toolbox

This directory contains reusable FREQ-NESS MoCap code. Project-specific data
loading, experimental contrasts, statistics, and manuscript figure generation
belong in the study directories at the repository root.

## Contents

- `FREQNESS_Startup_Mocap.m`: initializes the toolbox and loads datasets from
  `FREQNESS_Data`.
- `FREQNESS_MainPipeline_Mocap.m`: general block-based MATLAB workflow for the
  available participant-, visualization-, and coordination-level functions.
- `FREQNESS_InterpolateGaps_Mocap`: standalone NaN-gap reconstruction and QC
  with output directly compatible with the `bad_segments` analysis option.
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

The third-order analysis layer is specific to the MoCap framework. It operates
across corresponding participant-level FREQ-NESS outputs using separate
functions for network-landscape similarity (`FREQNESS_LandscapeSimilarity`),
phase-space temporal coordination (`FREQNESS_PhaseSpaceRQA_Mocap`), JRQA
temporal coordination (`FREQNESS_TimeCoord_Mocap`), and spatial coordination
(`FREQNESS_SpaceCoord_Mocap`). Landscape similarity correlates both a selected
component's eigenvalue trajectory and the H2 entropy landscape between
participants across all frequencies or a requested nearest-neighbor frequency
range. Phase-space RQA treats every participant's
selected network time series as one dimension of the joint group state and
therefore supports dyads and larger groups without scalar delay embedding.
Its frequency and component inputs can be scalars shared by the whole group
or participant-specific vectors; component 1 is used for all participants
when no component is supplied.

The phase-space RQA metrics are independently implemented and callable as:
`FREQNESS_RQA_RecurrenceRate_Mocap`,
`FREQNESS_RQA_MeanDiagonalLength_Mocap`,
`FREQNESS_RQA_Determinism_Mocap`, `FREQNESS_RQA_Entropy_Mocap`,
`FREQNESS_RQA_TrappingTime_Mocap`, `FREQNESS_RQA_Laminarity_Mocap`,
`FREQNESS_RQA_MaxVerticalLine_Mocap`, and
`FREQNESS_RQA_Divergence_Mocap`.

`FREQNESS_EffectDim_Mocap` is the MoCap counterpart of the MEEG
`FREQNESS_EntropyLandscape` function. It computes quadratic Rényi entropy and
effective dimensionality from the complete eigenspectrum and visualizes the
effective number of frequency-specific body networks. Its visualization uses
the same log2 frequency axis, shaded group SEM, and component palette as the
network landscape.

## Filter widths

When `fwidth` is empty, `FREQNESS_NetworkEstimation_Mocap` calls
`FREQNESS_ComputeFilterWidths_Mocap` to calculate widths from physical
frequency values rather than the number or density of requested bins. The
default logarithmic mode varies Q smoothly from 7 at the lowest frequency to
3.5 at the highest frequency in each participant's numerical range. Linear
mode uses constant Q = 5. Explicit scalar, shared vector, and participant-
specific matrix widths bypass the automatic schedule.

## Gap handling

`FREQNESS_NetworkEstimation_Mocap` automatically detects NaN gaps within the
analyzed interval and calls `FREQNESS_InterpolateGaps_Mocap`. Internal gaps up
to 50 ms are linearly interpolated by default. Longer cubic-spline
reconstruction is available through `maximum_reconstructed_gap` but must be
enabled explicitly after dataset-specific validation. Boundary and unsupported
gaps stop the analysis. A consolidated warning reports successful
reconstruction.

Reconstructed values are used only to provide continuous input for filtering.
Every affected timepoint remains in the shared `FREQ.bad_segments` vector and
is excluded from broadband and narrowband covariance matrices. Participant-
specific indices and reconstruction masks are retained in
`FREQ.bad_segments_by_participant` and `FREQ.gap_info`. Phase-space RQA honors
the shared mask. The JRQA-based `FREQNESS_TimeCoord_Mocap` explicitly rejects
gappy inputs because that implementation cannot safely exclude samples. When
raw `Patterns.markerData` containing NaNs is supplied for visualization, the
visualizer calls the same interpolation function using the reconstruction
limits retained in `FREQ.gap_info`.

`FREQNESS_Visualizer_Mocap` follows the MEEG visualizer convention of showing
the grand-average network landscape by default and accepting `plot_all=true`
for participant-level landscapes. Its MoCap-specific outputs comprise labelled
XYZ pattern matrices, globally normalized skeletal activation maps, and an
optional synchronized animation of the network backprojection and original
motion. Animation is controlled through `Patterns.animate`; marker colors
remain participant-specific, while the static outputs use the visual language
of the Dance reference study's Figure 2.

## External dependencies

- `filterFGx.m` and the included FREQ-NESS helper
  `FREQNESS_AnalyticSignal.m` are required by
  `FREQNESS_NetworkEstimation_Mocap`. The helper is the toolbox's internal
  FFT-based equivalent of `hilbert.m`, avoiding that external dependency.
- `RPparam.m` and the included minimal JRQA dependency subset from the CRP
  Toolbox are required by `FREQNESS_TimeCoord_Mocap`.
- `dl.m`, `tt.m`, and `entropy.m` from that same subset are required by
  `FREQNESS_PhaseSpaceRQA_Mocap` and its metric functions. They are
  byte-identical to the versions distributed with BROADNESS.

Place third-party functions, together with their upstream licence and
documentation, in `FREQNESS_ExternalFunctions`. FREQ-NESS-owned helpers such
as `FREQNESS_AnalyticSignal.m` belong in `FREQNESS_Functions`.
