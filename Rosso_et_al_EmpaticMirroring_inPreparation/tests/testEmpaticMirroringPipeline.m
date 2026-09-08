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

config = syntheticAlignmentConfig();
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

config = syntheticAlignmentConfig();
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
verifyTrue(testCase,all(isfinite(dyad.data(:,100,2)),'all'));
verifyEqual(testCase,dyad.badMarkerSampleMask(:,100,2),[true;false]);

end


function testBoundaryGapsUseNearestContinuityValues(testCase)

config = syntheticAlignmentConfig();
coordinates = ones(6,20);
coordinates(1:3,1:3) = NaN;
coordinates(4:6,18:20) = NaN;

[filled,~,policy] = EmpaticMirroring_ApplyMarkerPolicy( ...
    coordinates,["A";"B"],120,config);

verifyTrue(testCase,all(isfinite(filled),'all'));
verifyEqual(testCase,filled(1:3,1:3),ones(3,3));
verifyEqual(testCase,filled(4:6,18:20),ones(3,3));
verifyEqual(testCase,find(policy.originalBadSampleMask),[1:3 18:20]);
verifyEqual(testCase,policy.gapInfo.boundary_method,"nearest");
verifyTrue(testCase,policy.isEligible);

end


function testGapsOutsideAnalysisWindowDoNotAffectAlignment(testCase)

