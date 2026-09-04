function tests = testFREQNESSNetworkEstimationMocap
%TESTFREQNESSNETWORKESTIMATIONMOCAP Regression tests for the MoCap estimator.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
addpath(fullfile(toolboxRoot,'FREQNESS_ExternalFunctions'));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testBadSegmentsMatchManualMaskedCovariances(testCase)

rng(17);
nCoordinates = 6;
nSamples = 600;
nParticipants = 2;
srate = 120;
frex = 2;
fwidth = 0.3;
regularisation = 0.01;
ncomps = 2;
data = randn(nCoordinates,nSamples,nParticipants);
badSegments = 191:230;
data(:,badSegments,:) = data(:,badSegments,:) + 25;
badSegmentsWithDuplicates = [badSegments badSegments(1:3)];

FREQ = FREQNESS_NetworkEstimation_Mocap(data,frex,srate, ...
    'fwidth',fwidth,'regularisation',regularisation, ...
    'ncomps',ncomps,'bad_segments',badSegmentsWithDuplicates);

goodSegments = setdiff(1:nSamples,badSegments);
for participantIndex = 1:nParticipants
    broadData = data(:,:,participantIndex);
    narrowData = filterFGx(broadData,srate,frex,fwidth,0);
    covS = cov(narrowData(:,goodSegments)');
    covR = cov(broadData(:,goodSegments)');
    covS = covS + 1e-6*eye(size(covS));
    evalsR = eig(covR);
    covR = (1-regularisation)*covR + ...
        regularisation*mean(evalsR)*eye(size(covR));
    [~,evals] = eig(covS,covR);
    expectedEvals = sort(diag(evals),'descend');
    expectedEvals = 100*expectedEvals/sum(expectedEvals);

    verifyEqual(testCase,FREQ.evals(:,1,participantIndex), ...
        expectedEvals,'AbsTol',1e-10);
end
verifyEqual(testCase,FREQ.bad_segments,badSegments);

end


function testEmptyBadSegmentsPreservePreviousBehavior(testCase)

rng(31);
data = randn(6,480,2);
arguments = {2,120,'fwidth',0.3,'ncomps',2};

withoutOption = FREQNESS_NetworkEstimation_Mocap(data,arguments{:});
withEmptyOption = FREQNESS_NetworkEstimation_Mocap( ...
    data,arguments{:},'bad_segments',[]);

verifyEqual(testCase,withEmptyOption.evals,withoutOption.evals);
verifyEqual(testCase,withEmptyOption.evecs,withoutOption.evecs);
verifyEqual(testCase,withEmptyOption.pats,withoutOption.pats);
verifyEqual(testCase,withEmptyOption.ts,withoutOption.ts);
verifyEmpty(testCase,withEmptyOption.bad_segments);

end


function testBadSegmentValidation(testCase)

data = randn(6,240,2);
baseArguments = {2,120,'fwidth',0.3,'ncomps',2};

verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'bad_segments',1.5), ...
    'bad_segments must contain finite integer sample indices.');
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'bad_segments',241), ...
    'One or more indices in bad_segments fall outside the analyzed time range.');
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'bad_segments',1:239), ...
    'Fewer than two samples remain for covariance estimation.');

end


function testShorterDurationUsesOnlyRequestedSamples(testCase)

rng(53);
srate = 120;
duration = 2;
nSamples = 480;
pnts2keep = duration*srate;
data = randn(6,nSamples,2);
arguments = {2,srate,'fwidth',0.3,'ncomps',2};

withDuration = FREQNESS_NetworkEstimation_Mocap( ...
    data,arguments{:},'duration',duration);
physicallyTruncated = FREQNESS_NetworkEstimation_Mocap( ...
    data(:,1:pnts2keep,:),arguments{:});

verifyEqual(testCase,withDuration.evals,physicallyTruncated.evals);
verifyEqual(testCase,withDuration.evecs,physicallyTruncated.evecs);
verifyEqual(testCase,withDuration.pats,physicallyTruncated.pats);
verifyEqual(testCase,withDuration.ts,physicallyTruncated.ts);
verifySize(testCase,withDuration.ts,[2 pnts2keep 1 2]);
verifyEqual(testCase,withDuration.duration,duration);

end


function testDurationValidation(testCase)

data = randn(6,240,2);
baseArguments = {2,120,'fwidth',0.3,'ncomps',2};

verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'duration',0), ...
    'duration must be one positive finite scalar expressed in seconds.');
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'duration',[1 2]), ...
    'duration must be one positive finite scalar expressed in seconds.');
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'duration',1/7), ...
    'duration multiplied by srate must define an integer number of samples.');
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'duration',3), ...
    'Requested duration exceeds the length of the data.');
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'duration',1/120), ...
    'The requested duration must contain at least two samples.');

