function summary = EmpaticMirroring_ExportStatistics(config)
%EMPATICMIRRORING_EXPORTSTATISTICS Create BLOCK 6 long-format exports.
%   Repetitions are averaged within participant and factorial cell. The
%   participant remains the repeated-measures unit; acquisition TrialIndex
%   is absent from this final analysis table by design.

validateBlock6Inputs(config);
if ~isfolder(config.block6.output_path)
    mkdir(config.block6.output_path);
end

components = config.block3.components(:)';
componentTables = cell(numel(components),1);
csvFiles = strings(numel(components),1);
xlsxFiles = strings(numel(components),1);

for componenti = 1:numel(components)
    which_comp = components(componenti);
    coordinationFile = fullfile(config.block3.output_path, ...
        ['Component_' num2str(which_comp)], ...
        ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' ...
        num2str(which_comp) '.mat']);
    phaseFile = fullfile(config.block4.output_path, ...
        ['Component_' num2str(which_comp)], ...
        ['FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#' ...
        num2str(which_comp) '.mat']);
    assert(isfile(coordinationFile), ...
        'Missing BLOCK 3 summary: %s',coordinationFile);
    assert(isfile(phaseFile),'Missing BLOCK 4 summary: %s',phaseFile);
    C = load(coordinationFile,'MIRROR','meter', ...
        'participantIds','designTable','validTrialMask');
    P = load(phaseFile,'PhaseRQA','meter','participantIds', ...
        'designTable','validTrialMask');
    validateSummaryPair(C,P,which_comp);

    componentTables{componenti} = buildComponentTable(C,P,which_comp);
    csvFiles(componenti) = fullfile(config.block6.output_path, ...
        ['OUT2R_Comp#' num2str(which_comp) '.csv']);
    writetable(componentTables{componenti},csvFiles(componenti));
    if config.block6.write_xlsx
        xlsxFiles(componenti) = fullfile(config.block6.output_path, ...
            ['OUT2R_Comp#' num2str(which_comp) '.xlsx']);
        writetable(componentTables{componenti},xlsxFiles(componenti));
    end
end

statisticsTable = vertcat(componentTables{:});
combinedCsvFile = string(fullfile(config.block6.output_path, ...
    'OUT2R_AllComponents.csv'));
% Statistical exports are inexpensive derived files. Rebuild them on every
% run so a pilot table can never be mistaken for the full-sample export.
writetable(statisticsTable,combinedCsvFile);

summary = struct( ...
    'rowCount',height(statisticsTable), ...
    'componentCount',numel(components), ...
    'csvFiles',csvFiles, ...
    'xlsxFiles',xlsxFiles, ...
    'combinedCsvFile',combinedCsvFile, ...
    'statisticsTable',statisticsTable);

fprintf('BLOCK 6 exported %d participant-cell-meter-component rows.\n', ...
    summary.rowCount);

end


function validateBlock6Inputs(config)

required = {'output_path','overwrite_flag','write_xlsx'};
if ~isstruct(config) || ~isfield(config,'block6') || ...
        ~all(isfield(config.block6,required)) || ...
        ~isfield(config,'block3') || ~isfield(config.block3,'components') || ...
        ~isfield(config.block3,'output_path') || ...
        ~isfield(config,'block4') || ~isfield(config.block4,'output_path')
    error('EmpaticMirroring:StatisticsConfiguration', ...
        'The BLOCK 6 configuration is incomplete.');
end
if ~islogical(config.block6.overwrite_flag) || ...
        ~isscalar(config.block6.overwrite_flag) || ...
        ~islogical(config.block6.write_xlsx) || ...
        ~isscalar(config.block6.write_xlsx)
    error('EmpaticMirroring:StatisticsFlags', ...
        'BLOCK 6 overwrite and XLSX settings must be scalar logicals.');
end

end


function validateSummaryPair(C,P,which_comp)

coordinationFields = {'MIRROR','meter','participantIds', ...
    'designTable','validTrialMask'};
phaseFields = {'PhaseRQA','meter','participantIds','designTable', ...
    'validTrialMask'};
phaseMetrics = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
coverageFields = {'ValidSampleCount','ExcludedSampleCount', ...
    'EligiblePairCount','EligiblePairFraction'};
if ~all(isfield(C,coordinationFields)) || ~all(isfield(P,phaseFields)) || ...
        ~isfield(P.PhaseRQA,'output') || ...
        ~all(isfield(P.PhaseRQA.output,phaseMetrics)) || ...
        ~isfield(P.PhaseRQA,'coverage') || ...
        ~all(isfield(P.PhaseRQA.coverage,coverageFields)) || ...
        ~isequal(C.meter,P.meter) || ...
        ~isequal(string(C.participantIds),string(P.participantIds)) || ...
        ~isequal(C.designTable,P.designTable) || ...
        ~isequal(size(C.validTrialMask),size(P.validTrialMask))
    error('EmpaticMirroring:StatisticsSummaryMismatch', ...
        'BLOCK 3 and BLOCK 4 summaries mismatch for component %d.', ...
        which_comp);
