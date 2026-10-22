function [FREQjrqa,Surrogates] = FREQNESS_JRQASurrogates_Mocap( ...
    FREQ,JRQA,target_frex,varargin)

% ========================================================================
%  FREQ-NESS MOCAP: CIRCULAR-SHIFT JRQA SURROGATES
% ========================================================================
%  Tests whether observed joint recurrence exceeds recurrence obtained after
%  disrupting between-participant temporal alignment. The second partner's
%  recurrence plot is circularly shifted by the same amount on both axes,
%  preserving its recurrence geometry and marginal recurrence rate while
%  changing its alignment with the first partner.
%
%  Inputs are FREQ, the final JRQA parameter structure, and target_frex.
%  Standardization is optional and defaults to false. Name-value pairs other than
%  'n_surrogates', 'minimum_shift', and 'random_seed' are forwarded to its
%  validated implementation.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQjrqa  : Observed validated JRQA outputs with matrices retained.
%  - Surrogates: One structure per metric level containing surrogate RR and
%                DET distributions, one-sided empirical p-values, z-scores,
%                and the realized circular shifts.
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


%% Separate surrogate settings from TimeCoord options

opts = struct('n_surrogates',100,'minimum_shift',[],'random_seed',1);
[opts,timecoord_arguments] = parse_surrogate_options(opts,varargin{:});
validate_positive_integer(opts.n_surrogates,'n_surrogates')
validate_nonnegative_integer(opts.random_seed,'random_seed')
if ~isempty(opts.minimum_shift)
    validate_positive_integer(opts.minimum_shift,'minimum_shift')
end


%% Compute the observed validated recurrence plots

FREQjrqa = FREQNESS_TimeCoord_Mocap( ...
    FREQ,target_frex,timecoord_arguments{:}, ...
    'method','jrqa','jrqa',JRQA, ...
    'implementation','validated','store_matrices',true);


%% Circular-shift the second participant recurrence geometry

rng_state = rng;
rng(opts.random_seed,'twister');
cleanup_rng = onCleanup(@() rng(rng_state));

nlevels = numel(FREQjrqa);
empty_surrogate = struct('RR',[],'DET',[],'Shifts',[], ...
    'ObservedRR',[],'ObservedDET',[],'PValueRR',[],'PValueDET',[], ...
    'ZScoreRR',[],'ZScoreDET',[],'NullMethod','circular_shift_partner_2');
Surrogates = repmat(empty_surrogate,1,nlevels);

for leveli = 1:nlevels
    participant_rp = FREQjrqa(leveli).ParticipantRecurrencePlots;
    eligible_pair_mask = FREQjrqa(leveli).EligiblePairMask;
    nstates = size(participant_rp,1);
    if isempty(opts.minimum_shift)
        minimum_shift = max( ...
            FREQjrqa(leveli).TheilerWindow+1, ...
            FREQjrqa(leveli).EmbeddingDimension* ...
            FREQjrqa(leveli).Delay);
    else
        minimum_shift = opts.minimum_shift;
    end
    if minimum_shift >= floor(nstates/2)
        error(['minimum_shift must be smaller than half the number of ' ...
            'reconstructed states.']);
    end

    valid_shifts = minimum_shift:(nstates-minimum_shift);
    sampled_shifts = valid_shifts(randi( ...
        numel(valid_shifts),opts.n_surrogates,1));
    surrogate_rr = zeros(opts.n_surrogates,1);
    surrogate_det = zeros(opts.n_surrogates,1);

    for surrogatei = 1:opts.n_surrogates
        shifted_partner = circshift( ...
            participant_rp(:,:,2), ...
            [sampled_shifts(surrogatei) sampled_shifts(surrogatei)]);
        surrogate_joint = participant_rp(:,:,1) & ...
            shifted_partner & eligible_pair_mask;
        surrogate_rr(surrogatei) = sum(surrogate_joint,'all')/ ...
            nnz(eligible_pair_mask);
        RQA = FREQNESS_RQA_Mocap( ...
            surrogate_joint,FREQjrqa(leveli).Lmin,FREQjrqa(leveli).Vmin);
        surrogate_det(surrogatei) = RQA.det;
    end

    Surrogates(leveli).RR = surrogate_rr;
    Surrogates(leveli).DET = surrogate_det;
    Surrogates(leveli).Shifts = sampled_shifts;
    Surrogates(leveli).ObservedRR = FREQjrqa(leveli).RR;
    Surrogates(leveli).ObservedDET = FREQjrqa(leveli).DET;
    Surrogates(leveli).PValueRR = (1+sum( ...
        surrogate_rr >= FREQjrqa(leveli).RR))/(opts.n_surrogates+1);
    Surrogates(leveli).PValueDET = (1+sum( ...
        surrogate_det >= FREQjrqa(leveli).DET))/(opts.n_surrogates+1);
    Surrogates(leveli).ZScoreRR = standardized_difference( ...
        FREQjrqa(leveli).RR,surrogate_rr);
    Surrogates(leveli).ZScoreDET = standardized_difference( ...
        FREQjrqa(leveli).DET,surrogate_det);
end

end


%% Helper function: Parse and remove surrogate-specific options
function [opts,timecoord_arguments] = parse_surrogate_options(opts,varargin)

if mod(numel(varargin),2) ~= 0
    error('Arguments must be given as name-value pairs.');
end
timecoord_arguments = {};
for argi = 1:2:numel(varargin)
    if ~(ischar(varargin{argi}) || ...
            (isstring(varargin{argi}) && isscalar(varargin{argi})))
        error('Optional argument names must be text.');
    end
    name = lower(char(varargin{argi}));
    if isfield(opts,name)
        opts.(name) = varargin{argi+1};
    elseif ismember(name,{'method','jrqa'})
        error('JRQA surrogates use the positional JRQA parameters and method jrqa.');
    elseif ismember(name,{'implementation','store_matrices'})
        % These are controlled by this wrapper to guarantee valid surrogates.
        continue
    else
        timecoord_arguments(end+1:end+2) = ...
            varargin(argi:argi+1);
    end
end

end


%% Helper function: Standardized observed-null difference
function z_score = standardized_difference(observed,null_distribution)

null_sd = std(null_distribution);
if null_sd == 0
    z_score = NaN;
else
    z_score = (observed-mean(null_distribution))/null_sd;
end

end


%% Validation helpers
function validate_positive_integer(value,name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 1 || value ~= round(value)
    error('%s must be one positive integer.',name);
end
end

function validate_nonnegative_integer(value,name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 0 || value ~= round(value)
    error('%s must be one non-negative integer.',name);
end
end
