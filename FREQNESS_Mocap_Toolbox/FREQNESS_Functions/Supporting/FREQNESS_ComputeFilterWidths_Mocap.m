function fwidth = FREQNESS_ComputeFilterWidths_Mocap(frex,filter)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP version
%
% ========================================================================
%  This function computes physically calibrated Gaussian-filter widths
%  from the analyzed frequencies. Each participant column is calibrated
%  from its numerical frequency range in Hz, independently of the number
%  or spacing of frequency bins.
%
%  The logarithmic schedule (default) decreases spectral selectivity
%  smoothly from Q = 7 at the lowest frequency to Q = 3.5 at the highest:
%
%      t(f) = log(f/fmin) / log(fmax/fmin)
%      Q(f) = 7 * (3.5/7)^t(f)
%      FWHM(f) = f / Q(f)
%
%  The linear schedule uses constant Q = 5, so FWHM grows linearly with
%  centre frequency. For a single unique frequency, the logarithmic mode
%  uses the geometric midpoint Q = sqrt(7*3.5).
%
% ------------------------------------------------------------------------
%  INPUTS:
% ------------------------------------------------------------------------
%  - frex   : Non-empty [nFrex x nParticipants] array of positive finite
%             frequencies in Hz. Use a column vector for one participant.
%  - filter : 'logarithmic' (default) or 'linear'.
%
% ------------------------------------------------------------------------
%  OUTPUT:
% ------------------------------------------------------------------------
%  - fwidth : Positive [nFrex x nParticipants] FWHM values in Hz with the
%             same size and element order as frex. Columns are calibrated
%             independently.
%
% ------------------------------------------------------------------------
%  AUTHORS:
%  Mattia Rosso & Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%
% ========================================================================

if nargin < 1 || ~isnumeric(frex) || ~isreal(frex) || ...
        isempty(frex) || ~ismatrix(frex) || any(~isfinite(frex(:))) || ...
        any(frex(:) <= 0)
    error(['frex must be a non-empty [nFrex x nParticipants] array of ' ...
        'positive finite frequencies.']);
end

if nargin < 2 || isempty(filter)
    filter = 'logarithmic';
end

if ~(ischar(filter) || (isstring(filter) && isscalar(filter))) || ...
        ~(strcmpi(filter,'logarithmic') || strcmpi(filter,'linear'))
    error('filter must be either ''logarithmic'' or ''linear''.');
end

frex = double(frex);

if strcmpi(filter,'linear')
    fwidth = frex ./ 5;
    return
end

q_low = 7;
q_high = 3.5;
fwidth = zeros(size(frex));

for subi = 1:size(frex,2)
    this_frex = frex(:,subi);
    fmin = min(this_frex);
    fmax = max(this_frex);

    if fmin == fmax
        q_values = sqrt(q_low*q_high) * ones(size(this_frex));
    else
        log_position = log(this_frex./fmin) ./ log(fmax/fmin);
        q_values = q_low .* (q_high/q_low).^log_position;
    end

    fwidth(:,subi) = this_frex ./ q_values;
end

end
