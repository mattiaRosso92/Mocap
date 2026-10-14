function METER = FREQNESS_MetricProminence_Mocap(FREQ,anchor_frex,varargin)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP VERSION
%
% ========================================================================
%  This function estimates the prominence of a selected bodily network at
%  harmonics and subharmonics of an anchor frequency. Each metric value is
%  normalized by the selected component's mean prominence across all
%  nonmetric frequencies. A global measure averages every available metric
%  level before applying the same normalization. Requested frequencies are
%  matched to their nearest neighbors in FREQ.frex, and the realized
%  frequencies are retained in the output.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ : structure with fields
%          • FREQ.evals -> complete normalized eigenspectrum
%                         [nEigenvalues x nFrex x (nParticipants)]
%          • FREQ.frex  -> shared frequency vector [nFrex x 1], or an
%                         [nFrex x nParticipants] frequency matrix
%
%  - anchor_frex : positive anchor frequency. A scalar is reused for all
%                  participants; a vector assigns one value per participant.
%                  When empty or omitted, the most prominent frequency of
%                  the selected component is used with a warning.
%
%  - Optional name-value pairs:
%      - 'component'            : component to analyze. Default: 1.
%
%      - 'metric_levels'        : anchor-frequency multipliers for the
%                                 level-specific output. Default: [] (all
%                                 available harmonics and subharmonics).
%
%      - 'global_metric_levels' : anchor-frequency multipliers included in
%                                 the global metric measure. Default: []
%                                 (all available harmonics and subharmonics).
%                                 Requested metric_levels are always included.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENT:
% ------------------------------------------------------------------------
%  - METER : structure containing only the outcome measures and the
%            information required to interpret them:
%          • GlobalProminence   -> mean prominence across the global metric
%                                   set, divided by the mean prominence at
%                                   all nonmetric frequencies
%                                   [1 x nParticipants]
%          • MetricProminence   -> prominence at each requested metric level,
%                                   divided by the same nonmetric mean
%                                   [nLevels x nParticipants]
%          • Component          -> component used for the computation
%          • AnchorFrequency    -> frequency-bin value used as the anchor
%                                   [1 x nParticipants]
%          • AnchorInferred     -> true when the anchor was inferred from
%                                   the selected component's spectral peak
%          • MetricLevels       -> multipliers represented by the rows of
%                                   MetricProminence [1 x nLevels]
%          • MetricFrequencies  -> nearest frequencies used for those levels
%                                   [nLevels x nParticipants]
%          • GlobalMetricLevels -> multipliers included in GlobalProminence
%                                    [1 x nGlobalLevels]
%          • GlobalFrequencies -> nearest frequencies used for the global set
%                                   [nGlobalLevels x nParticipants]
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

if nargin < 2
    anchor_frex = [];
end

opts = struct('component',1,'metric_levels',[], ...
    'global_metric_levels',[]);
opts = parse_name_value_pairs(opts,varargin{:});
which_comp = opts.component;


%% Map and validate inputs from FREQ

if ~isstruct(FREQ)
    error('Input must be a FREQ structure.');
end
if ~isfield(FREQ,'evals') || isempty(FREQ.evals)
    error('FREQ.evals is missing or empty.');
end
if ~isfield(FREQ,'frex') || isempty(FREQ.frex)
    error('FREQ.frex is missing or empty.');
end

eigenspectrum = FREQ.evals;
if ~isnumeric(eigenspectrum) || ~isreal(eigenspectrum) || ...
        ndims(eigenspectrum) > 3 || any(~isfinite(eigenspectrum(:))) || ...
        any(eigenspectrum(:) < 0)
    error(['FREQ.evals must be a real finite numeric array of non-negative ' ...
        'eigenvalues in [nEigenvalues x nFrex x (nParticipants)] format.']);
end

neigenvalues = size(eigenspectrum,1);
nfrex = size(eigenspectrum,2);
nsubs = size(eigenspectrum,3);
if nfrex < 2
    error('At least two frequencies are required to estimate metric prominence.');
end

if ~isnumeric(which_comp) || ~isreal(which_comp) || ...
        ~isscalar(which_comp) || ~isfinite(which_comp) || ...
        which_comp < 1 || which_comp ~= round(which_comp) || ...
        which_comp > neigenvalues
    error(['component must be one positive integer indexing the first ' ...
        'dimension of FREQ.evals.']);
end

eigenspectrum_sum = reshape(sum(eigenspectrum,1),nfrex,nsubs);
if any(abs(eigenspectrum_sum-100) > 1e-3,'all')
    error('FREQ.evals must be normalized to percentage explained variance.');
end

