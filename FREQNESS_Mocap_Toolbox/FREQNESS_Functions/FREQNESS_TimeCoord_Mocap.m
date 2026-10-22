function FREQjrqa = FREQNESS_TimeCoord_Mocap( ...
    FREQ,JRQA,target_frex,varargin)

% ========================================================================
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP VERSION
% ========================================================================
%  Estimates temporal coordination between two participants using joint
%  recurrence quantification analysis (JRQA) of frequency-resolved network
%  activation time series. The validated implementation constructs one
%  recurrence plot per participant in matched delay-embedding spaces and
%  retains only simultaneous recurrence points in their Hadamard product.
%
%  Existing calls remain backward compatible through the default legacy
%  implementation. Select 'implementation','validated' to use internally
%  consistent preprocessing, embedding, distance, threshold, and Theiler
%  settings with complete output provenance.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ : Structure containing
%      - FREQ.ts   : [nComponents x nTimePoints x nFrex x 2].
%      - FREQ.frex : Shared frequency vector or participant-specific
%                    [nFrex x 2] frequency matrix.
%      - FREQ.bad_segments : Must be empty because JRQA requires a common,
%                            contiguous time grid.
%
%  - JRQA : Structure containing scalar positive integers JRQA.m and
%           JRQA.tau. Validated radius-threshold analyses additionally use
%           JRQA.ps as one shared radius or one radius per participant, or
%           JRQA.RadiusFraction for adaptive_max_radius.
%
%  - target_frex : Two-element vector, one anchor frequency per participant.
%
%  Optional name-value pairs:
%  - 'duration'          : Proportional interval in [0 1]. Default: full.
%  - 'component'         : Component index. Default: 1.
%  - 'metric_levels'     : Target-frequency multipliers. Default: 1.
%  - 'implementation'    : 'legacy' or 'validated'. Default: 'legacy'.
%  - 'srate'             : Original sampling rate. Required for filtering
%                          or downsampling; otherwise sample units are used.
%  - 'target_srate'      : Sampling rate after integer decimation.
%  - 'lowpass_cutoff'    : Anti-alias low-pass cutoff in Hz.
%  - 'filter_order'      : Butterworth order. Default: 4.
%  - 'standardize'       : Validated implementation only. Z-score each
%                          participant's retained time series independently
%                          after filtering, decimation and duration selection,
%                          before embedding: (x-mean(x))/std(x,0).
%                          Default: true. Set false to retain signal units.
%                          Legacy preprocessing remains unchanged.
%  - 'threshold_method'  : 'radius', 'adaptive_max_radius', or 'fixed_rr'.
%                          adaptive_max_radius calculates 10%-style
%                          participant radii in the final embedding and
%                          applies their maximum to both participants.
%                          Default: 'radius'.
%  - 'threshold'         : Radius/radii, adaptive radius fraction, or target
%                          marginal RR. For radius, empty uses JRQA.ps. For
%                          adaptive_max_radius, empty uses
%                          JRQA.RadiusFraction. Default: empty.
%  - 'theiler_window'    : Excluded half-width in embedded samples.
%                          Default: 0.
%  - 'lmin'/'vmin'       : Minimum diagonal/vertical line length. Default: 2.
%  - 'store_matrices'    : Retain participant and joint RPs. Default: false.
%
%  For repeated-condition analyses, estimate a shared radius externally using
%  the chosen design and pass it through 'threshold' on every call. The toolbox
%  does not infer dyads, conditions, or a cross-trial aggregation policy.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENT:
% ------------------------------------------------------------------------
%  - FREQjrqa : Structure array with one element per metric level. Existing
%               RR, DET, L, Lmax, ENTR, LAM, TT, Vmax, T1, and T2 fields
%               are preserved. Validated outputs additionally record the
%               realized thresholds, participant radius estimates, radius
%               fraction, marginal recurrence rates, embedding, selected
%               frequencies, eligible pairs, and preprocessing.
%
% ------------------------------------------------------------------------
%  AUTHORS:
% ------------------------------------------------------------------------
%  Mattia Rosso, Felix Bigand, Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  felix.bigand@iit.it
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%  Center for Music in the Brain, Aarhus University
%  Neuroscience of Perception & Action Lab, Italian Institute of Technology (IIT)
%  Centre for Eudaimonia and Human Flourishing, Linacre College, University of Oxford
%
% ========================================================================


%% Handle optional arguments

