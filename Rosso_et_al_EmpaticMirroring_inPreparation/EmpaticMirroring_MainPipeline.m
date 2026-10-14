%% EMPATIC MIRRORING: COMPLETE FREQ-NESS MOCAP PIPELINE
% The entire study workflow is intentionally visible in this script. Study
% bookkeeping is implemented below in chronological order; only general
% FREQ-NESS operations are delegated to the MoCap toolbox.

clear
close all
clc


%% SETUP

script_file = mfilename('fullpath');
if isempty(script_file)
    script_file = matlab.desktop.editor.getActiveFilename;
end
assert(~isempty(script_file), ...
    'Open EmpaticMirroring_MainPipeline.m in MATLAB before running it.');
path_study = fileparts(script_file);
path_repo = fileparts(path_study);
path_data = fullfile(path_study,'EmpaticMirrorring_Data');
path_toolbox = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');
% Preserve the study's historical filtering by default. Select 'physical'
% to use the toolbox's frequency-calibrated widths for a new analysis.
filter_width_calibration = validatestring( ...
    'legacy',{'physical','legacy'});
filter_type = validatestring('logarithmic',{'logarithmic','linear'});
filter_output_tag = [filter_width_calibration '_' filter_type];
path_output = fullfile(path_study,'outputs',filter_output_tag);
path_qc = fullfile(path_output,'qc');
path_models = fullfile(path_output,'preprocessed_models');
path_participants = fullfile(path_output,'participants');
path_landscape = fullfile(path_output,'02_Landscape');
path_interaction = fullfile(path_output,'03_Interaction');
path_rqa = fullfile(path_interaction,'01_PhaseSpaceRQA');
path_spatial = fullfile(path_interaction,'02_SpatialAndLandscape');
path_group = fullfile(path_output,'04_Group');
path_figures = fullfile(path_group,'Figures');
path_metric_prominence = fullfile(path_group,'MetricProminence');
path_statistics = fullfile(path_output,'05_Statistics_R');

assert(isfolder(path_data),'Data directory not found: %s',path_data);
assert(isfolder(path_toolbox),'MoCap toolbox not found: %s',path_toolbox);
addpath(path_toolbox)
addpath(fullfile(path_toolbox,'FREQNESS_Functions'))
addpath(fullfile(path_toolbox,'FREQNESS_ExternalFunctions'))

output_paths = {path_output,path_qc,path_models,path_participants, ...
    path_landscape,path_interaction,path_rqa,path_spatial,path_group, ...
    path_figures,path_metric_prominence,path_statistics};
for pathi = 1:numel(output_paths)
    if ~isfolder(output_paths{pathi}); mkdir(output_paths{pathi}); end
end

% Run controls. Existing compatible outputs are reused by default. Set
% EMPATIC_MIRRORING_OVERWRITE=1 for a complete production rebuild.
run_blocks = true(1,6);
run_metric_prominence = true;
overwrite = strcmp(getenv('EMPATIC_MIRRORING_OVERWRITE'),'1');
save_flag = true;
vis_flag = true;
figure_visibility = 'on';
max_dyads = inf;
if strcmp(getenv('EMPATIC_MIRRORING_FIGURES'),'0')
    vis_flag = false;
    figure_visibility = 'off';
end

% Shared trigger-aligned interval. Acquisition included a 3 s cue/wait, but
% frame counts show that it was removed before participant MAT export. Both
% members therefore use [0,33 s); adding 3 s would misalign the dyad.
srate_teacher = 300;
srate_participant = 120;
srate = 120;
analysis_duration = 33;
teacher_offset = 0;
participant_offset = 0;
filter_padding = 1;

% QTM preprocessing filled gaps <=50 ms. The toolbox checks again, linearly
% interpolates gaps <=50 ms and reconstructs supported gaps <=2 s. Boundary
% values support filtering only. Every reconstructed timepoint stays in
% bad_segments and is excluded from FREQ-NESS and RQA estimates.
short_gap_seconds = .050;
maximum_reconstructed_gap_seconds = 2;
minimum_complete_timepoint_fraction = .50;
boundary_method = 'nearest';

% Full 22-marker skeleton, shared by teacher and participant.
marklabels = {'L Elbow','L Wrist','L Hand','L Shoulder', ...
    'R Shoulder','Sternum','R Elbow','R Wrist','R Hand','L Hip', ...
    'R Hip','Pelvis','L Knee','R Knee','L Ankle','R Ankle', ...
    'L Foot','R Foot','B Head','L Head','R Head','T Head'};
bones = [20,22;22,21;21,19;19,20;19,6;4,6;6,5;4,5;4,1;1,2;2,3; ...
    5,7;7,8;8,9;6,12;10,12;11,12;10,11;10,13;13,15;15,17; ...
    11,14;14,16;16,18];
marker_policy_version = "full22_toolbox_context_v4";

% Confirmed beat frequency and analysis grid: beat/4 to 4 x beat.
beat_frex = 1.67*ones(1,2);
frex_vector = (beat_frex(1)/4:beat_frex(1)/8:beat_frex(1)*4)';
frex = repmat(frex_vector,1,2);
meter = [.25 .5 1 2];
global_metric_levels = [.25 .5 1 2 3 4];
components = 1:2;
ncomps = 4;
regularisation = .01;
prominence_component = 1;
if strcmp(filter_width_calibration,'legacy')
    filter_width = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
        frex,filter_type);
    expected_filter_width = filter_width;
else
    filter_width = [];
    expected_filter_width = FREQNESS_ComputeFilterWidths_Mocap( ...
        frex,filter_type);
end
eigenvalue_negative_tolerance = 2e-4;

% Interaction-analysis settings.
landscape_frequency_range = [];       % [] uses the complete FREQ.frex grid
rqa_downsample_factor = 5;
rqa_lp_order = 4;
rqa_lp_cutoff_norm = .8;
rqa_duration = [.15 .85];
rqa_standardize = true;
rqa_threshold_method = 'max_fraction';
rqa_threshold = .1;
rqa_theiler_window = 0;
rqa_lmin = 2;
rqa_vmin = 2;
rqa_store_matrices = false;
rqa_figure = false;
rqa_animate = false;

% Group figures and statistical export.
ncomps2keep = 4;
pattern_components = 1:2;
pattern_frequencies = [.25 .5 1 2];
plot_pattern_bones = true;
write_xlsx = true;

% Folder annotations are audited but waived for these participants. All
% objective structure, rate, duration, marker, gap and coverage rules remain.
annotated_subjects = ["002" "022" "046"];
annotated_subject_notes = ["only 5 recordings" ...
    "very bad quality; disappeared hips" "only 28 recordings"];

save(fullfile(path_output,'EmpaticMirroring_RunConfiguration.mat'), ...
    'run_blocks','run_metric_prominence','overwrite','save_flag','vis_flag','srate_teacher', ...
    'srate_participant','srate','analysis_duration','teacher_offset', ...
    'participant_offset','short_gap_seconds', ...
    'maximum_reconstructed_gap_seconds', ...
    'minimum_complete_timepoint_fraction','marklabels','bones', ...
    'beat_frex','frex','meter','components','ncomps','regularisation', ...
    'filter_width_calibration','filter_type','filter_width', ...
    'expected_filter_width','prominence_component','global_metric_levels');


%% DATA PREPARATION - FRAME COUNTS, GAPS, AND RECORDING QC

% Recordings started automatically but were stopped manually. Inspect the
% third dimension of the QTM trajectory matrix before selecting the cohort.
files = dir(fullfile(path_data,'**','*.mat'));
assert(~isempty(files),'No MAT files were found below %s.',path_data);
file_paths = reshape(string(fullfile({files.folder},{files.name})),[],1);
[file_paths,sort_order] = sort(file_paths);
files = files(sort_order);
nfiles = numel(files);

File = file_paths;
RelativePath = erase(file_paths,string(path_data)+filesep);
Subject = strings(nfiles,1); Role = strings(nfiles,1);
FolderStatus = strings(nfiles,1); TrialIndex = nan(nfiles,1);
Instruction = strings(nfiles,1); Complexity = strings(nfiles,1);
Version = nan(nfiles,1); Movement = nan(nfiles,1); Note = strings(nfiles,1);
PairingKey = strings(nfiles,1); MatrixPath = strings(nfiles,1);
MatrixSize = strings(nfiles,1); MarkerCount = nan(nfiles,1);
MarkerStatus = strings(nfiles,1); RetainedMarkerCount = nan(nfiles,1);
MarkerPolicyStatus = strings(nfiles,1);
RetainedHasMissingCoordinates = false(nfiles,1);
RetainedMissingMarkerSamples = nan(nfiles,1);
RetainedBadTimepointCount = nan(nfiles,1);
InterpolatedMarkerSamples = nan(nfiles,1);
ReconstructedMarkerSamples = nan(nfiles,1);
FilledMarkerSamples = nan(nfiles,1);
CompleteTimepointFraction = nan(nfiles,1);
UnresolvedMarkerCount = nan(nfiles,1); UnresolvedMarkers = strings(nfiles,1);
LongestValidRunSeconds = nan(nfiles,1);
MeetsThreeCycleRunAtLowestFrequency = false(nfiles,1);
NumberFrames = nan(nfiles,1); DeclaredFrames = nan(nfiles,1);
SampleRate = nan(nfiles,1); DurationSeconds = nan(nfiles,1);
RequiredFrames = nan(nfiles,1); PreferredFrames = nan(nfiles,1);
HasMissingCoordinates = false(nfiles,1); MissingMarkerSamples = nan(nfiles,1);
BadTimepointCount = nan(nfiles,1); MissingGapCount = nan(nfiles,1);
LongestMissingGapFrames = nan(nfiles,1);
LongestMissingGapMilliseconds = nan(nfiles,1);
AffectedMarkerCount = nan(nfiles,1);
FullRecordingHasMissingCoordinates = false(nfiles,1);
FullRecordingMissingMarkerSamples = nan(nfiles,1);
FullRecordingMissingGapCount = nan(nfiles,1);
FullRecordingLongestMissingGapMilliseconds = nan(nfiles,1);
LoadStatus = strings(nfiles,1); NameStatus = strings(nfiles,1);
LengthStatus = strings(nfiles,1); OverallStatus = strings(nfiles,1);
ExcludeRecording = false(nfiles,1); ExclusionReasons = strings(nfiles,1);
ReadyForAlignment = false(nfiles,1); ErrorMessage = strings(nfiles,1);

