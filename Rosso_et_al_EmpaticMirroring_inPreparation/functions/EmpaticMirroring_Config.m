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

% QTM preprocessing already filled gaps <=50 ms. Remaining missing samples
% are never treated as observations: they are represented by finite zero
% placeholders and listed in bad_segments for covariance exclusion.
config.preprocessing.upstreamFilledGapLimitSeconds = 0.050;

% Match the DyadicDance template: [coordinates x time x participants], with
% model first and participant second. Single precision limits regenerated
% dyad outputs to a safe size without changing the raw inputs.
config.dyads.participantOrder = ["model","participant"];
config.dyads.storageClass = "single";
config.dyads.overwrite = false;
config.dyads.save = true;

% Every valid QTM export is expected to use the shared 22-marker layout.
config.markers.expectedCount = 22;

% Exact optional-argument convention used by FREQNESS NetworkEstimation.
config.network.badSegmentsOptionName = "bad_segments";

% BLOCK 1 - NETWORK ESTIMATION. Match FREQNESS_DyadicDance_Mocap naming
% and frequency construction. The confirmed beat frequency is 1.67 Hz in
% every trial and condition. Model and participant share the teacher-video
% stimulus, hence the same frequency vector is assigned to both members of
% every artificial dyad.
config.block1.run = false;
config.block1.beat_frex = 1.67*ones(1,2);
frex_vector = (config.block1.beat_frex(1)/8: ...
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

% BLOCK 3 - SPATIAL COORDINATION. JRQA is disabled because it cannot exclude
% the study's gappy samples without biasing temporal recurrence estimates.
config.block3.run = false;
config.block3.output_path = fullfile(config.paths.outputRoot, ...
    '03_Coordination');
config.block3.overwrite_flag = false;
config.block3.save_flag = true;
config.block3.components = 1:2;
config.block3.metric_levels = [.25 .5 1 2];
config.block3.max_dyads = inf;

% BLOCK 4 - GAP-AWARE PHASE-SPACE RQA. Filter continuous valid runs
% independently, downsample to 24 Hz, and exclude remapped bad samples.
config.block4.run = false;
config.block4.output_path = fullfile(config.paths.outputRoot, ...
    '04_PhaseSpaceRQA');
config.block4.overwrite_flag = false;
config.block4.save_flag = true;
config.block4.components = 1:2;
config.block4.metric_levels = [.25 .5 1 2];
config.block4.downsample_factor = 5;
config.block4.lp_order = 4;
config.block4.lp_cutoff_norm = .8;
config.block4.duration = [.15 .85];
config.block4.standardize = true;
config.block4.threshold_method = 'max_fraction';
config.block4.threshold = .1;
config.block4.theiler_window = 0;
config.block4.lmin = 2;
config.block4.vmin = 2;
config.block4.store_matrices = false;
config.block4.figure = false;
config.block4.animate = false;
config.block4.max_dyads = inf;

% BLOCK 5 - GROUP-LEVEL SUMMARIES AND VISUALIZATION. Stream individual
% results condition by condition; save means/SEMs rather than dense copies
% of every FREQ output.
config.block5.run = false;
config.block5.output_path = fullfile(config.paths.outputRoot,'05_Group');
config.block5.figure_path = fullfile(config.block5.output_path,'Figures');
config.block5.overwrite_flag = false;
config.block5.save_flag = true;
config.block5.make_figures = true;
config.block5.ncomps2keep = 4;
config.block5.pattern_components = 1:2;
config.block5.pattern_frequencies = [.25 .5 1 2];
config.block5.plot_pattern_bones = false;
config.block5.max_dyads = inf;

% BLOCK 6 - R-READY STATISTICAL EXPORT. Trial-level results remain in
% BLOCKS 3-4; this export averages repetitions within each participant and
% factorial cell before statistical modelling.
config.block6.run = false;
config.block6.output_path = fullfile(config.paths.outputRoot, ...
    '06_Statistics_R');
config.block6.overwrite_flag = false;
config.block6.write_xlsx = true;

config.naming.teacherFolder = "Michalina";
config.output.figureVisible = "on";

end
