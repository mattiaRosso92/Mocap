function tests = testFREQNESSTimeCoordMethodsMocap
%TESTFREQNESSTIMECOORDMETHODSMOCAP Unified temporal interface and defaults.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

test_root = fileparts(mfilename('fullpath'));
toolbox_root = fileparts(test_root);
addpath(genpath(fullfile(toolbox_root,'FREQNESS_Functions')));
addpath(fullfile(toolbox_root,'FREQNESS_ExternalFunctions'));
testCase.TestData.FREQ = synthetic_freq(120,2);
testCase.TestData.JRQA = struct('m',2,'tau',3,'ps',.8);

end


function testDefaultIsNonStandardizedPhaseSpace(testCase)

FREQ = testCase.TestData.FREQ;
[output,figures] = FREQNESS_TimeCoord_Mocap(FREQ,1);
explicit = FREQNESS_TimeCoord_Mocap(FREQ,1, ...
    'method','phase_space','standardize',false);
verifyEqual(testCase,output,explicit);
verifyEqual(testCase,output.Method,'phase_space');
verifyFalse(testCase,output.Standardized);
verifyEqual(testCase,output.PhaseSpace, ...
    [reshape(FREQ.ts(1,:,1,1),[],1) reshape(FREQ.ts(1,:,1,2),[],1)]);
verifyEqual(testCase,output.SelectedComponents,[1 1]);
verifyEmpty(testCase,figures.phase_space);
verifyEmpty(testCase,figures.animation);

end


function testOptionalNormalizationUsesOnlyValidSamples(testCase)

FREQ = testCase.TestData.FREQ;
FREQ.bad_segments = 20:30;
output = FREQNESS_TimeCoord_Mocap(FREQ,1,'standardize',true);
valid = output.ValidSampleMask;
verifyTrue(testCase,output.Standardized);
verifyEqual(testCase,mean(output.PhaseSpace(valid,:),1),[0 0],'AbsTol',1e-12);
verifyEqual(testCase,std(output.PhaseSpace(valid,:),0,1),[1 1],'AbsTol',1e-12);
verifyTrue(testCase,all(isnan(output.PhaseSpace(~valid,:)),'all'));

end


function testGroupSpecificFrequenciesAndComponents(testCase)

FREQ = synthetic_freq(120,3);
components = [1 2 1];
frequencies = [1 2 1];
output = FREQNESS_TimeCoord_Mocap(FREQ,frequencies, ...
    'component',components,'metric_levels',[1 2]);
verifySize(testCase,output,[1 2]);
verifyEqual(testCase,output(1).SelectedFrequencies,frequencies);
verifyEqual(testCase,output(1).SelectedComponents,components);
for subi = 1:3
    verifyEqual(testCase,output(1).PhaseSpace(:,subi), ...
        reshape(FREQ.ts(components(subi),:,frequencies(subi),subi),[],1));
end

end


function testJRQADefaultIsValidatedAndNonStandardized(testCase)

FREQ = testCase.TestData.FREQ;
JRQA = testCase.TestData.JRQA;
[output,figures] = FREQNESS_TimeCoord_Mocap(FREQ,[1 1], ...
    'method','jrqa','parameters',JRQA,'store_matrices',true);
explicit = FREQNESS_TimeCoord_Mocap(FREQ,[1 1], ...
    'method','jrqa','parameters',JRQA,'store_matrices',true, ...
    'standardize',false);
verifyEqual(testCase,output,explicit);
verifyEqual(testCase,output.Method,'jrqa');
verifyEqual(testCase,output.Implementation,'validated');
verifyFalse(testCase,output.Preprocessing.Standardized);
verifyEqual(testCase,output.PhaseSpace{1}(:,1), ...
    reshape(FREQ.ts(1,1:117,1,1),[],1));
verifyEmpty(testCase,figures.phase_space);
verifyEmpty(testCase,figures.recurrence_plot);

end


function testMissingJRQAParametersDoNotTriggerTuning(testCase)

verifyError(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    testCase.TestData.FREQ,[1 1],'method','jrqa'), ...
    'FREQNESS:TimeCoord:MissingJRQA');
verifyError(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    testCase.TestData.FREQ,[1 1],'method','jrqa', ...
    'parameters',struct('m',2)), ...
    'FREQNESS:TimeCoord:MissingJRQA');

end


function testIncompatibleOptionsAreRejected(testCase)

FREQ = testCase.TestData.FREQ;
JRQA = testCase.TestData.JRQA;
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,1,'parameters',JRQA), ...
    'The parameters option is only valid for method ''jrqa''.');
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,1,'implementation','validated'),'Unrecognized argument: implementation');
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,[1 1],'method','jrqa','parameters',JRQA,'animate',true), ...
    'Unrecognized argument: animate');
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,[1 1],'method','jrqa','parameters',JRQA,'downsample',2), ...
    'Unrecognized argument: downsample');

end


function testMethodAndBooleanValidation(testCase)

