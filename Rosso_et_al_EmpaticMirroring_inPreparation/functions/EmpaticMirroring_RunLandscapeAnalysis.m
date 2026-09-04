function [dyadManifest,summary] = EmpaticMirroring_RunLandscapeAnalysis( ...
    dyadManifest,config)
%EMPATICMIRRORING_RUNLANDSCAPEANALYSIS Build BLOCK 2 FREQ-NESS outputs.
%   Mirrors the DyadicDance landscape and effective-dimensionality block.
%   The unbalanced Empatic Mirroring design is represented by analysisRows
%   rather than positional condition arrays, preventing missing trials from
%   shifting Instruction, Complexity, Version, or Movement labels.

validateBlock2Inputs(dyadManifest,config);
if ~isfolder(config.block2.output_path)
    mkdir(config.block2.output_path);
end

nRows = height(dyadManifest);
landscapeFile = strings(nRows,1);
landscapeStatus = repmat("not eligible",nRows,1);
landscapeErrorMessage = strings(nRows,1);
negativeEigenvalueCount = nan(nRows,1);
maximumNegativeEigenvalue = nan(nRows,1);
maximumNegativeMassRatio = nan(nRows,1);
coreFiles = resolveCoreFiles(dyadManifest);
eligibleRows = find(strlength(coreFiles) > 0 & isfile(coreFiles));
if isfinite(config.block2.max_dyads)
    eligibleRows = eligibleRows(1:min( ...
        numel(eligibleRows),config.block2.max_dyads));
end

nAnalysisRows = numel(eligibleRows);
successMask = false(nAnalysisRows,1);
[analysisRows,design] = EmpaticMirroring_IndexAnalysisRows( ...
    dyadManifest,eligibleRows);
marker_reference = [];
validTrialMask = false(design.nparticipants,design.nconds,design.ntrials);

fprintf('\nBLOCK 2: processing %d FREQ network landscapes...\n', ...
    nAnalysisRows);

for analysisi = 1:nAnalysisRows
    rowIndex = eligibleRows(analysisi);
    participanti = analysisRows.ParticipantIndex(analysisi);
    condi = analysisRows.ConditionIndex(analysisi);
    triali = analysisRows.RepetitionIndex(analysisi);
    input_file = coreFiles(rowIndex);
    output_file = landscapeOutputFile(input_file,config.block2.output_path);
    landscapeFile(rowIndex) = output_file;

    try
        S = load(input_file,'FREQ','marker_reference');
        validateCoreInput(S,config);
        [FREQ,eigenvalue_qc] = ...
            EmpaticMirroring_CorrectNumericalEigenvalues( ...
            S.FREQ,config.block2.eigenvalue_negative_tolerance);
        negativeEigenvalueCount(rowIndex) = ...
            eigenvalue_qc.correctedCount;
        maximumNegativeEigenvalue(rowIndex) = ...
            eigenvalue_qc.maximumNegativeMagnitude;
        maximumNegativeMassRatio(rowIndex) = ...
            eigenvalue_qc.maximumNegativeMassRatio;

        % Retain the complete eigenspectrum for EffectDimensionality;
        % retain only the requested spatial components for visualization.
        [this_H2,this_ED] = FREQNESS_EffectDim_Mocap( ...
            FREQ,'figure',false);

        if isfile(output_file) && ~config.block2.overwrite_flag
            savedLandscape = load(output_file,'H2','ED_trial', ...
                'frex','frex_norm','eigenvalue_qc');
            validateLandscapeOutput(savedLandscape,FREQ,this_H2, ...
                this_ED,eigenvalue_qc);
            landscapeStatus(rowIndex) = "existing";
        else
            H2 = this_H2;
            ED_trial = this_ED;
            frex = FREQ.frex;
            frex_norm = FREQ.frex_norm;
            if config.block2.save_flag
                save(output_file,'H2','ED_trial','frex','frex_norm', ...
                    'rowIndex','eigenvalue_qc','-v7.3');
                landscapeStatus(rowIndex) = "created";
            else
                landscapeStatus(rowIndex) = "computed";
            end
        end

        if isempty(marker_reference)
            marker_reference = S.marker_reference;
        end

        validTrialMask(participanti,condi,triali) = true;
        successMask(analysisi) = true;
    catch exception
        landscapeStatus(rowIndex) = "error";
        landscapeErrorMessage(rowIndex) = string(exception.message);
        warning('EmpaticMirroring:LandscapeAnalysisFailed', ...
            'BLOCK 2 failed for row %d: %s',rowIndex,exception.message);
    end

    if mod(analysisi,25) == 0 || analysisi == nAnalysisRows
        fprintf('  processed %d/%d network landscapes\n', ...
            analysisi,nAnalysisRows);
    end
