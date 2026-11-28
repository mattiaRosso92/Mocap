# Orchestra study

`FREQNESS_Orchestra_Main.m` starts from Kiersten's processed XY trajectories.
It is one chronological study script and calls the current MoCap toolbox
functions directly. It does not perform preprocessing or modify the toolbox.

## Execution order

1. **Block 0:** edit the central `CFG` settings and initialize the toolbox.
2. **Block 1:** estimate one whole-ensemble FREQNESS solution per complete
   recording under `data/full-piece-data-fixed-despiked`.
3. **Block 2:** estimate each supplied musical-section CSV listed in the
   manifests under `data/segment-piece-data-fixed-despiked`.
4. **Block 3:** load saved cores and visualize landscapes, labelled activation
   matrices, and static overhead activation patterns.

The core blocks are enabled by default. Visualization is disabled initially;
enable `CFG.block3.run_flag` after inspecting the core index files. The three
stages run independently after Block 0. Block 3 needs only saved outputs,
not the source CSVs. Rerun Block 0 after editing scientific settings so that
output routes reflect the new configuration.

The default input root is `concertproject_kiersten/data` alongside the script.
If the handover is renamed `_Kiersten`, update `CFG.common.data_path`. Both
handover names and the generated `FREQNESS_Output` directory are gitignored.

## Scientific settings and data contract

- **Sampling rate: 25 Hz**, confirmed by the user on 28 November 2026.
  New cores record the confirmation source/date separately from independent
  camera verification, which remains false. Audio-to-frame alignment is
  still unresolved and is not corrected or resampled by this pipeline.
- **Frequency grid: 0.5:0.1:10 Hz.** Physical logarithmic widths are the
  default. Set `CFG.common.filter_width_calibration='legacy'` to compute a
  matched historical-width comparison. Each calibration is a separate core
  analysis using the current toolbox; selecting a gallery option never
  relabels an estimate from the other calibration.
- **Regularisation: 0.01.** Four components retain spatial patterns,
  eigenvectors, and time series. The complete normalized eigenspectrum is
  retained independently of that component count. Component landscapes show
  only the leading component; H2 uses the complete eigenspectrum. The longest supplied recording needs approximately 103 MiB for
  its four-component time series alone. Observations run sequentially.
- CSVs contain `frame,1x,1y,2x,2y,...`, with numeric track IDs and consecutive
  frame indices. All values must be finite. Inputs are adapted to
  `[X1;Y1;Z1;X2;Y2;Z2;...] x time`, with Z set to zero as in the original
  script. All supplied frames and tracks are retained. The prototype's
  temporary half-recording selection and track-64 removal are superseded by
  the requested full-piece workflow.
- Each solution represents **one ensemble recording or section**. Musicians
  are coordinate channels, not independent observations along a participant
  dimension. Tracks are labelled `Track_1`, `Track_2`, etc., preserving CSV
  IDs. Unverified conductor/instrument labels are not assigned.
- There is no resampling, detrending, despiking, interpolation, or missing-data
  repair. Segment frame counts and original frame indices must agree with the
  manifest. Missing segment CSVs are recorded as `missing_source` and skipped;
  they are not reconstructed from full recordings. Original manifest fields,
  including audio/EAF timing and availability annotations, are saved intact.
  Score-section labels are imported explicitly as text, preserving mixed
  labels such as `Start`, `5`, and `10` without numeric coercion.

This first pipeline estimates the whole available ensemble. Instrument-group
estimation, aggregation across recordings, temporal windows, and statistical
tests are not part of these blocks.

## Selection, saving, and resuming

Use `CFG.common.pieces` and `CFG.common.recordings` to select inputs; recording
names are exact stems without `.csv`. `CFG.block2.segment_labels` optionally
selects manifest labels. Empty recording/section lists mean all.

Outputs are stored under:

```text
FREQNESS_Output/<legacy|physical>_<filter>/<rate_grid_settings_signature>/
  01_Core_FullPiece/<piece>/GED_<recording>.mat
  02_Core_SegmentPiece/<piece>/<recording>/GED_<section>.mat
  03_Visualization/leading_H2_empirical_peak_magnitude/<full_piece|segment_piece>/...
```

