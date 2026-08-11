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
- `RPparam.m` and a minimal JRQA dependency subset from the CRP Toolbox for
  recurrence-based temporal coordination.

## Included CRP Toolbox subset

The temporal-coordination implementation uses the JRQA code distributed with
the CRP Toolbox by Norbert Marwan under the GNU General Public License, version
2 or later. The included `jrqa.m` identifies itself as revision 2.11 dated
2016-03-03.

Only the runtime files exercised by non-interactive JRQA calls are included:

- `jrqa.m`, `crp2.m`, `dl.m`, `entropy.m`, and `tt.m`;
- `private/check_stop.m`, `private/init_properties.m`,
  `private/is_crp_plugin.m`, and `private/splash_gpl.m`.

The complete CRP Toolbox is not bundled. The local change in
`private/splash_gpl.m` allows it to locate the colocated `jrqa.m` when the
full-toolbox `crp.m` entry point is absent. The accompanying `.gpl.crp` marker
keeps automated `silent` analyses non-interactive. The JRQA numerical routines
are otherwise unchanged.