end

dyadManifest.CoreFile = coreFiles;
dyadManifest.LandscapeFile = landscapeFile;
dyadManifest.LandscapeStatus = landscapeStatus;
dyadManifest.LandscapeErrorMessage = landscapeErrorMessage;
dyadManifest.NegativeEigenvalueCount = negativeEigenvalueCount;
dyadManifest.MaximumNegativeEigenvalue = maximumNegativeEigenvalue;
dyadManifest.MaximumNegativeMassRatio = maximumNegativeMassRatio;
analysisRows.SummaryIncluded = successMask;
participantIds = design.participantIds;
designTable = design.designTable;

group_output_file = fullfile(config.block2.output_path, ...
    'FREQNESS_GroupNetworkSummary.mat');
if config.block2.save_flag
    % Keep this catalogue lightweight. Complete evals/patterns remain in
    % the per-recording FREQ files and H2/ED in the landscape files; later
    % blocks load only the observations they require.
    save(group_output_file,'analysisRows','participantIds','designTable', ...
        'validTrialMask','marker_reference');
end

if ~isfolder(config.paths.qcOutputRoot)
    mkdir(config.paths.qcOutputRoot);
end
writetable(dyadManifest,fullfile(config.paths.qcOutputRoot, ...
    'landscape_analysis_manifest.csv'));

available = landscapeStatus == "created" | ...
    landscapeStatus == "existing";
summary = struct( ...
    'eligibleCount',nAnalysisRows, ...
    'createdCount',nnz(landscapeStatus == "created"), ...
    'existingCount',nnz(landscapeStatus == "existing"), ...
    'computedCount',nnz(landscapeStatus == "computed"), ...
    'errorCount',nnz(landscapeStatus == "error"), ...
    'availableCount',nnz(available), ...
    'groupOutputFile',string(group_output_file));

fprintf(['BLOCK 2 outputs available: %d (%d created, %d existing); ' ...
    '%d errors.\n'],summary.availableCount,summary.createdCount, ...
    summary.existingCount,summary.errorCount);

end


function validateBlock2Inputs(dyadManifest,config)

if ~istable(dyadManifest) || ...
        ~ismember('DyadFile',dyadManifest.Properties.VariableNames)
    error('EmpaticMirroring:LandscapeManifest', ...
        'dyadManifest must contain a DyadFile column.');
end
required = {'output_path','overwrite_flag','save_flag', ...
    'ncomps2keep','max_dyads','eigenvalue_negative_tolerance'};
if ~isstruct(config) || ~isfield(config,'block2') || ...
        ~all(isfield(config.block2,required))
    error('EmpaticMirroring:LandscapeConfiguration', ...
        'The BLOCK 2 configuration is incomplete.');
end
if ~islogical(config.block2.overwrite_flag) || ...
        ~isscalar(config.block2.overwrite_flag) || ...
        ~islogical(config.block2.save_flag) || ...
        ~isscalar(config.block2.save_flag)
    error('EmpaticMirroring:LandscapeFlags', ...
        'BLOCK 2 overwrite and save settings must be scalar logical values.');
end
if ~isnumeric(config.block2.ncomps2keep) || ...
        ~isscalar(config.block2.ncomps2keep) || ...
        ~isfinite(config.block2.ncomps2keep) || ...
        config.block2.ncomps2keep < 1 || ...
        config.block2.ncomps2keep ~= round(config.block2.ncomps2keep)
    error('EmpaticMirroring:LandscapeComponents', ...
        'config.block2.ncomps2keep must be one positive integer.');
