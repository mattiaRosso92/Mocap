function [analysisRows,design] = EmpaticMirroring_IndexAnalysisRows( ...
    dyadManifest,selectedRows)
%EMPATICMIRRORING_INDEXANALYSISROWS Map recordings to the factorial design.
%   The resulting indices mirror the DyadicDance dyad-condition-trial
%   organization: participant replaces dyad, the 24 factorial combinations
%   replace condition, and acquisition order determines only the repetition
%   slot within a participant-condition cell.

required = {'Subject','TrialIndex','Instruction','Complexity', ...
    'Version','Movement'};
if ~istable(dyadManifest) || ...
        ~all(ismember(required,dyadManifest.Properties.VariableNames))
    error('EmpaticMirroring:AnalysisDesignManifest', ...
        ['The manifest must contain Subject, TrialIndex, Instruction, ' ...
        'Complexity, Version, and Movement.']);
end
if ~isnumeric(selectedRows) || ~isvector(selectedRows) || ...
        any(~isfinite(selectedRows)) || any(selectedRows < 1) || ...
        any(selectedRows ~= round(selectedRows)) || ...
        any(selectedRows > height(dyadManifest)) || ...
        numel(unique(selectedRows)) ~= numel(selectedRows)
    error('EmpaticMirroring:AnalysisDesignRows', ...
        'selectedRows must contain unique valid manifest row indices.');
end

selectedRows = selectedRows(:);
analysisRows = dyadManifest(selectedRows,:);
analysisRows.ManifestRow = selectedRows;

instructions = ["mir" "obs"];
complexities = ["low" "medium" "high"];
versions = 1:2;
movements = 1:2;
nconds = numel(instructions)*numel(complexities)* ...
    numel(versions)*numel(movements);

conditionNumber = zeros(nconds,1);
instruction = strings(nconds,1);
complexity = strings(nconds,1);
version = zeros(nconds,1);
movement = zeros(nconds,1);
condi = 0;
for instructioni = 1:numel(instructions)
    for complexityi = 1:numel(complexities)
        for versioni = 1:numel(versions)
            for movementi = 1:numel(movements)
                condi = condi + 1;
                conditionNumber(condi) = condi;
                instruction(condi) = instructions(instructioni);
                complexity(condi) = complexities(complexityi);
                version(condi) = versions(versioni);
                movement(condi) = movements(movementi);
            end
        end
    end
end
designTable = table(conditionNumber,instruction,complexity,version, ...
    movement,'VariableNames',{'ConditionIndex','Instruction', ...
    'Complexity','Version','Movement'});

participantLabel = string(analysisRows.Subject);
numericParticipantLabel = str2double(participantLabel);
if all(isfinite(numericParticipantLabel)) && ...
        all(numericParticipantLabel >= 0) && ...
        all(numericParticipantLabel == round(numericParticipantLabel))
    participantLabel = compose("%03d",numericParticipantLabel);
end
participantIds = unique(participantLabel,'stable');
numericIds = str2double(participantIds);
if all(isfinite(numericIds))
    [~,participantOrder] = sort(numericIds);
else
    [~,participantOrder] = sort(participantIds);
end
participantIds = participantIds(participantOrder);
[isParticipant,participantIndex] = ismember( ...
    participantLabel,participantIds);
if ~all(isParticipant)
    error('EmpaticMirroring:AnalysisDesignParticipants', ...
        'At least one participant label could not be indexed.');
end

rowInstruction = lower(string(analysisRows.Instruction));
rowComplexity = lower(string(analysisRows.Complexity));
rowVersion = numericFactor(analysisRows.Version,'Version');
rowMovement = numericFactor(analysisRows.Movement,'Movement');
conditionIndex = zeros(height(analysisRows),1);
for rowi = 1:height(analysisRows)
    match = designTable.Instruction == rowInstruction(rowi) & ...
        designTable.Complexity == rowComplexity(rowi) & ...
        designTable.Version == rowVersion(rowi) & ...
        designTable.Movement == rowMovement(rowi);
    if nnz(match) ~= 1
        error('EmpaticMirroring:AnalysisDesignCondition', ...
            'Manifest row %d does not map to exactly one design cell.', ...
            selectedRows(rowi));
    end
    conditionIndex(rowi) = designTable.ConditionIndex(match);
end

trialIndex = numericFactor(analysisRows.TrialIndex,'TrialIndex');
repetitionIndex = zeros(height(analysisRows),1);
for participanti = 1:numel(participantIds)
    for conditioni = 1:nconds
        rows = find(participantIndex == participanti & ...
            conditionIndex == conditioni);
        if isempty(rows)
            continue
        end
        [~,order] = sortrows([trialIndex(rows) selectedRows(rows)], ...
            [1 2]);
        repetitionIndex(rows(order)) = 1:numel(rows);
    end
end

analysisRows.ParticipantLabel = participantLabel;
analysisRows.ParticipantIndex = participantIndex;
analysisRows.ConditionIndex = conditionIndex;
analysisRows.RepetitionIndex = repetitionIndex;

if isempty(repetitionIndex)
    ntrials = 0;
else
    ntrials = max(repetitionIndex);
end
design = struct( ...
    'participantIds',participantIds, ...
    'designTable',designTable, ...
    'nparticipants',numel(participantIds), ...
    'nconds',nconds, ...
    'ntrials',ntrials);

end


function values = numericFactor(inputValues,factorName)

if isnumeric(inputValues)
    values = double(inputValues);
else
    values = str2double(string(inputValues));
end
values = values(:);
if any(~isfinite(values)) || any(values ~= round(values))
    error('EmpaticMirroring:AnalysisDesignNumericFactor', ...
        '%s must contain finite integer values.',factorName);
end

end
