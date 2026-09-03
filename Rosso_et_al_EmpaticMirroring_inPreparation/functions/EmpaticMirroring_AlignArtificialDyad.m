function [dyad,teacherPrepared] = EmpaticMirroring_AlignArtificialDyad( ...
    teacher,participant,config,teacherPrepared)
%EMPATICMIRRORING_ALIGNARTIFICIALDYAD Trigger-align one artificial dyad.
%   In the preprocessed MAT exports, sample 1 is treated as video onset for
%   both roles; both use [0,33 s) and are returned at 120 Hz in
%   coordinates-by-time-by-participant format, ordered model then
%   participant. Remaining missing timepoints are zero placeholders and are
%   listed in bad_segments; they must be excluded from covariance estimates.

if nargin < 3 || isempty(config)
    config = EmpaticMirroring_Config();
end
if nargin < 4
    teacherPrepared = [];
end

if isempty(teacherPrepared)
    validateRecording(teacher,'teacher');
    assertRate(teacher.sampleRate,config.sampling.teacherHz,'teacher');
    teacherLabels = normalizeMarkerLabels(teacher.labels);
    [teacherAligned,teacherBadMask,teacherInfo] = alignWindow( ...
        teacher.coordinates,teacher.sampleRate, ...
        config.sampling.outputHz, ...
        config.timing.teacherOffsetSeconds, ...
        config.timing.analysisDurationSeconds, ...
        config.timing.filterPaddingSeconds);
    teacherPrepared = struct( ...
        'data',teacherAligned, ...
        'badMask',teacherBadMask, ...
        'labels',teacherLabels, ...
        'originalLabels',teacher.labels, ...
        'file',teacher.file, ...
        'alignment',teacherInfo, ...
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
participantLabels = normalizeMarkerLabels(participant.labels);
[participantCoordinates,~] = reorderMarkers( ...
    participant.coordinates,participantLabels,teacherPrepared.labels);

[participantAligned,participantBadMask,participantInfo] = alignWindow( ...
    participantCoordinates,participant.sampleRate, ...
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
if any(~isfinite(teacherAligned),'all') || ...
        any(~isfinite(participantAligned),'all')
    error('EmpaticMirroring:NonfiniteDyadInput', ...
        'Artificial-dyad data must be finite after bad-sample masking.');
end

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
dyad.participantOrder = config.dyads.participantOrder;
dyad.badSampleMask = badSampleMask;
dyad.badSegmentsByParticipant = badSegmentsByParticipant;
% FREQ-NESS currently accepts one shared vector: use the synchronized union
% so every participant covariance is estimated from identical timepoints.
dyad.badSegments = badSegments;
dyad.goodSegments = setdiff(1:nExpected,badSegments);

end


function labels = normalizeMarkerLabels(labels)

labels = regexprep(strtrim(string(labels(:))),'\s+',' ');
normalized = lower(labels);
aliases = [ ...
    "strainum", "sternum"; ...
    "r should", "r shoulder"; ...
    "l ankel", "l ankle"; ...
    "r ankel", "r ankle"; ...
    "f head", "t head"];
for aliasIndex = 1:size(aliases,1)
    normalized(normalized == aliases(aliasIndex,1)) = ...
        aliases(aliasIndex,2);
end

% The model's F Head and participants' T Head are the sole unmatched head
% labels among otherwise identical 22-marker sets. Treat them as one shared
% reference; the supplied layout confirms that four head markers are used.
labels = strings(size(normalized));
for labelIndex = 1:numel(normalized)
    labels(labelIndex) = canonicalCapitalization(normalized(labelIndex));
end

if numel(unique(normalized)) ~= numel(normalized)
    error('EmpaticMirroring:DuplicateCanonicalMarker', ...
        'Marker aliases produce duplicate canonical labels.');
end

end


function label = canonicalCapitalization(label)

words = split(label," ");
for wordIndex = 1:numel(words)
    word = char(words(wordIndex));
    if ~isempty(word)
        word(1) = upper(word(1));
    end
    words(wordIndex) = string(word);
end
label = strjoin(words," ");

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

required = {'data','badMask','labels','originalLabels','file', ...
    'alignment','gapReport'};
expectedSamples = round(config.timing.analysisDurationSeconds * ...
    config.sampling.outputHz);
if ~isstruct(prepared) || ~isscalar(prepared) || ...
        ~all(isfield(prepared,required)) || ...
        ~isnumeric(prepared.data) || ~ismatrix(prepared.data) || ...
        size(prepared.data,2) ~= expectedSamples || ...
        any(~isfinite(prepared.data),'all') || ...
        ~islogical(prepared.badMask) || ...
        ~isequal(size(prepared.badMask),[1 expectedSamples]) || ...
        numel(prepared.labels) ~= size(prepared.data,1)/3
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


function [coordinates,originalLabels] = reorderMarkers( ...
    coordinates,originalLabels,targetLabels)

originalLabels = string(originalLabels(:));
targetLabels = string(targetLabels(:));

[matched,markerOrder] = ismember(lower(strtrim(targetLabels)), ...
    lower(strtrim(originalLabels)));
if ~all(matched) || numel(unique(markerOrder)) ~= numel(markerOrder)
    error('EmpaticMirroring:MarkerMismatch', ...
        'Teacher and participant marker labels do not match uniquely.');
end

coordinateOrder = reshape(3*markerOrder(:)' + (-2:0)',1,[]);
coordinates = coordinates(coordinateOrder,:);

end


function [Y,badMask,info] = alignWindow( ...
    X,fsIn,fsOut,startOffsetSeconds,durationSeconds,paddingSeconds)

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

inputBadMask = any(~isfinite(X),1);
X(:,inputBadMask) = 0;

% The recording begins at the trigger. Reflection padding supplies the
% teacher's unavailable pre-trigger filter context; genuine context is used
% whenever the requested window begins later within the recording.
leftReflection = X(:,nPadIn+1:-1:2);
rightReflection = X(:,end-1:-1:end-nPadIn);
XboundaryPadded = [leftReflection X rightReflection];
leftBadReflection = inputBadMask(nPadIn+1:-1:2);
rightBadReflection = inputBadMask(end-1:-1:end-nPadIn);
badBoundaryPadded = [leftBadReflection inputBadMask rightBadReflection];

segmentStart = startSample;
segmentLength = nWindowIn + 2*nPadIn;
Xsegment = XboundaryPadded(:, ...
    segmentStart:segmentStart+segmentLength-1);
badSegment = badBoundaryPadded( ...
    segmentStart:segmentStart+segmentLength-1);

[p,q] = rat(fsOut/fsIn,1e-12);
if p == q
    Ysegment = Xsegment;
    badSegmentOutput = badSegment;
else
    if exist('resample','file') ~= 2
        error('EmpaticMirroring:MissingResample', ...
            'MATLAB Signal Processing Toolbox function resample is required.');
    end
    % resample applies a polyphase anti-aliasing FIR before the teacher's
    % 300-to-120 Hz decimation (rational sampling ratio 2/5).
    Ysegment = resample(Xsegment',p,q)';
    % Propagate the mask through the same finite-impulse-response operation.
    % Any output influenced by a missing input is excluded downstream.
    badSegmentOutput = abs(resample(double(badSegment),p,q)) > 1e-10;
end

nPadOut = round(paddingSeconds*fsOut);
nWindowOut = round(durationSeconds*fsOut);
Y = Ysegment(:,nPadOut+(1:nWindowOut));
badMask = badSegmentOutput(nPadOut+(1:nWindowOut));
Y(:,badMask) = 0;

info = struct( ...
    'inputSampleRate',fsIn, ...
    'outputSampleRate',fsOut, ...
    'resamplingRatio',[p q], ...
    'startOffsetSeconds',startOffsetSeconds, ...
    'durationSeconds',durationSeconds, ...
    'inputStartSample',startSample, ...
    'inputEndSample',endSample, ...
    'outputSamples',nWindowOut);

end
