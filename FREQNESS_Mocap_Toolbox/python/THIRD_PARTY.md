# Attribution and licences

Original MoCap toolbox code: Mattia Rosso, Felix Bigand, Leonardo Bonetti,
GPL-3.0-or-later. The complete licence is included in the installed package
under `freqness_mocap/licenses/LICENSE.txt` and in the repository root.

The brain FREQ-NESS Python package provided the architecture and interface
model. Its contributors are Mattia Rosso, Chiara Malvaso and Leonardo Bonetti.
This MoCap implementation was translated against the current MoCap MATLAB
code; it does not import the brain Python package at runtime.

- `filterFGx.py` implements Mike X Cohen's frequency-domain Gaussian filtering
  as adapted in the MoCap MATLAB `filterFGx.m`; credit remains with Mike X
  Cohen (mikexcohen@gmail.com).
- `_embedding.py` adapts Hui Yang's `mutual.m` and `false_nearest.m`, retaining
  the original binning, nearest-neighbour search and next-sample FNN criterion.
  Copyright (c) 2016, Hui Yang; BSD-3-Clause. The full notice is distributed as
  `freqness_mocap/licenses/Hui-Yang-BSD-3-Clause.txt`.
- `FREQNESS_RQA_Mocap.py` adapts the line-counting conventions of Norbert
  Marwan's CRP `dl.m` (2016) and `tt.m` (2017), Copyright (c) 2008–,
  Potsdam Institute for Climate Impact Research; Copyright (c) 2001–2008,
  Potsdam University. GNU GPL version 2 or later; complete text is distributed
  as `freqness_mocap/licenses/GPL-2.0-or-later.txt`.

The original MATLAB dependencies, their notices, source links and retained
revisions are documented in `FREQNESS_ExternalFunctions/README.md`.
NumPy, SciPy, Matplotlib and h5py retain their respective upstream licences.
