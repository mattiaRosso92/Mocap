function tests = DyadicDance_PhaseReuseTest
% Saved RR/DET import/resume regression; never calculate recurrence matrices.
tests = functiontests(localfunctions);
end

function testImportExportAndResume(testCase)
[CFG,code,reference] = fixture;
before = dir(fullfile(CFG.block6.reuse_rqa_path,'*.mat'));
block6 = code(strfind(code,'%% BLOCK 6 -'):strfind(code,'%% BLOCK 7 -')-1);
profile clear
profile on
execute_block(CFG,block6);
profile off
calls = profile('info');
verifyFalse(testCase,any(contains({calls.FunctionTable.FunctionName}, ...
    {'FREQNESS_TimeCoord_Mocap','compute_phase_space_rqa'})));
for component = 1:2
    files = dir(fullfile(CFG.block6.output_path,sprintf('Component_%d',component),'*.mat'));
    verifyEqual(testCase,numel(files),1); % Summary only; no trial-file duplication.
    S = load(fullfile(files.folder,files.name));
    verifyEqual(testCase,fieldnames(S.PhaseRQA.output),{'RR';'DET'});
    verifyEqual(testCase,S.reuse_source.metrics,{'RR','DET'});
    for metric = {'RR','DET'}
        expected = permute(reference.(metric{1})(:,:,:,component,:,1),[1 2 5 3 4 6]);
        verifyEqual(testCase,S.PhaseRQA.output.(metric{1}),expected);
    end
end
after = dir(fullfile(CFG.block6.reuse_rqa_path,'*.mat'));
verifyEqual(testCase,[before.datenum],[after.datenum]);
verifyEqual(testCase,[before.bytes],[after.bytes]);

% Imported summaries remain usable without the original comparison folder.
files = dir(fullfile(CFG.block6.output_path,'Component_*','*.mat'));
CFG.block6.reuse_rqa_path = fullfile(CFG.block6.output_path,'not_present');
execute_block(CFG,block6);
after = dir(fullfile(CFG.block6.output_path,'Component_*','*.mat'));
verifyEqual(testCase,[files.datenum],[after.datenum]);

