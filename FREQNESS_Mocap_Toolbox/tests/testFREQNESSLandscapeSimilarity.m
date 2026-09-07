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


function testDyadReturnsTwoScalarCorrelations(testCase)

first = [60 50 40; 30 30 35; 10 20 25];
second = [55 48 42; 32 31 33; 13 21 25];
FREQ = syntheticFREQ(cat(3,first,second),[1 2 4]);

[similarityComp,similarityEntropy,selectedFrex] = ...
    FREQNESS_LandscapeSimilarity(FREQ);
expectedComp = corrcoef(first(1,:)',second(1,:)');
expectedEntropy = corrcoef(entropyLandscape(first),entropyLandscape(second));

verifyEqual(testCase,similarityComp,expectedComp(1,2),'AbsTol',1e-12);
verifyEqual(testCase,similarityEntropy,expectedEntropy(1,2),'AbsTol',1e-12);
verifyEqual(testCase,selectedFrex,[1;2;4]);

end


function testRequestedComponentIsUsed(testCase)

first = [60 50 40; 20 25 30; 15 15 20; 5 10 10];
second = [40 50 60; 20 25 30; 20 13 5; 20 12 5];
FREQ = syntheticFREQ(cat(3,first,second),[1 2 4]);

similarityDefault = FREQNESS_LandscapeSimilarity(FREQ);
similaritySecond = FREQNESS_LandscapeSimilarity(FREQ,'component',2);

verifyEqual(testCase,similarityDefault,-1,'AbsTol',1e-12);
verifyEqual(testCase,similaritySecond,1,'AbsTol',1e-12);

end


function testGroupReturnsTwoParticipantCorrelationMatrices(testCase)

first = [60 50 40; 30 30 35; 10 20 25];
second = [55 48 42; 32 31 33; 13 21 25];
third = [40 50 60; 35 30 25; 25 20 15];
FREQ = syntheticFREQ(cat(3,first,second,third),[1 2 4]);

[similarityComp,similarityEntropy] = FREQNESS_LandscapeSimilarity(FREQ);
expectedComp = corrcoef([first(1,:)' second(1,:)' third(1,:)']);
expectedEntropy = corrcoef([entropyLandscape(first) ...
    entropyLandscape(second) entropyLandscape(third)]);

verifySize(testCase,similarityComp,[3 3]);
verifySize(testCase,similarityEntropy,[3 3]);
verifyEqual(testCase,similarityComp,expectedComp,'AbsTol',1e-12);
verifyEqual(testCase,similarityEntropy,expectedEntropy,'AbsTol',1e-12);

end


function testFrequencyRangeUsesNearestInclusiveBounds(testCase)

first = [62 55 45 36; 25 27 31 34; 13 18 24 30];
second = [58 52 47 38; 27 29 30 33; 15 19 23 29];
FREQ = syntheticFREQ(cat(3,first,second),[1 2 4 8]);

[similarityComp,similarityEntropy,selectedFrex] = ...
    FREQNESS_LandscapeSimilarity(FREQ, ...
    'component',2,'frequency_range',[1.6 4.7]);
expectedComp = corrcoef(first(2,2:3)',second(2,2:3)');
firstEntropy = entropyLandscape(first);
secondEntropy = entropyLandscape(second);
expectedEntropy = corrcoef(firstEntropy(2:3),secondEntropy(2:3));

verifyEqual(testCase,similarityComp,expectedComp(1,2),'AbsTol',1e-12);
verifyEqual(testCase,similarityEntropy,expectedEntropy(1,2),'AbsTol',1e-12);
verifyEqual(testCase,selectedFrex,[2;4]);

end


function testIdenticalParticipantFrequencyMatricesAreAccepted(testCase)

first = [60 50 40; 30 30 35; 10 20 25];
second = [55 48 42; 32 31 33; 13 21 25];
FREQ = syntheticFREQ(cat(3,first,second),repmat([1;2;4],1,2));

[similarityComp,similarityEntropy,selectedFrex] = ...
    FREQNESS_LandscapeSimilarity(FREQ);

verifyTrue(testCase,isscalar(similarityComp));
verifyTrue(testCase,isscalar(similarityEntropy));
verifyEqual(testCase,selectedFrex,[1;2;4]);

end


function testSingleParticipantWarnsAndReturnsEmpty(testCase)

FREQ = syntheticFREQ([60 50 40; 30 30 35; 10 20 25],[1 2 4]);

verifyWarning(testCase,@() FREQNESS_LandscapeSimilarity(FREQ), ...
    'FREQNESS:LandscapeSimilarity:InsufficientParticipants');
[similarityComp,similarityEntropy,selectedFrex] = ...
    callWithWarningDisabled(FREQ);
verifyEmpty(testCase,similarityComp);
verifyEmpty(testCase,similarityEntropy);
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
    FREQ,'component',3), ...
    ['component must be one positive integer indexing the first ' ...
    'dimension of FREQ.evals.']);
verifyFailureMessage(testCase,@() FREQNESS_LandscapeSimilarity( ...
    FREQ,'frequency_range',[4 1]), ...
    ['frequency_range must be empty or a two-element positive ' ...
    'finite real vector ordered as [low high].']);
verifyFailureMessage(testCase,@() FREQNESS_LandscapeSimilarity( ...
    FREQ,'frequency_range',[2 2]), ...
    ['At least two selected frequencies are required ' ...
    'to compute landscape similarity.']);

differentFrex = FREQ;
differentFrex.frex = [1 1; 2 2.1; 4 4];
verifyFailureMessage(testCase,@() FREQNESS_LandscapeSimilarity(differentFrex), ...
    'Landscape similarity requires the same frequency grid for every participant.');

end


function H2 = entropyLandscape(evals)

probabilities = evals./sum(evals,1);
H2 = -log(sum(probabilities.^2,1))';

end


function FREQ = syntheticFREQ(evals,frex)

FREQ = struct('evals',evals,'frex',frex);

end


function [similarityComp,similarityEntropy,selectedFrex] = ...
        callWithWarningDisabled(FREQ)

warningState = warning('off', ...
    'FREQNESS:LandscapeSimilarity:InsufficientParticipants');
cleanup = onCleanup(@() warning(warningState));
[similarityComp,similarityEntropy,selectedFrex] = ...
    FREQNESS_LandscapeSimilarity(FREQ);

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
