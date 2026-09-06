function [dyad,teacherPrepared] = EmpaticMirroring_AlignArtificialDyad( ...
    teacher,participant,config,teacherPrepared)
%EMPATICMIRRORING_ALIGNARTIFICIALDYAD Trigger-align one artificial dyad.
%   In the preprocessed MAT exports, sample 1 is treated as video onset for
%   both roles; both use [0,33 s) and are returned at 120 Hz in
%   coordinates-by-time-by-participant format, ordered model then
%   participant. The fixed study marker policy is applied before alignment.
%   Short-gap interpolation keeps filtering continuous, while originally
%   missing timepoints remain listed in bad_segments for covariance exclusion.

if nargin < 3 || isempty(config)
    config = EmpaticMirroring_Config();
end
if nargin < 4
    teacherPrepared = [];
end

if isempty(teacherPrepared)
    validateRecording(teacher,'teacher');
    assertRate(teacher.sampleRate,config.sampling.teacherHz,'teacher');
    [teacherCoordinates,teacherLabels,teacherMarkerPolicy] = ...
        EmpaticMirroring_ApplyMarkerPolicy(teacher.coordinates, ...
        teacher.labels,teacher.sampleRate,config);
    teacherMarkerPolicy = annotateAnalysisEligibility( ...
        teacherMarkerPolicy,teacher.sampleRate, ...
        config.timing.teacherOffsetSeconds, ...
        config.timing.analysisDurationSeconds);
    assertMarkerEligibility(teacherMarkerPolicy,teacher.file,'teacher');
    [teacherAligned,teacherBadMask,teacherMarkerBadMask,teacherInfo] = ...
        alignWindow(teacherCoordinates, ...
        teacherMarkerPolicy.originalMissingMask, ...
        teacher.sampleRate, ...
        config.sampling.outputHz, ...
        config.timing.teacherOffsetSeconds, ...
        config.timing.analysisDurationSeconds, ...
        config.timing.filterPaddingSeconds);
    teacherPrepared = struct( ...
        'data',teacherAligned, ...
        'badMask',teacherBadMask, ...
        'markerBadMask',teacherMarkerBadMask, ...
        'labels',teacherLabels, ...
        'originalLabels',teacher.labels, ...
        'file',teacher.file, ...
        'alignment',teacherInfo, ...
        'markerPolicy',teacherMarkerPolicy, ...
        'gapReport',summarizeBadMask( ...
        teacherBadMask,config.sampling.outputHz));
else
    validatePreparedTeacher(teacherPrepared,config);
end

% An empty participant is the model-cache preparation mode used by the
% batch builder. It guarantees that each model file is processed only once.
if isempty(participant)
    dyad = [];
    return
end

validateRecording(participant,'participant');
assertRate(participant.sampleRate, ...
    config.sampling.participantHz,'participant');
[participantCoordinates,participantLabels,participantMarkerPolicy] = ...
    EmpaticMirroring_ApplyMarkerPolicy(participant.coordinates, ...
    participant.labels,participant.sampleRate,config);
participantMarkerPolicy = annotateAnalysisEligibility( ...
    participantMarkerPolicy,participant.sampleRate, ...
    config.timing.participantOffsetSeconds, ...
    config.timing.analysisDurationSeconds);
assertMarkerEligibility(participantMarkerPolicy,participant.file, ...
    'participant');
if ~isequal(participantLabels,teacherPrepared.labels)
    error('EmpaticMirroring:CanonicalMarkerMismatch', ...
        'Model and participant do not share the configured marker order.');
end

[participantAligned,participantBadMask,participantMarkerBadMask, ...
    participantInfo] = alignWindow( ...
    participantCoordinates,participantMarkerPolicy.originalMissingMask, ...
    participant.sampleRate, ...
    config.sampling.outputHz, ...
    config.timing.participantOffsetSeconds, ...
    config.timing.analysisDurationSeconds, ...
    config.timing.filterPaddingSeconds);

