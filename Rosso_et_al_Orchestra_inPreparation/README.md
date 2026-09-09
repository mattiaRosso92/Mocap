# Orchestra study

Study-specific workspace for the orchestra application of FREQ-NESS MoCap.

The pipeline uses physical logarithmic filter widths by default. Set
`filter_width_calibration='legacy'` to reproduce the former automatic schedule
as an explicit width vector. Physical and legacy outputs are written below
separate `<physical|legacy>_<logarithmic|linear>` folders, and each saved GED
structure records the calibration, filter type, and realized `fwhm`.
