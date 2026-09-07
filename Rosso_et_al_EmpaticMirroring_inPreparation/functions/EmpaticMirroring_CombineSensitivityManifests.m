function [combinedManifest,summary] = ...
    EmpaticMirroring_CombineSensitivityManifests( ...
    primaryManifest,recoveredManifest,statusField,fileField,outputFile)
%EMPATICMIRRORING_COMBINESENSITIVITYMANIFESTS Join available disjoint cohorts.
%   Only rows with a successful status and an existing output file enter the
%   combined sensitivity manifest. Primary paths are referenced in place;
%   primary files are neither copied nor overwritten.

arguments
    primaryManifest table
    recoveredManifest table
    statusField (1,1) string
    fileField (1,1) string
    outputFile (1,1) string
end

required = {'ParticipantFile','Subject','TrialIndex','Instruction', ...
    'Complexity','Version','Movement','DyadFile',char(statusField), ...
    char(fileField)};
if ~all(ismember(required,primaryManifest.Properties.VariableNames)) || ...
        ~all(ismember(required,recoveredManifest.Properties.VariableNames))
    error('EmpaticMirroring:SensitivityManifestFields', ...
        'Primary and recovered manifests lack required analysis fields.');
end

primaryAvailable = availableRows(primaryManifest,statusField,fileField);
recoveredAvailable = availableRows(recoveredManifest,statusField,fileField);
primary = primaryManifest(primaryAvailable,:);
recovered = recoveredManifest(recoveredAvailable,:);

commonVariables = primary.Properties.VariableNames(ismember( ...
    primary.Properties.VariableNames, ...
    recovered.Properties.VariableNames));
primary = primary(:,commonVariables);
recovered = recovered(:,commonVariables);
[primary,recovered] = normalizeCommonTypes(primary,recovered);
primary.AnalysisCohort = repmat("primary retained",height(primary),1);
recovered.AnalysisCohort = repmat( ...
    "recovered sensitivity",height(recovered),1);
combinedManifest = [primary; recovered];

participantFiles = string(combinedManifest.ParticipantFile);
if numel(unique(participantFiles)) ~= numel(participantFiles)
    error('EmpaticMirroring:SensitivityManifestOverlap', ...
        ['Primary and recovered manifests overlap. Recovery must add ' ...
         'recordings without replacing primary observations.']);
end

subjectNumber = str2double(string(combinedManifest.Subject));
trialNumber = double(combinedManifest.TrialIndex);
[~,order] = sortrows([subjectNumber trialNumber],[1 2]);
combinedManifest = combinedManifest(order,:);

outputFolder = fileparts(outputFile);
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(combinedManifest,outputFile);

summary = struct( ...
    'primaryCount',height(primary), ...
    'recoveredCount',height(recovered), ...
    'combinedCount',height(combinedManifest), ...
    'participantCount',numel(unique( ...
        string(combinedManifest.Subject))), ...
    'outputFile',outputFile);
fprintf(['Combined %s manifest: %d primary + %d recovered = %d ' ...
    'available recordings.\n'],statusField,summary.primaryCount, ...
    summary.recoveredCount,summary.combinedCount);

end


function mask = availableRows(manifest,statusField,fileField)

status = string(manifest.(statusField));
files = string(manifest.(fileField));
mask = ismember(status,["created","existing","available"]) & ...
    strlength(files) > 0;
for rowi = find(mask(:))'
    mask(rowi) = isfile(files(rowi));
end

end


function [first,second] = normalizeCommonTypes(first,second)

stringVariables = {'ParticipantFile','TeacherFile','Subject', ...
    'Instruction','Complexity','PairingKey','ParticipantQCStatus', ...
    'TeacherQCStatus','PairingStatus','DyadFile','DyadStatus', ...
    'DyadErrorMessage','CoreFile','CoreStatus','CoreErrorMessage', ...
    'LandscapeFile','LandscapeStatus','LandscapeErrorMessage'};
for variable = stringVariables
    name = char(variable);
    if ismember(name,first.Properties.VariableNames)
        first.(name) = string(first.(name));
        second.(name) = string(second.(name));
    end
end
if ismember('ReadyForAlignment',first.Properties.VariableNames)
    first.ReadyForAlignment = logical(first.ReadyForAlignment);
    second.ReadyForAlignment = logical(second.ReadyForAlignment);
end

end
