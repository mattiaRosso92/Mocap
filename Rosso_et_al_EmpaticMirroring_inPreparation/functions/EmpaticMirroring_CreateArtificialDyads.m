function [dyadManifest,summary] = EmpaticMirroring_CreateArtificialDyads( ...
    dyadManifest,config,frameQC)
%EMPATICMIRRORING_CREATEARTIFICIALDYADS Build FREQ-NESS-ready dyad files.
%   Each markData array follows the DyadicDance template:
%   [XYZ marker coordinates x time x participants], where participant 1 is
%   the model and participant 2 is the experimental participant. The shared
%   bad_segments vector is the synchronized union of participant-specific
%   bad samples and is suitable for covariance exclusion.

modelOutputRoot = config.paths.modelOutputRoot;
if ~isfolder(modelOutputRoot)
    mkdir(modelOutputRoot);
end

nRows = height(dyadManifest);
dyadFile = strings(nRows,1);
dyadStatus = repmat("not eligible",nRows,1);
modelBadSampleCount = nan(nRows,1);
participantBadSampleCount = nan(nRows,1);
sharedBadSampleCount = nan(nRows,1);
sharedBadSamplePercent = nan(nRows,1);
goodSampleCount = nan(nRows,1);
errorMessage = strings(nRows,1);

eligibleRows = find(dyadManifest.PairingStatus == "matched" & ...
    dyadManifest.ReadyForAlignment);
fprintf('\nCreating %d artificial dyads in FREQ-NESS format...\n', ...
    numel(eligibleRows));

% Prepare every condition-labelled model recording exactly once. The same
% aligned 120 Hz data and post-resampling bad-sample mask are then reused in
% every participant pairing that references that model file.
if nargin >= 3 && ~isempty(frameQC)
    teacherFiles = unique(frameQC.File(frameQC.Role == "teacher" & ...
        frameQC.ReadyForAlignment),'stable');
else
    teacherFiles = unique(dyadManifest.TeacherFile(eligibleRows),'stable');
end
teacherCache = containers.Map('KeyType','char','ValueType','any');
for teacherIndex = 1:numel(teacherFiles)
    teacherFile = teacherFiles(teacherIndex);
    teacher = EmpaticMirroring_LoadRecording(teacherFile);
    [~,teacherPrepared] = EmpaticMirroring_AlignArtificialDyad( ...
        teacher,[],config);
    teacherCache(char(teacherFile)) = teacherPrepared;
    savePreparedModel(teacherPrepared,modelOutputRoot,config);
end
fprintf('Prepared %d model recordings once for reuse.\n', ...
    numel(teacherFiles));

