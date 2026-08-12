function ENTR = FREQNESS_RQA_Entropy_Mocap(recurrence_plot,lmin)
% FREQNESS_RQA_ENTROPY_MOCAP Entropy of recurrent diagonal lengths.

if nargin < 2 || isempty(lmin)
    lmin = 2;
end
validate_inputs(recurrence_plot,lmin)
[~,diagonal_lengths] = dl(recurrence_plot);
diagonal_lengths = diagonal_lengths(diagonal_lengths >= lmin);
if isempty(diagonal_lengths)
    ENTR = NaN;
else
    histogram_diagonals = hist(diagonal_lengths(:), ...
        1:min(size(recurrence_plot))); %#ok<HIST>
    ENTR = entropy(histogram_diagonals(:));
end

end


function validate_inputs(recurrence_plot,lmin)
validate_recurrence_plot(recurrence_plot)
if ~isnumeric(lmin) || ~isscalar(lmin) || ~isfinite(lmin) || ...
        lmin < 1 || lmin ~= round(lmin)
    error('lmin must be one positive integer.');
end
if exist('dl','file') ~= 2 || exist('entropy','file') ~= 2
    error('dl.m and entropy.m are required in FREQNESS_ExternalFunctions.');
end
end


function validate_recurrence_plot(recurrence_plot)
if ~(islogical(recurrence_plot) || isnumeric(recurrence_plot)) || ...
        ~ismatrix(recurrence_plot) || isempty(recurrence_plot) || ...
        size(recurrence_plot,1) ~= size(recurrence_plot,2) || ...
        any(~isfinite(recurrence_plot(:))) || ...
        any(recurrence_plot(:) ~= 0 & recurrence_plot(:) ~= 1)
    error('recurrence_plot must be a non-empty square binary matrix.');
end
end
