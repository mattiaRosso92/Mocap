# Historical Dance material

This directory is excluded from the final publication workflow.
Historical scripts preserve their original cohorts (including 33-dyad runs)
and settings rather than retroactively relabelling them as 35-dyad results.
All final main and supplementary entry points outside this directory require
35 dyads. JRQA, including corrected variants, is historical only.

`JRQA/DyadicDance_JRQA_Validation.m` retains the original corrected 33-dyad
validation workflow and surrogate analyses. It is not a final replication
entry point and does not restore removed incorrect toolbox implementations.
`DyadicDance_StatisticalModels_Historical.R` preserves the exact fitting
definitions used by these archived drivers; final scripts never import it.

`JRQA/DyadicDance_JRQA_Comparisons.R` contains the saved-method comparisons
and circular-shift statistics previously appended to the main R script.
It refuses existing comparison/surrogate output folders.

## Archived statistical drivers

These are the actual R analysis/plotting drivers used during the Dance
reanalyses, previously kept locally under `.codex`. Their model formulas,
transformations, exclusions, seeds and multiple-comparison procedures are
preserved. Only repository-path setup and existing-output safeguards were
added. Generated reports and figures are **not** source files to commit.

For the selected manuscript analysis use the parent `DyadicDance_Stats.R`
with `PhaseSpaceRQACorrected`, following MATLAB Blocks 0, 6 and 8. Do not run
all historical alternatives as part of the primary workflow.

## Inventory and prerequisites

All paths below are relative to `Dance_Data`. Historical scripts require
their specific MATLAB exports and, where used as regression references,
previous statistical tables. They do not generate missing RQA data.

| Script | Purpose / inputs |
| --- | --- |
| `PhaseSpace_Development/DyadicDance_PhaseAntialiasDownsample_Stats.R` | Actual 35-dyad corrected-filter comparison: legacy 25 Hz versus corrected 25/50 Hz, plus matched-span DET; reads `Factor*_Component*.xlsx` in `FREQNESS_Results_Rosso_et_al_inPreparation/legacy_logarithmic_recovered_dyads/PhaseSpaceRQA_AA10Hz_Downsample_20261017` and legacy 35-dyad exports |
| `PhaseSpace_Development/DyadicDance_PhaseRaw_Stats.R` | Original 33-dyad standardized versus non-standardized PS-RQA; both outcomes log-transformed at this historical stage |
| `PhaseSpace_Development/DyadicDance_PhaseTransform_Comparison.R` | Raw/log model and residual comparison for non-standardized 10% PS-RQA; checks the earlier all-log models |
| `JRQA/DyadicDance_PhaseLegacy_Comparison.R` | Original 33-dyad JRQA versus non-standardized 10% PS-RQA with selected log-RR/raw-DET models |
| `PhaseSpace_Development/DyadicDance_PhaseRadius05_Diagnostics.R` | Raw/log model diagnostics for the 33-dyad 5% radius exports |
| `PhaseSpace_Development/DyadicDance_PhaseRadius05_Stats.R` | 33-dyad legacy JRQA and 10%/5% PS-RQA comparison; requires earlier model and diagnostic tables |
| `JRQA/DyadicDance_Recovered35_Stats.R` | 33-versus-35-dyad FaithfulAdaptiveMax JRQA and 10% PS-RQA; checks that original 33-dyad inputs remain unchanged |
| `PhaseSpace_Development/DyadicDance_Recovered35_Radius05_Stats.R` | 35-dyad 5%-versus-10% PS-RQA; checks original 33-dyad values and RR threshold monotonicity |
| `JRQA/DyadicDance_Recovered35_Legacy_Stats.R` | Original legacy JRQA extended to 35 dyads, with unchanged-data checks |
| `JRQA/DyadicDance_FixedDyad_TransformationSensitivity.R` | Raw/log diagnostics for fixed-dyad-radius JRQA |
| `JRQA/DyadicDance_FixedDyad_PlotProfiles.R` | Condition profiles for legacy, adaptive-max and fixed-dyad-radius JRQA |
| `Exploratory/DyadicDance_LandscapeRaw_Sensitivity.R` | Raw-r versus Fisher-z models, leave-one-dyad-out checks and 20,000 whole-dyad bootstrap resamples (seed 17102026); requires `05_LandscapeSimilarity/Component_1/Sensitivity_RawVsFisher/ModelData.csv` |
| `Exploratory/DyadicDance_LandscapeFlaggedDyads_Sensitivity.R` | Exploratory omission of dyads 15/5/both, compared with all 35; requires the previous sensitivity's model data and tables |

Except for the explicitly corrected filter comparison, historical PS-RQA
comparisons retain their original **100 Hz** filtering before decimation.
They must not be relabelled as corrected 10 Hz analyses. Output narratives
describe those historical runs, not the current repository's state.

## Running an individual historical analysis

Run from the repository root, for example:

```sh
Rscript Rosso_et_al_Dance_inPreparation/Historical/PhaseSpace_Development/DyadicDance_PhaseAntialiasDownsample_Stats.R
```

Alternatively set `FREQNESS_REPO` to the checkout root. Scripts use the same
R libraries as the primary workflow (`readxl`, `dplyr`, `ggplot2`, `lme4`,
`lmerTest`; some require only a subset). Drivers reusing `analyse_component`
load only function definitions from DyadicDance_StatisticalModels_Historical.R,
not a primary analysis loop.

Existing output folders stop execution rather than replacing old evidence.
For a deliberate rerun, choose a fresh output location in that script and
retain its input/regression-reference paths. Some historical inputs are
intermediate exports not produced by the current primary pipeline; distribute
those separately if the corresponding sensitivity analysis is to be reproduced.
The raw-versus-Fisher script permits its input `ModelData.csv` in the output
folder, but refuses existing generated outputs.

These analyses are sensitivity/audit records, not independent replications.
Keep all 35 dyads in the primary analysis; do not choose a radius, transform,
sampling factor, exclusion or correction based on the resulting significance.
