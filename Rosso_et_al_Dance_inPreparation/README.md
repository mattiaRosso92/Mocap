# Dyadic dance study

Priority study and first reference test case for FREQ-NESS MoCap. Keep
study-specific preprocessing, orchestration, statistical analysis, and figure
generation in this directory; reusable functionality belongs in
`FREQNESS_Mocap_Toolbox`.

The Dance pipeline retains JRQA in its existing group-analysis section and
runs participant-dimensional phase-space RQA in the immediately following,
separate section. This keeps the two temporal-coordination formulations
independent while matching component, frequency, duration, filtering, and
downsampling settings for comparison.

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
