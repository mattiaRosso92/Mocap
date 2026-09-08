function [FREQ] = FREQNESS_NetworkEstimation_Mocap(data, frex, srate, varargin)
% ========================================================================
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP version
%
%  As compared to the original version for brain voxel data, the following
%  changes have been implemented in this function:
%  - spatial activation patterns are signed and stay in the scale of the data
%  - narrow-band filter is optimized for low frequencies (< 10 Hz)    
%
% ========================================================================
%
%  This script takes a multivariate dataset (markers × time matrix) 
%  and produces a frequency-resolved brain network landscape.
%
%  The analysis scales to dyads and larger groups. To do so, concatenate
%  the participants of the same dyads and groups along the 3rd dimension of
%  the data matrix (markers × time matrix x participants)
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - data   : 2D matrix in markers-by-time format.
%             NOTE: the XYZ spatial dimensions are concatenated in the same
%             input datamatrix. The format has to be the following:
%             [X_mrk1;
%              Y_mrk1;
%              Z_mrk1;
%              X_mrk2;
%              Y_mrk2;
%              Z_mrk2;
%              ...]
%             Optionally, this can be a 3D matrix in
%             markers-by-time-by-participants format.
%
%  - frex   : Shared frequency vector or participant-specific
%             [nFrex x nParticipants] frequency matrix.
%
%  - srate  : Sampling rate (Hz).
%
%  The following parameters can be specified using name-value pairs:
%
%  - 'duration'        : Duration of the recording to analyze (seconds).
%                        Default: full data duration.
%
%  - 'fwidth'          : Full-width at half-maximum (FWHM) of the frequency filter.
%                        Default: computed based on reference values.
%
%  - 'filter'          : Filter design method. Options:
%                        'logarithmic' (default) or 'linear'.
%
%  - 'regularisation'  : Shrinkage factor for covariance matrix regularization.
%                        Default: 0.01.
%
%  - 'ncomps'          : Number of components to retain per frequency.
%                        Default: 30.
%
%  - 'bad_segments'    : Vector of sample indices (e.g., 1-based timepoints)
%                        to be excluded from the analysis.
%                        These will be removed from covariance computations.
%
%  - 'interpolate_gaps': Detect and reconstruct NaN gaps before filtering.
%                        Reconstructed samples remain excluded through
%                        bad_segments. Default: true.
%
%  - 'maximum_interpolated_gap' : Maximum gap duration in seconds for
%                                  automatic linear interpolation.
%                                  Default: 0.05.
%
%  - 'maximum_reconstructed_gap': Maximum gap duration in seconds for
%                                  optional cubic-spline reconstruction.
%                                  Default: [] (disabled).
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ      : Structure containing:
%      - FREQ.evals : Complete normalized eigenspectrum
%                    [nMarkerCoordinates x nFrex x nParticipants]. This
%                    always contains all eigenvalues, independently of
%                    ncomps.
%      - FREQ.evecs : Retained eigenvectors
%                    [nMarkerCoordinates x ncomps x nFrex x nParticipants].
%      - FREQ.pats  : Retained spatial activation patterns, with the same
%                    component dimensions as FREQ.evecs.
%      - FREQ.ts    : Retained component time series
%                    [ncomps x nTime x nFrex x nParticipants].
%      - FREQ.bad_segments : Shared excluded sample indices.
%      - FREQ.bad_segments_by_participant : Participant-specific indices.
%      - FREQ.gap_info : Gap-detection and reconstruction provenance.
%                        Additional fields support second-order functions.
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
%  Rome (IT), 11/04/2025
% ========================================================================