The settings signature distinguishes exact frequency vectors, rates, retained
component counts, regularisation, calibration, coordinate policy, timing
provenance, and SHA-256 hashes of the estimator and selected width helper. Each
core contains `GED`, `analysis_info`, `CFG`, `frex`, `srate`, `marklabels`, and
`marker_position`. `GED` preserves eigenvalues, retained eigenvectors, signed
patterns, time series, and toolbox metadata. `marker_position` retains only
the first coordinate frame for static visualization, avoiding a duplicate
copy of the complete input trajectories.

`analysis_info` records source path/size/modification time, original frame
bounds, track IDs, scientific settings, the segment manifest row when
applicable, and estimator source text. MAT files use `-v7.3` and are moved
into place only after saving completes. Compatible outputs are reused.
Changed sources, estimator code, or settings cause an error instead of
silent reuse; inspect the discrepancy before enabling that block's
`overwrite_flag`. Size and modification time are provenance checks, not a
cryptographic data checksum.

Each core block refreshes its `core_index.csv`, including `saved`, `existing`,
`missing_source` (sections only), and `not_selected` statuses. The index
describes this invocation; previously saved cores remain on disk.

## Visualization

Block 3 has independent stage, recording, and musical-segment selectors,
plus the shared piece selector. It reads saved eigenvalues and patterns
without loading unused time series or requiring source CSVs.

- **Leading-component landscapes:** one curve per full recording, overlaid
  within each piece; one curve per available musical segment, overlaid within
  each recording. Only component 1 is shown, as a percentage of the complete
  eigenvalue sum. Native frequency bins are connected without smoothing.
- **H2 landscapes:** separate figures with exactly the same curves/colors.
  `FREQNESS_EffectDim_Mocap(FREQ,'figure',false)` computes quadratic Rényi
  entropy from **all** saved eigenvalues: `H2 = -log(sum(p.^2))`, where
  `p = lambda/sum(lambda)` across coordinate channels, in natural-log units
  (nats). ED is also retained. Lower H2 means a more concentrated spectrum;
  raw H2 depends on channel count, which varies across some recordings.
- **Temporal colors:** red to light blue across numeric day/rehearsal order,
  with concerts last and purple (Concert 2 dashed). Musical segments follow
  their manifest indices, with red first and light blue last. Missing
  segments are omitted, without substituting an estimate or renumbering.
- **Empirical-peak patterns:** both overhead views and labelled activation
  matrices show component 1 at its highest stored value on the analyzed
  frequency grid, independently for every observation. Exact ties select the
  first (lowest-frequency) bin. Frequency-boundary maxima and ties are flagged
  in the titles/catalog; these need not represent distinct interior peaks.
  No peak fitting, smoothing, or frequency substitution is performed.

Signed core patterns are preserved. A separate display copy is rectified:

- **Activation matrices:** absolute coordinate weights in raw pattern units.
- **Coordinate overhead views:** absolute weights divided by the maximum
  absolute coordinate weight across tracks at that observation's selected
  component and frequency; the same denominator serves X, Y and Z.
- **XY vector magnitude:** `hypot(raw_X,raw_Y)` is computed before scaling,
  then divided by its maximum across tracks. This is invariant to rotations
  of image axes, but does not correct perspective or recover depth.

Each denominator, raw magnitude, normalized display value and all-zero flag
is saved. Zero patterns remain finite and zero. These maps show relative
spatial distributions, not comparable absolute movement amplitudes across
recordings. Z remains an unmeasured placeholder. Track IDs remain unchanged;
verified musician labels and activity exclusions are deferred.

Figures are saved as 200-dpi PNGs and closed by default. For interactive
inspection, set `figure_visibility='on'` and `close_figures_flag=false`.
The `leading_H2_empirical_peak_magnitude` output route preserves previous
signed empirical-peak and 20-component/2-Hz figures. Replacing figures within a route requires `overwrite_flag`.
Per-observation `visualization_info.mat` records source provenance, empirical
peak index/frequency/value, boundary/tie flags, and plotting settings.
Each overlay's `landscape_data.mat` retains the plotted spectra, H2/ED,
chronological labels, colors, and source metadata. Each stage exports a
`figure_catalog.json` containing the plotted values and original PNG paths.

Build the app/offline gallery directly from these MATLAB catalogs:

```sh
python3 build_orchestra_report.py \
  --visualization-path "FREQNESS_Output/physical_logarithmic/<settings>/03_Visualization/leading_H2_empirical_peak_magnitude" \
  --visualization-path "FREQNESS_Output/legacy_logarithmic/<settings>/03_Visualization/leading_H2_empirical_peak_magnitude" \
  --output-path "FREQNESS_Output/report"
```

