function tests = testFREQNESSLandscapeSimilarity
%TESTFREQNESSLANDSCAPESIMILARITY Tests for landscape similarity.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testDyadReturnsScalarCorrelation(testCase)

first = [1 3 5; 2 4 6];
second = 2*first+7;
FREQ = syntheticFREQ(cat(3,first,second),[1 2 4]);

[similarity,selectedFrex] = FREQNESS_LandscapeSimilarity(FREQ);

verifyEqual(testCase,similarity,1,'AbsTol',1e-12);
verifyEqual(testCase,selectedFrex,[1;2;4]);

end


function testGroupReturnsParticipantCorrelationMatrix(testCase)

first = [1 3 5; 2 4 6];
second = 10-first;
third = 3*first+2;
FREQ = syntheticFREQ(cat(3,first,second,third),[1 2 4]);

similarity = FREQNESS_LandscapeSimilarity(FREQ);
expected = corrcoef([first(:) second(:) third(:)]);

verifySize(testCase,similarity,[3 3]);
verifyEqual(testCase,similarity,expected,'AbsTol',1e-12);

end


function testFrequencyRangeUsesNearestInclusiveBounds(testCase)

first = [1 3 5 7; 2 4 6 8];
second = [8 13 17 1; 7 15 19 2];
FREQ = syntheticFREQ(cat(3,first,second),[1 2 4 8]);

[similarity,selectedFrex] = FREQNESS_LandscapeSimilarity( ...
    FREQ,'frequency_range',[1.6 4.7]);
selectedFirst = first(:,2:3);
selectedSecond = second(:,2:3);
expected = corrcoef(selectedFirst(:),selectedSecond(:));

verifyEqual(testCase,similarity,expected(1,2),'AbsTol',1e-12);
verifyEqual(testCase,selectedFrex,[2;4]);

end


function testIdenticalParticipantFrequencyMatricesAreAccepted(testCase)

first = [1 3 5; 2 4 6];
second = 2*first+7;
FREQ = syntheticFREQ(cat(3,first,second),repmat([1;2;4],1,2));

[similarity,selectedFrex] = FREQNESS_LandscapeSimilarity(FREQ);

verifyEqual(testCase,similarity,1,'AbsTol',1e-12);
verifyEqual(testCase,selectedFrex,[1;2;4]);

end


function testSingleParticipantWarnsAndReturnsEmpty(testCase)

FREQ = syntheticFREQ(reshape(1:6,2,3),[1 2 4]);

verifyWarning(testCase,@() FREQNESS_LandscapeSimilarity(FREQ), ...
    'FREQNESS:LandscapeSimilarity:InsufficientParticipants');
[similarity,selectedFrex] = callWithWarningDisabled(FREQ);
verifyEmpty(testCase,similarity);
verifyEmpty(testCase,selectedFrex);

end


function testInputValidation(testCase)

FREQ = syntheticFREQ(rand(2,3,2),[1 2 4]);

verifyFailureMessage(testCase,@() FREQNESS_LandscapeSimilarity(7), ...
    'Input must be a FREQ structure.');
verifyFailureMessage(testCase,@() FREQNESS_LandscapeSimilarity( ...
    rmfield(FREQ,'evals')), ...
    'FREQ.evals is missing or empty.');
verifyFailureMessage(testCase,@() FREQNESS_LandscapeSimilarity( ...
    FREQ,'frequency_range',[4 1]), ...
    ['frequency_range must be empty or a two-element positive ' ...
    'finite real vector ordered as [low high].']);

differentFrex = FREQ;
differentFrex.frex = [1 1; 2 2.1; 4 4];
verifyFailureMessage(testCase,@() FREQNESS_LandscapeSimilarity(differentFrex), ...
    'Landscape similarity requires the same frequency grid for every participant.');

end


function FREQ = syntheticFREQ(evals,frex)

FREQ = struct('evals',evals,'frex',frex);

end


function [similarity,selectedFrex] = callWithWarningDisabled(FREQ)

warningState = warning('off', ...
    'FREQNESS:LandscapeSimilarity:InsufficientParticipants');
cleanup = onCleanup(@() warning(warningState));
[similarity,selectedFrex] = FREQNESS_LandscapeSimilarity(FREQ);

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
