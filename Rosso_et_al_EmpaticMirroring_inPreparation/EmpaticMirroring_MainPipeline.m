%% EMPATIC MIRRORING: COMPLETE FREQ-NESS MOCAP PIPELINE
% This script is deliberately written as one chronological study workflow.
% The scientific choices and every analysis stage are visible here; helper
% functions are used only for repetitive file parsing, alignment, compact
% bookkeeping, and plotting.

clear
close all
clc


%% SETUP - USER SETTINGS, STARTUP, AND OUTPUT ROUTING

script_file = mfilename('fullpath');
if isempty(script_file)
    try
        script_file = matlab.desktop.editor.getActiveFilename;
    catch
        script_file = '';
    end
end
assert(~isempty(script_file), ...
    'Open EmpaticMirroring_MainPipeline.m in MATLAB before running it.');
path_study = fileparts(script_file);
path_repo = fileparts(path_study);
addpath(fullfile(path_study,'functions'));

config = EmpaticMirroring_Config();
config.paths.studyRoot = path_study;
config.paths.repositoryRoot = path_repo;
config.paths.dataRoot = fullfile(path_study,'EmpaticMirrorring_Data');
config.paths.toolboxRoot = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');

% Run every block by default. Existing compatible outputs are reused unless
% EMPATIC_MIRRORING_OVERWRITE=1 is set for a deliberate production rebuild.
run_blocks = true(1,6);
overwrite = strcmp(getenv('EMPATIC_MIRRORING_OVERWRITE'),'1');
config.dyads.overwrite = overwrite;
config.block1.overwrite_flag = overwrite;
config.block2.overwrite_flag = overwrite;
config.block3.overwrite_flag = overwrite;
config.block4.overwrite_flag = overwrite;
config.block5.overwrite_flag = overwrite;
config.block1.run = run_blocks(1);
config.block2.run = run_blocks(2);
config.block3.run = run_blocks(3);
config.block4.run = run_blocks(4);
config.block5.run = run_blocks(5);
run_R_statistics = run_blocks(6);

% Sampling and alignment. Both roles use the common trigger and retain the
% same [0,33 s) interval. Although acquisition included a 3 s cue/wait for
% participants, frame counts show that it was removed before MAT export;
% adding another 3 s offset would misalign the artificial dyads.
srate_teacher = 300;
srate_participant = 120;
srate = 120;
analysis_duration = 33;
config.sampling.teacherHz = srate_teacher;
config.sampling.participantHz = srate_participant;
config.sampling.outputHz = srate;
config.timing.teacherOffsetSeconds = 0;
config.timing.participantOffsetSeconds = 0;
config.timing.analysisDurationSeconds = analysis_duration;

% Gap policy. The QTM preprocessing phase had already filled gaps <=50 ms.
% The toolbox checks again, linearly interpolates gaps <=50 ms, reconstructs
% supported gaps <=2 s with cubic splines, and uses nearest observed values
% only at analysis boundaries where two-sided interpolation is impossible.
% Every affected timepoint is returned in bad_segments. Reconstructed values
% support filtering only; they never enter covariance or downstream
% time-resolved estimates.
config.preprocessing.shortGapInterpolationSeconds = .050;
config.preprocessing.maximumReconstructedGapSeconds = 2;
config.preprocessing.minimumCompleteTimepointFraction = .50;

% Full 22-marker layout. The same skeleton is used for model and participant.
marklabels = config.markers.labels;
bones = config.markers.bones;

% Confirmed beat and frequency grid: beat/4 to 4x beat in beat/8 steps.
beat_frex = 1.67*ones(1,2);
frex_vector = (beat_frex(1)/4:beat_frex(1)/8:beat_frex(1)*4)';
frex = repmat(frex_vector,1,2);
meter = [.25 .5 1 2];
components = 1:2;
config.block1.beat_frex = beat_frex;
config.block1.frex = frex;
config.block1.duration = analysis_duration;
config.block3.components = components;
config.block3.metric_levels = meter;
config.block3.landscape_frequency_range = []; % [] = complete FREQ.frex grid

