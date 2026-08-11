% ========================================================================
%  FREQ-NESS MOCAP: MAIN ANALYSIS PIPELINE
% ========================================================================
%
%  This script is the general workflow for frequency-resolved network
%  estimation of full-body motion-capture data. It mirrors the organization
%  of the MEEG FREQ-NESS pipeline while retaining the MoCap analysis layers:
%
%  1) Participant-level network estimation
%  2) Network-landscape and bodily-pattern visualization
%  3) Interaction analyses across participants
%
%  Place each dataset in a separate folder inside FREQNESS_Data. A dataset
%  may be stored as one group-level .mat array or as one .mat file per
%  participant. See FREQNESS_Startup_Mocap for the complete convention.
%
%  External dependencies:
%  - filterFGx.m and FREQNESS_AnalyticSignal.m are required for network
%    estimation.
%  - RPparam.m and jrqa.m from the CRP Toolbox are required only when the
%    group-analysis block is enabled.
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

%% ========================================================================
% STARTUP
% ========================================================================

clear
close all
clc

[allData,dataLabels,path_home] = FREQNESS_Startup_Mocap();


%% ========================================================================
% DEFINE ANALYSIS SETTINGS
%
% Edit this section before running the pipeline.
% ========================================================================

% Network estimation is always run because its output is required by the
% second- and third-order functions.
run_visualizer     = false;
run_group_analyses = false;


% ------------------------------------------------------------------------
% BLOCK #1: FREQNESS_NetworkEstimation_Mocap
% ------------------------------------------------------------------------

% A numeric frequency vector is applied to every dataset. Alternatively,
% provide one frequency vector per dataset in a cell array matching allData.
frex  = 0.1:0.1:10;
srate = 250;

network_duration       = [];
network_fwidth         = [];
network_filter         = 'logarithmic';
network_regularisation = 0.01;
network_ncomps         = 30;


% ------------------------------------------------------------------------
% BLOCK #2: FREQNESS_Visualizer_Mocap
% ------------------------------------------------------------------------

% The current skeleton visualization supports the 22-marker configuration
% used in the Dance reference study. Replace these labels when using another
% compatible marker configuration.
marker_labels = {'LB Head','LF Head','RF Head','RB Head','Sternum', ...
    'L Shoulder','R Shoulder','L Elbow','L Wrist','L Hand','R Elbow', ...
    'R Wrist','R Hand','Pelvis','L Hip','R Hip','L Knee','L Ankle', ...
    'L Foot','R Knee','R Ankle','R Foot'};

landscape_frex   = [];
landscape_ncomps = 10;
patterns_frex    = 1;
patterns_comp    = 1;
patterns_start   = 0.25;


% ------------------------------------------------------------------------
% BLOCK #3: FREQNESS_GroupAnalyses_Mocap
% ------------------------------------------------------------------------

% target_frex must contain one target frequency per participant. Supply a
% numeric vector to reuse it for every dataset, or one vector per dataset in
% a cell array matching allData.
target_frex = [];

% Embedding settings determined before running the group-analysis function.
% At minimum, JRQA.m and JRQA.tau must be provided when the block is enabled.
JRQA = struct('m',[],'tau',[]);

group_filter_width = 0.2;
group_metric_levels = [0.25 0.5 1 2];
group_component = 1;
group_duration = [0.15 0.85];
group_visualize = false;


%% ========================================================================
% INITIALIZE OUTPUT VARIABLES
% ========================================================================

ndatasets = numel(allData);

GED        = cell(ndatasets,1);
FREQjrqa   = cell(ndatasets,1);
FREQmirror = cell(ndatasets,1);


%% ========================================================================
% RUN PIPELINE
% ========================================================================

for datai = 1:ndatasets

    fprintf('\nANALYSING DATASET: %s\n',dataLabels{datai});

    if isempty(allData{datai})
        warning('Skipping dataset %s: no data were loaded.',dataLabels{datai});
        continue
    end

    this_data = allData{datai};

    if iscell(frex)
        if datai > numel(frex) || isempty(frex{datai}) %#ok<UNRCH>
            error('No frequency vector was provided for dataset %s.',dataLabels{datai});
        end
        this_frex = frex{datai};
    else
        this_frex = frex;
    end


    %% ====================================================================
    % BLOCK #1: FREQNESS_NetworkEstimation_Mocap
    % =====================================================================

    if exist('filterFGx','file') ~= 2 || ...
            exist('FREQNESS_AnalyticSignal','file') ~= 2
        error(['filterFGx.m and FREQNESS_AnalyticSignal.m are required. ' ...
            'Add the missing file to the toolbox before running this pipeline.']);
    end

    GED{datai} = FREQNESS_NetworkEstimation_Mocap( ...
        this_data,this_frex,srate, ...
        'duration',network_duration, ...
        'fwidth',network_fwidth, ...
        'filter',network_filter, ...
        'regularisation',network_regularisation, ...
        'ncomps',network_ncomps);


    %% ====================================================================
    % BLOCK #2: FREQNESS_Visualizer_Mocap
    % =====================================================================

    if run_visualizer

        if numel(marker_labels) ~= size(this_data,1)/3 %#ok<UNRCH>
            error(['marker_labels must contain one label per XYZ marker ' ...
                'triplet in dataset %s.'],dataLabels{datai});
        end

        Landscape = [];
        if isempty(landscape_frex)
            Landscape.frex = this_frex;
        else
            Landscape.frex = landscape_frex;
        end
        Landscape.ncomps = min(landscape_ncomps,size(GED{datai}.evals,1));

        Patterns = [];
        Patterns.frex = patterns_frex;
        Patterns.labels = marker_labels;
        Patterns.markerData = this_data;
        Patterns.comp = patterns_comp;
        Patterns.srate = srate;
        Patterns.start = patterns_start;

        FREQNESS_Visualizer_Mocap(GED{datai},Landscape,Patterns);

    end


    %% ====================================================================
    % BLOCK #3: FREQNESS_GroupAnalyses_Mocap
    % =====================================================================

    if run_group_analyses

        if exist('RPparam','file') ~= 2 || exist('jrqa','file') ~= 2 %#ok<UNRCH>
            error(['RPparam.m and jrqa.m were not found. Add the CRP ' ...
                'Toolbox dependencies to FREQNESS_ExternalFunctions before ' ...
                'running group analyses.']);
        end

        if iscell(target_frex)
            if datai > numel(target_frex) || isempty(target_frex{datai})
                error('No target frequencies were provided for dataset %s.', ...
                    dataLabels{datai});
            end
            this_target_frex = target_frex{datai};
        else
            this_target_frex = target_frex;
        end

        if isempty(this_target_frex)
            error(['target_frex must contain one frequency per participant ' ...
                'when group analyses are enabled.']);
        end

        if isempty(JRQA.m) || isempty(JRQA.tau)
            error('JRQA.m and JRQA.tau must be defined for group analyses.');
        end

        [FREQjrqa{datai},FREQmirror{datai}] = ...
            FREQNESS_GroupAnalyses_Mocap( ...
            GED{datai},JRQA,this_target_frex,srate,group_visualize, ...
            'filter_width',group_filter_width, ...
            'metric_levels',group_metric_levels, ...
            'component',group_component, ...
            'duration',group_duration);

    end

end


fprintf('\nFREQ-NESS MoCap pipeline completed.\n');
