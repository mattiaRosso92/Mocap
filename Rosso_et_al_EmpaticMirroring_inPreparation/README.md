# Empatic mirroring study

Study-specific workspace for the empatic mirroring application of FREQ-NESS
MoCap. Reusable toolbox functions remain in `../FREQNESS_Mocap_Toolbox` and
must not be edited for study-specific behavior.

## Study progress

| Complete | Stage | Progress and completion criterion |
|:---:|---|---|
| ☑ | Import and handle data | **Complete:** folder normalization, recursive import, frame/rate/name/marker/gap QC, explicit file- and participant-level exclusions, and the processed-MAT timing rule are implemented. |
| ☑ | Create artificial dyads | **Complete:** every eligible participant trial is paired with its condition-labelled model recording and stored as `[coordinates x time x participants]`, with synchronized bad-sample lists. |
| ◐ | Run toolbox analyses | **BLOCKS 1–6 implemented:** all per-recording analyses, streamed group summaries, and cell-averaged statistical exports preserve the complete design without duplicating the large FREQ arrays. The confirmed 1.67 Hz beat frequency is configured; production execution remains intentionally disabled until the full run is requested. |
| ☐ | Replicate with previously excluded participants | Not started. Repair excluded recordings where scientifically defensible, document every repair, rerun the identical pipeline, and compare the sensitivity results with the primary analysis. |

## Pipeline

Run `EmpaticMirroring_MainPipeline.m` from MATLAB. The implemented stages:

1. scans every QTM-exported `.mat` file without assuming a fixed variable name;
2. verifies that each file contains one numeric 3-D trajectory matrix;
3. reports and plots the distribution of frame counts;
4. flags recordings that cannot contain the requested aligned interval;
5. parses instruction, complexity, version, and movement from filenames;
6. excludes annotated or nonconforming files/folders, short recordings,
   incomplete marker layouts, and recordings with fewer than two usable
   samples while retaining them in the QC audit table;
7. prepares each model file once at 120 Hz, including its resampled
   bad-sample mask;
8. builds every artificial dyad by reusing the prepared model and aligning
   it with one participant recording;
9. saves the dyadic input and synchronized bad-sample indices required for
   covariance exclusion; and
10. when enabled, runs resumable FREQ network estimation and saves each core
    output beside its artificial-dyad input; and
11. derives per-recording network landscapes and effective dimensionality,
    then writes a lightweight experimental-design catalogue; and
12. computes per-recording spatial mirroring for each selected component,
    plus compact summaries for statistics;
13. computes phase-space RQA for temporal coordination;
14. streams individual outputs to create participant-level group means, SEM,
    and optional figures without saving dense trial-level copies; and
15. averages repetitions within participant-condition cells and exports
    long-format CSV/XLSX tables for R.

The QC stage writes `recording_exclusions.csv`, `participant_qc_summary.csv`,
`participant_exclusions.csv`, and `model_exclusions.csv` to `outputs/qc/`.
Core estimation additionally writes `core_analysis_manifest.csv` with the
output path and created, existing, or error status of every selected dyad.
Landscape analysis writes `landscape_analysis_manifest.csv` with the same
per-recording audit trail. Spatial coordination writes
`spatial_coordination_analysis_manifest.csv` with one row per recording and
component.
Phase-space RQA writes `phase_rqa_gapaware_analysis_manifest.csv`, including
valid-sample and eligible-pair coverage for every recording and component.
Every excluded recording can carry multiple standardized reasons so that,
for example, an annotation, a short duration, and an incomplete marker layout
are preserved rather than reduced to one label.

The leading trial index (1-48) records acquisition order and is retained only
for provenance. It is not an analysis factor. `mir` and `obs` encode mirror
and observe instructions; `low`, `medium`, and `high` encode music complexity;
and `mov1`/`mov2` distinguish the leg-back and jazz-like movement types.

The model performed the movement at only one physical complexity level. The
three complexity labels on model files identify music complexity overlaid
later, so complexity, version, and movement are still all used to select the
correct model stimulus when forming each artificial dyad. Instruction is not
part of that lookup because both participant instructions used the same model
stimuli.

