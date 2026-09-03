%% Empatic mirroring: main study pipeline
% Study-specific orchestration belongs here. The reusable FREQ-NESS MoCap
% toolbox is treated as a dependency and is not modified by this pipeline.

clearvars
close all
clc

studyRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(studyRoot,'functions'));

config = EmpaticMirroring_Config();

assert(isfolder(config.paths.dataRoot), ...
    'Data directory not found: %s',config.paths.dataRoot);
assert(isfolder(config.paths.toolboxRoot), ...
    'FREQ-NESS MoCap toolbox not found: %s',config.paths.toolboxRoot);

% Add only the toolbox code used by this study. Do not invoke the general
% startup loader because study data remain outside FREQNESS_Data.
addpath(config.paths.toolboxRoot);
addpath(fullfile(config.paths.toolboxRoot,'FREQNESS_Functions'));
addpath(fullfile(config.paths.toolboxRoot,'FREQNESS_ExternalFunctions'));

%% 1. Frame-count and file-structure quality control
% FRAME-COUNT QC: Recordings started automatically from the shared trigger
% but were stopped manually. Inspect all frame counts before preprocessing;
% participant analysis uses trigger+3 s through trigger+36 s (33 s total).

frameQC = EmpaticMirroring_FrameCountQC(config);

%% 2. Build the artificial-dyad manifest

dyadManifest = EmpaticMirroring_BuildDyadManifest(frameQC,config);

participantRows = frameQC.Role == "participant";
participantReadyFraction = nnz(frameQC.ReadyForAlignment & participantRows) / ...
    max(1,nnz(participantRows));
if participantReadyFraction < 0.9
    warning('EmpaticMirroring:TimingWindowMismatch', ...
        ['Only %.1f%% of participant files contain the configured ' ...
         'trigger+3 s through trigger+36 s interval. Confirm whether the ' ...
         'MAT exports already begin at video onset before batch alignment.'], ...
        100*participantReadyFraction);
end

fprintf('\nEmpatic mirroring pipeline initialization complete.\n');
fprintf('Files inspected: %d\n',height(frameQC));
fprintf('Candidate artificial dyads: %d\n',height(dyadManifest));
fprintf('Dyads ready for alignment: %d\n',nnz(dyadManifest.ReadyForAlignment));
fprintf('Review QC outputs in: %s\n\n',config.paths.qcOutputRoot);

%% 3. Alignment and FREQ-NESS analysis
% EmpaticMirroring_LoadRecording and EmpaticMirroring_AlignArtificialDyad
% implement the reviewed loading/alignment contract. Batch analysis will be
% enabled after the frame-count and pairing manifests have been reviewed.
