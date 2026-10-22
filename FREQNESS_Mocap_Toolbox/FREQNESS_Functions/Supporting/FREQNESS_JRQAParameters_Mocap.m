function JRQA = FREQNESS_JRQAParameters_Mocap( ...
    FREQ,target_frex,srate,varargin)

% ========================================================================
%  FREQ-NESS MOCAP: JRQA EMBEDDING-PARAMETER ESTIMATION
% ========================================================================
%  Estimates participant- and metric-level delay-embedding parameters from
%  FREQ-NESS network activation time series. The delay is the first local
%  minimum of time-delayed mutual information. The embedding dimension is
%  the first dimension whose false-nearest-neighbour proportion is at or
%  below the requested criterion. The recurrence radius is a fixed fraction
%  of the Euclidean phase-space diameter.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ        : FREQ-NESS structure with
%                  FREQ.ts [nComponents x nTime x nFrex x nParticipants]
%                  and a shared or participant-specific FREQ.frex.
%  - target_frex : One positive target frequency per participant.
%  - srate       : Original sampling rate in Hz.
%
%  Optional name-value pairs:
%  - 'metric_levels'     : Harmonic/subharmonic multipliers. Default: 1.
%  - 'component'         : One component index. Default: 1.
%  - 'duration'          : Proportional interval within [0 1]. Default: full.
%  - 'target_srate'      : Sampling rate after decimation. Default: srate.
%  - 'lowpass_cutoff'    : Anti-alias low-pass cutoff in Hz. Default: none.
%  - 'filter_order'      : Butterworth filter order. Default: 4.
%  - 'standardize'       : Z-score before parameter estimation. Default: false.
%  - 'maximum_lag'       : Largest tested AMI delay. Default: 20 samples.
%  - 'maximum_dimension' : Largest tested embedding dimension. Default: 5.
%  - 'fnn_threshold'     : False-nearest-neighbour criterion. Default: 0.10.
%  - 'radius_fraction'   : Fraction of phase-space diameter. Default: 0.10.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENT:
% ------------------------------------------------------------------------
%  - JRQA : Structure containing [nParticipants x nMetricLevels] estimates
%           for tau, m, and ps, selection fallbacks, diagnostic curves,
%           selected frequencies, and preprocessing provenance.
%
% ------------------------------------------------------------------------
%  EXTERNAL DEPENDENCIES:
% ------------------------------------------------------------------------
%  - mutual.m, false_nearest.m, and pss.m from the included CRP subset.
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

opts = struct('metric_levels',1,'component',1,'duration',[], ...
    'target_srate',srate,'lowpass_cutoff',[],'filter_order',4, ...
    'standardize',false,'maximum_lag',20,'maximum_dimension',5, ...
    'fnn_threshold',0.10,'radius_fraction',0.10);
opts = parse_name_value_pairs(opts,varargin{:});


%% Validate inputs

[nsubs,valid_shared_frex] = validate_freq_input(FREQ);
validate_positive_scalar(srate,'srate')

if ~isnumeric(target_frex) || ~isreal(target_frex) || ...
        numel(target_frex) ~= nsubs || any(~isfinite(target_frex)) || ...
        any(target_frex <= 0)
    error('target_frex must contain one positive finite value per participant.');
end
target_frex = reshape(target_frex,1,[]);

if ~isnumeric(opts.component) || ~isscalar(opts.component) || ...
        ~isfinite(opts.component) || opts.component < 1 || ...
        opts.component ~= round(opts.component) || ...
        opts.component > size(FREQ.ts,1)
    error('component must be one valid positive integer index.');
end
validate_positive_vector(opts.metric_levels,'metric_levels')
metric_levels = reshape(opts.metric_levels,1,[]);
validate_positive_integer(opts.maximum_lag,'maximum_lag')
validate_positive_integer(opts.maximum_dimension,'maximum_dimension')
validate_open_fraction(opts.fnn_threshold,'fnn_threshold')
validate_open_fraction(opts.radius_fraction,'radius_fraction')

