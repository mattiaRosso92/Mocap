function config = EmpaticMirroring_Config()
%EMPATICMIRRORING_CONFIG Central configuration for the study pipeline.

functionsRoot = fileparts(mfilename('fullpath'));
studyRoot = fileparts(functionsRoot);
repositoryRoot = fileparts(studyRoot);

config.paths.studyRoot = studyRoot;
config.paths.repositoryRoot = repositoryRoot;
config.paths.dataRoot = fullfile(studyRoot,'EmpaticMirrorring_Data');
config.paths.toolboxRoot = fullfile(repositoryRoot,'FREQNESS_Mocap_Toolbox');
config.paths.outputRoot = fullfile(studyRoot,'outputs');
config.paths.qcOutputRoot = fullfile(config.paths.outputRoot,'qc');
config.paths.modelOutputRoot = fullfile(config.paths.outputRoot, ...
    'preprocessed_models');
config.paths.participantsOutputRoot = fullfile(config.paths.outputRoot, ...
    'participants');

% Trial-level inputs, bad-sample lists, and future core FREQ results share
% one participant-specific folder below the dedicated outputs root. Raw data
% remain immutable and generated files never enter the import scan.

config.sampling.teacherHz = 300;
config.sampling.participantHz = 120;
config.sampling.outputHz = 120;

% ALIGNMENT CONTRACT FOR PREPROCESSED MAT EXPORTS: acquisition included a
% 3 s participant cue/wait, but the exported participant files cluster at
% 33.45 s and almost none contain 36 s. Treat MAT sample 1 as video onset
% for both roles and analyze the same following 33 s without time warping.
config.timing.teacherOffsetSeconds = 0;
config.timing.participantOffsetSeconds = 0;
config.timing.analysisDurationSeconds = 33;
config.timing.filterPaddingSeconds = 1;

% QTM preprocessing previously filled gaps <=50 ms. The shared MoCap
% toolbox repeats this rule and reconstructs longer gaps up to 2 s with
% cubic splines. At the required analysis boundaries only, nearest observed
% values provide filter continuity when two-sided interpolation is impossible.
% Observed coordinates are held fixed. Every originally missing timepoint
% remains in bad_segments and is never a covariance or downstream time-series
% observation; reconstruction exists solely to support resampling/filtering.
config.preprocessing.upstreamFilledGapLimitSeconds = 0.050;
config.preprocessing.shortGapInterpolationSeconds = 0.050;
config.preprocessing.maximumReconstructedGapSeconds = 2;
config.preprocessing.minimumCompleteTimepointFraction = 0.50;
config.preprocessing.reconstructionMethod = "cubic_spline";
config.preprocessing.boundaryMethod = "nearest";

% Match the DyadicDance template: [coordinates x time x participants], with
% model first and participant second. Single precision limits regenerated
% dyad outputs to a safe size without changing the raw inputs.
config.dyads.participantOrder = ["model","participant"];
config.dyads.storageClass = "single";
config.dyads.overwrite = false;
config.dyads.save = true;

% FULL-SKELETON POLICY: retain all 22 markers in one canonical order for
% every recording. Missing coordinates are reconstructed under the policy
% above but remain excluded samples. Recordings exceeding reconstruction or
% observed-data coverage limits are excluded rather than silently repaired.
config.markers.rawExpectedCount = 22;
config.markers.policyVersion = "full22_toolbox_context_v4";
config.markers.labels = {'L Elbow','L Wrist','L Hand','L Shoulder', ...
    'R Shoulder','Sternum','R Elbow','R Wrist','R Hand','L Hip', ...
    'R Hip','Pelvis','L Knee','R Knee','L Ankle','R Ankle', ...
    'L Foot','R Foot','B Head','L Head','R Head','T Head'};
config.markers.excludedLabels = {};
% Same anatomical link logic as DyadicDance, remapped to this study's
% marker order: head, upper torso, arms, pelvis and both legs.
config.markers.bones = [20,22;22,21;21,19;19,20;19,6; ...
    4,6;6,5;4,5;4,1;1,2;2,3;5,7;7,8;8,9; ...
    6,12;10,12;11,12;10,11;10,13;13,15;15,17; ...
    11,14;14,16;16,18];
config.markers.expectedCount = numel(config.markers.labels);

% Exact optional-argument convention used by FREQNESS NetworkEstimation.
config.network.badSegmentsOptionName = "bad_segments";

% BLOCK 1 - NETWORK ESTIMATION. Match FREQNESS_DyadicDance_Mocap naming
% and frequency construction. The confirmed beat frequency is 1.67 Hz in
% every trial and condition. Model and participant share the teacher-video
% stimulus, hence the same frequency vector is assigned to both members of
% every artificial dyad.
config.block1.run = false;
config.block1.beat_frex = 1.67*ones(1,2);
frex_vector = (config.block1.beat_frex(1)/4: ...
    config.block1.beat_frex(1)/8:config.block1.beat_frex(1)*4)';
