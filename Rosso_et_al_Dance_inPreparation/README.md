# Dyadic dance study

Priority study and first reference test case for FREQ-NESS MoCap. Keep
study-specific preprocessing, orchestration, statistical analysis, and figure
generation in this directory; reusable functionality belongs in
`FREQNESS_Mocap_Toolbox`.

The Dance pipeline retains the historical JRQA outputs and the separate
participant-dimensional phase-space RQA implementation. Corrected JRQA is run
by `FREQNESS_DyadicDance_JRQA_Validation.m`, which consumes the completed core
outputs without modifying them or either earlier temporal analysis.

## Recovered-dyad Dance pipeline

The main Dance script includes all 35 dyads. It preserves dyad 13's recorded
condition labels (7/8/9/8 trials) and excludes only dyad 32's original trial 32,
whose two participant files contain no recorded coordinates. After the existing
last-marker removal, the other 63 recordings from these dyads have complete
coordinates and matching 15,000-sample participant lengths. No gap reconstruction
or condition relabelling is needed for those recordings.

`CFG.common.excluded_trials` uses original recording IDs. The shared
`trial_indices` and `trial_counts` determine the loops in all blocks. Unused
array slots are NaN; trial averages omit these slots, retaining the dyad as the
statistical unit. Original trial IDs remain saved with core outputs. Recovered
analyses use a separate `<filter tag>_recovered_dyads` results folder, preserving
earlier group summaries. Run Block 0 before resuming a later block.

`CFG.block6.standardize` retains the existing true default; false selects
non-standardised phase-space RQA and separate numerical/statistical output
folders. The radius remains 10% of maximum phase-space distance. These changes
do not alter toolbox functions or the separate validated-JRQA script.

## Metric prominence (BLOCK 4)

The main pipeline now runs coordination in Block 3, metric prominence in
Block 4, landscape similarity in Block 5, phase-space RQA in Block 6,
group visualization in Block 7, and statistical exports in Block 8.
Existing output folder names are preserved
to avoid invalidating completed analyses; prominence uses `04_MetricProminence`.
Run Block 0, then Block 4 independently. Component 1 is independently configurable
in `CFG.block4`. `reuse_core_path` optionally points to a scientifically matching
completed core folder; only missing core files are taken from it. Do not use
outputs from another filter calibration or frequency grid.

`FREQNESS_MetricProminence_Mocap` uses each participant's song beat as anchor,
returns beat/4, beat/2, beat and 2xbeat, and preserves its default Global metric
set (all available harmonics/subharmonics). All ratios share the nonmetric
baseline. On the Dance grid the automatic Global set is beat/8, beat/4,
beat/3, beat/2, beat, 2x, 3x and 4xbeat; beat/3 uses the nearest 3/8xbeat bin.
The four requested meter frequencies are represented exactly.
Participant ratios are averaged within each trial, then trials are
averaged within dyad/condition. This is individual prominence averaged within
dyad, not a coupling measure. Individual outputs and realized frequencies are
retained in each trial file, with a compact summary and independent CSV export.

Run `Rscript Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_MetricProminence_Stats.R`
from the repository, or pass an input CSV and new output directory as arguments.
It fits five log-ratio Visual x Music models with a random dyad intercept,
uses Holm correction across all five outcomes separately for each effect,
and saves exactly five original-scale condition plots plus model tables and
residual diagnostics. Existing R output directories are never overwritten.

## Landscape similarity (BLOCK 5)

Run Block 0 then Block 5 independently. `CFG.block5` selects Component 1
by default, output/overwrite settings and an optional matching `reuse_core_path`.
The existing `FREQNESS_LandscapeSimilarity` function correlates the partners'
component eigenvalue landscapes and their full-eigenspectrum H2 entropy
landscapes. It does not correlate effective dimensionality.

Partners hearing different songs have different frequencies in Hz. The study
therefore passes unchanged eigenvalues with a verified shared beat-relative
axis (1/8 to 4xbeat): corresponding beat multiples, not absolute Hz, are aligned.
No interpolation or core re-estimation occurs. Trial files retain the selected
axis, original recording ID, settings and core source path. Outputs live in
`05_LandscapeSimilarity/Component_1`, independently of earlier analyses.

Signed trial correlations are Fisher-transformed before averaging within
dyad/condition; undefined or perfect correlations stop the export for inspection.
`FREQNESS_Mocap_LandscapeSimilarity_Stats.R` fits two Visual x Music models on
these z averages with a random dyad intercept, applies Holm correction across
the two outcomes separately for each effect, and produces two condition plots.
Plot centres and SEM bounds are calculated on z and back-transformed to r.
Run with Rscript, optionally supplying an input CSV and a new output directory.
Existing R output directories are not overwritten.

## Validated JRQA reanalysis

