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
% 
%  - frex   : Vector of frequencies (ascending order).
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
%  - GED       : Structure containing eigenvalues, eigenvectors, spatial 
%                activation patterns, and network time series.
%
% ------------------------------------------------------------------------
%  AUTHORS:
%  Mattia Rosso, Leonardo Bonetti, Felix Bigand
%  mattia.rosso@clin.au.dk
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%  felix.bigand@iit.it
%  Center for Music in the Brain, Aarhus University
%  Centre for Eudaimonia and Human Flourishing, Linacre College, University of Oxford
%  Neuroscience of Perception & Action Lab, Italian Institute of Technology (IIT)
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
    disp("Duration not provided. Using full data duration.");
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
    disp('Filter width not provided. Using default reference values.');
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
    disp("Invalid filter type. Defaulting to 'logarithmic'.");
    fwidth_all = logspace(log10(fwidth), log10(fwidth * nfrex), nfrex);
end

%% GED Computation

% Initialize output structure
GED = [];

% Assign broadband source data
broadData = data(:, 1:pnts2keep);

% Initialize GED outputs
GEDevals = zeros(ncomps, nfrex);
[GEDevecs, GEDpats] = deal(zeros(size(broadData,1), ncomps, nfrex));
GEDts = zeros(ncomps, size(broadData,2), nfrex);

% Perform frequency-resolved brain network separation via GED
for frexi = 1:nfrex % loop over input frequencies
    display(['Processing frequency #' num2str(frexi)])
    
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
    GEDevecs(:,:,frexi) = evecs(:,1:ncomps);
    GEDevals(:,frexi) = evals(1:ncomps);
    
    % Brain networks' spatial activation patterns and time series
    for compi = 1:ncomps
        
        % Compute spatial activation patterns and flip sign
        GEDpats(:,compi,frexi) = GEDevecs(:,compi,frexi)' * covS; % get component
        [~,idxmax] = max(abs(GEDpats(:,compi,frexi)));     % find max magnitude
        GEDpats(:,compi,frexi)  = GEDpats(:,compi,frexi) * sign(GEDpats(idxmax,compi,frexi)); % possible sign flip
        
        % NOTE: the following has been commented out from previous version
        % for MEG. Consider it makes sense NOT to normalize 0-1 for
        % back-projecting and visualizing motion, in order to stay in the
        % scale of the data. However, it might make sense to use this when
        % starting to work at the group level
        % Take the absolute value and normalize 0-to-1 (this is necessary due to sign ambiguity from source reconstruction)
        % GEDpats(:,compi,frexi) = abs( GEDpats(:,compi,frexi) / max(GEDpats(:,compi,frexi)) );
        
        % Compute the network's activation time series 
        GEDts(compi,:,frexi) = GEDevecs(:,compi,frexi)' * broadData;
        
    end
    
end


% Assign outputs to structure
GED.evals = GEDevals; % eigenvalues
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
