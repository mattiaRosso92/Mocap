# Dyadic dance study

Priority study and first reference test case for FREQ-NESS MoCap. Keep
study-specific preprocessing, orchestration, statistical analysis, and figure
generation in this directory; reusable functionality belongs in
`FREQNESS_Mocap_Toolbox`.

The manuscript temporal analysis is participant-dimensional phase-space RQA
with corrected 10 Hz filtering before decimation to 25 Hz. Historical JRQA
outputs remain separate. Corrected JRQA is run
by `FREQNESS_DyadicDance_JRQA_Validation.m`, which consumes the completed core
outputs without modifying them or either earlier temporal analysis.

Block 6 uses `FREQNESS_TimeCoord_Mocap` with `'method','phase_space'` and no
parameter structure. Block 3 computes spatial coordination only. Historical
JRQA tuning and recomputation have been removed, not silently substituted with
corrected calculations. Existing historical summaries remain read-only inputs
for optional plots and exports. The separate corrected JRQA validation uses
the unified interface with `'method','jrqa','parameters',JRQA` and its explicit
normalization setting; there is no longer an `implementation` input.
Startup resolves the toolbox's Analysis, Visualization, and Supporting
subfolders. This interface migration does not change study settings,
saved variable names, output locations, or cache/overwrite checks.

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

All blocks now share the matching legacy-core fallback through
`CFG.common.reuse_core_path`. Block 1 skips those existing cores after checking
trial IDs and actual filter widths; it does not duplicate the original 33 dyads.
Block 2 rebuilds the 35-dyad network/ED summary from compact core fields, reusing
completed legacy ED outputs. Blocks 3–6 follow the same retained-trial list.
Group plots and exports reject summaries with different dyads/trials instead
of silently adopting an older 33-dyad list. The current R study scripts require
all 35 dyads. Historical sensitivity/validation scripts retain their original
cohorts and are not additional steps in the main manuscript workflow.

## Spatial coordination (BLOCK 3)

Spatial coordination always runs independently of temporal coordination.
`CFG.block3.reuse_legacy_jrqa=false` disables historical JRQA plots by default;
when enabled, Block 7 only reads existing historical summaries. Likewise,
`CFG.block8.export_jrqa` exports saved historical summaries only and stops if
they are missing. Neither option can run old tuning or replace those summaries.
The primary temporal analysis remains Block 6.
Components 1 and 2 use the existing `FREQNESS_SpaceCoord_Mocap` calculation:
Pearson correlations between partners' absolute spatial patterns at matching
beat-relative frequencies. The legacy 33-dyad spatial values are reused
unchanged; the recovered 63 trials are calculated from their existing cores.
Per-trial `FREQNESS_SPATIAL_*` files and separate spatial summaries retain
original recording IDs and source provenance under `03_Coordination/Component_*`.

Run Block 0, Block 3, then the **spatial section of Block 8** (before
`Optional historical JRQA export`) to update spatial results alone. No core
estimation, RQA, or group plotting is needed. Block 8 exports both the mean
raw trial correlation and the mean trial-level Fisher transform, `atanh(r)`,
to `06_Statistics_R/SpatialCoordination`. Fisher transformation is performed
before averaging, not applied to the condition-mean correlation. Undefined
or perfect correlations and missing retained trials stop the export.

The main R script fits `SpatialRaw` as the manuscript analysis and
`SpatialFisher` as sensitivity, using the same factorial and metric-specific
mixed models and four-meter Bonferroni correction. To run only these methods:

```sh
FREQNESS_STATS_METHODS=SpatialRaw,SpatialFisher Rscript Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_Stats.R
Rscript Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_SpatialComparison.R
```

Outputs go under `FREQNESS_Mocap_Stats_Results/legacy_logarithmic_recovered_dyads/SpatialCoordination`
in `Raw`, `Fisher`, and `Comparison` subfolders, without overwriting old results.
The comparison script reads the saved model tables, compares the legacy 33-dyad
analysis, and plots raw-r and back-transformed Fisher summaries plus residual
Q-Q plots. It accepts a new comparison output directory as an optional argument.

## Manuscript phase-space RQA (BLOCK 6)

All settings are explicit in `CFG.block6` in Block 0:

| Setting | Selected analysis |
| --- | --- |
| Dyads / components | All 35 dyads; Components 1 and 2 |
| Input / output sampling rate | 250 Hz / 25 Hz (`downsample = 10`) |
| Anti-alias filter | Fourth-order Butterworth, physical cutoff 10 Hz; `filtfilt` on the full input series |
| Duration | Decimate first, then retain `round(.15*N):round(.85*N)`; 1051 samples for these trials |
| Metric levels | Each partner's own song beat multiplied by `[.25 .5 1 2]` |
| Phase space | One participant per dimension; no time-delay embedding |
| Input standardization | `false`; no z-scoring |
| Radius | `0.1 * max(pairwise Euclidean distance)` within each trial/component/meter, not a fixed 10% RR |
| Recurrence criterion | Strict distance `< radius` |
| Theiler / minimum line lengths | `0` (identity diagonal retained); `lmin = 2`, `vmin = 2` |

The filter is designed at the **original** rate: `10/(250/2) = .08`, not the
historical `.8` (100 Hz). The physical 10 Hz cutoff does not change with the
decimation factor; the block rejects factors whose new Nyquist is at or below
that cutoff. Filtering precedes both decimation and duration selection.
This downstream correction does not change core estimation, Gaussian filter
width calibration, effective dimensionality or spatial coordination.

