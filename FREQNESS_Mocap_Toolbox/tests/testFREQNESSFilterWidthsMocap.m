function tests = testFREQNESSFilterWidthsMocap
%TESTFREQNESSFILTERWIDTHSMOCAP Regression tests for physical filter widths.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
toolboxRoot = fileparts(testRoot);
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
addpath(fullfile(toolboxRoot,'FREQNESS_ExternalFunctions'));
testCase.TestData.toolboxRoot = toolboxRoot;

end


function testLogarithmicReferenceCalibration(testCase)

frex = [0.5 2 10]';
expected = [0.071428571428571; ...
    0.393763558044584; ...
    2.857142857142857];

actual = FREQNESS_ComputeFilterWidths_Mocap(frex,'logarithmic');

verifyEqual(testCase,actual,expected,'AbsTol',1e-12);

end


function testAutomaticWidthsAreFrequencyDensityInvariant(testCase)

frex_sparse = (0.1:0.1:10)';
frex_dense = (0.1:0.05:10)';

log_sparse = FREQNESS_ComputeFilterWidths_Mocap( ...
    frex_sparse,'logarithmic');
log_dense = FREQNESS_ComputeFilterWidths_Mocap( ...
    frex_dense,'logarithmic');
linear_sparse = FREQNESS_ComputeFilterWidths_Mocap(frex_sparse,'linear');
linear_dense = FREQNESS_ComputeFilterWidths_Mocap(frex_dense,'linear');

verifyEqual(testCase,log_sparse,log_dense(1:2:end),'AbsTol',0);
verifyEqual(testCase,linear_sparse,linear_dense(1:2:end),'AbsTol',0);

end


function testParticipantColumnsUseTheirOwnFrequencyRanges(testCase)

frex = [0.4175 0.2313125; ...
    1.67 1.8505; ...
    6.68 7.402];
expected_q = [7 7; ...
    sqrt(7*3.5) 7*(3.5/7)^0.6; ...
    3.5 3.5];

actual = FREQNESS_ComputeFilterWidths_Mocap(frex,'logarithmic');

verifyEqual(testCase,frex./actual,expected_q,'AbsTol',1e-12);

end


function testLinearModeUsesConstantQ(testCase)

frex = [0.5 0.75; 2 3; 10 12];
actual = FREQNESS_ComputeFilterWidths_Mocap(frex,'linear');

verifyEqual(testCase,actual,frex/5,'AbsTol',0);

end


function testSingleFrequencyUsesLogarithmicMidpointQ(testCase)

frex = [1.67 2.15];
actual = FREQNESS_ComputeFilterWidths_Mocap(frex,'logarithmic');

verifyEqual(testCase,actual,frex/sqrt(7*3.5),'AbsTol',1e-12);

end


function testNetworkEstimationUsesPhysicalWidths(testCase)

data = deterministic_data();
frex_sparse = [2 4 6];
frex_dense = [2 3 4 5 6];

FREQ_sparse = FREQNESS_NetworkEstimation_Mocap( ...
    data,frex_sparse,64,'ncomps',3);
FREQ_dense = FREQNESS_NetworkEstimation_Mocap( ...
    data,frex_dense,64,'ncomps',3);
idx_shared = 1:2:numel(frex_dense);

verifyEqual(testCase,FREQ_sparse.fwhm, ...
    FREQ_dense.fwhm(idx_shared,:),'AbsTol',0);
verifyEqual(testCase,FREQ_sparse.evals, ...
    FREQ_dense.evals(:,idx_shared,:),'AbsTol',1e-12);

end


function testExplicitWidthsBypassAutomaticMode(testCase)

data = deterministic_data();
frex = [2 2.5; 4 5; 6 7.5];
shared_widths = [0.4 0.8 1.2];
participant_widths = [0.4 0.5; 0.8 1; 1.2 1.5];

FREQ_scalar = FREQNESS_NetworkEstimation_Mocap( ...
    data,frex,64,'fwidth',0.8,'filter','logarithmic','ncomps',1);
FREQ_shared = FREQNESS_NetworkEstimation_Mocap( ...
    data,frex,64,'fwidth',shared_widths,'filter','linear','ncomps',1);
FREQ_participant = FREQNESS_NetworkEstimation_Mocap( ...
    data,frex,64,'fwidth',participant_widths, ...
    'filter','logarithmic','ncomps',1);

verifyEqual(testCase,FREQ_scalar.fwhm,0.8*ones(3,2),'AbsTol',0);
verifyEqual(testCase,FREQ_shared.fwhm, ...
    repmat(shared_widths(:),1,2),'AbsTol',0);
verifyEqual(testCase,FREQ_participant.fwhm,participant_widths,'AbsTol',0);

end


function testLegacyLogarithmicScheduleMatchesFormerDefault(testCase)

frex = (0.1:0.1:10)';
expected = logspace(log10(0.01),log10(1),100)';

actual = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
    frex,'logarithmic');

verifyEqual(testCase,actual,expected,'AbsTol',0);

end


function testLegacyLinearScheduleMatchesFormerOption(testCase)

frex = (0.1:0.1:10)';
expected = (0.01:0.01:1)';

actual = FREQNESS_ComputeLegacyFilterWidths_Mocap(frex,'linear');

verifyEqual(testCase,actual,expected,'AbsTol',1e-15);

end


function testLegacyParticipantColumnsRemainIndependent(testCase)

frex = [0.4 0.3; 0.5 0.4; 0.6 0.5];
first_widths = 0.01 .* 100.^([3 2]./99);
expected = zeros(size(frex));
for subi = 1:size(frex,2)
    expected(:,subi) = logspace(log10(first_widths(subi)), ...
        log10(first_widths(subi)*size(frex,1)),size(frex,1))';
end

actual = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
    frex,'logarithmic');

verifyEqual(testCase,actual,expected,'AbsTol',1e-15);

end


function testLegacyWidthsRemainExplicitEstimatorInputs(testCase)

data = deterministic_data();
frex = [2 2.5; 4 5; 6 7.5];
legacy_widths = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
    frex,'logarithmic');

FREQ = FREQNESS_NetworkEstimation_Mocap( ...
    data,frex,64,'fwidth',legacy_widths,'ncomps',1);

verifyEqual(testCase,FREQ.fwhm,legacy_widths,'AbsTol',0);

end


function data = deterministic_data

srate = 64;
time = (0:511)/srate;
participant_one = [ ...
    sin(2*pi*2*time) + 0.20*cos(2*pi*11*time); ...
    cos(2*pi*3*time) + 0.10*sin(2*pi*13*time); ...
    0.70*sin(2*pi*4*time + 0.3) + 0.30*cos(2*pi*7*time); ...
    0.40*cos(2*pi*6*time - 0.2) + 0.25*sin(2*pi*9*time); ...
    0.55*sin(2*pi*5*time + 0.1) + 0.15*cos(2*pi*14*time); ...
    0.45*cos(2*pi*8*time - 0.4) + 0.20*sin(2*pi*10*time)];
participant_two = participant_one + [ ...
    0.05*cos(2*pi*5*time); ...
    0.05*sin(2*pi*8*time); ...
    0.04*cos(2*pi*10*time); ...
    0.04*sin(2*pi*12*time); ...
    0.03*cos(2*pi*3*time); ...
    0.03*sin(2*pi*7*time)];
data = cat(3,participant_one,participant_two);

end
