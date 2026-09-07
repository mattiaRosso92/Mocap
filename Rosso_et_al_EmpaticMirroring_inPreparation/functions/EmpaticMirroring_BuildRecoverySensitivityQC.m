function [sensitivityQC,recoveryAudit,summary] = ...
    EmpaticMirroring_BuildRecoverySensitivityQC(frameQC,config)
%EMPATICMIRRORING_BUILDRECOVERYSENSITIVITYQC Audit annotated participants.
%   The folder annotation is the only waived exclusion. A recording is
%   admitted only when every objective primary-pipeline criterion still
%   passes. Reconstructed samples retain their original bad-sample masks.

required = {'File','Subject','Role','FolderStatus','LoadStatus', ...
    'NameStatus','MarkerStatus','MarkerPolicyStatus','SampleRate', ...
    'LengthStatus','RetainedBadTimepointCount','RequiredFrames', ...
    'OverallStatus','ExcludeRecording','ExclusionReasons', ...
    'ReadyForAlignment'};
if ~istable(frameQC) || ...
        ~all(ismember(required,frameQC.Properties.VariableNames))
    error('EmpaticMirroring:RecoveryQCInput', ...
        'frameQC is missing fields required by the recovery audit.');
end
if ~isfield(config,'sensitivity') || ...
        ~all(isfield(config.sensitivity,{'subjects', ...
        'subject_annotations'})) || ...
        numel(config.sensitivity.subjects) ~= ...
        numel(config.sensitivity.subject_annotations)
    error('EmpaticMirroring:RecoveryQCConfiguration', ...
        'Recovery subjects and annotations must be paired.');
end

subjects = normalizeSubjects(config.sensitivity.subjects);
frameQC.Subject = normalizeSubjects(frameQC.Subject);
frameQC.Subject(string(frameQC.Role) == "teacher") = ...
    string(config.naming.teacherFolder);
participantMask = string(frameQC.Role) == "participant";
candidateMask = participantMask & ...
    ismember(normalizeSubjects(frameQC.Subject),subjects);
recoveryAudit = frameQC(candidateMask,:);
if isempty(recoveryAudit)
    error('EmpaticMirroring:RecoveryQCMissingCandidates', ...
        'No configured sensitivity participants were found in frameQC.');
end

nRows = height(recoveryAudit);
annotation = strings(nRows,1);
objectiveExclusionReasons = strings(nRows,1);
recoverForSensitivity = false(nRows,1);
decision = strings(nRows,1);
for rowi = 1:nRows
    subjectIndex = find(subjects == normalizeSubjects( ...
        recoveryAudit.Subject(rowi)),1);
    annotation(rowi) = string( ...
        config.sensitivity.subject_annotations(subjectIndex));
    objectiveExclusionReasons(rowi) = objectiveReasons( ...
        recoveryAudit(rowi,:),config);
    recoverForSensitivity(rowi) = ...
        string(recoveryAudit.FolderStatus(rowi)) == ...
        "annotated subject folder" && ...
        strlength(objectiveExclusionReasons(rowi)) == 0;
    if recoverForSensitivity(rowi)
        decision(rowi) = "recover";
    else
        decision(rowi) = "remain excluded";
    end
end

recoveryAudit.SubjectAnnotation = annotation;
recoveryAudit.PrimaryExclusionReasons = string( ...
    recoveryAudit.ExclusionReasons);
recoveryAudit.ObjectiveExclusionReasons = objectiveExclusionReasons;
recoveryAudit.RecoverForSensitivity = recoverForSensitivity;
recoveryAudit.SensitivityDecision = decision;

% Retain all model rows and all candidate rows in the sensitivity QC table.
% Rejected candidates remain annotated and therefore cannot enter the dyad
% manifest. Only accepted copies receive the explicit folder-status waiver.
teacherMask = string(frameQC.Role) == "teacher";
sensitivityQC = frameQC(teacherMask | candidateMask,:);
isCandidateCopy = string(sensitivityQC.Role) == "participant";
candidateFiles = string(recoveryAudit.File(recoverForSensitivity));
isRecoveredCopy = isCandidateCopy & ...
    ismember(string(sensitivityQC.File),candidateFiles);
sensitivityQC.FolderStatus(isRecoveredCopy) = "ok";
sensitivityQC.OverallStatus(isRecoveredCopy) = ...
    "recovered for sensitivity analysis";