config = syntheticAlignmentConfig();
nTeacher = 40*config.sampling.teacherHz;
nParticipant = 40*config.sampling.participantHz;
teacher = syntheticRecording(ones(1,nTeacher), ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(ones(1,nParticipant), ...
    config.sampling.participantHz,"participant.mat");
teacher.coordinates(1:3,end-100:end) = NaN;
participant.coordinates(1:3,end-100:end) = NaN;

dyad = EmpaticMirroring_AlignArtificialDyad(teacher,participant,config);

verifyTrue(testCase,all(isfinite(dyad.data),'all'));
verifyEmpty(testCase,dyad.badSegments);
verifyEmpty(testCase,dyad.badSegmentsByParticipant{1});
verifyEmpty(testCase,dyad.badSegmentsByParticipant{2});

end


function testPostWindowContextSupportsEndpointReconstruction(testCase)

config = syntheticAlignmentConfig();
nTeacher = 40*config.sampling.teacherHz;
nParticipant = 40*config.sampling.participantHz;
teacher = syntheticRecording(ones(1,nTeacher), ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(ones(1,nParticipant), ...
    config.sampling.participantHz,"participant.mat");
analysisEnd = config.timing.analysisDurationSeconds* ...
    config.sampling.participantHz;
participant.coordinates(1:3,analysisEnd-5:analysisEnd+10) = NaN;

dyad = EmpaticMirroring_AlignArtificialDyad(teacher,participant,config);

verifyTrue(testCase,all(isfinite(dyad.data),'all'));
verifyEqual(testCase,dyad.badSegmentsByParticipant{2}, ...
    analysisEnd-5:analysisEnd);

end


function testLongGapIsReconstructedButRemainsExcluded(testCase)

config = syntheticAlignmentConfig();
nSamples = 600;
time = linspace(0,4*pi,nSamples);
coordinates = [sin(time);cos(time);.5*sin(time); ...
    2+sin(time);3+cos(time);4+.5*sin(time)];
observed = coordinates;
gap = 200:260;
coordinates(1:3,gap) = NaN;

[reconstructed,~,policy] = EmpaticMirroring_ApplyMarkerPolicy( ...
    coordinates,["A";"B"],120,config);

verifyTrue(testCase,all(isfinite(reconstructed),'all'));
verifyEqual(testCase,reconstructed(:,setdiff(1:nSamples,gap)), ...
    observed(:,setdiff(1:nSamples,gap)),'AbsTol',0);
verifyTrue(testCase,all(policy.reconstructedMask(1,gap)));
verifyTrue(testCase,all(policy.originalBadSampleMask(gap)));
verifyEqual(testCase,policy.filledMask,policy.originalMissingMask);
verifyFalse(testCase,any(policy.unresolvedMask,'all'));

end


function testTeacherGapMaskSurvivesResampling(testCase)

config = syntheticAlignmentConfig();
nTeacher = 40*config.sampling.teacherHz;
nParticipant = 40*config.sampling.participantHz;
teacher = syntheticRecording(ones(1,nTeacher), ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(ones(1,nParticipant), ...
    config.sampling.participantHz,"participant.mat");
teacher.coordinates(1:3,300:314) = NaN;

dyad = EmpaticMirroring_AlignArtificialDyad(teacher,participant,config);

verifyNotEmpty(testCase,dyad.badSegmentsByParticipant{1});
verifyEmpty(testCase,dyad.badSegmentsByParticipant{2});
verifyEqual(testCase,dyad.badSegments, ...
    dyad.badSegmentsByParticipant{1});
verifyTrue(testCase,all(isfinite( ...
    dyad.data(:,dyad.badSegments,1)),'all'));

end


function testPreparedTeacherCanBeReusedWithoutRawTeacher(testCase)

config = syntheticAlignmentConfig();
nTeacher = 40*config.sampling.teacherHz;
nParticipant = 40*config.sampling.participantHz;
teacher = syntheticRecording(ones(1,nTeacher), ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(ones(1,nParticipant), ...
    config.sampling.participantHz,"participant.mat");
teacher.coordinates(1:3,300:314) = NaN;

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


function testArtificialDyadBuilderWritesCompleteMetadata(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = syntheticAlignmentConfig();
config.markers.excludedLabels = {'Excluded marker'};
config.paths.dataRoot = fullfile(temporaryRoot,'data');
config.paths.outputRoot = fullfile(temporaryRoot,'outputs');
config.paths.qcOutputRoot = fullfile(config.paths.outputRoot,'qc');
config.paths.modelOutputRoot = fullfile(config.paths.outputRoot, ...
    'preprocessed_models');
config.paths.participantsOutputRoot = fullfile(config.paths.outputRoot, ...
    'participants');
config.dyads.overwrite = true;
mkdir(config.paths.qcOutputRoot);

teacherFolder = fullfile(config.paths.dataRoot,'Michalina','1_mat');
participantFolder = fullfile(config.paths.dataRoot,'001','1_mat');
mkdir(teacherFolder);
mkdir(participantFolder);
teacherFile = string(fullfile(teacherFolder,'1_mir_low_v1_mov1.mat'));
participantFile = string(fullfile(participantFolder, ...
    '1_mir_low_v1_mov1.mat'));
writeSyntheticQtm(teacherFile,config.sampling.teacherHz,40);
writeSyntheticQtm(participantFile,config.sampling.participantHz,40);

% Numeric IDs can arise when a cached CSV is imported; filenames must still
% use the canonical three-digit representation rather than char(1).
Subject = 1;
TrialIndex = 1;
Instruction = "mir";
Complexity = "low";
Version = 1;
Movement = 1;
PairingKey = "low_v1_mov1";
ParticipantFile = participantFile;
TeacherFile = teacherFile;
PairingStatus = "matched";
ReadyForAlignment = true;
dyadManifest = table(Subject,TrialIndex,Instruction,Complexity,Version, ...
    Movement,PairingKey,ParticipantFile,TeacherFile,PairingStatus, ...
    ReadyForAlignment);
File = teacherFile;
Role = "teacher";
frameQC = table(File,Role,ReadyForAlignment);

[savedManifest,summary] = EmpaticMirroring_CreateArtificialDyads( ...
    dyadManifest,config,frameQC);

verifyEqual(testCase,summary.createdCount,1);
verifyEqual(testCase,summary.errorCount,0);
verifyEqual(testCase,summary.availableCount,summary.eligibleCount);
verifyTrue(testCase,isfile(savedManifest.DyadFile));
verifyTrue(testCase,contains(savedManifest.DyadFile,"S001_T01"));
saved = load(savedManifest.DyadFile,'markData','dyad_info', ...
    'marker_policy','bad_segments');
verifySize(testCase,saved.markData,[6 3960 2]);
verifyEqual(testCase,saved.dyad_info.excludedMarkers, ...
    config.markers.excludedLabels);
verifyEqual(testCase,saved.marker_policy.excludedLabels, ...
    config.markers.excludedLabels);
verifyEmpty(testCase,saved.bad_segments);

end


function testGapBeyondReconstructionLimitExcludesRecording(testCase)

config = syntheticAlignmentConfig();
nTeacher = 40*config.sampling.teacherHz;
nParticipant = 40*config.sampling.participantHz;
teacher = syntheticRecording(ones(1,nTeacher), ...
    config.sampling.teacherHz,"teacher.mat");
participant = syntheticRecording(ones(1,nParticipant), ...
    config.sampling.participantHz,"participant.mat");
participant.coordinates(1:3,100:341) = NaN;

verifyError(testCase,@() EmpaticMirroring_AlignArtificialDyad( ...
    teacher,participant,config), ...
    'FREQNESS:GapInterpolation:UnresolvedGaps');

end


function testMarkerPolicyUsesCanonicalFullSkeleton(testCase)

config = EmpaticMirroring_Config();
rawLabels = circshift(string(config.markers.labels),5);
nMarkers = numel(rawLabels);
nSamples = 20;
coordinates = zeros(3*nMarkers,nSamples);
for markerIndex = 1:nMarkers
    coordinates(3*markerIndex+(-2:0),:) = markerIndex;
end

[retained,labels,policy] = EmpaticMirroring_ApplyMarkerPolicy( ...
    coordinates,rawLabels,120,config);

verifyEqual(testCase,labels,string(config.markers.labels(:)));
verifySize(testCase,retained,[3*config.markers.expectedCount nSamples]);
expectedMarkerIndices = zeros(nMarkers,1);
for markerIndex = 1:nMarkers
    expectedMarkerIndices(markerIndex) = find( ...
        rawLabels == string(config.markers.labels{markerIndex}));
end
verifyEqual(testCase,retained(1:3:end,1),expectedMarkerIndices);
verifyTrue(testCase,policy.isEligible);
verifyEmpty(testCase,policy.unresolvedMarkerLabels);

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


function testConfirmedCoreFrequencyGrid(testCase)

config = EmpaticMirroring_Config();
expectedBeatFrequency = 1.67*ones(1,2);
expectedFrexVector = (1.67/4:1.67/8:1.67*4)';

verifyEqual(testCase,config.block1.beat_frex,expectedBeatFrequency);
verifyEqual(testCase,config.block1.frex, ...
    repmat(expectedFrexVector,1,2));
verifyEqual(testCase,config.block1.ncomps,4);
verifyFalse(testCase,config.block1.run);
verifyEqual(testCase,config.block4.pattern_components,1:2);
verifyEqual(testCase,config.block4.pattern_frequencies,[.25 .5 1 2]);
verifyTrue(testCase,config.block4.plot_pattern_bones);
verifyEqual(testCase,config.markers.rawExpectedCount,22);
verifyEqual(testCase,config.markers.expectedCount,22);
verifyEqual(testCase,config.markers.policyVersion, ...
    "full22_toolbox_context_v4");
verifyEqual(testCase,string(config.markers.labels(:)),[ ...
    "L Elbow";"L Wrist";"L Hand";"L Shoulder";"R Shoulder"; ...
    "Sternum";"R Elbow";"R Wrist";"R Hand";"L Hip";"R Hip"; ...
    "Pelvis";"L Knee";"R Knee";"L Ankle";"R Ankle"; ...
    "L Foot";"R Foot";"B Head";"L Head";"R Head";"T Head"]);
verifyEqual(testCase,config.markers.bones,[ ...
    20,22;22,21;21,19;19,20;19,6;4,6;6,5;4,5;4,1;1,2;2,3; ...
    5,7;7,8;8,9;6,12;10,12;11,12;10,11;10,13;13,15;15,17; ...
    11,14;14,16;16,18]);

end


function testVisualizerShowsBonesForBothDyadMembers(testCase)

previousVisibility = get(groot,'defaultFigureVisible');
set(groot,'defaultFigureVisible','off');
cleanup = onCleanup(@() set(groot,'defaultFigureVisible', ...
    previousVisibility));

FREQ = struct( ...
    'evals',ones(6,1,2), ...
    'pats',reshape(1:12,[6 1 1 2]), ...
    'frex',1);
Patterns = struct( ...
    'frex',1, ...
    'labels',{{'Marker 1','Marker 2'}}, ...
    'markerData',reshape(1:12,[6 1 2]), ...
    'comp',1, ...
    'srate',120, ...
    'start',0, ...
    'bones',[1 2], ...
    'plot_bones',true, ...
    'plot_matrix',false, ...
    'animate',false);

figures = FREQNESS_Visualizer_Mocap(FREQ,[],Patterns);
% One link is drawn in three projections for each of two dyad members.
verifyEqual(testCase,numel(findall(figures.patterns(1),'Type','Line')),6);
close(figures.patterns);

end


function testVisualizerCanHideBones(testCase)

previousVisibility = get(groot,'defaultFigureVisible');
set(groot,'defaultFigureVisible','off');
cleanup = onCleanup(@() set(groot,'defaultFigureVisible', ...
    previousVisibility));

FREQ = struct( ...
    'evals',ones(6,1,2), ...
    'pats',reshape(1:12,[6 1 1 2]), ...
    'frex',1);
Patterns = struct( ...
    'frex',1, ...
    'labels',{{'Marker 1','Marker 2'}}, ...
    'markerData',reshape(1:12,[6 1 2]), ...
    'comp',1, ...
    'srate',120, ...
    'start',0, ...
    'bones',[1 2], ...
    'plot_bones',false, ...
    'plot_matrix',false, ...
    'animate',false);

figures = FREQNESS_Visualizer_Mocap(FREQ,[],Patterns);
verifyEmpty(testCase,findobj(figures.patterns(1),'Type','Line'));
close(figures.patterns);

end


function testCoreAnalysisIsResumableAndUsesBadSegments(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = syntheticAlignmentConfig();
config.paths.qcOutputRoot = fullfile(temporaryRoot,'qc');
config.block1.beat_frex = 1.67*ones(1,2);
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
bad_segments_by_participant = {20,30};
markData(:,bad_segments,:) = 0;
marker_reference = markData(:,1,:);
marker_policy = struct('version',config.markers.policyVersion);
dyad_info = struct('subject',"001",'trialIndex',1);
save(dyadFile,'markData','srate','bad_segments', ...
    'bad_segments_by_participant', ...
    'marker_reference','marker_policy','dyad_info');

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
verifyEqual(testCase,savedCore.FREQ.bad_segments_by_participant, ...
    bad_segments_by_participant);
verifySize(testCase,savedCore.FREQ.evals,[6 2 2]);
verifySize(testCase,savedCore.FREQ.evecs,[6 2 2 2]);

[secondManifest,secondSummary] = EmpaticMirroring_RunCoreAnalysis( ...
    dyadManifest,config,networkEstimatorContract);
verifyEqual(testCase,secondManifest.CoreStatus,"existing");
verifyEqual(testCase,secondSummary.existingCount,1);
verifyEqual(testCase,secondSummary.createdCount,0);

end


function testLandscapeAnalysisPreservesDesignAndIsResumable(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = EmpaticMirroring_Config();
config.paths.qcOutputRoot = fullfile(temporaryRoot,'qc');
config.block2.output_path = fullfile(temporaryRoot,'02_Landscape');
config.block2.overwrite_flag = false;
config.block2.save_flag = true;
config.block2.ncomps2keep = 2;
config.block2.max_dyads = inf;

participantOutputRoot = fullfile(temporaryRoot,'participants','001');
mkdir(participantOutputRoot);
dyadFile = fullfile(participantOutputRoot, ...
    'S001_T01_mir_low_v1_mov1.mat');
coreFile = fullfile(participantOutputRoot, ...
    'FREQNESS_CORE_S001_T01_mir_low_v1_mov1.mat');

FREQ = struct();
FREQ.evals = reshape(1:24,[6 2 2]);
FREQ.evals(6,1,1) = -1e-5;
FREQ.pats = reshape(1:96,[6 4 2 2]);
FREQ.frex = repmat([1;2],1,2);
FREQ.frex_norm = FREQ.frex./[1.67 1.67];
marker_reference = zeros(6,1,2);
save(coreFile,'FREQ','marker_reference');

DyadFile = string(dyadFile);
DyadStatus = "created";
CoreFile = string(coreFile);
CoreStatus = "created";
Subject = "001";
TrialIndex = 1;
Instruction = "mir";
Complexity = "low";
Version = 1;
Movement = 1;
dyadManifest = table(DyadFile,DyadStatus,CoreFile,CoreStatus, ...
    Subject,TrialIndex,Instruction,Complexity,Version,Movement);

[firstManifest,firstSummary] = ...
    EmpaticMirroring_RunLandscapeAnalysis(dyadManifest,config);

verifyEqual(testCase,firstManifest.LandscapeStatus,"created");
verifyEqual(testCase,firstSummary.createdCount,1);
verifyEqual(testCase,firstSummary.errorCount,0);
verifyTrue(testCase,isfile(firstManifest.LandscapeFile));
verifyTrue(testCase,isfile(firstSummary.groupOutputFile));
verifyEqual(testCase,fileparts(firstManifest.LandscapeFile), ...
    string(config.block2.output_path));

[expectedFREQ,expectedCorrectionCount] = ...
    correctTestEigenvalueNoise(FREQ);
[expectedH2,expectedED] = FREQNESS_EffectDim_Mocap( ...
    expectedFREQ,'figure',false);
savedLandscape = load(firstManifest.LandscapeFile,'H2_teacher', ...
    'H2_participant','ED_teacher','ED_participant','eigenvalue_qc');
verifyEqual(testCase,savedLandscape.H2_teacher, ...
    expectedH2(:,1),'AbsTol',eps);
verifyEqual(testCase,savedLandscape.H2_participant, ...
    expectedH2(:,2),'AbsTol',eps);
verifyEqual(testCase,savedLandscape.ED_teacher, ...
    expectedED(:,1),'AbsTol',eps);
verifyEqual(testCase,savedLandscape.ED_participant, ...
    expectedED(:,2),'AbsTol',eps);
verifyEqual(testCase,savedLandscape.eigenvalue_qc.correctedCount, ...
    expectedCorrectionCount);
verifyEqual(testCase,firstManifest.NegativeEigenvalueCount, ...
    expectedCorrectionCount);
verifyGreaterThan(testCase, ...
    firstManifest.MaximumNegativeMassRatio,0);
verifyLessThanOrEqual(testCase, ...
    firstManifest.MaximumNegativeMassRatio, ...
    config.block2.eigenvalue_negative_tolerance);

group = load(firstSummary.groupOutputFile,'analysisRows', ...
    'participantIds','designTable','validTrialMask','marker_reference');
verifyFalse(testCase,isfield(group,'all_evals'));
verifyEqual(testCase,group.participantIds,"001");
verifyEqual(testCase,height(group.designTable),24);
verifySize(testCase,group.validTrialMask,[1 24]);
verifyTrue(testCase,group.validTrialMask(1,1,1));
verifyEqual(testCase,group.analysisRows.Subject,"001");
verifyEqual(testCase,group.analysisRows.Instruction,"mir");
verifyEqual(testCase,group.analysisRows.Complexity,"low");
verifyEqual(testCase,group.analysisRows.Version,1);
verifyEqual(testCase,group.analysisRows.Movement,1);
verifyEqual(testCase,group.analysisRows.TrialIndex,1);
verifyEqual(testCase,group.analysisRows.ParticipantIndex,1);
verifyEqual(testCase,group.analysisRows.ConditionIndex,1);
verifyEqual(testCase,group.analysisRows.RepetitionIndex,1);
verifyTrue(testCase,group.analysisRows.SummaryIncluded);
verifyEqual(testCase,group.marker_reference,marker_reference);

% A stricter historical acceptance ceiling does not invalidate identical
% corrected spectra after the configured ceiling is relaxed.
historicalLandscape = load(firstManifest.LandscapeFile);
historicalLandscape.eigenvalue_qc.tolerance = 1e-5;
save(firstManifest.LandscapeFile,'-struct','historicalLandscape');
[secondManifest,secondSummary] = ...
    EmpaticMirroring_RunLandscapeAnalysis(dyadManifest,config);
verifyEqual(testCase,secondManifest.LandscapeStatus,"existing");
verifyEqual(testCase,secondSummary.existingCount,1);
verifyEqual(testCase,secondSummary.createdCount,0);

end


function testAnalysisIndexPreservesConditionsAndRepetitions(testCase)

Subject = ["002";"001";"001";"001"];
TrialIndex = [8;9;1;7];
Instruction = ["obs";"mir";"mir";"mir"];
Complexity = ["high";"low";"low";"low"];
Version = [2;1;1;1];
Movement = [2;1;1;2];
dyadManifest = table(Subject,TrialIndex,Instruction,Complexity, ...
    Version,Movement);

[analysisRows,design] = EmpaticMirroring_IndexAnalysisRows( ...
    dyadManifest,(1:4)');

verifyEqual(testCase,design.participantIds,["001";"002"]);
verifyEqual(testCase,height(design.designTable),24);
verifyEqual(testCase,design.ntrials,2);
verifyEqual(testCase,analysisRows.ParticipantIndex,[2;1;1;1]);
verifyEqual(testCase,analysisRows.ConditionIndex,[24;1;1;2]);
verifyEqual(testCase,analysisRows.RepetitionIndex,[1;2;1;1]);

end


function testCoordinationAnalysisUsesFactorialIndicesAndIsResumable(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = EmpaticMirroring_Config();
config.paths.qcOutputRoot = fullfile(temporaryRoot,'qc');
config.block3.spatial_output_path = fullfile(temporaryRoot, ...
    '03_Interaction','02_SpatialAndLandscape');
config.block3.overwrite_flag = false;
config.block3.save_flag = true;
config.block3.components = 1;
config.block3.metric_levels = 1;
config.block3.max_dyads = inf;

participantOutputRoot = fullfile(temporaryRoot,'participants','001');
mkdir(participantOutputRoot);
dyadFile = fullfile(participantOutputRoot, ...
    'S001_T01_mir_low_v1_mov1.mat');
coreFile = fullfile(participantOutputRoot, ...
    'FREQNESS_CORE_S001_T01_mir_low_v1_mov1.mat');

rng(812);
FREQ = struct();
FREQ.ts = randn(2,600,2,2);
FREQ.pats = randn(6,2,2,2);
FREQ.frex = repmat([1;2],1,2);
FREQ.evals = cat(3,[4 3;2 2;1 1;.5 .6;.3 .2;.1 .1], ...
    [3 4;2 2;1 1;.6 .5;.2 .3;.1 .1]);
FREQ.srate = 120;
beat_frex = [1.67 1.67];
save(coreFile,'FREQ','beat_frex');

DyadFile = string(dyadFile);
CoreFile = string(coreFile);
Subject = "001";
TrialIndex = 1;
Instruction = "mir";
Complexity = "low";
Version = 1;
Movement = 1;
dyadManifest = table(DyadFile,CoreFile,Subject,TrialIndex, ...
    Instruction,Complexity,Version,Movement);

[firstManifest,firstSummary] = ...
    EmpaticMirroring_RunCoordinationAnalysis(dyadManifest,config);

verifyEqual(testCase,firstManifest.CoordinationStatus,"created");
verifyEqual(testCase,firstSummary.createdCount,1);
verifyEqual(testCase,firstSummary.errorCount,0);
outputFile = firstSummary.coordinationManifest.CoordinationFile;
verifyTrue(testCase,isfile(outputFile));
saved = load(outputFile,'FREQmirror','landscape_similarity_comp', ...
    'landscape_similarity_entropy','selected_frex','which_comp', ...
    'meter','analysis_info');
verifyEqual(testCase,saved.which_comp,1);
verifyEqual(testCase,saved.meter,1);
verifyEqual(testCase,saved.analysis_info.method, ...
    "spatial_mirroring_and_landscape_similarity");
verifyEqual(testCase,numel(saved.FREQmirror),1);
verifyTrue(testCase,isfinite(saved.landscape_similarity_comp));
verifyTrue(testCase,isfinite(saved.landscape_similarity_entropy));
verifyEqual(testCase,saved.selected_frex,[1;2]);

summaryFile = fullfile(config.block3.spatial_output_path,'Component_1', ...
    'FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#1.mat');
verifyTrue(testCase,isfile(summaryFile));
group = load(summaryFile,'MIRROR','LANDSCAPE_SIMILARITY_COMP', ...
    'LANDSCAPE_SIMILARITY_ENTROPY','designTable', ...
    'componentRows','validTrialMask');
verifySize(testCase,group.MIRROR,[1 24]);
verifyEqual(testCase,group.MIRROR(1,1,1,1),saved.FREQmirror);
verifyEqual(testCase,group.LANDSCAPE_SIMILARITY_COMP(1,1,1), ...
    saved.landscape_similarity_comp);
verifyEqual(testCase,group.LANDSCAPE_SIMILARITY_ENTROPY(1,1,1), ...
    saved.landscape_similarity_entropy);
verifyEqual(testCase,height(group.designTable),24);
verifyEqual(testCase,group.componentRows.ConditionIndex,1);
verifyTrue(testCase,group.validTrialMask(1,1,1));

[secondManifest,secondSummary] = ...
    EmpaticMirroring_RunCoordinationAnalysis(dyadManifest,config);
verifyEqual(testCase,secondManifest.CoordinationStatus,"existing");
verifyEqual(testCase,secondSummary.existingCount,1);
verifyEqual(testCase,secondSummary.createdCount,0);

end


function testPhaseRQAUsesFactorialIndicesAndIsResumable(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = EmpaticMirroring_Config();
config.paths.qcOutputRoot = fullfile(temporaryRoot,'qc');
config.block3.rqa_output_path = fullfile(temporaryRoot, ...
    '03_Interaction','01_PhaseSpaceRQA');
config.block3.overwrite_flag = false;
config.block3.save_flag = true;
config.block3.components = 1;
config.block3.metric_levels = 1;
config.block3.rqa_downsample_factor = 2;
config.block3.rqa_lp_order = 4;
config.block3.rqa_lp_cutoff_norm = .8;
config.block3.rqa_duration = [.15 .85];
config.block3.rqa_standardize = true;
config.block3.rqa_threshold_method = 'max_fraction';
config.block3.rqa_threshold = .2;
config.block3.rqa_theiler_window = 0;
config.block3.rqa_lmin = 2;
config.block3.rqa_vmin = 2;
config.block3.rqa_store_matrices = false;
config.block3.rqa_figure = false;
config.block3.rqa_animate = false;
config.block3.max_dyads = inf;

participantOutputRoot = fullfile(temporaryRoot,'participants','001');
mkdir(participantOutputRoot);
dyadFile = fullfile(participantOutputRoot, ...
    'S001_T01_mir_low_v1_mov1.mat');
coreFile = fullfile(participantOutputRoot, ...
    'FREQNESS_CORE_S001_T01_mir_low_v1_mov1.mat');

rng(913);
FREQ = struct();
FREQ.ts = randn(2,600,2,2);
FREQ.frex = repmat([1;2],1,2);
FREQ.srate = 120;
% The six-sample valid island 121:126 is too short for filtfilt and must be
% added to the remapped mask rather than joined to neighboring valid runs.
FREQ.bad_segments = [101:120 127:140 301:305];
FREQ.ts(:,FREQ.bad_segments,:,:) = 1e6;
beat_frex = [1.67 1.67];
save(coreFile,'FREQ','beat_frex');

DyadFile = string(dyadFile);
CoreFile = string(coreFile);
Subject = "001";
TrialIndex = 1;
Instruction = "mir";
Complexity = "low";
Version = 1;
Movement = 1;
dyadManifest = table(DyadFile,CoreFile,Subject,TrialIndex, ...
    Instruction,Complexity,Version,Movement);

[firstManifest,firstSummary] = ...
    EmpaticMirroring_RunPhaseSpaceRQA(dyadManifest,config);

verifyEqual(testCase,firstManifest.PhaseRQAStatus,"created");
verifyEqual(testCase,firstSummary.createdCount,1);
verifyEqual(testCase,firstSummary.errorCount,0);
outputFile = firstSummary.phaseRQAManifest.PhaseRQAFile;
verifyTrue(testCase,isfile(outputFile));
saved = load(outputFile,'FREQrqa','PhaseRQA','analysis_info', ...
    'preprocessing_qc');
verifyEqual(testCase,saved.PhaseRQA.component,1);
verifyEqual(testCase,saved.analysis_info.outputSrate,60);
verifyEqual(testCase,saved.analysis_info.implementation,"gap_aware_v1");
verifyEqual(testCase,numel(saved.FREQrqa),1);
verifyFalse(testCase,isfield(saved.FREQrqa,'DistanceMatrix') && ...
    ~isempty(saved.FREQrqa.DistanceMatrix));
verifyGreaterThan(testCase,saved.FREQrqa.ExcludedSampleCount,0);
verifyLessThan(testCase,saved.FREQrqa.ValidSampleCount, ...
    numel(saved.FREQrqa.SelectedSampleIndices));
verifyEqual(testCase,saved.preprocessing_qc.ShortRunExcludedSampleCount,6);

summaryFile = fullfile(config.block3.rqa_output_path,'Component_1', ...
    'FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#1.mat');
verifyTrue(testCase,isfile(summaryFile));
group = load(summaryFile,'PhaseRQA','designTable', ...
    'componentRows','validTrialMask');
verifySize(testCase,group.PhaseRQA.output.RR,[1 24]);
verifyEqual(testCase,group.PhaseRQA.output.RR(1,1,1,1), ...
    saved.FREQrqa.RR);
verifyEqual(testCase,group.PhaseRQA.coverage.ValidSampleCount(1,1,1,1), ...
    saved.FREQrqa.ValidSampleCount);
verifyEqual(testCase,height(group.designTable),24);
verifyEqual(testCase,group.componentRows.ConditionIndex,1);
verifyTrue(testCase,group.validTrialMask(1,1,1));

[secondManifest,secondSummary] = ...
    EmpaticMirroring_RunPhaseSpaceRQA(dyadManifest,config);
verifyEqual(testCase,secondManifest.PhaseRQAStatus,"existing");
verifyEqual(testCase,secondSummary.existingCount,1);
verifyEqual(testCase,secondSummary.createdCount,0);

end


function testGroupAndStatisticsUseParticipantCellMeans(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = EmpaticMirroring_Config();
config.block2.output_path = fullfile(temporaryRoot,'02_Landscape');
config.block3.spatial_output_path = fullfile(temporaryRoot, ...
    '03_Interaction','02_SpatialAndLandscape');
config.block3.components = 1;
config.block3.rqa_output_path = fullfile(temporaryRoot, ...
    '03_Interaction','01_PhaseSpaceRQA');
config.block4.output_path = fullfile(temporaryRoot,'04_Group');
config.block4.figure_path = fullfile(config.block4.output_path,'Figures');
config.block4.make_figures = false;
config.block4.ncomps2keep = 2;
config.block4.max_dyads = inf;
config.block5.output_path = fullfile(temporaryRoot,'05_Statistics_R');
config.block5.overwrite_flag = false;
config.block5.write_xlsx = false;

participantOutputRoot = fullfile(temporaryRoot,'participants','001');
mkdir(participantOutputRoot);
mkdir(config.block2.output_path);
coreFiles = strings(2,1);
landscapeFiles = strings(2,1);
for triali = 1:2
    coreFiles(triali) = fullfile(participantOutputRoot, ...
        "FREQNESS_CORE_S001_T0" + triali + "_mir_low_v1_mov1.mat");
    landscapeFiles(triali) = fullfile(config.block2.output_path, ...
        "FREQNESS_LANDSCAPE_S001_T0" + triali + ...
        "_mir_low_v1_mov1.mat");
    value = 2*triali-1;
    roleEvals = nan(6,2,2);
    roleEvals(:,:,1) = 10*value;
    roleEvals(:,:,2) = value;
    FREQ = struct( ...
        'evals',roleEvals, ...
        'pats',value*ones(6,2,2,2), ...
        'frex_norm',repmat([2/3;4/3],1,2));
    marker_reference = zeros(6,1,2);
    ED_teacher = 10*value*ones(2,1);
    ED_participant = value*ones(2,1);
    save(coreFiles(triali),'FREQ','marker_reference');
    save(landscapeFiles(triali),'ED_teacher','ED_participant');
end

DyadFile = ["dyad1.mat";"dyad2.mat"];
CoreFile = coreFiles;
LandscapeFile = landscapeFiles;
Subject = ["001";"001"];
TrialIndex = [1;2];
Instruction = ["mir";"mir"];
Complexity = ["low";"low"];
Version = [1;1];
Movement = [1;1];
dyadManifest = table(DyadFile,CoreFile,LandscapeFile,Subject, ...
    TrialIndex,Instruction,Complexity,Version,Movement);
[componentRows,design] = EmpaticMirroring_IndexAnalysisRows( ...
    dyadManifest,(1:2)');
participantIds = design.participantIds;
designTable = design.designTable;
meter = 1;
validTrialMask = false(1,24,2);
validTrialMask(1,1,1:2) = true;

coordinationFolder = fullfile(config.block3.spatial_output_path, ...
    'Component_1');
mkdir(coordinationFolder);
MIRROR = nan(1,24,1,2);
MIRROR(1,1,1,:) = [1 3];
LANDSCAPE_SIMILARITY_COMP = nan(1,24,2);
LANDSCAPE_SIMILARITY_COMP(1,1,:) = [.2 .6];
LANDSCAPE_SIMILARITY_ENTROPY = nan(1,24,2);
LANDSCAPE_SIMILARITY_ENTROPY(1,1,:) = [.4 .8];
save(fullfile(coordinationFolder, ...
    'FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#1.mat'), ...
    'MIRROR','LANDSCAPE_SIMILARITY_COMP', ...
    'LANDSCAPE_SIMILARITY_ENTROPY','meter','participantIds','designTable', ...
    'componentRows','validTrialMask');

phaseFolder = fullfile(config.block3.rqa_output_path,'Component_1');
mkdir(phaseFolder);
PhaseRQA = struct();
phaseFields = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
for fieldi = 1:numel(phaseFields)
    PhaseRQA.output.(phaseFields{fieldi}) = nan(1,24,1,2);
    PhaseRQA.output.(phaseFields{fieldi})(1,1,1,:) = [1 3];
end
coverageFields = {'ValidSampleCount','ExcludedSampleCount', ...
    'EligiblePairCount','EligiblePairFraction'};
coverageValues = {[10 20],[2 4],[100 400],[.5 .7]};
for fieldi = 1:numel(coverageFields)
    PhaseRQA.coverage.(coverageFields{fieldi}) = nan(1,24,1,2);
    PhaseRQA.coverage.(coverageFields{fieldi})(1,1,1,:) = ...
        coverageValues{fieldi};
end
save(fullfile(phaseFolder, ...
    'FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#1.mat'), ...
    'PhaseRQA','meter','participantIds','designTable', ...
    'componentRows','validTrialMask');

groupSummary = EmpaticMirroring_RunGroupAnalysis(dyadManifest,config);
verifyEqual(testCase,groupSummary.recordingCount,2);
network = load(groupSummary.networkSummaryFile);
verifyFalse(testCase,isfield(network,'sem_evals_teacher'));
verifyFalse(testCase,isfield(network,'sem_ED_teacher'));
verifyEqual(testCase,network.avg_evals_teacher(1,:,:), ...
    20*ones(1,6,2));
verifyEqual(testCase,network.avg_evals_participant(1,:,:), ...
    2*ones(1,6,2));
verifyEqual(testCase,network.avg_pats(1,:,:,:,:),2*ones(1,6,2,2,2));
verifyEqual(testCase,network.avg_ED_teacher(1,:),20*ones(1,2));
verifyEqual(testCase,network.avg_ED_participant(1,:),2*ones(1,2));
verifyEqual(testCase,network.participantCounts(1),1);

% BLOCK 6 uses only trials available to both spatial and temporal analyses.
phaseSummaryFile = fullfile(phaseFolder, ...
    'FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#1.mat');
phaseSummary = load(phaseSummaryFile);
phaseSummary.validTrialMask(1,1,2) = false;
save(phaseSummaryFile,'-struct','phaseSummary');

statistics = EmpaticMirroring_ExportStatistics(config);
verifyEqual(testCase,statistics.rowCount,1);
T = statistics.statisticsTable;
verifyEqual(testCase,T.Participant,"001");
verifyEqual(testCase,T.Instruction,"mir");
verifyEqual(testCase,T.Complexity,"low");
verifyEqual(testCase,T.Version,1);
verifyEqual(testCase,T.Movement,1);
verifyEqual(testCase,T.NRepetitions,1);
verifyEqual(testCase,T.Mirror,1);
verifyFalse(testCase,ismember('RR_JRQA',T.Properties.VariableNames));
verifyFalse(testCase,ismember('DET_JRQA',T.Properties.VariableNames));
verifyEqual(testCase,T.RR_Phase,1);
verifyEqual(testCase,T.ValidSamples_Phase,10);
verifyEqual(testCase,T.ExcludedSamples_Phase,2);
verifyEqual(testCase,T.EligiblePairs_Phase,100);
verifyEqual(testCase,T.EligiblePairFraction_Phase,.5, ...
    'AbsTol',eps);
verifyTrue(testCase,isfile(statistics.combinedCsvFile));
verifyTrue(testCase,isfile(statistics.landscapeSimilarityCsvFile));
verifyEqual(testCase,height(statistics.landscapeSimilarityTable),1);
verifyEqual(testCase, ...
    statistics.landscapeSimilarityTable.LandscapeSimilarityComponent,.4);
verifyEqual(testCase, ...
    statistics.landscapeSimilarityTable.LandscapeSimilarityEntropy,.6, ...
    'AbsTol',eps);

end


function testRecoverySensitivityWaivesOnlyFolderAnnotation(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));

config = EmpaticMirroring_Config();
config.paths.qcOutputRoot = char(temporaryRoot);
File = ["accepted.mat";"wrong_rate.mat";"bad_marker.mat"; ...
    "teacher.mat"];
Subject = ["002";"002";"022";"Michalina"];
Role = ["participant";"participant";"participant";"teacher"];
FolderStatus = ["annotated subject folder"; ...
    "annotated subject folder";"annotated subject folder";"ok"];
LoadStatus = repmat("ok",4,1);
NameStatus = repmat("ok",4,1);
MarkerStatus = ["ok";"ok";"expected 22, found 21";"ok"];
MarkerPolicyStatus = repmat("ok",4,1);
SampleRate = [120;100;120;300];
LengthStatus = repmat("ok",4,1);
RetainedBadTimepointCount = zeros(4,1);
RequiredFrames = [3960;3300;3960;9900];
OverallStatus = [repmat("annotated subject folder",3,1);"ok"];
ExcludeRecording = [true;true;true;false];
ExclusionReasons = [repmat( ...
    "folder: annotated subject folder",3,1);""];
ReadyForAlignment = [false;false;false;true];
frameQC = table(File,Subject,Role,FolderStatus,LoadStatus,NameStatus, ...
    MarkerStatus,MarkerPolicyStatus,SampleRate,LengthStatus, ...
    RetainedBadTimepointCount,RequiredFrames,OverallStatus, ...
    ExcludeRecording,ExclusionReasons,ReadyForAlignment);

[sensitivityQC,audit,summary] = ...
    EmpaticMirroring_BuildRecoverySensitivityQC(frameQC,config);

verifyEqual(testCase,summary.recoveredCount,1);
verifyEqual(testCase,summary.remainingExcludedCount,2);
verifyEqual(testCase,audit.RecoverForSensitivity,[true;false;false]);
accepted = sensitivityQC.File == "accepted.mat";
verifyEqual(testCase,sensitivityQC.FolderStatus(accepted),"ok");
verifyTrue(testCase,sensitivityQC.ReadyForAlignment(accepted));
verifyFalse(testCase,sensitivityQC.ExcludeRecording(accepted));
wrongRate = audit.File == "wrong_rate.mat";
verifyTrue(testCase,contains( ...
    audit.ObjectiveExclusionReasons(wrongRate),"sample rate"));
badMarker = audit.File == "bad_marker.mat";
verifyTrue(testCase,contains( ...
    audit.ObjectiveExclusionReasons(badMarker),"marker layout"));
verifyTrue(testCase,isfile(fullfile(temporaryRoot, ...
    'recovery_recording_audit.csv')));

end


function testRecoverySensitivityOutputPathsAreIsolated(testCase)

primary = EmpaticMirroring_Config();
primaryRoot = string(primary.paths.outputRoot);
[recovered,combined] = ...
    EmpaticMirroring_ConfigureRecoverySensitivity(primary);

verifyEqual(testCase,string(primary.paths.outputRoot),primaryRoot);
verifyTrue(testCase,startsWith(string(recovered.paths.outputRoot), ...
    string(primary.sensitivity.output_root)));
verifyTrue(testCase,startsWith(string(combined.paths.outputRoot), ...
    string(primary.sensitivity.output_root)));
verifyNotEqual(testCase,string(recovered.paths.outputRoot),primaryRoot);
verifyNotEqual(testCase,string(combined.paths.outputRoot),primaryRoot);
verifyNotEqual(testCase,string(recovered.paths.outputRoot), ...
    string(combined.paths.outputRoot));
verifyEqual(testCase,string(recovered.paths.qcOutputRoot), ...
    string(combined.paths.qcOutputRoot));

end


function testAnnotatedParticipantFolderUsesValidatedManifestId(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));
config = EmpaticMirroring_Config();
config.paths.dataRoot = char(temporaryRoot);
config.paths.participantsOutputRoot = fullfile(temporaryRoot,'outputs');
participantFile = fullfile(temporaryRoot,'002-only 5','2_mat', ...
    '1_mir_low_v1_mov1.mat');

resultsFolder = EmpaticMirroring_ParticipantResultsFolder( ...
    participantFile,config,"002");

verifyEqual(testCase,string(resultsFolder), ...
    string(fullfile(config.paths.participantsOutputRoot,'002')));

end


function testSensitivityManifestCombinesOnlyAvailableDisjointRows(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));
primaryFile = fullfile(temporaryRoot,'primary.mat');
recoveredFile = fullfile(temporaryRoot,'recovered.mat');
unused = 1;
save(primaryFile,'unused');
save(recoveredFile,'unused');

primary = sensitivityManifestFixture("001",1,"p1.mat", ...
    primaryFile,"created");
primary = [primary; sensitivityManifestFixture("003",2,"p3.mat", ...
    "missing.mat","not eligible")];
recovered = sensitivityManifestFixture("002",1,"p2.mat", ...
    recoveredFile,"existing");
outputFile = fullfile(temporaryRoot,'combined.csv');

[combined,summary] = EmpaticMirroring_CombineSensitivityManifests( ...
    primary,recovered,"CoreStatus","CoreFile",outputFile);

verifyEqual(testCase,summary.primaryCount,1);
verifyEqual(testCase,summary.recoveredCount,1);
verifyEqual(testCase,summary.combinedCount,2);
verifyEqual(testCase,string(combined.Subject),["001";"002"]);
verifyEqual(testCase,string(combined.AnalysisCohort), ...
    ["primary retained";"recovered sensitivity"]);
verifyTrue(testCase,isfile(outputFile));

end


function testSensitivityCompactSummaryMergePreservesParticipantOrder(testCase)

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot,'s'));
primary = EmpaticMirroring_Config();
primary.paths.outputRoot = fullfile(temporaryRoot,'primary');
primary.block2.output_path = fullfile(primary.paths.outputRoot,'02_Landscape');
primary.block3.spatial_output_path = fullfile(primary.paths.outputRoot, ...
    '03_Interaction','02_SpatialAndLandscape');
primary.block3.rqa_output_path = fullfile(primary.paths.outputRoot, ...
    '03_Interaction','01_PhaseSpaceRQA');
primary.block3.components = 1;
recovered = primary;
recovered.paths.outputRoot = fullfile(temporaryRoot,'recovered');
recovered.block3.spatial_output_path = fullfile( ...
    recovered.paths.outputRoot,'03_Interaction','02_SpatialAndLandscape');
recovered.block3.rqa_output_path = fullfile( ...
    recovered.paths.outputRoot,'03_Interaction','01_PhaseSpaceRQA');
combined = primary;
combined.paths.outputRoot = fullfile(temporaryRoot,'combined');
combined.paths.qcOutputRoot = fullfile(combined.paths.outputRoot,'qc');
combined.block3.spatial_output_path = fullfile( ...
    combined.paths.outputRoot,'03_Interaction','02_SpatialAndLandscape');
combined.block3.rqa_output_path = fullfile( ...
    combined.paths.outputRoot,'03_Interaction','01_PhaseSpaceRQA');

writeCompactSensitivityFixtures(primary,["001";"003"],[10;30],2);
writeCompactSensitivityFixtures(recovered,"002",20,1);
summary = EmpaticMirroring_MergeSensitivitySummaries( ...
    primary,recovered,combined);

mergedFile = fullfile(combined.block3.spatial_output_path,'Component_1', ...
    'FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#1.mat');
S = load(mergedFile,'MIRROR','participantIds','validTrialMask');
verifyEqual(testCase,string(S.participantIds),["001";"002";"003"]);
verifyEqual(testCase,squeeze(S.MIRROR(:,1,1,1)),[10;20;30]);
verifySize(testCase,S.MIRROR,[3 24 1 2]);
verifyEqual(testCase,summary.audit.CombinedParticipants,3);
verifyEqual(testCase,summary.audit.CombinedValidRecordings,3);

end


function manifest = sensitivityManifestFixture( ...
    subject,trialIndex,participantFile,coreFile,coreStatus)

ParticipantFile = string(participantFile);
Subject = string(subject);
TrialIndex = trialIndex;
Instruction = "mir";
Complexity = "low";
Version = 1;
Movement = 1;
DyadFile = "dyad.mat";
CoreStatus = string(coreStatus);
CoreFile = string(coreFile);
manifest = table(ParticipantFile,Subject,TrialIndex,Instruction, ...
    Complexity,Version,Movement,DyadFile,CoreStatus,CoreFile);

end


function writeCompactSensitivityFixtures(config,participantIds,values,ntrials)

participantIds = string(participantIds(:));
values = values(:);
nparticipants = numel(participantIds);
condition = (1:24)';
instruction = repmat("mir",24,1);
complexity = repmat("low",24,1);
version = ones(24,1);
movement = ones(24,1);
designTable = table(condition,instruction,complexity,version,movement, ...
    'VariableNames',{'ConditionIndex','Instruction','Complexity', ...
    'Version','Movement'});
meter = 1;
which_comp = 1;
MIRROR = nan(nparticipants,24,1,ntrials);
LANDSCAPE_SIMILARITY_COMP = nan(nparticipants,24,ntrials);
LANDSCAPE_SIMILARITY_ENTROPY = nan(nparticipants,24,ntrials);
validTrialMask = false(nparticipants,24,ntrials);
for participanti = 1:nparticipants
    MIRROR(participanti,1,1,1) = values(participanti);
    LANDSCAPE_SIMILARITY_COMP(participanti,1,1) = values(participanti)/100;
    LANDSCAPE_SIMILARITY_ENTROPY(participanti,1,1) = ...
        values(participanti)/100;
    validTrialMask(participanti,1,1) = true;
end
ParticipantLabel = participantIds;
ParticipantIndex = (1:nparticipants)';
componentRows = table(ParticipantLabel,ParticipantIndex);
coordinationFolder = fullfile(config.block3.spatial_output_path, ...
    'Component_1');
mkdir(coordinationFolder);
save(fullfile(coordinationFolder, ...
    'FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#1.mat'), ...
    'MIRROR','LANDSCAPE_SIMILARITY_COMP', ...
    'LANDSCAPE_SIMILARITY_ENTROPY','which_comp','meter', ...
    'participantIds','designTable', ...
    'componentRows','validTrialMask');

PhaseRQA = struct();
phaseFields = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
for fieldi = 1:numel(phaseFields)
    PhaseRQA.output.(phaseFields{fieldi}) = MIRROR;
end
coverageFields = {'ValidSampleCount','ExcludedSampleCount', ...
    'EligiblePairCount','EligiblePairFraction'};
for fieldi = 1:numel(coverageFields)
    PhaseRQA.coverage.(coverageFields{fieldi}) = MIRROR;
end
phaseFolder = fullfile(config.block3.rqa_output_path,'Component_1');
mkdir(phaseFolder);
save(fullfile(phaseFolder, ...
    'FREQNESS_PHASERQA_GAPAWARE_SUMMARY_Comp#1.mat'), ...
    'PhaseRQA','which_comp','meter','participantIds','designTable', ...
    'componentRows','validTrialMask');

end


function [FREQ,correctedCount] = correctTestEigenvalueNoise(FREQ)

correctedCount = 0;
for subi = 1:size(FREQ.evals,3)
    for frexi = 1:size(FREQ.evals,2)
        values = FREQ.evals(:,frexi,subi);
        negativeMask = values < 0;
        if any(negativeMask)
            originalSum = sum(values);
            values(negativeMask) = 0;
            values = values.*(originalSum/sum(values));
            FREQ.evals(:,frexi,subi) = values;
            correctedCount = correctedCount + nnz(negativeMask);
        end
    end
end

end


function recording = syntheticRecording(signal,sampleRate,fileName)

recording = struct();
recording.file = fileName;
recording.sampleRate = sampleRate;
recording.labels = ["A";"B"];
recording.coordinates = repmat(signal,6,1);

end


function writeSyntheticQtm(filePath,sampleRate,durationSeconds)

nFrames = sampleRate*durationSeconds;
time = (0:nFrames-1)/sampleRate;
trajectory = zeros(2,4,nFrames);
for markerIndex = 1:2
    trajectory(markerIndex,1,:) = sin(2*pi*1.5*time) + markerIndex;
    trajectory(markerIndex,2,:) = cos(2*pi*1.5*time) + markerIndex;
    trajectory(markerIndex,3,:) = 0.5*sin(2*pi*0.75*time) + markerIndex;
    trajectory(markerIndex,4,:) = 1;
end
qtm_test = struct( ...
    'Frames',nFrames, ...
    'FrameRate',sampleRate, ...
    'Trajectories',struct('Labeled',struct( ...
    'Data',trajectory,'Labels',{{'A','B'}})));
save(filePath,'qtm_test');

end


function config = syntheticAlignmentConfig()

config = EmpaticMirroring_Config();
config.markers.rawExpectedCount = 2;
config.markers.policyVersion = "synthetic_fixed2_v1";
config.markers.labels = {'A','B'};
config.markers.excludedLabels = {};
config.markers.bones = [1 2];
config.markers.expectedCount = 2;

end
