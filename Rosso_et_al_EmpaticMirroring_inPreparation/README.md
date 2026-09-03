# Empatic mirroring study

Study-specific workspace for the empatic mirroring application of FREQ-NESS
MoCap. Reusable toolbox functions remain in `../FREQNESS_Mocap_Toolbox` and
must not be edited for study-specific behavior.

## Pipeline

Run `EmpaticMirroring_MainPipeline.m` from MATLAB. The current first stage:

1. scans every QTM-exported `.mat` file without assuming a fixed variable name;
2. verifies that each file contains one numeric 3-D trajectory matrix;
3. reports and plots the distribution of frame counts;
4. flags recordings that cannot contain the requested aligned interval;
5. parses condition, intensity, version, and movement from filenames; and
6. builds a manifest pairing every participant trial with its teacher clip.

Alignment uses the common acquisition trigger as sample zero. Teacher data use
seconds `[0, 33)`, participant data use seconds `[3, 36)` to remove the cue and
waiting period, and the common output rate is 120 Hz (3960 samples). Teacher
recordings are resampled from 300 Hz with anti-alias filtering; participant
recordings remain at 120 Hz.

Generated QC tables and figures are written to `outputs/`, which is ignored by
Git. Raw `.mat` and `.qtm` files are also ignored repository-wide.

## Current timing check

The first full scan on 2026-09-03 found a median participant duration of about
33.46 seconds. Under the stated `trigger + 3 s` participant offset, only 3 of
2419 supported participant files contain the complete 33-second analysis
window. This strongly suggests that the converted MAT files may already begin
near teacher-video onset rather than at the beginning of the cue/wait period.
Batch alignment remains intentionally disabled until this acquisition detail
is confirmed. The scan also flags four unexpected 100 Hz exports separately.
