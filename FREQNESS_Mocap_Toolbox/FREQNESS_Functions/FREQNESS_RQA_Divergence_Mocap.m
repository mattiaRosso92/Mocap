function DIV = FREQNESS_RQA_Divergence_Mocap(recurrence_plot,lmin)
% FREQNESS_RQA_DIVERGENCE_MOCAP Inverse longest recurrent diagonal.

if nargin < 2 || isempty(lmin)
    lmin = 2;
end
validate_inputs(recurrence_plot,lmin)
[~,diagonal_lengths] = dl(recurrence_plot);
diagonal_lengths = diagonal_lengths(diagonal_lengths >= lmin);

% Match BROADNESS: when present, omit the longest diagonal, which is the
% line of identity in an unmasked recurrence plot.
if numel(diagonal_lengths) >= 2
    Lmax = max(diagonal_lengths(1:end-1));
elseif isscalar(diagonal_lengths)
    Lmax = diagonal_lengths(1);
else
    DIV = NaN;
    return
end
DIV = 1/Lmax;

end


function validate_inputs(recurrence_plot,lmin)
validate_recurrence_plot(recurrence_plot)
if ~isnumeric(lmin) || ~isscalar(lmin) || ~isfinite(lmin) || ...
        lmin < 1 || lmin ~= round(lmin)
    error('lmin must be one positive integer.');
end
if exist('dl','file') ~= 2
    error('dl.m is required in FREQNESS_ExternalFunctions.');
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