% NOTE: credit for the GED implementation goes to Mike X Cohen
% (Cohen, 2022 - 'A tutorial on generalized eigendecomposition for denoising,
% contrast enhancement, and dimension reduction in multichannel electrophysiology')


%% Check mandatory inputs

if nargin < 3
    error('data, frex, and srate are required inputs.');
end

if ~isnumeric(data) || ~isreal(data) || isempty(data) || ...
        ndims(data) > 3 || any(isinf(data(:)))
    error(['data must be a non-empty real numeric array without Inf values in ' ...
        '[marker coordinates x time] or ' ...
        '[marker coordinates x time x participants] format. NaN gaps can ' ...
        'be reconstructed automatically.']);
end

if ~isnumeric(srate) || ~isreal(srate) || ~isscalar(srate) || ...
        ~isfinite(srate) || srate <= 0
    error('srate must be one positive finite scalar.');
end

if ~isnumeric(frex) || ~isreal(frex) || isempty(frex) || ...
        ~ismatrix(frex) || any(~isfinite(frex(:))) || any(frex(:) <= 0)
    error('frex must contain positive finite frequencies.');
end

if any(frex(:) >= srate/2)
    error('All frequencies in frex must be lower than the Nyquist frequency.');
end

%% Handle Optional Arguments

% Define default values
opts = struct('duration', [], 'fwidth', [], 'filter', 'logarithmic', ...
    'regularisation', 0.01, 'ncomps', 30, 'bad_segments',[], ...
    'interpolate_gaps',true,'maximum_interpolated_gap',0.05, ...
    'maximum_reconstructed_gap',[]);

% Parse name-value pair arguments
opts = parse_name_value_pairs(opts, varargin{:});

% If duration is empty, use full data duration
if isempty(opts.duration)
    opts.duration = size(data, 2) / srate;
end

% Assign values
duration       = opts.duration;
fwidth         = opts.fwidth;
filter         = opts.filter;
regularisation = opts.regularisation;
ncomps         = opts.ncomps;
idx2remove     = opts.bad_segments; % in the current version, these apply to all subjects in the input
interpolate_gaps = opts.interpolate_gaps;

% Validate optional inputs
if ~isempty(duration) && (~isnumeric(duration) || ~isreal(duration) || ...
        ~isscalar(duration) || ~isfinite(duration) || duration <= 0)
    error('duration must be one positive finite scalar expressed in seconds.');
end

if ~(ischar(filter) || (isstring(filter) && isscalar(filter))) || ...
        ~(strcmpi(filter,'logarithmic') || strcmpi(filter,'linear'))
    error('filter must be either ''logarithmic'' or ''linear''.');
end

if ~isnumeric(regularisation) || ~isreal(regularisation) || ...
        ~isscalar(regularisation) || ~isfinite(regularisation) || ...
        regularisation < 0 || regularisation >= 1
    error('regularisation must be one finite scalar in the interval [0, 1).');
end

if ~isnumeric(ncomps) || ~isreal(ncomps) || ~isscalar(ncomps) || ...
        ~isfinite(ncomps) || ncomps ~= round(ncomps) || ncomps < 1
    error('ncomps must be one positive integer.');
end


if ncomps > size(data,1)
    error('ncomps cannot exceed the number of marker coordinates.');
end

if ~islogical(interpolate_gaps) || ~isscalar(interpolate_gaps)
    error('interpolate_gaps must be one logical value (true or false).');
end

% Compute necessary parameters
pnts2keep = duration * srate;

if abs(pnts2keep - round(pnts2keep)) > eps(max(1,pnts2keep))
    error('duration multiplied by srate must define an integer number of samples.');
end
pnts2keep = round(pnts2keep);

% Check duration
if pnts2keep > size(data,2)
    error('Requested duration exceeds the length of the data.');
end

if pnts2keep < 2
    error('The requested duration must contain at least two samples.');
end

if ~isempty(idx2remove) && (~isnumeric(idx2remove) || ...
        ~isreal(idx2remove) || ~isvector(idx2remove) || ...
        any(~isfinite(idx2remove)) || ...
        any(idx2remove ~= round(idx2remove)))
    error('bad_segments must contain finite integer sample indices.');
end

supplied_bad_segments = unique(idx2remove(:)');

% Check that the range of the bad segments falls within the requested duration
if any(supplied_bad_segments < 1) || any(supplied_bad_segments > pnts2keep)
    error('One or more indices in bad_segments fall outside the analyzed time range.');
end

% Reconstruct NaN gaps once within the analyzed interval. The reconstructed
% values keep filtering continuous, while all detected samples remain in the
% shared exclusion mask used by both covariance matrices.
analysis_data = data(:,1:pnts2keep,:);
if ~interpolate_gaps && any(isnan(analysis_data),'all')
    error(['data contains NaN gaps while interpolate_gaps is false. Enable ' ...
        'automatic interpolation or preprocess the gaps before estimation.']);
end
[analysis_data,detected_bad_segments,gap_info] = ...
    FREQNESS_InterpolateGaps_Mocap(analysis_data,srate, ...
    'maximum_interpolated_gap',opts.maximum_interpolated_gap, ...
    'maximum_reconstructed_gap',opts.maximum_reconstructed_gap);
idx2remove = unique([supplied_bad_segments detected_bad_segments]);
nsubs = size(analysis_data,3);
gap_info.detected_bad_segments = detected_bad_segments;
gap_info.supplied_bad_segments = supplied_bad_segments;
gap_info.has_detected_gaps = gap_info.has_gaps;
gap_info.detected_affected_timepoint_count = gap_info.affected_timepoint_count;
gap_info.bad_segments = idx2remove;
gap_info.has_gaps = ~isempty(idx2remove);
gap_info.affected_timepoint_count = numel(idx2remove);
for subi = 1:nsubs
    gap_info.bad_segments_by_participant{subi} = unique( ...
        [gap_info.bad_segments_by_participant{subi} supplied_bad_segments]);
end

% Define good indexes to keep for computing the covariance matrices
idx2cov = setdiff(1:pnts2keep,idx2remove);
if numel(idx2cov) < 2
    error('Fewer than two samples remain for covariance estimation.');
end

% Normalize shared or participant-specific frequency input
if isvector(frex)
    frex = sort(frex(:),'ascend');
    nfrex = numel(frex);
    frex_by_participant = repmat(frex,1,nsubs);
    shared_frequencies = true;
elseif ismatrix(frex) && size(frex,2) == nsubs
    frex = sort(frex,1,'ascend');
    nfrex = size(frex,1);
    frex_by_participant = frex;
    shared_frequencies = false;
else
    error(['frex must be a shared vector or an ' ...
        '[nFrex x nParticipants] matrix.']);
end

% Handle missing filter width (based on Rosso et al., 2025 - Advanced Science)
if isempty(fwidth)
    ref_frex = .1;
    ref_fwhm = .01;
    max_frex = 10;
    nfrex_above = 100;
    frex_all = linspace(ref_frex,max_frex,nfrex_above);
    reference_widths = logspace(log10(ref_fwhm), ...
        log10(ref_fwhm*nfrex_above),nfrex_above);
    starting_width = zeros(1,nsubs);
    for subi = 1:nsubs
        [~,idx] = min(abs(frex_all-frex_by_participant(1,subi)));
        starting_width(subi) = reference_widths(idx);
    end
elseif isnumeric(fwidth) && isreal(fwidth) && isscalar(fwidth) && ...
        isfinite(fwidth) && fwidth > 0
    starting_width = repmat(fwidth,1,nsubs);
elseif isnumeric(fwidth) && isreal(fwidth) && isvector(fwidth) && ...
        numel(fwidth) == nfrex && all(isfinite(fwidth(:))) && ...
        all(fwidth(:) > 0)
    fwidth_all = repmat(fwidth(:),1,nsubs);
    starting_width = [];
elseif isnumeric(fwidth) && isreal(fwidth) && ...
        isequal(size(fwidth),[nfrex nsubs]) && ...
        all(isfinite(fwidth(:))) && all(fwidth(:) > 0)
    fwidth_all = fwidth;
    starting_width = [];
else
    error(['fwidth must be empty, a positive scalar, a shared nFrex ' ...
        'vector, or an [nFrex x nParticipants] matrix.']);
end

if ~isempty(starting_width)
    fwidth_all = zeros(nfrex,nsubs);
    for subi = 1:nsubs
        if strcmpi(filter,'logarithmic')
            fwidth_all(:,subi) = logspace(log10(starting_width(subi)), ...
                log10(starting_width(subi)*nfrex),nfrex);
        elseif strcmpi(filter,'linear')
            fwidth_all(:,subi) = linspace(starting_width(subi), ...
                starting_width(subi)*nfrex,nfrex);
        else
            error('filter must be ''logarithmic'' or ''linear''.');
        end
    end
end

if ~isnumeric(fwidth_all) || ~isreal(fwidth_all) || ...
        any(~isfinite(fwidth_all(:))) || any(fwidth_all(:) <= 0)
    error('fwidth must contain positive finite values.');
end

%% Generalized eigendecomposition (GED)

fprintf('\nFREQNESS Network Estimation: estimating frequency-resolved networks for %d participants.\n', nsubs);

% Initialize output structure
FREQ = [];

% Initialize GED outputs
GEDevals = zeros(size(data,1), nfrex, nsubs);
[GEDevecs, GEDpats] = deal(zeros(size(data,1), ncomps, nfrex, nsubs));
GEDts = zeros(ncomps, pnts2keep, nfrex, nsubs);

% Loop over participants (also works with one single participant)
for subi = 1:nsubs
    disp(['FREQNESS Network Estimation: participant #' num2str(subi)]);

    % Assign broadband marker data
    broadData = analysis_data(:,:,subi);

    % Remove bad segments, if any bad segments is provided as input
    if ~isempty(idx2remove)
        pct_removed = 100 * length(idx2remove) / pnts2keep;
        disp(['Removing ' num2str(length(idx2remove)) ' bad timepoints ' ...
            '(' num2str(pct_removed) '% of the input data).']);
    end

    % Compute and regularise the broadband covariance matrix once
    covR = cov(broadData(:,idx2cov)');
    evalsR = eig(covR);
    covR = (1-regularisation)*covR + ...
        regularisation * mean(evalsR) * eye(size(covR));

    % Perform frequency-resolved network separation via GED
    for frexi = 1:nfrex % loop over input frequencies
        disp(['Estimating network at ' ...
            num2str(frex_by_participant(frexi,subi)) ' Hz'])

        % Filter data
        narrowData = filterFGx(broadData,srate, ...
            frex_by_participant(frexi,subi),fwidth_all(frexi,subi),0); % turn the last argument to 1 to visualize the filter

        % Compute narrowband covariance matrix
        covS = cov(narrowData(:,idx2cov)');

        % Regularisation (to bring the covariance matrix to full rank)
        covS = covS  + 1e-6*eye(size(covS)); % regularise the S covariance matrix by adding a small perturbation/noise

        % Eigendecomposition
        [evecs,evals] = eig(covS ,covR);
        [evals,sidx]  = sort( diag(evals),'descend' ); % the first output returns sorted evals extracted from diagonal
        evecs = evecs(:,sidx);          % sort eigenvectors
        if ~isfinite(sum(evals)) || abs(sum(evals)) < realmin
            error('Generalized eigenvalues cannot be normalized because their sum is zero or non-finite.');
        end
        evals = evals.*100./sum(evals); % normalize eigenvalues to percent variance explained
        % Assign temporary variables to output
        GEDevecs(:,:,frexi,subi) = evecs(:,1:ncomps);
        GEDevals(:,frexi,subi) = evals;

        % Networks' spatial activation patterns and time series
        for compi = 1:ncomps

            % Compute spatial activation patterns and flip sign
            GEDpats(:,compi,frexi,subi) = covS * GEDevecs(:,compi,frexi,subi); % get component
            [~,idxmax] = max(abs(GEDpats(:,compi,frexi,subi)));     % find max magnitude
            GEDpats(:,compi,frexi,subi)  = GEDpats(:,compi,frexi,subi) * sign(GEDpats(idxmax,compi,frexi,subi)); % possible sign flip

            % NOTE: the following has been commented out from previous version
            % for MEG. Consider it makes sense NOT to normalize 0-1 for
            % back-projecting and visualizing motion, in order to stay in the
            % scale of the data. However, it might make sense to use this when
            % starting to work at the group level
            % Take the absolute value and normalize 0-to-1 (this is necessary due to sign ambiguity from source reconstruction)
            % GEDpats(:,compi,frexi) = abs( GEDpats(:,compi,frexi) / max(GEDpats(:,compi,frexi)) );

            % Compute the network's activation time series
            GEDts(compi,:,frexi,subi) = GEDevecs(:,compi,frexi,subi)' * broadData;

        end

    end

end

% Assign outputs to structure
FREQ.evals = GEDevals;    % complete normalized eigenspectrum
FREQ.evecs = GEDevecs;    % eigenvectors
FREQ.pats  = GEDpats;     % spatial activation patterns
FREQ.ts    = GEDts;       % time series
if shared_frequencies
    FREQ.frex = frex;     % analyzed frequencies shared by all participants
else
    FREQ.frex = frex_by_participant; % participant-specific analyzed frequencies
end
FREQ.fwhm = fwidth_all;                  % corresponding filter widths
FREQ.srate = srate;                      % sampling rate for secondary functions
FREQ.duration = pnts2keep/srate;        % analyzed duration in seconds
FREQ.bad_segments = idx2remove;         % excluded sample indices
FREQ.bad_segments_by_participant = ...
    gap_info.bad_segments_by_participant; % participant-specific excluded samples
FREQ.gap_info = gap_info;               % gap reconstruction and QC provenance
FREQ.regularisation = regularisation;   % covariance shrinkage factor


end



%% Helper Function: Parse Name-Value Pairs
function opts = parse_name_value_pairs(opts, varargin)
    if mod(length(varargin), 2) ~= 0
        error('Arguments must be given as name-value pairs.');
    end
    for i = 1:2:length(varargin)
        name = lower(varargin{i});
        if isfield(opts, name)
            opts.(name) = varargin{i+1};
        else
            error(['Unrecognized argument: ', name]);
        end
    end
end

%%