FREQ = testCase.TestData.FREQ;
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap(FREQ,1,'method',1), ...
    'method must be ''phase_space'' or ''jrqa''.');
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,1,'standardize',1),'standardize must be one logical value.');
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,1,'method'),'Arguments must be given as name-value pairs.');

end


function testPhaseSpaceMethodSelectionPreservesOptions(testCase)

FREQ = testCase.TestData.FREQ;
for standardize = [false true]
    default_call = FREQNESS_TimeCoord_Mocap( ...
        FREQ,1,'standardize',standardize,'store_matrices',true);
    explicit_call = FREQNESS_TimeCoord_Mocap( ...
        FREQ,1,'method','phase_space','standardize',standardize,'store_matrices',true);
    verifyEqual(testCase,default_call,explicit_call);
    verifyEqual(testCase,explicit_call.Standardized,standardize);
end

end


function testTemporaryPhaseSpaceEntryPointIsRemoved(testCase)

analysis_root = fileparts(which('FREQNESS_TimeCoord_Mocap'));
verifyFalse(testCase,isfile(fullfile(analysis_root,'FREQNESS_PhaseSpaceRQA_Mocap.m')));
verifyEmpty(testCase,which('FREQNESS_PhaseSpaceRQA_Mocap'));

end


function testPositionalJRQAParametersAreRejected(testCase)

FREQ = testCase.TestData.FREQ;
JRQA = testCase.TestData.JRQA;
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,JRQA,[1 1]),'Arguments must be given as name-value pairs.');
verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap( ...
    FREQ,JRQA,[1 1],'implementation','validated'), ...
    'Arguments must be given as name-value pairs.');

end


function testImplementationSelectorIsRemovedIncludingSurrogates(testCase)

FREQ = testCase.TestData.FREQ;
JRQA = testCase.TestData.JRQA;
for implementation = {'legacy','validated'}
    verifyFailureMessage(testCase,@() FREQNESS_TimeCoord_Mocap(FREQ,[1 1], ...
        'method','jrqa','parameters',JRQA,'implementation',implementation{1}), ...
        'Unrecognized argument: implementation');
    verifyFailureMessage(testCase,@() FREQNESS_JRQASurrogates_Mocap(FREQ,JRQA,[1 1], ...
        'implementation',implementation{1},'n_surrogates',3), ...
        'Unrecognized argument: implementation');
end

end


function testPreprocessingDefaultRetainsSignalUnits(testCase)

signal = (1:50)';
[processed,info] = FREQNESS_PreprocessTimeCoord_Mocap(signal,100);
verifyEqual(testCase,processed,signal);
verifyFalse(testCase,info.Standardized);

end


function testTuningAndSurrogatesDefaultToRawSignals(testCase)

FREQ = synthetic_freq(350,2);
parameters = FREQNESS_JRQAParameters_Mocap(FREQ,[1 1],100, ...
    'maximum_lag',10,'maximum_dimension',3);
for subi = 1:2
    verifyFalse(testCase,parameters.Preprocessing{subi}.Standardized);
end
[output,~] = FREQNESS_JRQASurrogates_Mocap( ...
    FREQ,testCase.TestData.JRQA,[1 1],'n_surrogates',3);
verifyEqual(testCase,output.Method,'jrqa');
verifyFalse(testCase,output.Preprocessing.Standardized);
verifyFailureMessage(testCase,@() FREQNESS_JRQASurrogates_Mocap( ...
    FREQ,testCase.TestData.JRQA,[1 1],'parameters',testCase.TestData.JRQA), ...
    'JRQA surrogates use the positional JRQA parameters and method jrqa.');

end


function testPhaseSpaceFiguresAndAnimationsRemainAvailable(testCase)

old_visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanup = onCleanup(@() set(groot,'DefaultFigureVisible',old_visibility));
for nsubs = 2:3
    FREQ = synthetic_freq(12,nsubs);
    [~,figures] = FREQNESS_TimeCoord_Mocap(FREQ,1, ...
        'figure',true,'animate',true,'animation_pause',0);
    handles = [figures.phase_space figures.distance_matrix ...
        figures.recurrence_plot figures.animation];
    cleanup_figures = onCleanup(@() close(handles(isgraphics(handles))));
    verifyNumElements(testCase,handles,4);
    verifyTrue(testCase,all(isgraphics(handles)));
    clear cleanup_figures
end

end


function FREQ = synthetic_freq(ntime,nsubs)

time = (0:ntime-1)/100;
FREQ = struct('ts',zeros(2,ntime,2,nsubs),'frex',[1;2],'bad_segments',[]);
for subi = 1:nsubs
    for compi = 1:2
        for frexi = 1:2
            FREQ.ts(compi,:,frexi,subi) = subi+compi+frexi + ...
                (subi+compi)*sin(2*pi*frexi*time+.2*subi) + ...
                .3*cos(2*pi*.3*time);
        end
    end
end

end


function verifyFailureMessage(testCase,function_handle,expected_message)

try
    function_handle();
    verifyFail(testCase,'Expected the function to throw an error.');
catch exception
    verifyEqual(testCase,exception.message,expected_message);
end

end
