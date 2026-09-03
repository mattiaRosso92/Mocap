# Empatic mirroring study

Study-specific workspace for the empatic mirroring application of FREQ-NESS
MoCap. Reusable toolbox functions remain in `../FREQNESS_Mocap_Toolbox` and
must not be edited for study-specific behavior.

## Study progress

| Complete | Stage | Progress and completion criterion |
|:---:|---|---|
| ☐ | Import and handle data | **In progress:** recursive import, frame/rate/name/gap QC, file-level exclusions, and recorded reasons are implemented. Complete after resolving the participant 3-second offset and model-gap policy, then exporting the final participant-level exclusion list with reasons. |
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

Alignment uses the common acquisition trigger as sample zero. Teacher data use
seconds `[0, 33)`, participant data use seconds `[3, 36)` to remove the cue and
waiting period, and the common output rate is 120 Hz (3960 samples). Teacher
recordings are resampled from 300 Hz with anti-alias filtering; participant
recordings remain at 120 Hz.

Recordings must contain the full requested interval: 9900 teacher frames and
4320 participant frames. A short recording is excluded rather than padded,
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
33.46 seconds. Under the stated `trigger + 3 s` participant offset, only 3 of
2419 supported participant files contain the complete 33-second analysis
window. This strongly suggests that the converted MAT files may already begin
near teacher-video onset rather than at the beginning of the cue/wait period.
Batch alignment remains intentionally disabled until this acquisition detail
is confirmed. The scan also flags four unexpected 100 Hz exports separately.
