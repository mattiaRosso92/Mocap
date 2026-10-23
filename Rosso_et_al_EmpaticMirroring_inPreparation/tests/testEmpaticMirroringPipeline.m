function tests = testEmpaticMirroringPipeline
%TESTEMPATICMIRRORINGPIPELINE Regression tests for the linear study script.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
studyRoot = fileparts(testRoot);
pipelineFile = fullfile(studyRoot,'EmpaticMirroring_MainPipeline.m');
statisticsFile = fullfile(studyRoot,'EmpaticMirroring_Stats.R');

testCase.TestData.studyRoot = studyRoot;
testCase.TestData.pipelineFile = pipelineFile;
testCase.TestData.pipelineText = fileread(pipelineFile);
testCase.TestData.statisticsText = fileread(statisticsFile);
testCase.TestData.outputRoot = fullfile(studyRoot,'outputs');

end


function testProminenceRetainsInstructionFactor(testCase)

statisticsText = testCase.TestData.statisticsText;
requiredStatements = { ...
    'mutate(ModelOutcome = LogMetricProminence)', ...
    'mutate(ModelOutcome = LogGlobalMetricProminence)', ...
    'include_meter = TRUE, include_instruction = TRUE', ...
    'include_meter = FALSE, include_instruction = TRUE', ...
    'prominence_model, ~ Complexity | Instruction * Movement * Meter', ...
    'global_prominence_model, ~ Complexity | Instruction * Movement', ...
    'prominence_model, ~ Complexity | Version', ...
    'prominence_model, ~ Version | Movement'};

for statementi = 1:numel(requiredStatements)
    verifyTrue(testCase,contains(statisticsText,requiredStatements{statementi}), ...
        sprintf('Missing prominence-factor contract: %s', ...
        requiredStatements{statementi}));
end
verifyTrue(testCase,contains(testCase.TestData.pipelineText, ...
    'Instruction retained as a design factor'));
verifyFalse(testCase,contains(statisticsText,'InstructionNormalized'));
verifyFalse(testCase,contains(statisticsText,'mirroring/observation'));

end


function testPipelineIsOneReadableScript(testCase)

pipelineText = testCase.TestData.pipelineText;
verifyEmpty(testCase,regexp(pipelineText,'(?m)^\s*function\b','once'));
verifyEmpty(testCase,regexp(pipelineText, ...
    'EmpaticMirroring_[A-Za-z0-9_]+\s*\(','once'));
verifyEmpty(testCase,dir(fullfile(testCase.TestData.studyRoot, ...
    'functions','*.m')));

end


function testAnalysisSectionsAreChronological(testCase)

pipelineText = testCase.TestData.pipelineText;
headings = { ...
    '%% DATA PREPARATION - FRAME COUNTS, GAPS, AND RECORDING QC', ...
    '%% DATA PREPARATION - ARTIFICIAL DYADS', ...
    '%% BLOCK 1 - FREQ-NESS CORE NETWORK ESTIMATION', ...
    '%% BLOCK 2 - ROLE-SPECIFIC LANDSCAPES AND EFFECTIVE DIMENSIONALITY', ...
    '%% BLOCK 3 - INTERACTION ANALYSES', ...
    '%% BLOCK 4 - GROUP SUMMARIES AND FIGURES', ...
    '%% BLOCK 5 - R-READY STATISTICAL EXPORTS', ...
    '%% PARTICIPANT METRIC-PROMINENCE MODULE', ...
    '%% BLOCK 6 - MIXED-EFFECTS MODELS IN R'};

locations = nan(size(headings));
for headingi = 1:numel(headings)
    location = strfind(pipelineText,headings{headingi});
    verifyNumElements(testCase,location,1);
    locations(headingi) = location;
end
verifyGreaterThan(testCase,diff(locations),zeros(1,numel(locations)-1));

