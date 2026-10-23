function tests = DyadiDance_PhasePipelineTest
%TESTFREQNESSDANCEPHASEPIPELINE Selected study settings and sampling contract.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repo = fileparts(fileparts(mfilename('fullpath')));
code = fileread(fullfile(repo,'Rosso_et_al_Dance_inPreparation', ...
    'DyadiDance_MainPipeline.m'));
code = [fileread(fullfile(repo,'Rosso_et_al_Dance_inPreparation', ...
    'Supporting','DyadiDance_Configuration.m')) newline code];
CFG.common = struct('data_path',tempdir,'results_path',tempdir, ...
    'filter_output_tag','legacy_logarithmic','reuse_core_path',tempdir);
first = strfind(code,'% Manuscript phase-space RQA:');
last = strfind(code,'CFG.block7.output_path =');
eval(code(first:last-1)); % Evaluate the actual settings, without running a study.
testCase.TestData.CFG = CFG;
testCase.TestData.code = code;
testCase.TestData.r_code = fileread(fullfile(repo, ...
    'Rosso_et_al_Dance_inPreparation','DyadiDance_Stats.R'));
end

function testManuscriptDefaults(testCase)
p = testCase.TestData.CFG.block6;
verifyEqual(testCase,p.components,1:2);
verifyEqual(testCase,[p.srate p.downsample p.lowpass_hz p.filter_order],[250 10 10 4]);
verifyEqual(testCase,p.duration,[.15 .85]);
verifyEqual(testCase,p.metric_levels,[.25 .5 1 2]);
verifyFalse(testCase,p.standardize);
verifyEqual(testCase,p.threshold_method,'max_fraction');
verifyEqual(testCase,p.threshold,.1);
verifyEqual(testCase,[p.theiler_window p.lmin p.vmin],[0 2 2]);
verifyEqual(testCase,p.output_tag, ...
    'PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0');
verifyTrue(testCase,contains(testCase.TestData.r_code,p.output_tag));
verifyTrue(testCase,contains(testCase.TestData.r_code, ...
    'unset = "SpatialRaw,SpatialFisher,PhaseSpaceRQACorrected"'));
end

function testPhysicalFilterAndCrop(testCase)
p = testCase.TestData.CFG.block6;
[b,a] = butter(p.filter_order,p.lowpass_hz/(p.srate/2),'low');
% The same full-rate filter is applied before either decimation factor.
t = (0:14999)'/p.srate;
y = filtfilt(b,a,sin(2*pi*2*t)+sin(2*pi*40*t));
y5 = y(1:5:end);
verifyEqual(testCase,y(1:10:end),y5(1:2:end));
H = freqz(b,a,2*pi*[2 40]/p.srate);
verifyGreaterThan(testCase,abs(H(1))^2,.99);
verifyLessThan(testCase,abs(H(2))^2,1e-4);
n = numel(y(1:p.downsample:end));
indices = round(p.duration(1)*n):round(p.duration(2)*n);
verifyEqual(testCase,numel(indices),1051);
verifyEqual(testCase,indices([1 end]),[225 1275]);
end

function testSeparateOutputsAndCacheChecks(testCase)
code = testCase.TestData.code;
first = strfind(code,'%% BLOCK 6 -');
last = strfind(code,'%% BLOCK 7 -');
block6 = code(first:last-1);
verifyFalse(testCase,contains(block6,'legacy_phase_rqa_file'));
verifyTrue(testCase,contains(block6,'isequaln(S.PhaseRQA,PhaseRQA)'));
verifyTrue(testCase,contains(block6,'S.id_trial == id_trial'));
verifyTrue(testCase,contains(block6,'CFG.block6.lowpass_hz/(srate/2)'));
verifyFalse(testCase,contains(code,'export_jrqa'));
verifyTrue(testCase,contains(testCase.TestData.r_code, ...
    'Statistics already exist'));
end
