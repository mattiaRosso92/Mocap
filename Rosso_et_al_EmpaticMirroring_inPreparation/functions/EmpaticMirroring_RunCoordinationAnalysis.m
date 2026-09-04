function [dyadManifest,summary] = EmpaticMirroring_RunCoordinationAnalysis( ...
    dyadManifest,config)
%EMPATICMIRRORING_RUNCOORDINATIONANALYSIS Run BLOCK 3 coordination.
%   Mirrors the DyadicDance JRQA temporal-coordination and spatial-mirroring
%   block. One output is stored per participant recording and component;
%   compact scalar summaries retain participant-condition-repetition indices.

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

% lp_cutoff_norm is the desired fraction of the new Nyquist frequency.
% Express it relative to the original Nyquist before decimation so this is
% a genuine anti-alias filter (the template comment states this intention).
antialiasCutoff = config.block3.lp_cutoff_norm / ...
    config.block3.downsample_factor;
[b_butt,a_butt] = butter(config.block3.lp_order,antialiasCutoff,'low');

fprintf('\nBLOCK 3: processing %d recordings across %d components...\n', ...
    nAnalysisRows,ncomponents);

for componenti = 1:ncomponents
    which_comp = components(componenti);
    component_output_path = fullfile(config.block3.output_path, ...
        ['Component_' num2str(which_comp)]);
    if ~isfolder(component_output_path)
        mkdir(component_output_path);
    end

    JRQA = resolveJRQAParameters(which_comp,coreFiles(eligibleRows), ...
        analysisRows,config,b_butt,a_butt,component_output_path);

    MIRROR = nan(design.nparticipants,design.nconds,nmeters,design.ntrials);
    RR = nan(design.nparticipants,design.nconds,nmeters,design.ntrials);
    DET = nan(design.nparticipants,design.nconds,nmeters,design.ntrials);
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
            analysis_info = coordinationAnalysisInfo(input_file, ...
                which_comp,meter,JRQA,config,S.FREQ.srate);

            if isfile(output_file) && ~config.block3.overwrite_flag
                saved = load(output_file,'FREQjrqa','FREQmirror', ...
                    'JRQA','which_comp','meter','analysis_info');
                validateCoordinationOutput(saved,analysis_info,nmeters);
                FREQjrqa = saved.FREQjrqa;
                FREQmirror = saved.FREQmirror;
                coordinationStatus(longIndex) = "existing";
            else
                FREQ = preprocessCoordinationTimeSeries( ...
                    S.FREQ,which_comp,config,b_butt,a_butt);
                FREQjrqa = FREQNESS_TimeCoord_Mocap( ...
                    FREQ,JRQA,S.beat_frex, ...
                    'metric_levels',meter, ...
                    'component',which_comp, ...
                    'duration',config.block3.duration);
                FREQmirror = FREQNESS_SpaceCoord_Mocap( ...
                    S.FREQ,S.beat_frex, ...
                    'metric_levels',meter, ...
                    'component',which_comp);
                validateCoordinationMetrics(FREQjrqa,FREQmirror,nmeters);

                if config.block3.save_flag
                    save(output_file,'FREQjrqa','FREQmirror','JRQA', ...
                        'which_comp','meter','analysis_info','-v7.3');
                    coordinationStatus(longIndex) = "created";
                else
                    coordinationStatus(longIndex) = "computed";
                end
            end

            for metri = 1:nmeters
                MIRROR(participanti,condi,metri,triali) = ...
                    FREQmirror(metri);
                RR(participanti,condi,metri,triali) = ...
                    scalarMetric(FREQjrqa(metri).RR,'RR');
                DET(participanti,condi,metri,triali) = ...
                    scalarMetric(FREQjrqa(metri).DET,'DET');
            end
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
        ['FREQNESS_COORDINATION_SUMMARY_Comp#' ...
        num2str(which_comp) '.mat']);
    if config.block3.save_flag
        % Rebuild this compact scalar summary so pilot and full runs cannot
        % be confused. Complete FREQ arrays remain in per-recording files.
        save(coordination_summary_file,'MIRROR','RR','DET','which_comp', ...
            'meter','participantIds','designTable','componentRows', ...
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
    'coordination_analysis_manifest.csv'));

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

