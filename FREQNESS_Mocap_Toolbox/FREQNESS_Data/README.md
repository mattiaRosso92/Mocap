# Example data

This directory is reserved for small distributable example or reference data.
Raw, identifiable, unpublished, or large study datasets should not be committed
to the repository.

Create one subfolder per dataset processed by the general pipeline. Each
dataset folder may contain either:

1. one `.mat` file holding a numeric
   `[XYZ marker coordinates x time x participants]` array; or
2. one `.mat` file per participant, each holding a numeric
   `[XYZ marker coordinates x time]` matrix.

Participant files are sorted alphabetically and concatenated along the third
dimension. Every `.mat` file must contain exactly one data array, and marker
rows must repeat in `X, Y, Z` order. Missing coordinates may be encoded as
`NaN`; network estimation detects and reconstructs supported gaps while
retaining their sample indices for exclusion. Infinite values are invalid.