fprintf('\nInspecting frame counts and gaps in %d MAT files...\n',nfiles)
for filei = 1:nfiles
    [mat_folder,stem] = fileparts(file_paths(filei));
    [subject_folder,~] = fileparts(mat_folder);
    [~,subject_folder_name] = fileparts(subject_folder);
    [~,mat_folder_name] = fileparts(mat_folder);
    subject_folder_name = string(subject_folder_name);
    mat_folder_name = string(mat_folder_name);

    if strcmpi(subject_folder_name,'Michalina')
        Role(filei) = "teacher"; Subject(filei) = "Michalina";
        if mat_folder_name == "data_Michalina_mat"
            FolderStatus(filei) = "ok";
        else
            FolderStatus(filei) = "invalid teacher data folder";
        end
    else
        subject_token = regexp(char(subject_folder_name),'^\d{3}', ...
            'match','once');
        if isempty(subject_token)
            Role(filei) = "unknown"; FolderStatus(filei) = "invalid subject folder";
        else
            Role(filei) = "participant"; Subject(filei) = string(subject_token);
            if subject_folder_name ~= Subject(filei)
                FolderStatus(filei) = "annotated subject folder";
            elseif mat_folder_name ~= string(str2double(Subject(filei)))+"_mat"
                FolderStatus(filei) = "invalid participant data folder";
            else
                FolderStatus(filei) = "ok";
            end
        end
    end

    token = regexpi(char(stem), ...
        ['^(?<trial>\d+)_(?<instruction>obs|mir)_' ...
         '(?<complexity>low|medium|high)_(?:v)?(?<version>\d+)_' ...
         '(?:mov)?(?<movement>[12])(?<note>.*)$'], ...
        'names','once');
    if isempty(token)
        NameStatus(filei) = "invalid filename";
    else
        TrialIndex(filei) = str2double(token.trial);
        Instruction(filei) = lower(string(token.instruction));
        Complexity(filei) = lower(string(token.complexity));
        Version(filei) = str2double(token.version);
        Movement(filei) = str2double(token.movement);
        Note(filei) = string(token.note);
        PairingKey(filei) = Complexity(filei)+"_v"+Version(filei)+ ...
            "_mov"+Movement(filei);
        if strlength(strtrim(Note(filei))) > 0
            NameStatus(filei) = "annotated filename";
        elseif TrialIndex(filei) < 1 || TrialIndex(filei) > 48
            NameStatus(filei) = "trial index outside 1-48";
        else
            NameStatus(filei) = "ok";
        end
    end

    try
        loaded = load(char(file_paths(filei)));
        top_names = fieldnames(loaded);
        assert(numel(top_names) == 1,'Expected one top-level QTM variable.');
        qtm = loaded.(top_names{1});
        trajectory = qtm.Trajectories.Labeled.Data;
        assert(isnumeric(trajectory) && ndims(trajectory) == 3 && ...
            size(trajectory,2) >= 3,'Invalid labeled trajectory matrix.');
        MatrixPath(filei) = string(top_names{1})+".Trajectories.Labeled.Data";
        MatrixSize(filei) = sprintf('%dx%dx%d',size(trajectory));
        MarkerCount(filei) = size(trajectory,1);
        NumberFrames(filei) = size(trajectory,3);
        SampleRate(filei) = double(qtm.FrameRate);
        if isfield(qtm,'Frames'); DeclaredFrames(filei) = double(qtm.Frames); end
        if MarkerCount(filei) == numel(marklabels)
            MarkerStatus(filei) = "ok";
        else
            MarkerStatus(filei) = "expected "+numel(marklabels)+ ...
                ", found "+MarkerCount(filei);
        end
        if ~isfinite(SampleRate(filei)) || SampleRate(filei) <= 0
            LoadStatus(filei) = "missing frame rate";
        elseif isfinite(DeclaredFrames(filei)) && ...
                DeclaredFrames(filei) ~= NumberFrames(filei)
            LoadStatus(filei) = "frame count mismatch";
        else
            LoadStatus(filei) = "ok";
            DurationSeconds(filei) = NumberFrames(filei)/SampleRate(filei);
        end

        raw_missing = squeeze(any(~isfinite(trajectory(:,1:3,:)),2));
        if isvector(raw_missing); raw_missing = reshape(raw_missing,MarkerCount(filei),[]); end
        FullRecordingHasMissingCoordinates(filei) = any(raw_missing,'all');
        FullRecordingMissingMarkerSamples(filei) = nnz(raw_missing);
        gap_count = 0; longest_gap = 0;
        for markeri = 1:size(raw_missing,1)
            edges = diff([false raw_missing(markeri,:) false]);
            starts = find(edges == 1); ends = find(edges == -1)-1;
            lengths = ends-starts+1; gap_count = gap_count+numel(lengths);
            if ~isempty(lengths); longest_gap = max(longest_gap,max(lengths)); end
        end
        FullRecordingMissingGapCount(filei) = gap_count;
        FullRecordingLongestMissingGapMilliseconds(filei) = ...
            1000*longest_gap/SampleRate(filei);

        if Role(filei) == "teacher"
            analysis_offset = teacher_offset;
        elseif Role(filei) == "participant"
            analysis_offset = participant_offset;
        else
            analysis_offset = NaN;
        end
        if LoadStatus(filei) == "ok" && isfinite(analysis_offset)
            RequiredFrames(filei) = round((analysis_offset+analysis_duration)*SampleRate(filei));
            PreferredFrames(filei) = round((analysis_offset+analysis_duration+filter_padding)*SampleRate(filei));
            if NumberFrames(filei) < RequiredFrames(filei)
                LengthStatus(filei) = "too short";
            elseif NumberFrames(filei) < PreferredFrames(filei)
                LengthStatus(filei) = "usable without preferred guard";
            else
                LengthStatus(filei) = "ok";
            end
        else
            LengthStatus(filei) = "not assessed";
        end

        if LoadStatus(filei) == "ok" && MarkerStatus(filei) == "ok" && ...
                NumberFrames(filei) >= RequiredFrames(filei)
            raw_labels = string(qtm.Trajectories.Labeled.Labels(:));
            normalized_labels = lower(regexprep(strtrim(raw_labels),'\s+',' '));
            normalized_labels(normalized_labels == "strainum") = "sternum";
            normalized_labels(normalized_labels == "r should") = "r shoulder";
            normalized_labels(normalized_labels == "l ankel") = "l ankle";
            normalized_labels(normalized_labels == "r ankel") = "r ankle";
            normalized_labels(normalized_labels == "f head") = "t head";
            [matched,marker_order] = ismember(lower(string(marklabels(:))),normalized_labels);
            assert(all(matched) && numel(unique(marker_order)) == numel(marker_order), ...
                'Required marker labels are missing.');
            coordinate_order = reshape(3*marker_order(:)'+(-2:0)',1,[]);
            raw_coordinates = reshape(permute(trajectory(:,1:3,:),[2 1 3]), ...
                3*MarkerCount(filei),NumberFrames(filei));
            raw_coordinates = raw_coordinates(coordinate_order,:);

            analysis_start = 1+round(analysis_offset*SampleRate(filei));
            analysis_end = analysis_start+round(analysis_duration*SampleRate(filei))-1;
            context_frames = ceil(maximum_reconstructed_gap_seconds*SampleRate(filei))+1;
            context_start = max(1,analysis_start-context_frames);
            context_end = min(NumberFrames(filei),analysis_end+context_frames);
            analysis_samples = (analysis_start:analysis_end)-context_start+1;
            [~,~,gap_info] = FREQNESS_InterpolateGaps_Mocap( ...
                raw_coordinates(:,context_start:context_end),SampleRate(filei), ...
                'maximum_interpolated_gap',short_gap_seconds, ...
                'maximum_reconstructed_gap',maximum_reconstructed_gap_seconds, ...
                'required_samples',analysis_samples,'boundary_method',boundary_method);

            original_missing = gap_info.bad_marker_sample_mask(:,analysis_samples);
            interpolated_mask = gap_info.interpolated_marker_sample_mask(:,analysis_samples);
            reconstructed_mask = gap_info.reconstructed_marker_sample_mask(:,analysis_samples);
            unresolved_mask = gap_info.unresolved_marker_sample_mask(:,analysis_samples);
            RetainedMarkerCount(filei) = numel(marklabels);
            RetainedHasMissingCoordinates(filei) = any(original_missing,'all');
            RetainedMissingMarkerSamples(filei) = nnz(original_missing);
            RetainedBadTimepointCount(filei) = nnz(any(original_missing,1));
            InterpolatedMarkerSamples(filei) = nnz(interpolated_mask);
            ReconstructedMarkerSamples(filei) = nnz(reconstructed_mask);
            FilledMarkerSamples(filei) = nnz(interpolated_mask | reconstructed_mask);
            CompleteTimepointFraction(filei) = mean(~any(original_missing,1));
            UnresolvedMarkerCount(filei) = nnz(any(unresolved_mask,2));
            UnresolvedMarkers(filei) = strjoin(string(marklabels(any(unresolved_mask,2))),', ');
            valid_time = ~any(original_missing,1);
            edges = diff([false valid_time false]);
            run_starts = find(edges == 1); run_ends = find(edges == -1)-1;
            if isempty(run_starts); longest_valid_run = 0;
            else; longest_valid_run = max(run_ends-run_starts+1); end
            LongestValidRunSeconds(filei) = longest_valid_run/SampleRate(filei);
            MeetsThreeCycleRunAtLowestFrequency(filei) = ...
                LongestValidRunSeconds(filei) >= 3/min(frex(:));
            if any(unresolved_mask,'all')
                MarkerPolicyStatus(filei) = "gap beyond reconstruction limit";
            elseif CompleteTimepointFraction(filei) < minimum_complete_timepoint_fraction
                MarkerPolicyStatus(filei) = "insufficient all-marker coverage";
            else
                MarkerPolicyStatus(filei) = "ok";
            end

            analysis_missing = squeeze(any(~isfinite( ...
                trajectory(:,1:3,analysis_start:analysis_end)),2));
            if isvector(analysis_missing); analysis_missing = reshape(analysis_missing,MarkerCount(filei),[]); end
            HasMissingCoordinates(filei) = any(analysis_missing,'all');
            MissingMarkerSamples(filei) = nnz(analysis_missing);
            BadTimepointCount(filei) = nnz(any(analysis_missing,1));
            AffectedMarkerCount(filei) = nnz(any(analysis_missing,2));
            gap_count = 0; longest_gap = 0;
            for markeri = 1:size(analysis_missing,1)
                edges = diff([false analysis_missing(markeri,:) false]);
                starts = find(edges == 1); ends = find(edges == -1)-1;
                lengths = ends-starts+1; gap_count = gap_count+numel(lengths);
                if ~isempty(lengths); longest_gap = max(longest_gap,max(lengths)); end
            end
            MissingGapCount(filei) = gap_count;
            LongestMissingGapFrames(filei) = longest_gap;
            LongestMissingGapMilliseconds(filei) = 1000*longest_gap/SampleRate(filei);
        end
    catch exception
        if LoadStatus(filei) == "ok" && strlength(MarkerPolicyStatus(filei)) == 0
            MarkerPolicyStatus(filei) = "policy error: "+string(exception.message);
        elseif strlength(LoadStatus(filei)) == 0
            LoadStatus(filei) = "load error";
        end
        ErrorMessage(filei) = string(exception.message);
    end

    reasons = strings(0,1);
    if LoadStatus(filei) ~= "ok"; reasons(end+1) = "load/structure: "+LoadStatus(filei); end
    if FolderStatus(filei) ~= "ok"; reasons(end+1) = "folder: "+FolderStatus(filei); end
    if NameStatus(filei) ~= "ok"
        if NameStatus(filei) == "annotated filename"
            reasons(end+1) = "filename annotation: "+strtrim(Note(filei));
        else
            reasons(end+1) = "filename: "+NameStatus(filei);
        end
    end
    if MarkerStatus(filei) ~= "ok"; reasons(end+1) = "marker layout: "+MarkerStatus(filei); end
    if strlength(MarkerPolicyStatus(filei)) > 0 && MarkerPolicyStatus(filei) ~= "ok"
        reasons(end+1) = "marker policy: "+MarkerPolicyStatus(filei);
    end
    if Role(filei) == "participant"; expected_rate = srate_participant;
    elseif Role(filei) == "teacher"; expected_rate = srate_teacher;
    else; expected_rate = NaN; reasons(end+1) = "role: unrecognized data location"; end
    if LoadStatus(filei) == "ok" && isfinite(expected_rate) && ...
            abs(SampleRate(filei)-expected_rate) > 1e-9
        reasons(end+1) = "sample rate: expected "+expected_rate+" Hz, found "+SampleRate(filei)+" Hz";
    end
    if LengthStatus(filei) == "too short"; reasons(end+1) = "length: too short for configured 33 s window"; end
    if isfinite(RetainedBadTimepointCount(filei)) && ...
            RetainedBadTimepointCount(filei) >= RequiredFrames(filei)-1
        reasons(end+1) = "missing data: fewer than two valid covariance samples";
    end
    ExclusionReasons(filei) = strjoin(unique(reasons,'stable'),'; ');
    ExcludeRecording(filei) = strlength(ExclusionReasons(filei)) > 0;
    ReadyForAlignment(filei) = ~ExcludeRecording(filei);
    if ExcludeRecording(filei); OverallStatus(filei) = ExclusionReasons(filei);
    elseif RetainedHasMissingCoordinates(filei); OverallStatus(filei) = "usable after marker reconstruction";
    else; OverallStatus(filei) = LengthStatus(filei); end
    if mod(filei,100) == 0 || filei == nfiles
        fprintf('  inspected %d/%d files\n',filei,nfiles)
    end
end

frameQC = table(File,RelativePath,Subject,Role,FolderStatus,TrialIndex, ...
    Instruction,Complexity,Version,Movement,Note,PairingKey,MatrixPath, ...
    MatrixSize,MarkerCount,MarkerStatus,RetainedMarkerCount, ...
    MarkerPolicyStatus,RetainedHasMissingCoordinates, ...
    RetainedMissingMarkerSamples,RetainedBadTimepointCount, ...
    InterpolatedMarkerSamples,ReconstructedMarkerSamples,FilledMarkerSamples, ...
    CompleteTimepointFraction,UnresolvedMarkerCount,UnresolvedMarkers, ...
    LongestValidRunSeconds,MeetsThreeCycleRunAtLowestFrequency,NumberFrames, ...
    DeclaredFrames,SampleRate,DurationSeconds,RequiredFrames,PreferredFrames, ...
    HasMissingCoordinates,MissingMarkerSamples,BadTimepointCount,MissingGapCount, ...
    LongestMissingGapFrames,LongestMissingGapMilliseconds,AffectedMarkerCount, ...
    FullRecordingHasMissingCoordinates,FullRecordingMissingMarkerSamples, ...
    FullRecordingMissingGapCount,FullRecordingLongestMissingGapMilliseconds, ...
    LoadStatus,NameStatus,LengthStatus,OverallStatus,ExcludeRecording, ...
    ExclusionReasons,ReadyForAlignment,ErrorMessage);
writetable(frameQC,fullfile(path_qc,'frame_count_qc.csv'))

% Recover objectively valid recordings from the three annotated folders.
analysisQC = frameQC;
candidate_rows = analysisQC.Role == "participant" & ismember(analysisQC.Subject,annotated_subjects);
objective_ok = candidate_rows & analysisQC.FolderStatus == "annotated subject folder" & ...
    analysisQC.LoadStatus == "ok" & analysisQC.NameStatus == "ok" & ...
    analysisQC.MarkerStatus == "ok" & analysisQC.MarkerPolicyStatus == "ok" & ...
    abs(analysisQC.SampleRate-srate_participant) <= 1e-9 & ...
    ismember(analysisQC.LengthStatus,["ok" "usable without preferred guard"]) & ...
    analysisQC.RetainedBadTimepointCount < analysisQC.RequiredFrames-1;
recoveryAudit = analysisQC(candidate_rows,:);
recoveryAudit.SubjectAnnotation = strings(height(recoveryAudit),1);
for subjecti = 1:numel(annotated_subjects)
    recoveryAudit.SubjectAnnotation(recoveryAudit.Subject == annotated_subjects(subjecti)) = annotated_subject_notes(subjecti);
end
recoveryAudit.RecoverForSensitivity = ismember(recoveryAudit.File,analysisQC.File(objective_ok));
recoveryAudit.SensitivityDecision = repmat("remain excluded",height(recoveryAudit),1);
recoveryAudit.SensitivityDecision(recoveryAudit.RecoverForSensitivity) = "recover";
writetable(recoveryAudit,fullfile(path_qc,'recovery_recording_audit.csv'))
analysisQC.FolderStatus(objective_ok) = "ok";
analysisQC.OverallStatus(objective_ok) = "included after annotation audit";
analysisQC.ExcludeRecording(objective_ok) = false;
analysisQC.ExclusionReasons(objective_ok) = "";
analysisQC.ReadyForAlignment(objective_ok) = true;
writetable(analysisQC,fullfile(path_qc,'all_possible_participants_qc.csv'))

% Frame-count histogram required before analysis.
frame_figure = figure('Color','w','Visible',figure_visibility);
layout = tiledlayout(frame_figure,2,2,'TileSpacing','compact','Padding','compact');
title(layout,'Raw recording frame-count distributions')
valid_frames = isfinite(analysisQC.NumberFrames);
nexttile(layout,[1 2]); histogram(analysisQC.NumberFrames(valid_frames),max(10,min(80,ceil(sqrt(nnz(valid_frames))))));
xlabel('Number of frames'); ylabel('Number of files'); title('All MAT files'); grid on
nexttile(layout); participant_frames = valid_frames & analysisQC.Role == "participant";
histogram(analysisQC.NumberFrames(participant_frames),'BinWidth',srate_participant/4)
xline(round(analysis_duration*srate_participant),'r--','required'); xlabel('Number of frames'); ylabel('Number of files'); title('Participants (120 Hz)'); grid on
nexttile(layout); teacher_frames = valid_frames & analysisQC.Role == "teacher";
histogram(analysisQC.NumberFrames(teacher_frames),'BinWidth',srate_teacher/2)
xline(round(analysis_duration*srate_teacher),'r--','required'); xlabel('Number of frames'); ylabel('Number of files'); title('Teacher (300 Hz)'); grid on
exportgraphics(frame_figure,fullfile(path_qc,'frame_count_histograms.png'),'Resolution',200)
savefig(frame_figure,fullfile(path_qc,'frame_count_histograms.fig'))