fprintf(['BLOCK 3 outputs available: %d (%d created, %d existing); ' ...
    '%d errors.\n'],summary.availableCount,summary.createdCount, ...
    summary.existingCount,summary.errorCount);

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
    'attune_flag','JRQA','metric_levels','downsample_factor','lp_order', ...
    'lp_cutoff_norm','duration','max_dyads','max_attune_dyads'};
if ~isstruct(config) || ~isfield(config,'block3') || ...
        ~all(isfield(config.block3,required))
    error('EmpaticMirroring:CoordinationConfiguration', ...
        'The BLOCK 3 configuration is incomplete.');
end
if ~islogical(config.block3.overwrite_flag) || ...
        ~isscalar(config.block3.overwrite_flag) || ...
        ~islogical(config.block3.save_flag) || ...
        ~isscalar(config.block3.save_flag) || ...
        ~islogical(config.block3.attune_flag) || ...
        ~isscalar(config.block3.attune_flag)
    error('EmpaticMirroring:CoordinationFlags', ...
        'BLOCK 3 overwrite, save, and attune flags must be scalar logicals.');
end
positiveIntegerVector(config.block3.components,'components');
positiveIntegerScalar(config.block3.downsample_factor,'downsample_factor');
positiveIntegerScalar(config.block3.lp_order,'lp_order');
positiveIntegerOrInf(config.block3.max_dyads,'max_dyads');
positiveIntegerOrInf(config.block3.max_attune_dyads,'max_attune_dyads');
if ~isnumeric(config.block3.metric_levels) || ...
        ~isreal(config.block3.metric_levels) || ...
        isempty(config.block3.metric_levels) || ...
        ~isvector(config.block3.metric_levels) || ...
        any(~isfinite(config.block3.metric_levels)) || ...
        any(config.block3.metric_levels <= 0)
    error('EmpaticMirroring:CoordinationMetricLevels', ...
        'metric_levels must be a positive finite vector.');
end
if ~isnumeric(config.block3.lp_cutoff_norm) || ...
        ~isscalar(config.block3.lp_cutoff_norm) || ...
        ~isfinite(config.block3.lp_cutoff_norm) || ...
        config.block3.lp_cutoff_norm <= 0 || ...
        config.block3.lp_cutoff_norm >= 1
    error('EmpaticMirroring:CoordinationLowPass', ...
        'lp_cutoff_norm must lie strictly between zero and one.');
end
if ~isnumeric(config.block3.duration) || ...
        ~isreal(config.block3.duration) || ...
        numel(config.block3.duration) ~= 2 || ...
        any(~isfinite(config.block3.duration)) || ...
        config.block3.duration(1) < 0 || ...
        config.block3.duration(2) > 1 || ...
        config.block3.duration(1) >= config.block3.duration(2)
    error('EmpaticMirroring:CoordinationDuration', ...
        'duration must be an increasing proportional interval within [0 1].');
end
if exist('RPparam','file') ~= 2 || exist('jrqa','file') ~= 2
    error('EmpaticMirroring:CoordinationDependencies', ...
        'RPparam.m and jrqa.m are required for BLOCK 3.');
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


function positiveIntegerScalar(value,name)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 1 || value ~= round(value)
    error('EmpaticMirroring:CoordinationPositiveInteger', ...
        'config.block3.%s must be one positive integer.',name);
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


function JRQA = resolveJRQAParameters(which_comp,coreFiles,analysisRows, ...
    config,b_butt,a_butt,component_output_path)

parameter_file = fullfile(component_output_path, ...
    ['JRQA_Parameters_Comp#' num2str(which_comp) '.mat']);
parameterSettings = struct( ...
    'which_comp',which_comp, ...
    'metric_levels',config.block3.metric_levels, ...
    'downsample_factor',config.block3.downsample_factor, ...
    'lp_order',config.block3.lp_order, ...
    'lp_cutoff_norm',config.block3.lp_cutoff_norm, ...
    'antialias_cutoff_normalized_to_input_nyquist', ...
    config.block3.lp_cutoff_norm/config.block3.downsample_factor, ...
    'duration',config.block3.duration, ...
    'attune_flag',config.block3.attune_flag, ...
    'max_attune_dyads',config.block3.max_attune_dyads, ...
    'configured_JRQA',config.block3.JRQA);

