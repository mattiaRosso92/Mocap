function [similarity_comp,similarity_entropy,selected_frex] = ...
    FREQNESS_LandscapeSimilarity(FREQ,varargin)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP VERSION
%
% ========================================================================
%  This function estimates similarity between participants' component and
%  entropy landscapes across frequency. Component similarity correlates
%  the selected eigenvalue trajectory. Entropy similarity calls
%  FREQNESS_EffectDim_Mocap and correlates the resulting quadratic Rényi
%  entropy (H2) trajectories.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ : structure with fields
%          • FREQ.evals -> complete eigenvalue array
%                         [nEigenvalues x nFrex x nParticipants]
%          • FREQ.frex  -> shared frequency vector [nFrex x 1], or an
%                         [nFrex x nParticipants] matrix containing the
%                         same frequency grid for every participant
%
%  - Optional name-value pairs:
%      - 'component'       : eigenvalue/component trajectory to correlate.
%                            Default: 1.
%
%      - 'frequency_range' : two-element [low high] frequency range.
%                            Each bound is matched to its nearest neighbor
%                            in FREQ.frex and the inclusive interval is
%                            analyzed. Default: [] (all frequencies).
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - similarity_comp    : Pearson correlation of the selected component's
%                         eigenvalue trajectory for a dyad, or an
%                         [nParticipants x nParticipants] correlation
%                         matrix for a larger group.
%
%  - similarity_entropy : Pearson correlation of the H2 entropy landscape
%                         for a dyad, or an [nParticipants x nParticipants]
%                         correlation matrix for a larger group.
%
%  - selected_frex      : frequencies included in the correlations after
%                         nearest-neighbor matching.
%
%  All outputs are empty when fewer than two participants are present.
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

opts = struct('component',1,'frequency_range',[]);
opts = parse_name_value_pairs(opts,varargin{:});
component = opts.component;
frequency_range = opts.frequency_range;

if ~isempty(frequency_range) && (~isnumeric(frequency_range) || ...
        ~isreal(frequency_range) || ~isvector(frequency_range) || ...
        numel(frequency_range) ~= 2 || ...
        any(~isfinite(frequency_range)) || ...
        any(frequency_range <= 0) || ...
        frequency_range(1) > frequency_range(2))
    error(['frequency_range must be empty or a two-element positive ' ...
        'finite real vector ordered as [low high].']);
end


%% Map and validate inputs from FREQ

if ~isstruct(FREQ)
    error('Input must be a FREQ structure.');
end

if ~isfield(FREQ,'evals') || isempty(FREQ.evals)
    error('FREQ.evals is missing or empty.');
end

eigenspectrum = FREQ.evals;
if ~isnumeric(eigenspectrum) || ~isreal(eigenspectrum) || ...
        ndims(eigenspectrum) > 3 || any(~isfinite(eigenspectrum(:))) || ...
        any(eigenspectrum(:) < 0)
    error(['FREQ.evals must be a real finite numeric array of non-negative ' ...
        'eigenvalues in [nEigenvalues x nFrex x (nParticipants)] format.']);
end

nfrex = size(eigenspectrum,2);
nsubs = size(eigenspectrum,3);
similarity_comp = [];
similarity_entropy = [];
selected_frex = [];

if nsubs < 2
    warning('FREQNESS:LandscapeSimilarity:InsufficientParticipants', ...
        ['Landscape similarity requires at least two participants in the ' ...
        'last dimension of FREQ.evals. No output was produced.']);
    return
end

if ~isnumeric(component) || ~isreal(component) || ~isscalar(component) || ...
        ~isfinite(component) || component < 1 || component ~= round(component) || ...
        component > size(eigenspectrum,1)
    error(['component must be one positive integer indexing the first ' ...
        'dimension of FREQ.evals.']);
end

if any(sum(eigenspectrum,1) <= 0,'all')
    error('Every participant-frequency eigenspectrum must have a positive sum.');
end

if ~isfield(FREQ,'frex') || isempty(FREQ.frex)
    error('FREQ.frex is missing or empty.');
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
    shared_frex = FREQ.frex(:);
else
    shared_frex = FREQ.frex(:,1);
    if any(FREQ.frex ~= shared_frex,'all')
        error(['Landscape similarity requires the same frequency grid for ' ...
            'every participant.']);
    end
end


%% Select the frequency interval

if isempty(frequency_range)
    selected_indices = 1:nfrex;
else
    if any(diff(shared_frex) <= 0)
        error(['FREQ.frex must be strictly increasing when frequency_range ' ...
            'is used.']);
    end
    [~,first_index] = min(abs(shared_frex-frequency_range(1)));
    [~,last_index] = min(abs(shared_frex-frequency_range(2)));
    selected_indices = first_index:last_index;
end
selected_frex = shared_frex(selected_indices);


%% Compute between-participant landscape similarity

if numel(selected_indices) < 2
    error(['At least two selected frequencies are required ' ...
        'to compute landscape similarity.']);
end

component_landscapes = reshape( ...
    eigenspectrum(component,selected_indices,:),numel(selected_indices),nsubs);
[H2,~] = FREQNESS_EffectDim_Mocap(FREQ,'figure',false);
entropy_landscapes = H2(selected_indices,:);

similarity_comp = correlate_landscapes( ...
    component_landscapes,nsubs,'Component');
similarity_entropy = correlate_landscapes( ...
    entropy_landscapes,nsubs,'Entropy');

fprintf(['\nFREQNESS Landscape Similarity: correlated component #%d and ' ...
    'H2 entropy landscapes for %d participants across %d frequencies.\n'], ...
    component,nsubs,numel(selected_frex));

end


%% Helper function: Correlate participant landscapes
function similarity = correlate_landscapes(landscapes,nsubs,landscape_name)

if any(std(landscapes,0,1) == 0)
    warning(['FREQNESS:LandscapeSimilarity:Constant' landscape_name 'Landscape'], ...
        ['At least one participant has a constant ' lower(landscape_name) ...
        ' landscape; its correlations are undefined.']);
end

correlation_matrix = corrcoef(landscapes);
if nsubs == 2
    similarity = correlation_matrix(1,2);
else
    similarity = correlation_matrix;
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
