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
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ      : Structure containing:
%      - FREQ.evals : Complete normalized eigenspectrum
%                    [nMarkerCoordinates x nFrex x nParticipants]. This
%                    always contains all eigenvalues, independently of
%                    ncomps.
%      - FREQ.evecs : Retained eigenvectors.
%      - FREQ.pats  : Retained spatial activation patterns.
%      - FREQ.ts    : Retained network time series.
%                If more participants are given as input, outputs will be
%                stored along an extra dimension for every individual.
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


%% Handle Optional Arguments

% Define default values
opts = struct('duration', [], 'fwidth', [], 'filter', 'logarithmic', ...
    'regularisation', 0.01, 'ncomps', 30, 'bad_segments',[]);

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

% Validate optional inputs
if ~isempty(duration) && (~isnumeric(duration) || ~isreal(duration) || ...
        ~isscalar(duration) || ~isfinite(duration) || duration <= 0)
    error('duration must be one positive finite scalar expressed in seconds.');
end

if ~isnumeric(ncomps) || ~isreal(ncomps) || ~isscalar(ncomps) || ...
        ~isfinite(ncomps) || ncomps ~= round(ncomps) || ncomps < 1 || ...
        ncomps > size(data,1)
    error('ncomps must be an integer from 1 to the number of marker coordinates.');
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

idx2remove = unique(idx2remove(:)','stable');

% Check that the range of the bad segments falls within the requested duration
if any(idx2remove < 1) || any(idx2remove > pnts2keep)
    error('One or more indices in bad_segments fall outside the analyzed time range.');
end

% Define good indexes to keep for computing the covariance matrices
idx2cov = setdiff(1:pnts2keep,idx2remove);
if numel(idx2cov) < 2
    error('Fewer than two samples remain for covariance estimation.');
end

% Check input size to verify if more than one participant is being analyzed
if ndims(data) < 3
    nsubs = 1;
else
    nsubs = size(data,3);
end

% Normalize shared or participant-specific frequency input
if ~isnumeric(frex) || ~isreal(frex) || isempty(frex) || ...
        any(~isfinite(frex(:))) || any(frex(:) <= 0)
    error('frex must contain positive finite frequencies.');
end
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
elseif isnumeric(fwidth) && isscalar(fwidth) && ...
        isfinite(fwidth) && fwidth > 0
    starting_width = repmat(fwidth,1,nsubs);
elseif isnumeric(fwidth) && isvector(fwidth) && ...
        numel(fwidth) == nfrex && all(isfinite(fwidth)) && all(fwidth > 0)
    fwidth_all = repmat(fwidth(:),1,nsubs);
    starting_width = [];
elseif isnumeric(fwidth) && isequal(size(fwidth),[nfrex nsubs]) && ...
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

%% GED Computation
% disp(['Data given for ' num2str(nsubs) ' participants']);

% Initialize GED outputs (subjects as last dimension)
FREQ = []; % output structure
GEDevals = zeros(size(data,1), nfrex, nsubs);
[GEDevecs, GEDpats] = deal(zeros(size(data,1), ncomps, nfrex, nsubs));
GEDts = zeros(ncomps, pnts2keep, nfrex, nsubs);

% Run FREQ-NESS on each subject, separately
for subi = 1:nsubs

    % Assign broadband marker data from each participant
    broadData = data(:, 1:pnts2keep, subi); % subi indexing works even if singleton

    % Remove bad segments, if any bad segments is provided as input
    if ~isempty(idx2remove)
        pct_removed = 100 * length(idx2remove) / pnts2keep;
        disp(['Removing ' num2str(length(idx2remove)) ' bad timepoints ' ...
            '(' num2str(pct_removed) '% of the input data).']);
    end

    % Perform frequency-resolved brain network separation via GED
    for frexi = 1:nfrex % loop over input frequencies
        % display(['Processing frequency #' num2str(frexi)])

        % Filter data
        narrowData = filterFGx(broadData,srate, ...
            frex_by_participant(frexi,subi),fwidth_all(frexi,subi),0);

        % Compute covariance matrices
        covS = cov(narrowData(:,idx2cov)');
        covR = cov(broadData(:,idx2cov)');

        % Regularisation (to bring covariance matrices to full rank)
        covS = covS  + 1e-6*eye(size(covS)); % regularise the S covariance matrix by adding a small perturbation/noise
        evalsR = eig(covR ); % re-compute eigenvalues of R covariance matrix for its regularisation
        covR  = (1-regularisation)*covR  + regularisation * mean(evalsR) * eye(size(covR)); % regularise the R covariance matrix

        % Eigendecomposition
        [evecs,evals] = eig(covS ,covR);
        [evals,sidx]  = sort( diag(evals),'descend' ); % the first output returns sorted evals extracted from diagonal
        evecs = evecs(:,sidx);          % sort eigenvectors
        evals = evals.*100./sum(evals); % normalize eigenvalues to percent variance explained
        % Assign temporary variables to output
        GEDevecs(:,:,frexi,subi) = evecs(:,1:ncomps);
        GEDevals(:,frexi,subi) = evals;

        % Brain networks' spatial activation patterns and time series
        for compi = 1:ncomps

            % Compute spatial activation patterns and flip sign
            GEDpats(:,compi,frexi,subi) = GEDevecs(:,compi,frexi,subi)' * covS; % get component
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


% If only 1 single participant was analyzed, squeeze the outputs before
% final assignment
if nsubs == 1
    GEDevals = squeeze(GEDevals);
    GEDevecs = squeeze(GEDevecs);
    GEDpats  = squeeze(GEDpats);
    GEDts    = squeeze(GEDts);
end

% Assign outputs to structure
FREQ.evals = GEDevals; % complete normalized eigenspectrum
FREQ.evecs = GEDevecs; % eigenvectors
FREQ.pats  = GEDpats;  % spatial activation patterns
FREQ.ts    = GEDts;    % time series
if shared_frequencies
    FREQ.frex = frex;
else
    FREQ.frex = frex_by_participant;
end
FREQ.fwhm = fwidth_all;
FREQ.duration = pnts2keep/srate;        % analyzed duration in seconds
FREQ.bad_segments = idx2remove;         % excluded sample indices


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
