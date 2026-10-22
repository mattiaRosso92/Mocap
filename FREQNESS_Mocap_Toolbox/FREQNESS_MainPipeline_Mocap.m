% ========================================================================
%  FREQ-NESS MOCAP: MAIN ANALYSIS PIPELINE
% ========================================================================
%
%  This script is the general workflow for frequency-resolved network
%  estimation of full-body motion-capture data. It mirrors the organization
%  of the MEEG FREQ-NESS pipeline while retaining the MoCap analysis layers:
%
%  1) Participant-level network estimation
%  2) Effective dimensionality of the bodily-network eigenspectrum
%  3) Metric prominence of a selected bodily network
%  4) Network-landscape and bodily-pattern visualization
%  5) Network-landscape similarity across participants
%  6) Temporal coordination: phase-space RQA (default method)
%  7) Temporal coordination: optional JRQA example
%  8) Spatial coordination across participants
%
%  Place each dataset in a separate folder inside FREQNESS_Data. A dataset
%  may be stored as one group-level .mat array or as one .mat file per
%  participant. See FREQNESS_Startup_Mocap for the complete convention.
%
%  External dependencies:
%  - filterFGx.m and FREQNESS_AnalyticSignal.m are required for network
%    estimation.
%  - dl.m, tt.m, and entropy.m from the included CRP Toolbox subset are
%    required for phase-space RQA.
%  - The included CRP Toolbox subset supplies mutual information, false
%    nearest neighbours, and recurrence-line metrics for validated JRQA.
%    RPparam.m and jrqa.m are retained only for legacy-compatible calls.
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
run_effect_dim  = true;
run_metric_prominence = false;
run_visualizer  = false;
run_landscape_similarity = false;
run_phase_rqa   = false;
run_time_coord  = false;
run_space_coord = false;


% ------------------------------------------------------------------------
% BLOCK #1: FREQNESS_NetworkEstimation_Mocap
% ------------------------------------------------------------------------

% A numeric frequency vector is applied to every participant. For grouped
% data, an [nFrex x nParticipants] matrix permits participant-specific
% frequencies. Alternatively, provide one vector/matrix per dataset in a
% cell array matching allData.
frex  = 0.1:0.1:10;
srate = 250;

network_duration       = [];
% [] computes physical widths from the numerical frequency range:
% logarithmic uses Q = 7 to 3.5; linear uses constant Q = 5.
network_fwidth         = [];
network_filter         = 'logarithmic';
network_regularisation = 0.01;
% ncomps controls only retained eigenvectors, patterns, and time series.
% NetworkEstimation always retains the complete eigenspectrum for EffectDim.
network_ncomps         = 4;
% NaN gaps are reconstructed once for filtering but remain excluded from
% covariance and downstream time-resolved analyses through bad_segments.
network_interpolate_gaps = true;
network_maximum_interpolated_gap = 0.05;
% Enable longer cubic-spline reconstruction only after dataset validation.
network_maximum_reconstructed_gap = [];


% ------------------------------------------------------------------------
% BLOCK #2: FREQNESS_EffectDim_Mocap
% ------------------------------------------------------------------------

effectdim_figure   = true;
effectdim_plot_all = false;


% ------------------------------------------------------------------------
% BLOCK #3: FREQNESS_MetricProminence_Mocap
% ------------------------------------------------------------------------

% Supply one anchor frequency for every participant, or leave empty to use
% the most prominent frequency of the selected component with a warning.
% Empty metric-level arrays use every harmonic and subharmonic available in
% the analyzed frequency grid.
metric_anchor_frex = [];
metric_prominence_component = 1;
metric_prominence_levels = [];
metric_prominence_global_levels = [];


% ------------------------------------------------------------------------
% BLOCK #4: FREQNESS_Visualizer_Mocap
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
landscape_xlabel = 'Frequency (Hz)';
landscape_title  = 'Bodily network landscape';
visualizer_plot_all = false;
patterns_frex    = 1;
patterns_comp    = 1;
patterns_start   = 0.25;
patterns_plot_matrix = true;
patterns_animate = false;
patterns_animation_duration = 10;
patterns_frequency_unit = 'Hz';

