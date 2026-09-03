# Empatic mirroring study

Study-specific workspace for the empatic mirroring application of FREQ-NESS
MoCap. Reusable toolbox functions remain in `../FREQNESS_Mocap_Toolbox` and
must not be edited for study-specific behavior.

## Study progress

| Complete | Stage | Progress and completion criterion |
|:---:|---|---|
| ☑ | Import and handle data | **Complete:** folder normalization, recursive import, retained-window frame/rate/name/gap QC, file-level exclusion reasons, and participant/model exclusion reports are implemented. The processed MAT timing rule is documented below. |
| ☐ | Create artificial dyads | **In progress:** participant-to-model pairing manifest is implemented using complexity, version, and movement. Complete after eligible recordings can be aligned and exported as dyads. |
| ☐ | Run toolbox analyses | Not started. Complete after the finalized dyads have passed input validation and the planned FREQ-NESS MoCap analyses have run successfully. |
| ☐ | Replicate with previously excluded participants | Not started. Repair excluded recordings where scientifically defensible, document every repair, rerun the identical pipeline, and compare the sensitivity results with the primary analysis. |

## Pipeline

Run `EmpaticMirroring_MainPipeline.m` from MATLAB. The current first stage:

1. scans every QTM-exported `.mat` file without assuming a fixed variable name;
2. verifies that each file contains one numeric 3-D trajectory matrix;
3. reports and plots the distribution of frame counts;
4. flags recordings that cannot contain the requested aligned interval;
5. parses instruction, complexity, version, and movement from filenames;
6. excludes annotated or nonconforming files/folders from analysis while
   retaining them in the QC audit table; and
7. builds a manifest pairing every eligible participant trial with its
   corresponding model clip.

The QC stage writes `recording_exclusions.csv`, `participant_qc_summary.csv`,
`participant_exclusions.csv`, and `model_exclusions.csv` to `outputs/qc/`.
Every recording can carry multiple standardized exclusion reasons so that,
for example, an annotation, a short duration, and remaining gaps are all
preserved rather than reduced to one label.

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
pipeline does not interpolate again: it reports any remaining gaps (including
their number and maximum duration) and excludes affected recordings before
FREQ-NESS. Historical QTM preprocessing also trimmed small movement-dependent
intervals at the recording extremes; these are documented in the main script
and require no additional operation.

Generated QC tables and figures are written to `outputs/`, which is ignored by
Git. Raw `.mat`, `.qtm`, and `.avi` files are also ignored repository-wide.

## Current timing check

The first full scan on 2026-09-03 found a median participant duration of about
33.46 seconds. Using MAT sample 1 as video onset retains 2203 of 2217
metadata-valid 120 Hz recordings by length; shortening the common window would
recover at most 14 additional recordings. The full 33-second window is kept.
The scan also flags four unexpected 100 Hz exports separately.

## Current participant exclusions

The 2026-09-03 audit retains 680 participant recordings and excludes six
participants entirely. File counts below overlap when a recording has more
than one problem; the generated CSV files are the authoritative audit trail.

| Participant | Reason for participant-level exclusion |
|---|---|
| 002 | Folder annotated “only 5”; five recordings present and none survive gap QC. |
| 022 | Folder annotated “very bad quality data, disappeared hips”; none of 47 recordings survive QC. |
| 025 | No recording survives QC; 22 filenames are annotated and 43 recordings contain retained-window gaps. |
| 036 | No recording survives QC; 12 filenames are annotated, 47 recordings contain gaps, and one is too short. |
| 046 | Folder annotated “only 28 trials”; none of the 28 recordings survive QC. |
| 052 | All 48 recordings contain retained-window gaps. |

The 18 model-labeled files are three exact complexity copies of six underlying
mocap trajectories. Across those six unique 33-second trajectories there are
261 distinct marker gaps: 42 are at most 50 ms and 219 exceed 50 ms. Median
gap duration is 203 ms and the longest is 1.777 s. Because every model
trajectory is affected even at a 30-second window, shortening is not a viable
remedy; the model data must be repaired upstream before artificial dyads can
be materialized.
