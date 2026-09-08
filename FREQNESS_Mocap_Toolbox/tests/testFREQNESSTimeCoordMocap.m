function tests = testFREQNESSTimeCoordMocap
%TESTFREQNESSTIMECOORDMOCAP Gap-safety tests for JRQA coordination.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testGappyFREQIsRejectedBeforeJRQA(testCase)

FREQ = struct();
FREQ.ts = randn(1,100,1,2);
FREQ.frex = 1;
FREQ.bad_segments = 20:25;
JRQA = struct('m',2,'tau',1);

verifyError(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,JRQA,[1 1]),'FREQNESS:TimeCoord:GapsUnsupported');

end


function testNonfiniteTimeSeriesAreRejected(testCase)

FREQ = struct();
FREQ.ts = randn(1,100,1,2);
FREQ.ts(1,20,1,1) = NaN;
FREQ.frex = 1;
JRQA = struct('m',2,'tau',1);

verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,JRQA,[1 1]),'FREQ.ts must be a real finite numeric array.');

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
