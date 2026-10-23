# External functions

This directory is reserved for third-party MATLAB dependencies that may be
redistributed. Record the upstream source, version, licence, and any local
changes for each dependency. Dependencies that cannot be redistributed should
instead be documented in the toolbox installation instructions.

Currently required:

- `filterFGx.m` for frequency-domain Gaussian filtering during network
  estimation;
- `FREQNESS_AnalyticSignal.m`, required by the current `filterFGx.m` version,
  is an internal FREQ-NESS helper included in `FREQNESS_Functions/Supporting` rather
  than a third-party dependency;
- `mutual.m`, `false_nearest.m`, and `pss.m` for corrected JRQA parameter tuning;
- `dl.m`, `tt.m`, and `entropy.m` from the same CRP Toolbox subset for the
  phase-space and corrected JRQA metrics. These three files are byte-identical to the files
  used by `BROADNESS_PhaseSpace_RQA`.

## Included CRP Toolbox subset

The retained dependency subset includes JRQA code distributed with
the CRP Toolbox by Norbert Marwan under the GNU General Public License, version
2 or later. The included `jrqa.m` identifies itself as revision 2.11 dated
2016-03-03.

The original non-interactive CRP subset contains:

- `jrqa.m`, `crp2.m`, `dl.m`, `entropy.m`, and `tt.m`;
- `private/check_stop.m`, `private/init_properties.m`,
  `private/is_crp_plugin.m`, and `private/splash_gpl.m`.

Both toolbox RQA implementations use `dl.m`, `tt.m`, and `entropy.m` for
recurrence metrics; neither calls `jrqa.m` or the CRP private helpers. The
obsolete local `RPparam.m` tuning routine and historical study recomputation
have been removed. The upstream CRP files are not a selectable toolbox method.

The complete CRP Toolbox is not bundled. The local change in
`private/splash_gpl.m` allows it to locate the colocated `jrqa.m` when the
full-toolbox `crp.m` entry point is absent. The accompanying `.gpl.crp` marker
keeps automated `silent` analyses non-interactive. The JRQA numerical routines
are otherwise unchanged.
