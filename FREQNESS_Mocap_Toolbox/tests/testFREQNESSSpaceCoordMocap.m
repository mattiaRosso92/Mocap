function tests = testFREQNESSSpaceCoordMocap
%TESTFREQNESSSPACECOORDMOCAP Raw/Fisher output and compatibility checks.
tests = functiontests(localfunctions);
end


function setupOnce(testCase)
toolbox_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(toolbox_root,'FREQNESS_Functions'));
first = [1 3 4;2 1 3;4 2 1;3 5 2;5 4 5];
second = [2 4 1;4 2 2;1 3 4;5 1 3;3 5 5];
FREQ.frex = [1 1.1;2 2.2;4 4.4];
FREQ.pats = zeros(5,2,3,2);
FREQ.pats(:,1,:,1) = reshape(first,5,1,3);
FREQ.pats(:,2,:,1) = reshape(first([2 5 1 4 3],:),5,1,3);
FREQ.pats(:,1,:,2) = reshape(second,5,1,3);
FREQ.pats(:,2,:,2) = reshape(second,5,1,3);
FREQ.pats([1 3],:,:,1) = -FREQ.pats([1 3],:,:,1);
testCase.TestData.FREQ = FREQ;
end


function testRawDefaultIsUnchanged(testCase)
FREQ = testCase.TestData.FREQ;
for component = 1:2
    expected = zeros(1,3);
    for metri = 1:3
        expected(metri) = corr(abs(FREQ.pats(:,component,metri,1)), ...
            abs(FREQ.pats(:,component,metri,2)));
    end
    actual = FREQNESS_SpaceCoord_Mocap(FREQ,[1 1.1], ...
        'component',component,'metric_levels',[1 2 4]);
    explicit = FREQNESS_SpaceCoord_Mocap(FREQ,[1 1.1], ...
        'component',component,'metric_levels',[1 2 4],'Fisher',false);
    verifyEqual(testCase,actual,expected);
    verifyEqual(testCase,explicit,actual);
    verifySize(testCase,actual,[1 3]);
end
verifyEqual(testCase,nargout('FREQNESS_SpaceCoord_Mocap'),1);
end


function testFisherUsesSameSingleOutput(testCase)
FREQ = testCase.TestData.FREQ;
for component = 1:2
    raw = FREQNESS_SpaceCoord_Mocap(FREQ,[1 1.1], ...
        'component',component,'metric_levels',[1 2 4]);
    actual = FREQNESS_SpaceCoord_Mocap(FREQ,[1 1.1], ...
        'component',component,'metric_levels',[1 2 4],'Fisher',true);
    verifyEqual(testCase,actual,atanh(raw));
    verifyEqual(testCase,tanh(actual),raw,'AbsTol',1e-14);
    verifySize(testCase,actual,[1 3]);
end
FREQ.frex = FREQ.frex(:,1); % Shared grid and case-insensitive option name.
raw = FREQNESS_SpaceCoord_Mocap(FREQ,[1 1]);
verifyEqual(testCase,FREQNESS_SpaceCoord_Mocap(FREQ,[1 1],'FISHER',true),atanh(raw));
end


function testPerfectAndUndefinedCorrelations(testCase)
FREQ.frex = [1;2;4];
FREQ.pats = zeros(4,1,3,2);
FREQ.pats(:,1,:,1) = reshape([1 1 1;3 3 1;1 1 1;3 3 1],4,1,3);
FREQ.pats(:,1,:,2) = reshape([1 3 1;3 1 3;1 3 1;3 1 3],4,1,3);
raw = FREQNESS_SpaceCoord_Mocap(FREQ,[1 1],'metric_levels',[1 2 4]);
actual = FREQNESS_SpaceCoord_Mocap(FREQ,[1 1], ...
    'metric_levels',[1 2 4],'Fisher',true);
verifyEqual(testCase,raw(1:2),[1 -1]);
verifyEqual(testCase,actual(1:2),[Inf -Inf]);
verifyTrue(testCase,isnan(raw(3)) && isnan(actual(3)));
end


function testFisherRequiresLogicalScalar(testCase)
FREQ = testCase.TestData.FREQ;
for value = {[],0,1,2,NaN,Inf,[true false],"true",'false',struct()}
    rejected = false;
    try
        FREQNESS_SpaceCoord_Mocap(FREQ,[1 1.1],'Fisher',value{1});
    catch ME
        rejected = strcmp(ME.message,'Fisher must be one logical scalar.');
    end
    verifyTrue(testCase,rejected);
end
end
