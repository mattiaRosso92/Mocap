function tests = testEmpaticMirroringPipeline
%TESTEMPATICMIRRORINGPIPELINE Study-pipeline regression tests.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
studyRoot = fileparts(testRoot);
addpath(fullfile(studyRoot,'functions'));
testCase.TestData.studyRoot = studyRoot;

end


function testTriggerRelativeAlignment(testCase)

config = EmpaticMirroring_Config();
frequencyHz = 1.5;

teacherTime = (0:40*config.sampling.teacherHz-1) / ...
    config.sampling.teacherHz;
participantTime = (0:40*config.sampling.participantHz-1) / ...
    config.sampling.participantHz;

teacherSignal = sin(2*pi*frequencyHz*teacherTime);
participantSignal = sin(2*pi*frequencyHz* ...
    (participantTime-config.timing.participantOffsetSeconds));

teacher = syntheticRecording(teacherSignal, ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(participantSignal, ...
    config.sampling.participantHz,"participant.mat");

dyad = EmpaticMirroring_AlignArtificialDyad( ...
    teacher,participant,config);

nExpected = config.timing.analysisDurationSeconds * ...
    config.sampling.outputHz;
verifySize(testCase,dyad.data,[6 nExpected 2]);
verifyEqual(testCase,dyad.time(1),0);
verifyEqual(testCase,dyad.time(end),(nExpected-1)/ ...
    config.sampling.outputHz,'AbsTol',eps);

% Ignore only the small resampling boundary region in this signal test.
interior = round(0.25*config.sampling.outputHz) + ...
    (1:nExpected-round(0.5*config.sampling.outputHz));
difference = dyad.data(:,interior,1)-dyad.data(:,interior,2);
verifyLessThan(testCase,max(abs(difference),[],'all'),1e-3);

end


function testQtmLoader(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

nMarkers = 2;
nFrames = 100;
qtm_test = struct();
qtm_test.Frames = nFrames;
qtm_test.FrameRate = 120;
qtm_test.Trajectories.Labeled.Data = randn(nMarkers,4,nFrames);
qtm_test.Trajectories.Labeled.Labels = {'A','B'};
filePath = fullfile(temporaryRoot,'1_obs_low_v1_mov1.mat');
save(filePath,'qtm_test');

recording = EmpaticMirroring_LoadRecording(filePath);

verifyEqual(testCase,recording.frameCount,nFrames);
verifyEqual(testCase,recording.sampleRate,120);
verifyEqual(testCase,recording.labels,["A";"B"]);
verifySize(testCase,recording.coordinates,[6 nFrames]);

end


function testShortGapInterpolation(testCase)

sampleRate = 120;
coordinates = repmat(1:20,6,1);
coordinates(1:3,8:9) = NaN;

[cleaned,report] = EmpaticMirroring_InterpolateShortGaps( ...
    coordinates,sampleRate,0.025);

verifyTrue(testCase,all(isfinite(cleaned),'all'));
verifyEqual(testCase,cleaned(1:3,8:9), ...
    repmat(8:9,3,1),'AbsTol',eps);
verifyEqual(testCase,report.interpolatedGapCount,1);
verifyEqual(testCase,report.remainingInvalidSampleCount,0);

end


function recording = syntheticRecording(signal,sampleRate,fileName)

recording = struct();
recording.file = fileName;
recording.sampleRate = sampleRate;
recording.labels = ["A";"B"];
recording.coordinates = repmat(signal,6,1);

end