% Analyse every objectively usable recording, including the three annotated
% participant folders previously treated as a sensitivity cohort. Folder
% annotations alone are waived; malformed, too-short, unreconstructable, or
% otherwise objectively invalid recordings remain excluded.
annotated_subjects = config.sensitivity.subjects;

assert(isfolder(config.paths.dataRoot), ...
    'Data directory not found: %s',config.paths.dataRoot);
assert(isfolder(config.paths.toolboxRoot), ...
    'FREQ-NESS MoCap toolbox not found: %s',config.paths.toolboxRoot);
addpath(config.paths.toolboxRoot);
addpath(fullfile(config.paths.toolboxRoot,'FREQNESS_Functions'));
addpath(fullfile(config.paths.toolboxRoot,'FREQNESS_ExternalFunctions'));

output_paths = {config.paths.outputRoot,config.paths.qcOutputRoot, ...
    config.paths.modelOutputRoot,config.paths.participantsOutputRoot, ...
    config.block2.output_path,config.block3.output_path, ...
    config.block3.rqa_output_path,config.block3.spatial_output_path, ...
    config.block4.output_path,config.block4.figure_path, ...
    config.block5.output_path};
for pathi = 1:numel(output_paths)
    if ~isfolder(output_paths{pathi})
        mkdir(output_paths{pathi})
    end
end

save(fullfile(config.paths.outputRoot, ...
    'EmpaticMirroring_RunConfiguration.mat'),'config','run_blocks', ...
    'overwrite','beat_frex','frex','meter','components');


%% DATA PREPARATION - FRAME COUNTS, QUALITY, AND ANALYSIS COHORT

% Recordings started automatically but were stopped manually. The first QC
% output is therefore a histogram of frame counts. A recording must contain
% the complete real 33 s window (9900 teacher or 3960 participant frames);
% missing duration is never synthesized or time-warped.
frameQC = EmpaticMirroring_FrameCountQC(config);

% Apply the folder-annotation waiver while retaining every objective QC rule.
[~,recoveryAudit,recoverySummary] = ...
    EmpaticMirroring_BuildRecoverySensitivityQC(frameQC,config);
analysisQC = frameQC;
recovered_files = string(recoveryAudit.File( ...
    recoveryAudit.RecoverForSensitivity));
recovered_rows = ismember(string(analysisQC.File),recovered_files);
analysisQC.FolderStatus(recovered_rows) = "ok";
analysisQC.OverallStatus(recovered_rows) = "included after annotation audit";
analysisQC.ExcludeRecording(recovered_rows) = false;
analysisQC.ExclusionReasons(recovered_rows) = "";
analysisQC.ReadyForAlignment(recovered_rows) = true;
writetable(analysisQC,fullfile(config.paths.qcOutputRoot, ...
    'all_possible_participants_qc.csv'));
exclusionReports = EmpaticMirroring_BuildExclusionReports(analysisQC,config);

fprintf('\nAll-possible-participants cohort: %d annotated recordings recovered.\n', ...
    recoverySummary.recoveredCount);
fprintf('Annotated subjects reviewed: %s\n', ...
    strjoin(annotated_subjects,', '));


%% DATA PREPARATION - ARTIFICIAL DYADS

% Pairing ignores Instruction because the model stimulus is identical for
% observation and imitation. Complexity, Version, and Movement select the
% presented model clip. The model performed one physical complexity level;
% low/medium/high describe music overlaid later and are retained as design
% labels. Acquisition-order indices 1-48 are provenance only.
dyadManifest = EmpaticMirroring_BuildDyadManifest(analysisQC,config);
[dyadManifest,dyadSummary] = EmpaticMirroring_CreateArtificialDyads( ...
    dyadManifest,config,analysisQC);
assert(dyadSummary.errorCount == 0 && ...
    dyadSummary.availableCount == dyadSummary.eligibleCount, ...
    'Artificial-dyad generation was incomplete.');

% Each dyad is [66 XYZ coordinates x 3960 samples x 2 members], ordered
% model then participant. Model clips are imported/downsampled once and
% reused. Anti-aliasing is supplied by MATLAB resample during 300->120 Hz
% conversion. The toolbox, not this study script, performs gap reconstruction.