for eligibleIndex = 1:numel(eligibleRows)
    rowIndex = eligibleRows(eligibleIndex);
    participantOutputRoot = EmpaticMirroring_ParticipantResultsFolder( ...
        dyadManifest.ParticipantFile(rowIndex),config);
    if ~isfolder(participantOutputRoot)
        mkdir(participantOutputRoot);
    end
    outputFile = fullfile(participantOutputRoot,dyadFileName( ...
        dyadManifest(rowIndex,:)));
    dyadFile(rowIndex) = string(outputFile);

    try
        if isfile(outputFile) && ~config.dyads.overwrite
            saved = load(outputFile,'bad_segments', ...
                'bad_segments_by_participant','srate','markData');
            validateSavedDyad(saved,config);
            dyadStatus(rowIndex) = "existing";
        else
            participant = EmpaticMirroring_LoadRecording( ...
                dyadManifest.ParticipantFile(rowIndex));
            teacherPrepared = teacherCache(char( ...
                dyadManifest.TeacherFile(rowIndex)));
            dyad = EmpaticMirroring_AlignArtificialDyad( ...
                [],participant,config,teacherPrepared);

            markData = cast(dyad.data,char(config.dyads.storageClass));
            srate = dyad.sampleRate;
            marklabels = cellstr(dyad.labels(:)');
            xyz_marklabels = expandXyzLabels(marklabels);
            nsubs = size(markData,3);
            sublabels = cellstr("_" + upper(dyad.participantOrder));
            bad_segments = double(dyad.badSegments(:)');
            bad_segments_by_participant = cellfun( ...
                @(indices) double(indices(:)'), ...
                dyad.badSegmentsByParticipant,'UniformOutput',false);
            bad_sample_mask = dyad.badSampleMask;
            marker_reference = markData(:,1,:);
            dyad_info = buildDyadInfo(dyadManifest(rowIndex,:),dyad);

            if config.dyads.save
                save(outputFile,'markData','srate','marklabels', ...
                    'xyz_marklabels','nsubs','sublabels','bad_segments', ...
                    'bad_segments_by_participant','bad_sample_mask', ...
                    'marker_reference','dyad_info','-v7.3');
            end
            saved = struct( ...
                'bad_segments',bad_segments, ...
                'bad_segments_by_participant', ...
                {bad_segments_by_participant}, ...
                'srate',srate,'markData',markData);
            validateSavedDyad(saved,config);
            dyadStatus(rowIndex) = "created";
        end

        modelBadSampleCount(rowIndex) = numel( ...
            saved.bad_segments_by_participant{1});
        participantBadSampleCount(rowIndex) = numel( ...
            saved.bad_segments_by_participant{2});
        sharedBadSampleCount(rowIndex) = numel(saved.bad_segments);
        nSamples = size(saved.markData,2);
        sharedBadSamplePercent(rowIndex) = ...
            100*sharedBadSampleCount(rowIndex)/nSamples;
        goodSampleCount(rowIndex) = nSamples-sharedBadSampleCount(rowIndex);
    catch exception
        dyadStatus(rowIndex) = "error";
        errorMessage(rowIndex) = string(exception.message);
        warning('EmpaticMirroring:DyadCreationFailed', ...
            'Could not create dyad row %d: %s',rowIndex,exception.message);
    end

    if mod(eligibleIndex,100) == 0 || eligibleIndex == numel(eligibleRows)
        fprintf('  processed %d/%d artificial dyads\n', ...
            eligibleIndex,numel(eligibleRows));
    end
end

dyadManifest.DyadFile = dyadFile;
dyadManifest.DyadStatus = dyadStatus;
dyadManifest.ModelBadSampleCount = modelBadSampleCount;
dyadManifest.ParticipantBadSampleCount = participantBadSampleCount;
dyadManifest.SharedBadSampleCount = sharedBadSampleCount;
dyadManifest.SharedBadSamplePercent = sharedBadSamplePercent;
dyadManifest.GoodSampleCount = goodSampleCount;
dyadManifest.DyadErrorMessage = errorMessage;
writetable(dyadManifest,fullfile(config.paths.qcOutputRoot, ...
    'artificial_dyad_manifest.csv'));

createdOrExisting = dyadStatus == "created" | dyadStatus == "existing";
summary = struct( ...
    'eligibleCount',numel(eligibleRows), ...
    'createdCount',nnz(dyadStatus == "created"), ...
    'existingCount',nnz(dyadStatus == "existing"), ...
    'errorCount',nnz(dyadStatus == "error"), ...
    'availableCount',nnz(createdOrExisting), ...
    'modelPreparedCount',numel(teacherFiles), ...
    'participantsOutputRoot', ...
    string(config.paths.participantsOutputRoot));

fprintf(['Artificial dyads available: %d (%d created, %d existing); ' ...
    '%d errors.\n'],summary.availableCount,summary.createdCount, ...
    summary.existingCount,summary.errorCount);

end


function savePreparedModel(prepared,outputRoot,config)

[~,stem] = fileparts(prepared.file);
outputFile = fullfile(outputRoot,char(string(stem) + "_processed.mat"));
if isfile(outputFile) && ~config.dyads.overwrite
    return
end

modelData = cast(prepared.data,char(config.dyads.storageClass));
srate = config.sampling.outputHz;
marklabels = cellstr(prepared.labels(:)');
xyz_marklabels = expandXyzLabels(marklabels);
bad_segments = double(find(prepared.badMask));
bad_sample_mask = prepared.badMask;
model_info = struct( ...
    'sourceFile',prepared.file, ...
    'alignment',prepared.alignment, ...
    'gapReport',prepared.gapReport, ...
    'processingPolicy', ...
    ['Imported and downsampled once from 300 Hz to 120 Hz; reused for ' ...
     'all artificial dyads linked to this condition-labelled model.']);

if config.dyads.save
    save(outputFile,'modelData','srate','marklabels','xyz_marklabels', ...
        'bad_segments','bad_sample_mask','model_info','-v7.3');
end

end


function name = dyadFileName(row)

name = sprintf('S%s_T%02d_%s_%s_v%d_mov%d.mat', ...
    char(row.Subject),row.TrialIndex,char(row.Instruction), ...
    char(row.Complexity),row.Version,row.Movement);

end


function xyzLabels = expandXyzLabels(markerLabels)

xyzLabels = cell(1,3*numel(markerLabels));
for markerIndex = 1:numel(markerLabels)
    xyzLabels{3*(markerIndex-1)+1} = ['X_' markerLabels{markerIndex}];
    xyzLabels{3*(markerIndex-1)+2} = ['Y_' markerLabels{markerIndex}];
    xyzLabels{3*(markerIndex-1)+3} = ['Z_' markerLabels{markerIndex}];
end

end


function info = buildDyadInfo(row,dyad)

info = struct( ...
    'subject',row.Subject, ...
    'trialIndex',row.TrialIndex, ...
    'instruction',row.Instruction, ...
    'complexity',row.Complexity, ...
    'version',row.Version, ...
    'movement',row.Movement, ...
    'pairingKey',row.PairingKey, ...
    'participantOrder',dyad.participantOrder, ...
    'teacherFile',dyad.teacherFile, ...
    'participantFile',dyad.participantFile, ...
    'teacherAlignment',dyad.teacherAlignment, ...
    'participantAlignment',dyad.participantAlignment, ...
    'teacherGapReport',dyad.teacherGapReport, ...
    'participantGapReport',dyad.participantGapReport, ...
    'badSegmentsPolicy', ...
    ['Synchronized union of model and participant bad samples; pass as ' ...
     '''bad_segments'' so both covariance matrices use identical times.']);

end


function validateSavedDyad(saved,config)

required = {'markData','srate','bad_segments', ...
    'bad_segments_by_participant'};
if ~all(isfield(saved,required))
    error('EmpaticMirroring:SavedDyadFields', ...
        'Saved artificial dyad lacks required FREQ-NESS input fields.');
end
expectedSamples = round(config.timing.analysisDurationSeconds * ...
    config.sampling.outputHz);
if ~isnumeric(saved.markData) || ndims(saved.markData) ~= 3 || ...
        size(saved.markData,2) ~= expectedSamples || ...
        size(saved.markData,3) ~= 2 || any(~isfinite(saved.markData),'all')
    error('EmpaticMirroring:SavedDyadShape', ...
        ['markData must be finite and arranged as ' ...
         '[coordinates x %d samples x 2 participants].'],expectedSamples);
end
if saved.srate ~= config.sampling.outputHz
    error('EmpaticMirroring:SavedDyadRate', ...
        'Artificial dyad has an unexpected sampling rate.');
end
if ~isnumeric(saved.bad_segments) || ~isvector(saved.bad_segments) || ...
        any(saved.bad_segments < 1) || ...
        any(saved.bad_segments > expectedSamples) || ...
        any(saved.bad_segments ~= round(saved.bad_segments))
    error('EmpaticMirroring:BadSegmentsFormat', ...
        'bad_segments must contain valid 1-based integer sample indices.');
end
if ~iscell(saved.bad_segments_by_participant) || ...
        numel(saved.bad_segments_by_participant) ~= 2
    error('EmpaticMirroring:ParticipantBadSegmentsFormat', ...
        'bad_segments_by_participant must contain one list per dyad member.');
end
if ~isequal(saved.bad_segments,unique(saved.bad_segments,'stable'))
    error('EmpaticMirroring:BadSegmentsOrder', ...
        'bad_segments must be unique and sorted in time.');
end

end
