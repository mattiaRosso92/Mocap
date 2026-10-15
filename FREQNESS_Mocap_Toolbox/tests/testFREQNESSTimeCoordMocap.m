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

% Call with the documented positional argument order.
output = FREQNESS_TimeCoord_Mocap(FREQ,JRQA,[1 1], ...
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
output = FREQNESS_TimeCoord_Mocap(FREQ,JRQA,[1 1], ...
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


function testPreprocessingUsesPhysicalTenHertzCutoff(testCase)

srate = 250;
time = (0:2499)'/srate;
signal = sin(2*pi*2*time)+sin(2*pi*40*time);
[processed,info] = FREQNESS_PreprocessTimeCoord_Mocap(signal,srate, ...
    'target_srate',25,'lowpass_cutoff',10,'duration',[.15 .85]);

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
    FREQ,JRQA,[1 1]),'FREQNESS:TimeCoord:GapsUnsupported');

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
    FREQ,JRQA,[1 1]),'FREQ.ts must be a real finite numeric array.');

end


function verifyFailureMessage(testCase,functionHandle,expectedMessage)

try
    functionHandle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expectedMessage);
end

end
