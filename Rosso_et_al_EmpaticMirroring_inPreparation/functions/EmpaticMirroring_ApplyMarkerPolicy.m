function [coordinates,labels,policy] = ...
    EmpaticMirroring_ApplyMarkerPolicy( ...
    coordinates,labels,sampleRate,config)
%EMPATICMIRRORING_APPLYMARKERPOLICY Create the full analysis marker space.
%   Raw markers are reordered to the canonical 22-marker skeleton. Short
%   gaps are linearly interpolated and longer accepted gaps are reconstructed
%   with the cross-validated cubic-spline method. Observed values are never
%   changed. Every originally missing sample remains identified for exclusion
%   from FREQ-NESS and downstream time-resolved analyses.

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
[markerCoordinates,reconstruction] = reconstructMarkerGaps( ...
    markerCoordinates,originalMissingMask,sampleRate,config);

coordinates = reshape(permute(markerCoordinates,[2 1 3]), ...
    3*nMarkers,nSamples);
unresolvedLabels = labels(any(reconstruction.unresolvedMask,2));
policy = struct( ...
    'version',string(config.markers.policyVersion), ...
    'labels',labels, ...
    'originalMissingMask',originalMissingMask, ...
    'originalBadSampleMask',any(originalMissingMask,1), ...
    'interpolatedMask',reconstruction.interpolatedMask, ...
    'interpolatedSampleCount',nnz(reconstruction.interpolatedMask), ...
    'reconstructedMask',reconstruction.reconstructedMask, ...
    'reconstructedSampleCount',nnz(reconstruction.reconstructedMask), ...
    'filledMask',reconstruction.filledMask, ...
    'filledSampleCount',nnz(reconstruction.filledMask), ...
    'unresolvedMask',reconstruction.unresolvedMask, ...
    'unresolvedBadSampleMask',any(reconstruction.unresolvedMask,1), ...
    'unresolvedMarkerLabels',unresolvedLabels, ...
    'maximumInterpolatedGapFrames',reconstruction.maximumInterpolatedGapFrames, ...
    'maximumInterpolatedGapMilliseconds', ...
    1000*reconstruction.maximumInterpolatedGapFrames/sampleRate, ...
    'maximumReconstructedGapFrames', ...
    reconstruction.maximumReconstructedGapFrames, ...
    'maximumReconstructedGapMilliseconds', ...
    1000*reconstruction.maximumReconstructedGapFrames/sampleRate, ...
    'completeTimepointFraction',mean(~any(originalMissingMask,1)), ...
    'reconstructionMethod',string( ...
    config.preprocessing.reconstructionMethod), ...
    'isEligible',~any(reconstruction.unresolvedMask,'all'));

end


function [markerCoordinates,details] = reconstructMarkerGaps( ...
    markerCoordinates,originalMissingMask,sampleRate,config)

nMarkers = size(markerCoordinates,1);
nSamples = size(markerCoordinates,3);
maximumInterpolatedGapFrames = floor( ...
    config.preprocessing.shortGapInterpolationSeconds*sampleRate + 1e-9);
maximumReconstructedGapFrames = floor( ...
    config.preprocessing.maximumReconstructedGapSeconds*sampleRate + 1e-9);
interpolatedMask = false(nMarkers,nSamples);
reconstructedMask = false(nMarkers,nSamples);
unresolvedMask = false(nMarkers,nSamples);

filled = markerCoordinates;
for markerIndex = 1:nMarkers
    missing = originalMissingMask(markerIndex,:);
    transitions = diff([false missing false]);
    gapStarts = find(transitions == 1);
    gapEnds = find(transitions == -1)-1;
    for gapIndex = 1:numel(gapStarts)
        indices = gapStarts(gapIndex):gapEnds(gapIndex);
        if numel(indices) <= maximumInterpolatedGapFrames
            interpolatedMask(markerIndex,indices) = true;
        elseif numel(indices) <= maximumReconstructedGapFrames
            reconstructedMask(markerIndex,indices) = true;
        else
            unresolvedMask(markerIndex,indices) = true;
        end
    end
    markerValues = reshape(markerCoordinates(markerIndex,:,:),3,nSamples);
    shortIndices = find(interpolatedMask(markerIndex,:));
    longIndices = find(reconstructedMask(markerIndex,:));
    if ~isempty(longIndices)
        [markerValues,success] = ...
            fillMissingIndices(markerValues,longIndices,'spline');
        if ~success
            unresolvedMask(markerIndex,longIndices) = true;
            reconstructedMask(markerIndex,longIndices) = false;
        end
    end
    if ~isempty(shortIndices)
        markerValues = fillMissingIndices(markerValues,shortIndices,'linear');
    end
    filled(markerIndex,:,:) = reshape(markerValues,1,3,nSamples);
end

markerCoordinates = filled;

details = struct( ...
    'interpolatedMask',interpolatedMask, ...
    'reconstructedMask',reconstructedMask, ...
    'filledMask',interpolatedMask | reconstructedMask, ...
    'unresolvedMask',unresolvedMask, ...
    'maximumInterpolatedGapFrames',maximumInterpolatedGapFrames, ...
    'maximumReconstructedGapFrames',maximumReconstructedGapFrames);

end


function [values,success] = fillMissingIndices(values,indices,method)

success = true;
for coordinateIndex = 1:size(values,1)
    row = values(coordinateIndex,:);
    observed = find(isfinite(row));
    if isempty(observed) || (strcmp(method,'spline') && numel(observed) < 4)
        success = false;
        return
    end
    internal = indices(indices > observed(1) & indices < observed(end));
    if ~isempty(internal)
        row(internal) = interp1(observed,row(observed),internal,method);
    end
    leading = indices(indices < observed(1));
    trailing = indices(indices > observed(end));
    row(leading) = row(observed(1));
    row(trailing) = row(observed(end));
    values(coordinateIndex,:) = row;
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
