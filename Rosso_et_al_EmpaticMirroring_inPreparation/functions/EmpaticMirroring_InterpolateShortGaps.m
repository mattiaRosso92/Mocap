function [coordinates,report] = EmpaticMirroring_InterpolateShortGaps( ...
    coordinates,sampleRate,maxGapSeconds)
%EMPATICMIRRORING_INTERPOLATESHORTGAPS Repair bounded marker dropouts.
%   A marker sample is missing when any of its XYZ coordinates is nonfinite.
%   Only gaps no longer than maxGapSeconds and bounded by valid samples on
%   both sides are linearly interpolated. Longer and edge gaps are retained.

if ~isnumeric(coordinates) || ~ismatrix(coordinates) || ...
        mod(size(coordinates,1),3) ~= 0
    error('EmpaticMirroring:CoordinateShape', ...
        'Coordinates must be a numeric [3*markers x time] matrix.');
end
if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
        ~isfinite(sampleRate) || sampleRate <= 0
    error('EmpaticMirroring:SampleRate', ...
        'sampleRate must be one positive finite scalar.');
end
if ~isnumeric(maxGapSeconds) || ~isscalar(maxGapSeconds) || ...
        ~isfinite(maxGapSeconds) || maxGapSeconds < 0
    error('EmpaticMirroring:GapDuration', ...
        'maxGapSeconds must be one nonnegative finite scalar.');
end

nMarkers = size(coordinates,1)/3;
maxGapSamples = floor(maxGapSeconds*sampleRate);
initialInvalidSampleCount = 0;
interpolatedSampleCount = 0;
interpolatedGapCount = 0;
retainedGapCount = 0;

for markerIndex = 1:nMarkers
    rows = 3*(markerIndex-1) + (1:3);
    invalid = any(~isfinite(coordinates(rows,:)),1);
    initialInvalidSampleCount = initialInvalidSampleCount + nnz(invalid);
    if ~any(invalid)
        continue
    end

    transitions = diff([false invalid false]);
    gapStarts = find(transitions == 1);
    gapEnds = find(transitions == -1)-1;

    for gapIndex = 1:numel(gapStarts)
        firstMissing = gapStarts(gapIndex);
        lastMissing = gapEnds(gapIndex);
        gapLength = lastMissing-firstMissing+1;
        bounded = firstMissing > 1 && lastMissing < size(coordinates,2);

        if maxGapSamples > 0 && gapLength <= maxGapSamples && bounded && ...
                all(isfinite(coordinates(rows,firstMissing-1)),'all') && ...
                all(isfinite(coordinates(rows,lastMissing+1)),'all')
            endpoints = [firstMissing-1 lastMissing+1];
            query = firstMissing:lastMissing;
            for coordinateIndex = rows
                coordinates(coordinateIndex,query) = interp1( ...
                    endpoints,coordinates(coordinateIndex,endpoints), ...
                    query,'linear');
            end
            interpolatedSampleCount = interpolatedSampleCount + gapLength;
            interpolatedGapCount = interpolatedGapCount + 1;
        else
            retainedGapCount = retainedGapCount + 1;
        end
    end
end

remainingInvalid = false(nMarkers,size(coordinates,2));
for markerIndex = 1:nMarkers
    rows = 3*(markerIndex-1) + (1:3);
    remainingInvalid(markerIndex,:) = ...
        any(~isfinite(coordinates(rows,:)),1);
end

report = struct( ...
    'maxGapSeconds',maxGapSeconds, ...
    'maxGapSamples',maxGapSamples, ...
    'initialInvalidSampleCount',initialInvalidSampleCount, ...
    'interpolatedSampleCount',interpolatedSampleCount, ...
    'interpolatedGapCount',interpolatedGapCount, ...
    'retainedGapCount',retainedGapCount, ...
    'remainingInvalidSampleCount',nnz(remainingInvalid), ...
    'remainingInvalidMask',remainingInvalid);

end
