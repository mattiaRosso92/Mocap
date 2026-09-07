function frameQC = EmpaticMirroring_FrameCountQC(config)
%EMPATICMIRRORING_FRAMECOUNTQC Inspect every QTM MAT export before analysis.
%   Recordings share an automatic start trigger but were stopped manually.
%   This function finds the unique numeric 3-D matrix in every MAT file,
%   reads its third dimension as frame count, plots the distribution, and
%   flags files that are too short for their trigger-relative window.

dataRoot = config.paths.dataRoot;
outputRoot = config.paths.qcOutputRoot;

files = dir(fullfile(dataRoot,'**','*.mat'));
if isempty(files)
    error('EmpaticMirroring:NoMatFiles', ...
        'No MAT files were found below %s.',dataRoot);
end

filePaths = reshape(string(fullfile({files.folder},{files.name})),[],1);
[filePaths,sortOrder] = sort(filePaths);
files = files(sortOrder);
nFiles = numel(files);

relativePath = strings(nFiles,1);
subject = strings(nFiles,1);
role = strings(nFiles,1);
folderStatus = strings(nFiles,1);
matrixPath = strings(nFiles,1);
matrixSize = strings(nFiles,1);
markerCount = nan(nFiles,1);
markerStatus = strings(nFiles,1);
retainedMarkerCount = nan(nFiles,1);
markerPolicyStatus = strings(nFiles,1);
retainedHasMissingCoordinates = false(nFiles,1);
retainedMissingMarkerSamples = nan(nFiles,1);
retainedBadTimepointCount = nan(nFiles,1);
interpolatedMarkerSamples = nan(nFiles,1);
reconstructedMarkerSamples = nan(nFiles,1);
filledMarkerSamples = nan(nFiles,1);
completeTimepointFraction = nan(nFiles,1);
unresolvedMarkerCount = nan(nFiles,1);
unresolvedMarkers = strings(nFiles,1);
longestValidRunSeconds = nan(nFiles,1);
meetsThreeCycleRunAtLowestFrequency = false(nFiles,1);
numberFrames = nan(nFiles,1);
declaredFrames = nan(nFiles,1);
sampleRate = nan(nFiles,1);
durationSeconds = nan(nFiles,1);
trialIndex = nan(nFiles,1);
instruction = strings(nFiles,1);
complexity = strings(nFiles,1);
version = nan(nFiles,1);
movement = nan(nFiles,1);
note = strings(nFiles,1);
pairingKey = strings(nFiles,1);
loadStatus = strings(nFiles,1);
nameStatus = strings(nFiles,1);
lengthStatus = strings(nFiles,1);
overallStatus = strings(nFiles,1);
errorMessage = strings(nFiles,1);
requiredFrames = nan(nFiles,1);
preferredFrames = nan(nFiles,1);
readyForAlignment = false(nFiles,1);
hasMissingCoordinates = false(nFiles,1);
missingMarkerSamples = nan(nFiles,1);
badTimepointCount = nan(nFiles,1);
missingGapCount = nan(nFiles,1);
longestMissingGapFrames = nan(nFiles,1);
longestMissingGapMilliseconds = nan(nFiles,1);
affectedMarkerCount = nan(nFiles,1);
fullRecordingHasMissingCoordinates = false(nFiles,1);
fullRecordingMissingMarkerSamples = nan(nFiles,1);
fullRecordingMissingGapCount = nan(nFiles,1);
fullRecordingLongestMissingGapMilliseconds = nan(nFiles,1);
excludeRecording = false(nFiles,1);
exclusionReasons = strings(nFiles,1);

dataRootPrefix = string(dataRoot) + filesep;

fprintf('\nInspecting frame counts in %d MAT files...\n',nFiles);

