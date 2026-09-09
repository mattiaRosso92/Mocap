function tests = testFREQNESSStudyFilterCalibration
%TESTFREQNESSSTUDYFILTERCALIBRATION Study-level FWHM provenance safeguards.

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
    'isequal(saved_core.GED.fwhm,'));
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
