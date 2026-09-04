function tests = testEmpaticMirroringPipeline
%TESTEMPATICMIRRORINGPIPELINE Study-pipeline regression tests.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testRoot = fileparts(mfilename('fullpath'));
studyRoot = fileparts(testRoot);
repositoryRoot = fileparts(studyRoot);
toolboxRoot = fullfile(repositoryRoot,'FREQNESS_Mocap_Toolbox');
addpath(fullfile(studyRoot,'functions'));
addpath(fullfile(toolboxRoot,'FREQNESS_Functions'));
addpath(fullfile(toolboxRoot,'FREQNESS_ExternalFunctions'));
testCase.TestData.studyRoot = studyRoot;
testCase.TestData.toolboxRoot = toolboxRoot;

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


function testRemainingGapBecomesBadSegment(testCase)

config = EmpaticMirroring_Config();
nTeacher = 40*config.sampling.teacherHz;
nParticipant = 40*config.sampling.participantHz;
teacher = syntheticRecording(zeros(1,nTeacher), ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(zeros(1,nParticipant), ...
    config.sampling.participantHz,"participant.mat");
participant.coordinates(1:3,100) = NaN;

dyad = EmpaticMirroring_AlignArtificialDyad(teacher,participant,config);

verifyTrue(testCase,all(isfinite(dyad.data),'all'));
verifyEqual(testCase,dyad.badSegmentsByParticipant{1},zeros(1,0));
verifyEqual(testCase,dyad.badSegmentsByParticipant{2},100);
verifyEqual(testCase,dyad.badSegments,100);
verifyTrue(testCase,all(dyad.data(:,100,2) == 0,'all'));

end


function testTeacherGapMaskSurvivesResampling(testCase)

config = EmpaticMirroring_Config();
nTeacher = 40*config.sampling.teacherHz;
nParticipant = 40*config.sampling.participantHz;
teacher = syntheticRecording(ones(1,nTeacher), ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(ones(1,nParticipant), ...
    config.sampling.participantHz,"participant.mat");
teacher.coordinates(1:3,300:315) = NaN;

dyad = EmpaticMirroring_AlignArtificialDyad(teacher,participant,config);

verifyNotEmpty(testCase,dyad.badSegmentsByParticipant{1});
verifyEmpty(testCase,dyad.badSegmentsByParticipant{2});
verifyEqual(testCase,dyad.badSegments, ...
    dyad.badSegmentsByParticipant{1});
verifyTrue(testCase,all(dyad.data(:,dyad.badSegments,1) == 0,'all'));

end


function testPreparedTeacherCanBeReusedWithoutRawTeacher(testCase)

config = EmpaticMirroring_Config();
nTeacher = 40*config.sampling.teacherHz;
nParticipant = 40*config.sampling.participantHz;
teacher = syntheticRecording(ones(1,nTeacher), ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(ones(1,nParticipant), ...
    config.sampling.participantHz,"participant.mat");
teacher.coordinates(1:3,300:315) = NaN;

[emptyDyad,preparedTeacher] = EmpaticMirroring_AlignArtificialDyad( ...
    teacher,[],config);
reusedDyad = EmpaticMirroring_AlignArtificialDyad( ...
    [],participant,config,preparedTeacher);

verifyEmpty(testCase,emptyDyad);
verifySize(testCase,reusedDyad.data,[6 3960 2]);
verifyEqual(testCase,reusedDyad.data(:,:,1),preparedTeacher.data);
verifyEqual(testCase,reusedDyad.badSampleMask(:,1), ...
    preparedTeacher.badMask(:));

end


function testParticipantResultsAreRoutedBesideMatFolder(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));
config = EmpaticMirroring_Config();
config.paths.dataRoot = temporaryRoot;
config.paths.participantsOutputRoot = fullfile(temporaryRoot,'outputs', ...
    'participants');
participantFile = fullfile(temporaryRoot,'001','1_mat', ...
    '1_mir_low_v1_mov1.mat');

resultsFolder = EmpaticMirroring_ParticipantResultsFolder( ...
    participantFile,config);

verifyEqual(testCase,string(resultsFolder), ...
    fullfile(temporaryRoot,'outputs','participants','001'));

end


function testManifestExcludesAnnotationsAndMatchesStimulus(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = EmpaticMirroring_Config();
config.paths.qcOutputRoot = temporaryRoot;

file = ["participant.mat";"participant_noted.mat";"model.mat"];
role = ["participant";"participant";"teacher"];
folderStatus = ["ok";"ok";"ok"];
nameStatus = ["ok";"annotated filename";"ok"];
subject = ["001";"001";"Michalina"];
trialIndex = [17;18;7];
instruction = ["obs";"mir";"mir"];
complexity = ["high";"high";"high"];
version = [2;2;2];
movement = [1;1;1];
pairingKey = ["high_v2_mov1";"high_v2_mov1";"high_v2_mov1"];
numberFrames = [4320;4320;9900];
overallStatus = ["ok";"annotated filename";"ok"];
readyForAlignment = [true;false;true];
frameQC = table(file,role,folderStatus,nameStatus,subject,trialIndex, ...
    instruction,complexity,version,movement,pairingKey,numberFrames, ...
    overallStatus,readyForAlignment, ...
    'VariableNames',{'File','Role','FolderStatus','NameStatus','Subject', ...
    'TrialIndex','Instruction','Complexity','Version','Movement', ...
    'PairingKey','NumberFrames','OverallStatus','ReadyForAlignment'});

manifest = EmpaticMirroring_BuildDyadManifest(frameQC,config);

verifyEqual(testCase,height(manifest),1);
verifyEqual(testCase,manifest.ParticipantFile,"participant.mat");
verifyEqual(testCase,manifest.TeacherFile,"model.mat");
verifyEqual(testCase,manifest.PairingStatus,"matched");
verifyTrue(testCase,manifest.ReadyForAlignment);

end


function testProvisionalCoreFrequencyGrid(testCase)

config = EmpaticMirroring_Config();
expectedBeatFrequency = 1.5*ones(1,2);
expectedFrexVector = (1.5/8:1.5/8:1.5*4)';

verifyEqual(testCase,config.block1.beat_frex,expectedBeatFrequency);
verifyEqual(testCase,config.block1.frex, ...
    repmat(expectedFrexVector,1,2));
verifyEqual(testCase,config.block1.ncomps,4);
verifyFalse(testCase,config.block1.run);

end


function testCoreAnalysisIsResumableAndUsesBadSegments(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = EmpaticMirroring_Config();
config.paths.qcOutputRoot = fullfile(temporaryRoot,'qc');
config.block1.beat_frex = 1.5*ones(1,2);
config.block1.frex = repmat([1;2],1,2);
config.block1.duration = 2;
config.block1.fwidth = repmat([0.3;0.4],1,2);
config.block1.regularisation = 0.01;
config.block1.ncomps = 2;
config.block1.overwrite_flag = false;
config.block1.save_flag = true;
config.block1.max_dyads = inf;

participantOutputRoot = fullfile(temporaryRoot,'participants','001');
mkdir(participantOutputRoot);
dyadFile = fullfile(participantOutputRoot, ...
    'S001_T01_mir_low_v1_mov1.mat');
rng(109);
markData = randn(6,240,2);
srate = 120;
bad_segments = [20 30];
markData(:,bad_segments,:) = 0;
marker_reference = markData(:,1,:);
dyad_info = struct('subject',"001",'trialIndex',1);
save(dyadFile,'markData','srate','bad_segments', ...
    'marker_reference','dyad_info');

DyadFile = string(dyadFile);
DyadStatus = "created";
dyadManifest = table(DyadFile,DyadStatus);
networkEstimatorContract = ...
    EmpaticMirroring_CheckNetworkEstimatorContract(config);

[firstManifest,firstSummary] = EmpaticMirroring_RunCoreAnalysis( ...
    dyadManifest,config,networkEstimatorContract);

verifyEqual(testCase,firstManifest.CoreStatus,"created");
verifyEqual(testCase,firstSummary.createdCount,1);
verifyEqual(testCase,firstSummary.errorCount,0);
verifyTrue(testCase,isfile(firstManifest.CoreFile));
verifyEqual(testCase,fileparts(firstManifest.CoreFile), ...
    string(participantOutputRoot));

savedCore = load(firstManifest.CoreFile,'FREQ','beat_frex','srate');
verifyEqual(testCase,savedCore.beat_frex,config.block1.beat_frex);
verifyEqual(testCase,savedCore.srate,srate);
verifyEqual(testCase,savedCore.FREQ.frex,config.block1.frex);
verifyEqual(testCase,savedCore.FREQ.frex_norm, ...
    config.block1.frex./config.block1.beat_frex);
verifyEqual(testCase,savedCore.FREQ.bad_segments,bad_segments);
verifySize(testCase,savedCore.FREQ.evals,[6 2 2]);
verifySize(testCase,savedCore.FREQ.evecs,[6 2 2 2]);

[secondManifest,secondSummary] = EmpaticMirroring_RunCoreAnalysis( ...
    dyadManifest,config,networkEstimatorContract);
verifyEqual(testCase,secondManifest.CoreStatus,"existing");
verifyEqual(testCase,secondSummary.existingCount,1);
verifyEqual(testCase,secondSummary.createdCount,0);

end


function recording = syntheticRecording(signal,sampleRate,fileName)

recording = struct();
recording.file = fileName;
recording.sampleRate = sampleRate;
recording.labels = ["A";"B"];
recording.coordinates = repmat(signal,6,1);

end