for iFile = 1:nFiles
    trajectory = [];
    markerPolicy = [];
    relativePath(iFile) = erase(filePaths(iFile),dataRootPrefix);
    [matFolder,stem] = fileparts(filePaths(iFile));
    [subjectFolder,~] = fileparts(matFolder);
    [~,subjectName] = fileparts(subjectFolder);
    [role(iFile),subject(iFile),folderStatus(iFile)] = ...
        parseRecordingFolders(subjectName,matFolder,config);

    token = parseRecordingName(stem);
    if isempty(token)
        nameStatus(iFile) = "invalid filename";
    else
        trialIndex(iFile) = str2double(token.trial);
        instruction(iFile) = lower(string(token.instruction));
        complexity(iFile) = lower(string(token.complexity));
        version(iFile) = str2double(token.version);
        movement(iFile) = str2double(token.movement);
        note(iFile) = string(token.note);
        pairingKey(iFile) = complexity(iFile) + "_v" + ...
            version(iFile) + "_mov" + movement(iFile);
        if strlength(strtrim(note(iFile))) > 0
            nameStatus(iFile) = "annotated filename";
        elseif trialIndex(iFile) < 1 || trialIndex(iFile) > 48
            nameStatus(iFile) = "trial index outside 1-48";
        else
            nameStatus(iFile) = "ok";
        end
    end

    try
        loaded = load(char(filePaths(iFile)));
        [candidatePaths,candidateSizes,candidateMatrices] = ...
            findNumeric3DMatrices(loaded,"");

        if isempty(candidatePaths)
            loadStatus(iFile) = "no numeric 3-D matrix";
        elseif numel(candidatePaths) > 1
            loadStatus(iFile) = "multiple numeric 3-D matrices";
            matrixPath(iFile) = strjoin(candidatePaths,"; ");
        else
            matrixPath(iFile) = candidatePaths(1);
            thisSize = candidateSizes(1,:);
            matrixSize(iFile) = sprintf('%dx%dx%d',thisSize);
            markerCount(iFile) = thisSize(1);
            if markerCount(iFile) == config.markers.rawExpectedCount
                markerStatus(iFile) = "ok";
            else
                markerStatus(iFile) = "expected " + ...
                    config.markers.rawExpectedCount + ", found " + ...
                    markerCount(iFile);
            end
            numberFrames(iFile) = thisSize(3);

            [sampleRate(iFile),declaredFrames(iFile)] = ...
                readQtmMetadata(loaded);

            trajectory = candidateMatrices{1};
            fullGapSummary = summarizeMissingCoordinates( ...
                candidateMatrices{1},sampleRate(iFile));
            fullRecordingHasMissingCoordinates(iFile) = ...
                fullGapSummary.hasMissingCoordinates;
            fullRecordingMissingMarkerSamples(iFile) = ...
                fullGapSummary.missingMarkerSamples;
            fullRecordingMissingGapCount(iFile) = ...
                fullGapSummary.missingGapCount;
            fullRecordingLongestMissingGapMilliseconds(iFile) = ...
                fullGapSummary.longestMissingGapMilliseconds;

            if ~isfinite(sampleRate(iFile)) || sampleRate(iFile) <= 0
                loadStatus(iFile) = "missing frame rate";
            elseif isfinite(declaredFrames(iFile)) && ...
                    declaredFrames(iFile) ~= numberFrames(iFile)
                loadStatus(iFile) = "frame count mismatch";
            else
                loadStatus(iFile) = "ok";
                durationSeconds(iFile) = ...
                    numberFrames(iFile)/sampleRate(iFile);
                try
                    rawLabels = readQtmMarkerLabels(loaded, ...
                        markerCount(iFile));
                    rawCoordinates = reshape(permute( ...
                        trajectory(:,1:3,:),[2 1 3]), ...
                        3*markerCount(iFile),numberFrames(iFile));
                    [~,~,markerPolicy] = ...
                        EmpaticMirroring_ApplyMarkerPolicy( ...
                        rawCoordinates,rawLabels,sampleRate(iFile),config);
                    retainedMarkerCount(iFile) = ...
                        numel(markerPolicy.labels);
                    unresolvedMarkerCount(iFile) = ...
                        numel(markerPolicy.unresolvedMarkerLabels);
                    unresolvedMarkers(iFile) = strjoin( ...
                        markerPolicy.unresolvedMarkerLabels,', ');
                catch markerException
                    markerPolicyStatus(iFile) = ...
                        "policy error: " + string(markerException.message);
                end
            end
        end
    catch exception
        loadStatus(iFile) = "load error";
        errorMessage(iFile) = string(exception.message);
    end

    if role(iFile) == "teacher" && approximatelyEqual( ...
            sampleRate(iFile),config.sampling.teacherHz)
        offsetSeconds = config.timing.teacherOffsetSeconds;
    elseif role(iFile) == "participant" && approximatelyEqual( ...
            sampleRate(iFile),config.sampling.participantHz)
        offsetSeconds = config.timing.participantOffsetSeconds;
    else
        offsetSeconds = NaN;
    end

    if loadStatus(iFile) == "ok" && isfinite(offsetSeconds)
        requiredFrames(iFile) = round((offsetSeconds + ...
            config.timing.analysisDurationSeconds)*sampleRate(iFile));
        preferredFrames(iFile) = round((offsetSeconds + ...
            config.timing.analysisDurationSeconds + ...
            config.timing.filterPaddingSeconds)*sampleRate(iFile));

        if numberFrames(iFile) < requiredFrames(iFile)
            lengthStatus(iFile) = "too short";
        elseif numberFrames(iFile) < preferredFrames(iFile)
            lengthStatus(iFile) = "usable without preferred guard";
        else
            lengthStatus(iFile) = "ok";
        end

        if numberFrames(iFile) >= requiredFrames(iFile)
            analysisStart = 1 + round(offsetSeconds*sampleRate(iFile));
            analysisEnd = analysisStart + round( ...
                config.timing.analysisDurationSeconds*sampleRate(iFile))-1;
            analysisGapSummary = summarizeMissingCoordinates( ...
                trajectory(:,:,analysisStart:analysisEnd), ...
                sampleRate(iFile));
            hasMissingCoordinates(iFile) = ...
                analysisGapSummary.hasMissingCoordinates;
            missingMarkerSamples(iFile) = ...
                analysisGapSummary.missingMarkerSamples;
            badTimepointCount(iFile) = ...
                analysisGapSummary.badTimepointCount;
            missingGapCount(iFile) = analysisGapSummary.missingGapCount;
            longestMissingGapFrames(iFile) = ...
                analysisGapSummary.longestMissingGapFrames;
            longestMissingGapMilliseconds(iFile) = ...
                analysisGapSummary.longestMissingGapMilliseconds;
            affectedMarkerCount(iFile) = ...
                analysisGapSummary.affectedMarkerCount;
            if ~isempty(markerPolicy)
                retainedWindow = analysisStart:analysisEnd;
                retainedMissing = markerPolicy.originalMissingMask( ...
                    :,retainedWindow);
                retainedHasMissingCoordinates(iFile) = ...
                    any(retainedMissing,'all');
                retainedMissingMarkerSamples(iFile) = ...
                    nnz(retainedMissing);
                retainedBadTimepointCount(iFile) = ...
                    nnz(any(retainedMissing,1));
                interpolatedMarkerSamples(iFile) = nnz( ...
                    markerPolicy.interpolatedMask(:,retainedWindow));
                reconstructedMarkerSamples(iFile) = nnz( ...
                    markerPolicy.reconstructedMask(:,retainedWindow));
                filledMarkerSamples(iFile) = nnz( ...
                    markerPolicy.filledMask(:,retainedWindow));
                completeTimepointFraction(iFile) = mean( ...
                    ~any(retainedMissing,1));
                unresolvedInWindow = markerPolicy.unresolvedMask( ...
                    :,retainedWindow);
                unresolvedMarkerCount(iFile) = nnz( ...
                    any(unresolvedInWindow,2));
                unresolvedMarkers(iFile) = strjoin( ...
                    markerPolicy.labels(any(unresolvedInWindow,2)),', ');
                validAfterShortInterpolation = ~any(retainedMissing,1);
                longestValidRunSeconds(iFile) = longestTrueRun( ...
                    validAfterShortInterpolation)/sampleRate(iFile);
                minimumRunSeconds = 3/min(config.block1.frex(:));
                meetsThreeCycleRunAtLowestFrequency(iFile) = ...
                    longestValidRunSeconds(iFile) >= minimumRunSeconds;
                if any(unresolvedInWindow,'all')
                    markerPolicyStatus(iFile) = ...
                        "gap beyond reconstruction limit";
                elseif completeTimepointFraction(iFile) < ...
                        config.preprocessing.minimumCompleteTimepointFraction
                    markerPolicyStatus(iFile) = ...
                        "insufficient all-marker coverage";
                else
                    markerPolicyStatus(iFile) = "ok";
                end
            end
        end
    elseif loadStatus(iFile) == "ok"
        lengthStatus(iFile) = "unknown sample rate";
    else
        lengthStatus(iFile) = "not assessed";
    end

    if loadStatus(iFile) ~= "ok"
        overallStatus(iFile) = loadStatus(iFile);
    elseif folderStatus(iFile) ~= "ok"
        overallStatus(iFile) = folderStatus(iFile);
    elseif role(iFile) == "unknown"
        overallStatus(iFile) = "invalid subject folder";
    elseif nameStatus(iFile) ~= "ok"
        overallStatus(iFile) = nameStatus(iFile);
    elseif markerStatus(iFile) ~= "ok"
        overallStatus(iFile) = "invalid marker layout";
    elseif strlength(markerPolicyStatus(iFile)) > 0 && ...
            markerPolicyStatus(iFile) ~= "ok"
        overallStatus(iFile) = markerPolicyStatus(iFile);
    elseif ~isfinite(offsetSeconds)
        overallStatus(iFile) = "unexpected sample rate for role";
    elseif lengthStatus(iFile) == "too short"
        overallStatus(iFile) = lengthStatus(iFile);
    elseif retainedBadTimepointCount(iFile) >= requiredFrames(iFile)-1
        overallStatus(iFile) = "insufficient valid samples";
    elseif retainedHasMissingCoordinates(iFile)
        overallStatus(iFile) = "usable after marker reconstruction";
    else
        overallStatus(iFile) = lengthStatus(iFile);
    end

    exclusionReasons(iFile) = buildExclusionReasons( ...
        loadStatus(iFile),folderStatus(iFile),nameStatus(iFile), ...
        note(iFile),role(iFile),sampleRate(iFile),lengthStatus(iFile), ...
        markerStatus(iFile),markerPolicyStatus(iFile), ...
        unresolvedMarkers(iFile),retainedBadTimepointCount(iFile), ...
        requiredFrames(iFile),config);
    excludeRecording(iFile) = strlength(exclusionReasons(iFile)) > 0;
    readyForAlignment(iFile) = ~excludeRecording(iFile);

    if mod(iFile,100) == 0 || iFile == nFiles
        fprintf('  inspected %d/%d files\n',iFile,nFiles);
    end