end
if ~isnumeric(config.block2.max_dyads) || ...
        ~isscalar(config.block2.max_dyads) || ...
        ~(config.block2.max_dyads == Inf || ...
        (isfinite(config.block2.max_dyads) && ...
        config.block2.max_dyads >= 1 && ...
        config.block2.max_dyads == round(config.block2.max_dyads)))
    error('EmpaticMirroring:LandscapeMaximum', ...
        'config.block2.max_dyads must be a positive integer or Inf.');
end
if ~isnumeric(config.block2.eigenvalue_negative_tolerance) || ...
        ~isscalar(config.block2.eigenvalue_negative_tolerance) || ...
        ~isfinite(config.block2.eigenvalue_negative_tolerance) || ...
        config.block2.eigenvalue_negative_tolerance < 0
    error('EmpaticMirroring:LandscapeEigenvalueTolerance', ...
        ['config.block2.eigenvalue_negative_tolerance must be one ' ...
        'finite non-negative ratio.']);
end

end


function coreFiles = resolveCoreFiles(dyadManifest)

nRows = height(dyadManifest);
coreFiles = strings(nRows,1);
if ismember('CoreFile',dyadManifest.Properties.VariableNames)
    coreFiles = string(dyadManifest.CoreFile);
end
dyadFiles = string(dyadManifest.DyadFile);
for rowIndex = 1:nRows
    if strlength(coreFiles(rowIndex)) == 0 && ...
            strlength(dyadFiles(rowIndex)) > 0
        [inputFolder,inputStem] = fileparts(dyadFiles(rowIndex));
        coreFiles(rowIndex) = string(fullfile(inputFolder, ...
            "FREQNESS_CORE_" + inputStem + ".mat"));
    end
end

end


function output_file = landscapeOutputFile(input_file,output_path)

[~,inputStem] = fileparts(input_file);
unitStem = erase(string(inputStem),"FREQNESS_CORE_");
output_file = string(fullfile(output_path, ...
    "FREQNESS_LANDSCAPE_" + unitStem + ".mat"));

end


function validateCoreInput(S,config)

if ~isfield(S,'FREQ') || ~isstruct(S.FREQ) || ...
        ~isfield(S,'marker_reference')
    error('EmpaticMirroring:LandscapeCoreFields', ...
        'BLOCK 1 output must contain FREQ and marker_reference.');
end
required = {'evals','pats','frex','frex_norm'};
if ~all(isfield(S.FREQ,required)) || ...
        size(S.FREQ.evals,3) ~= 2 || size(S.FREQ.pats,4) ~= 2 || ...
        size(S.FREQ.pats,2) < config.block2.ncomps2keep
    error('EmpaticMirroring:LandscapeCoreShape', ...
        'BLOCK 1 FREQ output is incompatible with BLOCK 2 settings.');
end

end


function validateLandscapeOutput(savedLandscape,FREQ,H2,ED_trial, ...
    eigenvalue_qc)

required = {'H2','ED_trial','frex','frex_norm','eigenvalue_qc'};
if ~all(isfield(savedLandscape,required)) || ...
        ~isequal(size(savedLandscape.H2), ...
        [size(FREQ.evals,2) size(FREQ.evals,3)]) || ...
        ~isequal(size(savedLandscape.ED_trial), ...
        [size(FREQ.evals,2) size(FREQ.evals,3)]) || ...
        ~isequal(savedLandscape.frex,FREQ.frex) || ...
        ~isequal(savedLandscape.frex_norm,FREQ.frex_norm) || ...
        ~isequaln(savedLandscape.H2,H2) || ...
        ~isequaln(savedLandscape.ED_trial,ED_trial) || ...
        ~isequaln(savedLandscape.eigenvalue_qc,eigenvalue_qc)
    error('EmpaticMirroring:LandscapeOutputContract', ...
        'Existing BLOCK 2 output does not match its FREQ input.');
end

end
