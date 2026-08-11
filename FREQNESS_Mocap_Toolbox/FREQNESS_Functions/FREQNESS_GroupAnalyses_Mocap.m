function [FREQjrqa,FREQmirror] = FREQNESS_GroupAnalyses_Mocap(GED,JRQA,target_frex,srate,vis_flag,varargin)
% ========================================================================
%  FREQNESS GROUP ANALYSES: SYNCHRONIZATION & MIRRORING
%

%  NOTE: This function currently supports dyadic analysis. Future versions will
%  scale to multiple participants.
%
%
% ========================================================================
%
%  This function contains a set of analyses to leverage the temporal and
%  spatial information derived from FREQNESS.  Attarctor dynamics are computed
%  based on based on the component activation timeseries, whereas spatial
%  mirroring is computed based on the spatial activation patterns.
%  Different metric levels can be compared (harmonics and subharmonix of the
% movement frequency of interest)
%
% The analyses performed are the following:
%
% Attractor dynamics:
% -
%  -
% - ....
%
% Mirroring:
% -
%

% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - GED              : Structure outputted by FREQNESS_NetworkEstimation function.
%                       We recommend not to modify this structure before giving it
%                       as input to the current function (FREQNESS_GroupAnalyses_Mocap).

%   NOTE: the participants have to be stored in the LAST DIMENSION of the
%   variables (e.g., GED.ts(Ncomponents × Ntimepoints × Nfrequencies x Nparticipants]). If you
%   did not modify the GED structure, you should not experience any issue
%   with this.

% - GED.ts  : Component activation timeseries, used for analyzing the dynamics related to SYNCHRONIZARION
% - GED.evals    : Normalized eigenvalues (variance explained in % points).
%      - GED.pats     : Spatial activation patterns, used to compute the
%                       spatial similarity as an index of MIRRORING
%      - GED.frex     : Vector of frequencies used for the decomposition;
%                       used to select subsets for analyses.
%
%
%  - srate : Sampling rate

%  - target_frex: Vector containing the target frequency (e.g., beat
%  frequency) for each participant.
%
%  - vis_flag: Set to 0 to disable output visulization, set to 1 to enable;
%
%
%  The following parameters can be specified using name-value pairs:
%
%  - 'duration'        : Duration of the recording to analyze (portion in 2-elements vector
%                        e.g. [.1 .9] from 10% until 90% of the full duration).
%                        Default: full data duration.
%
%  - 'component'          : Index of the component to analyze (the default is the 1st one)
%
%  - 'metric_levels'     : Vector of (sub)harmonics of the target_frex to analyze
%                      (e.g., [.5, 1, 2, 4] - where '1' is the target_frex)
%
%  - 'filter_width'  : Optional. Full width at half-maximum (FWHM) of the
%                      Gaussian filter used for filtering the signal. Default is 0.5.
%
%

% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
% - GROUPsync           : Structure outputted by FREQNESS_
%
% - GROUPmirror


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



%% Check the number of participants

% Check input size to verify if more than one participant is being analyzed
if length(size(GED.ts)) < 4 % no extra dimension in the input
    nsubs = 1;
    error('Only 1 participant was given as input! Please input data for 2 participants')
else
    nsubs = size(GED.ts,4);
    if nsubs ~= 2
        error(['This function currently supports dyadic analysis. Future versions will' ...
            ' scale to multiple participants. Please input dyadic data'])
    end
end
disp(['Analyses will be performed on ' num2str(nsubs) ' participants']);

% Check input frequencies
if length(target_frex) ~= nsubs
    error(['Please make sure that you input a vector with N frequencies = N subjects ' ...
        '(for dyads, a vector of 2 frequencies is expected)'])
end



