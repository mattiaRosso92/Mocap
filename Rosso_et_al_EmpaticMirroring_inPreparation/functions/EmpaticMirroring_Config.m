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
% and frequency construction. The provisional beat frequency is 1.5 Hz;
% replace it when the definitive stimulus timing is available. Model and
% participant share the teacher-video stimulus, hence the same frequency
% vector is assigned to both members of every artificial dyad.
config.block1.run = false;
config.block1.beat_frex = 1.5*ones(1,2);
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

config.naming.teacherFolder = "Michalina";
config.output.figureVisible = "on";

end
