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

New GED analyses use `CFG.common.filter_width_calibration='physical'` and the
toolbox's physical logarithmic Q schedule by default. Select `'legacy'` only
for historical replication. The pipeline then computes the former explicit
32-by-2 FWHM matrix after the two participant-specific beat grids have been
constructed and passes that matrix to `FREQNESS_NetworkEstimation_Mocap`.

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