For completed core analyses, run **Block 0, then Block 6, then the
Manuscript phase-space export section of Block 8**. This temporal-only route
does not require the spatial section; a full run executes both.
Block 6 reuses the validated RR/DET results described below when available.
Otherwise, it searches `CFG.block1.output_path` (including recovered dyads),
then the matching legacy `01_Core` folder for the original 33 dyads. It checks
trial IDs, stored filter widths and selected frequencies. Do not rerun core
estimation merely to reproduce the temporal analysis. Block 7 is optional for
group figures; R also produces condition plots.

Numerical outputs use a new folder:
`04_PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0/Component_<n>`.
For the legacy-logarithmic core analysis, `CFG.block6.reuse_rqa_path`
automatically selects the completed corrected comparison under
`PhaseSpaceRQA_AA10Hz_Downsample_20261017` when present. With overwrite disabled,
Block 6 validates its settings, all retained trial IDs, core metadata,
partner-specific frequencies, sample counts and trial/summary agreement.
It creates only two component summaries containing the saved **RR and DET**
and source provenance: no RQA is recomputed, no original files are changed,
and no per-trial files are duplicated. Subsequent runs validate and reuse
these self-contained summaries, even if the comparison folder is unavailable.
Block 7 plots only saved metrics; Block 8 exports the same RR/DET to R.
The other six RQA metrics were not retained by that comparison and are **not**
invented or represented as computed missing values.

Without a reusable summary or comparison, normal computation is unchanged:
per-trial files retain the full toolbox output, settings, original trial ID
and source core path. Existing files require matching settings and trial IDs.
To compute all eight metrics, clear `CFG.block6.reuse_rqa_path` and choose a
new output folder. A mismatch stops reuse rather than silently recalculating
or overwriting results.

These are **study settings**: reusable toolbox defaults and the separate
validated-JRQA script are unchanged. Alternate settings require a separate
output tag/folder and corresponding R input configuration.

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

The primary specification within that separate JRQA validation is `FixedDyadRadius`, under
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
    |-- 04_PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0/
    |-- 05_Group/
    `-- 06_Statistics_R/
```

Saved GED structures retain the selected calibration, filter type, and
realized `fwhm`. Existing core outputs without matching provenance are rejected
rather than mixed into a new analysis. The PCA branch does not use these
Gaussian filter widths.

## Statistical outputs

BLOCK 8 exports the selected phase-space RR and DET to
`06_Statistics_R/PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0`.
The default `CFG.block8.export_jrqa=false` makes this block independent of
JRQA completion; only historical JRQA exports remain opt-in. Spatial exports
always run in their separate folder. Existing
workbooks are checked against the current values and left untouched unless
overwrite is explicitly enabled.

Run `Rscript Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_Stats.R` from the
repository root. Its defaults are `SpatialRaw`, `SpatialFisher`, and
`PhaseSpaceRQACorrected`. All read both components from their matching
recovered-dyad MATLAB folders and require all 560 unique
dyad-condition-meter rows per component. The temporal models are:

- `log(RR) ~ Visual * Music * Meter + (1 | Dyad)`
- `DET ~ Visual * Music * Meter + (1 | Dyad)` on the original scale
- Within each meter, the corresponding `Visual * Music + (1 | Dyad)` model

Type III F tests use Satterthwaite degrees of freedom. Within-meter p-values
receive Bonferroni correction across all four meters separately for each
effect, outcome and component; alpha is .05. No extra correction is applied
across outcomes/components. Available trials are averaged **before** log
transformation, with dyad as the independent sampling unit. Plots show
original-scale means and SEM across dyads. Polynomial comparisons and residual
diagnostics are retained; log-RR/raw-DET was a diagnostic-based, post hoc
choice, not a preregistered model. Residual departures from normality remain
limitations, especially for DET; significance within one meter alone does not
establish meter specificity.

R outputs are isolated under
`Dance_Data/FREQNESS_Mocap_Stats_Results/legacy_logarithmic_recovered_dyads/PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0`.
Existing corrected-statistics folders are refused unless `overwrite_flag`
is explicitly enabled. The MATLAB and R configuration tags must agree.

Validated JRQA workbooks are stored in
`06_Statistics_R/JRQA_Validated/<specification>`. Selecting a validated JRQA
method in `FREQNESS_Mocap_Stats.R` saves model
outputs beneath
`FREQNESS_Mocap_Stats_Results/JRQA_Validated/<specification>`, so rerunning the
validation cannot replace earlier JRQA or phase-space statistics.
Method-comparison and circular-shift summaries are saved alongside these
outputs under `JRQA_Validated/Method_Comparison_FixedDyadRadius` and
`JRQA_Validated/Surrogate_Validation_FixedDyadRadius`, respectively.

The earlier method
`FREQNESS_STATS_METHODS=PhaseSpaceRQANonStandardized` still reads the separate
`06_Statistics_R/PhaseSpaceRQA_NonStandardized` sensitivity exports and fits
natural-log RR and untransformed DET, following residual diagnostics. This
post hoc transformation choice is not a preregistered manuscript analysis.
Outputs go to `PhaseSpaceRQA_NonStandardized/SelectedTransformations` beneath
the statistics output root, preserving the earlier all-log results. Existing
JRQA and normalized phase-space methods retain their transformations. This
does not create the historical sensitivity exports; they must already exist.
Set the environment variable
to `FixedDyadRadiusJRQA` (or another supported method) to select other model fits.
Historical method-comparison and surrogate plots run only when
`run_established_methods=true`; a default phase-space run does not rewrite them.

The actual R scripts used for earlier comparisons, transformation checks,
dyad recovery and landscape sensitivities are retained in
[`statistics_history`](statistics_history/README.md). They are audit/sensitivity
code, not additional steps required by the selected manuscript workflow.
Data, tables, plots, slide decks and other generated artifacts remain ignored.