Acquisition included a three-second participant cue/wait before the video, but
the preprocessed participant MAT exports cluster around 33.45 seconds and
almost none contain 36 seconds. The pipeline therefore treats MAT sample 1 as
video onset for both roles and uses `[0, 33)` (3960 output samples). This is an
evidence-based interpretation of the processed files, not a claim that the
original acquisition lacked the cue. Teacher recordings are resampled from
300 Hz with anti-alias filtering; participant recordings remain at 120 Hz.

Recordings must contain the full requested interval: 9900 teacher frames and
3960 participant frames. A short recording is excluded rather than padded,
stretched, or truncated to a shorter common duration. The extra one-second
filter guard is preferred but not part of the analysis interval; reflection
padding supplies it where genuine boundary context is unavailable.

Gaps of at most 50 ms were filled during the earlier QTM preprocessing. This
pipeline does not interpolate again. Remaining gaps are reported, replaced by
finite zero placeholders for storage, and listed as bad samples. The dyad's
shared `bad_segments` vector is the union of model and participant masks, so
both covariance matrices can use exactly the same valid timepoints. Historical
QTM preprocessing also trimmed small movement-dependent intervals at the
recording extremes; these are documented in the main script and require no
additional operation.

Each of the 18 condition-labelled model files is loaded, downsampled from 300
to 120 Hz, aligned, and assigned its post-resampling bad-sample mask once per
pipeline run. The prepared result is cached in memory and reused for every
matching participant; an auditable copy is saved in `outputs/preprocessed_models/`.
Artificial dyads are saved in `outputs/participants/<ID>/` using the
DyadicDance convention, with the model first and participant second. The dyad
file contains both member-specific and shared bad-sample lists. Core `FREQ`
outputs are written alongside these inputs in the same participant folder.
This dedicated results tree keeps raw QTM exports immutable and mirrors
the template pipeline's separation of raw data and generated results.

## Core FREQ-NESS analysis

BLOCK 1 mirrors `FREQNESS_DyadicDance_Mocap`: four components are retained,
the `FREQ` output contains the complete checked eigenspectrum,
frequencies are also stored normalized by `beat_frex`, existing outputs are
skipped unless `overwrite_flag` is enabled, and every result retains its
`marker_reference`, dyad metadata, sampling rate, and analysis settings.

The confirmed `beat_frex` is 1.67 Hz for both members of every artificial
dyad and applies to all trials and conditions. Following the template, `frex`
contains 32 points from beat/8 to beat×4 in beat/8 increments
(0.20875–6.68 Hz). `config.block1.run` remains `false` by default so a full
production run starts only when explicitly requested.

Generated QC tables and figures are written to `outputs/`, which is ignored by
Git. Raw `.mat`, `.qtm`, and `.avi` files are also ignored repository-wide.

## Network landscapes and effective dimensionality

BLOCK 2 mirrors the computation in the corresponding
`FREQNESS_DyadicDance_Mocap` block: it uses the complete eigenspectrum to
compute quadratic Rényi entropy (`H2`) and effective dimensionality (`ED`)
with `FREQNESS_EffectDim_Mocap`. Existing compatible per-recording landscape
files are reused unless overwriting is enabled.

GED can produce negligible negative eigenvalues through floating-point noise
even though the underlying covariance problem is non-negative. Before the
entropy calculation, BLOCK 2 clips and sum-preserving rescales only spectra
whose negative-to-positive eigenvalue mass is at most `2e-4`. The correction
count, largest corrected magnitude, and largest mass ratio are written to the
landscape manifest. Material negative spectra are rejected, and the original
BLOCK 1 `FREQ` files are never modified.

Complete eigenspectra and patterns are not copied into dense group arrays.
They remain in the individual core `FREQ` files, while the compact group file
stores `analysisRows`, the 24-cell `designTable`, participant identifiers, and
`validTrialMask`. `analysisRows` maps every result to Subject, Instruction,
Complexity, Version, Movement, and its acquisition-order TrialIndex. Repetition
indices are assigned by TrialIndex within each participant-condition cell, but
TrialIndex is not treated as a factor. This retains the DyadicDance
participant-condition-repetition semantics without hundreds of megabytes of
duplicated data or zero-valued placeholders for missing trials.

