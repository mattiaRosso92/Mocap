# Dyadic Dance study

The publication workflow analyses **all 35 dyads and 1119 retained trials**.
Dyad 13 retains its recorded 7/8/9/8 condition split; only dyad 32, original
trial 32, is excluded because neither partner has recorded marker coordinates.
No final analysis compares a smaller cohort or silently drops a dyad.

Public dataset: https://doi.org/10.48557/UR2GBG
([IIT Dataverse](https://dataverse.iit.it/dataset.xhtml?persistentId=doi:10.48557/UR2GBG)).
Verified on 2026-10-23: released dataset, 2278 files, no restricted files.
Place the existing trial CSVs and condition/song metadata in repository-level
`Dance_Data`; raw data and generated outputs remain ignored by Git.

Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti.

## Entry points

| File | Role |
| --- | --- |
| [DyadiDance_MainPipeline.m](DyadiDance_MainPipeline.m) | Main MATLAB analyses and exports |
| [DyadiDance_Stats.R](DyadiDance_Stats.R) | Main RR/DET and spatial models; also the 35-dyad Fisher sensitivity and extended model tables |
| [Supplementary/DyadiDance_Supplementary.m](Supplementary/DyadiDance_Supplementary.m) | Metric prominence, landscape similarity and supplementary figures |
| [Supplementary/DyadiDance_MetricProminence_Stats.R](Supplementary/DyadiDance_MetricProminence_Stats.R) | Global + four metric-level prominence models |
| [Supplementary/DyadiDance_LandscapeSimilarity_Stats.R](Supplementary/DyadiDance_LandscapeSimilarity_Stats.R) | Component-landscape and H2-landscape similarity models |
| [Supplementary/DyadiDance_SpatialComparison.R](Supplementary/DyadiDance_SpatialComparison.R) | Raw/Fisher comparison using only the final 35 dyads |
| [Supporting/DyadiDance_Configuration.m](Supporting/DyadiDance_Configuration.m) | One shared configuration and trial/song mapping |
| [Supporting/DyadiDance_GroupFigures.m](Supporting/DyadiDance_GroupFigures.m) | Shared unchanged figure calculations, selected as Main or Supplementary |
| [Examples/DyadiDance_Example.m](Examples/DyadiDance_Example.m) | Single-recording toolbox demonstration, not a cohort analysis |

All Dance source filenames use `DyadiDance_*`. Toolbox functions retain
`FREQNESS_*`. Existing MAT/XLSX/CSV filenames, variable names and output
directories are intentionally unchanged so completed results remain reusable.
The toolbox, Empatic and Orchestra analyses are not reorganized here.

## Run order and stable block IDs

Open `DyadiDance_MainPipeline.m` in MATLAB and run Block 0 before any later
block. The shared settings script is also readable/editable directly; both
entry points use the same settings. Run the complete main pipeline for a
fresh replication, or resume the required blocks using completed outputs.

| Original block ID | Entry point | Analysis |
| --- | --- | --- |
| 0 | Both | Shared settings, 35-dyad trial selection, participant-specific song/beat mapping |
| 1 | Main | Position-based network estimation |
| 2 | Main | Landscapes and full-spectrum effective dimensionality |
| 3 | Main | Spatial correlations, components 1 and 2 |
| 4 | Supplementary | Metric prominence, component 1 |
| 5 | Supplementary | Beat-relative landscape similarity, component 1 |
| 6 | Main | Corrected phase-space RQA, components 1 and 2 |
| 7 | Both | Main or supplementary figures from saved summaries |
| 8 | Main | Final spatial and RR/DET workbooks for R |

Block IDs and `CFG.block*` keys are deliberately preserved, including IDs
4/5 in the supplementary entry point. Renumbering these would break the
meaning of existing saved configurations. Output folder numbers are likewise
historical identifiers, not a new numbering scheme.

Run `Supplementary/DyadiDance_Supplementary.m` after the main MATLAB pipeline.
Its Blocks 4/5 need only the shared configuration and existing core estimates;
its figure block also needs the saved group/spatial/phase-space summaries.
It does not rerun core estimation or temporal RQA.

Then, from the repository root, run:

```sh
Rscript Rosso_et_al_Dance_inPreparation/DyadiDance_Stats.R
Rscript Rosso_et_al_Dance_inPreparation/Supplementary/DyadiDance_MetricProminence_Stats.R
Rscript Rosso_et_al_Dance_inPreparation/Supplementary/DyadiDance_LandscapeSimilarity_Stats.R
Rscript Rosso_et_al_Dance_inPreparation/Supplementary/DyadiDance_SpatialComparison.R
```

R requires readxl, dplyr, ggplot2, lme4 and lmerTest. The primary R entry point
defaults to SpatialRaw, SpatialFisher and PhaseSpaceRQACorrected; no historical
method can be selected there. `FREQNESS_STATS_METHODS` still selects among
these three methods. Complete 35-dyad inputs and both components are required.
Supplementary prominence/similarity R scripts accept an input CSV and a new
output directory as optional command-line arguments.

## Preserved scientific settings

Core estimation retains the study's explicit legacy logarithmic filter widths,
four retained components and the complete eigenspectrum. This is separate from
the corrected anti-aliasing used downstream for temporal analysis.
Each partner's frequency grid is defined from their own song tempo.

Phase-space RQA retains the validated settings: 250 Hz input; fourth-order
10 Hz Butterworth filtfilt before decimation by 10; central 15–85% window;
no z-standardization; one partner per joint-space dimension; Euclidean radius
0.1 times the trial's maximum joint distance; strict distance < radius;
Theiler window 0, lmin 2, vmin 2; beat multiples [.25 .5 1 2].

Compatible existing RR/DET summaries are reused. The optional validated
comparison-cache import checks settings, retained trials, frequencies and
sample counts before reuse. RR/DET-only summaries do not fabricate the six
other RQA metrics. No historical RQA result is silently substituted.

Spatial coordination correlates absolute patterns at partner-specific
beat-relative frequencies. The primary outcome is mean trial r; the Fisher
sensitivity is mean atanh(trial r), not atanh(mean r).

Main inferential models remain Visual * Music * Meter + (1 | Dyad).
RR uses natural log; DET and primary spatial correlations remain untransformed.
Per-meter models use Visual * Music + (1 | Dyad), with Bonferroni correction
across four meters per effect/component. Polynomial models, ANOVA tables and
residual diagnostics remain in the same R implementation; their extended
outputs support the supplement. No equations or inferential choices changed
during organization.

## Output safety

All numerical locations under
`Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/legacy_logarithmic_recovered_dyads`
are unchanged, including core reuse from the original results root.
Existing per-trial spatial results cover the complete final cohort; no old
33-dyad spatial summary is imported by the final pipeline.

MATLAB overwrite flags remain false. R refuses populated output directories;
choose a new output location for a deliberate rerun. No old result is deleted.
New group figures use `Main/` or `Supplementary/` beneath the established
configuration-tagged figure folder, avoiding collisions with older GROUP_NN
images whose numbering depended on the combined figure collection.

## Supplementary versus historical

[Supplementary/README.md](Supplementary/README.md) maps the manuscript's
candidates to implemented sections and explicitly lists unfinished items.
Metric prominence and landscape similarity are included by author decision.
The manuscript itself is not edited by this reorganization.

[Historical/README.md](Historical/README.md) inventories earlier JRQA,
phase-space development and exploratory analyses. They preserve their
original cohorts/settings as records, not final publication scripts.
**No JRQA analysis is included in the main or supplementary workflow.**

Tests remain under repository-level `tests/`; ignored local execution drivers
under `.codex/` and audit files under `Dance_Data/` remain development records,
not supported publication entry points.

## Validation

Run `runtests('tests')` in MATLAB after toolbox startup, and the two R tests
below from the repository root. Real-data tests explicitly skip if the local
exports are absent. They do not rerun full core estimation or RQA.

| Test file | Coverage |
| --- | --- |
| [DyadiDance_OrganizationTest.m](../tests/DyadiDance_OrganizationTest.m) | Publication/historical separation; all 35 dyads and 1119 trials; supplementary cache reuse without writes |
| [DyadiDance_PhasePipelineTest.m](../tests/DyadiDance_PhasePipelineTest.m) | Preserved manuscript settings, filtering/cropping and isolated output paths |
| [DyadiDance_PhaseReuseTest.m](../tests/DyadiDance_PhaseReuseTest.m) | Validated RR/DET import, export, resume and incompatible-cache rejection |
| [DyadiDance_SpatialPipelineTest.m](../tests/DyadiDance_SpatialPipelineTest.m) | Spatial-only computation and trial-level raw/Fisher exports |
| [DyadiDance_TimeCoordIntegrationTest.m](../tests/DyadiDance_TimeCoordIntegrationTest.m) | Unified toolbox interface and historical-only JRQA calls |
| [testFREQNESSStudyFilterCalibration.m](../tests/testFREQNESSStudyFilterCalibration.m) | Shared cross-study test; only the Dance source locations changed |
| [DyadiDance_TestStats.R](../tests/DyadiDance_TestStats.R) | Invalid-cohort rejection and corrected phase-space statistical regression |
| [DyadiDance_OrganizationTest.R](../tests/DyadiDance_OrganizationTest.R) | Complete final R entry points and unchanged saved main/supplementary model tables |

```sh
Rscript tests/DyadiDance_TestStats.R
Rscript tests/DyadiDance_OrganizationTest.R
```

Validated on 2026-10-23: all 16 MATLAB tests passed; all R scripts parsed;
main and supplementary statistical tables matched their saved references
(tolerance 1e-8 in the organization test). Both figure collections constructed
successfully, with representative PNG/FIG exports checked in a separate
temporary folder. Existing numerical results were not overwritten.
