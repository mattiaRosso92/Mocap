function [FREQ,qc] = EmpaticMirroring_CorrectNumericalEigenvalues( ...
    FREQ,tolerance)
%EMPATICMIRRORING_CORRECTNUMERICALEIGENVALUES Remove negligible GED noise.
%   Material negative eigenvalue mass is rejected. Accepted negative values
%   are clipped and each spectrum is rescaled to preserve its original sum.

eigenspectrum = FREQ.evals;
if ~isnumeric(eigenspectrum) || ~isreal(eigenspectrum) || ...
        any(~isfinite(eigenspectrum),'all')
    error('EmpaticMirroring:LandscapeEigenvalues', ...
        'FREQ.evals must contain real finite eigenvalues.');
end

nfrex = size(eigenspectrum,2);
nsubs = size(eigenspectrum,3);
correctedCount = 0;
maximumNegativeMagnitude = 0;
maximumNegativeMassRatio = 0;
for subi = 1:nsubs
    for frexi = 1:nfrex
        values = eigenspectrum(:,frexi,subi);
        negativeMask = values < 0;
        if ~any(negativeMask)
            continue
        end

        negativeMass = sum(abs(values(negativeMask)));
        positiveMass = sum(values(values > 0));
        negativeMassRatio = negativeMass/max(positiveMass,realmin);
        if positiveMass <= 0 || negativeMassRatio > tolerance
            error('EmpaticMirroring:LandscapeNegativeEigenvalues', ...
                ['FREQ.evals contains material negative mass (ratio %.6g; ' ...
                'allowed %.6g) at frequency %d, participant %d.'], ...
                negativeMassRatio,tolerance,frexi,subi);
        end

        originalSum = sum(values);
        values(negativeMask) = 0;
        values = values.*(originalSum/sum(values));
        eigenspectrum(:,frexi,subi) = values;
        correctedCount = correctedCount + nnz(negativeMask);
        maximumNegativeMagnitude = max(maximumNegativeMagnitude, ...
            max(abs(FREQ.evals(negativeMask,frexi,subi))));
        maximumNegativeMassRatio = max(maximumNegativeMassRatio, ...
            negativeMassRatio);
    end
end

FREQ.evals = eigenspectrum;
qc = struct( ...
    'correctedCount',correctedCount, ...
    'maximumNegativeMagnitude',maximumNegativeMagnitude, ...
    'maximumNegativeMassRatio',maximumNegativeMassRatio, ...
    'tolerance',tolerance, ...
    'policy',string(['Clip and sum-preserving rescale only numerical ' ...
    'negative GED eigenvalues whose negative/positive mass ratio is ' ...
    'within tolerance; reject material negative spectra.']));

end
