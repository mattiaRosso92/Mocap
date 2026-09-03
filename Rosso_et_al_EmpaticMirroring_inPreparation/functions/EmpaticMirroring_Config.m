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

% QTM preprocessing already filled gaps <=50 ms. Do not interpolate again:
% any remaining missing trajectory data are reported and excluded.
config.preprocessing.upstreamFilledGapLimitSeconds = 0.050;

config.naming.teacherFolder = "Michalina";
config.output.figureVisible = "on";

end
