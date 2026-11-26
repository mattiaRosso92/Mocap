# FREQ-NESS MoCap

## Download the toolbox

**[Download the latest FREQ-NESS MoCap Toolbox release](https://github.com/mattiaRosso92/Mocap/releases/latest/download/FREQNESS_Mocap.zip)**

The recommended archive contains **both MATLAB and Python** and extracts to the
short folder name `FREQNESS_Mocap`, following the brain FREQ-NESS release approach.
It excludes study pipelines, research data and generated results. See the
[toolbox setup instructions](FREQNESS_Mocap_Toolbox/README.md#quick-start).
For individual versions and Python wheel downloads, see [all releases](https://github.com/mattiaRosso92/Mocap/releases).
The download link becomes available after the first stable release is published
and its packaging workflow finishes successfully.

## Overview

MATLAB/Python toolbox and study pipelines for frequency-resolved analysis of
full-body motion-capture data.

FREQ-NESS MoCap applies frequency-resolved network estimation to multivariate
full-body kinematics. It is designed to support analysis of single participants
and interaction analyses involving dyads. Phase-space RQA also supports larger
groups, with one participant per coordinate of the joint state.

## Repository structure

```text
FREQNESS_Mocap_Toolbox/
  FREQNESS_Startup_Mocap.m     Toolbox initialization and dataset loading
  FREQNESS_MainPipeline_Mocap.m General block-based MATLAB workflow
  FREQNESS_Functions/          Reusable MATLAB toolbox functions
    Analysis/                 Network and coordination analyses
      private/                Internal temporal-coordination implementations
    Visualization/            Visualizer only
    Supporting/               Signal-processing and analysis helpers
  FREQNESS_ExampleScripts/     Reserved for dataset-independent examples
  FREQNESS_Data/               Small example or reference data only
  FREQNESS_ExternalFunctions/  Documented third-party MATLAB dependencies
  python/                      Python package, entry script, notebook and tests
  VERSION                      Shared MATLAB/Python release version

Rosso_et_al_Dance_inPreparation/
Rosso_et_al_EmpaticMirroring_inPreparation/
Rosso_et_al_Orchestra_inPreparation/
                               Study-specific pipelines and analyses
```

This mirrors the public MEEG FREQ-NESS repository by separating reusable
toolbox code from study-specific analysis code. Study folders may depend on the
toolbox, but reusable toolbox code should not depend on a particular study.

## Analysis levels

The MATLAB and Python toolbox implementations contain three levels of analysis:

1. `FREQNESS_NetworkEstimation_Mocap` performs the core participant-level
   frequency-resolved decomposition.
2. `FREQNESS_EffectDim_Mocap` and `FREQNESS_Visualizer_Mocap` provide
   second-order characterization of the effective dimensionality, estimated
   network landscape, and bodily activation patterns.
3. `FREQNESS_TimeCoord_Mocap` and `FREQNESS_SpaceCoord_Mocap` provide
   third-order temporal and spatial coordination analyses. TimeCoord defaults
   to phase-space RQA on non-standardized time series; JRQA is selected with
   `'method','jrqa'`. Normalization is optional through `'standardize',true`.
   JRQA supports a validated route
   with explicit anti-alias filtering, delay-embedding, recurrence threshold,
   Theiler exclusion, and complete provenance. Historical JRQA comparisons
   can read saved study outputs, but the obsolete computation is not available.

## Python toolbox

The Python package follows the brain FREQ-NESS public function names, dataclass
result and editable pipeline/notebook pattern, using a `src/` package layout while preserving
the MoCap MATLAB algorithms, array dimensions and defaults. Install from the
repository root:

```sh
python -m pip install './FREQNESS_Mocap_Toolbox/python[plot,mat73]'
```

See the [Python guide](FREQNESS_Mocap_Toolbox/python/README.md) for examples,
MATLAB/Python conventions, dependencies and numerical parity tests. MATLAB
is not needed to run the Python package. The study scripts remain MATLAB/R;
this port does not silently replace their computations or saved outputs.

## Reproduce the Dyadic Dance study

Follow the [study instructions](Rosso_et_al_Dance_inPreparation/README.md)
for data placement, dependencies, execution order and output locations.
The [public dataset](https://doi.org/10.48557/UR2GBG) was introduced by
Bigand et al. (2024). Raw data and analysis outputs are not included in Git.

The publication defaults use all 35 dyads and 1119 retained trials, GED on
positions with the study's legacy logarithmic filter widths, and the 10–45 s
window for phase-space RQA. Main and supplementary workflows share these
settings. Outputs are written under repository-level `Dance_Data`; external
cache imports are disabled by default.

MATLAB is required for estimation and figures; R is required for statistical
models. The optional supplement builder requires Python, python-docx and Pillow.
The study README lists the required R packages and commands.

The remaining study directories are retained as separate work areas so their
pipelines, outputs, and statistical analyses do not become part of the reusable
toolbox API.

## Versioned releases

`FREQNESS_Mocap_Toolbox/VERSION` and the Python `_version.py` must agree.
Version **1.0.0** is prepared as the first stable MATLAB/Python release. The
Python package metadata reads its version automatically from `_version.py`.
The parity workflow runs Python tests/builds on Linux, macOS and Windows and
generates fresh MATLAB reference outputs for cross-language regression tests.

To publish after merging the release PR and passing checks:

1. Create a GitHub release with tag `v1.0.0`, targeting the merged `main` commit.
2. Title it `FREQ-NESS MoCap v1.0.0`; leave **This is a pre-release** unchecked
   and select **Set as latest release**.
3. Publish and wait for **Package FREQ-NESS MoCap release** to succeed. It reruns
   validation, checks version/tag agreement, and attaches `FREQNESS_Mocap.zip`,
   a Python wheel and a Python source distribution from that same tagged commit.
4. Confirm all three assets are present and the download link above works.

This is the brain toolbox's publish-and-attach approach, with additional Python
distributions and parity validation. It assumes mutable GitHub releases: if
immutable releases are enabled, assets must instead be attached to a draft
before publication and the workflow must be adapted first. No action here
publishes to PyPI. Do not move an already published tag to different code;
subsequent fixes should receive a new version and tag.

## License

The project's original code is licensed under the GNU General Public License,
version 3 or (at your option) any later version (SPDX: GPL-3.0-or-later).
See [LICENSE](LICENSE) for the complete terms. Existing authorship notices
remain applicable.

Bundled third-party files retain their original copyright notices and terms;
the project license does not relicense them. See the
[dependency notices](FREQNESS_Mocap_Toolbox/FREQNESS_ExternalFunctions/README.md).
