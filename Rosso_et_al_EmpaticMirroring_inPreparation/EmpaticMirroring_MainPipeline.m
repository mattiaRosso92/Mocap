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
% LENGTH POLICY: require this complete real interval (teacher: 9900 frames;
% participant: 4320 frames); never stretch or fill a missing duration. Files
% that are too short are excluded. A missing optional 1 s filtering guard is
% supplied only by reflection padding outside the retained analysis window.
% Earlier QTM preprocessing trimmed small edge intervals (movement 1: about
% 1.26 s at the start and 5.12 s at the end; movement 2: about 0.26 s and
% 2.11 s). These historical trims are documented but need no extra action.

frameQC = EmpaticMirroring_FrameCountQC(config);

%% 2. Build the artificial-dyad manifest

% Trial indices 1-48 encode acquisition order only and are retained solely
% for provenance. Annotated/nonconforming files or folders are QC-listed but
% excluded. Model complexity labels refer to overlaid music—the same model
% movement was reused—yet complexity/version/movement still select the
% corresponding model stimulus file for every participant condition.

dyadManifest = EmpaticMirroring_BuildDyadManifest(frameQC,config);

participantRows = frameQC.Role == "participant";
participantReadyFraction = nnz(frameQC.ReadyForAlignment & participantRows) / ...
    max(1,nnz(participantRows));
if participantReadyFraction < 0.9
    % Most participant MAT files are only about 33.5 s long, inconsistent
    % with a trigger+3-to+36 s crop. Keep batch alignment disabled until it
    % is confirmed whether these exports already start at video onset; if
    % so, the participant offset should be changed to 0 s, not padded.
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