%% BLOCK 1 - FREQ-NESS CORE NETWORK ESTIMATION

% FREQNESS_NetworkEstimation_Mocap retains the full eigenspectrum and the
% requested four patterns/time series. Dyad preparation calls the shared
% FREQNESS_InterpolateGaps_Mocap routine before teacher resampling; the core
% estimator scans again for any remaining NaNs and combines detected samples
% with the supplied model/participant bad_segments union.
networkEstimatorContract = ...
    EmpaticMirroring_CheckNetworkEstimatorContract(config);
assert(networkEstimatorContract.ReadyForNetworkEstimation, ...
    'The active MoCap estimator is incompatible with bad_segments.');
if config.block1.run
    [dyadManifest,coreSummary] = EmpaticMirroring_RunCoreAnalysis( ...
        dyadManifest,config,networkEstimatorContract);
    assert(coreSummary.errorCount == 0,'BLOCK 1 produced errors.');
end


%% BLOCK 2 - ROLE-SPECIFIC LANDSCAPES AND EFFECTIVE DIMENSIONALITY

% The artificial dyad is asymmetric. Network landscapes and H2-derived
% effective dimensionality are therefore retained separately for teacher
% and experimental participant. Teacher curves are descriptive and carry no
% SEM because repeated teacher copies are not independent observations.
if config.block2.run
    [dyadManifest,landscapeSummary] = ...
        EmpaticMirroring_RunLandscapeAnalysis(dyadManifest,config);
    assert(landscapeSummary.errorCount == 0,'BLOCK 2 produced errors.');
end


%% BLOCK 3 - INTERACTION ANALYSES

% The interaction family is intentionally ordered as temporal recurrence,
% spatial coordination, then similarity of frequency-resolved landscapes.
% JRQA remains disabled because it cannot honour bad_segments without
% biasing its recurrence matrix.
if config.block3.run
    % 3A. Temporal coordination: gap-aware phase-space RQA.
    [dyadManifest,phaseRQASummary] = ...
        EmpaticMirroring_RunPhaseSpaceRQA(dyadManifest,config);
    assert(phaseRQASummary.errorCount == 0, ...
        'BLOCK 3 phase-space RQA produced errors.');

    % 3B. Spatial coordination, followed by 3C landscape similarity.
    [dyadManifest,coordinationSummary] = ...
        EmpaticMirroring_RunCoordinationAnalysis(dyadManifest,config);
    assert(coordinationSummary.errorCount == 0, ...
        'BLOCK 3 spatial/landscape analyses produced errors.');
end


%% BLOCK 4 - GROUP SUMMARIES AND FIGURES

% Repetitions are averaged inside Participant x factorial cell first. Group
% means and SEM then use participant as the inferential unit. Participant and
% teacher network landscapes/ED remain separate; interaction outcomes include
% spatial coordination, landscape similarity, and phase-space RQA.
if config.block4.run
    groupSummary = EmpaticMirroring_RunGroupAnalysis(dyadManifest,config);
end


%% BLOCK 5 - R-READY EXPORTS

% The meter-resolved file contains spatial coordination and phase-space RQA.
% Landscape similarity has no Meter factor because it correlates trajectories
% across frequencies, and is exported in its own participant-cell table.
if config.block5.run
    statisticsSummary = EmpaticMirroring_ExportStatistics(config);
end


%% BLOCK 6 - MIXED-EFFECTS MODELS IN R

% Existing outcomes retain the full five-factor model including Meter.
% Component- and entropy-landscape similarities use the four-factor model
% Instruction * Complexity * Version * Movement, with participant intercepts.
if run_R_statistics
    statistics_script = fullfile(path_study,'EmpaticMirroring_Stats.R');
    command = sprintf('Rscript "%s" --overwrite',statistics_script);
    [R_status,R_output] = system(command);
    fprintf('%s\n',R_output);
    assert(R_status == 0,'R statistical modelling failed.');
end


%% VALIDATION - NUMERICAL REPLICATION AUDIT

