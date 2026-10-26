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


function testMethodAwareLandscapeLabels(testCase)

original_visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanup = onCleanup(@() restoreFigures(original_visibility));
FREQ = struct('evals',[60 50 40; 40 50 60],'frex',[1 2 4]);
Landscape = struct('frex',[1 2 4],'ncomps',2);
methods = {'','ged','pca'};
labels = {'FREQ','GED','PCA'};
for methodi = 1:3
    if methodi>1, FREQ.method = methods{methodi}; end
    figures = FREQNESS_Visualizer_Mocap(FREQ,Landscape);
    ax = findobj(figures.landscape,'Type','axes');
    if methodi==3
        verifyEqual(testCase,ax.YLabel.String,'Narrowband variance (%)');
    else
        verifyEqual(testCase,ax.YLabel.String,'Relative eigenvalue contribution (%)');
    end
    curve = findobj(ax,'Type','line','DisplayName',[labels{methodi} ' #1']);
    assertNumElements(testCase,curve,1);
    verifyEqual(testCase,curve.YData([1 end]),[60 40],'AbsTol',1e-12);
end

end


function testVelocityStaticPatternsButNoPositionalAnimation(testCase)

original_visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanup = onCleanup(@() restoreFigures(original_visibility));
rng(151);
FREQ = struct('evals',(1:6)','frex',1,'pats',randn(6,1), ...
    'ts',randn(1,29),'method','pca','kinematics','velocity');
Patterns = struct('frex',1,'labels',{{'Marker 1','Marker 2'}}, ...
    'markerData',randn(6,30),'comp',1,'srate',100,'start',0, ...
    'plot_bones',false,'plot_matrix',true,'animate',false);
figures = FREQNESS_Visualizer_Mocap(FREQ,[],Patterns);
verifyNumElements(testCase,figures.patterns,1);
verifyNumElements(testCase,figures.pattern_matrix,1);
verifyEmpty(testCase,figures.animation);
Patterns.animate = true;
verifyError(testCase,@() FREQNESS_Visualizer_Mocap(FREQ,[],Patterns), ...
    'FREQNESS:Visualizer:VelocityAnimation');

end


function restoreFigures(originalVisibility)

close all force
set(groot,'DefaultFigureVisible',originalVisibility);

end
