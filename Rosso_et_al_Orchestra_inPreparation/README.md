# Orchestra study

Study-specific workspace for the orchestra application of FREQ-NESS MoCap.

The pipeline uses the historical logarithmic filter widths by default and
passes the former automatic schedule as an explicit width vector. Set
`filter_width_calibration='physical'` for a new analysis using the toolbox's
frequency-calibrated widths. Physical and legacy outputs are written below
separate `<physical|legacy>_<logarithmic|linear>` folders, and each saved GED
structure records the calibration, filter type, and realized `fwhm`.
