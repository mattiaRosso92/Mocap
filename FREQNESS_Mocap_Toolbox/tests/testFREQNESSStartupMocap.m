function tests = testFREQNESSStartupMocap
%TESTFREQNESSSTARTUPMOCAP Categorized paths and dataset-free pipeline startup.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

toolbox_root = fileparts(fileparts(mfilename('fullpath')));
fixture_root = tempname;
mkdir(fixture_root);
testCase.TestData.fixture_root = fixture_root;
testCase.TestData.original_path = path;
testCase.TestData.original_folder = pwd;

% Copy code only: tests must not load the user's datasets.
files = {'FREQNESS_Startup_Mocap.m','FREQNESS_MainPipeline_Mocap.m', ...
    'FREQNESS_Functions','FREQNESS_ExternalFunctions'};
for filei = 1:numel(files)
    copyfile(fullfile(toolbox_root,files{filei}), ...
        fullfile(fixture_root,files{filei}));
end
mkdir(fullfile(fixture_root,'FREQNESS_Data'));
mkdir(fullfile(fixture_root,'FREQNESS_ExampleScripts'));
addpath(fixture_root);
cd(fixture_root);

end


function teardownOnce(testCase)

cd(testCase.TestData.original_folder);
path(testCase.TestData.original_path);
rmdir(testCase.TestData.fixture_root,'s');

end


function testStartupFindsPublicFunctionsAndKeepsPrivateFoldersOffPath(testCase)

[allData,dataLabels,path_home] = FREQNESS_Startup_Mocap();
verifyEmpty(testCase,allData);
verifyEmpty(testCase,dataLabels);
verifyEqual(testCase,path_home,testCase.TestData.fixture_root);

folders = {'Analysis','Visualization','Supporting'};
for folderi = 1:numel(folders)
    this_folder = fullfile(path_home,'FREQNESS_Functions',folders{folderi});
    files = dir(fullfile(this_folder,'*.m'));
    verifyNotEmpty(testCase,files);
    for filei = 1:numel(files)
        [~,function_name] = fileparts(files(filei).name);
        verifyEqual(testCase,which(function_name), ...
            fullfile(this_folder,files(filei).name));
    end
end
path_entries = strsplit(path,pathsep);
verifyFalse(testCase,ismember(fullfile(path_home,'FREQNESS_Functions', ...
    'Analysis','private'),path_entries));
verifyFalse(testCase,ismember(fullfile(path_home,'FREQNESS_ExternalFunctions', ...
    'private'),path_entries));

end


function testMainPipelineUsesStartupWithoutDatasets(testCase)

[allData,dataLabels,path_home] = run_empty_pipeline();
verifyEmpty(testCase,allData);
verifyEmpty(testCase,dataLabels);
verifyEqual(testCase,path_home,testCase.TestData.fixture_root);

end


function [all_data,data_labels,path_toolbox] = run_empty_pipeline()

% Keep the script's clear command confined to this helper workspace.
FREQNESS_MainPipeline_Mocap
all_data = allData;
data_labels = dataLabels;
path_toolbox = path_home;

end
