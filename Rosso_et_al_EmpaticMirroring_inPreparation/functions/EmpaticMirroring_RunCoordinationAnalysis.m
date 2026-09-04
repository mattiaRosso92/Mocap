function [dyadManifest,summary] = EmpaticMirroring_RunCoordinationAnalysis( ...
    dyadManifest,config)
%EMPATICMIRRORING_RUNCOORDINATIONANALYSIS Run BLOCK 3 spatial coordination.
%   Mirrors the DyadicDance spatial-mirroring analysis. JRQA is disabled
%   because its implementation cannot safely exclude gappy samples.

validateBlock3Inputs(dyadManifest,config);
if ~isfolder(config.block3.output_path)
    mkdir(config.block3.output_path);
end

coreFiles = resolveCoreFiles(dyadManifest);
eligibleRows = find(strlength(coreFiles) > 0 & isfile(coreFiles));
if isfinite(config.block3.max_dyads)
    eligibleRows = eligibleRows(1:min( ...
        numel(eligibleRows),config.block3.max_dyads));
end
if isempty(eligibleRows)
    error('EmpaticMirroring:CoordinationMissingCoreOutputs', ...
        'BLOCK 3 requires at least one existing BLOCK 1 core FREQ file.');
end
[analysisRows,design] = EmpaticMirroring_IndexAnalysisRows( ...
    dyadManifest,eligibleRows);

components = config.block3.components(:)';
meter = config.block3.metric_levels(:)';
ncomponents = numel(components);
nmeters = numel(meter);
nAnalysisRows = height(analysisRows);
nOutputs = nAnalysisRows*ncomponents;

manifestRow = repelem(eligibleRows,ncomponents,1);
component = repmat(components',nAnalysisRows,1);
coordinationFile = strings(nOutputs,1);
coordinationStatus = repmat("not processed",nOutputs,1);
coordinationErrorMessage = strings(nOutputs,1);

fprintf('\nBLOCK 3: processing spatial coordination for %d recordings ' + ...
    "across %d components...\n",nAnalysisRows,ncomponents);

for componenti = 1:ncomponents
    which_comp = components(componenti);
    component_output_path = fullfile(config.block3.output_path, ...
        ['Component_' num2str(which_comp)]);
    if ~isfolder(component_output_path)
        mkdir(component_output_path);
    end

    MIRROR = nan(design.nparticipants,design.nconds,nmeters,design.ntrials);
    validTrialMask = false( ...
        design.nparticipants,design.nconds,design.ntrials);

    for analysisi = 1:nAnalysisRows
        rowIndex = eligibleRows(analysisi);
        longIndex = (analysisi-1)*ncomponents + componenti;
        input_file = coreFiles(rowIndex);
        output_file = coordinationOutputFile( ...
            input_file,component_output_path);
        coordinationFile(longIndex) = output_file;

        participanti = analysisRows.ParticipantIndex(analysisi);
        condi = analysisRows.ConditionIndex(analysisi);
        triali = analysisRows.RepetitionIndex(analysisi);

        try
            S = load(input_file,'FREQ','beat_frex');
            validateCoreInput(S,which_comp);
            analysis_info = coordinationAnalysisInfo( ...
                input_file,which_comp,meter);

            if isfile(output_file) && ~config.block3.overwrite_flag
                saved = load(output_file,'FREQmirror','which_comp', ...
                    'meter','analysis_info');
                validateCoordinationOutput(saved,analysis_info,nmeters);
                FREQmirror = saved.FREQmirror;
                coordinationStatus(longIndex) = "existing";
            else
                FREQmirror = FREQNESS_SpaceCoord_Mocap( ...
                    S.FREQ,S.beat_frex, ...
                    'metric_levels',meter, ...
                    'component',which_comp);
                validateCoordinationMetrics(FREQmirror,nmeters);

                if config.block3.save_flag
                    save(output_file,'FREQmirror','which_comp','meter', ...
                        'analysis_info','-v7.3');
                    coordinationStatus(longIndex) = "created";
                else
                    coordinationStatus(longIndex) = "computed";
                end
            end

            MIRROR(participanti,condi,:,triali) = ...
                reshape(FREQmirror,[1 1 nmeters 1]);
            validTrialMask(participanti,condi,triali) = true;
        catch exception
            coordinationStatus(longIndex) = "error";
            coordinationErrorMessage(longIndex) = string(exception.message);
            warning('EmpaticMirroring:CoordinationAnalysisFailed', ...
                'BLOCK 3 failed for row %d, component %d: %s', ...
                rowIndex,which_comp,exception.message);
        end

        if mod(analysisi,25) == 0 || analysisi == nAnalysisRows
            fprintf('  component %d: processed %d/%d recordings\n', ...
                which_comp,analysisi,nAnalysisRows);
        end
    end

    participantIds = design.participantIds;
    designTable = design.designTable;
    componentRows = analysisRows;
    componentRows.CoordinationIncluded = ...
        validTrialMask(sub2ind(size(validTrialMask), ...
        componentRows.ParticipantIndex,componentRows.ConditionIndex, ...
        componentRows.RepetitionIndex));
    coordination_summary_file = fullfile(component_output_path, ...
        ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' ...
        num2str(which_comp) '.mat']);
    if config.block3.save_flag
        save(coordination_summary_file,'MIRROR','which_comp','meter', ...
            'participantIds','designTable','componentRows', ...
            'validTrialMask','-v7.3');
    end
