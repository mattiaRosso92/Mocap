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

% ALIGNMENT CONTRACT: both recordings start from the shared trigger.
% Teacher video time is trigger+0 s; participant video time is trigger+3 s
% after the cue/wait interval. Analyze the following 33 seconds.
config.timing.teacherOffsetSeconds = 0;
config.timing.participantOffsetSeconds = 3;
config.timing.analysisDurationSeconds = 33;
config.timing.filterPaddingSeconds = 1;

% Provisional study-level missing-data rule. Review the empirical gap-length
% distribution before batch analysis; longer or edge gaps remain invalid.
config.preprocessing.maxInterpolatedGapSeconds = 0.25;

config.naming.teacherFolder = "Michalina";
config.output.figureVisible = "on";

end
