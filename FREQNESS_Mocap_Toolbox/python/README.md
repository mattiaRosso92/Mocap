# FREQ-NESS MoCap — Python

Python implementation of the current MoCap MATLAB toolbox. It follows the
brain FREQ-NESS named public functions, dataclass network result and editable
script/notebook workflow, packaged using a `src/` layout. The scientific reference
is MoCap MATLAB, including its conventions and explicit legacy-filter helper.
The MATLAB study pipelines and R models are not translated or modified.

## Install and run

Python 3.10 or later is required. The recommended
[combined MATLAB/Python download](https://github.com/mattiaRosso92/Mocap/releases/latest/download/FREQNESS_Mocap.zip)
extracts to `FREQNESS_Mocap`. From inside that extracted folder:

```sh
python -m pip install './python[plot,mat73]'
```

Alternatively, from the root of a Git clone:

```sh
python -m pip install './FREQNESS_Mocap_Toolbox/python[plot,mat73]'
```

NumPy and SciPy provide the numerical implementation. The `plot` extra adds
Matplotlib; `mat73` adds h5py for numeric MATLAB v7.3 input files. Neither MATLAB
nor the MATLAB Engine is required. Optional plotting dependencies are imported
only when needed. For development, use `pip install -e './FREQNESS_Mocap_Toolbox/python[test]'`.

```python
import numpy as np
from freqness_mocap import (
    FREQNESS_NetworkEstimation_Mocap, FREQNESS_EffectDim_Mocap,
    FREQNESS_TimeCoord_Mocap, FREQNESS_SpaceCoord_Mocap,
)

# data: XYZ coordinates × time × participants; frex: Hz.
frex = np.arange(1, 33) / 8
FREQ = FREQNESS_NetworkEstimation_Mocap(data, frex, srate=250, ncomps=4)
H2, ED = FREQNESS_EffectDim_Mocap(FREQ, figure=False)
spatial = FREQNESS_SpaceCoord_Mocap(FREQ, 1, Fisher=False)
temporal = FREQNESS_TimeCoord_Mocap(FREQ, 1, standardize=False)
rr = temporal[0].RR
```

Edit `FREQNESS_MainPipeline_Mocap.py` or use `FREQNESS_NotebookPipeline.ipynb`
for the general eight-block workflow. Startup reads numeric `.mat` datasets
from `FREQNESS_Data`; it accepts one group file or one file per participant
inside each dataset folder. v7.3 loading supports numeric arrays, not arbitrary
nested MATLAB objects. Outputs remain in memory: nothing is saved or overwritten
automatically. A wheel-only installation needs an explicit toolbox/data path.

## Public functions

| Layer | Functions |
| --- | --- |
| Setup | `FREQNESS_Startup_Mocap`, `FREQNESS_MainPipeline_Mocap` |
| Core | `FREQNESS_NetworkEstimation_Mocap` |
| Characterization | `FREQNESS_EffectDim_Mocap`, `FREQNESS_MetricProminence_Mocap` |
| Coordination | `FREQNESS_LandscapeSimilarity`, `FREQNESS_SpaceCoord_Mocap`, `FREQNESS_TimeCoord_Mocap` |
| Visualization | `FREQNESS_Visualizer_Mocap` |
| Recurrence support | `FREQNESS_RQA_Mocap`, `FREQNESS_PreprocessTimeCoord_Mocap`, `FREQNESS_JRQAParameters_Mocap`, `FREQNESS_JRQASurrogates_Mocap` |
| Signal support | `FREQNESS_ComputeFilterWidths_Mocap`, `FREQNESS_ComputeLegacyFilterWidths_Mocap`, `FREQNESS_InterpolateGaps_Mocap`, `FREQNESS_AnalyticSignal`, `filterFGx` |

`FREQNESSResult` is a dataclass. Other named outputs use attribute-access
structures (`Struct`); coordination returns a list of metric-level records
with an additional `.figures` attribute. Dictionaries and attribute-based
structures can be supplied where MATLAB uses structures. Use Python keyword
arguments in place of MATLAB name-value pairs; retain public spellings such
as `regularisation` and `Fisher`.

## Numerical conventions

- Data keep MATLAB axis order: coordinates × time × participants. A 2-D input
  represents one participant. XYZ coordinates remain interleaved by marker.
- `FREQ.evals`: all coordinates × frequencies × participants, independently
  of `ncomps`; each full spectrum sums to 100. `evecs` and `pats`: coordinates
  × retained components × frequencies × participants. `ts`: retained
  components × time × frequencies × participants. Singleton axes are retained.
- Public component numbers and sample-index metadata (`bad_segments`, etc.)
  remain **one-based**, for interchange with MATLAB. Python list/array indexing
  is still zero-based. Frequencies and widths may be participant-specific.
- GED on positions remains the default. `method='pca'` decomposes the same
  narrowband covariance. `kinematics='velocity'` differentiates supplied
  positions before filtering: N positions give N−1 midpoint velocities.
  `FREQ.method`, `kinematics`, `sample_offset` and gap provenance are retained.
- Automatic widths use physical frequencies. Historical bin-count-dependent
  widths require explicit `FREQNESS_ComputeLegacyFilterWidths_Mocap` output
  passed as `fwidth`; they are not restored as a default.
- Eigenvector signs are arbitrary. Parity tests align a vector and its score
  together, and compare complete subspaces when PCA eigenvalues are tied.
- Gap interpolation preserves observed samples. Reconstructed samples are
  excluded from covariance and phase-space recurrence calculations. Velocity
  exclusion masks include both differences adjacent to each bad position.
- `FREQNESS_SpaceCoord_Mocap` correlates absolute spatial weights and returns
  one raw array by default; `Fisher=True` returns `atanh(r)` in that same output.
  For strict compatibility, it preserves MATLAB's existing use of the second
  partner's selected frequency-bin index for both patterns. Landscape similarity
  and pooled landscape/ED plots require a shared/aligned frequency grid; the
  toolbox does not silently infer beat-relative alignment for a study.

## Temporal coordination

```python
# Default: group-state phase-space RQA, one dimension per participant.
coord = FREQNESS_TimeCoord_Mocap(FREQ, target_frex,
    threshold_method='max_fraction', threshold=0.1, standardize=False)

# Corrected JRQA: explicit final parameters, exactly two participants.
coord = FREQNESS_TimeCoord_Mocap(FREQ, target_frex,
    method='jrqa', parameters={'m': 3, 'tau': 4},
    threshold_method='radius', threshold=0.8, standardize=True)
```

The JRQA example values illustrate the interface, not recommended universal
parameters. Tuning is a separate call to `FREQNESS_JRQAParameters_Mocap`;
selection/pooling belongs in the study. No historical implementation or removed
signature is available. Normalization is **off** by default throughout.

Phase-space RQA supports participant-specific frequencies/components, marked
gaps, and a 10,000-sample limit before forming dense quadratic-size distance/RP
matrices. Its `downsample` option is a stride, **not** anti-alias filtering.
Use `FREQNESS_PreprocessTimeCoord_Mocap` upstream when reducing sampling rate.
JRQA uses that helper internally and requires continuous, unmarked input.
`fixed_rr` targets the group RP for phase-space RQA but each marginal RP for
JRQA; those thresholds must not be interpreted as equivalent joint RR targets.

The standalone `FREQNESS_RQA_Mocap` returns `rr`, `det`, `l`, `entr`, `lam`,
`tt`, `vmax`, `div`. Line extraction preserves the bundled CRP functions'
packed-diagonal and vertical-edge conventions, including their degenerate
cases, to reproduce MATLAB rather than silently substituting another RQA
definition. Coordination RR uses its eligible-pair denominator, while the
standalone metric uses all matrix entries.

## Figures and animations

Landscape/ED plots retain log2 frequency axes, component colours and group SEM.
Spatial patterns retain the MATLAB diagonal X/Y/Z layout and participant
colours. Two-/three-participant phase-space plots and animations use
**time-coloured trajectory lines**, broken at excluded samples. Larger groups
use a coordinate-by-time heatmap. Plot changes never modify scientific arrays.
Keep returned animation objects alive when using an interactive backend.

Numerical quantities and plot meanings match MATLAB; rendering is not
pixel-identical across backends. Phase-space time colours use jet in both;
Python uses viridis in place of parula for distance and extended component palettes.
Velocity-derived outputs support static plots, but positional animation rejects
them rather than silently integrating velocity.

## Validation

Run the deterministic Python suite from this directory:

```sh
python -m pytest tests
```

Cross-language tests need an actual MATLAB-generated fixture. In MATLAB, add
`python/tests` to the path and call:

```matlab
generate_matlab_reference('/absolute/path/outside/git/matlab_reference.mat');
```

Then run Python with `FREQNESS_MATLAB_REFERENCE` set to that path. Without the
fixture, cross-language tests are explicitly skipped; pure Python tests still
run. CI generates the fixture afresh using MATLAB R2024b and runs both suites.
Coverage includes GED/PCA, velocity, interpolation, full-spectrum ED, metric
prominence, similarity, both RQA methods, AMI/FNN tuning, surrogates, and plotting.
Sample Dance data and comparison figures are intentionally not distributed.

## Packaging and releases

`../VERSION` and `src/freqness_mocap/_version.py` both specify **1.0.0**;
the GitHub release tag must be **v1.0.0**. Python package metadata reads
`_version.py` automatically. From this `python` directory, build locally
without publishing:

```sh
python -m pip install build
python -m build
python tools/package_release.py --tag v1.0.0 --output /tmp/FREQNESS_Mocap-1.0.0.zip
```

The ZIP uses a short `FREQNESS_Mocap/` root and includes source, docs, notebook,
tests and third-party notices, not studies, raw data, generated outputs or caches.
It refuses to overwrite an existing ZIP. A published GitHub release triggers
parity validation before attaching the ZIP, wheel and source distribution; it
does not publish to PyPI. Mark v1.0.0 as a stable/latest release, not a prerelease.
The current publish-and-attach workflow requires mutable releases; immutable
releases require uploading assets to a draft before publishing instead.
See [THIRD_PARTY.md](THIRD_PARTY.md) and installed
`freqness_mocap/licenses` for original attribution and licences.
