function tests = testFREQNESSMetricProminenceMocap
%TESTFREQNESSMETRICPROMINENCEMOCAP Tests for metric prominence.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testDefaultsUseEveryAvailableMetricLevel(testCase)

frex = [.25 .5 1 1.5 2 3 4];
first = [20 30 40 25 50 35 15; 50 40 30 45 25 35 55; ...
    30 30 30 30 25 30 30];
FREQ = syntheticFREQ(first,frex);

METER = FREQNESS_MetricProminence_Mocap(FREQ,1);
expectedLevels = [.25 .5 1 2 3 4];
expectedRaw = [20 30 40 50 35 15]';
expectedBaseline = 25;

verifyEqual(testCase,fieldnames(METER),{ ...
    'GlobalProminence';'MetricProminence';'Component'; ...
    'AnchorFrequency';'AnchorInferred';'MetricLevels'; ...
    'MetricFrequencies';'GlobalMetricLevels';'GlobalFrequencies'});
verifyEqual(testCase,METER.Component,1);
verifyEqual(testCase,METER.MetricLevels,expectedLevels);
verifyEqual(testCase,METER.GlobalMetricLevels,expectedLevels);
verifyEqual(testCase,METER.MetricProminence, ...
    expectedRaw/expectedBaseline,'AbsTol',1e-12);
verifyEqual(testCase,METER.GlobalProminence, ...
    mean(expectedRaw)/expectedBaseline,'AbsTol',1e-12);
verifyFalse(testCase,METER.AnchorInferred);

end


function testAutomaticLevelsIncludeReciprocalIntegerSubharmonics(testCase)

frex = [1/3 .5 1 1.5 2 3];
first = [20 30 40 25 50 35; 50 40 30 45 25 35; 30 30 30 30 25 30];
FREQ = syntheticFREQ(first,frex);

METER = FREQNESS_MetricProminence_Mocap(FREQ,1);

verifyEqual(testCase,METER.MetricLevels,[1/3 .5 1 2 3], ...
    'AbsTol',1e-12);

end


function testRequestedLevelsUseCommonGlobalBaseline(testCase)

frex = [.25 .5 1 1.5 2 3 4];
first = [20 30 40 25 50 35 15; 50 40 30 45 25 35 55; ...
    30 30 30 30 25 30 30];
FREQ = syntheticFREQ(first,frex);

METER = FREQNESS_MetricProminence_Mocap(FREQ,1, ...
    'metric_levels',[.5 1 2]);

verifyEqual(testCase,METER.MetricLevels,[.5 1 2]);
verifyEqual(testCase,METER.GlobalMetricLevels,[.25 .5 1 2 3 4]);
verifyEqual(testCase,METER.MetricProminence,[30 40 50]'/25, ...
    'AbsTol',1e-12);

end


function testExplicitGlobalLevelsIncludeRequestedLevels(testCase)

frex = [.25 .5 1 1.5 2 3 4];
first = [20 30 40 25 50 35 15; 50 40 30 45 25 35 55; ...
    30 30 30 30 25 30 30];
FREQ = syntheticFREQ(first,frex);

METER = FREQNESS_MetricProminence_Mocap(FREQ,1, ...
    'metric_levels',[.25 2], ...
    'global_metric_levels',[.5 1]);

verifyEqual(testCase,METER.GlobalMetricLevels,[.25 .5 1 2]);
verifyEqual(testCase,METER.MetricProminence,[20;50]/25, ...
    'AbsTol',1e-12);
verifyEqual(testCase,METER.GlobalProminence,35/25, ...
    'AbsTol',1e-12);

end


function testRequestedComponentIsUsed(testCase)

frex = [.25 .5 1 1.5 2 3 4];
first = [20 30 40 25 50 35 15; 50 40 30 45 25 35 55; ...
    30 30 30 30 25 30 30];
FREQ = syntheticFREQ(first,frex);

METER = FREQNESS_MetricProminence_Mocap(FREQ,1, ...
    'component',2,'metric_levels',[1 2], ...
    'global_metric_levels',[1 2]);

expectedBaseline = mean([50 40 45 35 55]);
verifyEqual(testCase,METER.Component,2);
verifyEqual(testCase,METER.MetricProminence, ...
    [30;25]/expectedBaseline,'AbsTol',1e-12);

end


function testMultipleParticipantsReturnParticipantColumns(testCase)

frex = [.5 1 1.5 2 3];
first = [20 40 25 50 30; 50 30 45 25 40; 30 30 30 25 30];
second = [30 45 20 40 25; 40 25 50 30 45; 30 30 30 30 30];
FREQ = syntheticFREQ(cat(3,first,second),frex);

METER = FREQNESS_MetricProminence_Mocap(FREQ,[1 1], ...
    'metric_levels',[.5 1 2]);

