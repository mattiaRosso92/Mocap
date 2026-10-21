function tests = testFREQNESSDanceSpatialPipeline
% Spatial recovery/export regression using the actual study blocks.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repo = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.code = fileread(fullfile(repo, ...
    'Rosso_et_al_Dance_inPreparation','FREQNESS_DyadicDance_Mocap.m'));
folder = tempname;
mkdir(folder);
testCase.TestData.folder = folder;
CFG.common = struct('data_path',fullfile(repo,'Dance_Data'), ...
    'ncomps',2,'list_dyads',[1 13 32],'ntrials',1, ...
    'reuse_results_path','','reuse_core_path','');
CFG.common.trial_counts = zeros(35,4);
CFG.common.trial_counts(CFG.common.list_dyads,:) = 1;
CFG.common.trial_indices = cell(35,4);
CFG.block1.output_path = fullfile(folder,'core');
CFG.block3 = struct('components',1:2,'compute_jrqa',false, ...
    'output_path',fullfile(folder,'spatial'),'overwrite_flag',false);
CFG.block8 = struct('output_path',fullfile(folder,'export'),'overwrite_flag',false);
mkdir(CFG.block1.output_path); mkdir(CFG.block8.output_path);
rng(21);
beat_frex = [1.8 2.1];
GED = struct('frex',(1:32)'/8.*beat_frex);
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        id_trial = condi+10;
        CFG.common.trial_indices{dyadi,condi} = id_trial;
        GED.pats = randn(66,2,32,2);
        save(fullfile(CFG.block1.output_path,sprintf( ...
            'FREQNESS_CORE_D%d_C%d_T1.mat',dyadi,condi)), ...
            'GED','beat_frex','id_trial','-v7.3');
    end
end
testCase.TestData.CFG = CFG;
end

function testSpatialOnlyAndRawFisherExport(testCase)
CFG = testCase.TestData.CFG;
code = testCase.TestData.code;
block3 = code(strfind(code,'%% BLOCK 3 -'):strfind(code,'%% BLOCK 4 -')-1);
execute_block(CFG,block3);
block8 = code(strfind(code,'%% BLOCK 8 -'):strfind(code,'%% Optional historical JRQA export')-1);
execute_block(CFG,block8);
for component = 1:2
    folder = fullfile(CFG.block3.output_path,sprintf('Component_%d',component));
    verifyEmpty(testCase,dir(fullfile(folder,'FREQNESS_COORDINATION*')));
    S = load(fullfile(folder,sprintf('FREQNESS_SPATIAL_SUMMARY_Comp#%d.mat',component)));
    verifyEqual(testCase,S.list_dyads,[1 13 32]);
    T = readtable(fullfile(CFG.block8.output_path,'SpatialCoordination', ...
        sprintf('OUT2R_Comp#%d.xlsx',component)),'TextType','string');
    verifyEqual(testCase,height(T),3*4*4);
    verifyEqual(testCase,unique(T.Dyad)',[1 13 32]);
    for rowi = 1:height(T)
        condi = 1+double(T.Music(rowi)=="Same")+2*double(T.Visual(rowi)=="Yes");
        metri = str2double(erase(T.Meter(rowi),"M"));
        C = load(fullfile(CFG.block1.output_path,sprintf( ...
            'FREQNESS_CORE_D%d_C%d_T1.mat',T.Dyad(rowi),condi)));
        idx = [2 4 8 16];
        expected = corr(abs(C.GED.pats(:,component,idx(metri),1)), ...
            abs(C.GED.pats(:,component,idx(metri),2)));
        verifyEqual(testCase,T.Mirror(rowi),expected,'AbsTol',1e-12);
        verifyEqual(testCase,T.FisherZ(rowi),atanh(expected),'AbsTol',1e-12);
    end
end
files = dir(fullfile(CFG.block3.output_path,'Component_*','*.mat'));
execute_block(CFG,block3);
after = dir(fullfile(CFG.block3.output_path,'Component_*','*.mat'));
verifyEqual(testCase,[files.datenum],[after.datenum]);
CFG.common.trial_indices{13,1} = 99;
rejected = false;
try
    execute_block(CFG,block3);
catch ME
    rejected = contains(ME.message,'Saved spatial settings/trial differ');
end
verifyTrue(testCase,rejected);
end

function testFisherBeforeAveraging(testCase)
r = [.1 .9];
verifyGreaterThan(testCase,abs(mean(atanh(r))-atanh(mean(r))),.1);
verifyTrue(testCase,contains(testCase.TestData.code, ...
    'avg_FisherZ = mean(atanh(S.MIRROR),4,''omitnan'')'));
end

function execute_block(CFG,code)
eval(code);
end
