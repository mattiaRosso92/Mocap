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

Two labelled specifications are written under
`03_Coordination_JRQA_Validated`: `CorrectedManuscript` uses the stated 10%
phase-space-radius method, while `Robustness` fixes each participant's marginal
recurrence rate at 5% and excludes the full embedding window around the
identity. Trial-level outputs, component summaries, parameter provenance, and
R-ready workbooks are kept separate from all historical results.

Block 5 additionally runs a reproducible circular-shift control on a
predefined stratified subset. It preserves each partner's recurrence geometry
while disrupting between-participant temporal alignment, and saves observed,
null, empirical-p, and standardized RR/DET results under
`03_Coordination_JRQA_Validated/SurrogateValidation`.

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
`06_Statistics_R/JRQA_Validated/<specification>`. By default,
`FREQNESS_Mocap_Stats.R` analyses only these new workbooks and saves model
outputs beneath
`FREQNESS_Mocap_Stats_Results/JRQA_Validated/<specification>`, so rerunning the
validation cannot replace earlier JRQA or phase-space statistics.
Method-comparison and circular-shift summaries are saved alongside these
outputs under `JRQA_Validated/Method_Comparison` and
`JRQA_Validated/Surrogate_Validation`, respectively.
