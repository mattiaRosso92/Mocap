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
- `FREQNESS_MetricProminence_Mocap`: component prominence at every available
  or requested harmonic and subharmonic of a supplied or inferred anchor
  frequency, normalized by the nonmetric network landscape.
- `FREQNESS_Functions/Analysis`: core, second-order, and third-order analyses,
  including recurrence metrics and the temporary phase-space entry point.
  TimeCoord implementations remain internal in `Analysis/private`.
- `FREQNESS_Functions/Visualization`: `FREQNESS_Visualizer_Mocap` only.
- `FREQNESS_Functions/Supporting`: signal processing, filter widths, gap
  interpolation, JRQA parameter estimation, and surrogate helpers.
- `FREQNESS_ExampleScripts`: dataset-independent examples demonstrating the
  public toolbox workflow.
- `FREQNESS_Data`: small distributable example or reference data. Raw and
  derived study data should remain outside the repository.
- `FREQNESS_ExternalFunctions`: third-party MATLAB dependencies, accompanied
  by their source, version, and licence information when redistribution is
  permitted.
- `python`: the future Python package and its tests.

Startup adds all public function subfolders automatically; MainPipeline uses
Startup, so function calls do not change. For manual path setup, use
`addpath(genpath(fullfile(path_toolbox,'FREQNESS_Functions')))` alongside
`FREQNESS_ExternalFunctions`. Adding only the parent `FREQNESS_Functions`
folder is no longer sufficient. MATLAB's `genpath` excludes `private` folders;
do not add those folders explicitly.

The third-order analysis layer is specific to the MoCap framework. It operates
across corresponding participant-level FREQ-NESS outputs using separate
functions for network-landscape similarity (`FREQNESS_LandscapeSimilarity`),
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

`FREQNESS_SpaceCoord_Mocap` returns raw spatial correlations by default.
Use `'Fisher',true` to return `atanh(r)` in the same single output array;
`'Fisher',false` preserves raw values. Perfect correlations map to +/-Inf.

### Temporal coordination

`FREQNESS_TimeCoord_Mocap` is the single recommended entry point for both
temporal methods. Phase-space RQA is the default; JRQA is selected explicitly:

```matlab
FREQcoord = FREQNESS_TimeCoord_Mocap(FREQ,target_frex);
FREQcoord = FREQNESS_TimeCoord_Mocap(FREQ,target_frex,'standardize',true);
FREQcoord = FREQNESS_TimeCoord_Mocap(FREQ,[f1 f2], ...
    'method','jrqa','parameters',JRQA);
```

`'parameters',JRQA` is required only for JRQA. Phase-space RQA needs no
parameter structure; omit this argument and set options such as `'threshold'`
directly when needed.

The methods live in `FREQNESS_Functions/Analysis/private/compute_phase_space_rqa.m`
and `compute_joint_rqa.m`. Their existing preprocessing order, threshold
definitions, gap handling, metrics, and visualizations are preserved.
Outputs retain their existing fields and add `Method`. Phase-space outputs
also record `Standardized`; JRQA records it in `Preprocessing.Standardized`.

**Normalization is off by default**, including in `FREQNESS_JRQAParameters_Mocap`,
`FREQNESS_PreprocessTimeCoord_Mocap`, and the surrogate workflow. Use
`'standardize',true` to subtract each retained participant series' mean and
divide by its sample standard deviation. Phase-space RQA uses only valid
samples for normalization. JRQA does this after filtering, downsampling and
cropping, before embedding; its saved `Preprocessing` records the mean and SD.
The general MainPipeline shows both methods with normalization disabled.

JRQA requires a final parameter structure with scalar `m` and `tau`; tuning
is not performed automatically. Use `FREQNESS_JRQAParameters_Mocap` separately,
then select or pool estimates according to the study design. Tuning and
analysis must use matching preprocessing and normalization. New JRQA calls
default to `implementation='validated'`; legacy JRQA remains explicitly
available and retains its historical CRP normalization rules, which the
`standardize` flag does not override. It is for historical reproduction only.

The methods have distinct options: phase-space RQA supports two or more
participants, participant-specific components, marked bad samples, and
phase-space plots/animation. JRQA currently requires two participants, a
shared component, and no marked gaps. `fixed_rr` targets the group-state RP
for phase-space RQA but each participant's marginal RP for JRQA. The same
threshold value therefore does not imply the same joint RR. Phase-space
`downsample` is a sample stride only; anti-alias filtering remains upstream.
JRQA accepts `target_srate` and `lowpass_cutoff` through its preprocessing helper.

