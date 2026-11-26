"""MoCap dataset discovery. Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
from pathlib import Path
import warnings
import numpy as np
from scipy.io import loadmat
from ._utils import array


def _load_numeric(path):
    try:
        contents = {k:v for k,v in loadmat(path).items() if not k.startswith("__")}
    except NotImplementedError:
        try:
            import h5py
        except ImportError as exc:
            raise ImportError("MATLAB v7.3 input requires freqness-mocap[mat73]") from exc
        with h5py.File(path,"r") as handle:
            names = [k for k in handle if not k.startswith("#")]
            if len(names)!=1 or not isinstance(handle[names[0]],h5py.Dataset):
                raise ValueError(f"{path.name} must contain exactly one numeric array")
            dataset = handle[names[0]]
            if dataset.dtype.kind not in "fiu":
                raise ValueError(f"{path.name} must contain a real numeric array")
            # MATLAB v7.3 stores dimensions in reverse HDF5 order.
            contents = {names[0]:np.asarray(dataset).transpose()}
    if len(contents)!=1:
        raise ValueError(f"{path.name} must contain exactly one data array")
    data = array(next(iter(contents.values())),path.name,finite=False,ndim=3)
    if data.ndim<2 or data.shape[0]%3 or data.shape[1]<2 or np.isinf(data).any():
        raise ValueError(f"{path.name} must contain XYZ x time x participants without Inf")
    return data


def FREQNESS_Startup_Mocap(path_home=None):
    """Return allData, dataLabels, toolbox root, following MATLAB folder ordering.

    FREQNESS_Data/<dataset> contains one group array or one .mat per participant.
    Numeric MATLAB v7 files work directly; v7.3 uses the optional h5py extra.
    Empty dataset directories are retained as None with a warning.
    """
    if path_home is None:
        roots = [Path.cwd(),*Path(__file__).resolve().parents]
        root = next((p for p in roots if (p/"FREQNESS_Data").is_dir()),None)
        if root is None:
            raise FileNotFoundError("Pass the toolbox root containing FREQNESS_Data")
    else:
        root = Path(path_home).expanduser().resolve()
    directory = root/"FREQNESS_Data"
    if not directory.is_dir():
        raise FileNotFoundError(directory)
    allData, labels = [], []
    for folder in sorted((p for p in directory.iterdir() if p.is_dir() and not p.name.startswith(".")),key=lambda p:p.name.lower()):
        labels.append(folder.name)
        paths = sorted(folder.glob("*.mat"),key=lambda p:p.name.lower())
        if not paths:
            warnings.warn(f"No .mat files in {folder}",RuntimeWarning)
            allData.append(None)
            continue
        arrays = [_load_numeric(path) for path in paths]
        if len(arrays)==1:
            data = arrays[0]
            allData.append(data[:,:,None] if data.ndim==2 else data)
        else:
            if any(x.ndim!=2 or x.shape!=arrays[0].shape for x in arrays):
                raise ValueError(f"{folder.name}: participant arrays must be 2-D with matching dimensions")
            allData.append(np.stack(arrays,axis=2))
    return allData, labels, root