teacherAligned = teacherPrepared.data;
teacherBadMask = teacherPrepared.badMask;
teacherInfo = teacherPrepared.alignment;
nExpected = round(config.timing.analysisDurationSeconds * ...
    config.sampling.outputHz);
if size(teacherAligned,2) ~= nExpected || ...
        size(participantAligned,2) ~= nExpected
    error('EmpaticMirroring:AlignedLength', ...
        'Aligned recordings must both contain %d samples.',nExpected);
end

badSampleMask = [teacherBadMask(:),participantBadMask(:)];
badSegmentsByParticipant = {find(teacherBadMask),find(participantBadMask)};
badSegments = find(any(badSampleMask,2))';
if numel(badSegments) >= nExpected-1
    error('EmpaticMirroring:InsufficientGoodSamples', ...
        'Fewer than two synchronized samples remain for covariance estimation.');
end
validateMissingValues(teacherAligned,teacherPrepared.markerBadMask, ...
    'teacher');
validateMissingValues(participantAligned,participantMarkerBadMask, ...
    'participant');

teacherGapReport = teacherPrepared.gapReport;
participantGapReport = summarizeBadMask( ...
    participantBadMask,config.sampling.outputHz);

dyad = struct();
dyad.data = cat(3,teacherAligned,participantAligned);
dyad.labels = teacherPrepared.labels;
dyad.teacherLabelsOriginalOrder = teacherPrepared.originalLabels;
dyad.participantLabelsOriginalOrder = participant.labels;
dyad.sampleRate = config.sampling.outputHz;
dyad.time = (0:nExpected-1)/config.sampling.outputHz;
dyad.teacherFile = teacherPrepared.file;
dyad.participantFile = participant.file;
dyad.teacherAlignment = teacherInfo;
dyad.participantAlignment = participantInfo;
dyad.teacherGapReport = teacherGapReport;
dyad.participantGapReport = participantGapReport;
dyad.markerPolicyVersion = string(config.markers.policyVersion);
dyad.teacherMarkerPolicy = teacherPrepared.markerPolicy;
dyad.participantMarkerPolicy = participantMarkerPolicy;
dyad.participantOrder = config.dyads.participantOrder;
dyad.badSampleMask = badSampleMask;
dyad.badMarkerSampleMask = cat(3, ...
    teacherPrepared.markerBadMask,participantMarkerBadMask);
dyad.badSegmentsByParticipant = badSegmentsByParticipant;
% FREQ-NESS currently accepts one shared vector: use the synchronized union
% so every participant covariance is estimated from identical timepoints.
dyad.badSegments = badSegments;
dyad.goodSegments = setdiff(1:nExpected,badSegments);

end


function report = summarizeBadMask(badMask,sampleRate)

transitions = diff([false badMask false]);
gapStarts = find(transitions == 1);
gapEnds = find(transitions == -1)-1;
gapLengths = gapEnds-gapStarts+1;
if isempty(gapLengths)
    longestGapFrames = 0;
else
    longestGapFrames = max(gapLengths);
end

report = struct( ...
    'badSampleCount',nnz(badMask), ...
    'badSamplePercent',100*nnz(badMask)/numel(badMask), ...
    'missingGapCount',numel(gapLengths), ...
    'longestMissingGapFrames',longestGapFrames, ...
    'longestMissingGapMilliseconds',1000*longestGapFrames/sampleRate);

end


function validateRecording(recording,role)

required = {'file','sampleRate','labels','coordinates'};
if ~isstruct(recording) || ~isscalar(recording) || ...
        ~all(isfield(recording,required))
    error('EmpaticMirroring:RecordingStructure', ...
        '%s recording lacks required fields.',role);
end
if ~isnumeric(recording.coordinates) || ...
        ~ismatrix(recording.coordinates) || ...
        mod(size(recording.coordinates,1),3) ~= 0
    error('EmpaticMirroring:CoordinateShape', ...
        '%s coordinates must be [3*markers x time].',role);
end
if numel(recording.labels) ~= size(recording.coordinates,1)/3
    error('EmpaticMirroring:MarkerLabels', ...
        '%s marker-label count does not match its coordinates.',role);
