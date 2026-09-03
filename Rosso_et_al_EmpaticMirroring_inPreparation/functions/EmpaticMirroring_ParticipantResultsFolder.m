function resultsFolder = EmpaticMirroring_ParticipantResultsFolder( ...
    participantFile,config)
%EMPATICMIRRORING_PARTICIPANTRESULTSFOLDER Route one participant's outputs.
%   Trial inputs and bad-sample lists are stored here; the future core FREQ
%   output must use this same participant-specific folder. The folder lives
%   below outputs/participants so generated results never alter raw data.

participantFile = char(participantFile);
[matFolder,~,~] = fileparts(participantFile);
participantFolder = fileparts(matFolder);
dataRoot = char(config.paths.dataRoot);

if isempty(participantFolder) || ...
        ~startsWith([participantFolder filesep],[dataRoot filesep])
    error('EmpaticMirroring:ParticipantOutputPath', ...
        'Participant file is not located below the configured data root.');
end

[~,subject] = fileparts(participantFolder);
if isempty(regexp(subject,'^\d{3}$','once'))
    error('EmpaticMirroring:ParticipantOutputSubject', ...
        'Cannot derive a canonical three-digit subject ID from %s.', ...
        participantFolder);
end

resultsFolder = fullfile(config.paths.participantsOutputRoot,subject);

end
