"""Circular-shift JRQA null. Mattia Rosso, Felix Bigand, Leonardo Bonetti."""
import numpy as np
from ._utils import Struct, scalar, empty
from .FREQNESS_TimeCoord_Mocap import FREQNESS_TimeCoord_Mocap
from .FREQNESS_RQA_Mocap import FREQNESS_RQA_Mocap


def FREQNESS_JRQASurrogates_Mocap(FREQ, JRQA, target_frex, *, n_surrogates=100,
                                minimum_shift=None, random_seed=1, **kwargs):
    """Return observed records and surrogate records with one-sided (+1) p-values.

    Shift partner 2's RP on both axes, retaining geometry and eligibility.
    Local MT19937 state reproduces MATLAB's uniform/randi sampling; seed zero
    maps to MATLAB's default Twister seed 5489. Global NumPy RNG is untouched.
    """
    if "method" in kwargs or "parameters" in kwargs:
        raise ValueError("Surrogates use positional JRQA parameters and method='jrqa'")
    kwargs.pop("store_matrices", None)
    n_surrogates = scalar(n_surrogates, "n_surrogates", integer=True)
    random_seed = scalar(random_seed, "random_seed", integer=True, strict=False)
    observed = FREQNESS_TimeCoord_Mocap(FREQ, target_frex, method="jrqa", parameters=JRQA, store_matrices=True, **kwargs)
    rng = np.random.RandomState(5489 if random_seed == 0 else random_seed)
    surrogates = []
    for result in observed:
        nstates = result.EffectiveStateCount
        minimum = max(result.TheilerWindow+1, result.EmbeddingDimension*result.Delay) if empty(minimum_shift) else scalar(minimum_shift, "minimum_shift", integer=True)
        if minimum >= nstates // 2:
            raise ValueError("minimum_shift must be smaller than half the state count")
        shifts = minimum + np.floor(rng.random_sample(n_surrogates) * (nstates - 2*minimum + 1)).astype(int)
        rr, det = np.empty(n_surrogates), np.empty(n_surrogates)
        for i, shift in enumerate(shifts):
            rp = result.ParticipantRecurrencePlots[:, :, 0] & np.roll(result.ParticipantRecurrencePlots[:, :, 1], (shift, shift), axis=(0, 1)) & result.EligiblePairMask
            rr[i] = rp.sum() / result.EligiblePairCount
            det[i] = FREQNESS_RQA_Mocap(rp, result.Lmin, result.Vmin).det
        def zscore(value, null):
            sd = null.std(ddof=1) if len(null) > 1 else 0
            return (value - null.mean()) / sd if sd != 0 else np.nan
        surrogates.append(Struct(RR=rr, DET=det, Shifts=shifts, ObservedRR=result.RR, ObservedDET=result.DET,
                                 PValueRR=(1 + np.sum(rr >= result.RR))/(n_surrogates + 1),
                                 PValueDET=(1 + np.sum(det >= result.DET))/(n_surrogates + 1),
                                 ZScoreRR=zscore(result.RR, rr), ZScoreDET=zscore(result.DET, det),
                                 NullMethod="circular_shift_partner_2"))
    return observed, surrogates
