function tests = testFREQNESSTimeCoordMocap
%TESTFREQNESSTIMECOORDMOCAP Regression tests for JRQA coordination.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
addpath(fullfile(toolboxRoot,'FREQNESS_ExternalFunctions'));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testValidatedRadiusJRQAPreservesOutputContract(testCase)

FREQ = syntheticFREQ(600);
JRQA = struct('m',2,'tau',4,'ps',0.5);

% Select JRQA explicitly through the unified temporal interface.
output = FREQNESS_TimeCoord_Mocap(FREQ,[1 1], ...
    'method','jrqa','jrqa',JRQA, ...
    'implementation','validated','threshold_method','radius', ...
    'store_matrices',true);

public_fields = {'RR','DET','L','Lmax','ENTR','LAM','TT', ...
    'Vmax','T1','T2'};
for fieldi = 1:numel(public_fields)
    verifyTrue(testCase,isfield(output,public_fields{fieldi}));
end
verifyGreaterThan(testCase,output.RR,0);
verifyLessThanOrEqual(testCase,output.RR,1);
verifyGreaterThanOrEqual(testCase,output.DET,0);
verifyLessThanOrEqual(testCase,output.DET,1);
verifyEqual(testCase,output.EmbeddingDimension,2);
verifyEqual(testCase,output.Delay,4);
verifyEqual(testCase,size(output.ParticipantRecurrencePlots,3),2);
verifyEqual(testCase,output.JointRecurrencePlot, ...
    all(output.ParticipantRecurrencePlots,3));

end


function testFixedMarginalRRAndTheilerAreExplicit(testCase)

FREQ = syntheticFREQ(500);
JRQA = struct('m',3,'tau',5);
targetRR = 0.1;
theilerWindow = (JRQA.m-1)*JRQA.tau;
output = FREQNESS_TimeCoord_Mocap(FREQ,[1 1], ...
    'method','jrqa','jrqa',JRQA, ...
    'implementation','validated','threshold_method','fixed_rr', ...
    'threshold',targetRR,'theiler_window',theilerWindow, ...
    'store_matrices',true);

verifyEqual(testCase,output.TheilerWindow,theilerWindow);
verifyEqual(testCase,output.ThresholdMethod,'fixed_rr');
verifyEqual(testCase,output.MarginalRR,[targetRR targetRR], ...
    'AbsTol',0.005);
verifyEqual(testCase,output.RR, ...
    sum(output.JointRecurrencePlot(output.EligiblePairMask))/ ...
    nnz(output.EligiblePairMask),'AbsTol',eps);
verifyFalse(testCase,any(output.JointRecurrencePlot( ...
    ~output.EligiblePairMask),'all'));

end


function testAdaptiveMaximumRadiusUsesFinalEmbedding(testCase)

FREQ = syntheticFREQ(600);
JRQA = struct('m',3,'tau',5,'RadiusFraction',0.10);
output = FREQNESS_TimeCoord_Mocap(FREQ,[1 1], ...
    'method','jrqa','jrqa',JRQA, ...
    'implementation','validated', ...
    'threshold_method','adaptive_max_radius', ...
    'store_matrices',true);

verifyEqual(testCase,output.ThresholdMethod,'adaptive_max_radius');
verifyEqual(testCase,output.RadiusFraction,0.10);
verifySize(testCase,output.ParticipantRadiusEstimates,[1 2]);
verifyGreaterThan(testCase,min(output.ParticipantRadiusEstimates),0);
verifyEqual(testCase,output.Thresholds, ...
    repmat(max(output.ParticipantRadiusEstimates),1,2));