end

coordinationManifest = table(manifestRow,component,coordinationFile, ...
    coordinationStatus,coordinationErrorMessage, ...
    'VariableNames',{'ManifestRow','Component','CoordinationFile', ...
    'CoordinationStatus','CoordinationErrorMessage'});
if ~isfolder(config.paths.qcOutputRoot)
    mkdir(config.paths.qcOutputRoot);
end
writetable(coordinationManifest,fullfile(config.paths.qcOutputRoot, ...
    'spatial_coordination_analysis_manifest.csv'));

dyadManifest.CoordinationStatus = repmat("not eligible",height(dyadManifest),1);
dyadManifest.CoordinationErrorMessage = strings(height(dyadManifest),1);
for analysisi = 1:nAnalysisRows
    rowIndex = eligibleRows(analysisi);
    rows = (analysisi-1)*ncomponents + (1:ncomponents);
    statuses = coordinationStatus(rows);
    if any(statuses == "error")
        dyadManifest.CoordinationStatus(rowIndex) = "error";
        messages = coordinationErrorMessage(rows);
        dyadManifest.CoordinationErrorMessage(rowIndex) = ...
            strjoin(messages(strlength(messages) > 0)," | ");
    elseif all(statuses == "created")
        dyadManifest.CoordinationStatus(rowIndex) = "created";
    elseif all(statuses == "existing")
        dyadManifest.CoordinationStatus(rowIndex) = "existing";
    elseif all(ismember(statuses,["created","existing","computed"]))
        dyadManifest.CoordinationStatus(rowIndex) = "available";
    end
end

available = ismember(coordinationStatus,["created","existing"]);
summary = struct( ...
    'eligibleCount',nOutputs, ...
    'createdCount',nnz(coordinationStatus == "created"), ...
    'existingCount',nnz(coordinationStatus == "existing"), ...
    'computedCount',nnz(coordinationStatus == "computed"), ...
    'errorCount',nnz(coordinationStatus == "error"), ...
    'availableCount',nnz(available), ...
    'coordinationManifest',coordinationManifest);

fprintf(['BLOCK 3 spatial outputs available: %d (%d created, ' ...
    '%d existing); %d errors.\n'],summary.availableCount, ...
    summary.createdCount,summary.existingCount,summary.errorCount);

end


function validateBlock3Inputs(dyadManifest,config)

requiredManifest = {'DyadFile','Subject','TrialIndex','Instruction', ...
    'Complexity','Version','Movement'};
if ~istable(dyadManifest) || ...
        ~all(ismember(requiredManifest,dyadManifest.Properties.VariableNames))
    error('EmpaticMirroring:CoordinationManifest', ...
        'dyadManifest is missing fields required for BLOCK 3.');
end
required = {'output_path','overwrite_flag','save_flag','components', ...
    'metric_levels','max_dyads'};
