function dyad = EmpaticMirroring_AlignArtificialDyad(teacher,participant,config)
%EMPATICMIRRORING_ALIGNARTIFICIALDYAD Trigger-align one artificial dyad.
%   Teacher data use [trigger, trigger+33 s). Participant data use
%   [trigger+3 s, trigger+36 s), excluding the cue/wait period. Both are
%   returned at 120 Hz in coordinates-by-time-by-participant format.

if nargin < 3 || isempty(config)
    config = EmpaticMirroring_Config();
end

validateRecording(teacher,'teacher');
validateRecording(participant,'participant');

assertRate(teacher.sampleRate,config.sampling.teacherHz,'teacher');
assertRate(participant.sampleRate, ...
    config.sampling.participantHz,'participant');

[participantCoordinates,participantLabels] = reorderMarkers( ...
    participant.coordinates,participant.labels,teacher.labels);

[teacherCoordinates,teacherGapReport] = ...
    EmpaticMirroring_InterpolateShortGaps(teacher.coordinates, ...
    teacher.sampleRate,config.preprocessing.maxInterpolatedGapSeconds);
[participantCoordinates,participantGapReport] = ...
    EmpaticMirroring_InterpolateShortGaps(participantCoordinates, ...
    participant.sampleRate,config.preprocessing.maxInterpolatedGapSeconds);

if any(~isfinite(teacherCoordinates(:)))
    error('EmpaticMirroring:TeacherMissingData', ...
        ['Teacher coordinates still contain nonfinite values after ' ...
         'short-gap interpolation; review or exclude this recording.']);
end
if any(~isfinite(participantCoordinates(:)))
    error('EmpaticMirroring:ParticipantMissingData', ...
        ['Participant coordinates still contain nonfinite values after ' ...
         'short-gap interpolation; review or exclude this recording.']);
end

[teacherAligned,teacherInfo] = alignWindow( ...
    teacherCoordinates,teacher.sampleRate, ...
    config.sampling.outputHz, ...
    config.timing.teacherOffsetSeconds, ...
    config.timing.analysisDurationSeconds, ...
    config.timing.filterPaddingSeconds);

[participantAligned,participantInfo] = alignWindow( ...
    participantCoordinates,participant.sampleRate, ...
    config.sampling.outputHz, ...
    config.timing.participantOffsetSeconds, ...
    config.timing.analysisDurationSeconds, ...
    config.timing.filterPaddingSeconds);

nExpected = round(config.timing.analysisDurationSeconds * ...
    config.sampling.outputHz);
if size(teacherAligned,2) ~= nExpected || ...
        size(participantAligned,2) ~= nExpected
    error('EmpaticMirroring:AlignedLength', ...
        'Aligned recordings must both contain %d samples.',nExpected);
end

dyad = struct();
dyad.data = cat(3,teacherAligned,participantAligned);
dyad.labels = teacher.labels;
dyad.participantLabelsOriginalOrder = participantLabels;
dyad.sampleRate = config.sampling.outputHz;
dyad.time = (0:nExpected-1)/config.sampling.outputHz;
dyad.teacherFile = teacher.file;
dyad.participantFile = participant.file;
dyad.teacherAlignment = teacherInfo;
dyad.participantAlignment = participantInfo;
dyad.teacherGapReport = teacherGapReport;
dyad.participantGapReport = participantGapReport;

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


function [Y,info] = alignWindow( ...
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

% The recording begins at the trigger. Reflection padding supplies the
% teacher's unavailable pre-trigger filter context; genuine context is used
% whenever the requested window begins later within the recording.
leftReflection = X(:,nPadIn+1:-1:2);
rightReflection = X(:,end-1:-1:end-nPadIn);
XboundaryPadded = [leftReflection X rightReflection];

segmentStart = startSample;
segmentLength = nWindowIn + 2*nPadIn;
Xsegment = XboundaryPadded(:, ...
    segmentStart:segmentStart+segmentLength-1);

[p,q] = rat(fsOut/fsIn,1e-12);
if p == q
    Ysegment = Xsegment;
else
    if exist('resample','file') ~= 2
        error('EmpaticMirroring:MissingResample', ...
            'MATLAB Signal Processing Toolbox function resample is required.');
    end
    Ysegment = resample(Xsegment',p,q)';
end

nPadOut = round(paddingSeconds*fsOut);
nWindowOut = round(durationSeconds*fsOut);
Y = Ysegment(:,nPadOut+(1:nWindowOut));

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
