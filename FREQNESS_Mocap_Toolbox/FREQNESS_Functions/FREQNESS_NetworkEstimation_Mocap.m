function [GED] = FREQNESS_NetworkEstimation_Mocap(data, frex, srate, varargin)
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
%  - frex   : Vector of frequencies.
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
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - GED       : Structure containing:
%      - GED.evals : Complete normalized eigenspectrum
%                    [nMarkerCoordinates x nFrex x nParticipants]. This
%                    always contains all eigenvalues, independently of
%                    ncomps.
%      - GED.evecs : Retained eigenvectors.
%      - GED.pats  : Retained spatial activation patterns.
%      - GED.ts    : Retained network time series.
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
opts = struct('duration', [], 'fwidth', [], 'filter', 'logarithmic', 'regularisation', 0.01, 'ncomps', 30);

% Parse name-value pair arguments
opts = parse_name_value_pairs(opts, varargin{:});

% If duration is empty, use full data duration
if isempty(opts.duration)
    % disp("Duration not provided. Using full data duration.");
    opts.duration = size(data, 2) / srate;
end

% Assign values
duration       = opts.duration;
fwidth         = opts.fwidth;
filter         = opts.filter;
regularisation = opts.regularisation;
ncomps         = opts.ncomps;

% Compute necessary parameters
pnts2keep = duration * srate;
nfrex = length(frex);
% Re-sort frequency vector in ascending order
frex = sort(frex,'ascend');

% Handle missing filter width (based on Rosso et al., 2025 - Advanced Science)
if isempty(fwidth)
    % disp('Filter width not provided. Using default reference values.');
    ref_frex = .1; % set a reference frequency
    ref_fwhm = .01;  % set a reference filter width
    max_frex = 10;   % set maximum frequency in the range of motion
    nfrex_above = 100; % how many frequencies above the reference
    % Compute the vector of frequencies
    frex_above = linspace(ref_frex, max_frex, nfrex_above);
    frex_all = frex_above;
    % Compute the vector of filter width (log-spaced)
    fwhm_above = logspace(log10(ref_fwhm), log10(ref_fwhm * (nfrex_above)), nfrex_above);
    fwidth_all = fwhm_above;
    % Match user-requested frequencies with the reference frequencies from Rosso et al. (2025)
    [~, idx] = min(abs(frex_all - frex(1))); % matching the lowest user-defined frequency
    fwidth = fwidth_all(idx);
end

% Compute filter widths
if strcmpi(filter, 'logarithmic')
    fwidth_all = logspace(log10(fwidth), log10(fwidth * nfrex), nfrex);
elseif strcmpi(filter, 'linear')
    fwidth_all = linspace(fwidth, fwidth * nfrex, nfrex);
else
    % disp("Invalid filter type. Defaulting to 'logarithmic'.");
    fwidth_all = logspace(log10(fwidth), log10(fwidth * nfrex), nfrex);
end

%% GED Computation

% Check input size to verify if more than one participant is being analyzed
if length(size(data)) < 3 % no extra dimension in the input
    nsubs = 1;
else
    nsubs = size(data,3);
end
% disp(['Data given for ' num2str(nsubs) ' participants']);

% Initialize GED outputs (subjects as last dimension)
GED = []; % output structure
GEDevals = zeros(size(data,1), nfrex, nsubs);
[GEDevecs, GEDpats] = deal(zeros(size(data,1), ncomps, nfrex, nsubs));
GEDts = zeros(ncomps, size(data,2), nfrex, nsubs);

% Run FREQ-NESS on each subject, separately
for subi = 1:nsubs

    % Assign broadband marker data from each participant
    broadData = data(:, 1:pnts2keep, subi); % subi indexing works even if singleton

    % Perform frequency-resolved brain network separation via GED
    for frexi = 1:nfrex % loop over input frequencies
        % display(['Processing frequency #' num2str(frexi)])

        % Filter data
        narrowData = filterFGx(broadData,srate,frex(frexi),fwidth_all(frexi),0); % turn the last argument of the function filterFGx() to 1 to get a visualization of the Gaussian filter in frequency domain

        % Compute covariance matrices
        covS = cov(narrowData');
        covR = cov(broadData');

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
GED.evals = GEDevals; % complete normalized eigenspectrum
GED.evecs = GEDevecs; % eigenvectors
GED.pats  = GEDpats;  % spatial activation patterns
GED.ts    = GEDts;    % time series
GED.frex  = frex;     % to make use of the analyzed frequencies later on


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