opts = struct('duration',[],'component',1,'metric_levels',1, ...
    'implementation','legacy','srate',[],'target_srate',[], ...
    'lowpass_cutoff',[],'filter_order',4,'standardize',true, ...
    'threshold_method','radius','threshold',[], ...
    'theiler_window',0,'lmin',2,'vmin',2,'store_matrices',false);
opts = parse_name_value_pairs(opts,varargin{:});


%% Validate inputs

[nsubs,valid_shared_frex] = validate_freq_input(FREQ);
validate_target_frequencies(target_frex,nsubs)
target_frex = reshape(target_frex,1,[]);
validate_jrqa(JRQA)
validate_positive_integer(opts.component,'component')
if opts.component > size(FREQ.ts,1)
    error('component exceeds the first dimension of FREQ.ts.');
end
validate_positive_vector(opts.metric_levels,'metric_levels')
metric_levels = reshape(opts.metric_levels,1,[]);
validate_duration(opts.duration)
implementation = validatestring( ...
    lower(char(opts.implementation)),{'legacy','validated'});
threshold_method = validatestring( ...
    lower(char(opts.threshold_method)), ...
    {'radius','adaptive_max_radius','fixed_rr'});
validate_nonnegative_integer(opts.theiler_window,'theiler_window')
validate_positive_integer(opts.lmin,'lmin')
validate_positive_integer(opts.vmin,'vmin')
validate_logical(opts.standardize,'standardize')
validate_logical(opts.store_matrices,'store_matrices')

if isempty(opts.srate)
    if ~isempty(opts.target_srate) || ~isempty(opts.lowpass_cutoff)
        error(['srate is required when target_srate or lowpass_cutoff is ' ...
            'specified.']);
    end
    processing_srate = 1;
    processing_target_srate = 1;
else
    validate_positive_scalar(opts.srate,'srate')
    processing_srate = opts.srate;
    if isempty(opts.target_srate)
        processing_target_srate = opts.srate;
    else
        validate_positive_scalar(opts.target_srate,'target_srate')
        processing_target_srate = opts.target_srate;
    end
end

if strcmp(implementation,'legacy')
    if exist('RPparam','file') ~= 2 || exist('jrqa','file') ~= 2
        error(['RPparam.m and jrqa.m are required for the legacy ' ...
            'implementation.']);
    end
else
    required_dependencies = {'dl','tt','entropy'};
    for dependencyi = 1:numel(required_dependencies)
        if exist(required_dependencies{dependencyi},'file') ~= 2
            error('%s.m is required in FREQNESS_ExternalFunctions.', ...
                required_dependencies{dependencyi});
        end
    end
end

fprintf('\nFREQNESS Time Coordination: analysing %d participants.\n',nsubs);


%% Find participant-specific frequencies

nlevels = numel(metric_levels);
idx_frex = zeros(nsubs,nlevels);
selected_frequencies = zeros(nsubs,nlevels);
for subi = 1:nsubs
    if valid_shared_frex
        this_frex = FREQ.frex(:);
    else
        this_frex = FREQ.frex(:,subi);
    end
    for leveli = 1:nlevels
        requested_frex = target_frex(subi)*metric_levels(leveli);
        [~,idx_frex(subi,leveli)] = min(abs(this_frex-requested_frex));
        selected_frequencies(subi,leveli) = ...
            this_frex(idx_frex(subi,leveli));
    end
end


%% Compute JRQA independently at every metric level

FREQjrqa = repmat(initialize_output(),1,nlevels);
for leveli = 1:nlevels

    selected_ts = zeros(size(FREQ.ts,2),nsubs);
    for subi = 1:nsubs
        selected_ts(:,subi) = reshape(FREQ.ts( ...
            opts.component,:,idx_frex(subi,leveli),subi),[],1);
    end

    [processed_ts,preprocessing] = ...
        FREQNESS_PreprocessTimeCoord_Mocap( ...
        selected_ts,processing_srate, ...
        'target_srate',processing_target_srate, ...
        'lowpass_cutoff',opts.lowpass_cutoff, ...
        'filter_order',opts.filter_order, ...
        'duration',opts.duration, ...
        'standardize',opts.standardize && strcmp(implementation,'validated'));
    if isempty(opts.srate)
        preprocessing.OriginalSamplingRate = [];
        preprocessing.TargetSamplingRate = [];
    end

    if strcmp(implementation,'legacy')
        FREQjrqa(leveli) = compute_legacy( ...
            processed_ts,JRQA,FREQjrqa(leveli));
    else
        FREQjrqa(leveli) = compute_validated( ...
            processed_ts,JRQA,threshold_method,opts,FREQjrqa(leveli));
    end

    FREQjrqa(leveli).SelectedFrequencies = ...
        selected_frequencies(:,leveli)';
    FREQjrqa(leveli).MetricLevel = metric_levels(leveli);
    FREQjrqa(leveli).Component = opts.component;
    FREQjrqa(leveli).Implementation = implementation;
    FREQjrqa(leveli).Preprocessing = preprocessing;