end

end


function validatePreparedTeacher(prepared,config)

required = {'data','badMask','markerBadMask','labels','originalLabels','file', ...
    'alignment','markerPolicy','gapReport'};
expectedSamples = round(config.timing.analysisDurationSeconds * ...
    config.sampling.outputHz);
if ~isstruct(prepared) || ~isscalar(prepared) || ...
        ~all(isfield(prepared,required)) || ...
        ~isnumeric(prepared.data) || ~ismatrix(prepared.data) || ...
        size(prepared.data,2) ~= expectedSamples || ...
        any(~isfinite(prepared.data),'all') || ...
        ~islogical(prepared.badMask) || ...
        ~isequal(size(prepared.badMask),[1 expectedSamples]) || ...
        ~islogical(prepared.markerBadMask) || ...
        ~isequal(size(prepared.markerBadMask), ...
        [numel(config.markers.labels) expectedSamples]) || ...
        numel(prepared.labels) ~= size(prepared.data,1)/3 || ...
        ~isequal(string(prepared.labels(:)), ...
        string(config.markers.labels(:))) || ...
        ~isfield(prepared.markerPolicy,'version') || ...
        string(prepared.markerPolicy.version) ~= ...
        string(config.markers.policyVersion)
    error('EmpaticMirroring:PreparedTeacherStructure', ...
        'Cached model data do not satisfy the artificial-dyad contract.');
end

end


function assertRate(actual,expected,role)

if abs(actual-expected) > max(eps(expected)*10,1e-9)
    error('EmpaticMirroring:UnexpectedSampleRate', ...
        'Expected %s data at %g Hz; found %g Hz.',role,expected,actual);
end

end


function [Y,badMask,markerBadMask,info] = alignWindow( ...
    X,inputMarkerBadMask,fsIn,fsOut,startOffsetSeconds,durationSeconds, ...
    paddingSeconds)

startSample = 1 + round(startOffsetSeconds*fsIn);
nWindowIn = round(durationSeconds*fsIn);
endSample = startSample + nWindowIn - 1;

if endSample > size(X,2)
    availableSeconds = max(0,(size(X,2)-startSample+1)/fsIn);
    error('EmpaticMirroring:RecordingTooShort', ...
        ['Requested %.3f seconds beginning %.3f seconds after the ' ...
         'trigger, but only %.3f seconds are available.'], ...
        durationSeconds,startOffsetSeconds,availableSeconds);
end

nPadIn = round(paddingSeconds*fsIn);
if size(X,2) <= nPadIn
    error('EmpaticMirroring:PaddingLength', ...
        'Recording is too short for %.3f seconds of reflection padding.', ...
        paddingSeconds);
end

inputMarkerBadMask = logical(inputMarkerBadMask);
if size(inputMarkerBadMask,2) ~= size(X,2) || ...
        size(inputMarkerBadMask,1) ~= size(X,1)/3
    error('EmpaticMirroring:MarkerMaskLength', ...
        'The marker-policy mask does not match the recording length.');
end

% No rate conversion is needed for participant recordings. Return only the
% analysis interval, so samples after its manually stopped endpoint cannot
% affect eligibility or enter the artificial dyad.
[p,q] = rat(fsOut/fsIn,1e-12);
if p == q
    Y = X(:,startSample:endSample);
    markerBadMask = inputMarkerBadMask(:,startSample:endSample);
    badMask = any(markerBadMask,1);
    info = alignmentInfo(fsIn,fsOut,p,q,startOffsetSeconds, ...
        durationSeconds,startSample,endSample,size(Y,2));
    return
end

% The recording begins at the trigger. Reflection padding supplies the
% teacher's unavailable pre-trigger filter context; genuine context is used
% whenever the requested window begins later within the recording.
leftReflection = X(:,nPadIn+1:-1:2);
rightReflection = X(:,end-1:-1:end-nPadIn);
XboundaryPadded = [leftReflection X rightReflection];
leftBadReflection = inputMarkerBadMask(:,nPadIn+1:-1:2);
rightBadReflection = inputMarkerBadMask(:,end-1:-1:end-nPadIn);
badBoundaryPadded = [leftBadReflection inputMarkerBadMask ...
    rightBadReflection];