end

frameQC = table(filePaths,relativePath,subject,role,folderStatus, ...
    trialIndex,instruction, ...
    complexity,version,movement,note,pairingKey,matrixPath,matrixSize, ...
    markerCount,markerStatus,retainedMarkerCount,markerPolicyStatus, ...
    retainedHasMissingCoordinates,retainedMissingMarkerSamples, ...
    retainedBadTimepointCount,interpolatedMarkerSamples, ...
    reconstructedMarkerSamples,filledMarkerSamples, ...
    completeTimepointFraction, ...
    unresolvedMarkerCount,unresolvedMarkers,longestValidRunSeconds, ...
    meetsThreeCycleRunAtLowestFrequency, ...
    numberFrames,declaredFrames,sampleRate,durationSeconds,requiredFrames, ...
    preferredFrames,hasMissingCoordinates,missingMarkerSamples, ...
    badTimepointCount, ...
    missingGapCount,longestMissingGapFrames, ...
    longestMissingGapMilliseconds,affectedMarkerCount, ...
    fullRecordingHasMissingCoordinates,fullRecordingMissingMarkerSamples, ...
    fullRecordingMissingGapCount, ...
    fullRecordingLongestMissingGapMilliseconds, ...
    loadStatus,nameStatus,lengthStatus,overallStatus, ...
    excludeRecording,exclusionReasons,readyForAlignment,errorMessage, ...
    'VariableNames',{'File','RelativePath','Subject','Role','FolderStatus', ...
    'TrialIndex', ...
    'Instruction','Complexity','Version','Movement','Note','PairingKey', ...
    'MatrixPath','MatrixSize','MarkerCount','MarkerStatus', ...
    'RetainedMarkerCount','MarkerPolicyStatus', ...
    'RetainedHasMissingCoordinates','RetainedMissingMarkerSamples', ...
    'RetainedBadTimepointCount','InterpolatedMarkerSamples', ...
    'ReconstructedMarkerSamples','FilledMarkerSamples', ...
    'CompleteTimepointFraction', ...
    'UnresolvedMarkerCount','UnresolvedMarkers', ...
    'LongestValidRunSeconds','MeetsThreeCycleRunAtLowestFrequency', ...
    'NumberFrames','DeclaredFrames', ...
    'SampleRate','DurationSeconds','RequiredFrames','PreferredFrames', ...
    'HasMissingCoordinates','MissingMarkerSamples','BadTimepointCount', ...
    'MissingGapCount', ...
    'LongestMissingGapFrames','LongestMissingGapMilliseconds', ...
    'AffectedMarkerCount', ...
    'FullRecordingHasMissingCoordinates', ...
    'FullRecordingMissingMarkerSamples','FullRecordingMissingGapCount', ...
    'FullRecordingLongestMissingGapMilliseconds', ...
    'LoadStatus','NameStatus','LengthStatus','OverallStatus', ...
    'ExcludeRecording','ExclusionReasons','ReadyForAlignment', ...
    'ErrorMessage'});