% Auditable recording- and participant-level exclusion reports.
recordingExclusions = analysisQC(analysisQC.ExcludeRecording,:);
modelExclusions = recordingExclusions(recordingExclusions.Role == "teacher",:);
participantData = analysisQC(analysisQC.Role == "participant",:);
subjects = sort(unique(participantData.Subject)); Subject = subjects;
SourceFolder = strings(numel(subjects),1); ExpectedTrialIndexCount = repmat(48,numel(subjects),1);
ObservedRecordingCount = zeros(numel(subjects),1); UniqueTrialIndexCount = zeros(numel(subjects),1);
MissingTrialIndices = strings(numel(subjects),1); DuplicateTrialIndices = strings(numel(subjects),1);
AnnotatedRecordingCount = zeros(numel(subjects),1); GapRecordingCount = zeros(numel(subjects),1);
MarkerPolicyExcludedRecordingCount = zeros(numel(subjects),1); TooShortRecordingCount = zeros(numel(subjects),1);
UnexpectedRateRecordingCount = zeros(numel(subjects),1); LoadOrStructureErrorCount = zeros(numel(subjects),1);
ExcludedRecordingCount = zeros(numel(subjects),1); EligibleRecordingCount = zeros(numel(subjects),1);
ExcludeParticipant = false(numel(subjects),1); ParticipantExclusionReason = strings(numel(subjects),1);
for subjecti = 1:numel(subjects)
    subject_qc = participantData(participantData.Subject == subjects(subjecti),:);
    path_parts = split(subject_qc.RelativePath(1),filesep); SourceFolder(subjecti) = path_parts(1);
    ObservedRecordingCount(subjecti) = height(subject_qc);
    trial_indices = subject_qc.TrialIndex(isfinite(subject_qc.TrialIndex)); unique_indices = unique(trial_indices);
    UniqueTrialIndexCount(subjecti) = numel(unique_indices);
    MissingTrialIndices(subjecti) = strjoin(string(setdiff((1:48)',unique_indices))',',');
    [unique_trials,~,trial_group] = unique(trial_indices); counts = accumarray(trial_group,1);
    DuplicateTrialIndices(subjecti) = strjoin(string(unique_trials(counts > 1))',',');
    AnnotatedRecordingCount(subjecti) = nnz(subject_qc.NameStatus == "annotated filename");
    GapRecordingCount(subjecti) = nnz(subject_qc.RetainedHasMissingCoordinates);
    MarkerPolicyExcludedRecordingCount(subjecti) = nnz(subject_qc.MarkerPolicyStatus ~= "ok" & strlength(subject_qc.MarkerPolicyStatus) > 0);
    TooShortRecordingCount(subjecti) = nnz(subject_qc.LengthStatus == "too short");
    UnexpectedRateRecordingCount(subjecti) = nnz(contains(subject_qc.ExclusionReasons,"sample rate:"));
    LoadOrStructureErrorCount(subjecti) = nnz(subject_qc.LoadStatus ~= "ok");
    ExcludedRecordingCount(subjecti) = nnz(subject_qc.ExcludeRecording);
    EligibleRecordingCount(subjecti) = nnz(subject_qc.ReadyForAlignment);
    ExcludeParticipant(subjecti) = EligibleRecordingCount(subjecti) == 0;
    if ExcludeParticipant(subjecti); ParticipantExclusionReason(subjecti) = "no recording survives QC"; end
end
participantSummary = table(Subject,SourceFolder,ExpectedTrialIndexCount,ObservedRecordingCount, ...
    UniqueTrialIndexCount,MissingTrialIndices,DuplicateTrialIndices,AnnotatedRecordingCount, ...
    GapRecordingCount,MarkerPolicyExcludedRecordingCount,TooShortRecordingCount, ...
    UnexpectedRateRecordingCount,LoadOrStructureErrorCount,ExcludedRecordingCount, ...
    EligibleRecordingCount,ExcludeParticipant,ParticipantExclusionReason);
participantExclusions = participantSummary(participantSummary.ExcludeParticipant,:);
writetable(recordingExclusions,fullfile(path_qc,'recording_exclusions.csv'))
writetable(modelExclusions,fullfile(path_qc,'model_exclusions.csv'))
writetable(participantSummary,fullfile(path_qc,'participant_qc_summary.csv'))
writetable(participantExclusions,fullfile(path_qc,'participant_exclusions.csv'))
fprintf('QC retained %d recordings; %d were excluded.\n',nnz(analysisQC.ReadyForAlignment),height(recordingExclusions))
fprintf('Recovered %d objectively valid recordings from annotated folders.\n',nnz(objective_ok))


%% DATA PREPARATION - ARTIFICIAL DYADS

% Pairing ignores Instruction because the model stimulus is identical for
% observation and imitation. Complexity labels music overlaid on the one
% physical model performance; Complexity, Version and Movement select it.
participant_rows = analysisQC.Role == "participant" & analysisQC.FolderStatus == "ok" & analysisQC.NameStatus == "ok";
teacher_rows = analysisQC.Role == "teacher" & analysisQC.FolderStatus == "ok" & analysisQC.NameStatus == "ok";
participants = analysisQC(participant_rows,:); teachers = analysisQC(teacher_rows,:); nrows = height(participants);
ParticipantFile = participants.File; TeacherFile = strings(nrows,1); Subject = participants.Subject;
TrialIndex = participants.TrialIndex; Instruction = participants.Instruction; Complexity = participants.Complexity;
Version = participants.Version; Movement = participants.Movement; PairingKey = participants.PairingKey;
ParticipantFrames = participants.NumberFrames; TeacherFrames = nan(nrows,1);
ParticipantQCStatus = participants.OverallStatus; TeacherQCStatus = strings(nrows,1);
PairingStatus = strings(nrows,1); ReadyForAlignment = false(nrows,1);
for rowi = 1:nrows
    matches = find(teachers.PairingKey == PairingKey(rowi));
    if isempty(matches); PairingStatus(rowi) = "teacher clip missing";
    elseif numel(matches) > 1; PairingStatus(rowi) = "teacher clip ambiguous";
    else
        teacheri = matches(1); TeacherFile(rowi) = teachers.File(teacheri);
        TeacherFrames(rowi) = teachers.NumberFrames(teacheri); TeacherQCStatus(rowi) = teachers.OverallStatus(teacheri);
        PairingStatus(rowi) = "matched"; ReadyForAlignment(rowi) = participants.ReadyForAlignment(rowi) && teachers.ReadyForAlignment(teacheri);
    end
end
dyadManifest = table(ParticipantFile,TeacherFile,Subject,TrialIndex,Instruction, ...
    Complexity,Version,Movement,PairingKey,ParticipantFrames,TeacherFrames, ...
    ParticipantQCStatus,TeacherQCStatus,PairingStatus,ReadyForAlignment);

% Prepare every teacher clip once, including anti-aliased 300->120 Hz
% resampling and post-resampling bad-sample bookkeeping.
teacher_files = unique(dyadManifest.TeacherFile(dyadManifest.PairingStatus == "matched" & dyadManifest.ReadyForAlignment),'stable');
teacher_cache = containers.Map('KeyType','char','ValueType','any');
fprintf('\nPreparing %d model recordings once for reuse...\n',numel(teacher_files))
for teacheri = 1:numel(teacher_files)
    teacher_file = teacher_files(teacheri); loaded = load(char(teacher_file)); names = fieldnames(loaded); qtm = loaded.(names{1});
    trajectory = qtm.Trajectories.Labeled.Data; raw_labels = string(qtm.Trajectories.Labeled.Labels(:));
    normalized_labels = lower(regexprep(strtrim(raw_labels),'\s+',' '));
    normalized_labels(normalized_labels == "strainum") = "sternum"; normalized_labels(normalized_labels == "r should") = "r shoulder";
    normalized_labels(normalized_labels == "l ankel") = "l ankle"; normalized_labels(normalized_labels == "r ankel") = "r ankle";
    normalized_labels(normalized_labels == "f head") = "t head";
    [matched,marker_order] = ismember(lower(string(marklabels(:))),normalized_labels); assert(all(matched),'Teacher lacks a required marker.');
    coordinates = reshape(permute(trajectory(:,1:3,:),[2 1 3]),3*size(trajectory,1),size(trajectory,3));
    coordinate_order = reshape(3*marker_order(:)'+(-2:0)',1,[]); coordinates = coordinates(coordinate_order,:);
    source_start = 1+round(teacher_offset*srate_teacher); source_end = source_start+round(analysis_duration*srate_teacher)-1;
    context_frames = ceil(maximum_reconstructed_gap_seconds*srate_teacher)+1;
    context_start = max(1,source_start-context_frames); context_end = min(size(coordinates,2),source_end+context_frames);
    analysis_samples = (source_start:source_end)-context_start+1;
    [filled,~,gap_info] = FREQNESS_InterpolateGaps_Mocap(coordinates(:,context_start:context_end),srate_teacher, ...
        'maximum_interpolated_gap',short_gap_seconds,'maximum_reconstructed_gap',maximum_reconstructed_gap_seconds, ...
        'required_samples',analysis_samples,'boundary_method',boundary_method);
    filled = filled(:,analysis_samples); teacher_marker_bad = gap_info.bad_marker_sample_mask(:,analysis_samples);
    teacher_interpolated = gap_info.interpolated_marker_sample_mask(:,analysis_samples);
    teacher_reconstructed = gap_info.reconstructed_marker_sample_mask(:,analysis_samples);
    teacher_unresolved = gap_info.unresolved_marker_sample_mask(:,analysis_samples);
    assert(~any(teacher_unresolved,'all'),'Unresolved teacher marker gap.');
    assert(mean(~any(teacher_marker_bad,1)) >= minimum_complete_timepoint_fraction,'Insufficient teacher coverage.');
    n_pad_in = round(filter_padding*srate_teacher); left_reflection = filled(:,n_pad_in+1:-1:2); right_reflection = filled(:,end-1:-1:end-n_pad_in);
    padded = [left_reflection filled right_reflection];
    padded_bad = [teacher_marker_bad(:,n_pad_in+1:-1:2) teacher_marker_bad teacher_marker_bad(:,end-1:-1:end-n_pad_in)];
    [p,q] = rat(srate/srate_teacher,1e-12); resampled = resample(padded',p,q)';
    input_time = (0:size(padded_bad,2)-1)/srate_teacher; output_time = (0:size(resampled,2)-1)/srate;
    resampled_bad = interp1(input_time,double(padded_bad'),output_time,'nearest',0)' > .5;
    n_pad_out = round(filter_padding*srate); nsamples = round(analysis_duration*srate);
    teacher_data = resampled(:,n_pad_out+(1:nsamples)); teacher_marker_bad = resampled_bad(:,n_pad_out+(1:nsamples));
    teacher_bad = any(teacher_marker_bad,1); teacher_fill_method = zeros(size(teacher_marker_bad),'uint8');
    maximum_short_gap = floor(short_gap_seconds*srate+1e-9);
    for markeri = 1:size(teacher_marker_bad,1)
        edges = diff([false teacher_marker_bad(markeri,:) false]); starts = find(edges == 1); ends = find(edges == -1)-1;
        for gapi = 1:numel(starts)
            indices = starts(gapi):ends(gapi); teacher_fill_method(markeri,indices) = uint8(1+(numel(indices)>maximum_short_gap));
        end
    end
    teacher_prepared = struct('data',teacher_data,'badMask',teacher_bad,'markerBadMask',teacher_marker_bad, ...
        'gapFillMethodMask',teacher_fill_method,'file',teacher_file,'interpolatedCount',nnz(teacher_interpolated), ...
        'reconstructedCount',nnz(teacher_reconstructed));
    teacher_cache(char(teacher_file)) = teacher_prepared;
    [~,teacher_stem] = fileparts(teacher_file); model_file = fullfile(path_models,char(string(teacher_stem)+"_processed.mat"));
    modelData = single(teacher_data); bad_segments = double(find(teacher_bad)); bad_sample_mask = teacher_bad;
    bad_marker_sample_mask = teacher_marker_bad; gap_fill_method_mask = teacher_fill_method;
    marker_policy = struct('version',marker_policy_version,'labels',{marklabels},'shortGapInterpolationSeconds',short_gap_seconds, ...
        'maximumReconstructedGapSeconds',maximum_reconstructed_gap_seconds);
    model_info = struct('sourceFile',teacher_file,'processingPolicy',['Imported and downsampled once from 300 Hz ' ...
        'to 120 Hz, then reused across matching artificial dyads.']);
    xyz_marklabels = strings(1,3*numel(marklabels));
    for markeri = 1:numel(marklabels)
        xyz_marklabels(3*(markeri-1)+(1:3)) = ["X_"+marklabels{markeri} "Y_"+marklabels{markeri} "Z_"+marklabels{markeri}];
    end
    if save_flag && (~isfile(model_file) || overwrite)
        save(model_file,'modelData','srate','marklabels','xyz_marklabels','bad_segments','bad_sample_mask', ...
            'bad_marker_sample_mask','gap_fill_method_mask','marker_policy','model_info','-v7.3')
    end
end

eligible_rows = find(dyadManifest.PairingStatus == "matched" & dyadManifest.ReadyForAlignment);
DyadFile = strings(height(dyadManifest),1); DyadStatus = repmat("not eligible",height(dyadManifest),1);
ModelBadSampleCount = nan(height(dyadManifest),1); ParticipantBadSampleCount = nan(height(dyadManifest),1);
SharedBadSampleCount = nan(height(dyadManifest),1); SharedBadSamplePercent = nan(height(dyadManifest),1);
GoodSampleCount = nan(height(dyadManifest),1); DyadErrorMessage = strings(height(dyadManifest),1);
fprintf('Creating %d artificial dyads...\n',numel(eligible_rows))
for analysisi = 1:numel(eligible_rows)
    rowi = eligible_rows(analysisi); subject = compose('%03d',str2double(dyadManifest.Subject(rowi)));
    participant_folder = fullfile(path_participants,char(subject)); if ~isfolder(participant_folder); mkdir(participant_folder); end
    dyad_stem = sprintf('S%s_T%02d_%s_%s_v%d_mov%d',char(subject),dyadManifest.TrialIndex(rowi), ...
        dyadManifest.Instruction(rowi),dyadManifest.Complexity(rowi),dyadManifest.Version(rowi),dyadManifest.Movement(rowi));
    dyad_file = fullfile(participant_folder,[dyad_stem '.mat']); DyadFile(rowi) = string(dyad_file);
    try
        if isfile(dyad_file) && ~overwrite
            saved = load(dyad_file,'markData','bad_segments','bad_segments_by_participant'); DyadStatus(rowi) = "existing";
        else
            participant_file = dyadManifest.ParticipantFile(rowi); loaded = load(char(participant_file)); names = fieldnames(loaded); qtm = loaded.(names{1});
            trajectory = qtm.Trajectories.Labeled.Data; raw_labels = string(qtm.Trajectories.Labeled.Labels(:));
            normalized_labels = lower(regexprep(strtrim(raw_labels),'\s+',' '));
            normalized_labels(normalized_labels == "strainum") = "sternum"; normalized_labels(normalized_labels == "r should") = "r shoulder";
            normalized_labels(normalized_labels == "l ankel") = "l ankle"; normalized_labels(normalized_labels == "r ankel") = "r ankle";
            normalized_labels(normalized_labels == "f head") = "t head";
            [matched,marker_order] = ismember(lower(string(marklabels(:))),normalized_labels); assert(all(matched),'Participant lacks a required marker.');
            coordinates = reshape(permute(trajectory(:,1:3,:),[2 1 3]),3*size(trajectory,1),size(trajectory,3));
            coordinate_order = reshape(3*marker_order(:)'+(-2:0)',1,[]); coordinates = coordinates(coordinate_order,:);
            source_start = 1+round(participant_offset*srate_participant); source_end = source_start+round(analysis_duration*srate_participant)-1;
            context_frames = ceil(maximum_reconstructed_gap_seconds*srate_participant)+1;
            context_start = max(1,source_start-context_frames); context_end = min(size(coordinates,2),source_end+context_frames);
            analysis_samples = (source_start:source_end)-context_start+1;
            [filled,~,gap_info] = FREQNESS_InterpolateGaps_Mocap(coordinates(:,context_start:context_end),srate_participant, ...
                'maximum_interpolated_gap',short_gap_seconds,'maximum_reconstructed_gap',maximum_reconstructed_gap_seconds, ...
                'required_samples',analysis_samples,'boundary_method',boundary_method);
            participant_data = filled(:,analysis_samples); participant_marker_bad = gap_info.bad_marker_sample_mask(:,analysis_samples);
            participant_unresolved = gap_info.unresolved_marker_sample_mask(:,analysis_samples);
            assert(~any(participant_unresolved,'all'),'Unresolved participant marker gap.');
            assert(mean(~any(participant_marker_bad,1)) >= minimum_complete_timepoint_fraction,'Insufficient participant coverage.');
            participant_bad = any(participant_marker_bad,1); participant_fill_method = zeros(size(participant_marker_bad),'uint8');
            maximum_short_gap = floor(short_gap_seconds*srate+1e-9);
            for markeri = 1:size(participant_marker_bad,1)
                edges = diff([false participant_marker_bad(markeri,:) false]); starts = find(edges == 1); ends = find(edges == -1)-1;
                for gapi = 1:numel(starts)
                    indices = starts(gapi):ends(gapi); participant_fill_method(markeri,indices) = uint8(1+(numel(indices)>maximum_short_gap));
                end
            end
            prepared_teacher = teacher_cache(char(dyadManifest.TeacherFile(rowi)));
            markData = single(cat(3,prepared_teacher.data,participant_data));
            bad_segments_by_participant = {double(find(prepared_teacher.badMask)),double(find(participant_bad))};
            bad_sample_mask = [prepared_teacher.badMask(:) participant_bad(:)]; bad_segments = double(find(any(bad_sample_mask,2))');
            bad_marker_sample_mask = cat(3,prepared_teacher.markerBadMask,participant_marker_bad);
            gap_fill_method_mask = cat(3,prepared_teacher.gapFillMethodMask,participant_fill_method);
            good_segments = setdiff(1:nsamples,bad_segments); marker_reference = markData(:,good_segments(1),:);
            nsubs = 2; sublabels = {'_MODEL','_PARTICIPANT'}; xyz_marklabels = cellstr(xyz_marklabels);
            marker_policy = struct('version',marker_policy_version,'labels',{marklabels},'shortGapInterpolationSeconds',short_gap_seconds, ...
                'maximumReconstructedGapSeconds',maximum_reconstructed_gap_seconds,'minimumCompleteTimepointFraction',minimum_complete_timepoint_fraction);
            dyad_info = struct('subject',subject,'trialIndex',dyadManifest.TrialIndex(rowi),'instruction',dyadManifest.Instruction(rowi), ...
                'complexity',dyadManifest.Complexity(rowi),'version',dyadManifest.Version(rowi),'movement',dyadManifest.Movement(rowi), ...
                'pairingKey',dyadManifest.PairingKey(rowi),'participantOrder',["model" "participant"], ...
                'teacherFile',dyadManifest.TeacherFile(rowi),'participantFile',participant_file,'markerPolicyVersion',marker_policy_version, ...
                'badSegmentsPolicy',['Reconstructed values support filtering only; the synchronized union is excluded downstream.']);
            save(dyad_file,'markData','srate','marklabels','xyz_marklabels','nsubs','sublabels','bad_segments', ...
                'bad_segments_by_participant','bad_sample_mask','bad_marker_sample_mask','gap_fill_method_mask', ...
                'marker_policy','marker_reference','dyad_info','-v7.3')
            saved = struct('markData',markData,'bad_segments',bad_segments,'bad_segments_by_participant',{bad_segments_by_participant});
            DyadStatus(rowi) = "created";
        end
        ModelBadSampleCount(rowi) = numel(saved.bad_segments_by_participant{1});
        ParticipantBadSampleCount(rowi) = numel(saved.bad_segments_by_participant{2});
        SharedBadSampleCount(rowi) = numel(saved.bad_segments); SharedBadSamplePercent(rowi) = 100*SharedBadSampleCount(rowi)/size(saved.markData,2);
        GoodSampleCount(rowi) = size(saved.markData,2)-SharedBadSampleCount(rowi);
    catch exception
        DyadStatus(rowi) = "error"; DyadErrorMessage(rowi) = string(exception.message); warning('Dyad row %d failed: %s',rowi,exception.message)
    end
    if mod(analysisi,100) == 0 || analysisi == numel(eligible_rows); fprintf('  processed %d/%d artificial dyads\n',analysisi,numel(eligible_rows)); end
end
dyadManifest.DyadFile = DyadFile; dyadManifest.DyadStatus = DyadStatus;
dyadManifest.ModelBadSampleCount = ModelBadSampleCount; dyadManifest.ParticipantBadSampleCount = ParticipantBadSampleCount;
dyadManifest.SharedBadSampleCount = SharedBadSampleCount; dyadManifest.SharedBadSamplePercent = SharedBadSamplePercent;
dyadManifest.GoodSampleCount = GoodSampleCount; dyadManifest.DyadErrorMessage = DyadErrorMessage;
writetable(dyadManifest,fullfile(path_qc,'artificial_dyad_manifest.csv'))
assert(~any(DyadStatus == "error"),'Artificial-dyad generation produced errors.')


%% BLOCK 1 - FREQ-NESS CORE NETWORK ESTIMATION

% Guard the covariance-exclusion contract before running the estimator.
estimator_file = fullfile(path_toolbox,'FREQNESS_Functions', ...
    'FREQNESS_NetworkEstimation_Mocap.m');
estimator_source = fileread(estimator_file);
SupportsBadSegmentsOption = contains(estimator_source,"'bad_segments'");
IndexesBroadbandCovariance = contains(estimator_source,"cov(broadData(:,idx2cov)')");
IndexesNarrowbandCovariance = contains(estimator_source,"cov(narrowData(:,idx2cov)')");
ReadyForNetworkEstimation = SupportsBadSegmentsOption && ...
    IndexesBroadbandCovariance && IndexesNarrowbandCovariance;
Status = "compatible";
if ~ReadyForNetworkEstimation
    Status = "BLOCKED: incomplete bad_segments support";
end
networkEstimatorContract = table(string(estimator_file), ...
    "bad_segments",SupportsBadSegmentsOption,IndexesBroadbandCovariance, ...
    IndexesNarrowbandCovariance,ReadyForNetworkEstimation,Status, ...
    'VariableNames',{'FunctionFile','RequiredOption', ...
    'SupportsBadSegmentsOption','IndexesBroadbandCovariance', ...
    'IndexesNarrowbandCovariance','ReadyForNetworkEstimation','Status'});
writetable(networkEstimatorContract,fullfile(path_qc, ...
    'network_estimator_contract.csv'))
assert(ReadyForNetworkEstimation, ...
    'MoCap estimator lacks complete bad_segments support.')

CoreFile = strings(height(dyadManifest),1);
CoreStatus = repmat("not eligible",height(dyadManifest),1);
CoreErrorMessage = strings(height(dyadManifest),1);
eligible_rows = find(ismember(dyadManifest.DyadStatus,["created" "existing"]) & ...
    strlength(dyadManifest.DyadFile) > 0 & isfile(dyadManifest.DyadFile));
if isfinite(max_dyads); eligible_rows = eligible_rows(1:min(end,max_dyads)); end
fprintf('\nBLOCK 1: running core FREQ-NESS for %d artificial dyads...\n',numel(eligible_rows))
for analysisi = 1:numel(eligible_rows)
    rowi = eligible_rows(analysisi);
    input_file = dyadManifest.DyadFile(rowi);
    [input_folder,input_stem] = fileparts(input_file);
    output_file = string(fullfile(input_folder,"FREQNESS_CORE_"+input_stem+".mat"));
    CoreFile(rowi) = output_file;
    try
        if isfile(output_file) && ~overwrite
            saved = load(output_file,'FREQ');
            expected_frex = size(frex,1);
            assert(isfield(saved,'FREQ') && size(saved.FREQ.evals,1) == 3*numel(marklabels) && ...
                size(saved.FREQ.evals,2) == expected_frex && size(saved.FREQ.evecs,2) == ncomps && ...
                isequal(saved.FREQ.frex,frex) && isequal(saved.FREQ.frex_norm,saved.FREQ.frex./beat_frex) && ...
                isfield(saved.FREQ,'fwhm') && isequal(saved.FREQ.fwhm,expected_filter_width) && ...
                isfield(saved.FREQ,'filter_width_calibration') && ...
                strcmpi(saved.FREQ.filter_width_calibration,filter_width_calibration) && ...
                isfield(saved.FREQ,'filter_type') && ...
                strcmpi(saved.FREQ.filter_type,filter_type) && ...
                isfield(saved.FREQ,'bad_segments_by_participant'), ...
                'Existing core output is incompatible.');
            CoreStatus(rowi) = "existing";
        else
            saved_dyad = load(input_file,'markData','srate','bad_segments', ...
                'bad_segments_by_participant','marker_reference','marker_policy','dyad_info');
            assert(size(saved_dyad.markData,2) == round(analysis_duration*saved_dyad.srate) && ...
                size(saved_dyad.markData,3) == 2 && any(isfinite(saved_dyad.markData),'all') && ...
                ~any(~isfinite(saved_dyad.markData),'all'),'Invalid artificial-dyad input.');
            markData = saved_dyad.markData;
            FREQ = FREQNESS_NetworkEstimation_Mocap(markData,frex,saved_dyad.srate, ...
                'duration',analysis_duration,'fwidth',filter_width, ...
                'filter',filter_type,'regularisation',regularisation, ...
                'ncomps',ncomps,'bad_segments',saved_dyad.bad_segments);
            FREQ.bad_segments_by_participant = saved_dyad.bad_segments_by_participant;
            FREQ.gap_info.bad_segments_by_participant = saved_dyad.bad_segments_by_participant;
            FREQ.frex_norm = FREQ.frex./beat_frex;
            assert(isequal(FREQ.fwhm,expected_filter_width), ...
                'Core output did not use the requested filter-width calibration.');
            FREQ.filter_width_calibration = string(filter_width_calibration);
            FREQ.filter_type = string(filter_type);
            assert(size(FREQ.evals,1) == size(markData,1), ...
                'The complete eigenspectrum was not retained.');
            analysis_info = struct('inputDyadFile',input_file,'frex',frex, ...
                'beat_frex',beat_frex,'duration',analysis_duration, ...
                'fwidth',FREQ.fwhm,'filter',string(filter_type), ...
                'filterWidthCalibration',string(filter_width_calibration), ...
                'regularisation',regularisation,'ncomps',ncomps, ...
                'badSegments',saved_dyad.bad_segments, ...
                'badSegmentsPolicy',['Synchronized dyad union excluded from ' ...
                'both narrowband and broadband covariance matrices.']);
            marker_reference = saved_dyad.marker_reference;
            dyad_info = saved_dyad.dyad_info;
            if save_flag
                save(output_file,'FREQ','beat_frex','analysis_info', ...
                    'marker_reference','dyad_info','srate','-v7.3')
                CoreStatus(rowi) = "created";
            else
                CoreStatus(rowi) = "computed";
            end
        end
    catch exception
        CoreStatus(rowi) = "error";
        CoreErrorMessage(rowi) = string(exception.message);
        warning('Core analysis row %d failed: %s',rowi,exception.message)
    end
    if mod(analysisi,25) == 0 || analysisi == numel(eligible_rows)
        fprintf('  processed %d/%d core analyses\n',analysisi,numel(eligible_rows))
    end
end
dyadManifest.CoreFile = CoreFile;
dyadManifest.CoreStatus = CoreStatus;
dyadManifest.CoreErrorMessage = CoreErrorMessage;
writetable(dyadManifest,fullfile(path_qc,'core_analysis_manifest.csv'))
assert(~any(CoreStatus == "error"),'BLOCK 1 produced errors.')


%% INDEX THE COMPLETE EXPERIMENTAL DESIGN

% The first filename number is recording order only. Each retained row is
% mapped to Instruction x Complexity x Version x Movement, and repetitions
% are ordered within Participant x condition by that acquisition index.
eligible_rows = find(strlength(dyadManifest.CoreFile) > 0 & ...
    isfile(dyadManifest.CoreFile));
analysisRows = dyadManifest(eligible_rows,:);
analysisRows.ManifestRow = eligible_rows;
instructions = ["mir" "obs"];
complexities = ["low" "medium" "high"];
versions = 1:2;
movements = 1:2;
nconds = numel(instructions)*numel(complexities)*numel(versions)*numel(movements);
ConditionIndex = (1:nconds)';
Instruction = strings(nconds,1); Complexity = strings(nconds,1);
Version = zeros(nconds,1); Movement = zeros(nconds,1);
condi = 0;
for instructioni = 1:numel(instructions)
    for complexityi = 1:numel(complexities)
        for versioni = 1:numel(versions)
            for movementi = 1:numel(movements)
                condi = condi+1;
                Instruction(condi) = instructions(instructioni);
                Complexity(condi) = complexities(complexityi);
                Version(condi) = versions(versioni);
                Movement(condi) = movements(movementi);
            end
        end
    end
end
designTable = table(ConditionIndex,Instruction,Complexity,Version,Movement);
participant_labels = compose('%03d',str2double(analysisRows.Subject));
participantIds = unique(participant_labels,'stable');
[~,participant_order] = sort(str2double(participantIds));
participantIds = participantIds(participant_order);
[~,ParticipantIndex] = ismember(participant_labels,participantIds);
row_condition = zeros(height(analysisRows),1);
for rowi = 1:height(analysisRows)
    match = designTable.Instruction == lower(string(analysisRows.Instruction(rowi))) & ...
        designTable.Complexity == lower(string(analysisRows.Complexity(rowi))) & ...
        designTable.Version == analysisRows.Version(rowi) & ...
        designTable.Movement == analysisRows.Movement(rowi);
    assert(nnz(match) == 1,'A manifest row does not map to one design cell.');
    row_condition(rowi) = designTable.ConditionIndex(match);
end
RepetitionIndex = zeros(height(analysisRows),1);
for participanti = 1:numel(participantIds)
    for condi = 1:nconds
        rows = find(ParticipantIndex == participanti & row_condition == condi);
        if isempty(rows); continue; end
        [~,order] = sortrows([analysisRows.TrialIndex(rows) eligible_rows(rows)],[1 2]);
        RepetitionIndex(rows(order)) = 1:numel(rows);
    end
end
analysisRows.ParticipantLabel = participant_labels;
analysisRows.ParticipantIndex = ParticipantIndex;
analysisRows.ConditionIndex = row_condition;
analysisRows.RepetitionIndex = RepetitionIndex;
nparticipants = numel(participantIds);
ntrials = max(RepetitionIndex);


%% BLOCK 2 - ROLE-SPECIFIC LANDSCAPES AND EFFECTIVE DIMENSIONALITY

% The artificial dyad is asymmetric. Network landscapes and H2-derived
% effective dimensionality remain separate for teacher and participant.
LandscapeFile = strings(height(dyadManifest),1);
LandscapeStatus = repmat("not eligible",height(dyadManifest),1);
LandscapeErrorMessage = strings(height(dyadManifest),1);
NegativeEigenvalueCount = nan(height(dyadManifest),1);
MaximumNegativeEigenvalue = nan(height(dyadManifest),1);
MaximumNegativeMassRatio = nan(height(dyadManifest),1);
validTrialMask = false(nparticipants,nconds,ntrials);
marker_reference = [];
fprintf('\nBLOCK 2: processing %d role-specific landscapes...\n',height(analysisRows))
if run_blocks(2)
    for analysisi = 1:height(analysisRows)
        rowi = eligible_rows(analysisi);
        input_file = dyadManifest.CoreFile(rowi);
        [~,input_stem] = fileparts(input_file);
        unit_stem = erase(string(input_stem),'FREQNESS_CORE_');
        output_file = string(fullfile(path_landscape,"FREQNESS_LANDSCAPE_"+unit_stem+".mat"));
        LandscapeFile(rowi) = output_file;
        try
            S = load(input_file,'FREQ','marker_reference');
            FREQ = S.FREQ;
            corrected_count = 0; maximum_negative = 0; maximum_ratio = 0;
            for subi = 1:size(FREQ.evals,3)
                for frexi = 1:size(FREQ.evals,2)
                    values = FREQ.evals(:,frexi,subi); negative = values < 0;
                    if ~any(negative); continue; end
                    negative_mass = sum(abs(values(negative)));
                    positive_mass = sum(values(values > 0));
                    ratio = negative_mass/max(positive_mass,realmin);
                    assert(positive_mass > 0 && ratio <= eigenvalue_negative_tolerance, ...
                        'Material negative eigenvalue mass.');
                    original_sum = sum(values);
                    maximum_negative = max(maximum_negative,max(abs(values(negative))));
                    values(negative) = 0;
                    values = values.*(original_sum/sum(values));
                    FREQ.evals(:,frexi,subi) = values;
                    corrected_count = corrected_count+nnz(negative);
                    maximum_ratio = max(maximum_ratio,ratio);
                end
            end
            eigenvalue_qc = struct('correctedCount',corrected_count, ...
                'maximumNegativeMagnitude',maximum_negative, ...
                'maximumNegativeMassRatio',maximum_ratio, ...
                'tolerance',eigenvalue_negative_tolerance, ...
                'policy',"Clip and sum-preserving rescale numerical negatives within tolerance.");
            NegativeEigenvalueCount(rowi) = corrected_count;
            MaximumNegativeEigenvalue(rowi) = maximum_negative;
            MaximumNegativeMassRatio(rowi) = maximum_ratio;
            [H2,ED] = FREQNESS_EffectDim_Mocap(FREQ,'figure',false);
            H2_teacher = H2(:,1); H2_participant = H2(:,2);
            ED_teacher = ED(:,1); ED_participant = ED(:,2);
            frex = FREQ.frex; frex_norm = FREQ.frex_norm;
            rowIndex = rowi;
            if save_flag && (~isfile(output_file) || overwrite)
                save(output_file,'H2_teacher','H2_participant','ED_teacher', ...
                    'ED_participant','frex','frex_norm','rowIndex','eigenvalue_qc','-v7.3')
                LandscapeStatus(rowi) = "created";
            else
                LandscapeStatus(rowi) = "existing";
            end
            if isempty(marker_reference); marker_reference = S.marker_reference; end
            validTrialMask(analysisRows.ParticipantIndex(analysisi), ...
                analysisRows.ConditionIndex(analysisi), ...
                analysisRows.RepetitionIndex(analysisi)) = true;
        catch exception
            LandscapeStatus(rowi) = "error";
            LandscapeErrorMessage(rowi) = string(exception.message);
            warning('Landscape row %d failed: %s',rowi,exception.message)
        end
        if mod(analysisi,25) == 0 || analysisi == height(analysisRows)
            fprintf('  processed %d/%d landscapes\n',analysisi,height(analysisRows))
        end
    end
end
dyadManifest.LandscapeFile = LandscapeFile;
dyadManifest.LandscapeStatus = LandscapeStatus;
dyadManifest.LandscapeErrorMessage = LandscapeErrorMessage;
dyadManifest.NegativeEigenvalueCount = NegativeEigenvalueCount;
dyadManifest.MaximumNegativeEigenvalue = MaximumNegativeEigenvalue;
dyadManifest.MaximumNegativeMassRatio = MaximumNegativeMassRatio;
analysisRows.SummaryIncluded = validTrialMask(sub2ind(size(validTrialMask), ...
    analysisRows.ParticipantIndex,analysisRows.ConditionIndex,analysisRows.RepetitionIndex));
save(fullfile(path_landscape,'FREQNESS_GroupNetworkSummary.mat'), ...
    'analysisRows','participantIds','designTable','validTrialMask','marker_reference')
writetable(dyadManifest,fullfile(path_qc,'landscape_analysis_manifest.csv'))
assert(~any(LandscapeStatus == "error"),'BLOCK 2 produced errors.')


%% BLOCK 3 - INTERACTION ANALYSES

% Interaction analyses are intentionally ordered as temporal recurrence,
% spatial coordination, then network-landscape similarity. JRQA is disabled
% because it cannot honour bad_segments without biasing its recurrence map.

% 3A. Gap-aware phase-space RQA.
metric_fields = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
coverage_fields = {'ValidSampleCount','ExcludedSampleCount', ...
    'EligiblePairCount','EligiblePairFraction'};
ncomponents = numel(components); nmeters = numel(meter);
noutputs = height(analysisRows)*ncomponents;
ManifestRow = repelem(eligible_rows,ncomponents,1);
Component = repmat(components',height(analysisRows),1);
PhaseRQAFile = strings(noutputs,1); PhaseRQAStatus = repmat("not processed",noutputs,1);
PhaseRQAErrorMessage = strings(noutputs,1); InputBadSampleCount = nan(noutputs,1);
ShortRunExcludedSampleCount = nan(noutputs,1); DownsampledBadSampleCount = nan(noutputs,1);
SelectedValidSampleCount = nan(noutputs,1); SelectedExcludedSampleCount = nan(noutputs,1);
EligiblePairCount = nan(noutputs,1); EligiblePairFraction = nan(noutputs,1);
antialias_cutoff = rqa_lp_cutoff_norm/rqa_downsample_factor;
[b_butt,a_butt] = butter(rqa_lp_order,antialias_cutoff,'low');
if run_blocks(3)
    fprintf('\nBLOCK 3A: phase-space RQA for %d recordings x %d components...\n',height(analysisRows),ncomponents)
    for componenti = 1:ncomponents
        which_comp = components(componenti);
        component_output_path = fullfile(path_rqa,['Component_' num2str(which_comp)]);
        if ~isfolder(component_output_path); mkdir(component_output_path); end
        PhaseRQA = struct('target_frex',[],'component',which_comp, ...
            'metric_levels',meter,'duration',rqa_duration, ...
            'standardize',rqa_standardize,'threshold_method', ...
            string(rqa_threshold_method),'threshold',rqa_threshold, ...
            'theiler_window',rqa_theiler_window,'lmin',rqa_lmin, ...
            'vmin',rqa_vmin,'store_matrices',rqa_store_matrices, ...
            'figure',rqa_figure,'animate',rqa_animate);
        phaseOutput = struct(); phaseCoverage = struct();
        for fieldi = 1:numel(metric_fields)
            phaseOutput.(metric_fields{fieldi}) = nan(nparticipants,nconds,nmeters,ntrials);
        end
        for fieldi = 1:numel(coverage_fields)
            phaseCoverage.(coverage_fields{fieldi}) = nan(nparticipants,nconds,nmeters,ntrials);
        end
        validTrialMask = false(nparticipants,nconds,ntrials);
        for analysisi = 1:height(analysisRows)
            rowi = eligible_rows(analysisi);
            longi = (analysisi-1)*ncomponents+componenti;
            input_file = dyadManifest.CoreFile(rowi);
            [~,input_stem] = fileparts(input_file);
            unit_stem = erase(string(input_stem),'FREQNESS_CORE_');
            output_file = string(fullfile(component_output_path, ...
                "FREQNESS_PHASERQA_GAPAWARE_"+unit_stem+".mat"));
            PhaseRQAFile(longi) = output_file;
            try
                S = load(input_file,'FREQ','beat_frex');
                analysis_info = struct('implementation',"gap_aware_v1", ...
                    'bad_segment_policy',"filter_valid_runs_then_mask_rqa", ...
                    'short_filter_run_policy',"exclude", ...
                    'inputCoreFile',input_file,'PhaseRQA',PhaseRQA, ...
                    'inputSrate',S.FREQ.srate,'downsample_factor', ...
                    rqa_downsample_factor,'outputSrate', ...
                    S.FREQ.srate/rqa_downsample_factor,'lp_order', ...
                    rqa_lp_order,'lp_cutoff_norm',rqa_lp_cutoff_norm, ...
                    'antialias_cutoff_normalized_to_input_nyquist',antialias_cutoff);
                if isfile(output_file) && ~overwrite
                    saved = load(output_file,'FREQrqa','PhaseRQA','analysis_info','preprocessing_qc');
                    FREQrqa = saved.FREQrqa; preprocessing_qc = saved.preprocessing_qc;
                    PhaseRQAStatus(longi) = "existing";
                else
                    FREQ = S.FREQ; dwn = rqa_downsample_factor;
                    ntime = size(FREQ.ts,2); nfrex = size(FREQ.ts,3); nsubs = size(FREQ.ts,4);
                    input_bad_segments = unique(FREQ.bad_segments(:)','stable');
                    input_valid = true(1,ntime); input_valid(input_bad_segments) = false;
                    edges = diff([false input_valid false]); run_starts = find(edges == 1); run_ends = find(edges == -1)-1;
                    minimum_run_samples = 3*(max(numel(a_butt),numel(b_butt))-1)+1;
                    filter_valid = input_valid; short_run_segments = zeros(numel(run_starts),2); short_run_count = 0;
                    for runi = 1:numel(run_starts)
                        if run_ends(runi)-run_starts(runi)+1 < minimum_run_samples
                            filter_valid(run_starts(runi):run_ends(runi)) = false;
                            short_run_count = short_run_count+1;
                            short_run_segments(short_run_count,:) = [run_starts(runi) run_ends(runi)];
                        end
                    end
                    short_run_segments = short_run_segments(1:short_run_count,:);
                    selected = reshape(permute(FREQ.ts(which_comp,:,:,:),[2 3 4 1]),ntime,nfrex*nsubs);
                    selected = double(selected);
                    filtered = zeros(size(selected));
                    edges = diff([false filter_valid false]); run_starts = find(edges == 1); run_ends = find(edges == -1)-1;
                    for runi = 1:numel(run_starts)
                        indices = run_starts(runi):run_ends(runi);
                        filtered(indices,:) = filtfilt(b_butt,a_butt,double(selected(indices,:)));
                    end
                    sample_indices = 1:dwn:ntime; downsampled_valid = filter_valid(sample_indices);
                    filtered = reshape(filtered(sample_indices,:),numel(sample_indices),nfrex,nsubs);
                    FREQ.ts = FREQ.ts(:,sample_indices,:,:);
                    FREQ.ts(which_comp,:,:,:) = cast(permute(filtered,[4 1 2 3]),'like',FREQ.ts);
                    FREQ.srate = FREQ.srate/dwn; FREQ.bad_segments = find(~downsampled_valid);
                    preprocessing_qc = struct('Policy',"filter_valid_runs_then_decimate", ...
                        'InputSampleCount',ntime,'InputBadSampleCount',numel(input_bad_segments), ...
                        'FilterMinimumRunSamples',minimum_run_samples,'ShortRunSegments',short_run_segments, ...
                        'ShortRunExcludedSampleCount',nnz(input_valid & ~filter_valid), ...
                        'DownsampleFactor',dwn,'DownsampledSampleCount',numel(sample_indices), ...
                        'DownsampledBadSampleCount',numel(FREQ.bad_segments), ...
                        'DownsampledValidSampleCount',nnz(downsampled_valid), ...
                        'DownsampledBadSegments',FREQ.bad_segments);
                    FREQrqa = FREQNESS_PhaseSpaceRQA_Mocap(FREQ,S.beat_frex, ...
                        'metric_levels',meter,'component',which_comp,'duration',rqa_duration, ...
                        'standardize',rqa_standardize,'threshold_method',rqa_threshold_method, ...
                        'threshold',rqa_threshold,'theiler_window',rqa_theiler_window, ...
                        'lmin',rqa_lmin,'vmin',rqa_vmin,'store_matrices',rqa_store_matrices, ...
                        'figure',rqa_figure,'animate',rqa_animate,'srate',FREQ.srate);
                    if save_flag
                        save(output_file,'FREQrqa','PhaseRQA','analysis_info','preprocessing_qc','-v7.3')
                        PhaseRQAStatus(longi) = "created";
                    else
                        PhaseRQAStatus(longi) = "computed";
                    end
                end
                InputBadSampleCount(longi) = preprocessing_qc.InputBadSampleCount;
                ShortRunExcludedSampleCount(longi) = preprocessing_qc.ShortRunExcludedSampleCount;
                DownsampledBadSampleCount(longi) = preprocessing_qc.DownsampledBadSampleCount;
                SelectedValidSampleCount(longi) = FREQrqa(1).ValidSampleCount;
                SelectedExcludedSampleCount(longi) = FREQrqa(1).ExcludedSampleCount;
                EligiblePairCount(longi) = FREQrqa(1).EligiblePairCount;
                EligiblePairFraction(longi) = FREQrqa(1).EligiblePairFraction;
                participanti = analysisRows.ParticipantIndex(analysisi);
                condi = analysisRows.ConditionIndex(analysisi);
                triali = analysisRows.RepetitionIndex(analysisi);
                for metri = 1:nmeters
                    for fieldi = 1:numel(metric_fields)
                        phaseOutput.(metric_fields{fieldi})(participanti,condi,metri,triali) = FREQrqa(metri).(metric_fields{fieldi});
                    end
                    for fieldi = 1:numel(coverage_fields)
                        phaseCoverage.(coverage_fields{fieldi})(participanti,condi,metri,triali) = FREQrqa(metri).(coverage_fields{fieldi});
                    end
                end
                validTrialMask(participanti,condi,triali) = true;
            catch exception
                PhaseRQAStatus(longi) = "error"; PhaseRQAErrorMessage(longi) = string(exception.message);
                warning('RQA row %d component %d failed: %s',rowi,which_comp,exception.message)
            end
            if mod(analysisi,25) == 0 || analysisi == height(analysisRows)
                fprintf('  RQA component %d: %d/%d\n',which_comp,analysisi,height(analysisRows))
            end
        end
        PhaseRQA.output = phaseOutput; PhaseRQA.coverage = phaseCoverage;
        componentRows = analysisRows;
        componentRows.PhaseRQAIncluded = validTrialMask(sub2ind(size(validTrialMask), ...
            componentRows.ParticipantIndex,componentRows.ConditionIndex,componentRows.RepetitionIndex));
        component_indices = (componenti:ncomponents:noutputs)';
        componentRows.InputBadSampleCount = InputBadSampleCount(component_indices);
        componentRows.ShortRunExcludedSampleCount = ShortRunExcludedSampleCount(component_indices);
        componentRows.DownsampledBadSampleCount = DownsampledBadSampleCount(component_indices);
        componentRows.SelectedValidSampleCount = SelectedValidSampleCount(component_indices);
        componentRows.SelectedExcludedSampleCount = SelectedExcludedSampleCount(component_indices);
        componentRows.EligiblePairCount = EligiblePairCount(component_indices);
        componentRows.EligiblePairFraction = EligiblePairFraction(component_indices);
        phase_summary_file = fullfile(component_output_path, ...
            ['FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#' num2str(which_comp) '.mat']);
        save(phase_summary_file,'PhaseRQA','which_comp','meter','participantIds', ...
            'designTable','componentRows','validTrialMask','-v7.3')
    end
end
phaseRQAManifest = table(ManifestRow,Component,PhaseRQAFile,PhaseRQAStatus, ...
    PhaseRQAErrorMessage,InputBadSampleCount,ShortRunExcludedSampleCount, ...
    DownsampledBadSampleCount,SelectedValidSampleCount,SelectedExcludedSampleCount, ...
    EligiblePairCount,EligiblePairFraction);
writetable(phaseRQAManifest,fullfile(path_qc,'phase_rqa_gapaware_analysis_manifest.csv'))
assert(~any(PhaseRQAStatus == "error"),'BLOCK 3 RQA produced errors.')

% 3B-3C. Spatial coordination, then network-landscape similarity.
ManifestRow = repelem(eligible_rows,ncomponents,1);
Component = repmat(components',height(analysisRows),1);
CoordinationFile = strings(noutputs,1); CoordinationStatus = repmat("not processed",noutputs,1);
CoordinationErrorMessage = strings(noutputs,1);
fprintf('\nBLOCK 3B-3C: spatial coordination and landscape similarity...\n')
if run_blocks(3)
    for componenti = 1:ncomponents
        which_comp = components(componenti);
        component_output_path = fullfile(path_spatial,['Component_' num2str(which_comp)]);
        if ~isfolder(component_output_path); mkdir(component_output_path); end
        MIRROR = nan(nparticipants,nconds,nmeters,ntrials);
        LANDSCAPE_SIMILARITY_COMP = nan(nparticipants,nconds,ntrials);
        LANDSCAPE_SIMILARITY_ENTROPY = nan(nparticipants,nconds,ntrials);
        validTrialMask = false(nparticipants,nconds,ntrials);
        for analysisi = 1:height(analysisRows)
            rowi = eligible_rows(analysisi); longi = (analysisi-1)*ncomponents+componenti;
            input_file = dyadManifest.CoreFile(rowi); [~,input_stem] = fileparts(input_file);
            unit_stem = erase(string(input_stem),'FREQNESS_CORE_');
            output_file = string(fullfile(component_output_path,"FREQNESS_SPATIALCOORDINATION_"+unit_stem+".mat"));
            CoordinationFile(longi) = output_file;
            try
                S = load(input_file,'FREQ','beat_frex');
                analysis_info = struct('method',"spatial_mirroring_and_landscape_similarity", ...
                    'inputCoreFile',input_file,'component',which_comp,'metric_levels',meter, ...
                    'landscape_frequency_range',landscape_frequency_range);
                if isfile(output_file) && ~overwrite
                    saved = load(output_file,'FREQmirror','landscape_similarity_comp', ...
                        'landscape_similarity_entropy','selected_frex');
                    FREQmirror = saved.FREQmirror;
                    landscape_similarity_comp = saved.landscape_similarity_comp;
                    landscape_similarity_entropy = saved.landscape_similarity_entropy;
                    selected_frex = saved.selected_frex;
                    CoordinationStatus(longi) = "existing";
                else
                    FREQmirror = FREQNESS_SpaceCoord_Mocap(S.FREQ,S.beat_frex, ...
                        'metric_levels',meter,'component',which_comp);
                    similarityFREQ = S.FREQ;
                    for subi = 1:size(similarityFREQ.evals,3)
                        for frexi = 1:size(similarityFREQ.evals,2)
                            values = similarityFREQ.evals(:,frexi,subi); negative = values < 0;
                            if ~any(negative); continue; end
                            negative_mass = sum(abs(values(negative))); positive_mass = sum(values(values > 0));
                            assert(positive_mass > 0 && negative_mass/max(positive_mass,realmin) <= eigenvalue_negative_tolerance, ...
                                'Material negative eigenvalue mass.');
                            original_sum = sum(values); values(negative) = 0; values = values.*(original_sum/sum(values));
                            similarityFREQ.evals(:,frexi,subi) = values;
                        end
                    end
                    if isempty(landscape_frequency_range)
                        [landscape_similarity_comp,landscape_similarity_entropy,selected_frex] = ...
                            FREQNESS_LandscapeSimilarity(similarityFREQ,'component',which_comp);
                    else
                        [landscape_similarity_comp,landscape_similarity_entropy,selected_frex] = ...
                            FREQNESS_LandscapeSimilarity(similarityFREQ,'component',which_comp, ...
                            'frequency_range',landscape_frequency_range);
                    end
                    if save_flag
                        save(output_file,'FREQmirror','landscape_similarity_comp', ...
                            'landscape_similarity_entropy','selected_frex','which_comp','meter','analysis_info','-v7.3')
                        CoordinationStatus(longi) = "created";
                    else
                        CoordinationStatus(longi) = "computed";
                    end
                end
                participanti = analysisRows.ParticipantIndex(analysisi); condi = analysisRows.ConditionIndex(analysisi);
                triali = analysisRows.RepetitionIndex(analysisi);
                MIRROR(participanti,condi,:,triali) = reshape(FREQmirror,[1 1 nmeters 1]);
                LANDSCAPE_SIMILARITY_COMP(participanti,condi,triali) = landscape_similarity_comp;
                LANDSCAPE_SIMILARITY_ENTROPY(participanti,condi,triali) = landscape_similarity_entropy;
                validTrialMask(participanti,condi,triali) = true;
            catch exception
                CoordinationStatus(longi) = "error"; CoordinationErrorMessage(longi) = string(exception.message);
                warning('Coordination row %d component %d failed: %s',rowi,which_comp,exception.message)
            end
            if mod(analysisi,25) == 0 || analysisi == height(analysisRows)
                fprintf('  coordination component %d: %d/%d\n',which_comp,analysisi,height(analysisRows))
            end
        end
        componentRows = analysisRows;
        componentRows.CoordinationIncluded = validTrialMask(sub2ind(size(validTrialMask), ...
            componentRows.ParticipantIndex,componentRows.ConditionIndex,componentRows.RepetitionIndex));
        coordination_summary_file = fullfile(component_output_path, ...
            ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' num2str(which_comp) '.mat']);
        save(coordination_summary_file,'MIRROR','LANDSCAPE_SIMILARITY_COMP', ...
            'LANDSCAPE_SIMILARITY_ENTROPY','which_comp','meter','participantIds', ...
            'designTable','componentRows','validTrialMask','-v7.3')
    end
end
coordinationManifest = table(ManifestRow,Component,CoordinationFile,CoordinationStatus,CoordinationErrorMessage);
writetable(coordinationManifest,fullfile(path_qc,'spatial_coordination_analysis_manifest.csv'))
assert(~any(CoordinationStatus == "error"),'BLOCK 3 spatial/landscape analyses produced errors.')


%% BLOCK 4 - GROUP SUMMARIES AND FIGURES

% Repetitions are averaged within Participant x factorial cell before the
% group mean/SEM. Teacher and participant landscapes and dimensionality are
% kept separate; teacher SEM is deliberately not shown.
if run_blocks(4)
    first_core = load(dyadManifest.CoreFile(eligible_rows(1)),'FREQ','marker_reference');
    ncoordinates = size(first_core.FREQ.evals,1);
    nfrex = size(first_core.FREQ.evals,2);
    nsubs = size(first_core.FREQ.evals,3);
    avg_evals_teacher = nan(nconds,ncoordinates,nfrex);
    avg_evals_participant = nan(nconds,ncoordinates,nfrex);
    sem_evals_participant = nan(nconds,ncoordinates,nfrex);
    avg_pats = nan(nconds,ncoordinates,ncomps2keep,nfrex,nsubs);
    sem_pats = nan(nconds,ncoordinates,ncomps2keep,nfrex,nsubs);
    avg_ED_teacher = nan(nconds,nfrex);
    avg_ED_participant = nan(nconds,nfrex);
    sem_ED_participant = nan(nconds,nfrex);
    avg_pattern_correlation = nan(nconds,nfrex,nsubs);
    sem_pattern_correlation = nan(nconds,nfrex,nsubs);
    participantCounts = zeros(nconds,1);
    frex2plot = first_core.FREQ.frex_norm(:,1);
    marker_reference = first_core.marker_reference;

    fprintf('\nBLOCK 4: aggregating %d recordings by experimental condition...\n',height(analysisRows))
    for condi = 1:nconds
        eval_sum = zeros(nparticipants,ncoordinates,nfrex,nsubs);
        pat_sum = zeros(nparticipants,ncoordinates,ncomps2keep,nfrex,nsubs);
        ed_sum = zeros(nparticipants,nfrex,nsubs);
        correlation_sum = zeros(nparticipants,nfrex,nsubs);
        correlation_count = zeros(nparticipants,nfrex,nsubs);
        repetition_count = zeros(nparticipants,1);
        rows = find(analysisRows.ConditionIndex == condi);
        for row_position = rows'
            rowi = eligible_rows(row_position);
            S = load(dyadManifest.CoreFile(rowi),'FREQ');
            L = load(dyadManifest.LandscapeFile(rowi),'ED_teacher','ED_participant');
            FREQ = S.FREQ;
            for subi = 1:size(FREQ.evals,3)
                for frexi = 1:size(FREQ.evals,2)
                    values = FREQ.evals(:,frexi,subi); negative = values < 0;
                    if ~any(negative); continue; end
                    negative_mass = sum(abs(values(negative))); positive_mass = sum(values(values > 0));
                    assert(positive_mass > 0 && negative_mass/max(positive_mass,realmin) <= eigenvalue_negative_tolerance, ...
                        'Material negative eigenvalue mass.');
                    original_sum = sum(values); values(negative) = 0;
                    values = values.*(original_sum/sum(values));
                    FREQ.evals(:,frexi,subi) = values;
                end
            end
            participanti = analysisRows.ParticipantIndex(row_position);
            eval_sum(participanti,:,:,:) = eval_sum(participanti,:,:,:) + ...
                reshape(FREQ.evals,[1 ncoordinates nfrex nsubs]);
            pat_sum(participanti,:,:,:,:) = pat_sum(participanti,:,:,:,:) + ...
                reshape(abs(FREQ.pats(:,1:ncomps2keep,:,:)), ...
                [1 ncoordinates ncomps2keep nfrex nsubs]);
            role_ED = nan(nfrex,nsubs);
            role_ED(:,1) = L.ED_teacher; role_ED(:,2) = L.ED_participant;
            ed_sum(participanti,:,:) = ed_sum(participanti,:,:) + reshape(role_ED,[1 nfrex nsubs]);
            if ncomps2keep >= 2
                for subi = 1:nsubs
                    for frexi = 1:nfrex
                        value = corr(abs(FREQ.pats(:,1,frexi,subi)),abs(FREQ.pats(:,2,frexi,subi)));
                        if isfinite(value)
                            correlation_sum(participanti,frexi,subi) = correlation_sum(participanti,frexi,subi)+value;
                            correlation_count(participanti,frexi,subi) = correlation_count(participanti,frexi,subi)+1;
                        end
                    end
                end
            end
            repetition_count(participanti) = repetition_count(participanti)+1;
        end

        eval_participant = nan(size(eval_sum)); pat_participant = nan(size(pat_sum)); ed_participant = nan(size(ed_sum));
        retained_participants = find(repetition_count > 0);
        for participanti = retained_participants'
            eval_participant(participanti,:,:,:) = eval_sum(participanti,:,:,:)/repetition_count(participanti);
            pat_participant(participanti,:,:,:,:) = pat_sum(participanti,:,:,:,:)/repetition_count(participanti);
            ed_participant(participanti,:,:) = ed_sum(participanti,:,:)/repetition_count(participanti);
        end
        participantCounts(condi) = numel(retained_participants);
        n = sum(~isnan(eval_participant(:,:,:,1)),1);
        mu = mean(eval_participant(:,:,:,1),1,'omitnan');
        avg_evals_teacher(condi,:,:) = reshape(mu,[1 ncoordinates nfrex]);
        n = sum(~isnan(eval_participant(:,:,:,2)),1);
        mu = mean(eval_participant(:,:,:,2),1,'omitnan');
        se = std(eval_participant(:,:,:,2),0,1,'omitnan')./sqrt(max(n,1)); se(n == 0) = NaN;
        avg_evals_participant(condi,:,:) = reshape(mu,[1 ncoordinates nfrex]);
        sem_evals_participant(condi,:,:) = reshape(se,[1 ncoordinates nfrex]);
        n = sum(~isnan(pat_participant),1); mu = mean(pat_participant,1,'omitnan');
        se = std(pat_participant,0,1,'omitnan')./sqrt(max(n,1)); se(n == 0) = NaN;
        avg_pats(condi,:,:,:,:) = reshape(mu,[1 ncoordinates ncomps2keep nfrex nsubs]);
        sem_pats(condi,:,:,:,:) = reshape(se,[1 ncoordinates ncomps2keep nfrex nsubs]);
        n = sum(~isnan(ed_participant(:,:,1)),1); mu = mean(ed_participant(:,:,1),1,'omitnan');
        avg_ED_teacher(condi,:) = reshape(mu,[1 nfrex]);
        n = sum(~isnan(ed_participant(:,:,2)),1); mu = mean(ed_participant(:,:,2),1,'omitnan');
        se = std(ed_participant(:,:,2),0,1,'omitnan')./sqrt(max(n,1)); se(n == 0) = NaN;
        avg_ED_participant(condi,:) = reshape(mu,[1 nfrex]);
        sem_ED_participant(condi,:) = reshape(se,[1 nfrex]);
        correlation_participant = correlation_sum./max(correlation_count,1);
        correlation_participant(correlation_count == 0) = NaN;
        n = sum(~isnan(correlation_participant),1); mu = mean(correlation_participant,1,'omitnan');
        se = std(correlation_participant,0,1,'omitnan')./sqrt(max(n,1)); se(n == 0) = NaN;
        avg_pattern_correlation(condi,:,:) = reshape(mu,[1 nfrex nsubs]);
        sem_pattern_correlation(condi,:,:) = reshape(se,[1 nfrex nsubs]);
    end

    network_summary_file = fullfile(path_group,'FREQNESS_GroupAnalysisSummary.mat');
    save(network_summary_file,'avg_evals_teacher','avg_evals_participant', ...
        'sem_evals_participant','avg_pats','sem_pats','avg_ED_teacher', ...
        'avg_ED_participant','sem_ED_participant','avg_pattern_correlation', ...
        'sem_pattern_correlation','frex2plot','participantCounts','analysisRows', ...
        'designTable','participantIds','marker_reference','marklabels','bones','-v7.3')

    % Summarize every interaction dependent variable using participants as
    % the inferential unit after within-cell repetition averaging.
    coordinationGroup = repmat(struct('Component',[],'Mean',struct(), ...
        'SEM',struct(),'N',struct()),1,ncomponents);
    phaseGroup = repmat(struct('Component',[],'Mean',struct(), ...
        'SEM',struct(),'N',struct(),'MeanCoverage',struct(), ...
        'SEMCoverage',struct()),1,ncomponents);
    for componenti = 1:ncomponents
        which_comp = components(componenti);
        coordination_file = fullfile(path_spatial,['Component_' num2str(which_comp)], ...
            ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' num2str(which_comp) '.mat']);
        C = load(coordination_file,'MIRROR','LANDSCAPE_SIMILARITY_COMP','LANDSCAPE_SIMILARITY_ENTROPY');
        coordinationGroup(componenti).Component = which_comp;
        participant_data = mean(C.MIRROR,4,'omitnan');
        n = sum(~isnan(participant_data),1); mu = mean(participant_data,1,'omitnan');
        se = std(participant_data,0,1,'omitnan')./sqrt(max(n,1)); se(n == 0) = NaN;
        coordinationGroup(componenti).Mean.MIRROR = reshape(mu,[nconds nmeters]);
        coordinationGroup(componenti).SEM.MIRROR = reshape(se,[nconds nmeters]);
        coordinationGroup(componenti).N.MIRROR = reshape(n,[nconds nmeters]);
        similarity_fields = {'LANDSCAPE_SIMILARITY_COMP','LANDSCAPE_SIMILARITY_ENTROPY'};
        for fieldi = 1:numel(similarity_fields)
            field = similarity_fields{fieldi}; participant_data = mean(C.(field),3,'omitnan');
            n = sum(~isnan(participant_data),1); mu = mean(participant_data,1,'omitnan');
            se = std(participant_data,0,1,'omitnan')./sqrt(max(n,1)); se(n == 0) = NaN;
            coordinationGroup(componenti).Mean.(field) = mu(:);
            coordinationGroup(componenti).SEM.(field) = se(:);
            coordinationGroup(componenti).N.(field) = n(:);
        end

        phase_file = fullfile(path_rqa,['Component_' num2str(which_comp)], ...
            ['FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#' num2str(which_comp) '.mat']);
        P = load(phase_file,'PhaseRQA'); phaseGroup(componenti).Component = which_comp;
        for fieldi = 1:numel(metric_fields)
            field = metric_fields{fieldi}; participant_data = mean(P.PhaseRQA.output.(field),4,'omitnan');
            n = sum(~isnan(participant_data),1); mu = mean(participant_data,1,'omitnan');
            se = std(participant_data,0,1,'omitnan')./sqrt(max(n,1)); se(n == 0) = NaN;
            phaseGroup(componenti).Mean.(field) = reshape(mu,[nconds nmeters]);
            phaseGroup(componenti).SEM.(field) = reshape(se,[nconds nmeters]);
            phaseGroup(componenti).N.(field) = reshape(n,[nconds nmeters]);
        end
        for fieldi = 1:numel(coverage_fields)
            field = coverage_fields{fieldi}; participant_data = mean(P.PhaseRQA.coverage.(field),4,'omitnan');
            n = sum(~isnan(participant_data),1); mu = mean(participant_data,1,'omitnan');
            se = std(participant_data,0,1,'omitnan')./sqrt(max(n,1)); se(n == 0) = NaN;
            phaseGroup(componenti).MeanCoverage.(field) = reshape(mu,[nconds nmeters]);
            phaseGroup(componenti).SEMCoverage.(field) = reshape(se,[nconds nmeters]);
        end
    end
    secondary_summary_file = fullfile(path_group,'FREQNESS_GroupCoordinationSummary.mat');
    save(secondary_summary_file,'coordinationGroup','phaseGroup','designTable','-v7.3')

    if vis_flag
        condition_labels = designTable.Instruction+"-"+designTable.Complexity+ ...
            "-v"+designTable.Version+"-mov"+designTable.Movement;
        x = log2(frex2plot(:)); colors = lines(ncomps2keep);

        fig = figure('Visible',figure_visibility,'Color','w'); tiledlayout(4,6,'TileSpacing','compact');
        for condi = 1:nconds
            nexttile; hold on
            for compi = 1:ncomps2keep
                y = squeeze(avg_evals_participant(condi,compi,:)); se = squeeze(sem_evals_participant(condi,compi,:));
                fill([x;flipud(x)],[y-se;flipud(y+se)],colors(compi,:),'FaceAlpha',.15,'EdgeColor','none');
                plot(x,y,'Color',colors(compi,:),'LineWidth',1.2)
            end
            title(condition_labels(condi),'Interpreter','none')
        end
        sgtitle('Participant network landscape')
        savefig(fig,fullfile(path_figures,'NetworkLandscape_Participants.fig'))
        exportgraphics(fig,fullfile(path_figures,'NetworkLandscape_Participants.png'),'Resolution',200)

        fig = figure('Visible',figure_visibility,'Color','w'); tiledlayout(4,6,'TileSpacing','compact');
        for condi = 1:nconds
            nexttile; hold on
            for compi = 1:ncomps2keep
                plot(x,squeeze(avg_evals_teacher(condi,compi,:)),'Color',colors(compi,:),'LineWidth',1.2)
            end
            title(condition_labels(condi),'Interpreter','none')
        end
        sgtitle('Teacher network landscape')
        savefig(fig,fullfile(path_figures,'NetworkLandscape_Teacher.fig'))
        exportgraphics(fig,fullfile(path_figures,'NetworkLandscape_Teacher.png'),'Resolution',200)

        fig = figure('Visible',figure_visibility,'Color','w'); tiledlayout(4,6,'TileSpacing','compact');
        for condi = 1:nconds
            nexttile; hold on; y = avg_ED_participant(condi,:)'; se = sem_ED_participant(condi,:)';
            fill([x;flipud(x)],[y-se;flipud(y+se)],[.9 .22 .16],'FaceAlpha',.2,'EdgeColor','none');
            plot(x,y,'Color',[.9 .22 .16],'LineWidth',1.2); title(condition_labels(condi),'Interpreter','none')
        end
        sgtitle('Participant effective dimensionality')
        savefig(fig,fullfile(path_figures,'EffectiveDimensionality_Participants.fig'))
        exportgraphics(fig,fullfile(path_figures,'EffectiveDimensionality_Participants.png'),'Resolution',200)

        fig = figure('Visible',figure_visibility,'Color','w'); tiledlayout(4,6,'TileSpacing','compact');
        for condi = 1:nconds
            nexttile; plot(x,avg_ED_teacher(condi,:)','Color',[.9 .22 .16],'LineWidth',1.2)
            title(condition_labels(condi),'Interpreter','none')
        end
        sgtitle('Teacher effective dimensionality')
        savefig(fig,fullfile(path_figures,'EffectiveDimensionality_Teacher.fig'))
        exportgraphics(fig,fullfile(path_figures,'EffectiveDimensionality_Teacher.png'),'Resolution',200)

        fig = figure('Visible',figure_visibility,'Color','w');
        plot(log2(frex2plot),squeeze(mean(avg_pattern_correlation,[1 3],'omitnan')),'Color',[.9 .22 .16],'LineWidth',1.5)
        yline(0,'k-'); ylim([-1 1]); xlabel('Frequency (x beat)');
        ylabel('Pattern correlation: components 1 and 2'); grid on
        savefig(fig,fullfile(path_figures,'ComponentPatternCorrelation.fig'))
        exportgraphics(fig,fullfile(path_figures,'ComponentPatternCorrelation.png'),'Resolution',200)

        % Grand-average spatial activation patterns use the full skeleton.
        FREQfigure = struct();
        FREQfigure.evals = cat(3,squeeze(mean(avg_evals_teacher,1,'omitnan')), ...
            squeeze(mean(avg_evals_participant,1,'omitnan')));
        FREQfigure.pats = squeeze(mean(avg_pats,1,'omitnan'));
        FREQfigure.frex = frex2plot;
        pattern_targets = pattern_frequencies(pattern_frequencies >= min(frex2plot) & pattern_frequencies <= max(frex2plot));
        for compi = pattern_components
            Patterns = struct('frex',pattern_targets,'labels',{marklabels}, ...
                'markerData',marker_reference,'comp',compi,'srate',srate, ...
                'start',.25,'bones',bones,'plot_bones',plot_pattern_bones, ...
                'plot_matrix',false,'animate',false,'frequency_unit','x beat');
            generated = FREQNESS_Visualizer_Mocap(FREQfigure,[],Patterns);
            drawnow
            for figurei = 1:numel(generated.patterns)
                name = sprintf('ActivationPatterns_Comp%d_Frequency%d',compi,figurei);
                assert(isgraphics(generated.patterns(figurei),'figure'), ...
                    'Visualizer returned an invalid activation-pattern figure.');
                savefig(generated.patterns(figurei),fullfile(path_figures,[name '.fig']))
                exportgraphics(generated.patterns(figurei),fullfile(path_figures,[name '.png']),'Resolution',200)
            end
        end

        metric_labels = compose('%g',meter)+" x beat ("+compose('%.3g',meter*beat_frex(1))+" Hz)";
        for componenti = 1:ncomponents
            which_comp = components(componenti);
            figure_groups = {coordinationGroup,{'MIRROR'},'SpatialCoordination'; ...
                phaseGroup,metric_fields,'PhaseRQA'};
            for groupi = 1:size(figure_groups,1)
                results = figure_groups{groupi,1}; fields = figure_groups{groupi,2}; prefix = figure_groups{groupi,3};
                for fieldi = 1:numel(fields)
                    field = fields{fieldi}; fig = figure('Visible',figure_visibility,'Color','w'); hold on
                    mu = results(componenti).Mean.(field); se = results(componenti).SEM.(field);
                    for metri = 1:size(mu,2)
                        errorbar(1:nconds,mu(:,metri),se(:,metri),'-o','LineWidth',1)
                    end
                    xticks(1:nconds); xticklabels(condition_labels); xtickangle(90); grid on
                    title(sprintf('%s %s - Component %d',prefix,field,which_comp)); legend(metric_labels,'Location','best')
                    name = sprintf('%s_%s_Comp%d',prefix,field,which_comp);
                    savefig(fig,fullfile(path_figures,[name '.fig'])); exportgraphics(fig,fullfile(path_figures,[name '.png']),'Resolution',200)
                end
            end
            similarity_fields = {'LANDSCAPE_SIMILARITY_COMP','LANDSCAPE_SIMILARITY_ENTROPY'};
            for fieldi = 1:numel(similarity_fields)
                if fieldi == 2 && componenti > 1; continue; end
                field = similarity_fields{fieldi}; fig = figure('Visible',figure_visibility,'Color','w');
                errorbar(1:nconds,coordinationGroup(componenti).Mean.(field), ...
                    coordinationGroup(componenti).SEM.(field),'-o','LineWidth',1)
                xticks(1:nconds); xticklabels(condition_labels); xtickangle(90); ylabel('Pearson correlation'); ylim([-1 1]); grid on
                if fieldi == 1
                    title(sprintf('Component landscape similarity - Component %d',which_comp));
                    name = sprintf('LandscapeSimilarity_Component_Comp%d',which_comp);
                else
                    title('H2 entropy-landscape similarity'); name = 'LandscapeSimilarity_Entropy';
                end
                savefig(fig,fullfile(path_figures,[name '.fig'])); exportgraphics(fig,fullfile(path_figures,[name '.png']),'Resolution',200)
            end
        end
        close all
    end
end


%% BLOCK 5 - R-READY STATISTICAL EXPORTS

% Meter-resolved coordination/RQA and frequency-landscape similarity are
% exported separately after within-cell repetition averaging.
if run_blocks(5)
    component_tables = cell(ncomponents,1);
    similarity_tables = cell(ncomponents,1);
    for componenti = 1:ncomponents
        which_comp = components(componenti);
        C = load(fullfile(path_spatial,['Component_' num2str(which_comp)], ...
            ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' num2str(which_comp) '.mat']));
        P = load(fullfile(path_rqa,['Component_' num2str(which_comp)], ...
            ['FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#' num2str(which_comp) '.mat']));
        joint_valid = C.validTrialMask & P.validTrialMask;
        expanded_mask = repmat(reshape(joint_valid,nparticipants,nconds,1,ntrials),1,1,nmeters,1);
        mirror_data = C.MIRROR; mirror_data(~expanded_mask) = NaN;
        mirror_mean = mean(mirror_data,4,'omitnan');
        phase_means = struct(); coverage_means = struct();
        for fieldi = 1:numel(metric_fields)
            field = metric_fields{fieldi}; data = P.PhaseRQA.output.(field); data(~expanded_mask) = NaN;
            phase_means.(field) = mean(data,4,'omitnan');
        end
        for fieldi = 1:numel(coverage_fields)
            field = coverage_fields{fieldi}; data = P.PhaseRQA.coverage.(field); data(~expanded_mask) = NaN;
            coverage_means.(field) = mean(data,4,'omitnan');
        end
        n_repetitions = sum(joint_valid,3); valid_cell = n_repetitions > 0;
        nrows_export = nnz(valid_cell)*nmeters;
        Participant = strings(nrows_export,1); Instruction = strings(nrows_export,1);
        Complexity = strings(nrows_export,1); Version = zeros(nrows_export,1); Movement = zeros(nrows_export,1);
        Condition = zeros(nrows_export,1); Meter = strings(nrows_export,1); MeterLevel = zeros(nrows_export,1);
        Component = repmat(which_comp,nrows_export,1); NRepetitions = zeros(nrows_export,1); Mirror = nan(nrows_export,1);
        RR_Phase = nan(nrows_export,1); L_Phase = nan(nrows_export,1); DET_Phase = nan(nrows_export,1);
        ENTR_Phase = nan(nrows_export,1); TT_Phase = nan(nrows_export,1); LAM_Phase = nan(nrows_export,1);
        Vmax_Phase = nan(nrows_export,1); DIV_Phase = nan(nrows_export,1);
        ValidSamples_Phase = nan(nrows_export,1); ExcludedSamples_Phase = nan(nrows_export,1);
        EligiblePairs_Phase = nan(nrows_export,1); EligiblePairFraction_Phase = nan(nrows_export,1);
        row = 0;
        for participanti = 1:nparticipants
            for condi = 1:nconds
                if ~valid_cell(participanti,condi); continue; end
                for metri = 1:nmeters
                    row = row+1; Participant(row) = participantIds(participanti);
                    Instruction(row) = designTable.Instruction(condi); Complexity(row) = designTable.Complexity(condi);
                    Version(row) = designTable.Version(condi); Movement(row) = designTable.Movement(condi);
                    Condition(row) = designTable.ConditionIndex(condi); Meter(row) = "M"+string(metri); MeterLevel(row) = meter(metri);
                    NRepetitions(row) = n_repetitions(participanti,condi); Mirror(row) = mirror_mean(participanti,condi,metri);
                    RR_Phase(row) = phase_means.RR(participanti,condi,metri); L_Phase(row) = phase_means.L(participanti,condi,metri);
                    DET_Phase(row) = phase_means.DET(participanti,condi,metri); ENTR_Phase(row) = phase_means.ENTR(participanti,condi,metri);
                    TT_Phase(row) = phase_means.TT(participanti,condi,metri); LAM_Phase(row) = phase_means.LAM(participanti,condi,metri);
                    Vmax_Phase(row) = phase_means.Vmax(participanti,condi,metri); DIV_Phase(row) = phase_means.DIV(participanti,condi,metri);
                    ValidSamples_Phase(row) = coverage_means.ValidSampleCount(participanti,condi,metri);
                    ExcludedSamples_Phase(row) = coverage_means.ExcludedSampleCount(participanti,condi,metri);
                    EligiblePairs_Phase(row) = coverage_means.EligiblePairCount(participanti,condi,metri);
                    EligiblePairFraction_Phase(row) = coverage_means.EligiblePairFraction(participanti,condi,metri);
                end
            end
        end
        component_tables{componenti} = table(Participant,Instruction,Complexity,Version,Movement,Condition, ...
            Meter,MeterLevel,Component,NRepetitions,Mirror,RR_Phase,L_Phase,DET_Phase,ENTR_Phase, ...
            TT_Phase,LAM_Phase,Vmax_Phase,DIV_Phase,ValidSamples_Phase,ExcludedSamples_Phase, ...
            EligiblePairs_Phase,EligiblePairFraction_Phase);
        writetable(component_tables{componenti},fullfile(path_statistics,['OUT2R_Comp#' num2str(which_comp) '.csv']))
        if write_xlsx; writetable(component_tables{componenti},fullfile(path_statistics,['OUT2R_Comp#' num2str(which_comp) '.xlsx'])); end

        component_similarity = C.LANDSCAPE_SIMILARITY_COMP; component_similarity(~C.validTrialMask) = NaN;
        entropy_similarity = C.LANDSCAPE_SIMILARITY_ENTROPY; entropy_similarity(~C.validTrialMask) = NaN;
        component_similarity = mean(component_similarity,3,'omitnan');
        entropy_similarity = mean(entropy_similarity,3,'omitnan');
        n_repetitions = sum(C.validTrialMask,3); valid_cell = n_repetitions > 0; nrows_similarity = nnz(valid_cell);
        Participant = strings(nrows_similarity,1); Instruction = strings(nrows_similarity,1);
        Complexity = strings(nrows_similarity,1); Version = zeros(nrows_similarity,1); Movement = zeros(nrows_similarity,1);
        Condition = zeros(nrows_similarity,1); Component = repmat(which_comp,nrows_similarity,1);
        NRepetitions = zeros(nrows_similarity,1); LandscapeSimilarityComponent = nan(nrows_similarity,1);
        LandscapeSimilarityEntropy = nan(nrows_similarity,1); row = 0;
        for participanti = 1:nparticipants
            for condi = 1:nconds
                if ~valid_cell(participanti,condi); continue; end
                row = row+1; Participant(row) = participantIds(participanti);
                Instruction(row) = designTable.Instruction(condi); Complexity(row) = designTable.Complexity(condi);
                Version(row) = designTable.Version(condi); Movement(row) = designTable.Movement(condi);
                Condition(row) = designTable.ConditionIndex(condi); NRepetitions(row) = n_repetitions(participanti,condi);
                LandscapeSimilarityComponent(row) = component_similarity(participanti,condi);
                LandscapeSimilarityEntropy(row) = entropy_similarity(participanti,condi);
            end
        end
        similarity_tables{componenti} = table(Participant,Instruction,Complexity,Version,Movement,Condition, ...
            Component,NRepetitions,LandscapeSimilarityComponent,LandscapeSimilarityEntropy);
    end
    statisticsTable = vertcat(component_tables{:});
    landscapeSimilarityTable = vertcat(similarity_tables{:});
    writetable(statisticsTable,fullfile(path_statistics,'OUT2R_AllComponents.csv'))
    writetable(landscapeSimilarityTable,fullfile(path_statistics,'OUT2R_LandscapeSimilarity.csv'))
    fprintf('BLOCK 5 exported %d meter-resolved and %d similarity rows.\n', ...
        height(statisticsTable),height(landscapeSimilarityTable))
end


%% PARTICIPANT METRIC-PROMINENCE MODULE

% This focused module reads the existing core FREQ outputs and never
% recomputes network estimation. Each requested metric level is normalized
% by Network 1's mean prominence at all nonmetric frequencies. The global
% measure averages every available beat-related level across the spectrum
% (beat/4, beat/2, beat, beat x 2, x 3, and x 4) before the same normalization.
if run_metric_prominence
    participant_role = 2;
    rawProminenceTrial = nan(nparticipants,nconds,nmeters,ntrials);
    nonmetricBaselineTrial = nan(nparticipants,nconds,ntrials);
    metricProminenceRatioTrial = nan(nparticipants,nconds,nmeters,ntrials);
    globalMetricMeanTrial = nan(nparticipants,nconds,ntrials);
    globalMetricProminenceRatioTrial = nan(nparticipants,nconds,ntrials);
    prominenceFrequencyHz = nan(1,nmeters);
    globalMetricFrequencyHz = nan(1,numel(global_metric_levels));
    fprintf('\nMETRIC PROMINENCE: reading %d existing core outputs...\n',height(analysisRows))
    for analysisi = 1:height(analysisRows)
        S = load(analysisRows.CoreFile(analysisi),'FREQ');
        FREQ = S.FREQ;
        participanti = analysisRows.ParticipantIndex(analysisi);
        condi = analysisRows.ConditionIndex(analysisi);
        repetitioni = analysisRows.RepetitionIndex(analysisi);
        participant_grid = FREQ.frex_norm(:,participant_role);
        global_metric_indices = nan(size(global_metric_levels));
        for globali = 1:numel(global_metric_levels)
            [distance,global_metric_indices(globali)] = min(abs( ...
                participant_grid-global_metric_levels(globali)));
            assert(distance <= sqrt(eps), ...
                'The participant frequency grid does not contain a global metric level.');
            realized_frequency = FREQ.frex(global_metric_indices(globali),participant_role);
            if isnan(globalMetricFrequencyHz(globali))
                globalMetricFrequencyHz(globali) = realized_frequency;
            else
                assert(abs(realized_frequency-globalMetricFrequencyHz(globali)) <= sqrt(eps), ...
                    'A global metric frequency differs across core outputs.');
            end
        end
        nonmetric_indices = setdiff(1:numel(participant_grid),global_metric_indices);
        assert(~isempty(nonmetric_indices), ...
            'At least one nonmetric frequency is required for normalization.');
        landscape = FREQ.evals(prominence_component,:,participant_role);
        assert(all(isfinite(landscape)) && all(landscape >= 0 & landscape <= 100), ...
            'Participant network landscape must contain finite percentages.');
        nonmetric_baseline = mean(landscape(nonmetric_indices));
        assert(isfinite(nonmetric_baseline) && nonmetric_baseline > 0, ...
            'The nonmetric baseline must be finite and positive.');
        global_metric_mean = mean(landscape(global_metric_indices));
        nonmetricBaselineTrial(participanti,condi,repetitioni) = nonmetric_baseline;
        globalMetricMeanTrial(participanti,condi,repetitioni) = global_metric_mean;
        globalMetricProminenceRatioTrial(participanti,condi,repetitioni) = ...
            global_metric_mean/nonmetric_baseline;
        for metri = 1:nmeters
            [meter_distance,meter_index] = min(abs( ...
                participant_grid-meter(metri)));
            assert(meter_distance <= sqrt(eps), ...
                'The participant frequency grid does not contain a requested meter.');
            spectrum_sum = sum(FREQ.evals(:,meter_index,participant_role));
            assert(abs(spectrum_sum-100) <= 1e-3, ...
                'FREQ.evals is not normalized to percentage explained variance.');
            value = landscape(meter_index);
            assert(isfinite(value) && value >= 0 && value <= 100, ...
                'Participant network prominence must be a finite percentage.');
            rawProminenceTrial(participanti,condi,metri,repetitioni) = value;
            metricProminenceRatioTrial(participanti,condi,metri,repetitioni) = ...
                value/nonmetric_baseline;
            realized_frequency = FREQ.frex(meter_index,participant_role);
            if isnan(prominenceFrequencyHz(metri))
                prominenceFrequencyHz(metri) = realized_frequency;
            else
                assert(abs(realized_frequency-prominenceFrequencyHz(metri)) <= sqrt(eps), ...
                    'A metric frequency differs across core outputs.');
            end
        end
    end

    rawProminenceParticipant = mean(rawProminenceTrial,4,'omitnan');
    nonmetricBaselineParticipant = mean(nonmetricBaselineTrial,3,'omitnan');
    metricProminenceRatioParticipant = mean(metricProminenceRatioTrial,4,'omitnan');
    prominenceNRepetitions = sum(isfinite(metricProminenceRatioTrial),4);
    valid_cell = prominenceNRepetitions > 0 & ...
        isfinite(metricProminenceRatioParticipant);
    nrows_prominence = nnz(valid_cell);
    Participant = strings(nrows_prominence,1); Instruction = strings(nrows_prominence,1);
    Complexity = strings(nrows_prominence,1); Version = zeros(nrows_prominence,1);
    Movement = zeros(nrows_prominence,1); Condition = zeros(nrows_prominence,1);
    Meter = strings(nrows_prominence,1); MeterLevel = zeros(nrows_prominence,1);
    Component = repmat(prominence_component,nrows_prominence,1);
    NRepetitions = zeros(nrows_prominence,1); FrequencyHz = nan(nrows_prominence,1);
    RawProminencePercent = nan(nrows_prominence,1);
    NonMetricBaselinePercent = nan(nrows_prominence,1);
    MetricProminenceRatio = nan(nrows_prominence,1);
    LogMetricProminence = nan(nrows_prominence,1); row = 0;
    for participanti = 1:nparticipants
        for condi = 1:nconds
            for metri = 1:nmeters
                if ~valid_cell(participanti,condi,metri); continue; end
                row = row+1; Participant(row) = participantIds(participanti);
                Instruction(row) = designTable.Instruction(condi);
                Complexity(row) = designTable.Complexity(condi);
                Version(row) = designTable.Version(condi);
                Movement(row) = designTable.Movement(condi);
                Condition(row) = designTable.ConditionIndex(condi);
                Meter(row) = "M"+string(metri); MeterLevel(row) = meter(metri);
                NRepetitions(row) = prominenceNRepetitions(participanti,condi,metri);
                FrequencyHz(row) = prominenceFrequencyHz(metri);
                RawProminencePercent(row) = rawProminenceParticipant(participanti,condi,metri);
                NonMetricBaselinePercent(row) = nonmetricBaselineParticipant(participanti,condi);
                MetricProminenceRatio(row) = ...
                    metricProminenceRatioParticipant(participanti,condi,metri);
                LogMetricProminence(row) = log(MetricProminenceRatio(row));
            end
        end
    end
    prominenceTable = table(Participant,Instruction,Complexity,Version,Movement, ...
        Condition,Meter,MeterLevel,Component,NRepetitions,FrequencyHz, ...
        RawProminencePercent,NonMetricBaselinePercent,MetricProminenceRatio, ...
        LogMetricProminence);
    writetable(prominenceTable,fullfile(path_statistics,'OUT2R_NetworkProminence.csv'))
    if write_xlsx
        writetable(prominenceTable,fullfile(path_statistics,'OUT2R_NetworkProminence.xlsx'))
    end
    globalMetricMeanParticipant = mean(globalMetricMeanTrial,3,'omitnan');
    globalMetricProminenceRatioParticipant = mean( ...
        globalMetricProminenceRatioTrial,3,'omitnan');
    globalMetricNRepetitions = sum(isfinite(globalMetricProminenceRatioTrial),3);
    valid_global = globalMetricNRepetitions > 0 & ...
        isfinite(globalMetricProminenceRatioParticipant);
    nrows_global = nnz(valid_global);
    Participant = strings(nrows_global,1); Instruction = strings(nrows_global,1);
    Complexity = strings(nrows_global,1); Version = zeros(nrows_global,1);
    Movement = zeros(nrows_global,1); Condition = zeros(nrows_global,1);
    Component = repmat(prominence_component,nrows_global,1);
    NRepetitions = zeros(nrows_global,1);
    GlobalMetricMeanPercent = nan(nrows_global,1);
    NonMetricBaselinePercent = nan(nrows_global,1);
    GlobalMetricProminenceRatio = nan(nrows_global,1);
    LogGlobalMetricProminence = nan(nrows_global,1); row = 0;
    for participanti = 1:nparticipants
        for condi = 1:nconds
            if ~valid_global(participanti,condi); continue; end
            row = row+1; Participant(row) = participantIds(participanti);
            Instruction(row) = designTable.Instruction(condi);
            Complexity(row) = designTable.Complexity(condi);
            Version(row) = designTable.Version(condi);
            Movement(row) = designTable.Movement(condi);
            Condition(row) = designTable.ConditionIndex(condi);
            NRepetitions(row) = globalMetricNRepetitions(participanti,condi);
            GlobalMetricMeanPercent(row) = globalMetricMeanParticipant(participanti,condi);
            NonMetricBaselinePercent(row) = nonmetricBaselineParticipant(participanti,condi);
            GlobalMetricProminenceRatio(row) = ...
                globalMetricProminenceRatioParticipant(participanti,condi);
            LogGlobalMetricProminence(row) = log(GlobalMetricProminenceRatio(row));
        end
    end
    globalProminenceTable = table(Participant,Instruction,Complexity,Version, ...
        Movement,Condition,Component,NRepetitions,GlobalMetricMeanPercent, ...
        NonMetricBaselinePercent,GlobalMetricProminenceRatio, ...
        LogGlobalMetricProminence);
    writetable(globalProminenceTable,fullfile(path_statistics, ...
        'OUT2R_GlobalMetricProminence.csv'))
    if write_xlsx
        writetable(globalProminenceTable,fullfile(path_statistics, ...
            'OUT2R_GlobalMetricProminence.xlsx'))
    end
    save(fullfile(path_metric_prominence,'FREQNESS_ParticipantMetricProminence.mat'), ...
        'rawProminenceTrial','rawProminenceParticipant', ...
        'nonmetricBaselineTrial','nonmetricBaselineParticipant', ...
        'metricProminenceRatioTrial','metricProminenceRatioParticipant', ...
        'globalMetricMeanTrial','globalMetricMeanParticipant', ...
        'globalMetricProminenceRatioTrial','globalMetricProminenceRatioParticipant', ...
        'prominenceNRepetitions','globalMetricNRepetitions','prominenceTable', ...
        'globalProminenceTable','prominenceFrequencyHz','globalMetricFrequencyHz', ...
        'prominence_component','meter','global_metric_levels','designTable', ...
        'participantIds','-v7.3')

    if vis_flag
        instruction_levels = ["obs" "mir"];
        instruction_names = ["Observation" "Imitation"];
        complexity_levels = ["low" "medium" "high"];
        instruction_colors = lines(numel(instruction_levels));
        fig = figure('Visible',figure_visibility,'Color','w');
        tiledlayout(2,nmeters,'TileSpacing','compact','Padding','compact');
        for movementi = 1:2
            for metri = 1:nmeters
                nexttile; hold on
                for instructioni = 1:numel(instruction_levels)
                    participant_complexity = nan(nparticipants,numel(complexity_levels));
                    for complexityi = 1:numel(complexity_levels)
                        conditions = find( ...
                            designTable.Instruction == instruction_levels(instructioni) & ...
                            designTable.Complexity == complexity_levels(complexityi) & ...
                            designTable.Movement == movementi);
                        participant_complexity(:,complexityi) = mean( ...
                            metricProminenceRatioParticipant(:,conditions,metri),2,'omitnan');
                    end
                    n = sum(isfinite(participant_complexity),1);
                    mu = mean(participant_complexity,1,'omitnan');
                    se = std(participant_complexity,0,1,'omitnan')./sqrt(max(n,1));
                    errorbar(1:numel(complexity_levels),mu,se,'-o', ...
                        'Color',instruction_colors(instructioni,:), ...
                        'LineWidth',1.5,'MarkerFaceColor',instruction_colors(instructioni,:))
                end
                xticks(1:numel(complexity_levels)); xticklabels(complexity_levels)
                yline(1,':','Nonmetric baseline','HandleVisibility','off')
                xlabel('Stimulus complexity'); ylabel('Metric / nonmetric prominence')
                title(sprintf('Movement %d, %.2g x beat',movementi,meter(metri))); grid on
                if movementi == 1 && metri == 1
                    legend(instruction_names,'Location','best')
                end
            end
        end
        sgtitle(sprintf('Participant Network %d normalized metric prominence',prominence_component))
        savefig(fig,fullfile(path_metric_prominence,'NetworkProminence_Complexity_Participants.fig'))
        exportgraphics(fig,fullfile(path_metric_prominence, ...
            'NetworkProminence_Complexity_Participants.png'),'Resolution',200)
    end
    fprintf(['METRIC PROMINENCE exported %d participant-condition-meter rows ' ...
        'and %d global rows.\n'],height(prominenceTable),height(globalProminenceTable))
end


%% BLOCK 6 - MIXED-EFFECTS MODELS IN R

if run_blocks(6)
    statistics_script = fullfile(path_study,'EmpaticMirroring_Stats.R');
    statistics_input = fullfile(path_statistics,'OUT2R_AllComponents.csv');
    similarity_input = fullfile(path_statistics,'OUT2R_LandscapeSimilarity.csv');
    prominence_input = fullfile(path_statistics,'OUT2R_NetworkProminence.csv');
    global_prominence_input = fullfile(path_statistics,'OUT2R_GlobalMetricProminence.csv');
    statistics_output = fullfile(path_output,'06_Statistics_Results');
    [R_status,R_output] = system(sprintf([ ...
        'Rscript "%s" --overwrite --input="%s" ' ...
        '--similarity-input="%s" --prominence-input="%s" ' ...
        '--global-prominence-input="%s" ' ...
        '--output="%s"'],statistics_script,statistics_input, ...
        similarity_input,prominence_input,global_prominence_input,statistics_output));
    fprintf('%s\n',R_output)
    assert(R_status == 0,'R statistical modelling failed.')
end


%% VALIDATION - NUMERICAL PARITY

% An optional reference folder can be supplied for a full refactor audit.
% It is deliberately external to the repository and never required normally.
reference_path = string(getenv('EMPATIC_MIRRORING_PARITY_REFERENCE'));
if strlength(reference_path) > 0 && isfolder(reference_path)
    AuditTarget = strings(0,1); ExactlyEqual = false(0,1); MaximumAbsoluteDifference = nan(0,1);
    for componenti = 1:ncomponents
        which_comp = components(componenti);
        current_coordination = load(fullfile(path_spatial,['Component_' num2str(which_comp)], ...
            ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' num2str(which_comp) '.mat']));
        reference_coordination = load(fullfile(reference_path,'03_Interaction', ...
            ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' num2str(which_comp) '.mat']));
        fields = {'MIRROR','LANDSCAPE_SIMILARITY_COMP','LANDSCAPE_SIMILARITY_ENTROPY','validTrialMask'};
        for fieldi = 1:numel(fields)
            field = fields{fieldi}; left = current_coordination.(field); right = reference_coordination.(field);
            AuditTarget(end+1,1) = "Block3 coordination C"+which_comp+" "+field;
            ExactlyEqual(end+1,1) = isequaln(left,right);
            difference = abs(double(left)-double(right)); MaximumAbsoluteDifference(end+1,1) = max(difference(:),[],'omitnan');
        end
        current_rqa = load(fullfile(path_rqa,['Component_' num2str(which_comp)], ...
            ['FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#' num2str(which_comp) '.mat']));
        reference_rqa = load(fullfile(reference_path,'03_Interaction', ...
            ['FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#' num2str(which_comp) '.mat']));
        for fieldi = 1:numel(metric_fields)
            field = metric_fields{fieldi}; left = current_rqa.PhaseRQA.output.(field); right = reference_rqa.PhaseRQA.output.(field);
            AuditTarget(end+1,1) = "Block3 RQA C"+which_comp+" "+field; ExactlyEqual(end+1,1) = isequaln(left,right);
            difference = abs(double(left)-double(right)); MaximumAbsoluteDifference(end+1,1) = max(difference(:),[],'omitnan');
        end
        for fieldi = 1:numel(coverage_fields)
            field = coverage_fields{fieldi}; left = current_rqa.PhaseRQA.coverage.(field); right = reference_rqa.PhaseRQA.coverage.(field);
            AuditTarget(end+1,1) = "Block3 coverage C"+which_comp+" "+field; ExactlyEqual(end+1,1) = isequaln(left,right);
            difference = abs(double(left)-double(right)); MaximumAbsoluteDifference(end+1,1) = max(difference(:),[],'omitnan');
        end
    end
    current_group = load(fullfile(path_group,'FREQNESS_GroupAnalysisSummary.mat'));
    reference_group = load(fullfile(reference_path,'04_Group','FREQNESS_GroupAnalysisSummary.mat'));
    fields = {'avg_evals_teacher','avg_evals_participant','sem_evals_participant','avg_pats','sem_pats', ...
        'avg_ED_teacher','avg_ED_participant','sem_ED_participant','avg_pattern_correlation','sem_pattern_correlation','participantCounts'};
    for fieldi = 1:numel(fields)
        field = fields{fieldi}; left = current_group.(field); right = reference_group.(field);
        AuditTarget(end+1,1) = "Block4 "+field; ExactlyEqual(end+1,1) = isequaln(left,right);
        difference = abs(double(left)-double(right)); MaximumAbsoluteDifference(end+1,1) = max(difference(:),[],'omitnan');
    end
    csv_names = ["OUT2R_AllComponents.csv" "OUT2R_Comp#1.csv" "OUT2R_Comp#2.csv" "OUT2R_LandscapeSimilarity.csv"];
    for filei = 1:numel(csv_names)
        left = readtable(fullfile(path_statistics,csv_names(filei)),'TextType','string','VariableNamingRule','preserve');
        right = readtable(fullfile(reference_path,'05_Statistics_R',csv_names(filei)),'TextType','string','VariableNamingRule','preserve');
        AuditTarget(end+1,1) = "Block5 "+csv_names(filei); ExactlyEqual(end+1,1) = isequaln(left,right);
        MaximumAbsoluteDifference(end+1,1) = double(~ExactlyEqual(end));
    end
    parityAudit = table(AuditTarget,ExactlyEqual,MaximumAbsoluteDifference);
    validation_path = fullfile(path_output,'09_CleanupValidation');
    if ~isfolder(validation_path); mkdir(validation_path); end
    writetable(parityAudit,fullfile(validation_path,'FlattenedPipeline_NumericalParity.csv'))
    disp(parityAudit)
    assert(all(parityAudit.ExactlyEqual),'The flattened pipeline does not exactly reproduce the reference run.')
end

fprintf('\nEmpatic Mirroring pipeline complete.\n')
fprintf('Artificial dyads available: %d\n',nnz(ismember(DyadStatus,["created" "existing"])))
if exist('statisticsTable','var')
    fprintf('Meter-resolved statistical rows: %d\n',height(statisticsTable))
    fprintf('Landscape-similarity statistical rows: %d\n',height(landscapeSimilarityTable))
end
