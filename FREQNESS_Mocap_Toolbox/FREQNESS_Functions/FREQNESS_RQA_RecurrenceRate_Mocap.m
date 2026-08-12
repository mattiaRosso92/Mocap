function RR = FREQNESS_RQA_RecurrenceRate_Mocap(recurrence_plot)
% FREQNESS_RQA_RECURRENCERATE_MOCAP Recurrence rate of a binary RP.

validate_recurrence_plot(recurrence_plot)
RR = sum(recurrence_plot(:))/numel(recurrence_plot);

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
