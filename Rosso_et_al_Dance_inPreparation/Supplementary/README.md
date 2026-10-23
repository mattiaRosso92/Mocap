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
- Block S1: reconstructed controls for all 1119 trials: GED/PCA with width
  multipliers 0.25, 0.5, 1, 2 and 4; position/velocity; X/Y/Z-only GED. Each
  partner uses their own song tempo and explicit primary filter widths.
  Every baseline eigenspectrum is checked against its saved primary core.
- Block 7: publication panels for condition-specific landscapes/ED,
  decomposition controls, XYZ patterns across components 1–4, within-person
  component-1/component-2 correlations, coordination in both components,
  metric prominence and landscape similarity. Aesthetics and panel assembly
  are coded here. Existing main figures are unchanged.
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

## Study-only control implementation

- `DyadiDance_NetworkEstimationPCA.m` is the supplied PCA reference, renamed
  to distinguish study code from the toolbox. It now accepts partner-specific
  width matrices and retains all eigenvalues for ED. Its narrowband PCA
  calculation is unchanged. It is **not** a new public toolbox function.
- `DyadiDance_ControlEstimation.m` computes only eigenvalues and axis patterns.
  GED and PCA share the same covariance. For gap-free inputs, Parseval's
  identity yields the same centered covariance directly from the filtered
  spectrum; only exactly-zero bins are skipped. No spectral cutoff is added.
  Gapped trials use time-domain covariance and the toolbox interpolation
  policy. Axis zeroing precedes gap detection. Velocity is the first
  difference times 250, excluding differences adjacent to reconstructed samples.
- `DyadiDance_ValidateControls.m` compares these controls against the public
  GED and supplied PCA references for all five widths, participant-specific
  widths, zeroed axes, gaps and velocity; it also checks complete-spectrum ED.

## Run and reproduce

1. Run the main pipeline to populate/reuse the final 35-dyad summaries.
2. Run `DyadiDance_Supplementary.m`. Existing prominence/similarity outputs
   and matching control files are reused. New controls, figures and their
   provenance are written only under `Supplementary_35` in the recovered-dyad
   results root. No primary core, coordination or RQA file is overwritten.
3. Run `DyadiDance_Stats.R` in the study root and the prominence/similarity R
   scripts here. Existing completed results may be reused; the two latter
   scripts require a new output directory if explicitly rerun.
4. Run `python DyadiDance_SupplementDocument.py` with `python-docx` and Pillow
   installed. It builds the Word supplement and figure/statistics ZIPs from
   the permanent figures and canonical R results. Use `--name NewName.docx`
   for a revised document; the builder does not overwrite an existing one.
   If the local manuscript is present, its package supplies the page system,
   theme and styles. `--template` selects another read-only manuscript copy.
   The document uses the manuscript's actual typography: 12-point Times New
   Roman, single-spaced justified paragraphs, italic analysis headings,
   10-point captions and one-inch margins, without added page numbering.

All generated files stay under ignored `Dance_Data`. Only source files and
documentation belong in Git. The manuscript is never edited by this workflow.

## Scope and interpretation

- These are newly reconstructed **35-dyad** controls, not relabelled figures
  from the presentation's 33-dyad analyses.
- Width multipliers modify the primary legacy-logarithmic schedule. They do
  not test the alternative physical-width calibration or independently vary
  frequency-grid resolution. Remove the separate frequency-resolution claim
  from the manuscript unless that additional experiment is specified.
- Sign indeterminacy is addressed analytically: independent axis reflection
  preserves joint Euclidean distances, the max-distance radius, RR and DET;
  absolute patterns are likewise invariant. This is not an empirical coupling
  test or a test of component matching under eigenvalue degeneracy.
- Add metric prominence and landscape similarity to the manuscript's list of
  supplementary analyses. The latter correlates H2 entropy, not ED itself.
- Do not claim cubic fits are best for every outcome: component-2 spatial
  coordination favors the quadratic model by AIC in the saved final analyses.
- Spatial pattern displays retain the shared post-aggregation magnitude scale;
  they do not normalize each participant/component to its own maximum first.
- Primary GED percentages are normalized eigenvalue contrasts; PCA percentages
  are narrowband covariance variance proportions. They have different meanings.
- Avoid stating that exactly two components suffice at every metric level:
  the 35-dyad mean effective dimensionality at twice the beat is 2.71.
- Component-pattern correlations preserve the original trial-weighted curve.
  Other descriptive landscapes average trials then partners within dyad.
