function summary = EmpaticMirroring_MergeSensitivitySummaries( ...
    primaryConfig,recoveredConfig,combinedConfig)
%EMPATICMIRRORING_MERGESENSITIVITYSUMMARIES Merge compact BLOCK 3/4 arrays.
%   Primary participant arrays are reused unchanged and concatenated with
%   recovered-only arrays. No primary per-recording analysis is recomputed.

components = primaryConfig.block3.components(:)';
if ~isequal(components,recoveredConfig.block3.components(:)') || ...
        ~isequal(components,combinedConfig.block3.components(:)')
    error('EmpaticMirroring:SensitivityComponentMismatch', ...
        'Primary, recovered, and combined component sets must match.');
end

auditRows = cell(numel(components),1);
for componenti = 1:numel(components)
    component = components(componenti);
    [primaryCoord,recoveredCoord] = loadSummaryPair( ...
        primaryConfig.block3.output_path, ...
        recoveredConfig.block3.output_path,component, ...
        'FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#');
    [primaryPhase,recoveredPhase] = loadSummaryPair( ...
        primaryConfig.block4.output_path, ...
        recoveredConfig.block4.output_path,component, ...
        'FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#');

    validatePair(primaryCoord,recoveredCoord,'coordination');
    validatePair(primaryPhase,recoveredPhase,'phase-space RQA');
    if ~isequal(primaryCoord.participantIds,primaryPhase.participantIds) || ...
            ~isequal(recoveredCoord.participantIds, ...
            recoveredPhase.participantIds)
        error('EmpaticMirroring:SensitivityParticipantMismatch', ...
            'BLOCK 3 and BLOCK 4 participant orders do not match.');
    end

    [participantIds,order] = mergedParticipantOrder( ...
        primaryCoord.participantIds,recoveredCoord.participantIds);
    designTable = primaryCoord.designTable;
    meter = primaryCoord.meter;
    which_comp = component;

    MIRROR = mergeArray(primaryCoord.MIRROR,recoveredCoord.MIRROR,NaN);
    validTrialMask = mergeTrialMask(primaryCoord.validTrialMask, ...
        recoveredCoord.validTrialMask);
    MIRROR = MIRROR(order,:,:,:);
    validTrialMask = validTrialMask(order,:,:);
    componentRows = mergeComponentRows(primaryCoord.componentRows, ...
        recoveredCoord.componentRows,participantIds);
    coordinationFolder = fullfile(combinedConfig.block3.output_path, ...
        ['Component_' num2str(component)]);
    ensureFolder(coordinationFolder);
    save(fullfile(coordinationFolder, ...
        ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' ...
        num2str(component) '.mat']),'MIRROR','which_comp','meter', ...
        'participantIds','designTable','componentRows','validTrialMask', ...
        '-v7.3');

    PhaseRQA = mergePhaseStructures(primaryPhase.PhaseRQA, ...
        recoveredPhase.PhaseRQA,order);
    validTrialMask = mergeTrialMask(primaryPhase.validTrialMask, ...
        recoveredPhase.validTrialMask);
    validTrialMask = validTrialMask(order,:,:);
    componentRows = mergeComponentRows(primaryPhase.componentRows, ...
        recoveredPhase.componentRows,participantIds);
    phaseFolder = fullfile(combinedConfig.block4.output_path, ...
        ['Component_' num2str(component)]);
    ensureFolder(phaseFolder);
    save(fullfile(phaseFolder, ...
        ['FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#' ...
        num2str(component) '.mat']),'PhaseRQA','which_comp','meter', ...
        'participantIds','designTable','componentRows','validTrialMask', ...
        '-v7.3');

    auditRows{componenti} = table(component, ...
        numel(primaryCoord.participantIds), ...
        numel(recoveredCoord.participantIds),numel(participantIds), ...
        nnz(primaryCoord.validTrialMask), ...
        nnz(recoveredCoord.validTrialMask),nnz(validTrialMask), ...
        'VariableNames',{'Component','PrimaryParticipants', ...
        'RecoveredParticipants','CombinedParticipants', ...
        'PrimaryValidRecordings','RecoveredValidRecordings', ...
        'CombinedValidRecordings'});
end

audit = vertcat(auditRows{:});
ensureFolder(combinedConfig.paths.qcOutputRoot);
writetable(audit,fullfile(combinedConfig.paths.qcOutputRoot, ...
    'compact_summary_merge_audit.csv'));
summary = struct('componentCount',numel(components), ...
    'audit',audit,'outputRoot',string(combinedConfig.paths.outputRoot));
fprintf('Merged compact BLOCK 3/4 summaries for %d components.\n', ...
    summary.componentCount);

end


function [primary,recovered] = loadSummaryPair( ...
    primaryRoot,recoveredRoot,component,prefix)

relativeFile = fullfile(['Component_' num2str(component)], ...
    [prefix num2str(component) '.mat']);
primaryFile = fullfile(primaryRoot,relativeFile);
recoveredFile = fullfile(recoveredRoot,relativeFile);
assert(isfile(primaryFile),'Missing primary summary: %s',primaryFile);
assert(isfile(recoveredFile),'Missing recovered summary: %s',recoveredFile);
primary = load(primaryFile);
recovered = load(recoveredFile);

end


function validatePair(primary,recovered,label)

required = {'participantIds','designTable','meter','componentRows', ...
    'validTrialMask'};
if ~all(isfield(primary,required)) || ...
        ~all(isfield(recovered,required)) || ...
        ~isequal(primary.designTable,recovered.designTable) || ...
        ~isequal(primary.meter,recovered.meter)
    error('EmpaticMirroring:SensitivitySummaryMismatch', ...
        'Primary and recovered %s summaries are incompatible.',label);
end

end


function [participantIds,order] = mergedParticipantOrder(primary,recovered)

primary = string(primary(:));
recovered = string(recovered(:));
if ~isempty(intersect(primary,recovered))
    error('EmpaticMirroring:SensitivityParticipantOverlap', ...
        'Recovered participant IDs overlap the retained primary cohort.');
end
unsorted = [primary; recovered];
numericIds = str2double(unsorted);
if all(isfinite(numericIds))
    [~,order] = sort(numericIds);
else
    [~,order] = sort(unsorted);
end
participantIds = unsorted(order);

end


function output = mergeArray(primary,recovered,fillValue)

if size(primary,2) ~= size(recovered,2) || ...
        size(primary,3) ~= size(recovered,3)
    error('EmpaticMirroring:SensitivityArrayMismatch', ...
        'Primary and recovered compact arrays are incompatible.');
end
nTrials = max(size(primary,4),size(recovered,4));
primaryPadded = repmat(cast(fillValue,'like',primary), ...
    size(primary,1),size(primary,2),size(primary,3),nTrials);
recoveredPadded = repmat(cast(fillValue,'like',recovered), ...
    size(recovered,1),size(recovered,2),size(recovered,3),nTrials);
primaryPadded(:,:,:,1:size(primary,4)) = primary;
recoveredPadded(:,:,:,1:size(recovered,4)) = recovered;
output = cat(1,primaryPadded,recoveredPadded);

end


function output = mergeTrialMask(primary,recovered)

if size(primary,2) ~= size(recovered,2)
    error('EmpaticMirroring:SensitivityMaskMismatch', ...
        'Primary and recovered validity masks are incompatible.');
end
nTrials = max(size(primary,3),size(recovered,3));
primaryPadded = false(size(primary,1),size(primary,2),nTrials);
recoveredPadded = false(size(recovered,1),size(recovered,2),nTrials);
primaryPadded(:,:,1:size(primary,3)) = primary;
recoveredPadded(:,:,1:size(recovered,3)) = recovered;
output = cat(1,primaryPadded,recoveredPadded);

end


function output = mergePhaseStructures(primary,recovered,order)

output = primary;
groups = {'output','coverage'};
for groupi = 1:numel(groups)
    group = groups{groupi};
    if ~isfield(primary,group) || ~isfield(recovered,group)
        error('EmpaticMirroring:SensitivityPhaseFields', ...
            'PhaseRQA summaries are missing the %s group.',group);
    end
    fields = fieldnames(primary.(group));
    if ~isequal(sort(fields),sort(fieldnames(recovered.(group))))
        error('EmpaticMirroring:SensitivityPhaseFields', ...
            'PhaseRQA %s fields differ between cohorts.',group);
    end
    for fieldi = 1:numel(fields)
        field = fields{fieldi};
        values = mergeArray(primary.(group).(field), ...
            recovered.(group).(field),NaN);
        output.(group).(field) = values(order,:,:,:);
    end
end

end


function rows = mergeComponentRows(primary,recovered,participantIds)

primary.AnalysisCohort = repmat("primary retained",height(primary),1);
recovered.AnalysisCohort = repmat( ...
    "recovered sensitivity",height(recovered),1);
if ~isequal(primary.Properties.VariableNames, ...
        recovered.Properties.VariableNames)
    common = primary.Properties.VariableNames(ismember( ...
        primary.Properties.VariableNames, ...
        recovered.Properties.VariableNames));
    primary = primary(:,common);
    recovered = recovered(:,common);
end
rows = [primary; recovered];
[found,index] = ismember(string(rows.ParticipantLabel),participantIds);
if ~all(found)
    error('EmpaticMirroring:SensitivityComponentRows', ...
        'A compact-summary participant could not be re-indexed.');
end
rows.ParticipantIndex = index;

end


function ensureFolder(path)

if ~isfolder(path)
    mkdir(path);
end

end