rqaLocation = strfind(pipelineText,'BLOCK 3A: phase-space RQA');
spatialLocation = strfind(pipelineText, ...
    'BLOCK 3B-3C: spatial coordination and landscape similarity');
verifyNumElements(testCase,rqaLocation,1);
verifyNumElements(testCase,spatialLocation,1);
verifyLessThan(testCase,rqaLocation,spatialLocation);

end


function testPipelineCallsGeneralToolboxFunctionsDirectly(testCase)

pipelineText = testCase.TestData.pipelineText;
toolboxFunctions = { ...
    'FREQNESS_InterpolateGaps_Mocap', ...
    'FREQNESS_ComputeFilterWidths_Mocap', ...
    'FREQNESS_ComputeLegacyFilterWidths_Mocap', ...
    'FREQNESS_NetworkEstimation_Mocap', ...
    'FREQNESS_EffectDim_Mocap', ...
    'FREQNESS_TimeCoord_Mocap', ...
    'FREQNESS_SpaceCoord_Mocap', ...
    'FREQNESS_LandscapeSimilarity', ...
    'FREQNESS_MetricProminence_Mocap', ...
    'FREQNESS_Visualizer_Mocap'};

for functioni = 1:numel(toolboxFunctions)
    verifyTrue(testCase,contains(pipelineText,toolboxFunctions{functioni}), ...
        sprintf('%s is not called directly.',toolboxFunctions{functioni}));
end

end


function testScientificConfigurationIsExplicit(testCase)

