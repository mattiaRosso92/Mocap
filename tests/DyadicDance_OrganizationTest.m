function tests = DyadicDance_OrganizationTest
% Publication boundaries, shared configuration and resumable supplementary outputs.
tests = functiontests(localfunctions);
end

function testPublicationBoundary(testCase)
repo = fileparts(fileparts(mfilename('fullpath')));
study = fullfile(repo,'Rosso_et_al_Dance_inPreparation');
files = [dir(fullfile(study,'**','*.m')); dir(fullfile(study,'**','*.R'))];
verifyTrue(testCase,all(startsWith({files.name},'DyadicDance_')));
main = fileread(fullfile(study,'DyadicDance_MainPipeline.m'));
supplementary = fileread(fullfile(study,'Supplementary','DyadicDance_Supplementary.m'));
stats = fileread(fullfile(study,'DyadicDance_Stats.R'));
comparison = fileread(fullfile(study,'Supplementary','DyadicDance_SpatialComparison.R'));
verifyTrue(testCase,contains(main,'https://doi.org/10.48557/UR2GBG'));
verifyFalse(testCase,contains(main,'reuse_legacy_jrqa'));
verifyFalse(testCase,contains(main,'legacy_spatial'));
verifyFalse(testCase,contains(main,'FREQNESS_JRQAParameters_Mocap('));
verifyFalse(testCase,contains(main,'FREQNESS_MetricProminence_Mocap('));
verifyFalse(testCase,contains(main,'FREQNESS_LandscapeSimilarity('));
verifyTrue(testCase,contains(supplementary,'FREQNESS_MetricProminence_Mocap('));
verifyTrue(testCase,contains(supplementary,'FREQNESS_LandscapeSimilarity('));
verifyFalse(testCase,contains(supplementary,'FREQNESS_TimeCoord_Mocap('));
verifyFalse(testCase,contains(stats,'JRQA'));
verifyFalse(testCase,contains(comparison,'Legacy33'));
verifyTrue(testCase,contains(comparison,'setequal(data$Dyad,1:35)'));
end

function testFinalCohortAndSupplementaryResume(testCase)
repo = fileparts(fileparts(mfilename('fullpath')));
study = fullfile(repo,'Rosso_et_al_Dance_inPreparation');
root = fullfile(repo,'Dance_Data','FREQNESS_Results_Rosso_et_al_inPreparation', ...
    'legacy_logarithmic');
metric_path = fullfile(root,'04_MetricProminence','Component_1');
similarity_path = fullfile(root,'05_LandscapeSimilarity','Component_1');
assumeTrue(testCase,numel(dir(fullfile(metric_path,'FREQNESS_METRIC_D*.mat'))) == 1119);
assumeTrue(testCase,numel(dir(fullfile(similarity_path,'FREQNESS_SIMILARITY_D*.mat'))) == 1119);
assumeTrue(testCase,isfile(fullfile(metric_path,'FREQNESS_METRIC_SUMMARY.mat')) && ...
    isfile(fullfile(similarity_path,'FREQNESS_SIMILARITY_SUMMARY.mat')) && ...
    isfile(fullfile(metric_path,'OUT2R_MetricProminence.csv')) && ...
    isfile(fullfile(similarity_path,'OUT2R_LandscapeSimilarity.csv')));
CFG = configure(study);
verifyEqual(testCase,CFG.common.list_dyads,1:35);
verifyEqual(testCase,sum(CFG.common.trial_counts,'all'),1119);
verifyEqual(testCase,CFG.common.trial_counts(13,:),[7 8 9 8]);
verifyEqual(testCase,CFG.common.trial_counts(32,:),[8 8 8 7]);
verifyFalse(testCase,CFG.block4.overwrite_flag || CFG.block5.overwrite_flag);
before = [dir(fullfile(metric_path,'*')); dir(fullfile(similarity_path,'*'))];
code = fileread(fullfile(study,'Supplementary','DyadicDance_Supplementary.m'));
block = code(strfind(code,'%% BLOCK 4 -'):strfind(code,'%% BLOCK S1 -')-1);
execute_block(CFG,block);
after = [dir(fullfile(metric_path,'*')); dir(fullfile(similarity_path,'*'))];
verifyEqual(testCase,{after.name},{before.name});
verifyEqual(testCase,[after.bytes],[before.bytes]);
verifyEqual(testCase,[after.datenum],[before.datenum]);
end

function CFG = configure(study)
run(fullfile(study,'Supporting','DyadicDance_Configuration.m'));
end

function execute_block(CFG,code)
eval(code);
end