end

end


%% Helper function: Legacy computation
function output = compute_legacy(time_series,JRQA,output)

ps = zeros(1,size(time_series,2));
for subi = 1:size(time_series,2)
    [~,~,ps(subi)] = RPparam(time_series(:,subi));
end
tuned_ps = max(ps);

Y = jrqa(time_series(:,1),time_series(:,2), ...
    JRQA.m,JRQA.tau,tuned_ps,[],[],[],[],'silent');
output.RR = Y(:,1);
output.DET = Y(:,2);
output.L = Y(:,3);
output.Lmax = Y(:,4);
output.ENTR = Y(:,5);
output.LAM = Y(:,6);
output.TT = Y(:,7);
output.Vmax = Y(:,8);
output.T1 = Y(:,9);
output.T2 = Y(:,10);
output.Thresholds = repmat(tuned_ps,1,2);
output.ThresholdMethod = 'legacy_max_participant_radius';
output.EmbeddingDimension = JRQA.m;
output.Delay = JRQA.tau;

end


%% Helper function: Validated joint recurrence
function output = compute_validated( ...
    time_series,JRQA,threshold_method,opts,output)

nstates = size(time_series,1)-(JRQA.m-1)*JRQA.tau;
if nstates < 4
    error(['JRQA.m and JRQA.tau leave fewer than four reconstructed ' ...
        'states.']);
end

nsubs = size(time_series,2);
phase_space = cell(1,nsubs);
distance_matrix = cell(1,nsubs);
for subi = 1:nsubs
    phase_space{subi} = delay_embed( ...
        time_series(:,subi),JRQA.m,JRQA.tau);
    distance_matrix{subi} = euclidean_distance_matrix(phase_space{subi});
end

[row_idx,column_idx] = ndgrid(1:nstates,1:nstates);
eligible_pair_mask = ...
    abs(row_idx-column_idx) > opts.theiler_window;
if opts.theiler_window == 0
    eligible_pair_mask(:) = true;
end
if ~any(eligible_pair_mask(:))
    error('No eligible state pairs remain after Theiler exclusion.');
end

[thresholds,participant_radius_estimates,radius_fraction] = ...
    resolve_thresholds( ...
    distance_matrix,eligible_pair_mask,JRQA,threshold_method,opts.threshold);
participant_rp = false(nstates,nstates,nsubs);
marginal_rr = zeros(1,nsubs);
for subi = 1:nsubs
    participant_rp(:,:,subi) = ...
        distance_matrix{subi} < thresholds(subi);
    participant_rp(:,:,subi) = ...
        participant_rp(:,:,subi) & eligible_pair_mask;
    marginal_rr(subi) = sum(participant_rp(:,:,subi),'all')/ ...
        nnz(eligible_pair_mask);
end

joint_rp = all(participant_rp,3);
RQA = FREQNESS_RQA_Mocap(joint_rp,opts.lmin,opts.vmin);
output.RR = sum(joint_rp,'all')/nnz(eligible_pair_mask);
output.DET = RQA.det;
output.L = RQA.l;
output.ENTR = RQA.entr;
output.LAM = RQA.lam;
output.TT = RQA.tt;
output.Vmax = RQA.vmax;
output.Lmax = maximum_diagonal_length(joint_rp,opts.lmin);
[output.T1,output.T2] = recurrence_times(joint_rp);

output.Thresholds = thresholds;
output.ThresholdMethod = threshold_method;
output.ParticipantRadiusEstimates = participant_radius_estimates;
output.RadiusFraction = radius_fraction;
output.MarginalRR = marginal_rr;
output.ExpectedJointRR = prod(marginal_rr);
output.ExcessJointRR = output.RR-output.ExpectedJointRR;
output.EmbeddingDimension = JRQA.m;
output.Delay = JRQA.tau;
output.TheilerWindow = opts.theiler_window;
output.EffectiveStateCount = nstates;
output.EligiblePairCount = nnz(eligible_pair_mask);
output.Lmin = opts.lmin;
output.Vmin = opts.vmin;
if opts.store_matrices
    output.ParticipantRecurrencePlots = participant_rp;
    output.JointRecurrencePlot = joint_rp;
    output.EligiblePairMask = eligible_pair_mask;
    output.PhaseSpace = phase_space;