## Temporal and spatial coordination

BLOCK 3 mirrors the DyadicDance spatial-mirroring analysis. Components 1 and
2 are analyzed independently at metric levels `[0.25 0.5 1 2]` using the
original FREQ patterns. Each recording/component has one resumable output;
scalar `MIRROR` values are also assembled into compact
`[participant x condition x metric x repetition]` summaries, with missing or
failed observations represented by `NaN` and a validity mask.

JRQA is disabled because its current implementation cannot exclude the
study's gappy samples without biasing temporal recurrence estimates.

## Phase-space RQA

BLOCK 4 mirrors the DyadicDance phase-space temporal-coordination block. It
uses components 1 and 2, metric levels `[0.25 0.5 1 2]`, the proportional
interval `[0.15 0.85]`, anti-alias filtering, and a 24 Hz working rate.
Default settings standardize both dyad members, use a
maximum-distance fraction of `0.1`, and retain RR, L, DET, ENTR, TT, LAM,
Vmax, and DIV. Distance and recurrence matrices are not stored by default.
Each recording/component is independently resumable.

The shared `FREQ.bad_segments` mask is honored throughout BLOCK 4. Each
continuous valid run is zero-phase filtered independently before decimation,
so placeholder values cannot bleed across gaps. Runs shorter than the filter
minimum are added to the exclusion mask. The mask is then remapped from 120
to 24 Hz and passed in `FREQ` to the toolbox RQA function. Invalid samples do
not enter standardization, distance or threshold estimation, or recurrence
rate denominators; retained time positions break recurrence lines at gaps.
Individual outputs, compact summaries, and QC report the resulting sample and
pair coverage. Gap-aware filenames prevent reuse of earlier pilot outputs.

## Group analysis and statistical export

BLOCK 5 streams individual core and landscape files one condition at a time.
It first averages repetitions within each participant-condition cell and then
computes means and SEM across participants. Only group-level eigenspectrum,
pattern, and effective-dimensionality summaries are saved; complete trial
arrays remain in their individual files. Coordination and phase-space
summaries use the same order of averaging, and optional figures cover all 24
factorial cells. Activation-pattern figures show only components 1 and 2 at
`[0.25 0.5 1 2]` times the beat; bones are disabled so marker-wise XYZ
activation weights remain visually unobstructed.

BLOCK 6 exports one row per Participant × Instruction × Complexity ×
Version × Movement × Meter × Component. It includes spatial mirroring,
all eight phase-space RQA measures, and the number of recordings
averaged into each cell, plus phase-space valid-sample and eligible-pair
coverage. Only trials available to both spatial and temporal analyses enter a
combined row. TrialIndex is intentionally absent because it is acquisition
provenance; per-recording results remain available for audit and verification.

## Current timing check

The first full scan on 2026-09-03 found a median participant duration of about
33.46 seconds. Using MAT sample 1 as video onset retains 2203 of 2217
metadata-valid 120 Hz recordings by length; shortening the common window would
recover at most 14 additional recordings. The full 33-second window is kept.
The scan also flags four unexpected 100 Hz exports separately.

## Current participant exclusions

The 2026-09-03 audit retains 2187 participant recordings for dyad creation,
excludes 238 recordings, and excludes three of 52 participants entirely. File
counts overlap when one recording has multiple problems; the generated CSV
files are the authoritative audit trail.

| Participant | Reason for participant-level exclusion |
|---|---|
| 002 | Folder annotated “only 5”; all five recordings are excluded by the folder annotation. |
| 022 | Folder annotated “very bad quality data, disappeared hips”; all 47 recordings are excluded. |
| 046 | Folder annotated “only 28 trials”; all 28 recordings are excluded. |

The 18 model-labeled files are three exact complexity copies of six underlying
mocap trajectories. Across those six unique 33-second trajectories there are
261 distinct marker gaps: 42 are at most 50 ms and 219 exceed 50 ms. Median
gap duration is 203 ms and the longest is 1.777 s. Because every model
trajectory is affected even at a 30-second window, shortening is not a viable
remedy. These samples are retained in the audit masks but excluded from future
covariance computation; no further interpolation is performed.