for subi = 1:2
    phase_space = output.PhaseSpace{subi};
    squared_norm = sum(phase_space.^2,2);
    squared_distance = squared_norm+squared_norm'- ...
        2*(phase_space*phase_space');
    squared_distance(squared_distance < 0) = 0;
    expected_radius = 0.10*max(sqrt(squared_distance),[],'all');
    verifyEqual(testCase,output.ParticipantRadiusEstimates(subi), ...
        expected_radius,'AbsTol',1e-12);
end

end


function testOptionalStandardizationPreservesUnitsAndScaleInvariance(testCase)

FREQ = syntheticFREQ(350);
scaled_freq = FREQ;
scaled_freq.ts(1,:,1,1) = 3*FREQ.ts(1,:,1,1)+12;
scaled_freq.ts(1,:,1,2) = 7*FREQ.ts(1,:,1,2)-5;
JRQA = struct('m',3,'tau',4,'ps',0.8);
arguments = {'method','jrqa','jrqa',JRQA, ...
    'implementation','validated','store_matrices',true};
baseline = FREQNESS_TimeCoord_Mocap(FREQ,[1 1],arguments{:},'standardize',true);
normalized = FREQNESS_TimeCoord_Mocap( ...
    scaled_freq,[1 1],arguments{:},'standardize',true);
raw = FREQNESS_TimeCoord_Mocap( ...
    scaled_freq,[1 1],arguments{:},'standardize',false);

verifyTrue(testCase,normalized.Preprocessing.Standardized);
verifyFalse(testCase,raw.Preprocessing.Standardized);
verifyEqual(testCase,normalized.JointRecurrencePlot,baseline.JointRecurrencePlot);
verifyEqual(testCase,normalized.Thresholds,[0.8 0.8]);
for subi = 1:2
    series = reshape(scaled_freq.ts(1,:,1,subi),[],1);
    nstates = size(raw.PhaseSpace{subi},1);
    verifyEqual(testCase,raw.PhaseSpace{subi}(:,1),series(1:nstates));
    verifyEqual(testCase,normalized.Preprocessing.SeriesMean(subi), ...
        mean(series),'AbsTol',1e-12);
    verifyEqual(testCase,normalized.Preprocessing.SeriesSD(subi), ...
        std(series,0),'AbsTol',1e-12);
end

end


function testPreprocessingUsesPhysicalTenHertzCutoff(testCase)

srate = 250;
time = (0:2499)'/srate;
signal = sin(2*pi*2*time)+sin(2*pi*40*time);
[processed,info] = FREQNESS_PreprocessTimeCoord_Mocap(signal,srate, ...
    'target_srate',25,'lowpass_cutoff',10,'duration',[.15 .85], ...
    'standardize',true);

verifyEqual(testCase,info.NormalizedLowpassCutoff,10/(srate/2), ...
    'AbsTol',eps);
verifyEqual(testCase,info.DecimationFactor,10);
verifyEqual(testCase,info.LowpassCutoffHz,10);
verifyEqual(testCase,size(processed,1), ...
    round(.85*250)-round(.15*250)+1);
verifyEqual(testCase,mean(processed),0,'AbsTol',1e-12);
verifyEqual(testCase,std(processed),1,'AbsTol',1e-12);

end


function testParameterRulesMatchDiagnosticCurves(testCase)

FREQ = syntheticFREQ(900);
parameters = FREQNESS_JRQAParameters_Mocap(FREQ,[1 1],100, ...
    'target_srate',25,'lowpass_cutoff',10,'maximum_lag',20, ...
    'maximum_dimension',5);

for subi = 1:2
    mi = parameters.MutualInformation{subi};
    localMinimum = find(mi(2:end-1) <= mi(1:end-2) & ...
        mi(2:end-1) < mi(3:end),1,'first')+1;
    if isempty(localMinimum)
        [~,minimumRelative] = min(mi(2:end));
        localMinimum = minimumRelative+1;
    end
    verifyEqual(testCase,parameters.tau(subi),localMinimum-1);

    fnn = parameters.FalseNearestFraction{subi};
    expectedDimension = find(fnn <= parameters.FNNThreshold,1,'first');
    if isempty(expectedDimension)
        [~,expectedDimension] = min(fnn);
    end
    verifyEqual(testCase,parameters.m(subi),expectedDimension);
end

end


function testCircularShiftSurrogatesPreserveMarginalGeometry(testCase)

FREQ = syntheticFREQ(350);
JRQA = struct('m',2,'tau',4);
[observed,surrogates] = FREQNESS_JRQASurrogates_Mocap( ...
    FREQ,JRQA,[1 1],'threshold_method','fixed_rr','threshold',.08, ...
    'theiler_window',4,'n_surrogates',20,'random_seed',27);

verifySize(testCase,surrogates.RR,[20 1]);
verifySize(testCase,surrogates.DET,[20 1]);
verifyEqual(testCase,surrogates.ObservedRR,observed.RR);
verifyEqual(testCase,surrogates.ObservedDET,observed.DET);
verifyGreaterThan(testCase,min(surrogates.Shifts),0);
verifyGreaterThanOrEqual(testCase,surrogates.PValueRR,1/21);
verifyLessThanOrEqual(testCase,surrogates.PValueRR,1);
verifyGreaterThanOrEqual(testCase,surrogates.PValueDET,1/21);
verifyLessThanOrEqual(testCase,surrogates.PValueDET,1);

end


function testGappyFREQIsRejectedBeforeJRQA(testCase)

FREQ = struct();
FREQ.ts = randn(1,100,1,2);
FREQ.frex = 1;
FREQ.bad_segments = 20:25;
JRQA = struct('m',2,'tau',1);

verifyError(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,[1 1],'method','jrqa','jrqa',JRQA), ...
    'FREQNESS:TimeCoord:GapsUnsupported');

end


function FREQ = syntheticFREQ(ntime)

rng(42);
time = (0:ntime-1)/100;
shared = sin(2*pi*1.2*time)+0.25*sin(2*pi*0.3*time);
FREQ = struct();
FREQ.ts = zeros(1,ntime,1,2);
FREQ.ts(1,:,1,1) = shared+0.15*randn(1,ntime);
FREQ.ts(1,:,1,2) = circshift(shared,7)+0.15*randn(1,ntime);
FREQ.frex = 1;
FREQ.bad_segments = [];

end


function testNonfiniteTimeSeriesAreRejected(testCase)

FREQ = struct();
FREQ.ts = randn(1,100,1,2);
FREQ.ts(1,20,1,1) = NaN;
FREQ.frex = 1;
JRQA = struct('m',2,'tau',1);

verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,[1 1],'method','jrqa','jrqa',JRQA), ...
    'FREQ.ts must be a real finite numeric array.');

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