end

end


%% Helper function: Resolve participant recurrence thresholds
function [thresholds,participant_radius_estimates,radius_fraction] = ...
    resolve_thresholds( ...
    distance_matrix,eligible_pair_mask,JRQA,method,requested_threshold)

nsubs = numel(distance_matrix);
participant_radius_estimates = [];
radius_fraction = [];
switch method
    case 'radius'
        if isempty(requested_threshold)
            if ~isfield(JRQA,'ps') || isempty(JRQA.ps)
                error(['JRQA.ps or the threshold option is required for ' ...
                    'validated radius-threshold JRQA.']);
            end
            thresholds = JRQA.ps;
        else
            thresholds = requested_threshold;
        end
        if ~isnumeric(thresholds) || ~isreal(thresholds) || ...
                ~isvector(thresholds) || ...
                ~ismember(numel(thresholds),[1 nsubs]) || ...
                any(~isfinite(thresholds)) || any(thresholds <= 0)
            error('Radius thresholds must be one or two positive finite values.');
        end
        thresholds = reshape(thresholds,1,[]);
        if isscalar(thresholds)
            thresholds = repmat(thresholds,1,nsubs);
        end

    case 'adaptive_max_radius'
        if isempty(requested_threshold)
            if ~isfield(JRQA,'RadiusFraction') || ...
                    isempty(JRQA.RadiusFraction)
                error(['JRQA.RadiusFraction or the threshold option is ' ...
                    'required for adaptive_max_radius JRQA.']);
            end
            radius_fraction = JRQA.RadiusFraction;
        else
            radius_fraction = requested_threshold;
        end
        if ~isnumeric(radius_fraction) || ~isreal(radius_fraction) || ...
                ~isscalar(radius_fraction) || ~isfinite(radius_fraction) || ...
                radius_fraction <= 0 || radius_fraction >= 1
            error(['adaptive_max_radius threshold must be one radius ' ...
                'fraction strictly within (0,1).']);
        end

        participant_radius_estimates = zeros(1,nsubs);
        for subi = 1:nsubs
            participant_radius_estimates(subi) = radius_fraction*max( ...
                distance_matrix{subi},[],'all');
        end
        thresholds = repmat(max(participant_radius_estimates),1,nsubs);

    case 'fixed_rr'
        if ~isnumeric(requested_threshold) || ...
                ~isscalar(requested_threshold) || ...
                ~isfinite(requested_threshold) || ...
                requested_threshold <= 0 || requested_threshold >= 1
            error('fixed_rr threshold must be one scalar strictly within (0,1).');
        end
        unique_pair_mask = triu(eligible_pair_mask,1);
        if ~any(unique_pair_mask(:))
            error('No unique eligible state pairs remain for fixed_rr.');
        end
        thresholds = zeros(1,nsubs);
        for subi = 1:nsubs
            eligible_distances = sort( ...
                distance_matrix{subi}(unique_pair_mask));
            threshold_idx = max(1,min(numel(eligible_distances), ...
                ceil(requested_threshold*numel(eligible_distances))));
            thresholds(subi) = eligible_distances(threshold_idx);
        end
end

end


%% Helper function: Delay embedding
function phase_space = delay_embed(signal,m,tau)

nstates = numel(signal)-(m-1)*tau;
phase_space = zeros(nstates,m);
for dimi = 1:m
    offset = (dimi-1)*tau;
    phase_space(:,dimi) = signal(1+offset:nstates+offset);
end

end


%% Helper function: Euclidean distances
function distance_matrix = euclidean_distance_matrix(phase_space)

squared_norm = sum(phase_space.^2,2);
squared_distance = ...
    squared_norm+squared_norm'-2*(phase_space*phase_space');
squared_distance(squared_distance < 0) = 0;
distance_matrix = sqrt(squared_distance);

end


%% Helper function: Maximum recurrent diagonal length
function Lmax = maximum_diagonal_length(recurrence_plot,lmin)

[~,diagonal_lengths] = dl(recurrence_plot);
diagonal_lengths = diagonal_lengths(diagonal_lengths >= lmin);
if isempty(diagonal_lengths)
    Lmax = 0;
else
    Lmax = max(diagonal_lengths);
end

end


%% Helper function: Recurrence times
function [T1,T2] = recurrence_times(recurrence_plot)

