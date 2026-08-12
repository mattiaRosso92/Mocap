function TT = FREQNESS_RQA_TrappingTime_Mocap(recurrence_plot,vmin)
% FREQNESS_RQA_TRAPPINGTIME_MOCAP Mean recurrent vertical-line length.

if nargin < 2 || isempty(vmin)
    vmin = 2;
end
validate_inputs(recurrence_plot,vmin)
[~,vertical_lengths] = tt(recurrence_plot);
vertical_lengths = vertical_lengths(vertical_lengths >= vmin);
if isempty(vertical_lengths)
    TT = NaN;
else
    TT = mean(vertical_lengths);
end

end


function validate_inputs(recurrence_plot,vmin)
validate_recurrence_plot(recurrence_plot)
if ~isnumeric(vmin) || ~isscalar(vmin) || ~isfinite(vmin) || ...
        vmin < 1 || vmin ~= round(vmin)
    error('vmin must be one positive integer.');
end
if exist('tt','file') ~= 2
    error('tt.m is required in FREQNESS_ExternalFunctions.');
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
