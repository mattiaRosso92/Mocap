function FREQjrqa = FREQNESS_TimeCoord_Mocap(FREQ,JRQA,target_frex,varargin)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP VERSION
%
% ========================================================================
%  This function estimates temporal coordination between two participants
%  from their frequency-resolved network activation time series. Joint
%  recurrence quantification analysis (JRQA) is computed independently at
%  each requested harmonic or subharmonic of the participants' target
%  frequencies.
%
%  This third-order analysis is specific to the MoCap framework and was
%  extracted from the original combined coordination analysis.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ : Structure with fields
%          - FREQ.ts   : Network activation time series organized as
%                       [nComponents x nTimePoints x nFrex x 2].
%          - FREQ.frex : Shared frequency vector or participant-specific
%                       [nFrex x 2] frequency matrix.
%
%  - JRQA : Structure containing the embedding dimension JRQA.m and delay
%           JRQA.tau.
%
%  - target_frex : Two-element vector containing one target frequency per
%                  participant.
%
%  - Optional name-value pairs:
%      - 'duration'      : Two-element proportional interval of the time
%                          series to analyze. Default: full time series.
%      - 'component'     : Network component to analyze. Default: 1.
%      - 'metric_levels' : Harmonics or subharmonics of target_frex.
%                          Default: 1.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENT:
% ------------------------------------------------------------------------
%  - FREQjrqa : Structure array with one element per metric level and the
%               fields RR, DET, L, Lmax, ENTR, LAM, TT, Vmax, T1, and T2.
%
% ------------------------------------------------------------------------
%  EXTERNAL DEPENDENCIES:
% ------------------------------------------------------------------------
%  - RPparam.m
%  - jrqa.m and its CRP Toolbox dependencies
%
% ------------------------------------------------------------------------
%  AUTHORS:
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

opts = struct('duration',[],'component',1,'metric_levels',1);
opts = parse_name_value_pairs(opts,varargin{:});
duration = opts.duration;
which_comp = opts.component;
meter = opts.metric_levels;


%% Validate inputs

if ~isstruct(FREQ) || ~isfield(FREQ,'ts') || isempty(FREQ.ts) || ...
        ~isfield(FREQ,'frex') || isempty(FREQ.frex)
    error('FREQ must contain non-empty FREQ.ts and FREQ.frex fields.');
end

if ndims(FREQ.ts) < 4 || size(FREQ.ts,4) ~= 2
    error(['FREQNESS_TimeCoord_Mocap currently supports dyadic input. ' ...
        'FREQ.ts must contain exactly two participants in its last dimension.']);
end

nsubs = size(FREQ.ts,4);
valid_shared_frex = isvector(FREQ.frex) && ...
    numel(FREQ.frex) == size(FREQ.ts,3);
valid_participant_frex = ismatrix(FREQ.frex) && ...
    isequal(size(FREQ.frex),[size(FREQ.ts,3) nsubs]);
if ~isnumeric(FREQ.frex) || ~isreal(FREQ.frex) || ...
        any(~isfinite(FREQ.frex(:))) || ...
        ~(valid_shared_frex || valid_participant_frex)
    error(['FREQ.frex must be a shared frequency vector or an ' ...
        '[nFrex x nParticipants] frequency matrix.']);
end

if ~isnumeric(target_frex) || ~isreal(target_frex) || ...
        numel(target_frex) ~= nsubs || any(~isfinite(target_frex)) || ...
        any(target_frex <= 0)
    error('target_frex must contain one positive finite frequency per participant.');
end

if ~isstruct(JRQA) || ~isfield(JRQA,'m') || ~isfield(JRQA,'tau') || ...
        isempty(JRQA.m) || isempty(JRQA.tau)
    error('JRQA must contain non-empty JRQA.m and JRQA.tau fields.');
end

