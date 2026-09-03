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
% but were stopped manually. Acquisition had a 3 s participant cue/wait;
% however, the processed MAT files cluster at 33.45 s and almost none reach
% 36 s, showing that this interval was already removed before export. Thus,
% MAT sample 1 is video onset for both roles and both retain [0,33 s).
% LENGTH POLICY: require this complete real interval (teacher: 9900 frames;
% participant: 3960 frames); never stretch or fill a missing duration. Files
% that are too short are excluded. A missing optional 1 s filtering guard is
% supplied only by reflection padding outside the retained analysis window.
% Earlier QTM preprocessing trimmed small edge intervals (movement 1: about
% 1.26 s at the start and 5.12 s at the end; movement 2: about 0.26 s and
% 2.11 s). These historical trims are documented but need no extra action.

frameQC = EmpaticMirroring_FrameCountQC(config);

%% 2. Export recording- and participant-level exclusion reports

exclusionReports = EmpaticMirroring_BuildExclusionReports(frameQC,config);

%% 3. Build the artificial-dyad manifest

% Trial indices 1-48 encode acquisition order only and are retained solely
% for provenance. Annotated/nonconforming files or folders are QC-listed but
% excluded. Model complexity labels refer to overlaid music—the same model
% movement was reused—yet complexity/version/movement still select the
% corresponding model stimulus file for every participant condition.

dyadManifest = EmpaticMirroring_BuildDyadManifest(frameQC,config);

participantRows = frameQC.Role == "participant" & ...
    frameQC.LoadStatus == "ok" & frameQC.FolderStatus == "ok" & ...
    frameQC.NameStatus == "ok";
participantLengthReadyFraction = nnz(participantRows & ...
    frameQC.LengthStatus ~= "too short") / max(1,nnz(participantRows));
if participantLengthReadyFraction < 0.9
    warning('EmpaticMirroring:TimingWindowMismatch', ...
        ['Only %.1f%% of metadata-valid participant files contain the ' ...
         'configured 33 s interval beginning at MAT sample 1.'], ...
        100*participantLengthReadyFraction);
end

fprintf('\nEmpatic mirroring pipeline initialization complete.\n');
fprintf('Files inspected: %d\n',height(frameQC));
fprintf('Candidate artificial dyads: %d\n',height(dyadManifest));
fprintf('Dyads ready for alignment: %d\n',nnz(dyadManifest.ReadyForAlignment));
fprintf('Participants excluded entirely: %d\n', ...
    height(exclusionReports.participantExclusions));
fprintf('Review QC outputs in: %s\n\n',config.paths.qcOutputRoot);

%% 4. Alignment and FREQ-NESS analysis
% EmpaticMirroring_LoadRecording and EmpaticMirroring_AlignArtificialDyad
% implement the reviewed loading/alignment contract. Batch analysis will be
% enabled after the frame-count and pairing manifests have been reviewed.