% Dance-study 22-marker skeleton. Supply a different [nLinks x 2] array
% for other marker configurations, or [] to visualize markers only.
patterns_bones = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10; ...
    7,11;11,12;12,13;14,15;14,16;15,16;15,17;17,18;18,19; ...
    16,20;20,21;21,22];


% ------------------------------------------------------------------------
% BLOCK #5: FREQNESS_LandscapeSimilarity
% ------------------------------------------------------------------------

% Leave the frequency range empty to use all frequencies. Otherwise, the
% two bounds are matched to their nearest neighbors in FREQ.frex.
landscape_similarity_component = 1;
landscape_similarity_frequency_range = [];


% ------------------------------------------------------------------------
% BLOCK #6: FREQNESS_TimeCoord_Mocap — phase-space RQA
% ------------------------------------------------------------------------

% target_frex may be one frequency reused for all participants or one value
% per participant. Supply a numeric scalar/vector to reuse it for every
% dataset, or one scalar/vector per dataset in a cell array matching allData.
target_frex = [];

phaserqa_metric_levels = [0.25 0.5 1 2];
% A scalar component is reused for all participants. A vector assigns one
% component per participant. The toolbox default is component 1 for all.
phaserqa_component = 1;
phaserqa_duration = [0.15 0.85];
phaserqa_downsample = 1;
phaserqa_standardize = false;
phaserqa_threshold_method = 'max_fraction';
phaserqa_threshold = 0.1;
phaserqa_theiler_window = 0;
phaserqa_lmin = 2;
phaserqa_vmin = 2;
phaserqa_store_matrices = false;
phaserqa_figure = false;
phaserqa_animate = false;
phaserqa_animation_pause = 0.01;


% ------------------------------------------------------------------------
% BLOCK #7: FREQNESS_TimeCoord_Mocap — JRQA
% ------------------------------------------------------------------------

% Estimate embedding parameters with FREQNESS_JRQAParameters_Mocap before
% fixing them across comparable datasets. Radius-threshold analyses also
% require JRQA.ps. The legacy implementation remains available explicitly.
JRQA = struct('m',[],'tau',[],'ps',[]);

timecoord_metric_levels = [0.25 0.5 1 2];
timecoord_component = 1;
timecoord_duration = [0.15 0.85];
timecoord_implementation = 'validated';
timecoord_target_srate = srate;
timecoord_lowpass_cutoff = [];
timecoord_filter_order = 4;
timecoord_standardize = false;
timecoord_threshold_method = 'radius';
timecoord_threshold = [];
timecoord_theiler_window = 0;
timecoord_lmin = 2;
timecoord_vmin = 2;
% Set to a positive integer to test observed RR and DET against circularly
% shifted partner recurrence plots. Zero skips the surrogate analysis.
timecoord_n_surrogates = 0;
timecoord_minimum_shift = [];
timecoord_random_seed = 1;


% ------------------------------------------------------------------------
% BLOCK #8: FREQNESS_SpaceCoord_Mocap
% ------------------------------------------------------------------------

spacecoord_metric_levels = [0.25 0.5 1 2];
spacecoord_component = 1;


%% ========================================================================
% INITIALIZE OUTPUT VARIABLES
% ========================================================================

ndatasets = numel(allData);