recurrence_time_1 = [];
recurrence_time_2 = [];
for columni = 1:size(recurrence_plot,2)
    recurrence_idx = find(recurrence_plot(:,columni));
    recurrence_start_idx = find(diff(double( ...
        recurrence_plot(:,columni))) == 1);
    recurrence_time_1 = [recurrence_time_1; diff(recurrence_idx)]; %#ok<AGROW>
    recurrence_time_2 = [recurrence_time_2; ...
        diff(recurrence_start_idx)]; %#ok<AGROW>
end
if isempty(recurrence_time_1)
    T1 = NaN;
else
    T1 = mean(recurrence_time_1);
end
if isempty(recurrence_time_2)
    T2 = NaN;
else
    T2 = mean(recurrence_time_2);
end

end


%% Helper function: Initialize stable public output contract
function output = initialize_output()

output = struct( ...
    'RR',[],'DET',[],'L',[],'Lmax',[],'ENTR',[], ...
    'LAM',[],'TT',[],'Vmax',[],'T1',[],'T2',[], ...
    'SelectedFrequencies',[],'MetricLevel',[],'Component',[], ...
    'Implementation','','Thresholds',[],'ThresholdMethod','', ...
    'ParticipantRadiusEstimates',[],'RadiusFraction',[], ...
    'MarginalRR',[],'ExpectedJointRR',[],'ExcessJointRR',[], ...
    'EmbeddingDimension',[],'Delay',[],'TheilerWindow',[], ...
    'EffectiveStateCount',[],'EligiblePairCount',[], ...
    'Lmin',[],'Vmin',[],'Preprocessing',[], ...
    'ParticipantRecurrencePlots',[], ...
    'JointRecurrencePlot',[],'EligiblePairMask',[],'PhaseSpace',[]);

end


%% Input-validation helpers
function [nsubs,valid_shared_frex] = validate_freq_input(FREQ)

if ~isstruct(FREQ) || ~isfield(FREQ,'ts') || isempty(FREQ.ts) || ...
        ~isfield(FREQ,'frex') || isempty(FREQ.frex)
    error('FREQ must contain non-empty FREQ.ts and FREQ.frex fields.');
end
if ~isnumeric(FREQ.ts) || ~isreal(FREQ.ts) || ...
        any(~isfinite(FREQ.ts(:))) || ndims(FREQ.ts) > 4
    error('FREQ.ts must be a real finite numeric array.');
end
if isfield(FREQ,'bad_segments') && ~isempty(FREQ.bad_segments)
    error('FREQNESS:TimeCoord:GapsUnsupported', ...
        ['FREQNESS_TimeCoord_Mocap requires a common contiguous time grid ' ...
        'and does not support bad_segments.']);
end
nsubs = size(FREQ.ts,4);
if nsubs ~= 2
    error('FREQNESS_TimeCoord_Mocap currently requires exactly two participants.');
end
valid_shared_frex = isvector(FREQ.frex) && ...
    numel(FREQ.frex) == size(FREQ.ts,3);
valid_participant_frex = ismatrix(FREQ.frex) && ...
    isequal(size(FREQ.frex),[size(FREQ.ts,3) nsubs]);
if ~isnumeric(FREQ.frex) || ~isreal(FREQ.frex) || ...
        any(~isfinite(FREQ.frex(:))) || any(FREQ.frex(:) <= 0) || ...
        ~(valid_shared_frex || valid_participant_frex)
    error(['FREQ.frex must be a shared positive vector or an ' ...
        '[nFrex x nParticipants] positive matrix.']);
end

end

function validate_target_frequencies(target_frex,nsubs)
if ~isnumeric(target_frex) || ~isreal(target_frex) || ...
        numel(target_frex) ~= nsubs || any(~isfinite(target_frex)) || ...
        any(target_frex <= 0)
    error('target_frex must contain one positive finite value per participant.');
end
end

function validate_jrqa(JRQA)
if ~isstruct(JRQA) || ~isfield(JRQA,'m') || ~isfield(JRQA,'tau')
    error('JRQA must contain JRQA.m and JRQA.tau.');
end
validate_positive_integer(JRQA.m,'JRQA.m')
validate_positive_integer(JRQA.tau,'JRQA.tau')
end

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

function validate_nonnegative_integer(value,name)
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
        ~isfinite(value) || value < 0 || value ~= round(value)
    error('%s must be one non-negative integer.',name);
end
end

function validate_positive_vector(value,name)
if ~isnumeric(value) || ~isreal(value) || isempty(value) || ...
        ~isvector(value) || any(~isfinite(value)) || any(value <= 0)
    error('%s must be a vector of positive finite values.',name);
end
end

function validate_logical(value,name)
if ~(islogical(value) && isscalar(value))
    error('%s must be one logical scalar.',name);
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
