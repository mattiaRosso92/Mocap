function tests = testFREQNESSRQAMocap
%TESTFREQNESSRQAMOCAP Regression tests for consolidated RQA measures.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(genpath(fullfile(toolboxRoot,'FREQNESS_Functions')));
addpath(fullfile(toolboxRoot,'FREQNESS_ExternalFunctions'));
testCase.TestData.recurrencePlot = logical([ ...
    1 1 0 0 0 1 0 0; 1 1 1 0 0 0 1 0; 0 1 1 1 0 0 0 1; ...
    0 0 1 1 0 0 0 0; 0 0 0 0 1 1 0 0; 1 0 0 0 1 1 1 0; ...
    0 1 0 0 0 1 1 0; 0 0 1 0 0 0 0 1]);

end


function testDefaultFieldsAndExplicitDefaults(testCase)

recurrencePlot = testCase.TestData.recurrencePlot;
RQA = FREQNESS_RQA_Mocap(recurrencePlot);
verifySize(testCase,RQA,[1 1]);
verifyEqual(testCase,fieldnames(RQA), ...
    {'rr';'det';'l';'entr';'lam';'tt';'vmax';'div'});
verifyEqual(testCase,RQA,FREQNESS_RQA_Mocap(recurrencePlot,2,2));
verifyEqual(testCase,RQA,FREQNESS_RQA_Mocap(recurrencePlot,[],[]));

end


function testKnownLineDistribution(testCase)

% Diagonals: [2 2 3 3 3 3 8]; vertical lines >= 2: [2 2 2 2 3 3 3].
RQA = FREQNESS_RQA_Mocap(testCase.TestData.recurrencePlot);
probabilities = [2 4 1]/7;
verifyEqual(testCase,RQA.rr,24/64);
verifyEqual(testCase,RQA.det,1);
verifyEqual(testCase,RQA.l,24/7);
verifyEqual(testCase,RQA.entr,-sum(probabilities.*log(probabilities)), ...
    'AbsTol',1e-14);
verifyEqual(testCase,RQA.lam,17/24);
verifyEqual(testCase,RQA.tt,17/7);
verifyEqual(testCase,RQA.vmax,3);
verifyEqual(testCase,RQA.div,1/3);

end


function testIndependentMinimumLengths(testCase)

recurrencePlot = testCase.TestData.recurrencePlot;
RQA = FREQNESS_RQA_Mocap(recurrencePlot,3,3);
verifyEqual(testCase,RQA.det,20/24);
verifyEqual(testCase,RQA.l,4);
verifyEqual(testCase,RQA.lam,9/24);
verifyEqual(testCase,RQA.tt,3);
verifyEqual(testCase,FREQNESS_RQA_Mocap(recurrencePlot,[],3), ...
    FREQNESS_RQA_Mocap(recurrencePlot,2,3));
verifyEqual(testCase,FREQNESS_RQA_Mocap(recurrencePlot,3), ...
    FREQNESS_RQA_Mocap(recurrencePlot,3,2));

end


function testNoRecurrences(testCase)

RQA = FREQNESS_RQA_Mocap(false(8));
verifyEqual(testCase,RQA.rr,0);
fields = {'det','l','entr','lam','tt','vmax','div'};
for fieldi = 1:numel(fields)
    verifyTrue(testCase,isnan(RQA.(fields{fieldi})));
end

end


function testNoQualifyingLines(testCase)

RQA = FREQNESS_RQA_Mocap(testCase.TestData.recurrencePlot,9,9);
verifyEqual(testCase,RQA.rr,24/64);
verifyEqual(testCase,RQA.det,0);
verifyEqual(testCase,RQA.lam,0);
fields = {'l','entr','tt','vmax','div'};
for fieldi = 1:numel(fields)
    verifyTrue(testCase,isnan(RQA.(fields{fieldi})));
end

end


function testSingleDiagonalDivergence(testCase)

RQA = FREQNESS_RQA_Mocap(eye(8));
verifyEqual(testCase,RQA.rr,1/8);
verifyEqual(testCase,RQA.det,1);
verifyEqual(testCase,RQA.l,8);
verifyEqual(testCase,RQA.entr,0);
verifyEqual(testCase,RQA.div,1/8);
verifyEqual(testCase,RQA.lam,0);
verifyTrue(testCase,isnan(RQA.tt));
verifyTrue(testCase,isnan(RQA.vmax));

end


function testBinaryStorageTypes(testCase)

recurrencePlot = testCase.TestData.recurrencePlot;
RQA = FREQNESS_RQA_Mocap(recurrencePlot);
verifyEqual(testCase,RQA,FREQNESS_RQA_Mocap(double(recurrencePlot)));
verifyEqual(testCase,RQA,FREQNESS_RQA_Mocap(uint8(recurrencePlot)));
sparseRQA = FREQNESS_RQA_Mocap(sparse(recurrencePlot));
verifyTrue(testCase,issparse(sparseRQA.rr)); % Preserve the original storage type.
sparseRQA.rr = full(sparseRQA.rr);
verifyEqual(testCase,RQA,sparseRQA);

end


function testInvalidRecurrencePlots(testCase)

invalid = {[],zeros(2,3),zeros(2,2,2),[0 .5;1 0], ...
    [0 NaN;1 0],[0 Inf;1 0],'0101'};
for inputi = 1:numel(invalid)
    verifyFailureMessage(testCase,@() FREQNESS_RQA_Mocap(invalid{inputi}), ...
        'recurrence_plot must be a non-empty square binary matrix.');
end

end


function testInvalidMinimumLengths(testCase)

invalid = {0,-1,1.5,NaN,Inf,[1 2],'2'};
for inputi = 1:numel(invalid)
    verifyFailureMessage(testCase,@() FREQNESS_RQA_Mocap( ...
        eye(8),invalid{inputi},2),'lmin must be one positive integer.');
    verifyFailureMessage(testCase,@() FREQNESS_RQA_Mocap( ...
        eye(8),2,invalid{inputi}),'vmin must be one positive integer.');
end

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
