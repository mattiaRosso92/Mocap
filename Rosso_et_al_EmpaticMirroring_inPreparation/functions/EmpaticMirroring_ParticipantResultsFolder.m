function resultsFolder = EmpaticMirroring_ParticipantResultsFolder( ...
    participantFile,config,subject)
%EMPATICMIRRORING_PARTICIPANTRESULTSFOLDER Route one participant's outputs.
%   Trial inputs and bad-sample lists are stored here; the future core FREQ
%   output must use this same participant-specific folder. The folder lives
%   below outputs/participants so generated results never alter raw data.
%   An optional validated manifest subject supports annotated raw folders in
%   the recovery-sensitivity workflow.

participantFile = char(participantFile);
[matFolder,~,~] = fileparts(participantFile);
participantFolder = fileparts(matFolder);
dataRoot = char(config.paths.dataRoot);

if isempty(participantFolder) || ...
        ~startsWith([participantFolder filesep],[dataRoot filesep])
    error('EmpaticMirroring:ParticipantOutputPath', ...
        'Participant file is not located below the configured data root.');
end

[~,folderSubject] = fileparts(participantFolder);
if nargin < 3 || strlength(string(subject)) == 0
    subject = string(folderSubject);
else
    subject = string(subject);
end
numericSubject = str2double(subject);
if isfinite(numericSubject) && numericSubject >= 0 && ...
        numericSubject == round(numericSubject)
    subject = compose("%03d",numericSubject);
end
if isempty(regexp(subject,'^\d{3}$','once'))
    error('EmpaticMirroring:ParticipantOutputSubject', ...
        'Cannot resolve a canonical three-digit subject ID for %s.', ...
        participantFile);
end

resultsFolder = fullfile(config.paths.participantsOutputRoot,char(subject));

end
