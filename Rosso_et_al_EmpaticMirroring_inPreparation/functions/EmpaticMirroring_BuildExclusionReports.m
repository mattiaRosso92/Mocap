function reports = EmpaticMirroring_BuildExclusionReports(frameQC,config)
%EMPATICMIRRORING_BUILDEXCLUSIONREPORTS Export auditable QC exclusions.
%   File annotations exclude only that recording; annotated/nonconforming
%   subject folders exclude the participant. Participants with no recording
%   surviving structural, rate, length, and retained-window gap QC are also
%   excluded. Other participants remain available with flagged trials omitted.

outputRoot = config.paths.qcOutputRoot;
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

recordingExclusions = frameQC(frameQC.ExcludeRecording,:);
modelExclusions = recordingExclusions( ...
    recordingExclusions.Role == "teacher",:);

participantRows = frameQC.Role == "participant";
participantData = frameQC(participantRows,:);
subjects = sort(unique(participantData.Subject));
nSubjects = numel(subjects);

sourceFolder = strings(nSubjects,1);
observedRecordingCount = zeros(nSubjects,1);
uniqueTrialIndexCount = zeros(nSubjects,1);
missingTrialIndices = strings(nSubjects,1);
duplicateTrialIndices = strings(nSubjects,1);
annotatedRecordingCount = zeros(nSubjects,1);
gapRecordingCount = zeros(nSubjects,1);
markerPolicyExcludedRecordingCount = zeros(nSubjects,1);
tooShortRecordingCount = zeros(nSubjects,1);
unexpectedRateRecordingCount = zeros(nSubjects,1);
loadOrStructureErrorCount = zeros(nSubjects,1);
excludedRecordingCount = zeros(nSubjects,1);
eligibleRecordingCount = zeros(nSubjects,1);
excludeParticipant = false(nSubjects,1);
participantExclusionReason = strings(nSubjects,1);

for subjectIndex = 1:nSubjects
    rows = participantData.Subject == subjects(subjectIndex);
    subjectQC = participantData(rows,:);
    sourceFolder(subjectIndex) = firstPathComponent( ...
        subjectQC.RelativePath(1));
    observedRecordingCount(subjectIndex) = height(subjectQC);

    trialIndices = subjectQC.TrialIndex(isfinite(subjectQC.TrialIndex));
    uniqueIndices = unique(trialIndices);
    uniqueTrialIndexCount(subjectIndex) = numel(uniqueIndices);
    missing = setdiff((1:48)',uniqueIndices);
    missingTrialIndices(subjectIndex) = joinNumbers(missing);
    duplicateTrialIndices(subjectIndex) = duplicateNumbers(trialIndices);

    annotatedRecordingCount(subjectIndex) = nnz( ...
        subjectQC.NameStatus == "annotated filename");
    if ismember('RetainedHasMissingCoordinates', ...
            subjectQC.Properties.VariableNames)
        gapRecordingCount(subjectIndex) = nnz( ...
            subjectQC.RetainedHasMissingCoordinates);
    else
        gapRecordingCount(subjectIndex) = nnz( ...
            subjectQC.HasMissingCoordinates);
    end
    if ismember('MarkerPolicyStatus', ...
            subjectQC.Properties.VariableNames)
        markerPolicyExcludedRecordingCount(subjectIndex) = nnz( ...
            subjectQC.MarkerPolicyStatus == "long retained-marker gap");
    end
    tooShortRecordingCount(subjectIndex) = nnz( ...
        subjectQC.LengthStatus == "too short");
    unexpectedRateRecordingCount(subjectIndex) = nnz(contains( ...
        subjectQC.ExclusionReasons,"sample rate:"));
    loadOrStructureErrorCount(subjectIndex) = nnz( ...
        subjectQC.LoadStatus ~= "ok");
    excludedRecordingCount(subjectIndex) = nnz( ...
        subjectQC.ExcludeRecording);
    eligibleRecordingCount(subjectIndex) = nnz( ...
        subjectQC.ReadyForAlignment);

    badFolder = any(subjectQC.FolderStatus ~= "ok");
    noEligibleRecordings = eligibleRecordingCount(subjectIndex) == 0;
    excludeParticipant(subjectIndex) = badFolder || noEligibleRecordings;

    reasons = strings(0,1);
    if badFolder
        folderStatuses = unique(subjectQC.FolderStatus( ...
            subjectQC.FolderStatus ~= "ok"),'stable');
        reasons(end+1,1) = "folder '" + sourceFolder(subjectIndex) + ...
            "': " + strjoin(folderStatuses,", "); %#ok<AGROW>
    end
    if noEligibleRecordings
        reasons(end+1,1) = "no recording survives QC"; %#ok<AGROW>
    end
    participantExclusionReason(subjectIndex) = strjoin(reasons,"; ");
end

expectedTrialIndexCount = repmat(48,nSubjects,1);
participantSummary = table(subjects,sourceFolder,expectedTrialIndexCount, ...
    observedRecordingCount,uniqueTrialIndexCount,missingTrialIndices, ...
    duplicateTrialIndices,annotatedRecordingCount,gapRecordingCount, ...
    markerPolicyExcludedRecordingCount, ...
    tooShortRecordingCount,unexpectedRateRecordingCount, ...
    loadOrStructureErrorCount,excludedRecordingCount, ...
    eligibleRecordingCount,excludeParticipant,participantExclusionReason, ...
    'VariableNames',{'Subject','SourceFolder','ExpectedTrialIndexCount', ...
    'ObservedRecordingCount','UniqueTrialIndexCount','MissingTrialIndices', ...
    'DuplicateTrialIndices','AnnotatedRecordingCount', ...
    'GapRecordingCount','MarkerPolicyExcludedRecordingCount', ...
    'TooShortRecordingCount', ...
    'UnexpectedRateRecordingCount','LoadOrStructureErrorCount', ...
    'ExcludedRecordingCount','EligibleRecordingCount', ...
    'ExcludeParticipant','ParticipantExclusionReason'});
participantExclusions = participantSummary( ...
    participantSummary.ExcludeParticipant,:);

writetable(recordingExclusions, ...
    fullfile(outputRoot,'recording_exclusions.csv'));
writetable(modelExclusions,fullfile(outputRoot,'model_exclusions.csv'));
writetable(participantSummary, ...
    fullfile(outputRoot,'participant_qc_summary.csv'));
writetable(participantExclusions, ...
    fullfile(outputRoot,'participant_exclusions.csv'));

reports = struct( ...
    'recordingExclusions',recordingExclusions, ...
    'modelExclusions',modelExclusions, ...
    'participantSummary',participantSummary, ...
    'participantExclusions',participantExclusions);

fprintf(['Exclusion reports: %d recordings excluded; %d/%d participants ' ...
    'excluded entirely; %d model files excluded.\n'], ...
    height(recordingExclusions),height(participantExclusions),nSubjects, ...
    height(modelExclusions));

end


function component = firstPathComponent(relativePath)

parts = split(string(relativePath),filesep);
component = parts(1);

end


function text = joinNumbers(values)

if isempty(values)
    text = "";
else
    text = strjoin(string(values(:)'),",");
end

end


function text = duplicateNumbers(values)

if isempty(values)
    text = "";
    return
end
[uniqueValues,~,group] = unique(values);
counts = accumarray(group,1);
text = joinNumbers(uniqueValues(counts > 1));

end