valid_shared_frex = isnumeric(FREQ.frex) && isreal(FREQ.frex) && ...
    isvector(FREQ.frex) && numel(FREQ.frex) == nfrex;
valid_participant_frex = isnumeric(FREQ.frex) && isreal(FREQ.frex) && ...
    ismatrix(FREQ.frex) && isequal(size(FREQ.frex),[nfrex nsubs]);
if ~(valid_shared_frex || valid_participant_frex) || ...
        any(~isfinite(FREQ.frex(:))) || any(FREQ.frex(:) <= 0)
    error(['FREQ.frex must be a shared positive frequency vector or an ' ...
        '[nFrex x nParticipants] frequency matrix.']);
end
if valid_shared_frex
    frex_by_participant = repmat(FREQ.frex(:),1,nsubs);
else
    frex_by_participant = FREQ.frex;
end
if any(diff(frex_by_participant,1,1) <= 0,'all')
    error('FREQ.frex must be strictly increasing for every participant.');
end

validate_metric_levels(opts.metric_levels,'metric_levels',true)
validate_metric_levels( ...
    opts.global_metric_levels,'global_metric_levels',true)


%% Select or infer the anchor frequency

if isempty(anchor_frex)
    anchor_inferred = true;
    anchor_frex = zeros(1,nsubs);
    anchor_indices = zeros(1,nsubs);
    for subi = 1:nsubs
        [~,anchor_indices(subi)] = max( ...
            eigenspectrum(which_comp,:,subi),[],2);
        anchor_frex(subi) = ...
            frex_by_participant(anchor_indices(subi),subi);
    end
    warning('FREQNESS:MetricProminence:InferredAnchor', ...
        ['No anchor frequency was supplied. The most prominent frequency ' ...
        'of component #%d was used for each participant: %s Hz.'], ...
        which_comp,strjoin(string(anchor_frex),', '));
else
    anchor_inferred = false;
    if ~isnumeric(anchor_frex) || ~isreal(anchor_frex) || ...
            ~isvector(anchor_frex) || ...
            ~ismember(numel(anchor_frex),[1 nsubs]) || ...
            any(~isfinite(anchor_frex)) || any(anchor_frex <= 0)
        error(['anchor_frex must be empty, one positive finite scalar, or ' ...
            'contain one positive finite frequency per participant.']);
    end
    anchor_frex = reshape(anchor_frex,1,[]);
    if isscalar(anchor_frex)
        anchor_frex = repmat(anchor_frex,1,nsubs);
    end
    anchor_indices = zeros(1,nsubs);
    for subi = 1:nsubs
        if anchor_frex(subi) < frex_by_participant(1,subi) || ...
                anchor_frex(subi) > frex_by_participant(end,subi)
            error('Every anchor_frex value must lie inside its frequency range.');
        end
        [~,anchor_indices(subi)] = min(abs( ...
            frex_by_participant(:,subi)-anchor_frex(subi)));
    end
end
selected_anchor_frex = zeros(1,nsubs);
for subi = 1:nsubs
    selected_anchor_frex(subi) = ...
        frex_by_participant(anchor_indices(subi),subi);
end


%% Determine metric levels

available_metric_levels = automatic_metric_levels( ...
    frex_by_participant,anchor_frex);

if isempty(opts.metric_levels)
    metric_levels = available_metric_levels;
else
    metric_levels = unique(reshape(opts.metric_levels,1,[]),'sorted');
end

if isempty(opts.global_metric_levels)
    global_metric_levels = available_metric_levels;
else
    global_metric_levels = unique( ...
        reshape(opts.global_metric_levels,1,[]),'sorted');
end
global_metric_levels = unique( ...
    [global_metric_levels metric_levels],'sorted');

[metric_indices,metric_frex] = map_metric_levels( ...
    frex_by_participant,anchor_frex,metric_levels,'metric_levels');
[global_metric_indices,global_metric_frex] = map_metric_levels( ...
    frex_by_participant,anchor_frex,global_metric_levels, ...
    'global_metric_levels');


%% Compute nonmetric baseline and metric prominence

landscape = reshape( ...
    eigenspectrum(which_comp,:,:),nfrex,nsubs);
nlevels = numel(metric_levels);
nglobal = numel(global_metric_levels);
nnonmetric = nfrex-nglobal;
if nnonmetric < 1
    error(['At least one frequency must remain outside the global metric ' ...
        'set to estimate the nonmetric baseline.']);
end

nonmetric_indices = zeros(nnonmetric,nsubs);
nonmetric_baseline = zeros(1,nsubs);
raw_prominence = zeros(nlevels,nsubs);
global_mean = zeros(1,nsubs);

