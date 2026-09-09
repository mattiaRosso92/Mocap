# Empatic mirroring study

Study-specific FREQ-NESS MoCap pipeline for artificial model-participant
dyads. The main script is intentionally chronological and keeps the scientific
settings, import, QC, alignment, analysis, output routing, and plotting visible
in one place. Only general-purpose `FREQNESS_*` operations are delegated to the
MoCap toolbox; there is no study-specific helper layer.

## Progress

| Complete | Milestone | Current state |
|:---:|---|---|
| ☑ | Import and handle data | Recursive import, frame/rate/name/marker/gap QC, explicit exclusions, and auditable reports. |
| ☑ | Create artificial dyads | Every objectively usable participant trial is paired with its matching teacher stimulus in `[coordinates x time x members]` format. |
| ☑ | Run toolbox analyses | Core FREQ-NESS, role-specific landscapes/ED, interaction analyses, group summaries, and figures. |
| ☑ | Recover annotated participants | Folder annotations are audited rather than treated as automatic exclusions; all objective data-quality rules remain active. |
| ☑ | Statistical modelling | R-ready exports, mixed-effects models, diagnostics, contrasts, and multiplicity correction. |

## Running the pipeline

Open and run `EmpaticMirroring_MainPipeline.m` in MATLAB. By default all six
numbered blocks run in order and compatible outputs are reused. Set the
environment variable `EMPATIC_MIRRORING_OVERWRITE=1` only for a deliberate
full rebuild.

`filter_width_calibration='physical'` is the default for new analyses. Setting
it to `'legacy'` reconstructs the former bin-count-dependent logarithmic or
linear schedule and passes the resulting 31-by-2 width matrix explicitly to
the toolbox. Physical and legacy runs use separate output subdirectories, and
saved core outputs are reused only when their realized `FREQ.fwhm` and
calibration provenance match the current settings.

Setup, data QC, and artificial-dyad creation are unnumbered preparation
sections. The numbered analysis blocks are:

1. **Core network estimation** - `FREQNESS_NetworkEstimation_Mocap` at the
   confirmed 1.67 Hz beat, using 31 frequencies from beat/4 to beat x 4 and
   retaining four components plus the complete eigenspectrum.
2. **Role-specific network structure** - separate teacher and participant
   network landscapes and effective dimensionality.
3. **Interaction analyses**, always in this order:
   1. gap-aware phase-space RQA for temporal coordination;
   2. spatial coordination;
   3. component and entropy network-landscape similarity.
4. **Group summaries and figures** - repetitions are averaged within each
   participant-condition cell before group means and SEM are calculated.
5. **R-ready exports** - meter-resolved coordination/RQA and meter-independent
   landscape-similarity tables.
6. **Mixed-effects modelling in R** - factorial models, diagnostics, simple
   effects, and corrected omnibus tables.

A final unnumbered validation section can compare every numerical summary and
statistical export with a supplied reference run.

## Experimental design and alignment

Participant filenames encode Instruction (`mir`, `obs`), Complexity (`low`,
`medium`, `high`), Version (`v1`, `v2`), and Movement (`mov1`, `mov2`). The
leading 1-48 acquisition index is retained only as trial provenance.

The model performed one physical complexity level. Its low/medium/high labels
refer to the subsequently overlaid music, so Complexity, Version, and Movement
still select the matching model stimulus. Instruction does not enter the model
lookup because both participant instructions used the same video.

The common trigger supplies the shared time origin. Although acquisition
included a three-second participant cue/wait, the preprocessed participant MAT
files cluster around 33.45 seconds and generally do not contain 36 seconds.
The pipeline therefore interprets MAT sample 1 as video onset and retains the
same `[0, 33 s)` interval for both roles: 3,960 samples at 120 Hz. Teacher data
are resampled once from 300 to 120 Hz with anti-alias filtering and then reused
for every matching participant. A recording that cannot provide the complete
33-second interval is excluded; no recording is stretched or padded to create
missing duration.

## Gap and marker policy

Every recording is reordered to the same canonical 22-marker skeleton. The
toolbox function `FREQNESS_InterpolateGaps_Mocap` owns all gap reconstruction:

- gaps up to 50 ms use linear interpolation;
- supported longer gaps up to 2 seconds use cubic splines;
- real samples immediately outside the analysis interval may provide
  interpolation context;
- this study opts into nearest-observation filling only where a supported gap
  touches an analysis boundary and two-sided interpolation is impossible.

The toolbox default still rejects boundary gaps. The opt-in boundary values
exist solely to make resampling and filtering finite. Observed coordinate
values are never overwritten. Every originally missing sample, including every
boundary-filled sample, remains in member-specific `bad_segments` and in the
dyad union, so it is excluded from covariance estimation, gap-aware RQA, and
all downstream time-resolved computations. Recordings with gaps beyond the
two-second ceiling, invalid marker layouts, insufficient complete-marker
coverage, unexpected sampling rates, or inadequate duration remain excluded.

The same 22-marker bone matrix is used for model and participant visualization.
No marker is silently dropped to make a recording pass QC.

Historical QTM preprocessing had already filled gaps no longer than 50 ms and
trimmed small movement-specific intervals at the recording extremes. The
pipeline documents this acquisition history but does not apply those trims a
second time.

## Output layout

Generated data remain below calibration-specific folders in the ignored
`outputs/` tree:

```text
outputs/
`-- <physical|legacy>_<logarithmic|linear>/
    |-- qc/
    |-- preprocessed_models/
    |-- participants/<ID>/
    |-- 02_Landscape/
    |-- 03_Interaction/
    |   |-- 01_PhaseSpaceRQA/
    |   `-- 02_SpatialAndLandscape/
    |-- 04_Group/
    |-- 05_Statistics_R/
    |-- 06_Statistics_Results/
    `-- 09_CleanupValidation/
```

Artificial dyads and core `FREQ` outputs are stored beside one another in each
participant folder. Dense trial results remain per recording; compact group
files contain only the summaries needed downstream. Raw `.mat`, `.qtm`, and
`.avi` files and all generated outputs are ignored by Git.

Unversioned files produced by the historical pipeline remain directly below
`outputs/`. They are retained as reference results but are never inherited by
new calibration-aware runs.

The main exports are:

- `OUT2R_AllComponents.csv`: Participant x factorial cell x Meter x Component,
  containing spatial coordination and eight RQA measures with coverage QC;
- `OUT2R_LandscapeSimilarity.csv`: Participant x factorial cell x Component,
  containing selected-component and H2-entropy landscape correlations.

Landscape correlations are Fisher-z transformed only for statistical
modelling; exported values remain correlations on their original scale.

## Validated full run

The 2026-09-08 production workflow scanned 2,425 participant recordings and 18
teacher files. After auditing the three annotated participant folders, 1,951
recordings from all 52 participants passed every objective rule and completed
all six blocks. The final exports contain 8,864 meter-resolved rows and 2,216
landscape-similarity rows.

The single-script rewrite was checked against the latest pre-refactor run.
Both components' RQA metrics and coverage, spatial coordination, both landscape
similarities, role-specific group network summaries, and all four statistical
exports were exactly identical: all 47 parity checks passed with a maximum
absolute difference of zero.