if ~isstruct(config) || ~isfield(config,'block3') || ...
        ~all(isfield(config.block3,required))
    error('EmpaticMirroring:CoordinationConfiguration', ...
        'The BLOCK 3 configuration is incomplete.');
end
if ~islogical(config.block3.overwrite_flag) || ...
        ~isscalar(config.block3.overwrite_flag) || ...
        ~islogical(config.block3.save_flag) || ...
        ~isscalar(config.block3.save_flag)
    error('EmpaticMirroring:CoordinationFlags', ...
        'BLOCK 3 overwrite and save flags must be scalar logicals.');
end
positiveIntegerVector(config.block3.components,'components');
positiveIntegerOrInf(config.block3.max_dyads,'max_dyads');
if ~isnumeric(config.block3.metric_levels) || ...
        ~isreal(config.block3.metric_levels) || ...
        isempty(config.block3.metric_levels) || ...
        ~isvector(config.block3.metric_levels) || ...
        any(~isfinite(config.block3.metric_levels)) || ...
        any(config.block3.metric_levels <= 0)
    error('EmpaticMirroring:CoordinationMetricLevels', ...
        'metric_levels must be a positive finite vector.');
end

end


function positiveIntegerVector(value,name)

if ~isnumeric(value) || ~isreal(value) || isempty(value) || ...
        ~isvector(value) || any(~isfinite(value)) || ...
        any(value < 1) || any(value ~= round(value)) || ...
        numel(unique(value)) ~= numel(value)
    error('EmpaticMirroring:CoordinationPositiveIntegers', ...
        'config.block3.%s must contain unique positive integers.',name);
end

end


function positiveIntegerOrInf(value,name)

if ~isnumeric(value) || ~isscalar(value) || ...
        ~(value == Inf || (isfinite(value) && value >= 1 && ...
        value == round(value)))
    error('EmpaticMirroring:CoordinationMaximum', ...
        'config.block3.%s must be a positive integer or Inf.',name);
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


function validateCoreInput(S,which_comp)

if ~isfield(S,'FREQ') || ~isstruct(S.FREQ) || ...
        ~isfield(S,'beat_frex') || ...
        ~all(isfield(S.FREQ,{'pats','frex'})) || ...
        ndims(S.FREQ.pats) ~= 4 || size(S.FREQ.pats,4) ~= 2 || ...
        size(S.FREQ.pats,2) < which_comp || ...
        ~isnumeric(S.beat_frex) || ...
        ~isequal(size(S.beat_frex),[1 2]) || ...
        any(~isfinite(S.beat_frex)) || any(S.beat_frex <= 0)
    error('EmpaticMirroring:CoordinationCoreInput', ...
        'The BLOCK 1 FREQ output is incompatible with BLOCK 3.');
end

end


function output_file = coordinationOutputFile(input_file,output_path)

[~,inputStem] = fileparts(input_file);
unitStem = erase(string(inputStem),"FREQNESS_CORE_");
output_file = string(fullfile(output_path, ...
    "FREQNESS_SPATIALCOORDINATION_" + unitStem + ".mat"));

end


function info = coordinationAnalysisInfo(input_file,which_comp,meter)

info = struct( ...
    'method',"spatial_mirroring", ...
    'inputCoreFile',string(input_file), ...
    'component',which_comp, ...
    'metric_levels',meter);

end


function validateCoordinationOutput(saved,analysis_info,nmeters)

required = {'FREQmirror','which_comp','meter','analysis_info'};
if ~all(isfield(saved,required)) || ...
        ~isequaln(saved.analysis_info,analysis_info) || ...
        saved.which_comp ~= analysis_info.component || ...
        ~isequal(saved.meter,analysis_info.metric_levels)
    error('EmpaticMirroring:CoordinationOutputContract', ...
        'Existing BLOCK 3 output does not match the current configuration.');
end
validateCoordinationMetrics(saved.FREQmirror,nmeters);

end


function validateCoordinationMetrics(FREQmirror,nmeters)

if ~isnumeric(FREQmirror) || numel(FREQmirror) ~= nmeters || ...
        any(~isfinite(FREQmirror))
    error('EmpaticMirroring:CoordinationMetrics', ...
        'BLOCK 3 produced incomplete or non-finite mirroring metrics.');
end

end
