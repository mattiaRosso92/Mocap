function tests = testFREQNESSPhaseSpaceRQAMocap
%TESTFREQNESSPHASESPACERQAMOCAP Regression tests for phase-space RQA.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
addpath(fullfile(toolboxRoot,'FREQNESS_ExternalFunctions'));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testNoBadSegmentsPreserveRQADefinitions(testCase)

FREQ = syntheticFREQ(80);
threshold = .35;
FREQrqa = FREQNESS_PhaseSpaceRQA_Mocap(FREQ,1, ...
    'threshold',threshold,'store_matrices',true);

phaseSpace = [squeeze(FREQ.ts(1,:,1,1))' ...
    squeeze(FREQ.ts(1,:,1,2))'];
phaseSpace = (phaseSpace-mean(phaseSpace,1))./std(phaseSpace,0,1);
distanceMatrix = euclideanDistanceMatrix(phaseSpace);
recurrencePlot = distanceMatrix < max(distanceMatrix(:))*threshold;

RQA = FREQNESS_RQA_Mocap(recurrencePlot);
verifyEqual(testCase,FREQrqa.RR,RQA.rr,'AbsTol',eps);
verifyEqual(testCase,FREQrqa.L,RQA.l);
verifyEqual(testCase,FREQrqa.DET,RQA.det);
verifyEqual(testCase,FREQrqa.ENTR,RQA.entr);
verifyEqual(testCase,FREQrqa.TT,RQA.tt);
verifyEqual(testCase,FREQrqa.LAM,RQA.lam);
verifyEqual(testCase,FREQrqa.Vmax,RQA.vmax);
verifyEqual(testCase,FREQrqa.DIV,RQA.div);
verifyEqual(testCase,FREQrqa.ValidSampleCount,80);
verifyEqual(testCase,FREQrqa.ExcludedSampleCount,0);
verifyEqual(testCase,FREQrqa.EligiblePairCount,80^2);
verifyTrue(testCase,all(FREQrqa.ValidSampleMask));
verifyEmpty(testCase,FREQrqa.BadSegments);

end


function testEstimatorBadSegmentsFlowDirectlyIntoRQA(testCase)

rng(27);
badSegments = 91:105;
data = randn(6,360,2);
FREQ = FREQNESS_NetworkEstimation_Mocap(data,2,120, ...
    'fwidth',.3,'ncomps',1,'bad_segments',badSegments);
FREQrqa = FREQNESS_PhaseSpaceRQA_Mocap(FREQ,2);

verifyEqual(testCase,FREQrqa.BadSegments,badSegments);
verifyFalse(testCase,any(FREQrqa.ValidSampleMask(badSegments)));
verifyEqual(testCase,FREQrqa.ExcludedSampleCount,numel(badSegments));
verifyEqual(testCase,FREQrqa.ValidSampleCount,360-numel(badSegments));

end


function testBadSamplesCannotAffectDistancesOrMetrics(testCase)

badSegments = [20:25 40];
FREQ1 = syntheticFREQ(80);
FREQ1.bad_segments = badSegments;
FREQ2 = FREQ1;
FREQ1.ts(:,badSegments,:,:) = 1e8;
FREQ2.ts(:,badSegments,:,:) = -1e12;

arguments = {'threshold',.35,'store_matrices',true};
first = FREQNESS_PhaseSpaceRQA_Mocap(FREQ1,1,arguments{:});
second = FREQNESS_PhaseSpaceRQA_Mocap(FREQ2,1,arguments{:});

metricFields = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
for fieldi = 1:numel(metricFields)
    verifyEqual(testCase,first.(metricFields{fieldi}), ...
        second.(metricFields{fieldi}));
end
verifyTrue(testCase,all(isnan(first.PhaseSpace(badSegments,:)),'all'));
verifyTrue(testCase,all(isnan(first.DistanceMatrix(badSegments,:)),'all'));
verifyTrue(testCase,all(isnan(first.DistanceMatrix(:,badSegments)),'all'));
verifyFalse(testCase,any(first.RecurrencePlot(badSegments,:),'all'));
verifyFalse(testCase,any(first.RecurrencePlot(:,badSegments),'all'));
verifyFalse(testCase,any(first.EligiblePairMask(badSegments,:),'all'));
verifyFalse(testCase,any(first.EligiblePairMask(:,badSegments),'all'));
verifyEqual(testCase,first.ValidSampleCount,80-numel(badSegments));
verifyEqual(testCase,first.ExcludedSampleCount,numel(badSegments));
verifyEqual(testCase,first.EligiblePairCount, ...
    (80-numel(badSegments))^2);
verifyEqual(testCase,first.RR, ...
    sum(first.RecurrencePlot(first.EligiblePairMask))/ ...
    nnz(first.EligiblePairMask),'AbsTol',eps);

end


function testStoredAndAdditionalBadSegmentsAreCombinedAndMapped(testCase)

FREQ = syntheticFREQ(30);
FREQ.bad_segments = [8 20 8];
FREQrqa = FREQNESS_PhaseSpaceRQA_Mocap(FREQ,1, ...
    'duration',[.2 .8],'downsample',2, ...
    'bad_segments',[14 20 14],'store_matrices',true);

expectedSamples = 6:2:24;
expectedMask = ~ismember(expectedSamples,[8 14 20]);
verifyEqual(testCase,FREQrqa.BadSegments,[8 20 14]);
verifyEqual(testCase,FREQrqa.SelectedSampleIndices,expectedSamples);
verifyEqual(testCase,FREQrqa.ValidSampleMask,expectedMask);
verifyEqual(testCase,FREQrqa.ValidSampleCount,nnz(expectedMask));
verifyEqual(testCase,FREQrqa.ExcludedSampleCount,nnz(~expectedMask));

end


function testTheilerAndBadSegmentsDefineEligiblePairs(testCase)

FREQ = syntheticFREQ(40);
FREQ.bad_segments = [10 11 28];
theilerWindow = 2;
FREQrqa = FREQNESS_PhaseSpaceRQA_Mocap(FREQ,1, ...
    'threshold_method','fixed_rr','threshold',.2, ...
    'theiler_window',theilerWindow,'store_matrices',true);

valid = true(40,1);
valid(FREQ.bad_segments) = false;
[rowIndex,columnIndex] = ndgrid(1:40,1:40);
expectedEligible = valid & valid' & ...
    abs(rowIndex-columnIndex) > theilerWindow;
verifyEqual(testCase,FREQrqa.EligiblePairMask,expectedEligible);
verifyEqual(testCase,FREQrqa.EligiblePairCount,nnz(expectedEligible));
verifyEqual(testCase,FREQrqa.RR, ...
    sum(FREQrqa.RecurrencePlot(expectedEligible))/nnz(expectedEligible), ...
    'AbsTol',eps);

end


function testBadSegmentValidation(testCase)

FREQ = syntheticFREQ(30);
verifyFailureMessage(testCase,@() FREQNESS_PhaseSpaceRQA_Mocap( ...
    FREQ,1,'bad_segments',1.5), ...
    'bad_segments must contain finite integer sample indices.');
verifyFailureMessage(testCase,@() FREQNESS_PhaseSpaceRQA_Mocap( ...
    FREQ,1,'bad_segments',31), ...
    'bad_segments contains indices outside FREQ.ts.');
FREQ.bad_segments = NaN;
verifyFailureMessage(testCase,@() FREQNESS_PhaseSpaceRQA_Mocap(FREQ,1), ...
    'FREQ.bad_segments must contain finite integer sample indices.');

end


function FREQ = syntheticFREQ(nSamples)

time = linspace(0,8*pi,nSamples);
FREQ = struct();
FREQ.ts = zeros(1,nSamples,1,2);
FREQ.ts(1,:,1,1) = sin(time) + .1*cos(3*time);
FREQ.ts(1,:,1,2) = cos(.8*time) + .2*sin(2*time);
FREQ.frex = 1;

end


function distanceMatrix = euclideanDistanceMatrix(phaseSpace)

squaredNorm = sum(phaseSpace.^2,2);
squaredDistance = squaredNorm+squaredNorm'-2*(phaseSpace*phaseSpace');
squaredDistance(squaredDistance < 0) = 0;
distanceMatrix = sqrt(squaredDistance);

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
