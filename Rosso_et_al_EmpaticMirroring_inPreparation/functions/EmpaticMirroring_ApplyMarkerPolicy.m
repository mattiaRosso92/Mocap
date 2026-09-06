function [coordinates,labels,policy] = ...
    EmpaticMirroring_ApplyMarkerPolicy( ...
    coordinates,labels,sampleRate,config)
%EMPATICMIRRORING_APPLYMARKERPOLICY Create one fixed analysis marker space.
%   Raw markers are reordered to config.markers.labels and all other markers
%   are discarded consistently across recordings. Gaps no longer than the
%   study threshold are linearly interpolated marker-wise for filter
%   continuity, while the original missing-sample mask remains available
%   for covariance exclusion. Any longer retained-marker gap remains
%   unresolved and makes the recording ineligible for this study analysis.

if nargin < 4 || isempty(config)
    config = EmpaticMirroring_Config();
end
if ~isnumeric(coordinates) || ~ismatrix(coordinates) || ...
        mod(size(coordinates,1),3) ~= 0
    error('EmpaticMirroring:MarkerPolicyCoordinateShape', ...
        'Coordinates must be [3*markers x time].');
end
if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
        ~isfinite(sampleRate) || sampleRate <= 0
    error('EmpaticMirroring:MarkerPolicySampleRate', ...
        'sampleRate must be a positive finite scalar.');
end

sourceLabels = normalizeMarkerLabels(labels);
targetLabels = string(config.markers.labels(:));
if numel(sourceLabels) ~= size(coordinates,1)/3
    error('EmpaticMirroring:MarkerPolicyLabelCount', ...
        'Marker-label count does not match the coordinate array.');
end
[matched,markerOrder] = ismember(lower(targetLabels),lower(sourceLabels));
if ~all(matched) || numel(unique(markerOrder)) ~= numel(markerOrder)
    missingLabels = targetLabels(~matched);
    error('EmpaticMirroring:MarkerPolicyMismatch', ...
        'Recording lacks required analysis markers: %s.', ...
        strjoin(missingLabels,', '));
end

coordinateOrder = reshape(3*markerOrder(:)' + (-2:0)',1,[]);
coordinates = coordinates(coordinateOrder,:);
labels = targetLabels;

nMarkers = numel(labels);
nSamples = size(coordinates,2);
markerCoordinates = permute(reshape( ...
    coordinates,3,nMarkers,nSamples),[2 1 3]);
originalMissingMask = reshape(any(~isfinite(markerCoordinates),2), ...
    nMarkers,nSamples);
interpolatedMask = false(nMarkers,nSamples);
unresolvedMask = false(nMarkers,nSamples);
maximumGapFrames = floor( ...
    config.preprocessing.shortGapInterpolationSeconds*sampleRate + 1e-9);

for markerIndex = 1:nMarkers
    missing = originalMissingMask(markerIndex,:);
    transitions = diff([false missing false]);
    gapStarts = find(transitions == 1);
    gapEnds = find(transitions == -1)-1;
    for gapIndex = 1:numel(gapStarts)
        indices = gapStarts(gapIndex):gapEnds(gapIndex);
        if numel(indices) <= maximumGapFrames
            markerValues = reshape(markerCoordinates(markerIndex,:,:), ...
                3,nSamples);
            markerValues = interpolateGap(markerValues,indices);
            markerCoordinates(markerIndex,:,:) = reshape(markerValues, ...
                1,3,nSamples);
            interpolatedMask(markerIndex,indices) = true;
        else
            unresolvedMask(markerIndex,indices) = true;
        end
    end
end

coordinates = reshape(permute(markerCoordinates,[2 1 3]), ...
    3*nMarkers,nSamples);
unresolvedLabels = labels(any(unresolvedMask,2));
policy = struct( ...
    'version',string(config.markers.policyVersion), ...
    'labels',labels, ...
    'originalMissingMask',originalMissingMask, ...
    'originalBadSampleMask',any(originalMissingMask,1), ...
    'interpolatedMask',interpolatedMask, ...
    'interpolatedSampleCount',nnz(interpolatedMask), ...
    'unresolvedMask',unresolvedMask, ...
    'unresolvedBadSampleMask',any(unresolvedMask,1), ...
    'unresolvedMarkerLabels',unresolvedLabels, ...
    'maximumInterpolatedGapFrames',maximumGapFrames, ...
    'maximumInterpolatedGapMilliseconds', ...
    1000*maximumGapFrames/sampleRate, ...
    'isEligible',~any(unresolvedMask,'all'));

end


function values = interpolateGap(values,gapIndices)

% A short boundary gap has only one observed neighbor and is held at that
% value; an internal gap is linearly interpolated between observed samples.
nSamples = size(values,2);
leftIndex = gapIndices(1)-1;
rightIndex = gapIndices(end)+1;
if leftIndex >= 1 && rightIndex <= nSamples && ...
        all(isfinite(values(:,[leftIndex rightIndex])),'all')
    fraction = (gapIndices-leftIndex)/(rightIndex-leftIndex);
    values(:,gapIndices) = values(:,leftIndex) + ...
        (values(:,rightIndex)-values(:,leftIndex)).*fraction;
elseif leftIndex >= 1 && all(isfinite(values(:,leftIndex)))
    values(:,gapIndices) = values(:,leftIndex);
elseif rightIndex <= nSamples && all(isfinite(values(:,rightIndex)))
    values(:,gapIndices) = values(:,rightIndex);
end

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
if numel(unique(normalized)) ~= numel(normalized)
    error('EmpaticMirroring:DuplicateCanonicalMarker', ...
        'Marker aliases produce duplicate canonical labels.');
end

labels = strings(size(normalized));
for labelIndex = 1:numel(normalized)
    words = split(normalized(labelIndex)," ");
    for wordIndex = 1:numel(words)
        word = char(words(wordIndex));
        if ~isempty(word)
            word(1) = upper(word(1));
        end
        words(wordIndex) = string(word);
    end
    labels(labelIndex) = strjoin(words," ");
end

end
