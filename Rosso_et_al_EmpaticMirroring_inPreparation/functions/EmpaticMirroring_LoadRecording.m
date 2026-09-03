function recording = EmpaticMirroring_LoadRecording(filePath)
%EMPATICMIRRORING_LOADRECORDING Load one QTM MATLAB export for FREQ-NESS.
%   The QTM trajectory array is [markers x values x frames], where values
%   1:3 are XYZ. Coordinates are returned in the toolbox convention
%   [X1;Y1;Z1;X2;Y2;Z2;...] x time.

filePath = char(string(filePath));
if exist(filePath,'file') ~= 2
    error('EmpaticMirroring:FileNotFound','File not found: %s',filePath);
end

loaded = load(filePath);
topLevelNames = fieldnames(loaded);
if numel(topLevelNames) ~= 1
    error('EmpaticMirroring:TopLevelVariableCount', ...
        'Expected one top-level variable in %s; found %d.', ...
        filePath,numel(topLevelNames));
end

qtm = loaded.(topLevelNames{1});
if ~isstruct(qtm) || ~isscalar(qtm) || ...
        ~isfield(qtm,'Trajectories') || ...
        ~isfield(qtm.Trajectories,'Labeled') || ...
        ~isfield(qtm.Trajectories.Labeled,'Data')
    error('EmpaticMirroring:QTMStructure', ...
        'QTM labeled trajectory data were not found in %s.',filePath);
end

trajectoryData = qtm.Trajectories.Labeled.Data;
if ~isnumeric(trajectoryData) || ndims(trajectoryData) ~= 3 || ...
        size(trajectoryData,2) < 3
    error('EmpaticMirroring:TrajectoryShape', ...
        ['Expected numeric trajectory data shaped ' ...
         '[markers x at-least-3-values x frames] in %s.'],filePath);
end

nMarkers = size(trajectoryData,1);
nFrames = size(trajectoryData,3);
xyz = trajectoryData(:,1:3,:);
coordinates = reshape(permute(xyz,[2 1 3]),3*nMarkers,nFrames);

if ~isfield(qtm,'FrameRate') || ~isnumeric(qtm.FrameRate) || ...
        ~isscalar(qtm.FrameRate) || ~isfinite(qtm.FrameRate) || ...
        qtm.FrameRate <= 0
    error('EmpaticMirroring:FrameRate', ...
        'A positive scalar FrameRate was not found in %s.',filePath);
end

if isfield(qtm,'Frames') && qtm.Frames ~= nFrames
    error('EmpaticMirroring:FrameCountMismatch', ...
        'Declared Frames (%g) differs from trajectory frames (%d) in %s.', ...
        qtm.Frames,nFrames,filePath);
end

if isfield(qtm.Trajectories.Labeled,'Labels') && ...
        numel(qtm.Trajectories.Labeled.Labels) == nMarkers
    labels = string(qtm.Trajectories.Labeled.Labels(:));
else
    labels = "Marker_" + (1:nMarkers)';
end

quality = [];
if size(trajectoryData,2) >= 4
    quality = reshape(trajectoryData(:,4,:),nMarkers,nFrames);
end

recording = struct();
recording.file = string(filePath);
recording.variableName = string(topLevelNames{1});
recording.sampleRate = double(qtm.FrameRate);
recording.frameCount = nFrames;
recording.labels = labels;
recording.coordinates = double(coordinates);
recording.quality = double(quality);
recording.nonfiniteCoordinateFraction = ...
    nnz(~isfinite(coordinates))/numel(coordinates);

end