% Compare all previously available dependent variables against the earlier
% all-possible-participants (primary + recovered) export. Landscape similarity
% is new and therefore has no legacy comparator.
legacy_file = fullfile(config.paths.outputRoot,'08_ExcludedSensitivity', ...
    'CombinedPrimaryPlusRecovered','06_Statistics_R', ...
    'OUT2R_AllComponents.csv');
current_file = fullfile(config.block5.output_path, ...
    'OUT2R_AllComponents.csv');
if isfile(legacy_file) && isfile(current_file)
    replicationAudit = compareStatisticalExports(legacy_file,current_file);
    audit_folder = fullfile(config.paths.outputRoot,'07_CleanupValidation');
    if ~isfolder(audit_folder)
        mkdir(audit_folder)
    end
    writetable(replicationAudit,fullfile(audit_folder, ...
        'Legacy_vs_CleanPipeline_NumericalAudit.csv'));
    disp(replicationAudit)
end

fprintf('\nEmpatic Mirroring pipeline complete.\n');
fprintf('Artificial dyads available: %d\n',dyadSummary.availableCount);
if exist('statisticsSummary','var')
    fprintf('Meter-resolved statistical rows: %d\n', ...
        statisticsSummary.rowCount);
    fprintf('Landscape-similarity statistical rows: %d\n', ...
        height(statisticsSummary.landscapeSimilarityTable));
end


function audit = compareStatisticalExports(legacyFile,currentFile)
% Compare common rows without rounding and report cohort as well as values.

legacy = readtable(legacyFile,'TextType','string', ...
    'VariableNamingRule','preserve');
current = readtable(currentFile,'TextType','string', ...
    'VariableNamingRule','preserve');
keys = {'Participant','Instruction','Complexity','Version','Movement', ...
    'Meter','Component'};
legacy = sortrows(legacy,keys);
current = sortrows(current,keys);
[~,legacyCommon,currentCommon] = intersect( ...
    rowKeys(legacy,keys),rowKeys(current,keys),'stable');
sameKeys = height(legacy) == height(current) && ...
    numel(legacyCommon) == height(legacy);

common = intersect(legacy.Properties.VariableNames, ...
    current.Properties.VariableNames,'stable');
legacyNumeric = varfun(@isnumeric,legacy(:,common),'OutputFormat','uniform');
currentNumeric = varfun(@isnumeric,current(:,common),'OutputFormat','uniform');
numeric = common(legacyNumeric & currentNumeric);
numeric = setdiff(numeric,[keys {'Condition','MeterLevel'}],'stable');

Variable = string(numeric(:));
LegacyRows = repmat(height(legacy),numel(numeric),1);
CurrentRows = repmat(height(current),numel(numeric),1);
KeysMatchExactly = repmat(sameKeys,numel(numeric),1);
CommonRows = repmat(numel(legacyCommon),numel(numeric),1);
LegacyOnlyRows = repmat(height(legacy)-numel(legacyCommon),numel(numeric),1);
CurrentOnlyRows = repmat(height(current)-numel(currentCommon),numel(numeric),1);
MaximumAbsoluteDifference = nan(numel(numeric),1);
MeanAbsoluteDifference = nan(numel(numeric),1);
ExactlyEqual = false(numel(numeric),1);
for variablei = 1:numel(numeric)
    if ~isempty(legacyCommon)
        left = legacy.(numeric{variablei})(legacyCommon);
        right = current.(numeric{variablei})(currentCommon);
        difference = abs(left-right);
        MaximumAbsoluteDifference(variablei) = max(difference,[],'omitnan');
        MeanAbsoluteDifference(variablei) = mean(difference,'omitnan');
        ExactlyEqual(variablei) = isequaln(left,right);
    end
end
audit = table(Variable,LegacyRows,CurrentRows,KeysMatchExactly,CommonRows, ...
    LegacyOnlyRows,CurrentOnlyRows, ...
    MaximumAbsoluteDifference,MeanAbsoluteDifference,ExactlyEqual);

end


function keys = rowKeys(data,keyNames)

keys = strings(height(data),1);
for keyi = 1:numel(keyNames)
    keys = keys + "|" + string(data.(keyNames{keyi}));
end

end
