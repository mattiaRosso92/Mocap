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

% CRITICAL CONTRACT CHECK: artificial dyads use the optional bad_segments
% convention. Confirm that the active MoCap estimator excludes those samples
% from both covariance matrices before permitting core network analysis.
networkEstimatorContract = ...
    EmpaticMirroring_CheckNetworkEstimatorContract(config);
assert(networkEstimatorContract.ReadyForNetworkEstimation, ...
    'The active MoCap network estimator is incompatible with bad_segments.');

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

%% 4. Materialize artificial dyads in the DyadicDance input format

% markData is [XYZ marker coordinates x time x participants], ordered model
% then participant. bad_segments is the synchronized union of the two
% participant-specific lists, so both covariance matrices use the same times.
% Each condition-labelled model file is imported, downsampled, aligned, and
% assigned its post-resampling bad-sample mask once, then reused for all dyads.
% Each dyad (including its bad-sample lists) is saved in that participant's
% outputs/participants/<ID> folder; core FREQ outputs use it as well.
[dyadManifest,dyadSummary] = ...
    EmpaticMirroring_CreateArtificialDyads(dyadManifest,config,frameQC);

fprintf('Artificial dyads available: %d\n',dyadSummary.availableCount);
fprintf('Network estimator compatible with bad_segments: %d\n', ...
    networkEstimatorContract.ReadyForNetworkEstimation);

%% ========================================================================
% BLOCK 1 - NETWORK ESTIMATION
% =========================================================================
% The core runner follows FREQNESS_DyadicDance_Mocap: analyze each dyad in
% [coordinates x time x participants] format, retain the complete
% eigenspectrum, and save the FREQ output beside that participant's dyad.
% The synchronized bad_segments union is passed to NetworkEstimation so both
% covariance matrices use identical valid samples. Existing valid outputs are
% skipped unless overwrite is enabled, making interrupted runs resumable.

if config.block1.run
    [dyadManifest,coreSummary] = EmpaticMirroring_RunCoreAnalysis( ...
        dyadManifest,config,networkEstimatorContract);
    fprintf('Core FREQ-NESS outputs available: %d\n', ...
        coreSummary.availableCount);
else
    fprintf(['Core FREQ-NESS analysis is configured but disabled. ' ...
        'The confirmed 1.67 Hz beat frequency is configured; set ' ...
        'config.block1.run = true for the production run.\n']);
end


%% ========================================================================
% BLOCK 2 - NETWORK LANDSCAPES AND EFFECTIVE DIMENSIONALITY
% =========================================================================
% As in FREQNESS_DyadicDance_Mocap, retain the complete eigenspectrum for
% effective dimensionality and only the requested leading spatial patterns
% for later visualization. Complete FREQ arrays remain in one file per
% recording rather than being duplicated in a large dense group file. A
% lightweight catalogue indexes participants x conditions x repetitions;
% the 24 conditions encode Instruction x Complexity x Version x Movement.
% Missing/excluded recordings are absent and false in validTrialMask.

if config.block2.run
    [dyadManifest,landscapeSummary] = ...
        EmpaticMirroring_RunLandscapeAnalysis(dyadManifest,config);
    fprintf('BLOCK 2 landscape outputs available: %d\n', ...
        landscapeSummary.availableCount);
else
    fprintf(['BLOCK 2 network landscapes are configured but disabled. ' ...
        'Set config.block2.run = true after BLOCK 1 outputs exist.\n']);
end


%% ========================================================================
% BLOCK 3 - SPATIAL COORDINATION
% =========================================================================
% Mirror the DyadicDance spatial-mirroring analysis for every requested
% component and metric level. JRQA is disabled because it cannot exclude
% gappy samples safely. Each recording/component is saved independently;
% compact MIRROR arrays retain participant x condition x metric x repetition
% indexing for the 24-cell repeated-measures design.

if config.block3.run
    [dyadManifest,coordinationSummary] = ...
        EmpaticMirroring_RunCoordinationAnalysis(dyadManifest,config);
    fprintf('BLOCK 3 coordination outputs available: %d\n', ...
        coordinationSummary.availableCount);
else
    fprintf(['BLOCK 3 coordination analysis is configured but disabled. ' ...
        'Set config.block3.run = true after BLOCK 1 outputs exist.\n']);
end


%% ========================================================================
% BLOCK 4 - PHASE-SPACE RQA (TEMPORAL COORDINATION)
% =========================================================================
% Follow the DyadicDance phase-space RQA block using the selected components,
% metric levels, proportional interval, anti-alias filter, and 24 Hz working
% rate. One result is saved per recording/component and compact summaries
% retain the complete 24-cell experimental design.

if config.block4.run
    [dyadManifest,phaseRQASummary] = ...
        EmpaticMirroring_RunPhaseSpaceRQA(dyadManifest,config);
    fprintf('BLOCK 4 phase-space RQA outputs available: %d\n', ...
        phaseRQASummary.availableCount);
else
    fprintf(['BLOCK 4 phase-space RQA is configured but disabled. ' ...
        'Set config.block4.run = true after BLOCK 1 outputs exist.\n']);
end


%% ========================================================================
% BLOCK 5 - GROUP-LEVEL SUMMARIES AND VISUALIZATION
% =========================================================================
% Match the DyadicDance group outputs without loading or saving one dense
% copy of the complete experiment. Repetitions are averaged within each
% participant-condition cell first; participant means and SEM then use the
% participant as the inferential unit. The 24 factorial cells remain separate.

if config.block5.run
    groupSummary = EmpaticMirroring_RunGroupAnalysis(dyadManifest,config);
    fprintf('BLOCK 5 retained recordings: %d\n', ...
        groupSummary.recordingCount);
else
    fprintf(['BLOCK 5 group analysis is configured but disabled. ' ...
        'Enable it after BLOCKS 1-4 have completed.\n']);
end


%% ========================================================================
% BLOCK 6 - R-READY STATISTICAL EXPORT
% =========================================================================
% As in DyadicDance, average repeated recordings before final modelling.
% Export one row per Participant x Instruction x Complexity x Version x
% Movement x Meter x Component. Trial-level outputs remain available in the
% individual BLOCK 3 and BLOCK 4 files for audit.

if config.block6.run
    statisticsSummary = EmpaticMirroring_ExportStatistics(config);
    fprintf('BLOCK 6 statistical rows exported: %d\n', ...
        statisticsSummary.rowCount);
else
    fprintf(['BLOCK 6 statistical export is configured but disabled. ' ...
        'Enable it after BLOCKS 3 and 4 have completed.\n']);
end