if isfile(parameter_file) && ~config.block3.overwrite_flag
    saved = load(parameter_file,'JRQA','parameterSettings', ...
        'parameterCoreFiles');
    if all(isfield(saved,{'JRQA','parameterSettings','parameterCoreFiles'})) && ...
            isequaln(saved.parameterSettings,parameterSettings) && ...
            isequal(string(saved.parameterCoreFiles),string(coreFiles))
        validateJRQA(saved.JRQA);
        JRQA = saved.JRQA;
        return
    end
end

if config.block3.attune_flag
    JRQA = attuneJRQA(which_comp,coreFiles,config,b_butt,a_butt);
else
    JRQA = config.block3.JRQA;
    validateJRQA(JRQA);
end

if config.block3.save_flag
    parameterCoreFiles = coreFiles;
    parameterAnalysisRows = analysisRows;
    save(parameter_file,'JRQA','parameterSettings','parameterCoreFiles', ...
        'parameterAnalysisRows');
end

end


function JRQA = attuneJRQA(which_comp,coreFiles,config,b_butt,a_butt)

nAttune = numel(coreFiles);
if isfinite(config.block3.max_attune_dyads)
    nAttune = min(nAttune,config.block3.max_attune_dyads);
end
tau = [];
m = [];
ps = [];
meter = config.block3.metric_levels(:)';
for analysisi = 1:nAttune
    S = load(coreFiles(analysisi),'FREQ','beat_frex');
    validateCoreInput(S,which_comp);
    FREQ = preprocessCoordinationTimeSeries( ...
        S.FREQ,which_comp,config,b_butt,a_butt);
    for subi = 1:2
        for metri = 1:numel(meter)
            frex = frequencyVector(FREQ.frex,subi,size(FREQ.ts,3));
            [~,frexi] = min(abs(S.beat_frex(subi)*meter(metri)-frex));
            ts = squeeze(FREQ.ts(which_comp,:,frexi,subi));
            firstPoint = max(1,round(config.block3.duration(1)*numel(ts)));
            lastPoint = min(numel(ts), ...
                round(config.block3.duration(2)*numel(ts)));
            [thisTau,thisM,thisPs] = RPparam(ts(firstPoint:lastPoint));
            tau(end+1,1) = thisTau; %#ok<AGROW>
            m(end+1,1) = thisM; %#ok<AGROW>
            ps(end+1,1) = thisPs; %#ok<AGROW>
        end
    end
end
if isempty(tau) || any(~isfinite([tau;m;ps]))
    error('EmpaticMirroring:CoordinationAttunement', ...
        'JRQA attunement did not produce finite parameters.');
end
JRQA = struct( ...
    'tau',round(mean(tau)), ...
    'm',round(mean(m)), ...
    'ps',round(mean(ps),1));
validateJRQA(JRQA);

end


function validateJRQA(JRQA)

if ~isstruct(JRQA) || ~all(isfield(JRQA,{'tau','m'})) || ...
        ~isnumeric(JRQA.tau) || ~isscalar(JRQA.tau) || ...
        ~isfinite(JRQA.tau) || JRQA.tau < 1 || ...
        JRQA.tau ~= round(JRQA.tau) || ...
        ~isnumeric(JRQA.m) || ~isscalar(JRQA.m) || ...
        ~isfinite(JRQA.m) || JRQA.m < 1 || JRQA.m ~= round(JRQA.m)
    error('EmpaticMirroring:CoordinationJRQA', ...
        'JRQA.tau and JRQA.m must be positive integer scalars.');
end

end


function validateCoreInput(S,which_comp)

if ~isfield(S,'FREQ') || ~isstruct(S.FREQ) || ...
        ~isfield(S,'beat_frex') || ...
        ~all(isfield(S.FREQ,{'ts','pats','frex','srate'})) || ...
        ndims(S.FREQ.ts) ~= 4 || size(S.FREQ.ts,4) ~= 2 || ...
        ndims(S.FREQ.pats) ~= 4 || size(S.FREQ.pats,4) ~= 2 || ...
        size(S.FREQ.ts,1) < which_comp || ...
        size(S.FREQ.pats,2) < which_comp || ...
        ~isnumeric(S.beat_frex) || ...
        ~isequal(size(S.beat_frex),[1 2]) || ...
        any(~isfinite(S.beat_frex)) || any(S.beat_frex <= 0)
    error('EmpaticMirroring:CoordinationCoreInput', ...
        'The BLOCK 1 FREQ output is incompatible with BLOCK 3.');
