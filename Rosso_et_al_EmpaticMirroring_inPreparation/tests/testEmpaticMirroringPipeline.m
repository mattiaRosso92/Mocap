function tests = testEmpaticMirroringPipeline
%TESTEMPATICMIRRORINGPIPELINE Regression tests for the linear study script.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
studyRoot = fileparts(testRoot);
pipelineFile = fullfile(studyRoot,'EmpaticMirroring_MainPipeline.m');

testCase.TestData.studyRoot = studyRoot;
testCase.TestData.pipelineFile = pipelineFile;
testCase.TestData.pipelineText = fileread(pipelineFile);
testCase.TestData.outputRoot = fullfile(studyRoot,'outputs');

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
    'FREQNESS_PhaseSpaceRQA_Mocap', ...
    'FREQNESS_SpaceCoord_Mocap', ...
    'FREQNESS_LandscapeSimilarity', ...
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
    'landscape = FREQ.evals(prominence_component,:,participant_role)'));
verifyTrue(testCase,contains(moduleText,'OUT2R_NetworkProminence.csv'));
verifyTrue(testCase,contains(moduleText,'OUT2R_GlobalMetricProminence.csv'));
verifyTrue(testCase,contains(moduleText, ...
    'nonmetric_indices = setdiff(1:numel(participant_grid),global_metric_indices);'));
verifyTrue(testCase,contains(moduleText,'for metri = 1:nmeters'));
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