segmentStart = startSample;
segmentLength = nWindowIn + 2*nPadIn;
Xsegment = XboundaryPadded(:, ...
    segmentStart:segmentStart+segmentLength-1);
badSegment = badBoundaryPadded(:, ...
    segmentStart:segmentStart+segmentLength-1);

if any(~isfinite(Xsegment),'all')
    error('EmpaticMirroring:UnresolvedMarkerGap', ...
        'The retained teacher interval or resampling guard contains a gap.');
end
if exist('resample','file') ~= 2
    error('EmpaticMirroring:MissingResample', ...
        'MATLAB Signal Processing Toolbox function resample is required.');
end
% resample applies a polyphase anti-aliasing FIR before the teacher's
% 300-to-120 Hz decimation (rational sampling ratio 2/5).
Ysegment = resample(Xsegment',p,q)';
% Map originally missing instants to the resampled time grid. Do not filter
% the binary mask: FIR ringing would falsely mark distant valid samples.
inputTime = (0:size(badSegment,2)-1)/fsIn;
outputTime = (0:size(Ysegment,2)-1)/fsOut;
markerBadSegmentOutput = interp1(inputTime,double(badSegment'), ...
    outputTime,'nearest',0)' > 0.5;

nPadOut = round(paddingSeconds*fsOut);
nWindowOut = round(durationSeconds*fsOut);
Y = Ysegment(:,nPadOut+(1:nWindowOut));
markerBadMask = markerBadSegmentOutput(:,nPadOut+(1:nWindowOut));
badMask = any(markerBadMask,1);

info = alignmentInfo(fsIn,fsOut,p,q,startOffsetSeconds,durationSeconds, ...
    startSample,endSample,nWindowOut);

end


function policy = annotateAnalysisEligibility( ...
    policy,sampleRate,startOffsetSeconds,durationSeconds)

startSample = 1 + round(startOffsetSeconds*sampleRate);
endSample = startSample + round(durationSeconds*sampleRate)-1;
unresolved = policy.unresolvedMask(:,startSample:endSample);
policy.analysisUnresolvedMarkerLabels = ...
    policy.labels(any(unresolved,2));
policy.analysisIsEligible = ~any(unresolved,'all');

end


function assertMarkerEligibility(policy,file,role)

if policy.analysisIsEligible
    return
end
error('EmpaticMirroring:LongRetainedMarkerGap', ...
    ['%s recording %s contains a gap longer than the 50 ms limit in ' ...
     'retained marker(s): %s.'],role,string(file), ...
    strjoin(policy.analysisUnresolvedMarkerLabels,', '));

end


function validateMissingValues(coordinates,markerBadMask,role)

nMarkers = size(markerBadMask,1);
nSamples = size(markerBadMask,2);
coordinateBadMask = repelem(markerBadMask,3,1);
nonfiniteMask = ~isfinite(coordinates);
if ~isequal(size(coordinates),[3*nMarkers nSamples]) || ...
        any(nonfiniteMask & ~coordinateBadMask,'all')
    error('EmpaticMirroring:UnmaskedMissingValue', ...
        '%s data contain a missing value outside the marker mask.',role);
end

end


function info = alignmentInfo(fsIn,fsOut,p,q,startOffsetSeconds, ...
    durationSeconds,startSample,endSample,nOutputSamples)

info = struct( ...
    'inputSampleRate',fsIn, ...
    'outputSampleRate',fsOut, ...
    'resamplingRatio',[p q], ...
    'startOffsetSeconds',startOffsetSeconds, ...
    'durationSeconds',durationSeconds, ...
    'inputStartSample',startSample, ...
    'inputEndSample',endSample, ...
    'outputSamples',nOutputSamples);

end
