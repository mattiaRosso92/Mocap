function tests = testFREQNESSNetworkEstimationMocap
%TESTFREQNESSNETWORKESTIMATIONMOCAP Regression tests for the MoCap estimator.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(genpath(fullfile(toolboxRoot,'FREQNESS_Functions')));
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


function testDetectedGapsMatchStandalonePreprocessing(testCase)

rng(37);
srate = 120;
data = randn(6,480,2);
gappyData = data;
gappyData(1:3,191:194,1) = NaN;
gappyData(4:6,251:255,2) = NaN;
arguments = {2,srate,'fwidth',0.3,'ncomps',2};

warningState = warning('off', ...
    'FREQNESS:GapInterpolation:MissingDataReconstructed');
cleanup = onCleanup(@() warning(warningState));
automatic = FREQNESS_NetworkEstimation_Mocap(gappyData,arguments{:});
[filledData,detectedBadSegments] = ...
    FREQNESS_InterpolateGaps_Mocap(gappyData,srate);
manual = FREQNESS_NetworkEstimation_Mocap( ...
    filledData,arguments{:},'interpolate_gaps',false, ...
    'bad_segments',detectedBadSegments);

verifyEqual(testCase,automatic.evals,manual.evals);
verifyEqual(testCase,automatic.evecs,manual.evecs);
verifyEqual(testCase,automatic.pats,manual.pats);
verifyEqual(testCase,automatic.ts,manual.ts);
verifyEqual(testCase,automatic.bad_segments,[191:194 251:255]);
verifyEqual(testCase,automatic.bad_segments_by_participant{1},191:194);
verifyEqual(testCase,automatic.bad_segments_by_participant{2},251:255);
verifyTrue(testCase,automatic.gap_info.has_gaps);

end


function testDetectedAndSuppliedBadSegmentsAreCombined(testCase)

rng(41);
data = randn(6,360,2);
data(1:3,101:103,1) = NaN;
suppliedBadSegments = [50 200 50];

warningState = warning('off', ...
    'FREQNESS:GapInterpolation:MissingDataReconstructed');
cleanup = onCleanup(@() warning(warningState));
FREQ = FREQNESS_NetworkEstimation_Mocap(data,2,120, ...
    'fwidth',0.3,'ncomps',2,'bad_segments',suppliedBadSegments);

verifyEqual(testCase,FREQ.bad_segments,[50 101:103 200]);
verifyEqual(testCase,FREQ.bad_segments_by_participant{1},[50 101:103 200]);
verifyEqual(testCase,FREQ.bad_segments_by_participant{2},[50 200]);
verifyEqual(testCase,FREQ.gap_info.detected_bad_segments,101:103);
verifyEqual(testCase,FREQ.gap_info.supplied_bad_segments,[50 200]);

end


function testAutomaticGapWarningAndDisableOption(testCase)

data = randn(6,360,2);
data(1:3,101:103,1) = NaN;
arguments = {2,120,'fwidth',0.3,'ncomps',2};

verifyWarning(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,arguments{:}), ...
    'FREQNESS:GapInterpolation:MissingDataReconstructed');
verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,arguments{:},'interpolate_gaps',false), ...
    ['data contains NaN gaps while interpolate_gaps is false. Enable ' ...
    'automatic interpolation or preprocess the gaps before estimation.']);

end


function testOptionalLongGapReconstructionIsForwarded(testCase)

rng(43);
data = randn(6,360,2);
data(1:3,101:110,1) = NaN;
arguments = {2,120,'fwidth',0.3,'ncomps',2};

verifyError(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,arguments{:}),'FREQNESS:GapInterpolation:UnresolvedGaps');

warningState = warning('off', ...
    'FREQNESS:GapInterpolation:MissingDataReconstructed');
cleanup = onCleanup(@() warning(warningState));
FREQ = FREQNESS_NetworkEstimation_Mocap(data,arguments{:}, ...
    'maximum_reconstructed_gap',0.1);

verifyEqual(testCase,FREQ.bad_segments,101:110);
verifyEqual(testCase,nnz( ...
    FREQ.gap_info.reconstructed_marker_sample_mask),10);

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
dataMessage = ['data must be a non-empty real numeric array without Inf values in ' ...
    '[marker coordinates x time] or ' ...
    '[marker coordinates x time x participants] format. NaN gaps can ' ...
    'be reconstructed automatically.'];

verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap(), ...
    'data, frex, and srate are required inputs.');

invalidData = {[], 'data', complex(data,data), ...
    replaceDataValue(data,Inf), zeros(2,3,2,2)};
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

verifyFailureMessage(testCase,@() FREQNESS_NetworkEstimation_Mocap( ...
    data,baseArguments{:},'interpolate_gaps',1), ...
    'interpolate_gaps must be one logical value (true or false).');

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


function testGEDLoopParity(testCase)

rng(97);
nCoordinates = 6;
nSamples = 480;
nParticipants = 2;
srate = 120;
frex = [1 1.5; 2 2.5];
fwidth = [0.2 0.25; 0.3 0.35];
regularisation = 0.01;
ncomps = 2;
data = randn(nCoordinates,nSamples,nParticipants);

commandWindowOutput = evalc(['FREQ = FREQNESS_NetworkEstimation_Mocap(' ...
    'data,frex,srate,''fwidth'',fwidth,''regularisation'',' ...
    'regularisation,''ncomps'',ncomps);']);

verifySubstring(testCase,commandWindowOutput, ...
    ['FREQNESS Network Estimation: estimating frequency-resolved ' ...
    'networks for 2 participants.']);
for participantIndex = 1:nParticipants
    verifySubstring(testCase,commandWindowOutput, ...
        ['FREQNESS Network Estimation: participant #' ...
        num2str(participantIndex)]);

    broadData = data(:,:,participantIndex);
    covR = cov(broadData');
    evalsR = eig(covR);
    covR = (1-regularisation)*covR + ...
        regularisation*mean(evalsR)*eye(size(covR));

    for frequencyIndex = 1:size(frex,1)
        verifySubstring(testCase,commandWindowOutput, ...
            ['Estimating network at ' ...
            num2str(frex(frequencyIndex,participantIndex)) ' Hz']);

        narrowData = filterFGx(broadData,srate, ...
            frex(frequencyIndex,participantIndex), ...
            fwidth(frequencyIndex,participantIndex),0);
        covS = cov(narrowData') + 1e-6*eye(nCoordinates);

        for componentIndex = 1:ncomps
            expectedPattern = covS * FREQ.evecs( ...
                :,componentIndex,frequencyIndex,participantIndex);
            [~,maximumIndex] = max(abs(expectedPattern));
            expectedPattern = expectedPattern * ...
                sign(expectedPattern(maximumIndex));
            verifyEqual(testCase,FREQ.pats( ...
                :,componentIndex,frequencyIndex,participantIndex), ...
                expectedPattern,'AbsTol',1e-10);
        end
    end
end

end


function testSingleParticipantOutputContract(testCase)

rng(101);
nCoordinates = 6;
srate = 120;
duration = 2;
nSamplesToKeep = duration*srate;
frex = [1 2];
fwidth = [0.2 0.3];
regularisation = 0.05;
ncomps = 1;
data = randn(nCoordinates,480);

FREQ = FREQNESS_NetworkEstimation_Mocap(data,frex,srate, ...
    'duration',duration,'fwidth',fwidth, ...
    'regularisation',regularisation,'ncomps',ncomps);

verifyEqual(testCase,size(FREQ.evals,1),nCoordinates);
verifyEqual(testCase,size(FREQ.evals,2),numel(frex));
verifyEqual(testCase,size(FREQ.evals,3),1);

verifyEqual(testCase,size(FREQ.evecs,1),nCoordinates);
verifyEqual(testCase,size(FREQ.evecs,2),ncomps);
verifyEqual(testCase,size(FREQ.evecs,3),numel(frex));
verifyEqual(testCase,size(FREQ.evecs,4),1);
verifyEqual(testCase,size(FREQ.pats),size(FREQ.evecs));

verifyEqual(testCase,size(FREQ.ts,1),ncomps);
verifyEqual(testCase,size(FREQ.ts,2),nSamplesToKeep);
verifyEqual(testCase,size(FREQ.ts,3),numel(frex));
verifyEqual(testCase,size(FREQ.ts,4),1);

verifyEqual(testCase,FREQ.srate,srate);
verifyEqual(testCase,FREQ.duration,duration);
verifyEqual(testCase,FREQ.regularisation,regularisation);

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