%% Parse optional arguments
p = inputParser;
addParameter(p, 'filter_width', []);
addParameter(p, 'metric_levels', []);
addParameter(p, 'component', []);
addParameter(p, 'duration', []);
% addParameter(p, 'downsampling', []);
parse(p, varargin{:});
fwhm        = p.Results.filter_width;
meter       = p.Results.metric_levels;
which_comp  = p.Results.component;
duration    = p.Results.duration;
% dwn         = p.Results.downsampling;


% Define filter width (if not defined by the user)
if isempty(fwhm)
    fwhm = .3;
    disp(['Filter width not defined. The full width at half-maximum of the Gaussian filter was set by default at ' num2str(fwhm) ' Hz']);
end

% Select component (if not defined by the user)
if isempty(which_comp)
    which_comp = 1;
    disp(['Component not defined. By default, component #' num2str(which_comp) ' will be analyzed for the selected frequency and metric levels']);
end

% Select metric level (if not defined by the user)
if isempty(meter)
    meter = 1;
    disp('Metric levels not defined. Only the fundamental target frequency will be analyzed. You may add metric levels as e.g., [0.5 1 2 4]');
end
nmeters = length(meter);

% Apply duration trimming (if requested)
npnts = size(GED.ts,2);
if npnts ~= length(GED.ts) % Check the count of timepoints
    warning(['Suspected anomaly in the input GED structure. Make sure that' ...
        ' the 2nd dimension of GED.ts corresponds to N timepoitns'])
end
if ~isempty(duration)
    GED.ts = GED.ts(:,duration(1)*npnts:duration(2)*npnts,:,:); % truncate timeseries
    npnts = size(GED.ts,2); % update number of points
else
    disp('Duration not defined. Full timeseries will be used.');
end

% % Downsample (if requested)
% if  isempty(dwn)
%     dwn = 1; % do not downsample
%     disp('JRQA might be computationally consuming. Consider defining downsampling for your timeseries.');
% end


%% Block #0

% Find frequencies
idx_frex = zeros(nsubs,nmeters);

% Loop over subjects
for subi = 1:nsubs

    % Loop over metric levels (hamronics of the target frequency);
    for metri = 1:nmeters

        % Find frequency in vector
        [~,idx_frex(subi,metri)] = min(abs(target_frex(subi)*meter(metri) - GED.frex));

    end
end


% %% Frequency convergence
%
% % Set steps for median smoothing
% medsamples = .4*srate; % (400ms recommended by Cohen,2014 for electrophysiology)
%
% % % Steps for segmentation
% % nbins = 64;
%
% % Initialize timeseries
% [gedTs] = deal( zeros(nsubs, npnts) );
%
% % Loop over metric levels (hamronics of the target frequency);
% nmeters = length(meter);
% for metri = 1:nmeters
%
%     % Loop over subjects
%     for subi = 1:nsubs
%
%
%         % Assign timeseries
%         gedTs(subi,:) = GED.ts(which_comp,:,idx_frex(subi,metri),subi); % assign component corresponding to the frequency of interest
%
%         % Re-filter the component
%         tempIf = filterFGx( gedTs(subi,:), srate, target_frex(subi)*meter(metri), fwhm*meter(metri), 0); % scale gaussian filter by meter
%         % Extract angle time series
%         tempIf = angle(hilbert(tempIf));
%         % Compute instantaneous frequency
%         tempIf = [0 srate*diff(unwrap(tempIf))/(2*pi)];
%         % Median filter (remove the abrupt peaks, which are normal)
%         tempIf = movmedian(tempIf,medsamples);
%         % Assign to output variable
%         FREQsynch(metri).ifrexTs(subi,:) = tempIf;
%
%     end
%
%     % Compute the difference between the two timeseries as a measure of distance (or convergence)
%     FREQsynch(metri).diffrexTs = FREQsynch(metri).ifrexTs(2,:) - FREQsynch(metri).ifrexTs(1,:);
%
%
%     %% Plot instantaneous frequencies and their difference
%     if vis_flag ==1 % only if the user enables it
%         tvec = [0:1/srate:(npnts-1)/srate];
%         linewidth = 1.7;
%
%         figure;
%         subplot(2,1,1);
%         plot(tvec,FREQsynch(metri).ifrexTs(1,:), 'b', 'LineWidth', linewidth); hold on;
%         plot(tvec,FREQsynch(metri).ifrexTs(2,:), 'r', 'LineWidth', linewidth);
%         yline(target_frex(1)*meter(metri), 'b--', 'LineWidth', 1);
%         yline(target_frex(2)*meter(metri), 'r--', 'LineWidth', 1);
%         ymin = min(meter(metri) * [target_frex(1), target_frex(2)]);
%         ymax = max(meter(metri) * [target_frex(1), target_frex(2)]);
%         delta = 0.1 * ymin; % small buffer (e.g., 10%)
%         ylim([ymin - delta, ymax + delta]);
%         title('Instantaneous Frequencies');
%         xlabel('Time (s)');
%         ylabel('Frequency (Hz)');
%         legend({'Subject 1','Subject 2','Target 1','Target 2'});
%
%         subplot(2,1,2);
%         plot(tvec,FREQsynch(metri).diffrexTs, 'k', 'LineWidth', linewidth);
%         yline(0, 'k--');
%         yline(meter(metri)*(target_frex(2) - target_frex(1)), 'r--', 'LineWidth', 1);
%         ylim([0 - delta, 0 + delta]);
%         title('Difference in Instantaneous Frequency (Sub2 - Sub1)');
%         xlabel('Time (s)');
%         ylabel('Frequency Difference (Hz)');
%         legend({'Δf','Zero Line','Expected Δf'});
%
%     end
%



