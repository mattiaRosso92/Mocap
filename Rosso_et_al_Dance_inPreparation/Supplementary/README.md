# Dyadic Dance supplementary analyses

All final analyses use the same 35 dyads and 1119 retained trials as the main
pipeline. No 33-versus-35 comparison or JRQA analysis belongs here.

## Implemented material

- `DyadiDance_Supplementary.m`, Block 4: metric prominence. Individual ratios
  are averaged across partners and then trials. This is dyad-mean individual
  prominence, not interpersonal coupling. Global uses all available metric
  levels; separate levels are beat/4, beat/2, beat and 2x beat. On the current
  grid, the global 1/3 target maps to the nearest 3/8 bin, as before.
- Block 5: signed component-eigenvalue and H2-entropy landscape correlations.
  Both partners are aligned by beat multiple, not absolute Hz; no interpolation
  or re-estimation. Trial correlations are Fisher-transformed before averaging.
- Block 7: condition-specific landscapes/ED, XYZ views across components 1–4,
  within-participant component-1/component-2 spatial correlations, and
  component-2 coordination figures. Reuses the main saved summaries.
- `DyadiDance_MetricProminence_Stats.R`: five log-prominence Visual x Music
  models with random dyad intercept and Holm correction across five outcomes
  per effect; five original-scale condition plots.
- `DyadiDance_LandscapeSimilarity_Stats.R`: two Fisher-z Visual x Music models
  with random dyad intercept and Holm correction across outcomes per effect;
  plots back-transform z means and SEM bounds.
- `DyadiDance_SpatialComparison.R`: final 35-dyad raw/Fisher spatial
  comparisons and diagnostics only. Run the main `DyadiDance_Stats.R` first,
  which produces both inputs. Existing comparison outputs are never overwritten.
- The main `DyadiDance_Stats.R` also generates extended polynomial
  comparisons, ANOVA tables and residual diagnostics for the supplement.
  There is one implementation of those models, not a duplicate fitting script.

## Manuscript candidates not yet implemented as reproducible comparisons

| Candidate | Current status |
| --- | --- |
| GED versus PCA | The dormant PCA branch references a function absent from this checkout; do not select it as a runnable supplement |
| Core filter bandwidth/frequency resolution | Settings exist, but no systematic comparison driver; RQA anti-aliasing comparisons are a different question |
| Position versus velocity | Only commented-out conversion code exists, not a completed comparison |
| Axis-restricted re-estimation | The axis selector exists; the published supplementary figures currently show axis contributions of full-XYZ estimates |
| Component sign indeterminacy/coupling | Magnitude-based spatial processing exists, but no separate controlled comparison |

These items remain candidates, not claims of completed supplementary analyses.
Recover/implement them separately after agreeing their scientific specification.
Do not rerun existing core or RQA estimates just to reorganize source files.
