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
matrixPath = strings(nFiles,1);
matrixSize = strings(nFiles,1);
numberFrames = nan(nFiles,1);
declaredFrames = nan(nFiles,1);
sampleRate = nan(nFiles,1);
durationSeconds = nan(nFiles,1);
trialIndex = nan(nFiles,1);
condition = strings(nFiles,1);
intensity = strings(nFiles,1);
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

dataRootPrefix = string(dataRoot) + filesep;

fprintf('\nInspecting frame counts in %d MAT files...\n',nFiles);

for iFile = 1:nFiles
    relativePath(iFile) = erase(filePaths(iFile),dataRootPrefix);
    [matFolder,stem] = fileparts(filePaths(iFile));
    [subjectFolder,~] = fileparts(matFolder);
    [~,subjectName] = fileparts(subjectFolder);
    subject(iFile) = string(subjectName);

    token = parseRecordingName(stem);
    if isempty(token)
        nameStatus(iFile) = "invalid filename";
    else
        trialIndex(iFile) = str2double(token.trial);
        condition(iFile) = lower(string(token.condition));
        intensity(iFile) = lower(string(token.intensity));
        version(iFile) = str2double(token.version);
        movement(iFile) = str2double(token.movement);
        note(iFile) = string(token.note);
        pairingKey(iFile) = intensity(iFile) + "_v" + ...
            version(iFile) + "_mov" + movement(iFile);
        nameStatus(iFile) = "ok";
    end

    try
        loaded = load(char(filePaths(iFile)));
        [candidatePaths,candidateSizes] = findNumeric3DMatrices(loaded,"");

        if isempty(candidatePaths)
            loadStatus(iFile) = "no numeric 3-D matrix";
        elseif numel(candidatePaths) > 1
            loadStatus(iFile) = "multiple numeric 3-D matrices";
            matrixPath(iFile) = strjoin(candidatePaths,"; ");
        else
            matrixPath(iFile) = candidatePaths(1);
            thisSize = candidateSizes(1,:);
            matrixSize(iFile) = sprintf('%dx%dx%d',thisSize);
            numberFrames(iFile) = thisSize(3);

            [sampleRate(iFile),declaredFrames(iFile)] = ...
                readQtmMetadata(loaded);

            if ~isfinite(sampleRate(iFile)) || sampleRate(iFile) <= 0
                loadStatus(iFile) = "missing frame rate";
            elseif isfinite(declaredFrames(iFile)) && ...
                    declaredFrames(iFile) ~= numberFrames(iFile)
                loadStatus(iFile) = "frame count mismatch";
            else
                loadStatus(iFile) = "ok";
                durationSeconds(iFile) = ...
                    numberFrames(iFile)/sampleRate(iFile);
            end
        end
    catch exception
        loadStatus(iFile) = "load error";
        errorMessage(iFile) = string(exception.message);
    end

    if approximatelyEqual(sampleRate(iFile),config.sampling.teacherHz)
        role(iFile) = "teacher";
        subject(iFile) = config.naming.teacherFolder;
        offsetSeconds = config.timing.teacherOffsetSeconds;
    elseif approximatelyEqual( ...
            sampleRate(iFile),config.sampling.participantHz)
        role(iFile) = "participant";
        offsetSeconds = config.timing.participantOffsetSeconds;
    else
        role(iFile) = "unknown";
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
    elseif loadStatus(iFile) == "ok"
        lengthStatus(iFile) = "unknown sample rate";
    else
        lengthStatus(iFile) = "not assessed";
    end

    if loadStatus(iFile) ~= "ok"
        overallStatus(iFile) = loadStatus(iFile);
    elseif role(iFile) == "unknown"
        overallStatus(iFile) = "unsupported sample rate";
    elseif nameStatus(iFile) ~= "ok"
        overallStatus(iFile) = nameStatus(iFile);
    else
        overallStatus(iFile) = lengthStatus(iFile);
    end

    readyForAlignment(iFile) = loadStatus(iFile) == "ok" && ...
        nameStatus(iFile) == "ok" && role(iFile) ~= "unknown" && ...
        numberFrames(iFile) >= requiredFrames(iFile);

    if mod(iFile,100) == 0 || iFile == nFiles
        fprintf('  inspected %d/%d files\n',iFile,nFiles);
    end
end

frameQC = table(filePaths,relativePath,subject,role,trialIndex,condition, ...
    intensity,version,movement,note,pairingKey,matrixPath,matrixSize, ...
    numberFrames,declaredFrames,sampleRate,durationSeconds,requiredFrames, ...
    preferredFrames,loadStatus,nameStatus,lengthStatus,overallStatus, ...
    readyForAlignment,errorMessage, ...
    'VariableNames',{'File','RelativePath','Subject','Role','TrialIndex', ...
    'Condition','Intensity','Version','Movement','Note','PairingKey', ...
    'MatrixPath','MatrixSize','NumberFrames','DeclaredFrames', ...
    'SampleRate','DurationSeconds','RequiredFrames','PreferredFrames', ...
    'LoadStatus','NameStatus','LengthStatus','OverallStatus', ...
    'ReadyForAlignment','ErrorMessage'});

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

end


function token = parseRecordingName(stem)

expression = ['^(?<trial>\d+)_(?<condition>obs|mir)_' ...
    '(?<intensity>low|medium|high)_(?:v)?(?<version>\d+)_' ...
    '(?:mov)?(?<movement>\d+)(?<note>.*)$'];
token = regexpi(char(stem),expression,'names','once');

end


function [paths,sizes] = findNumeric3DMatrices(value,currentPath)

paths = strings(0,1);
sizes = zeros(0,3);

if isnumeric(value)
    if ndims(value) == 3 && size(value,3) > 1
        paths(end+1,1) = currentPath;
        sizes(end+1,:) = size(value);
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
        [childPaths,childSizes] = findNumeric3DMatrices( ...
            value(elementIndex).(fieldName),nextPath);
        paths = [paths; childPaths]; %#ok<AGROW>
        sizes = [sizes; childSizes]; %#ok<AGROW>
    end
end

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