required_dependencies = {'mutual','false_nearest','pss'};
for dependencyi = 1:numel(required_dependencies)
    if exist(required_dependencies{dependencyi},'file') ~= 2
        error('%s.m is required in FREQNESS_ExternalFunctions.', ...
            required_dependencies{dependencyi});
    end
end


%% Initialize parameter and diagnostic outputs

nlevels = numel(metric_levels);
tau = nan(nsubs,nlevels);
m = nan(nsubs,nlevels);
ps = nan(nsubs,nlevels);
selected_frequencies = nan(nsubs,nlevels);
tau_fallback = false(nsubs,nlevels);
m_fallback = false(nsubs,nlevels);
mutual_information = cell(nsubs,nlevels);
false_nearest_fraction = cell(nsubs,nlevels);
preprocessing = cell(nsubs,nlevels);


%% Estimate parameters independently for every participant and level

for subi = 1:nsubs
    if valid_shared_frex
        this_frex = FREQ.frex(:);
    else
        this_frex = FREQ.frex(:,subi);
    end

    for leveli = 1:nlevels
        requested_frex = target_frex(subi)*metric_levels(leveli);
        [~,frexi] = min(abs(this_frex-requested_frex));
        selected_frequencies(subi,leveli) = this_frex(frexi);

        selected_ts = reshape(FREQ.ts( ...
            opts.component,:,frexi,subi),[],1);
        [selected_ts,preprocessing{subi,leveli}] = ...
            FREQNESS_PreprocessTimeCoord_Mocap(selected_ts,srate, ...
            'target_srate',opts.target_srate, ...
            'lowpass_cutoff',opts.lowpass_cutoff, ...
            'filter_order',opts.filter_order, ...
            'duration',opts.duration, ...
            'standardize',opts.standardize);

        [tau(subi,leveli),mutual_information{subi,leveli}, ...
            tau_fallback(subi,leveli)] = select_delay( ...
            selected_ts,opts.maximum_lag);
        [m(subi,leveli),false_nearest_fraction{subi,leveli}, ...
            m_fallback(subi,leveli)] = select_dimension( ...
            selected_ts,tau(subi,leveli),opts.maximum_dimension, ...
            opts.fnn_threshold);
        ps(subi,leveli) = opts.radius_fraction*pss( ...
            selected_ts,m(subi,leveli),tau(subi,leveli),'euclidean');
    end
end


%% Assemble complete provenance

JRQA = struct();
JRQA.tau = tau;
JRQA.m = m;
JRQA.ps = ps;
JRQA.SelectedFrequencies = selected_frequencies;
JRQA.MetricLevels = metric_levels;
JRQA.Component = opts.component;
JRQA.TargetFrequencies = target_frex;
JRQA.MutualInformation = mutual_information;
JRQA.FalseNearestFraction = false_nearest_fraction;
JRQA.TauFallback = tau_fallback;
JRQA.DimensionFallback = m_fallback;
JRQA.Preprocessing = preprocessing;
JRQA.MaximumLag = opts.maximum_lag;
JRQA.MaximumDimension = opts.maximum_dimension;
JRQA.FNNThreshold = opts.fnn_threshold;
JRQA.RadiusFraction = opts.radius_fraction;
JRQA.DelayRule = 'first_local_mutual_information_minimum';
JRQA.DimensionRule = 'first_fnn_at_or_below_threshold';
JRQA.Distance = 'euclidean';
JRQA.Version = 'validated-v1';

end


%% Helper function: Select first local AMI minimum
function [tau,mi,fallback_flag] = select_delay(signal,maximum_lag)

maximum_lag = min(maximum_lag,numel(signal)-1);
mi = mutual(signal,[],maximum_lag);
if any(~isfinite(mi)) || numel(mi) < 2
    error('Mutual information returned insufficient or non-finite values.');