**Temporary study compatibility:** `FREQNESS_PhaseSpaceRQA_Mocap` still calls
the same private phase-space implementation. The old
`FREQNESS_TimeCoord_Mocap(FREQ,JRQA,target_frex,...)` signature still selects
JRQA, defaulting to its historical legacy implementation unless explicitly
overridden. Both are retained until study callers are migrated; neither
duplicates an algorithm. Normalization defaults to false in every call form:
reproducing previously normalized runs requires explicit `standardize=true`.

For repeated-condition JRQA, a study may pool radius estimates and pass the
same scalar `'threshold'` with `'threshold_method','radius'` to each call.
Pooling across trials or conditions belongs in the study pipeline. The
toolbox does not assume a particular experimental design. Keep normalization,
embedding, distance, and preprocessing settings consistent when pooling.

The recurrence metrics are consolidated in one function:

```matlab
RQA = FREQNESS_RQA_Mocap(recurrence_plot,2,2);
```

The optional second and third arguments are the minimum diagonal and vertical
line lengths; each defaults to 2. The single output structure contains `rr`,
`det`, `l`, `entr`, `lam`, `tt`, `vmax`, and `div`. The existing metric
definitions are preserved, with diagonal and vertical lengths extracted only
once each. This replaces the eight individual `FREQNESS_RQA_*_Mocap` metric
functions; direct callers should use the corresponding field instead.

JRQA and phase-space coordination functions keep their existing output fields
(`RR`, `DET`, etc.) and eligible-pair RR denominators. The standalone `RQA.rr`
uses all matrix entries as its denominator; callers with excluded pairs must
retain their eligible-pair denominator instead.

`FREQNESS_EffectDim_Mocap` is the MoCap counterpart of the MEEG
`FREQNESS_EntropyLandscape` function. It computes quadratic Rényi entropy and
effective dimensionality from the complete eigenspectrum and visualizes the
effective number of frequency-specific body networks. Its visualization uses
the same log2 frequency axis, shaded group SEM, and component palette as the
network landscape.

`FREQNESS_MetricProminence_Mocap` operates on the complete normalized
eigenspectrum returned by network estimation. It reports level-specific and
global metric prominence for every participant. These analysis-ready ratios
are the first fields in its deliberately minimal `METER` output, followed only
by the component, realized anchor, metric levels, and nearest frequencies
needed to interpret them. When no metric levels are requested, all integer
harmonics and reciprocal-integer subharmonics available within the analyzed
frequency range are used. The global measure always covers that complete set,
while explicitly requested levels are also excluded from the nonmetric
baseline. Component 1 is used by default. An omitted anchor is inferred
separately for each participant from the selected component's largest
eigenvalue and produces a warning because this data-driven choice is
exploratory rather than independent of the measured landscape.

## Filter widths

When `fwidth` is empty, `FREQNESS_NetworkEstimation_Mocap` calls
`FREQNESS_ComputeFilterWidths_Mocap` to calculate widths from physical
frequency values rather than the number or density of requested bins. The
default logarithmic mode varies Q smoothly from 7 at the lowest frequency to
3.5 at the highest frequency in each participant's numerical range. Linear
mode uses constant Q = 5. Explicit scalar, shared vector, and participant-
specific matrix widths bypass the automatic schedule.

Historical results can be reproduced without restoring the former automatic
default. Generate the old bin-count-dependent schedule explicitly and pass it
through `fwidth`:

```matlab
legacy_fwidth = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
    frex(:),'logarithmic');
FREQ = FREQNESS_NetworkEstimation_Mocap(data,frex,srate, ...
    'fwidth',legacy_fwidth);
```

The legacy helper exists only for reproducibility. New analyses should leave
`fwidth=[]` and use the physical schedules.

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
the shared mask. The JRQA method of `FREQNESS_TimeCoord_Mocap` explicitly rejects
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
- `RPparam.m` and `jrqa.m` from the included CRP subset are needed only for
  legacy JRQA. Parameter tuning uses `mutual.m`, `false_nearest.m`, and `pss.m`.
- `dl.m`, `tt.m`, and `entropy.m` from that same subset are required by
  `FREQNESS_RQA_Mocap`, used by phase-space RQA and validated JRQA. They are
  byte-identical to the versions distributed with BROADNESS.

Place third-party functions, together with their upstream licence and
documentation, in `FREQNESS_ExternalFunctions`. FREQ-NESS-owned helpers such
as `FREQNESS_AnalyticSignal.m` belong in `FREQNESS_Functions/Supporting`.
