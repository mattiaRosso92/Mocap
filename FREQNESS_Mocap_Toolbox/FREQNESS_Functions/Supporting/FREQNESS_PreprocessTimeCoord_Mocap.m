function [processed_ts,preprocessing] = ...
    FREQNESS_PreprocessTimeCoord_Mocap(time_series,srate,varargin)

% ========================================================================
%  FREQ-NESS MOCAP: TEMPORAL-COORDINATION PREPROCESSING
% ========================================================================
%  Low-pass filters, downsamples, temporally restricts, and optionally
%  standardizes network activation time series before recurrence analysis.
%  Filtering is performed at the original sampling rate before decimation.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - time_series : [nTimePoints x nSeries] real finite numeric matrix.
%  - srate       : Original sampling rate in Hz.
%
%  Optional name-value pairs:
%  - 'target_srate'   : Sampling rate after integer decimation. Default:
%                       the original sampling rate.
%  - 'lowpass_cutoff' : Low-pass cutoff in Hz. Default: no filtering.
%  - 'filter_order'   : Butterworth filter order. Default: 4.
%  - 'duration'       : Proportional interval within [0 1]. Default: full.
%  - 'standardize'    : Z-score each series after selection. Default: false.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - processed_ts : [nSelectedTimePoints x nSeries] processed matrix.
%  - preprocessing: Structure recording all realized processing settings,
%                   sample indices, and standardization parameters.
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


%% Handle optional arguments

opts = struct('target_srate',srate,'lowpass_cutoff',[], ...
    'filter_order',4,'duration',[],'standardize',false);
opts = parse_name_value_pairs(opts,varargin{:});


%% Validate inputs

if ~isnumeric(time_series) || ~isreal(time_series) || ...
        isempty(time_series) || ~ismatrix(time_series) || ...
        any(~isfinite(time_series(:)))
    error(['time_series must be a non-empty real finite matrix in ' ...
        '[nTimePoints x nSeries] format.']);
end
if isvector(time_series)
    time_series = time_series(:);
end
if size(time_series,1) < 4
    error('time_series must contain at least four time points.');
end
validate_positive_scalar(srate,'srate')
validate_positive_scalar(opts.target_srate,'target_srate')
if opts.target_srate > srate
    error('target_srate cannot exceed the original srate.');
end

decimation_factor = srate/opts.target_srate;
if abs(decimation_factor-round(decimation_factor)) > ...
        100*eps(max(srate,opts.target_srate))
    error(['srate/target_srate must be a positive integer because this ' ...
        'function performs integer decimation.']);
end
decimation_factor = round(decimation_factor);

if ~isempty(opts.lowpass_cutoff)
    validate_positive_scalar(opts.lowpass_cutoff,'lowpass_cutoff')
    if opts.lowpass_cutoff >= opts.target_srate/2
        error(['lowpass_cutoff must be below the target Nyquist frequency ' ...
            '(%g Hz).'],opts.target_srate/2);
    end
end
if ~isnumeric(opts.filter_order) || ~isscalar(opts.filter_order) || ...
        ~isfinite(opts.filter_order) || opts.filter_order < 1 || ...
        opts.filter_order ~= round(opts.filter_order)
    error('filter_order must be one positive integer.');
end
validate_duration(opts.duration)
if ~(islogical(opts.standardize) && isscalar(opts.standardize))
    error('standardize must be one logical scalar.');
end


%% Filter at the original sampling rate

filtered_ts = double(time_series);
normalised_cutoff = [];
if ~isempty(opts.lowpass_cutoff)
    normalised_cutoff = opts.lowpass_cutoff/(srate/2);
    [filter_b,filter_a] = butter( ...
        opts.filter_order,normalised_cutoff,'low');
    filtered_ts = filtfilt(filter_b,filter_a,filtered_ts);
end


%% Downsample and retain the requested proportional interval

ntime_original = size(filtered_ts,1);
downsampled_indices = 1:decimation_factor:ntime_original;
downsampled_ts = filtered_ts(downsampled_indices,:);
ntime_downsampled = size(downsampled_ts,1);

if isempty(opts.duration)
    first_point = 1;
    last_point = ntime_downsampled;
    duration = [0 1];
else
    first_point = max(1,round(opts.duration(1)*ntime_downsampled));
    last_point = min(ntime_downsampled, ...
        round(opts.duration(2)*ntime_downsampled));
    duration = reshape(opts.duration,1,[]);
end
if last_point-first_point+1 < 4
    error(['The selected duration retains fewer than four samples after ' ...
        'downsampling.']);
end

selected_downsampled_indices = first_point:last_point;
selected_original_indices = ...
    downsampled_indices(selected_downsampled_indices);
processed_ts = downsampled_ts(selected_downsampled_indices,:);


%% Standardize each retained series

series_mean = zeros(1,size(processed_ts,2));
series_sd = ones(1,size(processed_ts,2));
if opts.standardize
    series_mean = mean(processed_ts,1);
    series_sd = std(processed_ts,0,1);
    if any(~isfinite(series_sd) | series_sd == 0)
        error('Cannot standardize a constant or non-finite time series.');
    end
    processed_ts = (processed_ts-series_mean)./series_sd;
end


%% Record reproducible preprocessing metadata

preprocessing = struct( ...
    'OriginalSamplingRate',srate, ...
    'TargetSamplingRate',opts.target_srate, ...
    'DecimationFactor',decimation_factor, ...
    'LowpassCutoffHz',opts.lowpass_cutoff, ...
    'NormalizedLowpassCutoff',normalised_cutoff, ...
    'FilterOrder',opts.filter_order, ...
    'ZeroPhaseFiltering',~isempty(opts.lowpass_cutoff), ...
    'Duration',duration, ...
    'OriginalSampleCount',ntime_original, ...
    'DownsampledSampleCount',ntime_downsampled, ...
    'SelectedSampleCount',size(processed_ts,1), ...
    'SelectedDownsampledIndices',selected_downsampled_indices, ...
    'SelectedOriginalIndices',selected_original_indices, ...
    'Standardized',opts.standardize, ...
    'SeriesMean',series_mean, ...
    'SeriesSD',series_sd);

end


%% Helper function: Parse name-value pairs
function opts = parse_name_value_pairs(opts,varargin)

if mod(numel(varargin),2) ~= 0
    error('Arguments must be given as name-value pairs.');
end
for argi = 1:2:numel(varargin)
    if ~(ischar(varargin{argi}) || ...
            (isstring(varargin{argi}) && isscalar(varargin{argi})))
        error('Optional argument names must be text.');
    end
    name = lower(char(varargin{argi}));
    if ~isfield(opts,name)
        error('Unrecognized argument: %s',name);
    end
    opts.(name) = varargin{argi+1};
end

end


%% Helper function: Validate a positive scalar
function validate_positive_scalar(value,name)

if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
        ~isfinite(value) || value <= 0
    error('%s must be one positive finite numeric scalar.',name);
end

end


%% Helper function: Validate duration
function validate_duration(duration)

if isempty(duration)
    return
end
if ~isnumeric(duration) || ~isreal(duration) || numel(duration) ~= 2 || ...
        any(~isfinite(duration)) || duration(1) < 0 || ...
        duration(2) > 1 || duration(1) >= duration(2)
    error('duration must be an increasing two-element interval within [0 1].');
end

end