%% Block #1: Attractor dynamics

% % Downsample input timeseries
% GED.ts = GED.ts(:,1:dwn:end,:,:);
% npnts = size(GED.ts,2); % update number of points

% Initialize
[gedTs] = deal( zeros(nsubs, npnts) );
FREQjrqa = struct();

% Loop over metric levels (hamronics of the target frequency);
nmeters = length(meter);
for metri = 1:nmeters

    % Loop over subjects
    for subi = 1:nsubs
        % Assign timeseries
        gedTs(subi,:) = GED.ts(which_comp,:,idx_frex(subi,metri),subi); % assign component corresponding to the frequency of interest
        disp(['Optimizing embedding parameters for participant #' num2str(subi)])
        [~, ~, ps(subi)] = RPparam(gedTs(subi,:)');
    end
    tuned_ps = max(ps);

    % Compute JRQA
    Y =jrqa(gedTs(1,:)', gedTs(2,:)', JRQA.m, JRQA.tau, tuned_ps, [],[],[],[],'silent' );

    % Assign to output structure
    FREQjrqa(metri).RR    = Y(:,1);  % Recurrence rate
    FREQjrqa(metri).DET   = Y(:,2);  % Determinism
    FREQjrqa(metri).L     = Y(:,3);  % Mean diagonal line length
    FREQjrqa(metri).Lmax  = Y(:,4);  % Maximal diagonal line length
    FREQjrqa(metri).ENTR  = Y(:,5);  % Entropy of the diagonal line lengths
    FREQjrqa(metri).LAM   = Y(:,6);  % Laminarity
    FREQjrqa(metri).TT    = Y(:,7);  % Trapping time
    FREQjrqa(metri).Vmax  = Y(:,8);  % Maximal vertical line length
    FREQjrqa(metri).T1    = Y(:,9);  % Recurrence time of 1st type
    FREQjrqa(metri).T2    = Y(:,10); % Recurrence time of 2nd type

end


%% Block #2: Mirroring

for metri = 1:nmeters

    % Compute correlation between spatial activation patterns
    FREQmirror(metri) = corr(GED.pats(:,which_comp,idx_frex(subi,metri),1), GED.pats(:,which_comp,idx_frex(subi,metri),2));

end


end





