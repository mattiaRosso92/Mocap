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

- **Sampling rate: 25 Hz**, retained from the original orchestra script. The
  handover's audio/frame mappings and 30/40-fps metadata remain unresolved.
  `srate_confirmed_flag=false` produces a warning and records the assumption
  in every core. Confirm the processed-data clock before interpreting Hz or
  seconds; change the rate and confirmation setting only from that evidence.
- **Frequency grid: 0.5:0.1:10 Hz.** Historical logarithmic widths remain the
  default, passed explicitly to the current estimator. Set
  `CFG.common.filter_width_calibration='physical'` to use the current
  frequency-calibrated widths. Both choices are saved and routed separately.
- **Regularisation: 0.01.** Four components retain spatial patterns,
  eigenvectors, and time series. The complete normalized eigenspectrum is
  retained independently of that component count; landscapes default to 20
  components. The longest supplied recording needs approximately 103 MiB for
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
  03_Visualization/<full_piece|segment_piece>/...
```

The settings signature distinguishes exact frequency vectors, rates, retained
component counts, regularisation, calibration, and coordinate policy. Each
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

Block 3 has independent stage, recording, and section selectors. It consumes
the frequencies, sampling rate, labels, and layout saved with each core.
The default pattern is component 1 at 2 Hz. Requested frequencies are mapped
to actual analyzed frequencies with a warning for substitution; both are
recorded in `visualization_info.mat` alongside the figure paths.

The current toolbox visualizer is called with animation and skeletal links
disabled. The pipeline then sets spatial axes to an overhead view with image
Y increasing downward, arranges X/Y/Z panels side by side, and sizes labelled
matrices for the track count. This changes only presentation, not the coordinates
or signed activation values. Z is labelled as an unmeasured placeholder. Figures are
saved as 200-dpi PNGs and closed by default. For interactive inspection, set
`figure_visibility='on'` and `close_figures_flag=false`. Figure replacements
also require the visualization `overwrite_flag`.

## Validation

Run the study tests and shared filter-calibration checks from MATLAB:

```matlab
results = runtests({ ...
    'Rosso_et_al_Orchestra_inPreparation/tests/testOrchestraPipeline.m', ...
    'tests/testFREQNESSStudyFilterCalibration.m'});
assertSuccess(results)
```

The tests execute the actual script against temporary deterministic CSVs,
compare estimates with direct calls to the unchanged toolbox, check complete
frame/track retention and normalization, exercise missing/invalid inputs and
cache reuse, and generate figures independently of the input data. They do
not execute the full private dataset.