The validation workflow applies the manuscript's physical 10 Hz anti-alias
filter at the original 250 Hz sampling rate before downsampling to 25 Hz. It
estimates delay from the first local minimum of mutual information, selects
the first embedding dimension meeting the false-nearest-neighbour criterion,
and derives component-specific global parameters from the central 15--85% of
each trial.

The primary specification is `FixedDyadRadius`, under
`03_Coordination_JRQA_Validated`. It uses one component-level embedding and
one radius per dyad/component, pooled without condition labels as the median
across all trials, conditions, and metric levels. The candidate trial radii
come from `FaithfulAdaptiveMax`: 10% of each standardized participant's maximum
Euclidean distance in the final embedding, followed by the partner maximum.
`CFG.standardize` controls normalization inside the toolbox in both tuning
and analysis. `FaithfulAdaptiveMax` remains the adaptive sensitivity analysis.

Earlier `CorrectedManuscript` and fixed-5%-marginal-RR `Robustness` results
remain available for comparison. The former pooled radii estimated with
individual embeddings and should not be treated as the primary result.
Completed summaries are skipped when `CFG.overwrite_flag=false`. Trial-level
outputs, component summaries, parameter provenance, and R-ready workbooks
have separate specification folders. Core estimates are reused unchanged.

Block 5 additionally runs a reproducible circular-shift control on a
predefined stratified subset. It preserves each partner's recurrence geometry
while disrupting between-participant temporal alignment, and saves observed,
null, empirical-p, and standardized RR/DET results under
`03_Coordination_JRQA_Validated/SurrogateValidation/FixedDyadRadius`.
Observed and surrogate matrices use the same fixed dyad radius and embedding.
The default control covers five dyads, one trial per condition, and 100 shifts
per metric level. This is a sensitivity check rather than full-sample inference.

## Filter-width calibration

GED analyses use `CFG.common.filter_width_calibration='legacy'` by default so
study reruns preserve the historical filtering. The pipeline computes the
former explicit 32-by-2 FWHM matrix after the two participant-specific beat
grids have been constructed and passes it to
`FREQNESS_NetworkEstimation_Mocap`. Select `'physical'` for a new analysis
using the toolbox's frequency-calibrated widths.

Every calibration and filter combination has a separate results subdirectory:

```text
Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/
`-- <physical|legacy>_<logarithmic|linear>_recovered_dyads/
    |-- 01_Core/
    |-- 02_Landscape/
    |-- 03_Coordination/
    |-- 04_MetricProminence/
    |-- 05_LandscapeSimilarity/
    |-- 04_PhaseSpaceRQA/
    |-- 05_Group/
    `-- 06_Statistics_R/
```

Saved GED structures retain the selected calibration, filter type, and
realized `fwhm`. Existing core outputs without matching provenance are rejected
rather than mixed into a new analysis. The PCA branch does not use these
Gaussian filter widths.

## Statistical outputs

BLOCK 8 retains the established JRQA and spatial-similarity workbooks in
`06_Statistics_R` and exports participant-dimensional phase-space RR and DET
to `06_Statistics_R/PhaseSpaceRQA`. `FREQNESS_Mocap_Stats.R` applies the same
trial averaging, natural-log transformation, mixed-effects models, polynomial
comparisons, diagnostics, and four-level Bonferroni correction to both temporal
methods. Phase-space results are kept separately in
`FREQNESS_Mocap_Stats_Results/PhaseSpaceRQA` so existing JRQA results are not
overwritten.

Validated JRQA workbooks are stored in
`06_Statistics_R/JRQA_Validated/<specification>`. Selecting a validated JRQA
method in `FREQNESS_Mocap_Stats.R` saves model
outputs beneath
`FREQNESS_Mocap_Stats_Results/JRQA_Validated/<specification>`, so rerunning the
validation cannot replace earlier JRQA or phase-space statistics.
Method-comparison and circular-shift summaries are saved alongside these
outputs under `JRQA_Validated/Method_Comparison_FixedDyadRadius` and
`JRQA_Validated/Surrogate_Validation_FixedDyadRadius`, respectively.

The default model selection is now
`FREQNESS_STATS_METHODS=PhaseSpaceRQANonStandardized`. It reads the separate
`06_Statistics_R/PhaseSpaceRQA_NonStandardized` sensitivity exports and fits
natural-log RR and untransformed DET, following residual diagnostics. This
post hoc transformation choice is not a preregistered manuscript analysis.
Outputs go to `PhaseSpaceRQA_NonStandardized/SelectedTransformations` beneath
the statistics output root, preserving the earlier all-log results. Existing
JRQA and normalized phase-space methods retain their transformations. This
does not change the MATLAB pipeline's input-normalization settings or create
the sensitivity exports; they must already exist. Set the environment variable
to `FixedDyadRadiusJRQA` (or another supported method) to select other model fits.
