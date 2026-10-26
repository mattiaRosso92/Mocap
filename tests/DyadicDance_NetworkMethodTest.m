function tests = DyadicDance_NetworkMethodTest
% Exercise the actual BLOCK 1 on one synthetic dyad, outside study outputs.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repo = fileparts(fileparts(mfilename('fullpath')));
toolbox = fullfile(repo,'FREQNESS_Mocap_Toolbox');
addpath(genpath(fullfile(toolbox,'FREQNESS_Functions')));
addpath(fullfile(toolbox,'FREQNESS_ExternalFunctions'));
code = fileread(fullfile(repo,'Rosso_et_al_Dance_inPreparation', ...
    'DyadicDance_MainPipeline.m'));
testCase.TestData.block1 = code(strfind(code,'%% BLOCK 1 -'): ...
    strfind(code,'%% BLOCK 2 -')-1);
testCase.TestData.block2_guard = code(strfind(code,'% Publication blocks retain GED;'): ...
    strfind(code,'% Choose if you want to enable saving')-1);
end

function testMethodsUseSeparateFilesAndResumeWithoutWrites(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root,'s'));
rng(157);
for subi = 1:2
    path_data = fullfile(root,'Dyad_01',['subj' num2str(subi)]);
    mkdir(path_data);
    % Nine raw coordinates; BLOCK 1 removes the last XYZ triplet.
    writematrix([zeros(1,481); (1:9)' randn(9,480)], ...
        fullfile(path_data,'tr01.csv'));
    writematrix([0 0; 1 subi-1],fullfile(root,['song_subj' num2str(subi) '.csv']));
end
execute_block(testCase.TestData.block1,root,'GED');
ged_file = fullfile(root,'FREQNESS_CORE_D1_C1_T1.mat');
ged_before = dir(ged_file);
GED = load(ged_file,'GED');
verifyEqual(testCase,GED.GED.method,'ged');
verifyEqual(testCase,GED.GED.kinematics,'position');

execute_block(testCase.TestData.block1,root,'PCA');
pca_file = fullfile(root,'FREQNESS_CORE_D1_C1_T1_PCA.mat');
assertTrue(testCase,isfile(pca_file));
PCA = load(pca_file,'PCA');
verifyEqual(testCase,PCA.PCA.method,'pca');
verifyEqual(testCase,PCA.PCA.kinematics,'position');
verifyEqual(testCase,PCA.PCA.fwhm,GED.GED.fwhm);
verifyEqual(testCase,PCA.PCA.frex,GED.GED.frex);
verifySize(testCase,PCA.PCA.evals,[6 32 2]);
verifyEqual(testCase,dir(ged_file),ged_before);

pca_before = dir(pca_file);
execute_block(testCase.TestData.block1,root,'PCA');
execute_block(testCase.TestData.block1,root,'GED');
verifyEqual(testCase,dir(pca_file),pca_before);
verifyEqual(testCase,dir(ged_file),ged_before);
end

function testPCACannotEnterPublicationBlocks(testCase)
did_throw = false;
try
    execute_guard(testCase.TestData.block2_guard,'PCA');
catch exception
    did_throw = true;
    verifySubstring(testCase,exception.message,'BLOCKS 2-8 use manuscript GED outputs.');
end
verifyTrue(testCase,did_throw);
execute_guard(testCase.TestData.block2_guard,'GED');
end

function execute_guard(code,which_method)
eval(code);
end

function execute_block(code,root,which_method)
CFG = struct();
CFG.common = struct('trial_indices',{{1}},'trial_counts',1, ...
    'reuse_core_path',root,'filter_width_calibration','legacy', ...
    'filter_type','logarithmic','ncomps',2);
CFG.block1 = struct('output_path',root,'overwrite_flag',false);
path_home = root;
prefix = {''};
idx_XYZ = 1;
nconds = 1;
list_dyads = 1;
nsubs = 2;
sublabels = {'1','2'};
song_bpms = [120 150];
srate = 120;
save_flag = 1;
vis_flag = 0;
eval(code);
end
