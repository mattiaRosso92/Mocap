# External functions

This directory is reserved for third-party MATLAB dependencies that may be
redistributed. Record the upstream source, version, licence, and any local
changes for each dependency. Dependencies that cannot be redistributed should
instead be documented in the toolbox installation instructions.

Currently required:

- `filterFGx.m` for frequency-domain Gaussian filtering during network
  estimation;
- `FREQNESS_AnalyticSignal.m`, required by the current `filterFGx.m` version
  (this FREQ-NESS helper may alternatively live in `FREQNESS_Functions`);
- `RPparam.m` and `jrqa.m` from the CRP Toolbox for recurrence-based group
  analyses.