if ~isfolder(outputRoot)
    mkdir(outputRoot);
end
writetable(frameQC,fullfile(outputRoot,'frame_count_qc.csv'));

figureHandle = plotFrameDistributions(frameQC,config);
exportgraphics(figureHandle, ...
    fullfile(outputRoot,'frame_count_histograms.png'),'Resolution',200);
savefig(figureHandle,fullfile(outputRoot,'frame_count_histograms.fig'));

fprintf('Frame-count QC complete: %d ready, %d too short, %d other issues.\n', ...
    nnz(frameQC.ReadyForAlignment), ...
    nnz(frameQC.LengthStatus == "too short"), ...
    nnz(~frameQC.ReadyForAlignment & ...
        frameQC.LengthStatus ~= "too short"));

participantAssessed = frameQC.Role == "participant" & ...
    isfinite(frameQC.RetainedMissingMarkerSamples);
teacherAssessed = frameQC.Role == "teacher" & ...
    isfinite(frameQC.RetainedMissingMarkerSamples);
fprintf(['Remaining-gap QC: %d/%d assessed participant files and ' ...
    '%d/%d assessed model files contain gaps.\n'], ...
    nnz(participantAssessed & frameQC.RetainedHasMissingCoordinates), ...
    nnz(participantAssessed), ...
    nnz(teacherAssessed & frameQC.RetainedHasMissingCoordinates), ...
    nnz(teacherAssessed));

