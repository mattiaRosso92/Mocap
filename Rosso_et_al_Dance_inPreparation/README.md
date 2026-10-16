# Dyadic dance study

Priority study and first reference test case for FREQ-NESS MoCap. Keep
study-specific preprocessing, orchestration, statistical analysis, and figure
generation in this directory; reusable functionality belongs in
`FREQNESS_Mocap_Toolbox`.

The Dance pipeline retains the historical JRQA outputs and the separate
participant-dimensional phase-space RQA implementation. Corrected JRQA is run
by `FREQNESS_DyadicDance_JRQA_Validation.m`, which consumes the completed core
outputs without modifying them or either earlier temporal analysis.

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
`-- <physical|legacy>_<logarithmic|linear>/
    |-- 01_Core/
    |-- 02_Landscape/
    |-- 03_Coordination/
    |-- 04_PhaseSpaceRQA/
    |-- 05_Group/
    `-- 06_Statistics_R/
```

Saved GED structures retain the selected calibration, filter type, and
realized `fwhm`. Existing core outputs without matching provenance are rejected
rather than mixed into a new analysis. The PCA branch does not use these
Gaussian filter widths.

## Statistical outputs

BLOCK 6 retains the established JRQA and spatial-similarity workbooks in
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