Repeat `--visualization-path` for independently computed runs. Catalogs must
explicitly identify their calibration and spatial figure roles; duplicate
runs for one calibration/reference/stage and conflicting metadata are
rejected. The upstream selector defaults to physical when available and
preserves the selected calibration in navigation links. Piece, recording,
search and figure-type filters work within the selected result set.

Open `FREQNESS_Output/report/index.html`, or serve `FREQNESS_Output` on
localhost for the in-app browser. The Python script uses the standard
library and arranges original MATLAB figures without recomputing analyses.
The frequency-reference selector enables beat-relative results only when
corresponding validated catalogs are supplied.

## Empirical tempo and beat-relative segments

`FREQNESS_Orchestra_Tempo.m` is a separate, chronological audio-analysis
stage for the **existing WAV segments**. It does not infer full-piece audio,
apply Peter Keller's newer score-section boundaries, or alter motion data.
The original segment key is piece, recording, manifest index and label.
Peter's piece-level BPM ranges are retained as context only; they are not
assigned to unmatched segments.

The script uses the official [MIRtoolbox](https://github.com/olivierlar/mirtoolbox),
pinned to revision `71d6265151ec4f6bd24773e1412193c4ab9ef972`, in the ignored
`FREQNESS_Output/_Dependencies` directory. Its accompanying
`source_provenance.json` records source-file SHA-256 hashes, which are checked
before use. Third-party source is not modified. This dependency and its
provenance manifest must be present locally; they are not committed with
private study outputs.

The configured method estimates framewise tempo with `mirtempo` using
spectral flux, autocorrelation and tracking, searching 40–300 BPM. Stereo
audio is averaged and antialias-resampled to 11025 Hz for this audio stage
only. Eight-second windows advance by one second. The representative tempo
is the median of finite, in-range tracked BPM values; `beat_hz=BPM/60`.
Candidates, framewise estimates, peak strengths, source hashes and screening
reasons remain available in resumable per-segment caches and the tempo
catalog. Half/double-tempo ambiguity, instability, insufficient coverage,
silence and short input remain explicit review states, never zero tempos.
Three valid frames are required, so many clips below approximately ten
seconds will remain ineligible despite the four-second minimum input.

Both tempo execution and automatic acceptance default to **off**. The
28 November 2026 synthetic validation stopped this stage: a known 120-BPM
pulse returned scalar candidates/tracking alongside 1278 frame timestamps;
the untracked candidate was 119.988 BPM but the tracked value was 129.737 BPM.
The shape guard failed before acceptance. Three other tempo tests passed,
but no real-audio tempo analysis or beat-normalized study cores were run.
The user deferred task 3 for discussion after this failure. Execution stays
disabled; the beat-grid integration is tested scaffolding for a future
validated tempo catalog.
The configured MIR path requires further investigation or a separately
agreed alternative; do not relax the tests or enable it for inference.
Diagnostics are retained in the ignored run folder's `task3_blocker.json`
and `tempo_shape_probe.json`. No MIR source was changed. A stable
periodicity estimate is not proof of the musically intended beat level.
Only a catalog row with `status="accepted"`, `eligible_flag=true` and a
finite positive beat frequency can enter normalized core analysis.

For a validated tempo catalog, set these Main settings in Block 0:

```matlab
CFG.common.frequency_reference = 'beat';
CFG.common.tempo_file = '/path/to/tempo_catalog.json';
CFG.common.beat_ratios = (1:16)/8;
CFG.block1.run_flag = false;
CFG.block2.run_flag = true;
CFG.block3.stages = "segment_piece";
```

Each segment is estimated on `frex=beat_hz*beat_ratios`, in physical Hz.
`GED.frex` retains Hz; `GED.frex_norm=GED.frex/GED.beat_frex` records the
dimensionless frequency/beat ratio. This follows the Dance study's
trial-specific frequency construction. The shared ratio grid is 1/8 to 2
beats rather than extending to 4: fast score tempos would otherwise exceed
the 12.5-Hz Nyquist limit. Any segment whose complete configured grid reaches
Nyquist is held for review; bins are never silently clipped. These are new
core analyses, not relabelled existing 96-bin Hz spectra.

Each calibration/reference combination has its own output route, keyed by
the exact tempo-catalog hash and ratio grid. WAV hashes, CSV paths and
manifest hashes must match the accepted tempo mapping. Missing or review
tempos are recorded in the segment core index and skipped. Source clocks
remain unresolved: exact file identity does not establish audio/frame
alignment, and no time warping or correction is applied.

Beat landscapes align observations on the shared ratio grid, while spatial
patterns retain their selected physical-Hz peak. Crosses mark bins below the
saved minimum cycle count (default three). Triangles mark filter FWHM below
the segment's Fourier spacing, `1/duration`; the saved metadata include
cycles, FWHM, spacing and bins per FWHM. These are descriptive resolution
diagnostics, not a validity guarantee. All bins remain visible. Include
these segment catalogs as additional `--visualization-path` arguments to
enable the explorer's frequency/beat selector.


## Validation

Run the study tests and shared filter-calibration checks from MATLAB:

```matlab
results = runtests({ ...
    'Rosso_et_al_Orchestra_inPreparation/tests/testOrchestraPipeline.m', ...
    'Rosso_et_al_Orchestra_inPreparation/tests/testOrchestraSpatialDisplays.m', ...
    'Rosso_et_al_Orchestra_inPreparation/tests/testOrchestraBeatCore.m', ...
    'FREQNESS_Mocap_Toolbox/tests/testFREQNESSFilterWidthsMocap.m'});
assertSuccess(results)
```

The tests execute the actual script against temporary deterministic CSVs,
compare estimates with direct calls to the unchanged toolbox, check complete
frame/track retention and normalization, exercise missing/invalid inputs and
cache reuse, verify H2 against its defining equation, check numeric session
ordering and boundary/tied peak selection, and generate figures independently
of the input data. They do
not execute the full private dataset.

The spatial tests also inspect actual image/scatter values, verify XY
rotation invariance and all-zero behavior, and hash cores before/after
visualization. Run the gallery contract tests with:

```sh
python3 Rosso_et_al_Orchestra_inPreparation/tests/test_orchestra_report.py
```

Run `tests/testOrchestraTempo.m` separately with the pinned MIR dependency
available, before any real-audio tempo run. Its known 120-BPM synthetic pulse
test must pass without relaxing the tolerance. Then inspect representative
real audio with automatic acceptance disabled before enabling screening for
the remaining segments. New score-section mapping, musician names and
not-playing exclusions remain deferred.

## November 2026 implementation status

| Task | Status | Criticality or follow-up |
| --- | --- | --- |
| 1 — Sampling rate | Implemented: 25 Hz, user-confirmed | Independent camera metadata and audio/frame alignment remain unresolved. |
| 2 — Filter comparison | Complete: physical and matched legacy | Both calibrations have 27 full-piece and 351 segment cores; the new legacy spectra reproduce the archive exactly. |
| 3 — Segment tempo | Deferred by the user after MIR validation failed | Execution remains off; no real-audio or beat-normalized study result has been published. |
| 4 — Spatial displays | Complete: both calibrations exported | Absolute coordinates and XY norms retain signed cores and record their display denominators. |
| 5 — Musician labels | Deferred | Existing numeric track IDs remain. |
| 6 — Playing annotations | Deferred | No activity masking or covariance exclusion is applied. |
| 3+6 — Section/tempo integration | Deferred | Existing WAV boundaries need a verified mapping to Peter's newer score sections. |

The integrated synthetic study/calibration suite passed 34 MATLAB tests;
the gallery contract suite passed four Python tests. The separate tempo
suite passed three tests and failed the known-pulse output-contract test.
The read-only core audit checked all 756 estimates, sampling provenance,
complete spectra, filter widths, retained samples and source-file metadata.
Across 378 comparisons, new and archived legacy eigenvalues were identical.
All 378 archived cores and 46 toolbox files retained their original hashes.
The final display audit checked all 756 published observations against the
audited cores: maximum H2 and spatial-display differences were both zero.
The explorer contains 2,396 existing original PNGs and passed browser checks
for calibration switching, navigation, filters, image loading and enlargement.

Physical segment results require particular care at the low-frequency edge:
175 of 351 maxima are at 0.5 Hz and three at 10 Hz; 12 segments have the lowest
0.5-Hz filter's FWHM below `1/duration`. No segment has fewer than three
cycles at 0.5 Hz. This illustrates why cycle count alone does not establish
adequate narrowband resolution. The frequency grid and supplied data are
unchanged; these descriptive diagnostics are retained with the run outputs.
