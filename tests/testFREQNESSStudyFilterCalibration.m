function tests = testFREQNESSStudyFilterCalibration
%TESTFREQNESSSTUDYFILTERCALIBRATION Study filter provenance and toolbox paths.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
repoRoot = fileparts(testRoot);
testCase.TestData.empatic = fileread(fullfile(repoRoot, ...
    'Rosso_et_al_EmpaticMirroring_inPreparation', ...
    'EmpaticMirroring_MainPipeline.m'));
testCase.TestData.dance = fileread(fullfile(repoRoot, ...
    'Rosso_et_al_Dance_inPreparation','FREQNESS_DyadicDance_Mocap.m'));
testCase.TestData.orchestra = fileread(fullfile(repoRoot, ...
    'Rosso_et_al_Orchestra_inPreparation','FREQNESS_Orchestra_Main.m'));

end


function testEveryStudyDefaultsToLegacyWithExplicitPhysicalOptIn(testCase)

study_text = {testCase.TestData.empatic, ...
    testCase.TestData.dance,testCase.TestData.orchestra};
required_text = { ...
    '''legacy'',{''physical'',''legacy''}', ...
    'FREQNESS_ComputeLegacyFilterWidths_Mocap(', ...
    '''fwidth'',filter_width', ...
    'filter_width_calibration'};

for studyi = 1:numel(study_text)
    for texti = 1:numel(required_text)
        verifyTrue(testCase,contains(study_text{studyi}, ...
            required_text{texti}),sprintf( ...
            'Study %d lacks required filter calibration text: %s', ...
            studyi,required_text{texti}));
    end
end

end


function testCalibrationOutputsAreIsolated(testCase)

verifyTrue(testCase,contains(testCase.TestData.empatic, ...
    'path_output = fullfile(path_study,''outputs'',filter_output_tag);'));
verifyTrue(testCase,contains(testCase.TestData.dance, ...
    'CFG.common.filter_output_tag'));
verifyTrue(testCase,contains(testCase.TestData.dance, ...
    'CFG.common.results_folder = fullfile('));
verifyTrue(testCase,contains(testCase.TestData.dance, ...
    'isequal(size(saved_fwhm),size(saved_expected_filter_width))'));
verifyTrue(testCase,contains(testCase.TestData.dance, ...
    'max(abs(saved_fwhm-saved_expected_filter_width),[],''all'') < 1e-12'));
verifyTrue(testCase,contains(testCase.TestData.orchestra, ...
    'fullfile(path_home,''GED_output'',filter_output_tag)'));

end


function testGEDOutputsRetainCalibrationProvenance(testCase)

texts = {testCase.TestData.empatic, ...
    testCase.TestData.dance,testCase.TestData.orchestra};

for studyi = 1:numel(texts)
    verifyTrue(testCase,contains(texts{studyi}, ...
        '.filter_width_calibration = string('));
    verifyTrue(testCase,contains(texts{studyi}, ...
        '''filterWidthCalibration'''));
    verifyTrue(testCase,contains(texts{studyi},'''fwidth'''));
end

end


function testOrchestraSetupResolvesOrganizedToolboxFunctions(testCase)

code = testCase.TestData.orchestra;
path_repo = fileparts(fileparts(mfilename('fullpath')));
path_toolbox = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');
original_path = path;
cleanup = onCleanup(@() path(original_path));
active_paths = strsplit(original_path,pathsep);
toolbox_paths = strcmp(active_paths,path_toolbox) | ...
    startsWith(active_paths,[path_toolbox filesep]);
if any(toolbox_paths); rmpath(active_paths{toolbox_paths}); end

% Execute path setup only, without importing data or saving study outputs.
first = strfind(code,'addpath(path_toolbox)');
last = strfind(code,'%% Prepare data');
eval(code(first:last-1));
function_calls = regexp(code,'(FREQNESS_\w+)\s*\(','tokens');
assertNumElements(testCase,function_calls,4);
for functioni = 1:numel(function_calls)
    function_name = function_calls{functioni}{1};
    file = dir(fullfile(path_toolbox,'FREQNESS_Functions','**',[function_name '.m']));
    assertNumElements(testCase,file,1);
    verifyEqual(testCase,which(function_name),fullfile(file.folder,file.name));
end
verifyFalse(testCase,ismember(fullfile(path_toolbox,'FREQNESS_Functions', ...
    'Analysis','private'),strsplit(path,pathsep)));

end
