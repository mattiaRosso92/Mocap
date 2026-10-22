function RQA = FREQNESS_RQA_Mocap(recurrence_plot,lmin,vmin)

% ========================================================================
%  FREQ-NESS MOCAP: RECURRENCE QUANTIFICATION ANALYSIS
% ========================================================================
%  Computes eight RQA measures from an existing binary recurrence plot.
%  Diagonal and vertical line lengths are each extracted once using the
%  bundled CRP Toolbox routines dl.m and tt.m; entropy.m uses natural logs.
%  No embedding, thresholding, normalization, or exclusion is performed here.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - recurrence_plot : Non-empty [nstates x nstates] binary matrix.
%  - lmin            : Optional minimum diagonal length (default: 2).
%  - vmin            : Optional minimum vertical length (default: 2).
%                      Lengths are positive integers in samples. Empty
%                      arguments use the defaults independently.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - RQA : Scalar structure containing:
%      .rr   : Recurrence rate, recurrent entries / all matrix entries.
%      .det  : Fraction of recurrent entries in diagonals >= lmin.
%      .l    : Mean length of those diagonals (samples).
%      .entr : Entropy of their length distribution (natural-log units).
%      .lam  : Fraction of recurrent entries in vertical lines >= vmin.
%      .tt   : Mean length of those vertical lines (samples).
%      .vmax : Maximum length of those vertical lines (samples).
%      .div  : Inverse longest retained diagonal (1/samples), omitting one
%              longest diagonal when at least two qualify, as in the
%              existing BROADNESS-based calculation (normally the identity).
%
%  With no recurrences, rr = 0 and the remaining measures are NaN. With
%  recurrences but no qualifying lines, det/lam = 0 and the corresponding
%  length, entropy, and divergence measures are NaN. Existing dl/tt line
%  counting conventions are preserved, including for masked plots.
%  If pairs have been excluded, callers must divide the recurrence count
%  by their eligible-pair count instead of using .rr; zeros alone cannot
%  distinguish exclusions from nonrecurrences.
%
%  Example: RQA = FREQNESS_RQA_Mocap(recurrence_plot,2,2);
%
% ------------------------------------------------------------------------
%  AUTHORS:
% ------------------------------------------------------------------------
%  Mattia Rosso, Felix Bigand, Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  felix.bigand@iit.it
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%
% ========================================================================


%% Handle optional arguments and validate inputs

narginchk(1,3)
if nargin < 2 || isempty(lmin)
    lmin = 2;
end
if nargin < 3 || isempty(vmin)
    vmin = 2;
end
if ~(islogical(recurrence_plot) || isnumeric(recurrence_plot)) || ...
        ~ismatrix(recurrence_plot) || isempty(recurrence_plot) || ...
        size(recurrence_plot,1) ~= size(recurrence_plot,2) || ...
        any(~isfinite(recurrence_plot(:))) || ...
        any(recurrence_plot(:) ~= 0 & recurrence_plot(:) ~= 1)
    error('recurrence_plot must be a non-empty square binary matrix.');
end
validate_minimum_length(lmin,'lmin')
validate_minimum_length(vmin,'vmin')
if exist('dl','file') ~= 2 || exist('tt','file') ~= 2 || ...
        exist('entropy','file') ~= 2
    error('RQA requires dl.m, tt.m, and entropy.m on the MATLAB path.');
end


%% Extract shared line lengths

[~,diagonal_lengths] = dl(recurrence_plot);
diagonal_lengths = diagonal_lengths(diagonal_lengths >= lmin);
[~,vertical_lengths] = tt(recurrence_plot);
vertical_lengths = vertical_lengths(vertical_lengths >= vmin);
nrecurrences = sum(recurrence_plot(:));


%% Compute recurrence and line-based measures

RQA = struct('rr',nrecurrences/numel(recurrence_plot), ...
    'det',NaN,'l',NaN,'entr',NaN,'lam',NaN,'tt',NaN,'vmax',NaN,'div',NaN);

if nrecurrences > 0
    RQA.det = sum(diagonal_lengths)/nrecurrences;
    RQA.lam = sum(vertical_lengths)/nrecurrences;
end

if ~isempty(diagonal_lengths)
    RQA.l = mean(diagonal_lengths);
    histogram_diagonals = hist( ...
        diagonal_lengths(:),1:min(size(recurrence_plot))); %#ok<HIST>
    RQA.entr = entropy(histogram_diagonals(:));
    % Preserve the BROADNESS convention: omit one longest diagonal.
    if numel(diagonal_lengths) >= 2
        Lmax = max(diagonal_lengths(1:end-1));
    else
        Lmax = diagonal_lengths(1);
    end
    RQA.div = 1/Lmax;
end

if ~isempty(vertical_lengths)
    RQA.tt = mean(vertical_lengths);
    RQA.vmax = max(vertical_lengths);
end

end


%% Helper function: Validate minimum line lengths
function validate_minimum_length(value,name)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 1 || value ~= round(value)
    error('%s must be one positive integer.',name);
end

end
