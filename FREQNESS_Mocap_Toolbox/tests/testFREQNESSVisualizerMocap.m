function tests = testFREQNESSVisualizerMocap
%TESTFREQNESSVISUALIZERMOCAP Tests for gap-aware marker visualization.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(genpath(fullfile(toolboxRoot,'FREQNESS_Functions')));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testNaNMarkerDataUseSharedGapInterpolation(testCase)

originalVisibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanup = onCleanup(@() restoreFigures(originalVisibility));

nSamples = 30;
time = 1:nSamples;
markerData = repmat(time,6,1)+(1:6)';
markerData(1:3,10:12) = NaN;

FREQ = struct();
FREQ.evals = (1:6)';
FREQ.frex = 1;
FREQ.pats = randn(6,1);
FREQ.ts = randn(1,nSamples);
FREQ.gap_info = struct( ...
    'maximum_interpolated_gap_seconds',0.05, ...
    'maximum_reconstructed_gap_seconds',[]);

Patterns = struct('frex',1,'labels',{{'Marker 1','Marker 2'}}, ...
    'markerData',markerData,'comp',1,'srate',100,'start',0, ...
    'plot_bones',false,'plot_matrix',false,'animate',false);

verifyWarning(testCase,@() FREQNESS_Visualizer_Mocap( ...
    FREQ,[],Patterns),'FREQNESS:GapInterpolation:MissingDataReconstructed');

end


function restoreFigures(originalVisibility)

close all force
set(groot,'DefaultFigureVisible',originalVisibility);

end
