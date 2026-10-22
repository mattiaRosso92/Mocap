function fwidth = FREQNESS_ComputeLegacyFilterWidths_Mocap(frex,filter)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP version
%
% ========================================================================
%  This reproducibility helper reconstructs the automatic filter-width
%  schedule used before physical FWHM calibration. The legacy schedule is
%  intentionally dependent on the number of frequency bins and should be
%  passed explicitly through the fwidth option. It is not recommended for
%  new analyses.
%
%  Each participant column is treated exactly as the former estimator did:
%  its first frequency is matched to the nearest point on the 0.1:0.1:10 Hz
%  reference grid, whose widths span 0.01:logspace:1 Hz. Logarithmic or
%  linear widths then extend from that starting value to starting value
%  multiplied by nFrex.
%
% ------------------------------------------------------------------------
%  INPUTS:
% ------------------------------------------------------------------------
%  - frex   : Ascending [nFrex x nParticipants] array of positive finite
%             frequencies in Hz. Use a column vector for one participant.
%  - filter : 'logarithmic' (default) or 'linear'.
%
% ------------------------------------------------------------------------
%  OUTPUT:
% ------------------------------------------------------------------------
%  - fwidth : Explicit legacy [nFrex x nParticipants] FWHM values in Hz.
%
% ========================================================================

if nargin < 1 || ~isnumeric(frex) || ~isreal(frex) || ...
        isempty(frex) || ~ismatrix(frex) || any(~isfinite(frex(:))) || ...
        any(frex(:) <= 0)
    error(['frex must be a non-empty [nFrex x nParticipants] array of ' ...
        'positive finite frequencies.']);
end

if any(diff(frex,1,1) < 0,'all')
    error('Each participant column in frex must be sorted in ascending order.');
end

if nargin < 2 || isempty(filter)
    filter = 'logarithmic';
end

if ~(ischar(filter) || (isstring(filter) && isscalar(filter))) || ...
        ~(strcmpi(filter,'logarithmic') || strcmpi(filter,'linear'))
    error('filter must be either ''logarithmic'' or ''linear''.');
end

frex = double(frex);
nfrex = size(frex,1);
nsubs = size(frex,2);
reference_frequencies = linspace(.1,10,100);
reference_widths = logspace(log10(.01),log10(1),100);
fwidth = zeros(nfrex,nsubs);

for subi = 1:nsubs
    [~,reference_index] = min(abs( ...
        reference_frequencies-frex(1,subi)));
    starting_width = reference_widths(reference_index);

    if strcmpi(filter,'logarithmic')
        fwidth(:,subi) = logspace(log10(starting_width), ...
            log10(starting_width*nfrex),nfrex)';
    else
        fwidth(:,subi) = linspace(starting_width, ...
            starting_width*nfrex,nfrex)';
    end
end

end