end


function testMandatoryInputValidation(testCase)

data = randn(6,240,2);
baseArguments = {'fwidth',0.3,'ncomps',2};
dataMessage = ['data must be a non-empty, real, finite numeric array in ' ...
    '[marker coordinates x time] or ' ...
    '[marker coordinates x time x participants] format.'];

verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap(), ...
    'data, frex, and srate are required inputs.');

invalidData = {[], 'data', complex(data,data), ...
    replaceDataValue(data,NaN), zeros(2,3,2,2)};
for invalidIndex = 1:numel(invalidData)
    verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
        invalidData{invalidIndex},2,120,baseArguments{:}),dataMessage);
end

invalidSamplingRates = {0, [120 120], Inf, '120'};
for invalidIndex = 1:numel(invalidSamplingRates)
    verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
        data,2,invalidSamplingRates{invalidIndex},baseArguments{:}), ...
        'srate must be one positive finite scalar.');
end

invalidFrequencies = {[], -2, NaN, zeros(1,1,2)};
for invalidIndex = 1:numel(invalidFrequencies)
    verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
        data,invalidFrequencies{invalidIndex},120,baseArguments{:}), ...
        'frex must contain positive finite frequencies.');
end

end


function testOptionalInputValidation(testCase)

data = randn(6,240,2);
baseArguments = {2,120,'fwidth',0.3,'ncomps',2};

verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'filter','quadratic'), ...
    'filter must be either ''logarithmic'' or ''linear''.');

invalidRegularisation = {-0.1, 1, [0.01 0.02], complex(0.01,0.01), NaN};
for invalidIndex = 1:numel(invalidRegularisation)
    verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
        data,baseArguments{:},'regularisation', ...
        invalidRegularisation{invalidIndex}), ...
        'regularisation must be one finite scalar in the interval [0, 1).');
end

invalidComponentCounts = {0, 1.5, [1 2], complex(1,1), NaN};
for invalidIndex = 1:numel(invalidComponentCounts)
    verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
        data,2,120,'fwidth',0.3,'ncomps', ...
        invalidComponentCounts{invalidIndex}), ...
        'ncomps must be one positive integer.');
end
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,2,120,'fwidth',0.3,'ncomps',7), ...
    'ncomps cannot exceed the number of marker coordinates.');

invalidFilterWidths = {-0.3, complex(0.3,0.1), [0.2 0.3 0.4], NaN};
for invalidIndex = 1:numel(invalidFilterWidths)
    verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
        data,2,120,'fwidth',invalidFilterWidths{invalidIndex},'ncomps',2), ...
        ['fwidth must be empty, a positive scalar, a shared nFrex ' ...
        'vector, or an [nFrex x nParticipants] matrix.']);
end

end


function testNyquistValidation(testCase)

data = randn(6,240,2);
expectedMessage = ...
    'All frequencies in frex must be lower than the Nyquist frequency.';

verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,[2 60],120,'fwidth',0.3,'ncomps',2),expectedMessage);
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,[2 3; 4 60],120,'fwidth',0.3,'ncomps',2),expectedMessage);

end


function testEigenvalueNormalizationSafety(testCase)

data = zeros(6,240,2);

verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,2,120,'fwidth',0.3,'regularisation',0,'ncomps',2), ...
    ['Generalized eigenvalues cannot be normalized because their sum ' ...
    'is zero or non-finite.']);

end


function testParticipantSpecificInputsRemainSupported(testCase)

rng(79);
data = randn(6,480,2);
frex = [1 1.5; 2 2.5];
fwidth = [0.2 0.25; 0.3 0.35];

FREQ = FREQNESS_NetworkEstimation_Mocap(data,frex,120, ...
    'fwidth',fwidth,'ncomps',2);

verifyEqual(testCase,FREQ.frex,frex);
verifyEqual(testCase,FREQ.fwhm,fwidth);
verifySize(testCase,FREQ.evals,[6 2 2]);
verifySize(testCase,FREQ.evecs,[6 2 2 2]);

end


function outputData = replaceDataValue(inputData,replacementValue)

outputData = inputData;
outputData(1) = replacementValue;

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

didThrow = false;
try
    functionHandle();
catch exception
    didThrow = true;
    verifyEqual(testCase,exception.message,expectedMessage);
end
verifyTrue(testCase,didThrow,'Expected the function to throw an error.');

end