end

local_minimum = find( ...
    mi(2:end-1) <= mi(1:end-2) & ...
    mi(2:end-1) < mi(3:end),1,'first')+1;
fallback_flag = isempty(local_minimum);
if fallback_flag
    [~,local_minimum_relative] = min(mi(2:end));
    local_minimum = local_minimum_relative+1;
end

% mutual returns entries for lags 0:maximum_lag; convert MATLAB indexing
% back to the corresponding positive lag in samples.
tau = local_minimum-1;
tau = max(tau,1);

end


%% Helper function: Select first acceptable FNN dimension
function [dimension,fnn,fallback_flag] = select_dimension( ...
    signal,tau,maximum_dimension,fnn_threshold)

maximum_dimension = min(maximum_dimension, ...
    floor((numel(signal)-2)/tau)+1);
if maximum_dimension < 1
    error('The selected delay leaves no valid embedding dimension.');
end

fnn_output = false_nearest(signal,1,maximum_dimension,tau);
fnn = fnn_output(:,2);
valid_dimension = find(isfinite(fnn) & fnn <= fnn_threshold,1,'first');
fallback_flag = isempty(valid_dimension);
if fallback_flag
    finite_idx = find(isfinite(fnn));
    if isempty(finite_idx)
        error('False-nearest-neighbour estimation returned no finite values.');
    end
    [~,minimum_idx] = min(fnn(finite_idx));
    valid_dimension = finite_idx(minimum_idx);
end
dimension = valid_dimension;

end


%% Helper function: Validate FREQ structure
function [nsubs,valid_shared_frex] = validate_freq_input(FREQ)

if ~isstruct(FREQ) || ~isfield(FREQ,'ts') || isempty(FREQ.ts) || ...
        ~isfield(FREQ,'frex') || isempty(FREQ.frex)
    error('FREQ must contain non-empty FREQ.ts and FREQ.frex fields.');
end
if ~isnumeric(FREQ.ts) || ~isreal(FREQ.ts) || ...
        any(~isfinite(FREQ.ts(:))) || ndims(FREQ.ts) > 4
    error(['FREQ.ts must be a real finite numeric array in ' ...
        '[nComponents x nTime x nFrex x nParticipants] format.']);
end
nsubs = size(FREQ.ts,4);
if nsubs ~= 2
    error('Validated JRQA parameter estimation currently requires two participants.');
end

valid_shared_frex = isvector(FREQ.frex) && ...
    numel(FREQ.frex) == size(FREQ.ts,3);
valid_participant_frex = ismatrix(FREQ.frex) && ...
    isequal(size(FREQ.frex),[size(FREQ.ts,3) nsubs]);
if ~isnumeric(FREQ.frex) || ~isreal(FREQ.frex) || ...
        any(~isfinite(FREQ.frex(:))) || any(FREQ.frex(:) <= 0) || ...
        ~(valid_shared_frex || valid_participant_frex)
    error(['FREQ.frex must be a shared positive vector or an ' ...
        '[nFrex x nParticipants] positive frequency matrix.']);
end

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


%% Validation helpers
function validate_positive_scalar(value,name)
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
        ~isfinite(value) || value <= 0
    error('%s must be one positive finite scalar.',name);
end
end

function validate_positive_integer(value,name)
validate_positive_scalar(value,name)
if value ~= round(value)
    error('%s must be one positive integer.',name);
end
end

function validate_positive_vector(value,name)
if ~isnumeric(value) || ~isreal(value) || isempty(value) || ...
        ~isvector(value) || any(~isfinite(value)) || any(value <= 0)
    error('%s must be a vector of positive finite values.',name);
end
end

function validate_open_fraction(value,name)
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
        ~isfinite(value) || value <= 0 || value >= 1
    error('%s must be one finite scalar strictly between zero and one.',name);
end
end