FREQ       = cell(ndatasets,1);
H2         = cell(ndatasets,1);
ED         = cell(ndatasets,1);
METER      = cell(ndatasets,1);
similarity_comp = cell(ndatasets,1);
similarity_entropy = cell(ndatasets,1);
FREQrqa    = cell(ndatasets,1);
FREQjrqa   = cell(ndatasets,1);
JRQASurrogates = cell(ndatasets,1);
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

    if run_metric_prominence
        if iscell(metric_anchor_frex)
            if datai > numel(metric_anchor_frex)
                error('No metric anchor was provided for dataset %s.', ...
                    dataLabels{datai});
            end
            this_metric_anchor_frex = metric_anchor_frex{datai};
        else
            this_metric_anchor_frex = metric_anchor_frex;
        end
    end

    if run_phase_rqa || run_time_coord || run_space_coord
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
            error(['target_frex must contain a shared frequency or one ' ...
                'frequency per participant when coordination analyses are enabled.']);
        end
    end


    %% ====================================================================
    % BLOCK #1: FREQNESS_NetworkEstimation_Mocap
    % =====================================================================

    if exist('filterFGx','file') ~= 2 || ...
            exist('FREQNESS_ComputeFilterWidths_Mocap','file') ~= 2 || ...
            exist('FREQNESS_AnalyticSignal','file') ~= 2 || ...
            exist('FREQNESS_InterpolateGaps_Mocap','file') ~= 2
        error(['filterFGx.m, FREQNESS_ComputeFilterWidths_Mocap.m, ' ...
            'FREQNESS_AnalyticSignal.m, and ' ...
            'FREQNESS_InterpolateGaps_Mocap.m are required. ' ...
            'Add the missing file to the toolbox before running this pipeline.']);
    end

    FREQ{datai} = FREQNESS_NetworkEstimation_Mocap( ...
        this_data,this_frex,srate, ...
        'duration',network_duration, ...
        'fwidth',network_fwidth, ...
        'filter',network_filter, ...
        'regularisation',network_regularisation, ...
        'ncomps',network_ncomps, ...
        'interpolate_gaps',network_interpolate_gaps, ...
        'maximum_interpolated_gap', ...
        network_maximum_interpolated_gap, ...
        'maximum_reconstructed_gap', ...
        network_maximum_reconstructed_gap);

    if size(FREQ{datai}.evals,1) ~= size(this_data,1)
        error(['NetworkEstimation must retain the complete eigenspectrum ' ...
            'independently of network_ncomps.']);
    end


    %% ====================================================================
    % BLOCK #2: FREQNESS_EffectDim_Mocap
    % =====================================================================

    if run_effect_dim
        [H2{datai},ED{datai}] = FREQNESS_EffectDim_Mocap( ...
            FREQ{datai},'figure',effectdim_figure, ...
            'plot_all',effectdim_plot_all);
    end


    %% ====================================================================
    % BLOCK #3: FREQNESS_MetricProminence_Mocap
    % =====================================================================

    if run_metric_prominence

        METER{datai} = FREQNESS_MetricProminence_Mocap( ...
            FREQ{datai},this_metric_anchor_frex, ...
            'component',metric_prominence_component, ...
            'metric_levels',metric_prominence_levels, ...
            'global_metric_levels',metric_prominence_global_levels);

    end


    %% ====================================================================
    % BLOCK #4: FREQNESS_Visualizer_Mocap
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
        Landscape.ncomps = min(landscape_ncomps,size(FREQ{datai}.evals,1));
        Landscape.xlabel = landscape_xlabel;
        Landscape.title = landscape_title;

        Patterns = [];
        Patterns.frex = patterns_frex;
        Patterns.labels = marker_labels;
        Patterns.markerData = this_data;
        Patterns.comp = patterns_comp;
        Patterns.srate = srate;
        Patterns.start = patterns_start;
        Patterns.bones = patterns_bones;
        Patterns.plot_matrix = patterns_plot_matrix;
        Patterns.animate = patterns_animate;
        Patterns.animation_duration = patterns_animation_duration;
        Patterns.frequency_unit = patterns_frequency_unit;

        FREQNESS_Visualizer_Mocap(FREQ{datai},Landscape,Patterns, ...
            'plot_all',visualizer_plot_all);

    end


    %% ====================================================================
    % BLOCK #5: FREQNESS_LandscapeSimilarity
    % =====================================================================

    if run_landscape_similarity

        [similarity_comp{datai},similarity_entropy{datai}] = ...
            FREQNESS_LandscapeSimilarity(FREQ{datai}, ...
            'component',landscape_similarity_component,'frequency_range', ...
            landscape_similarity_frequency_range);

    end


    %% ====================================================================
    % BLOCK #6: FREQNESS_TimeCoord_Mocap — phase-space RQA
    % =====================================================================

    if run_phase_rqa

        FREQrqa{datai} = FREQNESS_TimeCoord_Mocap( ...
            FREQ{datai},this_target_frex, ...
            'method','phase_space', ...
            'metric_levels',phaserqa_metric_levels, ...
            'component',phaserqa_component, ...
            'duration',phaserqa_duration, ...
            'downsample',phaserqa_downsample, ...
            'standardize',phaserqa_standardize, ...
            'threshold_method',phaserqa_threshold_method, ...
            'threshold',phaserqa_threshold, ...
            'theiler_window',phaserqa_theiler_window, ...
            'lmin',phaserqa_lmin, ...
            'vmin',phaserqa_vmin, ...
            'store_matrices',phaserqa_store_matrices, ...
            'figure',phaserqa_figure, ...
            'animate',phaserqa_animate, ...
            'srate',srate, ...
            'animation_pause',phaserqa_animation_pause);

    end


    %% ====================================================================
    % BLOCK #7: FREQNESS_TimeCoord_Mocap — JRQA
    % =====================================================================

    if run_time_coord

        if isempty(JRQA.m) || isempty(JRQA.tau)
            error('JRQA.m and JRQA.tau must be defined for temporal coordination.');
        end
        if strcmpi(timecoord_implementation,'validated') && ...
                strcmpi(timecoord_threshold_method,'radius') && ...
                isempty(timecoord_threshold) && isempty(JRQA.ps)
            error(['Validated radius JRQA requires JRQA.ps or an explicit ' ...
                'timecoord_threshold.']);
        end

        timecoord_arguments = { ...
            'metric_levels',timecoord_metric_levels, ...
            'component',timecoord_component, ...
            'duration',timecoord_duration, ...
            'implementation',timecoord_implementation, ...
            'srate',srate, ...
            'target_srate',timecoord_target_srate, ...
            'lowpass_cutoff',timecoord_lowpass_cutoff, ...
            'filter_order',timecoord_filter_order, ...
            'standardize',timecoord_standardize, ...
            'threshold_method',timecoord_threshold_method, ...
            'threshold',timecoord_threshold, ...
            'theiler_window',timecoord_theiler_window, ...
            'lmin',timecoord_lmin,'vmin',timecoord_vmin};

        if timecoord_n_surrogates > 0
            if ~strcmpi(timecoord_implementation,'validated')
                error('Circular-shift surrogates require validated JRQA.');
            end
            [FREQjrqa{datai},JRQASurrogates{datai}] = ...
                FREQNESS_JRQASurrogates_Mocap( ...
                FREQ{datai},JRQA,this_target_frex, ...
                timecoord_arguments{:}, ...
                'n_surrogates',timecoord_n_surrogates, ...
                'minimum_shift',timecoord_minimum_shift, ...
                'random_seed',timecoord_random_seed);
        else
            FREQjrqa{datai} = FREQNESS_TimeCoord_Mocap( ...
                FREQ{datai},this_target_frex,'method','jrqa','parameters',JRQA, ...
                timecoord_arguments{:});
        end

    end


    %% ====================================================================
    % BLOCK #8: FREQNESS_SpaceCoord_Mocap
    % =====================================================================

    if run_space_coord

        FREQmirror{datai} = FREQNESS_SpaceCoord_Mocap( ...
            FREQ{datai},this_target_frex, ...
            'metric_levels',spacecoord_metric_levels, ...
            'component',spacecoord_component);

    end

end


fprintf('\nFREQ-NESS MoCap pipeline completed.\n');