end

end


function T = buildComponentTable(C,P,which_comp)

jointValidMask = C.validTrialMask & P.validTrialMask;
mirror = mean(applyTrialMask(C.MIRROR,jointValidMask),4,'omitnan');
phaseFields = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
phaseMeans = struct();
for fieldi = 1:numel(phaseFields)
    phaseMeans.(phaseFields{fieldi}) = mean( ...
        applyTrialMask(P.PhaseRQA.output.(phaseFields{fieldi}), ...
        jointValidMask),4,'omitnan');
end
coverageFields = {'ValidSampleCount','ExcludedSampleCount', ...
    'EligiblePairCount','EligiblePairFraction'};
coverageMeans = struct();
for fieldi = 1:numel(coverageFields)
    coverageMeans.(coverageFields{fieldi}) = mean( ...
        applyTrialMask(P.PhaseRQA.coverage.(coverageFields{fieldi}), ...
        jointValidMask),4,'omitnan');
end
nRepetitions = sum(jointValidMask,3);

nparticipants = numel(C.participantIds);
nconds = height(C.designTable);
nmeters = numel(C.meter);
validCell = nRepetitions > 0;
nRows = nnz(validCell)*nmeters;

Participant = strings(nRows,1);
Instruction = strings(nRows,1);
Complexity = strings(nRows,1);
Version = zeros(nRows,1);
Movement = zeros(nRows,1);
Condition = zeros(nRows,1);
Meter = strings(nRows,1);
MeterLevel = zeros(nRows,1);
Component = repmat(which_comp,nRows,1);
NRepetitions = zeros(nRows,1);
Mirror = nan(nRows,1);
RR_Phase = nan(nRows,1);
L_Phase = nan(nRows,1);
DET_Phase = nan(nRows,1);
ENTR_Phase = nan(nRows,1);
TT_Phase = nan(nRows,1);
LAM_Phase = nan(nRows,1);
Vmax_Phase = nan(nRows,1);
DIV_Phase = nan(nRows,1);
ValidSamples_Phase = nan(nRows,1);
ExcludedSamples_Phase = nan(nRows,1);
EligiblePairs_Phase = nan(nRows,1);
EligiblePairFraction_Phase = nan(nRows,1);

row = 0;
for participanti = 1:nparticipants
    for condi = 1:nconds
        if ~validCell(participanti,condi)
            continue
        end
        for metri = 1:nmeters
            row = row + 1;
            Participant(row) = string(C.participantIds(participanti));
            Instruction(row) = C.designTable.Instruction(condi);
            Complexity(row) = C.designTable.Complexity(condi);
            Version(row) = C.designTable.Version(condi);
            Movement(row) = C.designTable.Movement(condi);
            Condition(row) = C.designTable.ConditionIndex(condi);
            Meter(row) = "M" + string(metri);
            MeterLevel(row) = C.meter(metri);
            NRepetitions(row) = nRepetitions(participanti,condi);
            Mirror(row) = mirror(participanti,condi,metri);
            RR_Phase(row) = phaseMeans.RR(participanti,condi,metri);
            L_Phase(row) = phaseMeans.L(participanti,condi,metri);
            DET_Phase(row) = phaseMeans.DET(participanti,condi,metri);
            ENTR_Phase(row) = phaseMeans.ENTR(participanti,condi,metri);
            TT_Phase(row) = phaseMeans.TT(participanti,condi,metri);
            LAM_Phase(row) = phaseMeans.LAM(participanti,condi,metri);
            Vmax_Phase(row) = phaseMeans.Vmax(participanti,condi,metri);
            DIV_Phase(row) = phaseMeans.DIV(participanti,condi,metri);
            ValidSamples_Phase(row) = ...
                coverageMeans.ValidSampleCount(participanti,condi,metri);
            ExcludedSamples_Phase(row) = ...
                coverageMeans.ExcludedSampleCount(participanti,condi,metri);
            EligiblePairs_Phase(row) = ...
                coverageMeans.EligiblePairCount(participanti,condi,metri);
            EligiblePairFraction_Phase(row) = ...
                coverageMeans.EligiblePairFraction( ...
                participanti,condi,metri);
        end
    end
end

T = table(Participant,Instruction,Complexity,Version,Movement, ...
    Condition,Meter,MeterLevel,Component,NRepetitions,Mirror, ...
    RR_Phase,L_Phase,DET_Phase,ENTR_Phase,TT_Phase, ...
    LAM_Phase,Vmax_Phase,DIV_Phase,ValidSamples_Phase, ...
    ExcludedSamples_Phase,EligiblePairs_Phase, ...
    EligiblePairFraction_Phase);

end


function data = applyTrialMask(data,validTrialMask)

expandedMask = reshape(validTrialMask, ...
    size(validTrialMask,1),size(validTrialMask,2),1, ...
    size(validTrialMask,3));
expandedMask = repmat(expandedMask,1,1,size(data,3),1);
data(~expandedMask) = NaN;

end