if ~isnumeric(which_comp) || ~isscalar(which_comp) || ...
        which_comp < 1 || which_comp ~= round(which_comp) || ...
        which_comp > size(FREQ.ts,1)
    error('component must be an integer indexing the first dimension of FREQ.ts.');
end

if ~isnumeric(meter) || ~isreal(meter) || isempty(meter) || ...
        ~isvector(meter) || any(~isfinite(meter)) || any(meter <= 0)
    error('metric_levels must be a vector of positive finite values.');
end
meter = meter(:)';
nmeters = length(meter);

if ~isempty(duration)
    if ~isnumeric(duration) || ~isreal(duration) || numel(duration) ~= 2 || ...
            any(~isfinite(duration)) || duration(1) < 0 || ...
            duration(2) > 1 || duration(1) >= duration(2)
        error('duration must be an increasing two-element interval within [0 1].');
    end
end

if exist('RPparam','file') ~= 2 || exist('jrqa','file') ~= 2
    error(['RPparam.m and jrqa.m are required. Add the CRP Toolbox ' ...
        'dependencies to FREQNESS_ExternalFunctions before running ' ...
        'temporal coordination.']);
end

fprintf('\nFREQNESS Time Coordination: analysing %d participants.\n',nsubs);


%% Apply duration trimming

npnts = size(FREQ.ts,2);
if ~isempty(duration)
    first_point = round(duration(1)*npnts);
    last_point = round(duration(2)*npnts);
    first_point = max(first_point,1);
    last_point = min(last_point,npnts);
    FREQ.ts = FREQ.ts(:,first_point:last_point,:,:);
    npnts = size(FREQ.ts,2);
end


%% Find participant-specific frequencies

idx_frex = zeros(nsubs,nmeters);
for subi = 1:nsubs
    if valid_shared_frex
        this_frex = FREQ.frex(:);
    else
        this_frex = FREQ.frex(:,subi);
    end
    for metri = 1:nmeters
        [~,idx_frex(subi,metri)] = min(abs( ...
            target_frex(subi)*meter(metri)-this_frex));
    end
end


%% Compute attractor dynamics

gedTs = zeros(nsubs,npnts);
FREQjrqa = struct();

for metri = 1:nmeters

    ps = zeros(1,nsubs);
    for subi = 1:nsubs
        gedTs(subi,:) = FREQ.ts( ...
            which_comp,:,idx_frex(subi,metri),subi);
        fprintf('Optimizing embedding parameters for participant #%d\n',subi);
        [~,~,ps(subi)] = RPparam(gedTs(subi,:)');
    end
    tuned_ps = max(ps);

    Y = jrqa(gedTs(1,:)',gedTs(2,:)',JRQA.m,JRQA.tau,tuned_ps, ...
        [],[],[],[],'silent');

    FREQjrqa(metri).RR   = Y(:,1);
    FREQjrqa(metri).DET  = Y(:,2);
    FREQjrqa(metri).L    = Y(:,3);
    FREQjrqa(metri).Lmax = Y(:,4);
    FREQjrqa(metri).ENTR = Y(:,5);
    FREQjrqa(metri).LAM  = Y(:,6);
    FREQjrqa(metri).TT   = Y(:,7);
    FREQjrqa(metri).Vmax = Y(:,8);
    FREQjrqa(metri).T1   = Y(:,9);
    FREQjrqa(metri).T2   = Y(:,10);

end

end


%% Helper function: Parse name-value pairs
function opts = parse_name_value_pairs(opts,varargin)

if mod(length(varargin),2) ~= 0
    error('Arguments must be given as name-value pairs.');
end

for i = 1:2:length(varargin)
    if ~(ischar(varargin{i}) || (isstring(varargin{i}) && isscalar(varargin{i})))
        error('Optional argument names must be text.');
    end
    name = lower(char(varargin{i}));
    if isfield(opts,name)
        opts.(name) = varargin{i+1};
    else
        error(['Unrecognized argument: ' name]);
    end
end

end