config.block1.frex = repmat(frex_vector,1,2);
config.block1.duration = config.timing.analysisDurationSeconds;
config.block1.fwidth = [];
config.block1.filter = 'logarithmic';
config.block1.regularisation = 0.01;
config.block1.ncomps = 4;
config.block1.overwrite_flag = false;
config.block1.save_flag = true;
config.block1.max_dyads = inf;

% BLOCK 2 - NETWORK LANDSCAPES AND EFFECTIVE DIMENSIONALITY. Per-recording
% outputs follow the DyadicDance variables. The group file is deliberately
% a lightweight design catalogue; complete arrays remain in individual
% FREQ files and are loaded only when a downstream analysis requires them.
config.block2.run = false;
config.block2.output_path = fullfile(config.paths.outputRoot,'02_Landscape');
config.block2.overwrite_flag = false;
config.block2.save_flag = true;
config.block2.ncomps2keep = 4;
config.block2.max_dyads = inf;
% Permit only negligible negative mass caused by floating-point GED noise.
% The complete retained-sample audit found a maximum negative/positive mass
% ratio of 1.54e-4 (0.0154%); use a 2e-4 ceiling. BLOCK 2 clips accepted
% values, preserves each spectrum's sum, records the correction in QC, and
% still rejects any spectrum exceeding this empirically verified bound.
config.block2.eigenvalue_negative_tolerance = 2e-4;

% BLOCK 3 - INTERACTION ANALYSES, in this order: gap-aware phase-space RQA,
% spatial coordination, and network-landscape similarity. JRQA is disabled
% because it cannot exclude gappy samples without biasing recurrence.
config.block3.run = false;
config.block3.output_path = fullfile(config.paths.outputRoot,'03_Interaction');
config.block3.rqa_output_path = fullfile(config.block3.output_path, ...
    '01_PhaseSpaceRQA');
config.block3.spatial_output_path = fullfile(config.block3.output_path, ...
    '02_SpatialAndLandscape');
config.block3.overwrite_flag = false;
config.block3.save_flag = true;
config.block3.components = 1:2;
config.block3.metric_levels = [.25 .5 1 2];
% Empty selects the complete FREQ.frex grid. Optional bounds are matched
% to the nearest available frequencies by FREQNESS_LandscapeSimilarity.
config.block3.landscape_frequency_range = [];
config.block3.max_dyads = inf;
% RQA-specific settings within BLOCK 3.
config.block3.rqa_downsample_factor = 5;
config.block3.rqa_lp_order = 4;
config.block3.rqa_lp_cutoff_norm = .8;
config.block3.rqa_duration = [.15 .85];
config.block3.rqa_standardize = true;
config.block3.rqa_threshold_method = 'max_fraction';
config.block3.rqa_threshold = .1;
config.block3.rqa_theiler_window = 0;
config.block3.rqa_lmin = 2;
config.block3.rqa_vmin = 2;
config.block3.rqa_store_matrices = false;
config.block3.rqa_figure = false;
config.block3.rqa_animate = false;

% BLOCK 4 - GROUP-LEVEL SUMMARIES AND VISUALIZATION. Stream individual
% results condition by condition; save means/SEMs rather than dense copies
% of every FREQ output.
config.block4.run = false;
config.block4.output_path = fullfile(config.paths.outputRoot,'04_Group');
config.block4.figure_path = fullfile(config.block4.output_path,'Figures');
config.block4.overwrite_flag = false;
config.block4.save_flag = true;
config.block4.make_figures = true;
config.block4.ncomps2keep = 4;
config.block4.pattern_components = 1:2;
config.block4.pattern_frequencies = [.25 .5 1 2];
config.block4.plot_pattern_bones = true;
config.block4.max_dyads = inf;

% BLOCK 5 - R-READY STATISTICAL EXPORT. Trial-level interaction results
% remain in BLOCK 3; this export averages repetitions within participant and
% factorial cell before statistical modelling.
config.block5.run = false;
config.block5.output_path = fullfile(config.paths.outputRoot, ...
    '05_Statistics_R');
config.block5.overwrite_flag = false;
config.block5.write_xlsx = true;

% EXCLUDED-RECORDING SENSITIVITY ANALYSIS. This is deliberately separate
% from the primary output tree. Only the participant-folder annotations are
% waived for the named participants; every objective file, timing, marker,
% sample-rate, gap-reconstruction, and coverage rule remains unchanged.
config.sensitivity.run = false;
config.sensitivity.refresh_qc = false;
config.sensitivity.run_recovery_core = true;
config.sensitivity.run_recovered_blocks = true;
config.sensitivity.build_combined_outputs = true;
config.sensitivity.run_statistics = true;
config.sensitivity.compare_results = true;
config.sensitivity.overwrite = false;
config.sensitivity.subjects = ["002" "022" "046"];
config.sensitivity.subject_annotations = [ ...
    "only 5 recordings" ...
    "very bad quality; disappeared hips" ...
    "only 28 recordings"];
config.sensitivity.output_root = fullfile(config.paths.outputRoot, ...
    '08_ExcludedSensitivity');

config.naming.teacherFolder = "Michalina";
config.output.figureVisible = "on";

end
