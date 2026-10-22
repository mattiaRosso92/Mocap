function analytic_signal = FREQNESS_AnalyticSignal(data)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP VERSION
%
% ========================================================================
%  This function computes the discrete-time analytic signal through an FFT.
%  It is the FREQ-NESS internal equivalent of MATLAB's hilbert function and
%  avoids requiring the Signal Processing Toolbox for this operation.
%
%  The calculation is performed along the first dimension (time), with one
%  signal per column, and is used by filterFGx during network estimation.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENT:
% ------------------------------------------------------------------------
%  - data : Real numeric time-by-signals vector or matrix.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENT:
% ------------------------------------------------------------------------
%  - analytic_signal : Complex analytic signal with the same size as data.
%
% ------------------------------------------------------------------------
%  AUTHORS:
% ------------------------------------------------------------------------
%  Mattia Rosso, Felix Bigand, Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  felix.bigand@iit.it
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%
%  Adapted from the public MEEG FREQ-NESS implementation.
% ========================================================================

if ~isnumeric(data) || ~isreal(data) || isempty(data) || ...
        any(~isfinite(data(:)))
    error(['data must be a non-empty real numeric vector or matrix ' ...
        'containing finite values.']);
end

if ~ismatrix(data)
    error('data must be a vector or a 2D matrix with time along the first dimension.');
end

input_was_row = isrow(data);
if input_was_row
    data = data(:);
end

ntime = size(data,1);
if ntime < 2
    error('data must contain at least two time samples.');
end

analytic_filter = zeros(ntime,1);
analytic_filter(1) = 1;

if mod(ntime,2) == 0
    analytic_filter(ntime/2+1) = 1;
    analytic_filter(2:ntime/2) = 2;
else
    analytic_filter(2:(ntime+1)/2) = 2;
end

analytic_signal = ifft(fft(data,[],1).*analytic_filter,[],1);

if input_was_row
    analytic_signal = analytic_signal.';
end

end