end


function reasons = buildExclusionReasons(loadStatus,folderStatus, ...
    nameStatus,note,role,sampleRate,lengthStatus,markerStatus, ...
    markerPolicyStatus,unresolvedMarkers,badTimepointCount,requiredFrames, ...
    config)

parts = strings(0,1);
if loadStatus ~= "ok"
    parts(end+1,1) = "load/structure: " + loadStatus;
end
if folderStatus ~= "ok"
    parts(end+1,1) = "folder: " + folderStatus;
end
if nameStatus ~= "ok"
    if nameStatus == "annotated filename" && strlength(strtrim(note)) > 0
        parts(end+1,1) = "filename annotation: " + strtrim(note);
    else
        parts(end+1,1) = "filename: " + nameStatus;
    end
end
if markerStatus ~= "ok" && strlength(markerStatus) > 0
    parts(end+1,1) = "marker layout: " + markerStatus;
end
if markerPolicyStatus ~= "ok" && strlength(markerPolicyStatus) > 0
    reason = "marker policy: " + markerPolicyStatus;
    if strlength(unresolvedMarkers) > 0
        reason = reason + " (" + unresolvedMarkers + ")";
    end
    parts(end+1,1) = reason;
end
if role == "unknown"
    parts(end+1,1) = "role: unrecognized data location";