end

end


function FREQ = preprocessCoordinationTimeSeries( ...
    FREQ,which_comp,config,b_butt,a_butt)

dwn = config.block3.downsample_factor;
if mod(FREQ.srate,dwn) ~= 0
    error('EmpaticMirroring:CoordinationSampleRate', ...
        'FREQ.srate must be divisible by the BLOCK 3 downsample factor.');
end
nfrex = size(FREQ.ts,3);
nsubs = size(FREQ.ts,4);
filtered = zeros(ceil(size(FREQ.ts,2)/dwn),nfrex,nsubs, ...
    'like',FREQ.ts);
for subi = 1:nsubs
    for frexi = 1:nfrex
        ts = double(squeeze(FREQ.ts(which_comp,:,frexi,subi)));
        ts = filtfilt(b_butt,a_butt,ts);
        filtered(:,frexi,subi) = cast(ts(1:dwn:end), ...
            'like',FREQ.ts);
    end
end
FREQ.ts = FREQ.ts(:,1:dwn:end,:,:);
FREQ.ts(which_comp,:,:,:) = permute(filtered,[4 1 2 3]);
FREQ.srate = FREQ.srate/dwn;

end


function frex = frequencyVector(allFrex,subi,nfrex)

if isvector(allFrex) && numel(allFrex) == nfrex
    frex = allFrex(:);
elseif isequal(size(allFrex),[nfrex 2])
    frex = allFrex(:,subi);
else
    error('EmpaticMirroring:CoordinationFrequencies', ...
        'FREQ.frex has an incompatible shape.');
end

end


function output_file = coordinationOutputFile(input_file,output_path)

[~,inputStem] = fileparts(input_file);
unitStem = erase(string(inputStem),"FREQNESS_CORE_");
output_file = string(fullfile(output_path, ...
    "FREQNESS_COORDINATION_" + unitStem + ".mat"));

end


function info = coordinationAnalysisInfo(input_file,which_comp,meter, ...
    JRQA,config,inputSrate)

info = struct( ...
    'inputCoreFile',string(input_file), ...
    'component',which_comp, ...
    'metric_levels',meter, ...
    'JRQA',JRQA, ...
    'duration',config.block3.duration, ...
    'inputSrate',inputSrate, ...
    'downsample_factor',config.block3.downsample_factor, ...
    'outputSrate',inputSrate/config.block3.downsample_factor, ...
    'lp_order',config.block3.lp_order, ...
    'lp_cutoff_norm',config.block3.lp_cutoff_norm, ...
    'antialias_cutoff_normalized_to_input_nyquist', ...
    config.block3.lp_cutoff_norm/config.block3.downsample_factor);

end


function validateCoordinationOutput(saved,analysis_info,nmeters)

required = {'FREQjrqa','FREQmirror','JRQA','which_comp','meter', ...
    'analysis_info'};
if ~all(isfield(saved,required)) || ...
        ~isequaln(saved.analysis_info,analysis_info) || ...
        ~isequaln(saved.JRQA,analysis_info.JRQA) || ...
        saved.which_comp ~= analysis_info.component || ...
        ~isequal(saved.meter,analysis_info.metric_levels)
    error('EmpaticMirroring:CoordinationOutputContract', ...
        'Existing BLOCK 3 output does not match the current configuration.');
end
validateCoordinationMetrics(saved.FREQjrqa,saved.FREQmirror,nmeters);

end


function validateCoordinationMetrics(FREQjrqa,FREQmirror,nmeters)

if ~isstruct(FREQjrqa) || numel(FREQjrqa) ~= nmeters || ...
        ~all(isfield(FREQjrqa,{'RR','DET'})) || ...
        ~isnumeric(FREQmirror) || numel(FREQmirror) ~= nmeters || ...
        any(~isfinite(FREQmirror))
    error('EmpaticMirroring:CoordinationMetrics', ...
        'BLOCK 3 produced incomplete or non-finite coordination metrics.');
end
for metri = 1:nmeters
    scalarMetric(FREQjrqa(metri).RR,'RR');
    scalarMetric(FREQjrqa(metri).DET,'DET');
end

end


function value = scalarMetric(value,name)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    error('EmpaticMirroring:CoordinationScalarMetric', ...
        'FREQjrqa.%s must be one finite numeric value.',name);
end

end
