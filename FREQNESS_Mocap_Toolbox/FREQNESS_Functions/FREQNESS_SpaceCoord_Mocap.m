function FREQmirror = FREQNESS_SpaceCoord_Mocap(FREQ,target_frex,varargin)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP VERSION
%
% ========================================================================
%  This function estimates spatial coordination between two participants
%  by correlating the magnitudes of their frequency-resolved network
%  activation patterns. Pattern magnitudes make the result invariant to
%  the arbitrary polarity of eigendecomposition components.
%  One mirroring coefficient is returned for every requested harmonic or
%  subharmonic of the target movement frequency.
%
%  This third-order analysis is specific to the MoCap framework and was
%  extracted from the original combined coordination analysis.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ : Structure with fields
%          - FREQ.pats : Spatial activation patterns organized as
%                       [nCoordinates x nComponents x nFrex x 2].
%          - FREQ.frex : Shared frequency vector or participant-specific
%                       [nFrex x 2] frequency matrix.
%
%  - target_frex : Two-element vector containing one target frequency per
%                  participant.
%
%  - Optional name-value pairs:
%      - 'component'     : Network component to analyze. Default: 1.
%      - 'metric_levels' : Harmonics or subharmonics of target_frex.
%                          Default: 1.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENT:
% ------------------------------------------------------------------------
%  - FREQmirror : Spatial correlation coefficient for every metric level.
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

opts = struct('component',1,'metric_levels',1);
opts = parse_name_value_pairs(opts,varargin{:});
which_comp = opts.component;
meter = opts.metric_levels;


%% Validate inputs

if ~isstruct(FREQ) || ~isfield(FREQ,'pats') || isempty(FREQ.pats) || ...
        ~isfield(FREQ,'frex') || isempty(FREQ.frex)
    error('FREQ must contain non-empty FREQ.pats and FREQ.frex fields.');
end

if ndims(FREQ.pats) < 4 || size(FREQ.pats,4) ~= 2
    error(['FREQNESS_SpaceCoord_Mocap currently supports dyadic input. ' ...
        'FREQ.pats must contain exactly two participants in its last dimension.']);
end

nsubs = size(FREQ.pats,4);
valid_shared_frex = isvector(FREQ.frex) && ...
    numel(FREQ.frex) == size(FREQ.pats,3);
valid_participant_frex = ismatrix(FREQ.frex) && ...
    isequal(size(FREQ.frex),[size(FREQ.pats,3) nsubs]);
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

if ~isnumeric(which_comp) || ~isscalar(which_comp) || ...
        which_comp < 1 || which_comp ~= round(which_comp) || ...
        which_comp > size(FREQ.pats,2)
    error('component must be an integer indexing the second dimension of FREQ.pats.');
end

if ~isnumeric(meter) || ~isreal(meter) || isempty(meter) || ...
        ~isvector(meter) || any(~isfinite(meter)) || any(meter <= 0)
    error('metric_levels must be a vector of positive finite values.');
end
meter = meter(:)';
nmeters = length(meter);

fprintf('\nFREQNESS Space Coordination: analysing %d participants.\n',nsubs);


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


%% Compute spatial mirroring

FREQmirror = zeros(1,nmeters);
for metri = 1:nmeters

    % Preserve the original combined-analysis behavior: both participants are
    % compared at the frequency selected for the last participant.
    shared_frex_idx = idx_frex(nsubs,metri);
    % Component polarity is arbitrary in an eigendecomposition. Compare
    % activation magnitudes so spatial coordination is invariant to an
    % independent sign flip of either participant's component.
    FREQmirror(metri) = corr( ...
        abs(FREQ.pats(:,which_comp,shared_frex_idx,1)), ...
        abs(FREQ.pats(:,which_comp,shared_frex_idx,2)));

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