elseif loadStatus == "ok"
    if role == "participant"
        expectedRate = config.sampling.participantHz;
    else
        expectedRate = config.sampling.teacherHz;
    end
    if ~approximatelyEqual(sampleRate,expectedRate)
        parts(end+1,1) = "sample rate: expected " + expectedRate + ...
            " Hz, found " + sampleRate + " Hz";
    end
end
if lengthStatus == "too short"
    parts(end+1,1) = "length: too short for configured 33 s window";
end
if isfinite(badTimepointCount) && isfinite(requiredFrames) && ...
        badTimepointCount >= requiredFrames-1
    parts(end+1,1) = ...
        "missing data: fewer than two valid covariance samples";
end
reasons = strjoin(unique(parts,'stable'),"; ");

end


function longest = longestTrueRun(mask)

transitions = diff([false logical(mask(:)') false]);
runStarts = find(transitions == 1);
runEnds = find(transitions == -1)-1;
if isempty(runStarts)
    longest = 0;
else
    longest = max(runEnds-runStarts+1);
end

end


function token = parseRecordingName(stem)

expression = ['^(?<trial>\d+)_(?<instruction>obs|mir)_' ...
    '(?<complexity>low|medium|high)_(?:v)?(?<version>\d+)_' ...
    '(?:mov)?(?<movement>[12])(?<note>.*)$'];
token = regexpi(char(stem),expression,'names','once');

end


function [role,subject,status] = parseRecordingFolders( ...
    subjectFolderName,matFolder,config)

subjectFolderName = string(subjectFolderName);
[~,matFolderName] = fileparts(matFolder);
matFolderName = string(matFolderName);

if strcmpi(subjectFolderName,config.naming.teacherFolder)
    role = "teacher";
    subject = string(config.naming.teacherFolder);
    expectedMatFolder = "data_" + string(config.naming.teacherFolder) + "_mat";
    if matFolderName == expectedMatFolder
        status = "ok";
    else
        status = "invalid teacher data folder";
    end
    return
end

leadingSubject = regexp(char(subjectFolderName),'^\d{3}','match','once');
if isempty(leadingSubject)
    directSubject = regexp(char(matFolderName),'^\d{3}$','match','once');
    if ~isempty(directSubject)
        role = "participant";
        subject = string(directSubject);
        status = "missing participant *_mat subfolder";
        return
    end
    role = "unknown";
    subject = "";
    status = "invalid subject folder";
    return
end

role = "participant";
subject = string(leadingSubject);
if subjectFolderName ~= subject
    status = "annotated subject folder";
    return
end

expectedMatFolder = string(str2double(subject)) + "_mat";
if matFolderName ~= expectedMatFolder
    status = "invalid participant data folder";
else
    status = "ok";
end

end


function [paths,sizes,matrices] = findNumeric3DMatrices(value,currentPath)

paths = strings(0,1);
sizes = zeros(0,3);
matrices = cell(0,1);

if isnumeric(value)
    if ndims(value) == 3 && size(value,3) > 1
        paths(end+1,1) = currentPath;
        sizes(end+1,:) = size(value);
        matrices{end+1,1} = value;
    end
    return
end

if ~isstruct(value)
    return
end

fields = fieldnames(value);
for elementIndex = 1:numel(value)
    for fieldIndex = 1:numel(fields)
        fieldName = fields{fieldIndex};
        if strlength(currentPath) == 0
            nextPath = string(fieldName);
        else
            nextPath = currentPath + "." + fieldName;
        end
        if numel(value) > 1
            nextPath = nextPath + "(" + elementIndex + ")";
        end
        [childPaths,childSizes,childMatrices] = findNumeric3DMatrices( ...
            value(elementIndex).(fieldName),nextPath);
        paths = [paths; childPaths]; %#ok<AGROW>
        sizes = [sizes; childSizes]; %#ok<AGROW>
        matrices = [matrices; childMatrices]; %#ok<AGROW>
    end
end

end


function summary = summarizeMissingCoordinates(trajectory,sampleRate)

if size(trajectory,2) < 3
    summary = struct( ...
        'hasMissingCoordinates',true, ...
        'missingMarkerSamples',NaN, ...
        'badTimepointCount',NaN, ...
        'missingGapCount',NaN, ...
        'longestMissingGapFrames',NaN, ...
        'longestMissingGapMilliseconds',NaN, ...
        'affectedMarkerCount',NaN);
    return
end

coordinateData = trajectory(:,1:3,:);
missing = squeeze(any(~isfinite(coordinateData),2));
if isvector(missing)
    missing = reshape(missing,size(trajectory,1),size(trajectory,3));
end

gapCount = 0;
longestGap = 0;
for markerIndex = 1:size(missing,1)
    transitions = diff([false missing(markerIndex,:) false]);
    gapStarts = find(transitions == 1);
    gapEnds = find(transitions == -1)-1;
    gapLengths = gapEnds-gapStarts+1;
    gapCount = gapCount + numel(gapLengths);
    if ~isempty(gapLengths)
        longestGap = max(longestGap,max(gapLengths));
    end
end

if isfinite(sampleRate) && sampleRate > 0
    longestGapMilliseconds = 1000*longestGap/sampleRate;
else
    longestGapMilliseconds = NaN;
end

summary = struct( ...
    'hasMissingCoordinates',any(missing,'all'), ...
    'missingMarkerSamples',nnz(missing), ...
    'badTimepointCount',nnz(any(missing,1)), ...
    'missingGapCount',gapCount, ...
    'longestMissingGapFrames',longestGap, ...
    'longestMissingGapMilliseconds',longestGapMilliseconds, ...
    'affectedMarkerCount',nnz(any(missing,2)));

end


function labels = readQtmMarkerLabels(loaded,expectedCount)

names = fieldnames(loaded);
if numel(names) ~= 1
    error('EmpaticMirroring:QCMarkerLabels', ...
        'A unique QTM structure is required to read marker labels.');
end
qtm = loaded.(names{1});
if ~isstruct(qtm) || ~isscalar(qtm) || ...
        ~isfield(qtm,'Trajectories') || ...
        ~isfield(qtm.Trajectories,'Labeled') || ...
        ~isfield(qtm.Trajectories.Labeled,'Labels') || ...
        numel(qtm.Trajectories.Labeled.Labels) ~= expectedCount
    error('EmpaticMirroring:QCMarkerLabels', ...
        'QTM marker labels are absent or do not match the trajectory.');
end
labels = string(qtm.Trajectories.Labeled.Labels(:));

end


function [frameRate,declaredFrames] = readQtmMetadata(loaded)

frameRate = NaN;
declaredFrames = NaN;
names = fieldnames(loaded);
if numel(names) ~= 1
    return
end

qtm = loaded.(names{1});
if ~isstruct(qtm) || ~isscalar(qtm)
    return
end
if isfield(qtm,'FrameRate') && isnumeric(qtm.FrameRate) && ...
        isscalar(qtm.FrameRate)
    frameRate = double(qtm.FrameRate);
end
if isfield(qtm,'Frames') && isnumeric(qtm.Frames) && ...
        isscalar(qtm.Frames)
    declaredFrames = double(qtm.Frames);
end

end


function tf = approximatelyEqual(left,right)

tf = isfinite(left) && abs(left-right) <= max(1e-9,eps(right)*10);

end


function figureHandle = plotFrameDistributions(frameQC,config)

figureHandle = figure('Color','w', ...
    'Name','Empatic mirroring frame-count QC', ...
    'Visible',char(config.output.figureVisible));
layout = tiledlayout(figureHandle,2,2,'TileSpacing','compact', ...
    'Padding','compact');
title(layout,'Raw recording frame-count distributions');

valid = isfinite(frameQC.NumberFrames);
axisAll = nexttile(layout,[1 2]);
if any(valid)
    nBins = max(10,min(80,ceil(sqrt(nnz(valid)))));
    histogram(axisAll,frameQC.NumberFrames(valid),nBins);
else
    text(axisAll,0.5,0.5,'No valid frame counts', ...
        'HorizontalAlignment','center');
end
xlabel(axisAll,'Number of frames');
ylabel(axisAll,'Number of files');
title(axisAll,'All MAT files');
grid(axisAll,'on');

participantMask = valid & frameQC.Role == "participant";
axisParticipant = nexttile(layout);
if any(participantMask)
    histogram(axisParticipant,frameQC.NumberFrames(participantMask), ...
        'BinWidth',config.sampling.participantHz/4);
    hold(axisParticipant,'on');
    participantRequired = round(( ...
        config.timing.participantOffsetSeconds + ...
        config.timing.analysisDurationSeconds) * ...
        config.sampling.participantHz);
    participantPreferred = round(( ...
        config.timing.participantOffsetSeconds + ...
        config.timing.analysisDurationSeconds + ...
        config.timing.filterPaddingSeconds) * ...
        config.sampling.participantHz);
    xline(axisParticipant,participantRequired,'r--', ...
        sprintf('required: %d',participantRequired));
    xline(axisParticipant,participantPreferred,'m:', ...
        sprintf('preferred: %d',participantPreferred));
    focusDistribution(axisParticipant, ...
        frameQC.NumberFrames(participantMask),participantPreferred);
else
    text(axisParticipant,0.5,0.5,'No participant files', ...
        'HorizontalAlignment','center');
end
xlabel(axisParticipant,'Number of frames');
ylabel(axisParticipant,'Number of files');
title(axisParticipant,'Participants (120 Hz)');
grid(axisParticipant,'on');

teacherMask = valid & frameQC.Role == "teacher";
axisTeacher = nexttile(layout);
if any(teacherMask)
    histogram(axisTeacher,frameQC.NumberFrames(teacherMask), ...
        'BinWidth',config.sampling.teacherHz/2);
    hold(axisTeacher,'on');
    teacherRequired = round((config.timing.teacherOffsetSeconds + ...
        config.timing.analysisDurationSeconds) * ...
        config.sampling.teacherHz);
    teacherPreferred = round((config.timing.teacherOffsetSeconds + ...
        config.timing.analysisDurationSeconds + ...
        config.timing.filterPaddingSeconds) * ...
        config.sampling.teacherHz);
    xline(axisTeacher,teacherRequired,'r--', ...
        sprintf('required: %d',teacherRequired));
    xline(axisTeacher,teacherPreferred,'m:', ...
        sprintf('preferred: %d',teacherPreferred));
else
    text(axisTeacher,0.5,0.5,'No teacher files', ...
        'HorizontalAlignment','center');
end
xlabel(axisTeacher,'Number of frames');
ylabel(axisTeacher,'Number of files');
title(axisTeacher,'Teacher (300 Hz)');
grid(axisTeacher,'on');

end


function focusDistribution(axisHandle,values,requiredUpperBound)

values = sort(values(:));
nValues = numel(values);
lowerIndex = max(1,round(0.01*nValues));
upperIndex = min(nValues,round(0.99*nValues));
lower = values(lowerIndex);
upper = values(upperIndex);
margin = max(1,0.05*(upper-lower));
limits = [max(0,lower-margin) max(requiredUpperBound,upper+margin)];
xlim(axisHandle,limits);

nClipped = nnz(values < limits(1) | values > limits(2));
if nClipped > 0
    text(axisHandle,0.98,0.92, ...
        sprintf('%d extreme files outside view',nClipped), ...
        'Units','normalized','HorizontalAlignment','right', ...
        'VerticalAlignment','top');
end

end
