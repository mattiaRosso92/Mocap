function dyadManifest = EmpaticMirroring_BuildDyadManifest(frameQC,config)
%EMPATICMIRRORING_BUILDDYADMANIFEST Pair trials with teacher video clips.
%   Pairing ignores observe/imitate instruction and uses the shared stimulus
%   identity: complexity, version, and movement. The model performed one
%   physical complexity level; low/medium/high identify the music later
%   overlaid on that recording and remain necessary stimulus labels.

participantRows = frameQC.Role == "participant";
teacherRows = frameQC.Role == "teacher";
participantMetadataEligible = participantRows & ...
    frameQC.FolderStatus == "ok" & frameQC.NameStatus == "ok";
teacherMetadataEligible = teacherRows & ...
    frameQC.FolderStatus == "ok" & frameQC.NameStatus == "ok";

% Annotated or nonconforming files/folders remain in frame_count_qc.csv for
% auditability but are intentionally omitted from the analysis manifest.
participants = frameQC(participantMetadataEligible,:);
teachers = frameQC(teacherMetadataEligible,:);
nParticipants = height(participants);

participantFile = participants.File;
teacherFile = strings(nParticipants,1);
subject = participants.Subject;
trialIndex = participants.TrialIndex;
instruction = participants.Instruction;
complexity = participants.Complexity;
version = participants.Version;
movement = participants.Movement;
pairingKey = participants.PairingKey;
participantFrames = participants.NumberFrames;
teacherFrames = nan(nParticipants,1);
participantQCStatus = participants.OverallStatus;
teacherQCStatus = strings(nParticipants,1);
pairingStatus = strings(nParticipants,1);
readyForAlignment = false(nParticipants,1);

for rowIndex = 1:nParticipants
    matches = find(teachers.PairingKey == pairingKey(rowIndex));
    if isempty(matches)
        pairingStatus(rowIndex) = "teacher clip missing";
    elseif numel(matches) > 1
        pairingStatus(rowIndex) = "teacher clip ambiguous";
    else
        teacherRow = matches(1);
        teacherFile(rowIndex) = teachers.File(teacherRow);
        teacherFrames(rowIndex) = teachers.NumberFrames(teacherRow);
        teacherQCStatus(rowIndex) = teachers.OverallStatus(teacherRow);
        pairingStatus(rowIndex) = "matched";
        readyForAlignment(rowIndex) = ...
            participants.ReadyForAlignment(rowIndex) && ...
            teachers.ReadyForAlignment(teacherRow);
    end
end

dyadManifest = table(participantFile,teacherFile,subject,trialIndex, ...
    instruction,complexity,version,movement,pairingKey,participantFrames, ...
    teacherFrames,participantQCStatus,teacherQCStatus,pairingStatus, ...
    readyForAlignment, ...
    'VariableNames',{'ParticipantFile','TeacherFile','Subject', ...
    'TrialIndex','Instruction','Complexity','Version','Movement', ...
    'PairingKey','ParticipantFrames','TeacherFrames', ...
    'ParticipantQCStatus','TeacherQCStatus','PairingStatus', ...
    'ReadyForAlignment'});

if ~isfolder(config.paths.qcOutputRoot)
    mkdir(config.paths.qcOutputRoot);
end
writetable(dyadManifest, ...
    fullfile(config.paths.qcOutputRoot,'artificial_dyad_manifest.csv'));

fprintf('Dyad manifest: %d matched, %d missing, %d ambiguous.\n', ...
    nnz(dyadManifest.PairingStatus == "matched"), ...
    nnz(dyadManifest.PairingStatus == "teacher clip missing"), ...
    nnz(dyadManifest.PairingStatus == "teacher clip ambiguous"));
fprintf('Metadata exclusions: %d participant files, %d teacher files.\n', ...
    nnz(participantRows & ~participantMetadataEligible), ...
    nnz(teacherRows & ~teacherMetadataEligible));

end
