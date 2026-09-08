function tests = testFREQNESSInterpolateGapsMocap
%TESTFREQNESSINTERPOLATEGAPSMOCAP Tests for MoCap gap interpolation.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testGapFreeDataAreUnchanged(testCase)

data = reshape(1:240,6,20,2);
[filled,badSegments,gapInfo] = ...
    FREQNESS_InterpolateGaps_Mocap(data,100);

verifyEqual(testCase,filled,data);
verifyEmpty(testCase,badSegments);
verifyFalse(testCase,gapInfo.has_gaps);
verifyEmpty(testCase,gapInfo.bad_segments_by_participant{1});
verifyEmpty(testCase,gapInfo.bad_segments_by_participant{2});
verifyEqual(testCase,size(gapInfo.bad_marker_sample_mask),[2 20 2]);

end


function testShortGapsAreLinearAndReturnCoreReadyUnion(testCase)

nSamples = 30;
time = 1:nSamples;
participantOne = repmat(time,6,1)+(1:6)';
participantTwo = 2*repmat(time,6,1)+(1:6)';
original = cat(3,participantOne,participantTwo);
gappy = original;
gappy(1:3,10:12,1) = NaN;
gappy(4:6,5:6,2) = NaN;

verifyWarning(testCase,@() FREQNESS_InterpolateGaps_Mocap(gappy,100), ...
    'FREQNESS:GapInterpolation:MissingDataReconstructed');
[filled,badSegments,gapInfo] = callWithWarningDisabled(gappy,100);

verifyEqual(testCase,filled,original,'AbsTol',1e-12);
verifyEqual(testCase,badSegments,[5 6 10 11 12]);
verifyEqual(testCase,gapInfo.bad_segments_by_participant{1},10:12);
verifyEqual(testCase,gapInfo.bad_segments_by_participant{2},5:6);
verifyEqual(testCase,nnz(gapInfo.interpolated_marker_sample_mask),5);
verifyEqual(testCase,nnz(gapInfo.reconstructed_marker_sample_mask),0);
verifyEqual(testCase,gapInfo.affected_timepoint_count,5);

end


function testLongGapUsesOptionalSplineReconstruction(testCase)

nSamples = 60;
time = linspace(-1,1,nSamples);
original = zeros(6,nSamples);
for coordinateIndex = 1:6
    original(coordinateIndex,:) = coordinateIndex+time+ ...
        coordinateIndex*time.^2+0.2*time.^3;
end
gappy = original;
gappy(1:3,25:34) = NaN;

[filled,badSegments,gapInfo] = callWithWarningDisabled( ...
    gappy,100,'maximum_reconstructed_gap',0.2);

verifyEqual(testCase,filled,original,'AbsTol',1e-10);
verifyEqual(testCase,badSegments,25:34);
verifyEqual(testCase,nnz(gapInfo.interpolated_marker_sample_mask),0);
verifyEqual(testCase,nnz(gapInfo.reconstructed_marker_sample_mask),10);

end


function testObservedCoordinatesRemainExactlyUnchanged(testCase)

rng(13);
original = randn(6,40,2);
gappy = original;
gappy(2,15:17,1) = NaN;
missing = isnan(gappy);

[filled,~,~] = callWithWarningDisabled(gappy,100);

verifyEqual(testCase,filled(~missing),original(~missing),'AbsTol',0);
verifyTrue(testCase,all(isfinite(filled),'all'));

end


function testUnsupportedGapsProduceInformativeError(testCase)

internalLong = randn(6,40);
internalLong(1:3,10:20) = NaN;
verifyError(testCase,@() FREQNESS_InterpolateGaps_Mocap( ...
    internalLong,100),'FREQNESS:GapInterpolation:UnresolvedGaps');

boundary = randn(6,40);
boundary(1:3,1:2) = NaN;
verifyError(testCase,@() FREQNESS_InterpolateGaps_Mocap( ...
    boundary,100,'maximum_reconstructed_gap',0.2), ...
    'FREQNESS:GapInterpolation:UnresolvedGaps');

end


function testInputValidation(testCase)

verifyFailureMessage(testCase,@() FREQNESS_InterpolateGaps_Mocap( ...
    randn(5,20),100), ...
    'The first data dimension must contain complete XYZ marker triplets.');
verifyFailureMessage(testCase,@() FREQNESS_InterpolateGaps_Mocap( ...
    randn(6,20),100,'maximum_interpolated_gap',0), ...
    ['maximum_interpolated_gap must be one positive finite scalar ' ...
    'expressed in seconds.']);
verifyFailureMessage(testCase,@() FREQNESS_InterpolateGaps_Mocap( ...
    randn(6,20),100,'maximum_reconstructed_gap',0.01), ...
    ['maximum_reconstructed_gap must be empty or greater than or equal ' ...
    'to maximum_interpolated_gap.']);

end


function [filled,badSegments,gapInfo] = ...
        callWithWarningDisabled(data,srate,varargin)

warningState = warning('off', ...
    'FREQNESS:GapInterpolation:MissingDataReconstructed');
cleanup = onCleanup(@() warning(warningState));
[filled,badSegments,gapInfo] = FREQNESS_InterpolateGaps_Mocap( ...
    data,srate,varargin{:});

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