pipelineText = testCase.TestData.pipelineText;
requiredStatements = { ...
    'analysis_duration = 33;', ...
    'participant_offset = 0;', ...
    'srate_teacher = 300;', ...
    'srate_participant = 120;', ...
    'rqa_standardize = true;', ...
    'beat_frex = 1.67*ones(1,2);', ...
    'prominence_component = 1;', ...
    'global_metric_levels = [.25 .5 1 2 3 4];', ...
    'filter_width_calibration = validatestring(', ...
    '''legacy'',{''physical'',''legacy''});', ...
    'FREQNESS_ComputeLegacyFilterWidths_Mocap(', ...
    'isequal(saved.FREQ.fwhm,expected_filter_width)', ...
    'short_gap_seconds = .050;', ...
    'maximum_reconstructed_gap_seconds = 2;', ...
    'marklabels = {''L Elbow''', ...
    'bones = [20,22;', ...
    '''bad_segments'',saved_dyad.bad_segments', ...
    'FREQ.bad_segments = find(~downsampled_valid);'};

for statementi = 1:numel(requiredStatements)
    verifyTrue(testCase,contains(pipelineText,requiredStatements{statementi}), ...
        sprintf('Missing configuration: %s',requiredStatements{statementi}));
end

end


function testOrganizedToolboxPathsAndEstimatorGuard(testCase)

code = testCase.TestData.pipelineText;
path_toolbox = fullfile(fileparts(testCase.TestData.studyRoot),'FREQNESS_Mocap_Toolbox');
original_path = path;
cleanup = onCleanup(@() path(original_path));
active_paths = strsplit(original_path,pathsep);
toolbox_paths = strcmp(active_paths,path_toolbox) | ...
    startsWith(active_paths,[path_toolbox filesep]);
if any(toolbox_paths); rmpath(active_paths{toolbox_paths}); end
first = strfind(code,'addpath(path_toolbox)');
last = strfind(code,'output_paths =');
eval(code(first:last-1));

verifyEqual(testCase,which('FREQNESS_TimeCoord_Mocap'), ...
    fullfile(path_toolbox,'FREQNESS_Functions','Analysis','FREQNESS_TimeCoord_Mocap.m'));
verifyEqual(testCase,which('FREQNESS_Visualizer_Mocap'), ...
    fullfile(path_toolbox,'FREQNESS_Functions','Visualization','FREQNESS_Visualizer_Mocap.m'));
verifyEqual(testCase,which('FREQNESS_InterpolateGaps_Mocap'), ...
    fullfile(path_toolbox,'FREQNESS_Functions','Supporting','FREQNESS_InterpolateGaps_Mocap.m'));

% Execute the existing source guard without writing its QC table.
first = strfind(code,'estimator_file =');
last = strfind(code,'networkEstimatorContract =');
eval(code(first:last-1));
verifyEqual(testCase,estimator_file,which('FREQNESS_NetworkEstimation_Mocap'));
verifyTrue(testCase,ReadyForNetworkEstimation);

end


function testTimeCoordMatchesFormerCallWithGaps(testCase)

code = testCase.TestData.pipelineText;
path_toolbox = fullfile(fileparts(testCase.TestData.studyRoot),'FREQNESS_Mocap_Toolbox'); %#ok<NASGU>
original_path = path;
cleanup = onCleanup(@() path(original_path));
first = strfind(code,'addpath(path_toolbox)');
last = strfind(code,'output_paths =');
eval(code(first:last-1));

% Read only the current scientific settings, without starting the pipeline.
last = strfind(code,'% Group figures and statistical export.');
settings = regexp(code(1:last-1), ...
    '(?m)^(?:srate|beat_frex|frex_vector|frex|meter|components|rqa_\w+) = [^\r\n]+','match');
eval(strjoin(settings,newline));
first = strfind(code,'rqa_sampling_ratio =');
last = strfind(code,'if run_blocks(3)');
eval(code(first:last(1)-1));

% Full study duration/grid, including an interior run too short to filter.
time = (0:33*srate-1)/srate;
S.FREQ = struct('ts',zeros(2,numel(time),size(frex,1),2), ...
    'frex',frex,'srate',srate, ...
    'bad_segments',[1:5 1001:1020 1026:1030 2001:2020 3956:3960]);
S.beat_frex = beat_frex;
for subi = 1:2
    for compi = components
        for frexi = 1:size(frex,1)
            S.FREQ.ts(compi,:,frexi,subi) = subi+compi* ...
                sin(2*pi*frex(frexi,subi)*time+.2*subi)+.2*sin(2*pi*20*time);
        end
    end
end
first = strfind(code,'FREQ = S.FREQ; dwn =');
last = strfind(code,'FREQrqa = FREQNESS_TimeCoord_Mocap(');
preprocessing_code = code(first:last-1);
call_code = regexp(code, ...
    'FREQrqa = FREQNESS_TimeCoord_Mocap\([\s\S]*?;','match','once');
assertTrue(testCase,contains(call_code,'''method'',''phase_space'''));
for which_comp = components
    eval(preprocessing_code);
    expected = FREQNESS_PhaseSpaceRQA_Mocap(FREQ,S.beat_frex, ...
        'metric_levels',meter,'component',which_comp,'duration',rqa_duration, ...
        'standardize',rqa_standardize,'threshold_method',rqa_threshold_method, ...
        'threshold',rqa_threshold,'theiler_window',rqa_theiler_window, ...
        'lmin',rqa_lmin,'vmin',rqa_vmin,'store_matrices',rqa_store_matrices, ...
        'figure',rqa_figure,'animate',rqa_animate,'srate',FREQ.srate);
    eval(call_code);
    verifyEqual(testCase,FREQrqa,expected);
    verifyTrue(testCase,all([FREQrqa.Standardized]));
    verifyGreaterThan(testCase,[FREQrqa.ExcludedSampleCount],zeros(1,numel(meter)));
    verifyEqual(testCase,FREQ.srate,24);
    verifyEqual(testCase,preprocessing_qc.LowpassCutoffHz,9.6);
    verifyEqual(testCase,preprocessing_qc.ShortRunExcludedSampleCount,5);
end

end


function testRQAAntialiasingPrecedesIntegerDecimation(testCase)

pipelineText = testCase.TestData.pipelineText;
requiredStatements = { ...
    'rqa_target_srate = 24;', ...
    'rqa_antialias_filter_order = 4;', ...
    'rqa_antialias_cutoff_hz = 9.6;', ...
    'rqa_preprocessing_version = "gap_aware_antialias_v2";', ...
    'rqa_sampling_ratio = srate/rqa_target_srate;', ...
    'rqa_antialias_cutoff_hz < rqa_target_nyquist_hz', ...
    'rqa_antialias_cutoff_hz/(srate/2)', ...
    'filtered(indices,:) = filtfilt(b_butt,a_butt,double(selected(indices,:)));', ...
    'sample_indices = 1:dwn:ntime;', ...
    '''preprocessing_version'',rqa_preprocessing_version', ...
    '''antialias_policy'',"zero_phase_lowpass_before_integer_decimation"', ...
    '''Version'',rqa_preprocessing_version', ...
    '''LowpassCutoffHz'',rqa_antialias_cutoff_hz'};

for statementi = 1:numel(requiredStatements)
    verifyTrue(testCase,contains(pipelineText,requiredStatements{statementi}), ...
        sprintf('Missing RQA anti-aliasing safeguard: %s', ...
        requiredStatements{statementi}));
end
verifyFalse(testCase,contains(pipelineText,'rqa_lp_cutoff_norm ='));

rqaStart = strfind(pipelineText,'%% BLOCK 3 - INTERACTION ANALYSES');
rqaEnd = strfind(pipelineText, ...
    'BLOCK 3B-3C: spatial coordination and landscape similarity');
verifyNumElements(testCase,rqaStart,1);
verifyNumElements(testCase,rqaEnd,1);
rqaText = pipelineText(rqaStart:rqaEnd-1);
filterLocation = strfind(rqaText, ...
    'filtered(indices,:) = filtfilt(b_butt,a_butt,double(selected(indices,:)));');
decimationLocation = strfind(rqaText,'sample_indices = 1:dwn:ntime;');
verifyNumElements(testCase,filterLocation,1);
verifyNumElements(testCase,decimationLocation,1);
verifyLessThan(testCase,filterLocation,decimationLocation);

inputSrate = 120;
targetSrate = 24;
cutoffHz = 9.6;
downsampleFactor = inputSrate/targetSrate;
[b,a] = butter(4,cutoffHz/(inputSrate/2),'low');
time = (0:inputSrate*30-1)'/inputSrate;
signal = sin(2*pi*2*time)+sin(2*pi*20*time);
filtered = filtfilt(b,a,signal);
downsampled = filtered(1:downsampleFactor:end);
downsampledTime = time(1:downsampleFactor:end);
mask = downsampledTime >= 3 & downsampledTime < 27;
downsampled = downsampled(mask);
downsampledTime = downsampledTime(mask);
passbandAmplitude = 2/numel(downsampled)*abs(sum(downsampled.* ...
    exp(-1i*2*pi*2*downsampledTime)));
aliasedAmplitude = 2/numel(downsampled)*abs(sum(downsampled.* ...
    exp(-1i*2*pi*4*downsampledTime)));
verifyGreaterThan(testCase,passbandAmplitude,.9);
verifyLessThan(testCase,aliasedAmplitude,.01);
verifyLessThan(testCase,aliasedAmplitude/passbandAmplitude,.01);

end


function testRQARejectsIncompatibleCachedPreprocessing(testCase)

pipelineText = testCase.TestData.pipelineText;
requiredStatements = { ...
    'required_fields = {''preprocessing_version'',''inputSrate''', ...
    'metadata_compatible = isfield(saved,''FREQrqa'')', ...
    'string(saved.analysis_info.preprocessing_version)', ...
    'saved.analysis_info.antialias_cutoff_hz', ...
    'FREQNESS:EmpaticMirroring:StaleRQAOutput', ...
    'if reuse_existing'};