block8 = code(strfind(code,'%% Manuscript phase-space export'):end);
execute_block(CFG,block8);
for component = 1:2
    T = readtable(fullfile(CFG.block8.output_path,CFG.block6.output_tag, ...
        sprintf('OUT2R_Comp#%d.xlsx',component)),'TextType','string');
    verifyEqual(testCase,height(T),3*4*4);
    verifyEqual(testCase,unique(T.Dyad)',[1 13 32]);
    for rowi = 1:height(T)
        condi = 1+double(T.Music(rowi)=="Same")+2*double(T.Visual(rowi)=="Yes");
        metri = str2double(erase(T.Meter(rowi),"M"));
        verifyEqual(testCase,T.RR(rowi),reference.RR(T.Dyad(rowi),condi,1,component,metri,1),'AbsTol',1e-12);
        verifyEqual(testCase,T.DET(rowi),reference.DET(T.Dyad(rowi),condi,1,component,metri,1),'AbsTol',1e-12);
    end
end
exports = dir(fullfile(CFG.block8.output_path,CFG.block6.output_tag,'*.xlsx'));
execute_block(CFG,block8);
after = dir(fullfile(CFG.block8.output_path,CFG.block6.output_tag,'*.xlsx'));
verifyEqual(testCase,[exports.datenum],[after.datenum]);
CFG.block6.duration = [.2 .8];
verify_rejected(testCase,CFG,block6,'Reused phase-space summary settings/trials differ');
end

function testRejectReferenceMismatches(testCase)
for kind = {'settings','trial','frequency','samples','summary'}
    [CFG,code] = fixture;
    file = fullfile(CFG.block6.reuse_rqa_path,'D1_C1_T1.mat');
    source = load(file);
    switch kind{1}
        case 'settings', source.settings.threshold = .05;
        case 'trial', source.id_trial = 99;
        case 'frequency', source.selected_frequencies(1,1) = 99;
        case 'samples', source.sample_counts(1) = 99;
        case 'summary', source.RR(1,1,1) = .99;
    end
    save(file,'-struct','source');
    block6 = code(strfind(code,'%% BLOCK 6 -'):strfind(code,'%% BLOCK 7 -')-1);
    verify_rejected(testCase,CFG,block6,'Reference phase-space');
    verifyEmpty(testCase,dir(fullfile(CFG.block6.output_path,'Component_*','*.mat')));
end
end

function [CFG,code,reference] = fixture
repo = fileparts(fileparts(mfilename('fullpath')));
code = fileread(fullfile(repo,'Rosso_et_al_Dance_inPreparation','DyadicDance_MainPipeline.m'));
code = [fileread(fullfile(repo,'Rosso_et_al_Dance_inPreparation', ...
    'Supporting','DyadicDance_Configuration.m')) newline code];
folder = tempname; mkdir(folder);
CFG.common = struct('data_path',fullfile(repo,'Dance_Data'),'results_path',folder, ...
    'filter_output_tag','legacy_logarithmic','filter_width_calibration','legacy', ...
    'filter_type','logarithmic','reuse_core_path','','ncomps',4, ...
    'list_dyads',[1 13 32],'ntrials',1);
CFG.common.trial_counts = zeros(35,4);
CFG.common.trial_counts(CFG.common.list_dyads,:) = 1;
CFG.common.trial_indices = cell(35,4);
eval(code(strfind(code,'% Manuscript phase-space RQA:'):strfind(code,'CFG.block7.output_path =')-1));
CFG.block6.reuse_rqa_path = fullfile(folder,'reference');
CFG.block1.output_path = fullfile(folder,'core');
CFG.block8 = struct('output_path',fullfile(folder,'export'),'overwrite_flag',false);
mkdir(CFG.block6.reuse_rqa_path); mkdir(CFG.block1.output_path);
addpath(fullfile(repo,'FREQNESS_Mocap_Toolbox'));
FREQNESS_Startup_Mocap();
settings = struct('srate',250,'lowpass_hz',10,'filter_order',4,'factors',[10 5], ...
    'components',1:2,'metric_levels',[.25 .5 1 2],'duration',CFG.block6.duration, ...
    'threshold',.1,'standardize',false,'lmin',2,'theiler_window',0, ...
    'saved_metrics',{{'RR','DET','DET_spanmatched'}});
[RR,DET] = deal(nan(35,4,1,2,4,2));
beat_frex = [1.8 2.1];
GED.frex = (1:32)'/8.*beat_frex;
GED.fwhm = FREQNESS_ComputeLegacyFilterWidths_Mocap(GED.frex,'logarithmic');
GED.ts = zeros(2,100,32,2); % Shape metadata only; no RQA calculation.
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        id_trial = condi+10;
        CFG.common.trial_indices{dyadi,condi} = id_trial;
        source_file = fullfile(CFG.block1.output_path,sprintf('FREQNESS_CORE_D%d_C%d_T1.mat',dyadi,condi));
        save(source_file,'GED','beat_frex','id_trial','-v7.3');
        T = struct('settings',settings,'id_trial',id_trial,'source_file',source_file, ...
            'selected_frequencies',beat_frex'*settings.metric_levels, ...
            'sample_counts',[7 13]);
        % Distinct dyad/condition/component/meter/factor values expose transpositions.
        T.RR = reshape(1:16,2,4,2)/1000+dyadi/1000+condi/100;
        T.DET = .5+T.RR;
        save(fullfile(CFG.block6.reuse_rqa_path,sprintf('D%d_C%d_T1.mat',dyadi,condi)),'-struct','T');
        RR(dyadi,condi,1,:,:,:) = reshape(T.RR,1,1,1,2,4,2);
        DET(dyadi,condi,1,:,:,:) = reshape(T.DET,1,1,1,2,4,2);
    end
end
save(fullfile(CFG.block6.reuse_rqa_path,'Summary.mat'),'RR','DET','settings','CFG');
reference = struct('RR',RR,'DET',DET);
end

function execute_block(CFG,code)
eval(code);
end

function verify_rejected(testCase,CFG,code,message)
rejected = false;
try
    execute_block(CFG,code);
catch ME
    rejected = contains(ME.message,message);
end
verifyTrue(testCase,rejected);
end