verifySize(testCase,METER.MetricProminence,[3 2]);
verifySize(testCase,METER.GlobalProminence,[1 2]);
verifyEqual(testCase,METER.MetricProminence, ...
    [.8 1.5;1.6 2.25;2 2],'AbsTol',1e-12);
verifyEqual(testCase,METER.GlobalProminence,[1.4 1.75], ...
    'AbsTol',1e-12);
verifyEqual(testCase,METER.AnchorFrequency,[1 1]);

end


function testParticipantSpecificFrequencyGridsAreAccepted(testCase)

first = [20 40 25 50 30; 50 30 45 25 40; 30 30 30 25 30];
second = [30 45 20 40 25; 40 25 50 30 45; 30 30 30 30 30];
frex = [.5 1;1 2;1.5 3;2 4;3 6];
FREQ = syntheticFREQ(cat(3,first,second),frex);

METER = FREQNESS_MetricProminence_Mocap(FREQ,[1 2], ...
    'metric_levels',[.5 1 2]);

verifyEqual(testCase,METER.MetricFrequencies, ...
    [.5 1;1 2;2 4]);
verifyEqual(testCase,METER.AnchorFrequency,[1 2]);

end


function testMissingAnchorWarnsAndUsesComponentPeak(testCase)

frex = [.25 .5 1 1.5 2 3 4];
first = [20 30 40 25 50 35 15; 50 40 30 45 25 35 55; ...
    30 30 30 30 25 30 30];
FREQ = syntheticFREQ(first,frex);

verifyWarning(testCase,@() FREQNESS_MetricProminence_Mocap(FREQ), ...
    'FREQNESS:MetricProminence:InferredAnchor');
METER = callWithWarningDisabled(FREQ);

verifyEqual(testCase,METER.AnchorFrequency,2);
verifyTrue(testCase,METER.AnchorInferred);

end


function testNearestFrequencyIsRetainedInOutput(testCase)

frex = [.4 .9 1.4 1.9 2.4];
first = [20 40 25 50 30; 50 30 45 25 40; 30 30 30 25 30];
FREQ = syntheticFREQ(first,frex);

METER = FREQNESS_MetricProminence_Mocap(FREQ,1, ...
    'metric_levels',[1 2], ...
    'global_metric_levels',[1 2]);

verifyEqual(testCase,METER.AnchorFrequency,.9);
verifyEqual(testCase,METER.MetricFrequencies,[.9;1.9]);

end


function testInputValidation(testCase)

frex = [.5 1 1.5 2 3];
first = [20 40 25 50 30; 50 30 45 25 40; 30 30 30 25 30];
FREQ = syntheticFREQ(first,frex);

verifyFailureMessage(testCase,@() FREQNESS_MetricProminence_Mocap(7,1), ...
    'Input must be a FREQ structure.');
verifyFailureMessage(testCase,@() FREQNESS_MetricProminence_Mocap( ...
    rmfield(FREQ,'evals'),1), ...
    'FREQ.evals is missing or empty.');
verifyFailureMessage(testCase,@() FREQNESS_MetricProminence_Mocap( ...
    rmfield(FREQ,'frex'),1), ...
    'FREQ.frex is missing or empty.');
verifyFailureMessage(testCase,@() FREQNESS_MetricProminence_Mocap( ...
    FREQ,1,'component',4), ...
    ['component must be one positive integer indexing the first ' ...
    'dimension of FREQ.evals.']);
verifyFailureMessage(testCase,@() FREQNESS_MetricProminence_Mocap( ...
    FREQ,4), ...
    'Every anchor_frex value must lie inside its frequency range.');
verifyFailureMessage(testCase,@() FREQNESS_MetricProminence_Mocap( ...
    FREQ,1,'metric_levels',[1 -2]), ...
    'metric_levels must be empty or a vector of positive finite values.');
verifyFailureMessage(testCase,@() FREQNESS_MetricProminence_Mocap( ...
    FREQ,1,'metric_levels',[1 1.1]), ...
    ['The frequency grid maps multiple metric_levels values onto the same ' ...
    'bin for at least one participant.']);

unnormalized = FREQ;
unnormalized.evals = unnormalized.evals/100;
verifyFailureMessage(testCase,@() FREQNESS_MetricProminence_Mocap( ...
    unnormalized,1), ...
    'FREQ.evals must be normalized to percentage explained variance.');

end


function FREQ = syntheticFREQ(evals,frex)

FREQ = struct('evals',evals,'frex',frex);

end


function METER = callWithWarningDisabled(FREQ)

warningState = warning('off', ...
    'FREQNESS:MetricProminence:InferredAnchor');
cleanup = onCleanup(@() warning(warningState));
METER = FREQNESS_MetricProminence_Mocap(FREQ);

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