sensitivityQC.ExcludeRecording(isRecoveredCopy) = false;
sensitivityQC.ExclusionReasons(isRecoveredCopy) = "";
sensitivityQC.ReadyForAlignment(isRecoveredCopy) = true;

subjectSummary = buildSubjectSummary(recoveryAudit,subjects,config);
outputRoot = config.paths.qcOutputRoot;
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end
writetable(recoveryAudit,fullfile(outputRoot, ...
    'recovery_recording_audit.csv'));
writetable(subjectSummary,fullfile(outputRoot, ...
    'recovery_participant_summary.csv'));

summary = struct( ...
    'candidateCount',height(recoveryAudit), ...
    'recoveredCount',nnz(recoverForSensitivity), ...
    'remainingExcludedCount',nnz(~recoverForSensitivity), ...
    'participantCount',numel(subjects), ...
    'recoveredParticipantCount',numel(unique( ...
        normalizeSubjects(recoveryAudit.Subject(recoverForSensitivity)))), ...
    'subjectSummary',subjectSummary);

fprintf('\nRECOVERY QC: %d/%d annotated recordings admitted.\n', ...
    summary.recoveredCount,summary.candidateCount);
for rowi = 1:height(subjectSummary)
    fprintf('  participant %s: %d recovered, %d remain excluded (%s)\n', ...
        subjectSummary.Subject(rowi),subjectSummary.Recovered(rowi), ...
        subjectSummary.RemainExcluded(rowi), ...
        subjectSummary.SubjectAnnotation(rowi));
end

end


function reasons = objectiveReasons(row,config)

parts = strings(0,1);
if string(row.LoadStatus) ~= "ok"
    parts(end+1,1) = "load/structure: " + string(row.LoadStatus);
end
if string(row.NameStatus) ~= "ok"
    parts(end+1,1) = "filename: " + string(row.NameStatus);
end
if string(row.MarkerStatus) ~= "ok"
    parts(end+1,1) = "marker layout: " + string(row.MarkerStatus);
end
if string(row.MarkerPolicyStatus) ~= "ok"
    parts(end+1,1) = "marker policy: " + ...
        string(row.MarkerPolicyStatus);
end
if ~isfinite(row.SampleRate) || ...
        abs(row.SampleRate-config.sampling.participantHz) > ...
        eps(max(abs([row.SampleRate config.sampling.participantHz])))
    parts(end+1,1) = "sample rate: expected " + ...
        config.sampling.participantHz + " Hz, found " + row.SampleRate + ...
        " Hz";
end
if string(row.LengthStatus) == "too short"
    parts(end+1,1) = "length: too short for configured window";
elseif ~ismember(string(row.LengthStatus), ...
        ["ok","usable without preferred guard"])
    parts(end+1,1) = "length: " + string(row.LengthStatus);
end
if isfinite(row.RetainedBadTimepointCount) && ...
        isfinite(row.RequiredFrames) && ...
        row.RetainedBadTimepointCount >= row.RequiredFrames-1
    parts(end+1,1) = ...
        "missing data: fewer than two valid covariance samples";
end
if string(row.FolderStatus) ~= "annotated subject folder"
    parts(end+1,1) = "folder is not eligible for the annotation waiver";
end
reasons = strjoin(unique(parts,'stable'),"; ");

end


function summary = buildSubjectSummary(audit,subjects,config)

n = numel(subjects);
CandidateRecordings = zeros(n,1);
Recovered = zeros(n,1);
RemainExcluded = zeros(n,1);
SubjectAnnotation = strings(n,1);
for subjecti = 1:n
    rows = normalizeSubjects(audit.Subject) == subjects(subjecti);
    CandidateRecordings(subjecti) = nnz(rows);
    Recovered(subjecti) = nnz(rows & audit.RecoverForSensitivity);
    RemainExcluded(subjecti) = nnz(rows & ...
        ~audit.RecoverForSensitivity);
    SubjectAnnotation(subjecti) = string( ...
        config.sensitivity.subject_annotations(subjecti));
end
Subject = subjects(:);
summary = table(Subject,SubjectAnnotation,CandidateRecordings, ...
    Recovered,RemainExcluded);

end


function subjects = normalizeSubjects(values)

subjects = string(values(:));
numericValues = str2double(subjects);
numericMask = isfinite(numericValues) & numericValues >= 0 & ...
    numericValues == round(numericValues);
subjects(numericMask) = compose("%03d",numericValues(numericMask));
subjects(~numericMask & ismissing(subjects)) = "";

end
