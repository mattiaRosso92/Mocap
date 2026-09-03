function dyadManifest = EmpaticMirroring_BuildDyadManifest(frameQC,config)
%EMPATICMIRRORING_BUILDDYADMANIFEST Pair trials with teacher video clips.
%   Pairing ignores observe/imitate condition and uses the shared stimulus
%   identity: intensity, version, and movement.

participants = frameQC(frameQC.Role == "participant",:);
teachers = frameQC(frameQC.Role == "teacher",:);
nParticipants = height(participants);

participantFile = participants.File;
teacherFile = strings(nParticipants,1);
subject = participants.Subject;
trialIndex = participants.TrialIndex;
condition = participants.Condition;
intensity = participants.Intensity;
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
    if participants.NameStatus(rowIndex) ~= "ok"
        pairingStatus(rowIndex) = "invalid participant filename";
        continue
    end

    matches = find(teachers.PairingKey == pairingKey(rowIndex) & ...
        teachers.NameStatus == "ok");
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
    condition,intensity,version,movement,pairingKey,participantFrames, ...
    teacherFrames,participantQCStatus,teacherQCStatus,pairingStatus, ...
    readyForAlignment, ...
    'VariableNames',{'ParticipantFile','TeacherFile','Subject', ...
    'TrialIndex','Condition','Intensity','Version','Movement', ...
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

end