for subi = 1:nsubs
    nonmetric_indices(:,subi) = setdiff( ...
        (1:nfrex)',global_metric_indices(:,subi),'stable');
    nonmetric_baseline(subi) = mean( ...
        landscape(nonmetric_indices(:,subi),subi));
    raw_prominence(:,subi) = landscape(metric_indices(:,subi),subi);
    global_mean(subi) = mean( ...
        landscape(global_metric_indices(:,subi),subi));
end

if any(~isfinite(nonmetric_baseline)) || any(nonmetric_baseline <= 0)
    error('The nonmetric baseline must be finite and positive.');
end

prominence_ratio = raw_prominence./nonmetric_baseline;
global_prominence_ratio = global_mean./nonmetric_baseline;
if any(prominence_ratio <= 0,'all') || any(global_prominence_ratio <= 0)
    error('Metric prominence ratios must be positive.');
end


%% Assemble output structure

METER = struct;
METER.GlobalProminence = global_prominence_ratio;
METER.MetricProminence = prominence_ratio;
METER.Component = which_comp;
METER.AnchorFrequency = selected_anchor_frex;
METER.AnchorInferred = anchor_inferred;
METER.MetricLevels = metric_levels;
METER.MetricFrequencies = metric_frex;
METER.GlobalMetricLevels = global_metric_levels;
METER.GlobalFrequencies = global_metric_frex;

fprintf(['\nFREQNESS Metric Prominence: computed component #%d at %d ' ...
    'metric levels for %d participants.\n'],which_comp,nlevels,nsubs);

end


%% Helper function: Find all available harmonic and subharmonic levels
function metric_levels = automatic_metric_levels( ...
    frex_by_participant,anchor_frex)

nsubs = size(frex_by_participant,2);
maximum_subharmonic = floor(min( ...
    anchor_frex./min(frex_by_participant,[],1)));
maximum_harmonic = floor(min( ...
    max(frex_by_participant,[],1)./anchor_frex));

subharmonics = [];
if maximum_subharmonic >= 2
    subharmonics = 1./(maximum_subharmonic:-1:2);
end
harmonics = 1:maximum_harmonic;
candidates = unique([subharmonics harmonics],'sorted');

candidate_indices = zeros(numel(candidates),nsubs);
candidate_error = zeros(numel(candidates),nsubs);
for leveli = 1:numel(candidates)
    for subi = 1:nsubs
        requested_frex = anchor_frex(subi)*candidates(leveli);
        [distance,candidate_indices(leveli,subi)] = min(abs( ...
            frex_by_participant(:,subi)-requested_frex));
        candidate_error(leveli,subi) = distance/requested_frex;
    end
end

% Coarse frequency grids can map several theoretical levels onto the same
% bins. Retain the level with the smallest average relative mapping error.
[~,~,groups] = unique(candidate_indices,'rows');
keep = false(size(candidates));
for groupi = 1:max(groups)
    group_indices = find(groups == groupi);
    [~,best] = min(mean(candidate_error(group_indices,:),2));
    keep(group_indices(best)) = true;
end
metric_levels = candidates(keep);

if isempty(metric_levels)
    error('No harmonic or subharmonic levels are available in FREQ.frex.');
end

end


%% Helper function: Map metric levels to frequency bins
function [indices,selected_frex] = map_metric_levels( ...
    frex_by_participant,anchor_frex,metric_levels,argument_name)

nsubs = size(frex_by_participant,2);
nlevels = numel(metric_levels);
indices = zeros(nlevels,nsubs);
selected_frex = zeros(nlevels,nsubs);

for subi = 1:nsubs
    for leveli = 1:nlevels
        requested_frex = anchor_frex(subi)*metric_levels(leveli);
        if requested_frex < frex_by_participant(1,subi) || ...
                requested_frex > frex_by_participant(end,subi)
            error(['Every ' argument_name ' frequency must lie inside ' ...
                'each participant''s frequency range.']);
        end
        [~,indices(leveli,subi)] = min(abs( ...
            frex_by_participant(:,subi)-requested_frex));
        selected_frex(leveli,subi) = ...
            frex_by_participant(indices(leveli,subi),subi);
    end
    if numel(unique(indices(:,subi))) ~= nlevels
        error(['The frequency grid maps multiple ' argument_name ...
            ' values onto the same bin for at least one participant.']);
    end
end

end


%% Helper function: Validate metric levels
function validate_metric_levels(metric_levels,argument_name,allow_empty)

if isempty(metric_levels) && allow_empty
    return
end
if ~isnumeric(metric_levels) || ~isreal(metric_levels) || ...
        ~isvector(metric_levels) || isempty(metric_levels) || ...
        any(~isfinite(metric_levels)) || any(metric_levels <= 0)
    error([argument_name ' must be empty or a vector of positive finite values.']);
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
