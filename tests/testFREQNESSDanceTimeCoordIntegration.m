function tests = testFREQNESSDanceTimeCoordIntegration
%TESTFREQNESSDANCETIMECOORDINTEGRATION Study calls preserve temporal outputs.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

repo = fileparts(fileparts(mfilename('fullpath')));
path_toolbox = fullfile(repo,'FREQNESS_Mocap_Toolbox');
addpath(genpath(fullfile(path_toolbox,'FREQNESS_Functions')));
addpath(fullfile(path_toolbox,'FREQNESS_ExternalFunctions'));
code = fileread(fullfile(repo,'Rosso_et_al_Dance_inPreparation', ...
    'FREQNESS_DyadicDance_Mocap.m'));
validation_code = fileread(fullfile(repo,'Rosso_et_al_Dance_inPreparation', ...
    'FREQNESS_DyadicDance_JRQA_Validation.m'));
testCase.TestData.phase_call = study_call(code,'FREQrqa');
testCase.TestData.validated_call = study_call(validation_code,'FREQjrqa');

% Evaluate configuration only, without creating or accessing study outputs.
CFG.common = struct('data_path',tempdir,'results_path',tempdir, ...
    'filter_output_tag','legacy_logarithmic','reuse_core_path','');
first = strfind(code,'% Manuscript phase-space RQA:');
last = strfind(code,'CFG.block7.output_path =');
eval(code(first:last-1));
testCase.TestData.PhaseRQA = CFG.block6;
results_path = tempdir; %#ok<NASGU> Used by the validation configuration below.
first = strfind(validation_code,'CFG = struct();');
last = strfind(validation_code,'assert(isfolder(CFG.core_path),');
eval(validation_code(first:last-1));
testCase.TestData.CFG = CFG;

original_rng = rng;
cleanup = onCleanup(@() rng(original_rng));
rng(73);
beat_frex = [1.8 2.1];
time = (0:5999)/250;
GED = struct('frex',(1:32)'/8.*beat_frex,'ts',zeros(2,numel(time),32,2));
for subi = 1:2
    for compi = 1:2
        for frexi = 1:32
            GED.ts(compi,:,frexi,subi) = subi+compi* ...
                sin(2*pi*GED.frex(frexi,subi)*time+.2*subi) + ...
                .2*randn(size(time));
        end
    end
end
testCase.TestData.GED = GED;
testCase.TestData.beat_frex = beat_frex;

end


function testManuscriptPhaseCallPreservesSettings(testCase)

PhaseRQA = testCase.TestData.PhaseRQA;
PhaseRQA.animate = false;
this_target_frex = testCase.TestData.beat_frex;
meter = PhaseRQA.metric_levels;
duration = PhaseRQA.duration;
srate = PhaseRQA.srate/PhaseRQA.downsample;
make_figure = false; %#ok<NASGU> Used by the evaluated study call below.
verifyTrue(testCase,contains(testCase.TestData.phase_call, ...
    '''method'',''phase_space'''));
for which_comp = 1:2
    PhaseRQA.component = which_comp;
    GED = prepare_series(testCase.TestData.GED,which_comp, ...
        PhaseRQA.lowpass_hz/(PhaseRQA.srate/2),PhaseRQA.downsample);
    expected = FREQNESS_TimeCoord_Mocap(GED,this_target_frex, ...
        'method','phase_space', ...
        'metric_levels',meter,'component',PhaseRQA.component, ...
        'duration',duration,'standardize',PhaseRQA.standardize, ...
        'threshold_method',PhaseRQA.threshold_method,'threshold',PhaseRQA.threshold, ...
        'theiler_window',PhaseRQA.theiler_window,'lmin',PhaseRQA.lmin, ...
        'vmin',PhaseRQA.vmin,'store_matrices',false,'figure',false, ...
        'animate',false,'srate',srate);
    eval(testCase.TestData.phase_call);
    verifyEqual(testCase,FREQrqa,expected);
end

end


function testHistoricalJRQAIsReadOnly(testCase)

repo = fileparts(fileparts(mfilename('fullpath')));
code = fileread(fullfile(repo,'Rosso_et_al_Dance_inPreparation', ...
    'FREQNESS_DyadicDance_Mocap.m'));
verifyFalse(testCase,contains(code,'RPparam('));
verifyFalse(testCase,contains(code,'FREQNESS_DyadicDance_LegacyJRQA('));
verifyFalse(testCase,contains(code,'compute_jrqa'));
verifyTrue(testCase,contains(code,'CFG.block3.reuse_legacy_jrqa = false;'));
verifyTrue(testCase,contains(code,'%% Optional historical JRQA export'));
verifyFalse(testCase,isfile(fullfile(repo,'FREQNESS_Mocap_Toolbox', ...
    'FREQNESS_ExternalFunctions','RPparam.m')));

end


function testValidatedJRQACallPreservesSettingsAndThresholdMethods(testCase)

CFG = testCase.TestData.CFG;
S = struct('GED',testCase.TestData.GED,'beat_frex',testCase.TestData.beat_frex);
specification = struct('JRQA',struct('m',2,'tau',3,'ps',.8), ...
    'theiler_window',3);
methods = {'radius','adaptive_max_radius','fixed_rr'};
thresholds = [.8 .1 .05];
for which_comp = 1:2
    for methodi = 1:numel(methods)
        specification.threshold_method = methods{methodi};
        this_threshold = thresholds(methodi);
        expected = FREQNESS_TimeCoord_Mocap(S.GED,S.beat_frex, ...
            'method','jrqa','parameters',specification.JRQA, ...
            'metric_levels',CFG.metric_levels,'component',which_comp, ...
            'duration',CFG.duration, ...
            'srate',CFG.original_srate,'target_srate',CFG.target_srate, ...
            'lowpass_cutoff',CFG.lowpass_cutoff,'filter_order',CFG.filter_order, ...
            'standardize',CFG.standardize, ...
            'threshold_method',specification.threshold_method, ...
            'threshold',this_threshold,'theiler_window',specification.theiler_window, ...
            'lmin',CFG.lmin,'vmin',CFG.vmin,'store_matrices',false);
        eval(testCase.TestData.validated_call);
        verifyEqual(testCase,FREQjrqa,expected);
        verifyTrue(testCase,FREQjrqa(1).Preprocessing.Standardized);
    end
end

end


function call_code = study_call(code,output_name)

call_code = regexp(code,[output_name ...
    ' = FREQNESS_TimeCoord_Mocap\([\s\S]*?\);'],'match','once');
assert(~isempty(call_code),'Expected the study to use the unified TimeCoord interface.');

end


function GED = prepare_series(GED,which_comp,cutoff_norm,dwn)

[b,a] = butter(4,cutoff_norm,'low');
for subi = 1:2
    for frexi = 1:size(GED.ts,3)
        this_ts = reshape(GED.ts(which_comp,:,frexi,subi),[],1);
        GED.ts(which_comp,:,frexi,subi) = filtfilt(b,a,this_ts);
    end
end
GED.ts = GED.ts(:,1:dwn:end,:,:);

end