for statementi = 1:numel(requiredStatements)
    verifyTrue(testCase,contains(pipelineText,requiredStatements{statementi}), ...
        sprintf('Missing RQA cache safeguard: %s',requiredStatements{statementi}));
end

end


function testFilterCalibrationOutputsAreSeparated(testCase)

pipelineText = testCase.TestData.pipelineText;
requiredStatements = { ...
    'filter_output_tag = [filter_width_calibration ''_'' filter_type];', ...
    'path_output = fullfile(path_study,''outputs'',filter_output_tag);', ...
    'FREQ.filter_width_calibration = string(filter_width_calibration);', ...
    '''filterWidthCalibration'',string(filter_width_calibration)', ...
    '''fwidth'',FREQ.fwhm'};

for statementi = 1:numel(requiredStatements)
    verifyTrue(testCase,contains(pipelineText,requiredStatements{statementi}), ...
        sprintf('Missing calibration safeguard: %s', ...
        requiredStatements{statementi}));
end

end


function testProductionOutputContract(testCase)

outputRoot = testCase.TestData.outputRoot;
dyadManifestFile = fullfile(outputRoot,'qc','artificial_dyad_manifest.csv');
coreManifestFile = fullfile(outputRoot,'qc','core_analysis_manifest.csv');
allComponentsFile = fullfile(outputRoot,'05_Statistics_R', ...
    'OUT2R_AllComponents.csv');
similarityFile = fullfile(outputRoot,'05_Statistics_R', ...
    'OUT2R_LandscapeSimilarity.csv');
prominenceFile = fullfile(outputRoot,'05_Statistics_R', ...
    'OUT2R_NetworkProminence.csv');
globalProminenceFile = fullfile(outputRoot,'05_Statistics_R', ...
    'OUT2R_GlobalMetricProminence.csv');

assumeTrue(testCase,isfile(dyadManifestFile) && isfile(coreManifestFile) && ...
    isfile(allComponentsFile) && isfile(similarityFile) && ...
    isfile(prominenceFile) && isfile(globalProminenceFile), ...
    'Production outputs are unavailable; output-contract test skipped.');

dyads = readtable(dyadManifestFile,'TextType','string');
core = readtable(coreManifestFile,'TextType','string');
allComponents = readtable(allComponentsFile,'TextType','string');
similarity = readtable(similarityFile,'TextType','string');
prominence = readtable(prominenceFile,'TextType','string');
globalProminence = readtable(globalProminenceFile,'TextType','string');

usableDyads = ismember(dyads.DyadStatus,["created" "existing"]);
usableCore = ismember(core.CoreStatus,["created" "computed" "existing"]);
verifyEqual(testCase,nnz(usableDyads),1951);
verifyEqual(testCase,nnz(usableCore),1951);
verifyEqual(testCase,height(allComponents),8864);
verifyEqual(testCase,height(similarity),2216);
verifyEqual(testCase,height(prominence),4432);
verifyEqual(testCase,height(globalProminence),1108);
verifyEqual(testCase,numel(unique(allComponents.Participant)),52);
verifyEqual(testCase,sort(unique(allComponents.Component))',[1 2]);
verifyEqual(testCase,sort(unique(allComponents.MeterLevel))',[.25 .5 1 2]);
verifyEqual(testCase,unique(prominence.Component),1);
verifyEqual(testCase,sort(unique(prominence.MeterLevel))',[.25 .5 1 2]);
verifyEqual(testCase,sort(unique(prominence.FrequencyHz))', ...
    1.67*[.25 .5 1 2],'AbsTol',1e-12);
verifyGreaterThanOrEqual(testCase,prominence.RawProminencePercent, ...
    zeros(height(prominence),1));
verifyLessThanOrEqual(testCase,prominence.RawProminencePercent, ...
    100*ones(height(prominence),1));
verifyGreaterThan(testCase,prominence.NonMetricBaselinePercent, ...
    zeros(height(prominence),1));
verifyGreaterThan(testCase,prominence.MetricProminenceRatio, ...
    zeros(height(prominence),1));
verifyEqual(testCase,prominence.LogMetricProminence, ...
    log(prominence.MetricProminenceRatio),'AbsTol',1e-12);
verifyEqual(testCase,unique(globalProminence.Component),1);
verifyGreaterThan(testCase,globalProminence.NonMetricBaselinePercent, ...
    zeros(height(globalProminence),1));
verifyGreaterThan(testCase,globalProminence.GlobalMetricProminenceRatio, ...
    zeros(height(globalProminence),1));
verifyEqual(testCase,globalProminence.LogGlobalMetricProminence, ...
    log(globalProminence.GlobalMetricProminenceRatio),'AbsTol',1e-12);

end


function testMetricProminenceIsSelfContained(testCase)

pipelineText = testCase.TestData.pipelineText;
startLocation = strfind(pipelineText, ...
    '%% PARTICIPANT METRIC-PROMINENCE MODULE');
endLocation = strfind(pipelineText, ...
    '%% BLOCK 6 - MIXED-EFFECTS MODELS IN R');
verifyNumElements(testCase,startLocation,1);
verifyNumElements(testCase,endLocation,1);
moduleText = pipelineText(startLocation:endLocation-1);
verifyTrue(testCase,contains(moduleText, ...
    "load(analysisRows.CoreFile(analysisi),'FREQ')"));
verifyTrue(testCase,contains(moduleText, ...
    'METER = FREQNESS_MetricProminence_Mocap('));
verifyTrue(testCase,contains(moduleText, ...
    'METER.MetricProminence'));
verifyTrue(testCase,contains(moduleText, ...
    'METER.GlobalProminence'));
verifyTrue(testCase,contains(moduleText,'OUT2R_NetworkProminence.csv'));
verifyTrue(testCase,contains(moduleText,'OUT2R_GlobalMetricProminence.csv'));
verifyFalse(testCase,contains(moduleText,'nonmetric_indices ='));
verifyFalse(testCase,contains(moduleText,'global_metric_indices ='));
verifyFalse(testCase,contains(moduleText,'metricProminenceRatioTrial(participanti,condi,metri,repetitioni) ='));
verifyFalse(testCase,contains(moduleText,'FREQNESS_NetworkEstimation_Mocap('));

end


function testCoreOutputRetainsBadSegments(testCase)

manifestFile = fullfile(testCase.TestData.outputRoot,'qc', ...
    'core_analysis_manifest.csv');
assumeTrue(testCase,isfile(manifestFile), ...
    'Production core manifest is unavailable; FREQ contract test skipped.');

manifest = readtable(manifestFile,'TextType','string');
row = find(ismember(manifest.CoreStatus, ...
    ["created" "computed" "existing"]),1);
assumeFalse(testCase,isempty(row));
saved = load(manifest.CoreFile(row),'FREQ');

verifyTrue(testCase,isfield(saved,'FREQ'));
verifyTrue(testCase,isfield(saved.FREQ,'bad_segments'));
verifyTrue(testCase,isfield(saved.FREQ,'evals'));
verifyTrue(testCase,isfield(saved.FREQ,'frex'));
verifyEqual(testCase,size(saved.FREQ.evals,3),2);
verifyGreaterThan(testCase,numel(saved.FREQ.bad_segments),0);

end


function testParityAuditPasses(testCase)

auditFile = fullfile(testCase.TestData.outputRoot,'09_CleanupValidation', ...
    'FlattenedPipeline_NumericalParity.csv');
assumeTrue(testCase,isfile(auditFile), ...
    'No reference parity audit was requested; parity test skipped.');

audit = readtable(auditFile,'TextType','string');
verifyEqual(testCase,height(audit),47);
verifyTrue(testCase,all(audit.ExactlyEqual));
verifyEqual(testCase,audit.MaximumAbsoluteDifference,zeros(height(audit),1));

end
