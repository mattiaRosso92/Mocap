% Orchestra study: processed XY trajectories -> FREQ-NESS -> visualization.
% Each CSV is one ensemble observation; tracks are coordinate channels,
% not independent participants. Run BLOCK 0 before running later sections.
clear
close all
clc


%% BLOCK 0 - USER SETTINGS AND STARTUP

script_file = mfilename('fullpath');
if isempty(script_file)
    script_file = matlab.desktop.editor.getActiveFilename;
end
path_study = fileparts(script_file);
path_repo = fileparts(path_study);
path_toolbox = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');
assert(isfolder(path_toolbox),'MoCap toolbox not found: %s',path_toolbox);
addpath(path_toolbox)
addpath(genpath(fullfile(path_toolbox,'FREQNESS_Functions')))
addpath(genpath(fullfile(path_toolbox,'FREQNESS_ExternalFunctions')))

CFG = [];
CFG.common.data_path = fullfile(path_study,'concertproject_kiersten','data');
CFG.common.output_path = fullfile(path_study,'FREQNESS_Output');
CFG.common.pieces = ["carmen" "giant" "juliet" "siviglia" "strings"];
CFG.common.recordings = strings(0,1); % Empty = all; otherwise exact file stems.

% The user confirmed the 25 Hz sampling rate on 2026-11-28. This is user
% confirmation, not independent verification of camera metadata. The source
% audit's audio/frame scaling discrepancies remain a separate unresolved
% alignment issue; no resampling, time warping, or data repair is applied.
CFG.common.srate = 25;
CFG.common.srate_confirmed_flag = true;
CFG.common.srate_confirmation_source = "user";
CFG.common.srate_confirmation_date = "2026-11-28";
CFG.common.camera_metadata_verified_flag = false;
CFG.common.audio_alignment_status = "unresolved";
CFG.common.frex = .5:.1:10;
% Beat-relative estimation is a separate segment-only run. Disable Block 1,
% select segment_piece for Block 3, and pin an exported tempo catalog below.
CFG.common.frequency_reference = validatestring('hz',{'hz','beat'});
CFG.common.beat_ratios = (1:16)/8;
CFG.common.tempo_file = '';
CFG.common.minimum_cycles = 3; % Descriptive flag; never changes the grid.
CFG.common.ncomps = 4; % Spatial patterns/time series; all eigenvalues survive.
CFG.common.regularisation = .01;
CFG.common.method = 'ged';
CFG.common.kinematics = 'position';
% Run each calibration independently using otherwise identical settings.
% Both routes use the current toolbox and preserve earlier archived cores.
CFG.common.filter_width_calibration = validatestring( ...
    'physical',{'physical','legacy'});
CFG.common.filter_type = validatestring( ...
    'logarithmic',{'logarithmic','linear'});

CFG.block1.run_flag = true;
CFG.block1.overwrite_flag = false;
CFG.block2.run_flag = true;
CFG.block2.overwrite_flag = false;
CFG.block2.segment_labels = strings(0,1); % Empty = all manifest labels.

% Visualization runs separately from estimation and only needs saved cores.
% Enable after inspecting the core index CSVs. Empty selections mean all.
CFG.block3.run_flag = false;
CFG.block3.stages = ["full_piece" "segment_piece"];
CFG.block3.recordings = strings(0,1);
CFG.block3.segment_labels = strings(0,1);
% Component 1 only; H2 always uses the complete saved eigenspectrum.
% Patterns use the maximum observed component-1 bin (first bin for ties).
CFG.block3.color_first = [.85 .12 .15]; % First rehearsal / musical segment.
CFG.block3.color_last = [.35 .75 .94];  % Last rehearsal / musical segment.
CFG.block3.color_concert = [.50 .22 .70]; % Concerts follow all rehearsals.
CFG.block3.plot_matrix_flag = true;
% Provisional identities copied from the labelled Carmen demo in
% CoE_2026_Hackaton/data/64track-deeplabcut-carmen.csv. The user authorised
% applying its numeric IDs to all recordings, including 38/62/63-track sets.
% Peter Keller must check these assignments visually before interpretation.
CFG.block3.matrix_labels_flag = true;
CFG.block3.matrix_label_file = fullfile(path_study,'orchestra_provisional_labels.csv');
CFG.block3.save_flag = true;
CFG.block3.overwrite_flag = false;
CFG.block3.close_figures_flag = true;
CFG.block3.figure_visibility = 'off'; % 'on' and close_figures_flag=false to inspect.

% Validate shared scientific settings before constructing output routes.
validateattributes(CFG.common.srate,{'numeric'}, ...
    {'real','finite','scalar','positive'});
validateattributes(CFG.common.frex,{'numeric'}, ...
    {'real','finite','vector','nonempty','positive','increasing'});
assert(all(CFG.common.frex < CFG.common.srate/2), ...
    'CFG.common.frex must lie strictly below srate/2.');
validateattributes(CFG.common.ncomps,{'numeric'}, ...
    {'scalar','integer','positive'});
validateattributes(CFG.common.regularisation,{'numeric'}, ...
    {'real','finite','scalar','>=',0,'<',1});
validateattributes(CFG.common.srate_confirmed_flag,{'logical'},{'scalar'});
validateattributes(CFG.common.camera_metadata_verified_flag,{'logical'},{'scalar'});
assert(strcmp(CFG.common.method,'ged') && strcmp(CFG.common.kinematics,'position'), ...
    'The orchestra core comparison uses GED on supplied positions.');
if ~CFG.common.srate_confirmed_flag
    warning('Orchestra:UnconfirmedSamplingRate', ...
        ['Using the configured %g Hz analysis clock. Confirm it against ' ...
         'the processed-data timing before interpreting Hz or seconds.'], ...
        CFG.common.srate);
end

timing_provenance = struct( ...
    'srate_confirmation_source',CFG.common.srate_confirmation_source, ...
    'srate_confirmation_date',CFG.common.srate_confirmation_date, ...
    'camera_metadata_verified',CFG.common.camera_metadata_verified_flag, ...
    'audio_alignment_status',CFG.common.audio_alignment_status);

% A tempo belongs to an existing WAV segment, matched by its manifest key.
% This does not apply the newer score sections or resolve audio/frame clocks.
beat_reference_flag = strcmp(CFG.common.frequency_reference,'beat');
if beat_reference_flag
    assert(~CFG.block1.run_flag,'Orchestra:BeatFullPieceUnsupported', ...
        'Beat-relative analysis is segment-only: disable CFG.block1.run_flag.');
    assert(~CFG.block3.run_flag || ...
        all(string(CFG.block3.stages) == "segment_piece"), ...
        'Orchestra:BeatFullPieceUnsupported', ...
        'Beat-relative visualization requires CFG.block3.stages="segment_piece".');
    validateattributes(CFG.common.beat_ratios,{'numeric'}, ...
        {'real','finite','vector','nonempty','positive','increasing'});
    validateattributes(CFG.common.minimum_cycles,{'numeric'}, ...
        {'real','finite','scalar','positive'});
    assert(isfile(CFG.common.tempo_file),'Orchestra:TempoCatalogRequired', ...
        'Set CFG.common.tempo_file to a reviewed tempo_catalog.json before beat-relative analysis.');
    tempo_file_id = fopen(CFG.common.tempo_file,'rb');
    assert(tempo_file_id >= 0,'Orchestra:TempoCatalogRequired', ...
        'Cannot read the pinned tempo catalog: %s.',CFG.common.tempo_file);
    tempo_cleanup = onCleanup(@() fclose(tempo_file_id));
    tempo_bytes = fread(tempo_file_id,Inf,'*uint8');
    clear tempo_cleanup
    tempo_catalog = jsondecode(native2unicode(tempo_bytes','UTF-8'));
    required_tempo_fields = {'contract_version','analysis_unit', ...
        'score_section_mapping_applied','settings_signature','mir_commit', ...
        'mirtempo_sha256','observations'};
    assert(isstruct(tempo_catalog) && isscalar(tempo_catalog) && ...
        all(isfield(tempo_catalog,required_tempo_fields)) && ...
        isequal(tempo_catalog.contract_version,1) && ...
        strcmp(tempo_catalog.analysis_unit,'existing_wav_segment') && ...
        isequal(tempo_catalog.score_section_mapping_applied,false), ...
        'Orchestra:InvalidTempoCatalog', ...
        'Expected an existing-WAV-segment tempo catalog, without score-section mapping.');
    tempo_engine = java.security.MessageDigest.getInstance('SHA-256');
    tempo_engine.update(tempo_bytes);
    tempo_digest = typecast(tempo_engine.digest(),'uint8');
    tempo_catalog_sha256 = lower(reshape(dec2hex(tempo_digest,2)',1,[]));
    tempo_rows = tempo_catalog.observations;
    tempo_keys = table(strings(0,1),strings(0,1),zeros(0,1),strings(0,1), ...
        'VariableNames',{'Piece','Recording','SegmentIndex','SegmentLabel'});
    if ~isempty(tempo_rows)
        required_row_fields = {'piece','recording','segment_index','segment_label', ...
            'audio_file','audio_sha256','audio_duration_s','tempo_bpm','beat_hz', ...
            'source_csv','manifest_sha256','eligible_flag','status'};
        assert(isstruct(tempo_rows) && all(isfield(tempo_rows,required_row_fields)), ...
            'Orchestra:InvalidTempoCatalog','Tempo observation fields are incomplete.');
        tempo_indices = [tempo_rows.segment_index]';
        validateattributes(tempo_indices,{'numeric'}, ...
            {'real','finite','vector','integer','positive','numel',numel(tempo_rows)});
        tempo_keys = table(lower(string({tempo_rows.piece})'), ...
            string({tempo_rows.recording})',tempo_indices,string({tempo_rows.segment_label})', ...
            'VariableNames',{'Piece','Recording','SegmentIndex','SegmentLabel'});
        assert(height(unique(tempo_keys)) == height(tempo_keys), ...
            'Orchestra:DuplicateTempoKey', ...
            'Tempo catalog must contain one row per piece/recording/index/label.');
    end
end

% Resolve the current checkout's estimator and selected calibration helper.
% Content hashes enter the output signature so a toolbox update creates a
% new route rather than colliding with scientifically valuable saved cores.
core_file = which('FREQNESS_NetworkEstimation_Mocap');
if strcmp(CFG.common.filter_width_calibration,'legacy')
    width_file = which('FREQNESS_ComputeLegacyFilterWidths_Mocap');
else
    width_file = which('FREQNESS_ComputeFilterWidths_Mocap');
end
assert(startsWith(core_file,[fullfile(path_toolbox,'FREQNESS_Functions') filesep]) && ...
    startsWith(width_file,[fullfile(path_toolbox,'FREQNESS_Functions') filesep]), ...
    'Orchestra:UnexpectedToolbox', ...
    'Core estimation and filter calibration must resolve inside %s.',path_toolbox);
core_source = fileread(core_file);
width_source = fileread(width_file);
source_engine = java.security.MessageDigest.getInstance('SHA-256');
source_engine.update(unicode2native(core_source,'UTF-8'));
source_bytes = typecast(source_engine.digest(),'uint8');
core_sha256 = lower(reshape(dec2hex(source_bytes,2)',1,[]));
source_engine.update(unicode2native(width_source,'UTF-8'));
source_bytes = typecast(source_engine.digest(),'uint8');
width_sha256 = lower(reshape(dec2hex(source_bytes,2)',1,[]));
core_provenance = struct('estimator_file',string(core_file), ...
    'estimator_sha256',string(core_sha256),'filter_width_file',string(width_file), ...
    'filter_width_sha256',string(width_sha256));

% A settings signature separates arbitrary frequency grids and parameter
% choices, including changes that share the same first/last frequencies.
core_settings = struct('contract_version',2,'srate',CFG.common.srate, ...
    'srate_confirmed',CFG.common.srate_confirmed_flag, ...
    'timing_provenance',timing_provenance, ...
    'frex',CFG.common.frex(:),'ncomps',CFG.common.ncomps, ...
    'regularisation',CFG.common.regularisation, ...
    'method',CFG.common.method,'kinematics',CFG.common.kinematics, ...
    'interpolate_gaps',false, ...
    'filter_width_calibration',CFG.common.filter_width_calibration, ...
    'filter_type',CFG.common.filter_type, ...
    'estimator_sha256',core_sha256,'filter_width_sha256',width_sha256, ...
    'coordinate_policy','all_csv_xy_tracks_zero_z_no_preprocessing');
% Keep the established Hz signature and cache contract exactly unchanged.
% Only beat runs add the catalog fingerprint, ratio grid, and support rule.
if beat_reference_flag
    core_settings = rmfield(core_settings,'frex');
    core_settings.contract_version = 3;
    core_settings.frequency_reference = "beat";
    core_settings.beat_ratios = CFG.common.beat_ratios(:);
    core_settings.tempo_catalog_sha256 = tempo_catalog_sha256;
    core_settings.minimum_cycles = CFG.common.minimum_cycles;
end
signature_engine = java.security.MessageDigest.getInstance('SHA-256');
signature_engine.update(uint8(jsonencode(core_settings)));
signature_bytes = typecast(signature_engine.digest(),'uint8');
settings_signature = lower(reshape(dec2hex(signature_bytes,2)',1,[]));
filter_output_tag = [CFG.common.filter_width_calibration '_' ...
    CFG.common.filter_type];
analysis_tag = sprintf('fs%g_f%g-%g_n%d_%s',CFG.common.srate, ...
    CFG.common.frex(1),CFG.common.frex(end),numel(CFG.common.frex), ...
    settings_signature(1:12));
if beat_reference_flag
    analysis_tag = sprintf('fs%g_beat%g-%g_n%d_%s',CFG.common.srate, ...
        CFG.common.beat_ratios(1),CFG.common.beat_ratios(end), ...
        numel(CFG.common.beat_ratios),settings_signature(1:12));
end
CFG.common.results_path = fullfile(CFG.common.output_path, ...
    filter_output_tag,analysis_tag);
CFG.block1.output_path = fullfile(CFG.common.results_path,'01_Core_FullPiece');
CFG.block2.output_path = fullfile(CFG.common.results_path,'02_Core_SegmentPiece');
CFG.block3.output_path = fullfile(CFG.common.results_path, ...
    '03_Visualization','leading_H2_empirical_peak_magnitude');


%% BLOCK 1 - CORE ANALYSIS OF FULL PIECES

if CFG.block1.run_flag
    path_data = fullfile(CFG.common.data_path,'full-piece-data-fixed-despiked');
    assert(isfolder(path_data),'Full-piece data directory not found: %s',path_data);
    files = dir(fullfile(path_data,'*','*.csv'));
    source_files = sort(string(fullfile({files.folder},{files.name})))';
    nfiles = numel(source_files);
    FULL = table(source_files,strings(nfiles,1),strings(nfiles,1), ...
        strings(nfiles,1),repmat("not_selected",nfiles,1), ...
        nan(nfiles,1),nan(nfiles,1),'VariableNames', ...
        {'SourceFile','Piece','Recording','CoreFile','Status','ntracks','npnts'});
    assert(nfiles > 0,'No full-piece CSV files found below %s.',path_data);

    for filei = 1:nfiles
        source_file = char(source_files(filei));
        [this_folder,this_recording] = fileparts(source_file);
        [~,this_piece] = fileparts(this_folder);
        this_piece = lower(string(this_piece));
        this_recording = string(this_recording);
        FULL.Piece(filei) = this_piece;
        FULL.Recording(filei) = this_recording;
        if ~ismember(this_piece,lower(string(CFG.common.pieces))) || ...
                (~isempty(CFG.common.recordings) && ...
                ~ismember(this_recording,string(CFG.common.recordings)))
            continue
        end
        output_file = fullfile(CFG.block1.output_path,this_piece, ...
            "GED_"+this_recording+".mat");
        FULL.CoreFile(filei) = output_file;

        % The requested full-piece analysis retains every supplied frame and
        % track. It replaces the prototype's temporary half-recording and
        % track-64 exclusions; no new preprocessing is performed.
        % Validate CSV structure before adapting XY to the toolbox's XYZ layout.
        this_data = readtable(source_file,'VariableNamingRule','preserve');
        names = string(this_data.Properties.VariableNames);
        assert(names(1) == "frame" && mod(width(this_data)-1,2) == 0, ...
            'Expected frame,1x,1y,... coordinate pairs in %s.',source_file);
        assert(all(varfun(@isnumeric,this_data,'OutputFormat','uniform')), ...
            'All frame and coordinate columns must be numeric in %s.',source_file);
        x_names = names(2:2:end);
        y_names = names(3:2:end);
        valid_names = ~cellfun(@isempty,regexp(cellstr(x_names), ...
            '^[1-9]\d*x$','once'));
        assert(~isempty(x_names) && all(valid_names) && ...
            isequal(y_names,replace(x_names,"x","y")), ...
            'Orchestra:InvalidCoordinates', ...
            'Expected paired numeric track IDs (1x,1y,...) in %s.',source_file);
        track_ids = str2double(erase(x_names,"x"));
        assert(numel(unique(track_ids)) == numel(track_ids), ...
            'Duplicate track IDs in %s.',source_file);
        this_values = this_data{:,:}; % [frames x (1 + 2*ntracks)].
        frame = this_values(:,1);
        npnts = size(this_values,1);
        assert(npnts >= 2 && all(isfinite(this_values),'all'), ...
            'Orchestra:InvalidMovementData', ...
            'Expected at least two finite frames in %s; no repairs are applied.',source_file);
        assert(all(frame == round(frame)) && all(diff(frame) == 1), ...
            'Expected consecutive integer frame indices in %s.',source_file);

        marklabels = cellstr("Track_"+string(track_ids));
        ntracks = numel(track_ids);
        nmarks = 3*ntracks; % Coordinate channels, including zero-valued Z.
        x_idx = 1:3:nmarks;
        y_idx = 2:3:nmarks;
        z_idx = 3:3:nmarks;
        markData = zeros(nmarks,npnts); % [XYZ coordinates x frames].
        markData(x_idx,:) = this_values(:,2:2:end)';
        markData(y_idx,:) = this_values(:,3:2:end)';
        markData(z_idx,:) = 0; % Z was not recorded; preserve the original adapter.
        marker_position = markData(:,1); % Static overhead layout; no raw-data copy.
        assert(CFG.common.ncomps <= nmarks, ...
            'CFG.common.ncomps exceeds the coordinate count in %s.',source_file);

        % All settings are consumed from CFG; no scientific defaults reset here.
        srate = CFG.common.srate;
        frex = CFG.common.frex(:);
        filter_width_calibration = CFG.common.filter_width_calibration;
        filter_type = CFG.common.filter_type;
        if strcmp(filter_width_calibration,'legacy')
            filter_width = FREQNESS_ComputeLegacyFilterWidths_Mocap(frex,filter_type);
            expected_filter_width = filter_width;
        else
            filter_width = [];
            expected_filter_width = FREQNESS_ComputeFilterWidths_Mocap(frex,filter_type);
        end
        source_info = dir(source_file);
        analysis_info = struct('contract_version',2,'stage',"full_piece", ...
            'piece',this_piece,'recording',this_recording, ...
            'source_file',string(source_file),'source_bytes',source_info.bytes, ...
            'source_modified',source_info.datenum,'track_ids',track_ids, ...
            'frame_first',frame(1),'frame_last',frame(end),'npnts',npnts, ...
            'srate',srate,'srate_confirmed',CFG.common.srate_confirmed_flag, ...
            'timing_provenance',timing_provenance, ...
            'frex',frex,'ncomps',CFG.common.ncomps, ...
            'regularisation',CFG.common.regularisation, ...
            'method',string(CFG.common.method),'kinematics',string(CFG.common.kinematics), ...
            'interpolate_gaps',false, ...
            'filterWidthCalibration',string(filter_width_calibration), ...
            'filter',string(filter_type),'fwidth',expected_filter_width, ...
            'coordinate_policy',"all_csv_xy_tracks_zero_z_no_preprocessing", ...
            'segment',struct(),'core_source',core_source, ...
            'core_provenance',core_provenance,'settings_signature',string(settings_signature));

        FULL.ntracks(filei) = ntracks;
        FULL.npnts(filei) = npnts;
        if isfile(output_file) && ~CFG.block1.overwrite_flag
            saved_core = load(output_file,'analysis_info');
            assert(isfield(saved_core,'analysis_info') && ...
                isequaln(saved_core.analysis_info,analysis_info), ...
                'Orchestra:IncompatibleCore', ...
                ['Existing core is incompatible with its source/settings: %s. ' ...
                 'Inspect it before enabling overwrite_flag.'],output_file);
            FULL.Status(filei) = "existing";
            clear markData this_data this_values saved_core
            continue
        end

        fprintf('\nfull_piece: %s | %d tracks, %d frames; time series %.1f MiB\n', ...
            source_file,ntracks,npnts,8*CFG.common.ncomps*npnts*numel(frex)/2^20);
        GED = FREQNESS_NetworkEstimation_Mocap(markData,frex,srate, ...
            'method',CFG.common.method,'kinematics',CFG.common.kinematics, ...
            'fwidth',filter_width,'filter',filter_type, ...
            'ncomps',CFG.common.ncomps,'regularisation',CFG.common.regularisation, ...
            'interpolate_gaps',false);
        assert(isequal(GED.fwhm,expected_filter_width), ...
            'Core output did not use the requested filter-width calibration.');
        assert(strcmp(GED.method,CFG.common.method) && ...
            strcmp(GED.kinematics,CFG.common.kinematics) && ...
            GED.input_n_samples == npnts && size(GED.ts,2) == npnts && ...
            GED.sample_offset == 0 && isempty(GED.bad_segments), ...
            'Core output must preserve every supplied position sample: %s.',source_file);
        assert(isequal(size(GED.evals),[nmarks numel(frex)]) && ...
            all(isfinite(GED.evals),'all') && ...
            max(abs(sum(GED.evals,1)-100)) < 1e-8, ...
            'Invalid eigenspectrum dimensions, values, or normalization: %s.',source_file);
        GED.filter_width_calibration = string(filter_width_calibration);
        GED.filter_type = string(filter_type);
        output_folder = fileparts(output_file);
        if ~isfolder(output_folder); mkdir(output_folder); end
        % Complete eigenspectrum; retained patterns/eigenvectors/time series.
        % One file per observation makes expensive stages resumable.
        temporary_file = [tempname(output_folder) '.mat'];
        save(temporary_file,'GED','analysis_info','CFG','frex','srate', ...
            'marklabels','marker_position','-v7.3')
        movefile(temporary_file,output_file,'f')
        FULL.Status(filei) = "saved";
        clear GED markData this_data this_values saved_core

    end
    if ~isfolder(CFG.block1.output_path); mkdir(CFG.block1.output_path); end
    % The index is a regenerable record of this invocation, including skips.
    writetable(FULL,fullfile(CFG.block1.output_path,'core_index.csv'))
    fprintf('\nFull pieces: %d saved, %d reused, %d not selected.\n', ...
        nnz(FULL.Status == "saved"),nnz(FULL.Status == "existing"), ...
        nnz(FULL.Status == "not_selected"));
end


%% BLOCK 2 - CORE ANALYSIS OF MUSICAL SECTIONS

if CFG.block2.run_flag
    path_data = fullfile(CFG.common.data_path,'segment-piece-data-fixed-despiked');
    assert(isfolder(path_data),'Segment-piece data directory not found: %s',path_data);
    files = dir(fullfile(path_data,'*','*','segments_manifest.csv'));
    manifest_files = sort(string(fullfile({files.folder},{files.name})))';
    nfiles = numel(manifest_files);
    assert(nfiles > 0,'No segment manifests found below %s.',path_data);
    segment_tables = cell(nfiles,1);

    for filei = 1:nfiles
        manifest_file = char(manifest_files(filei));
        this_folder = fileparts(manifest_file);
        [piece_folder,this_recording] = fileparts(this_folder);
        [~,this_piece] = fileparts(piece_folder);
        this_piece = lower(string(this_piece));
        this_recording = string(this_recording);
        % Score labels can mix words (Start) and numbers; numeric inference
        % would silently turn the words into missing values.
        manifest_options = detectImportOptions(manifest_file,'VariableNamingRule','preserve');
        mask_text = ismember(manifest_options.VariableTypes,{'char','string'}) | ...
            strcmp(manifest_options.VariableNames,'label');
        manifest_options = setvartype(manifest_options, ...
            manifest_options.VariableNames(mask_text),'string');
        manifest = readtable(manifest_file,manifest_options);
        required_fields = {'index','label','start_row_index', ...
            'end_row_index_exclusive','frames','file'};
        assert(all(ismember(required_fields,manifest.Properties.VariableNames)), ...
            'Missing required segment-manifest columns in %s.',manifest_file);
        nsegments = height(manifest);
        assert(numel(unique(manifest.file)) == nsegments, ...
            'Duplicate segment filenames in %s.',manifest_file);
        SEG = table(repmat(this_piece,nsegments,1), ...
            repmat(this_recording,nsegments,1),string(manifest.label), ...
            string(fullfile(this_folder,manifest.file)),strings(nsegments,1), ...
            repmat("not_selected",nsegments,1),nan(nsegments,1),nan(nsegments,1), ...
            'VariableNames',{'Piece','Recording','SegmentLabel','SourceFile', ...
            'CoreFile','Status','ntracks','npnts'});
        if beat_reference_flag
            SEG.TempoStatus = repmat("not_selected",nsegments,1);
            SEG.TempoReviewReason = strings(nsegments,1);
            SEG.BeatHz = nan(nsegments,1);
            % Pin the motion/audio mapping as well as the WAV bytes. A
            % stable segment label cannot authorize a revised frame interval.
            manifest_file_id = fopen(manifest_file,'rb');
            assert(manifest_file_id >= 0,'Orchestra:TempoManifestMismatch', ...
                'Cannot verify the segment manifest: %s.',manifest_file);
            manifest_cleanup = onCleanup(@() fclose(manifest_file_id));
            manifest_engine = java.security.MessageDigest.getInstance('SHA-256');
            while ~feof(manifest_file_id)
                manifest_engine.update(fread(manifest_file_id,2^20,'*uint8'));
            end
            clear manifest_cleanup
            manifest_digest = typecast(manifest_engine.digest(),'uint8');
            manifest_sha256 = lower(reshape(dec2hex(manifest_digest,2)',1,[]));
        end

        for segi = 1:nsegments
            if ~ismember(this_piece,lower(string(CFG.common.pieces))) || ...
                    (~isempty(CFG.common.recordings) && ...
                    ~ismember(this_recording,string(CFG.common.recordings))) || ...
                    (~isempty(CFG.block2.segment_labels) && ...
                    ~ismember(string(manifest.label(segi)),string(CFG.block2.segment_labels)))
                continue
            end
            source_file = char(SEG.SourceFile(segi));
            if ~isfile(source_file)
                SEG.Status(segi) = "missing_source";
                warning('Orchestra:MissingSegment', ...
                    'Segment CSV is absent and will not be reconstructed: %s',source_file);
                continue
            end
            if beat_reference_flag
                idx_tempo = find(tempo_keys.Piece == this_piece & ...
                    tempo_keys.Recording == this_recording & ...
                    tempo_keys.SegmentIndex == manifest.index(segi) & ...
                    tempo_keys.SegmentLabel == string(manifest.label(segi)));
                SEG.Status(segi) = "tempo_review";
                if isempty(idx_tempo)
                    SEG.TempoStatus(segi) = "missing_catalog_row";
                    SEG.TempoReviewReason(segi) = "No exact manifest-key match in the pinned tempo catalog.";
                    continue
                end
                this_tempo = tempo_rows(idx_tempo);
                SEG.TempoStatus(segi) = string(this_tempo.status);
                eligible_tempo = strcmp(this_tempo.status,'accepted') && ...
                    islogical(this_tempo.eligible_flag) && isscalar(this_tempo.eligible_flag) && ...
                    this_tempo.eligible_flag && isnumeric(this_tempo.beat_hz) && ...
                    isreal(this_tempo.beat_hz) && isscalar(this_tempo.beat_hz) && ...
                    isfinite(this_tempo.beat_hz) && this_tempo.beat_hz > 0 && ...
                    isnumeric(this_tempo.tempo_bpm) && isreal(this_tempo.tempo_bpm) && ...
                    isscalar(this_tempo.tempo_bpm) && isfinite(this_tempo.tempo_bpm) && ...
                    this_tempo.tempo_bpm > 0;
                if ~eligible_tempo
                    SEG.TempoReviewReason(segi) = "Tempo is not accepted, eligible, finite and positive.";
                    continue
                end
                assert(isscalar(string(this_tempo.source_csv)) && ...
                    string(this_tempo.source_csv) == string(source_file) && ...
                    strcmpi(manifest_sha256,this_tempo.manifest_sha256), ...
                    'Orchestra:TempoManifestMismatch', ...
                    ['Accepted tempo must refer to this motion CSV and the unchanged ' ...
                     'segment manifest: %s. Regenerate the tempo catalog after mapping changes.'], ...
                    manifest_file);
                beat_frex = this_tempo.beat_hz;
                if abs(this_tempo.tempo_bpm/60-beat_frex) > 1e-10*max(1,beat_frex)
                    SEG.TempoReviewReason(segi) = "Accepted BPM and beat-Hz values disagree.";
                    continue
                end
                if any(beat_frex*CFG.common.beat_ratios >= CFG.common.srate/2)
                    SEG.TempoReviewReason(segi) = "The complete ratio grid is not below Nyquist; no bins were removed.";
                    continue
                end
                assert(ismember('audio_file',manifest.Properties.VariableNames), ...
                    'Orchestra:InvalidTempoManifest','Beat analysis needs manifest audio_file names.');
                audio_file = fullfile(this_folder,string(manifest.audio_file(segi)));
                assert(string(this_tempo.audio_file) == string(audio_file), ...
                    'Orchestra:TempoAudioMismatch', ...
                    'Tempo audio path does not match the selected manifest: %s.',manifest_file);
                if ~isfile(audio_file)
                    SEG.TempoReviewReason(segi) = "The accepted tempo's source WAV is missing.";
                    continue
                end
                % Verify the exact source WAV without decoding or altering it.
                audio_file_id = fopen(audio_file,'rb');
                assert(audio_file_id >= 0,'Orchestra:TempoAudioMismatch', ...
                    'Cannot verify the tempo source WAV: %s.',audio_file);
                audio_cleanup = onCleanup(@() fclose(audio_file_id));
                audio_engine = java.security.MessageDigest.getInstance('SHA-256');
                while ~feof(audio_file_id)
                    audio_engine.update(fread(audio_file_id,2^20,'*uint8'));
                end
                clear audio_cleanup
                audio_digest = typecast(audio_engine.digest(),'uint8');
                audio_sha256 = lower(reshape(dec2hex(audio_digest,2)',1,[]));
                assert(strcmpi(audio_sha256,this_tempo.audio_sha256), ...
                    'Orchestra:TempoAudioMismatch', ...
                    'Source WAV differs from the pinned tempo estimate: %s.',audio_file);
                wav_info = audioinfo(audio_file);
                wav_duration_s = wav_info.TotalSamples/wav_info.SampleRate;
                assert(isnumeric(this_tempo.audio_duration_s) && ...
                    isscalar(this_tempo.audio_duration_s) && ...
                    isfinite(this_tempo.audio_duration_s) && ...
                    abs(this_tempo.audio_duration_s-wav_duration_s) <= 1/wav_info.SampleRate+1e-9, ...
                    'Orchestra:TempoAudioMismatch', ...
                    'Tempo duration does not match the WAV sample count: %s.',audio_file);
                SEG.BeatHz(segi) = beat_frex;
            end
            [~,segment_name] = fileparts(source_file);
            output_file = fullfile(CFG.block2.output_path,this_piece, ...
                this_recording,"GED_"+string(segment_name)+".mat");
            SEG.CoreFile(segi) = output_file;
            segment_info = table2struct(manifest(segi,:));
            segment_info.manifest_file = string(manifest_file);
            % Validate CSV structure before adapting XY to the toolbox's XYZ layout.
            this_data = readtable(source_file,'VariableNamingRule','preserve');
            names = string(this_data.Properties.VariableNames);
            assert(names(1) == "frame" && mod(width(this_data)-1,2) == 0, ...
                'Expected frame,1x,1y,... coordinate pairs in %s.',source_file);
            assert(all(varfun(@isnumeric,this_data,'OutputFormat','uniform')), ...
                'All frame and coordinate columns must be numeric in %s.',source_file);
            x_names = names(2:2:end);
            y_names = names(3:2:end);
            valid_names = ~cellfun(@isempty,regexp(cellstr(x_names), ...
                '^[1-9]\d*x$','once'));
            assert(~isempty(x_names) && all(valid_names) && ...
                isequal(y_names,replace(x_names,"x","y")), ...
                'Orchestra:InvalidCoordinates', ...
                'Expected paired numeric track IDs (1x,1y,...) in %s.',source_file);
            track_ids = str2double(erase(x_names,"x"));
            assert(numel(unique(track_ids)) == numel(track_ids), ...
                'Duplicate track IDs in %s.',source_file);
            this_values = this_data{:,:}; % [frames x (1 + 2*ntracks)].
            frame = this_values(:,1);
            npnts = size(this_values,1);
            assert(npnts >= 2 && all(isfinite(this_values),'all'), ...
                'Orchestra:InvalidMovementData', ...
                'Expected at least two finite frames in %s; no repairs are applied.',source_file);
            assert(all(frame == round(frame)) && all(diff(frame) == 1), ...
                'Expected consecutive integer frame indices in %s.',source_file);
            assert(npnts == manifest.frames(segi) && ...
                npnts == manifest.end_row_index_exclusive(segi)-manifest.start_row_index(segi) && ...
                frame(1) == manifest.start_row_index(segi)+1 && ...
                frame(end) == manifest.end_row_index_exclusive(segi), ...
                'Segment frames disagree with the manifest: %s.',source_file);
            marklabels = cellstr("Track_"+string(track_ids));
            ntracks = numel(track_ids);
            nmarks = 3*ntracks; % Coordinate channels, including zero-valued Z.
            x_idx = 1:3:nmarks;
            y_idx = 2:3:nmarks;
            z_idx = 3:3:nmarks;
            markData = zeros(nmarks,npnts); % [XYZ coordinates x frames].
            markData(x_idx,:) = this_values(:,2:2:end)';
            markData(y_idx,:) = this_values(:,3:2:end)';
            markData(z_idx,:) = 0; % Z was not recorded; preserve the original adapter.
            marker_position = markData(:,1); % Static overhead layout; no raw-data copy.
            assert(CFG.common.ncomps <= nmarks, ...
                'CFG.common.ncomps exceeds the coordinate count in %s.',source_file);

            % All settings are consumed from CFG; no scientific defaults reset here.
            srate = CFG.common.srate;
            frex = CFG.common.frex(:);
            if beat_reference_flag
                frex = beat_frex*CFG.common.beat_ratios(:); % [frequencies x 1], Hz.
            end
            filter_width_calibration = CFG.common.filter_width_calibration;
            filter_type = CFG.common.filter_type;
            if strcmp(filter_width_calibration,'legacy')
                filter_width = FREQNESS_ComputeLegacyFilterWidths_Mocap(frex,filter_type);
                expected_filter_width = filter_width;
            else
                filter_width = [];
                expected_filter_width = FREQNESS_ComputeFilterWidths_Mocap(frex,filter_type);
            end
            source_info = dir(source_file);
            analysis_info = struct('contract_version',2,'stage',"segment_piece", ...
                'piece',this_piece,'recording',this_recording, ...
                'source_file',string(source_file),'source_bytes',source_info.bytes, ...
                'source_modified',source_info.datenum,'track_ids',track_ids, ...
                'frame_first',frame(1),'frame_last',frame(end),'npnts',npnts, ...
                'srate',srate,'srate_confirmed',CFG.common.srate_confirmed_flag, ...
                'timing_provenance',timing_provenance, ...
                'frex',frex,'ncomps',CFG.common.ncomps, ...
                'regularisation',CFG.common.regularisation, ...
                'method',string(CFG.common.method),'kinematics',string(CFG.common.kinematics), ...
                'interpolate_gaps',false, ...
                'filterWidthCalibration',string(filter_width_calibration), ...
                'filter',string(filter_type),'fwidth',expected_filter_width, ...
                'coordinate_policy',"all_csv_xy_tracks_zero_z_no_preprocessing", ...
                'segment',segment_info,'core_source',core_source, ...
                'core_provenance',core_provenance,'settings_signature',string(settings_signature));
            if beat_reference_flag
                motion_duration_s = npnts/srate;
                manifest_audio_duration_s = NaN;
                if isfield(segment_info,'audio_duration_s')
                    manifest_audio_duration_s = segment_info.audio_duration_s;
                end
                analysis_info.contract_version = 3;
                analysis_info.frequency_reference = "beat";
                analysis_info.beat_frex = beat_frex;
                analysis_info.beat_ratios = CFG.common.beat_ratios(:);
                analysis_info.frex_norm = frex/beat_frex;
                analysis_info.frequency_support = struct( ...
                    'minimum_cycles',CFG.common.minimum_cycles, ...
                    'motion_duration_s',motion_duration_s, ...
                    'cycles_observed',frex*motion_duration_s, ...
                    'insufficient_cycles_flag',frex*motion_duration_s < CFG.common.minimum_cycles, ...
                    'fft_resolution_hz',srate/npnts, ...
                    'fwhm_hz',expected_filter_width, ...
                    'bins_per_fwhm',expected_filter_width/(srate/npnts), ...
                    'bandwidth_below_resolution_flag',expected_filter_width/(srate/npnts) < 1, ...
                    'rule',"descriptive_cycle_count_not_filter_validity");
                analysis_info.tempo_provenance = struct( ...
                    'catalog_file',string(CFG.common.tempo_file), ...
                    'catalog_sha256',string(tempo_catalog_sha256), ...
                    'catalog_settings_signature',string(tempo_catalog.settings_signature), ...
                    'mir_commit',string(tempo_catalog.mir_commit), ...
                    'mirtempo_sha256',string(tempo_catalog.mirtempo_sha256), ...
                    'analysis_unit',string(tempo_catalog.analysis_unit), ...
                    'score_section_mapping_applied',false,'observation',this_tempo, ...
                    'wav_duration_s',wav_duration_s,'motion_duration_s',motion_duration_s, ...
                    'audio_motion_duration_difference_s',wav_duration_s-motion_duration_s, ...
                    'manifest_audio_duration_s',manifest_audio_duration_s, ...
                    'wav_minus_manifest_duration_s',wav_duration_s-manifest_audio_duration_s, ...
                    'audio_alignment_status',CFG.common.audio_alignment_status);
            end

            SEG.ntracks(segi) = ntracks;
            SEG.npnts(segi) = npnts;
            if isfile(output_file) && ~CFG.block2.overwrite_flag
                saved_core = load(output_file,'analysis_info');
                assert(isfield(saved_core,'analysis_info') && ...
                    isequaln(saved_core.analysis_info,analysis_info), ...
                    'Orchestra:IncompatibleCore', ...
                    ['Existing core is incompatible with its source/settings: %s. ' ...
                     'Inspect it before enabling overwrite_flag.'],output_file);
                SEG.Status(segi) = "existing";
                clear markData this_data this_values saved_core
                continue
            end

            fprintf('\nsegment_piece: %s | %d tracks, %d frames; time series %.1f MiB\n', ...
                source_file,ntracks,npnts,8*CFG.common.ncomps*npnts*numel(frex)/2^20);
            GED = FREQNESS_NetworkEstimation_Mocap(markData,frex,srate, ...
                'method',CFG.common.method,'kinematics',CFG.common.kinematics, ...
                'fwidth',filter_width,'filter',filter_type, ...
                'ncomps',CFG.common.ncomps,'regularisation',CFG.common.regularisation, ...
                'interpolate_gaps',false);
            assert(isequal(GED.fwhm,expected_filter_width), ...
                'Core output did not use the requested filter-width calibration.');
            assert(strcmp(GED.method,CFG.common.method) && ...
                strcmp(GED.kinematics,CFG.common.kinematics) && ...
                GED.input_n_samples == npnts && size(GED.ts,2) == npnts && ...
                GED.sample_offset == 0 && isempty(GED.bad_segments), ...
                'Core output must preserve every supplied position sample: %s.',source_file);
            assert(isequal(size(GED.evals),[nmarks numel(frex)]) && ...
                all(isfinite(GED.evals),'all') && ...
                max(abs(sum(GED.evals,1)-100)) < 1e-8, ...
                'Invalid eigenspectrum dimensions, values, or normalization: %s.',source_file);
            GED.filter_width_calibration = string(filter_width_calibration);
            GED.filter_type = string(filter_type);
            if beat_reference_flag
                GED.frex_norm = GED.frex/beat_frex;
                GED.beat_frex = beat_frex;
                assert(max(abs(GED.frex_norm(:)-CFG.common.beat_ratios(:))) < 1e-12, ...
                    'Beat-normalized frequencies must preserve the complete requested ratio grid.');
            end
            output_folder = fileparts(output_file);
            if ~isfolder(output_folder); mkdir(output_folder); end
            % Complete eigenspectrum; retained patterns/eigenvectors/time series.
            % One file per observation makes expensive stages resumable.
            temporary_file = [tempname(output_folder) '.mat'];
            save(temporary_file,'GED','analysis_info','CFG','frex','srate', ...
                'marklabels','marker_position','-v7.3')
            movefile(temporary_file,output_file,'f')
            SEG.Status(segi) = "saved";
            clear GED markData this_data this_values saved_core

        end
        segment_tables{filei} = SEG;
    end
    SEG = vertcat(segment_tables{:});
    if ~isfolder(CFG.block2.output_path); mkdir(CFG.block2.output_path); end
    writetable(SEG,fullfile(CFG.block2.output_path,'core_index.csv'))
    fprintf('\nSections: %d saved, %d reused, %d missing, %d tempo review, %d not selected.\n', ...
        nnz(SEG.Status == "saved"),nnz(SEG.Status == "existing"), ...
        nnz(SEG.Status == "missing_source"),nnz(SEG.Status == "tempo_review"), ...
        nnz(SEG.Status == "not_selected"));
end


%% BLOCK 3 - CHRONOLOGICAL LANDSCAPES AND EMPIRICAL-PEAK PATTERNS

if CFG.block3.run_flag
    assert(all(ismember(string(CFG.block3.stages),["full_piece" "segment_piece"])), ...
        'CFG.block3.stages must contain full_piece and/or segment_piece.');
    assert(CFG.block3.save_flag || ~CFG.block3.close_figures_flag, ...
        'Unsaved figures must remain open: disable close_figures_flag.');
    % Load optional provisional identities independently of scientific and
    % existing display signatures. Old settings without this option retain
    % Track_ID labels; enabling it never changes a core or an overhead map.
    matrix_labels_flag = isfield(CFG.block3,'matrix_labels_flag') && ...
        CFG.block3.matrix_labels_flag && CFG.block3.plot_matrix_flag;
    if isfield(CFG.block3,'matrix_labels_flag')
        validateattributes(CFG.block3.matrix_labels_flag,{'logical'},{'scalar'});
    end
    if matrix_labels_flag
        assert(isfield(CFG.block3,'matrix_label_file') && ...
            isfile(CFG.block3.matrix_label_file),'Orchestra:MissingMatrixLabels', ...
            'Set CFG.block3.matrix_label_file to the provisional ID/label CSV.');
        label_map = readtable(CFG.block3.matrix_label_file,'TextType','string', ...
            'VariableNamingRule','preserve');
        assert(all(ismember({'track_id','label','source_header'}, ...
            label_map.Properties.VariableNames)),'Orchestra:InvalidMatrixLabels', ...
            'Expected columns track_id, label and source_header.');
        validateattributes(label_map.track_id,{'numeric'}, ...
            {'real','finite','vector','nonempty','integer','positive'});
        assert(numel(unique(label_map.track_id)) == height(label_map) && ...
            all(~ismissing(label_map.label) & strlength(strtrim(label_map.label)) > 0) && ...
            all(~ismissing(label_map.source_header) & strlength(label_map.source_header) > 0), ...
            'Orchestra:InvalidMatrixLabels', ...
            'Labels require unique numeric track IDs and nonempty label/source strings.');
        label_source_ids = regexp(cellstr(label_map.source_header),'^(\d+).+\.x$', ...
            'tokens','once');
        assert(all(~cellfun(@isempty,label_source_ids)), ...
            'Orchestra:InvalidMatrixLabels','Expected source headers <numeric ID><label>.x.');
        label_source_ids = cellfun(@(x) str2double(x{1}),label_source_ids);
        assert(isequal(label_source_ids(:),label_map.track_id(:)), ...
            'Orchestra:InvalidMatrixLabels','Label IDs disagree with their source header IDs.');
        label_source = fileread(CFG.block3.matrix_label_file);
        label_engine = java.security.MessageDigest.getInstance('SHA-256');
        label_engine.update(unicode2native(label_source,'UTF-8'));
        label_digest = typecast(label_engine.digest(),'uint8');
        label_sha256 = lower(reshape(dec2hex(label_digest,2)',1,[]));
        [~,label_basename,label_extension] = fileparts(CFG.block3.matrix_label_file);
        matrix_label_settings = struct('presentation_version',1, ...
            'status',"provisional",'review_status',"pending_visual_inspection", ...
            'reviewer',"Peter Keller",'review_required',"Peter Keller visual inspection", ...
            'source_file',string([label_basename label_extension]), ...
            'source_sha256',string(label_sha256), ...
            'source_origin',"CoE_2026_Hackaton/data/64track-deeplabcut-carmen.csv headers", ...
            'assignment_policy',"user_authorised_numeric_ID_extrapolation_all_recordings", ...
            'unknown_ID_policy',"reject_unknown_track_ID", ...
            'track_ids',label_map.track_id(:),'labels',label_map.label(:), ...
            'source_headers',label_map.source_header(:));
        label_engine.update(unicode2native(jsonencode(matrix_label_settings),'UTF-8'));
        label_digest = typecast(label_engine.digest(),'uint8');
        matrix_label_signature = lower(reshape(dec2hex(label_digest,2)',1,[]));
        fprintf(['Activation matrix identities are PROVISIONAL: numeric IDs are ' ...
            'extrapolated from the Carmen demo; Peter Keller visual review pending.\n']);
    end
    visual_settings = struct('presentation_version',3, ...
        'component',1,'peak_method',"maximum_analyzed_bin_first_tie", ...
        'entropy_method',"complete_eigenspectrum_H2_natural_log", ...
        'pattern_transform',"absolute_display_copy", ...
        'matrix_units',"absolute_raw_pattern_weight", ...
        'coordinate_normalization',"maximum_absolute_coordinate_across_tracks", ...
        'xy_normalization',"maximum_raw_xy_magnitude_across_tracks", ...
        'filter_width_calibration',string(CFG.common.filter_width_calibration), ...
        'filter_type',string(CFG.common.filter_type), ...
        'color_first',CFG.block3.color_first,'color_last',CFG.block3.color_last, ...
        'color_concert',CFG.block3.color_concert,'plot_matrix',CFG.block3.plot_matrix_flag, ...
        'visualizer_source',fileread(which('FREQNESS_Visualizer_Mocap')), ...
        'entropy_source',fileread(which('FREQNESS_EffectDim_Mocap')));
    % Keep existing Hz visualization signatures unchanged. Beat-normalized
    % displays belong to segment cores estimated on their own physical grid.
    display_frequency_reference = "hz";
    if isfield(CFG.common,'frequency_reference')
        display_frequency_reference = string(CFG.common.frequency_reference);
    end
    assert(isscalar(display_frequency_reference) && ...
        ismember(display_frequency_reference,["hz" "beat"]), ...
        'Orchestra:InvalidFrequencyReference','Expected frequency_reference hz or beat.');
    if display_frequency_reference == "beat"
        assert(all(string(CFG.block3.stages) == "segment_piece"), ...
            'Orchestra:FullPieceBeatDisplay', ...
            'A section-specific beat cannot normalize a full-piece core. Select segment_piece only.');
        visual_settings.frequency_reference = "beat";
        visual_settings.frequency_axis = "physical_frequency_divided_by_segment_beat";
        visual_settings.cycle_count_warning = "bins_below_saved_minimum_motion_cycles";
        visual_settings.bandwidth_warning = "filter_FWHM_below_segment_Fourier_spacing";
    end
    original_visibility = get(groot,'DefaultFigureVisible');
    set(groot,'DefaultFigureVisible',CFG.block3.figure_visibility)
    try
        for stagei = 1:numel(CFG.block3.stages)
            this_stage = string(CFG.block3.stages(stagei));
            if this_stage == "full_piece"
                path_core = CFG.block1.output_path;
            else
                path_core = CFG.block2.output_path;
            end
            files = dir(fullfile(path_core,'**','GED_*.mat'));
            core_files = sort(string(fullfile({files.folder},{files.name})))';
            % Small spectra/provenance only: never retain sample-resolved arrays.
            observations = cell(numel(core_files),1);
            matrix_label_records = cell(numel(core_files),1);
            selected_count = 0;
            for filei = 1:numel(core_files)
                saved_core = load(core_files(filei),'analysis_info','marker_position','marklabels');
                info = saved_core.analysis_info;
                if ~ismember(info.piece,lower(string(CFG.common.pieces))) || ...
                        (~isempty(CFG.block3.recordings) && ...
                        ~ismember(info.recording,string(CFG.block3.recordings)))
                    continue
                end
                if this_stage == "segment_piece" && ~isempty(CFG.block3.segment_labels) && ...
                        ~ismember(string(info.segment.label),string(CFG.block3.segment_labels))
                    continue
                end
                % These cores are v7.3. Read just eigenvalues and, when needed,
                % patterns; loading GED would also load large unused time series.
                FREQ = struct('frex',info.frex(:)', ...
                    'evals',h5read(core_files(filei),'/GED/evals'));
                this_frequency_reference = "hz";
                if isfield(info,'frequency_reference')
                    this_frequency_reference = string(info.frequency_reference);
                end
                assert(isequal(this_frequency_reference,display_frequency_reference), ...
                    'Orchestra:FrequencyReferenceMismatch', ...
                    'Core frequency reference differs from the selected display: %s.',core_files(filei));
                if this_frequency_reference == "beat"
                    required_beat_fields = {'beat_frex','beat_ratios','frex_norm', ...
                        'frequency_support','tempo_provenance'};
                    assert(all(isfield(info,required_beat_fields)), ...
                        'Orchestra:MissingBeatProvenance','Beat core lacks normalization provenance: %s.',core_files(filei));
                    validateattributes(info.beat_frex,{'numeric'},{'real','finite','scalar','positive'});
                    this_frex_norm = reshape(info.frex_norm,1,[]);
                    this_plot_frex = reshape(info.beat_ratios,1,[]);
                    validateattributes(this_plot_frex,{'numeric'}, ...
                        {'real','finite','positive','increasing','vector'});
                    saved_frex_norm = reshape(h5read(core_files(filei),'/GED/frex_norm'),1,[]);
                    saved_beat_frex = h5read(core_files(filei),'/GED/beat_frex');
                    assert(isequal(size(this_frex_norm),size(FREQ.frex)) && ...
                        isequal(size(this_plot_frex),size(FREQ.frex)) && ...
                        isequal(size(saved_frex_norm),size(FREQ.frex)) && ...
                        isscalar(saved_beat_frex) && ...
                        abs(saved_beat_frex-info.beat_frex) < 1e-12 && ...
                        max(abs(this_frex_norm-FREQ.frex/info.beat_frex)) < 1e-12 && ...
                        max(abs(saved_frex_norm-this_frex_norm)) < 1e-12 && ...
                        max(abs(this_plot_frex-this_frex_norm)) < 1e-12, ...
                        'Orchestra:InvalidBeatNormalization', ...
                        'Saved physical frequencies and beat ratios disagree: %s.',core_files(filei));
                    required_support_fields = {'minimum_cycles','motion_duration_s', ...
                        'cycles_observed','insufficient_cycles_flag','fft_resolution_hz', ...
                        'fwhm_hz','bins_per_fwhm','bandwidth_below_resolution_flag'};
                    assert(isstruct(info.frequency_support) && isscalar(info.frequency_support) && ...
                        all(isfield(info.frequency_support,required_support_fields)), ...
                        'Orchestra:InvalidFrequencySupport', ...
                        'Beat core lacks cycle-count or filter-resolution metadata: %s.',core_files(filei));
                    this_support_cycles = FREQ.frex*(info.npnts/info.srate);
                    this_minimum_cycles = info.frequency_support.minimum_cycles;
                    validateattributes(this_minimum_cycles,{'numeric'}, ...
                        {'real','finite','scalar','positive'});
                    this_insufficient_cycles = this_support_cycles < this_minimum_cycles;
                    assert(abs(info.frequency_support.motion_duration_s-info.npnts/info.srate) < 1e-12 && ...
                        isequal(size(info.frequency_support.cycles_observed(:)'),size(FREQ.frex)) && ...
                        max(abs(info.frequency_support.cycles_observed(:)'-this_support_cycles)) < 1e-10 && ...
                        isequal(logical(info.frequency_support.insufficient_cycles_flag(:)'),this_insufficient_cycles), ...
                        'Orchestra:InvalidFrequencySupport', ...
                        'Saved cycle-count flags disagree with the motion duration: %s.',core_files(filei));
                    if any(this_insufficient_cycles)
                        warning('Orchestra:InsufficientCycles', ...
                            '%s: %d/%d bins span fewer than %g motion cycles; marked, not omitted.', ...
                            core_files(filei),nnz(this_insufficient_cycles),numel(FREQ.frex),this_minimum_cycles);
                    end
                    % A carrier-cycle count does not establish filter resolution.
                    % Compare saved bandwidths to the segment's Fourier spacing;
                    % this is a separate descriptive warning, never a bin mask.
                    this_fwhm_hz = reshape(h5read(core_files(filei),'/GED/fwhm'),1,[]);
                    validateattributes(this_fwhm_hz,{'numeric'}, ...
                        {'real','finite','positive','numel',numel(FREQ.frex)});
                    this_fft_resolution_hz = info.srate/info.npnts;
                    this_bins_per_fwhm = this_fwhm_hz/this_fft_resolution_hz;
                    this_bandwidth_below_resolution = this_bins_per_fwhm < 1;
                    assert(isscalar(info.frequency_support.fft_resolution_hz) && ...
                        abs(info.frequency_support.fft_resolution_hz-this_fft_resolution_hz) < 1e-12 && ...
                        isequal(size(info.frequency_support.fwhm_hz(:)'),size(FREQ.frex)) && ...
                        max(abs(info.frequency_support.fwhm_hz(:)'-this_fwhm_hz)) < 1e-10 && ...
                        isequal(size(info.frequency_support.bins_per_fwhm(:)'),size(FREQ.frex)) && ...
                        max(abs(info.frequency_support.bins_per_fwhm(:)'-this_bins_per_fwhm)) < 1e-10 && ...
                        isequal(logical(info.frequency_support.bandwidth_below_resolution_flag(:)'), ...
                        this_bandwidth_below_resolution), ...
                        'Orchestra:InvalidFrequencySupport', ...
                        'Saved filter-resolution flags disagree with the bandwidth or duration: %s.',core_files(filei));
                    if any(this_bandwidth_below_resolution)
                        warning('Orchestra:UnresolvedFilterBandwidth', ...
                            '%s: %d/%d filter FWHMs are below the segment Fourier spacing; marked, not omitted.', ...
                            core_files(filei),nnz(this_bandwidth_below_resolution),numel(FREQ.frex));
                    end
                end
                assert(isequal(size(FREQ.evals),[3*numel(info.track_ids) numel(FREQ.frex)]) && ...
                    all(isfinite(FREQ.evals),'all') && all(FREQ.evals >= 0,'all'), ...
                    'Orchestra:InvalidEigenspectrum','Invalid complete eigenspectrum: %s.',core_files(filei));
                assert(max(abs(sum(FREQ.evals,1)-100)) < 1e-8 && ...
                    all(diff(FREQ.evals,1,1) <= 1e-10,'all'), ...
                    'Orchestra:InvalidEigenspectrum','Expected sorted, percent-normalized eigenvalues.');
                [H2,ED] = FREQNESS_EffectDim_Mocap(FREQ,'figure',false);
                % H2 = -ln(sum(p.^2)), p = lambda/sum(lambda), over ALL
                % coordinate eigenvalues at each frequency. Units: nats.
                % Leading component remains percent of the same complete sum.
                [peak_value,idx_peak] = max(FREQ.evals(1,:));
                peak_frequency = FREQ.frex(idx_peak);
                boundary_peak = idx_peak == 1 || idx_peak == numel(FREQ.frex);
                peak_tie_count = nnz(FREQ.evals(1,:) == peak_value);
                peak_note = "empirical grid maximum";
                if boundary_peak; peak_note = peak_note+"; frequency boundary"; end
                if peak_tie_count > 1; peak_note = peak_note+"; first tied bin"; end
                pattern_frequency_label = sprintf('%.3g Hz',peak_frequency);
                if this_frequency_reference == "beat"
                    peak_frequency_normalized = this_frex_norm(idx_peak);
                    pattern_frequency_label = sprintf('%.3g Hz | %.3g x beat', ...
                        peak_frequency,peak_frequency_normalized);
                    if this_insufficient_cycles(idx_peak)
                        peak_note = peak_note+sprintf('; fewer than %g motion cycles at peak',this_minimum_cycles);
                    end
                    if this_bandwidth_below_resolution(idx_peak)
                        peak_note = peak_note+"; peak filter narrower than Fourier spacing";
                    end
                end

                % Derive magnitudes from the signed core before normalizing.
                % Rows remain XYZ triplets; XY magnitude ignores unmeasured Z.
                raw_patterns = h5read(core_files(filei),'/GED/pats');
                ntracks = numel(info.track_ids);
                assert(isreal(raw_patterns) && size(raw_patterns,1) == 3*ntracks && ...
                    size(raw_patterns,2) >= 1 && size(raw_patterns,3) == numel(FREQ.frex) && ...
                    size(raw_patterns,4) == 1 && all(isfinite(raw_patterns),'all'), ...
                    'Orchestra:InvalidPatterns','Expected finite signed coordinate patterns: %s.',core_files(filei));
                pattern_signed = reshape(raw_patterns(:,1,idx_peak),3,ntracks)'; % [tracks x XYZ].
                pattern_abs = abs(pattern_signed);
                pattern_xy_norm = hypot(pattern_signed(:,1),pattern_signed(:,2)); % [tracks x 1].
                coordinate_max = max(pattern_abs,[],'all');
                xy_max = max(pattern_xy_norm,[],1);
                coordinate_denominator = coordinate_max;
                xy_denominator = xy_max;
                if coordinate_denominator == 0; coordinate_denominator = 1; end
                if xy_denominator == 0; xy_denominator = 1; end
                spatial_display = struct('track_ids',info.track_ids(:), ...
                    'signed_weights',pattern_signed,'absolute_weights',pattern_abs, ...
                    'xy_magnitude',pattern_xy_norm, ...
                    'coordinate_max',coordinate_max,'coordinate_denominator',coordinate_denominator, ...
                    'xy_max',xy_max,'xy_denominator',xy_denominator, ...
                    'coordinate_all_zero',coordinate_max == 0,'xy_all_zero',xy_max == 0, ...
                    'coordinate_normalized',pattern_abs/coordinate_denominator, ...
                    'xy_normalized',pattern_xy_norm/xy_denominator);
                this_timing_provenance = struct('srate_confirmation_source',"not_recorded", ...
                    'srate_confirmation_date',"",'camera_metadata_verified',false, ...
                    'audio_alignment_status',"unresolved");
                if isfield(info,'timing_provenance'); this_timing_provenance = info.timing_provenance; end

                % Numeric Day/Rehearsal order; all concerts follow rehearsals.
                recording_tokens = regexp(char(info.recording),'D(\d+)-full-R(\d+)','tokens','once');
                concert_tokens = regexp(char(info.recording),'fullconcert-(\d+)','tokens','once');
                concert_flag = ~isempty(concert_tokens);
                if concert_flag
                    day = 0;
                    repetition = str2double(concert_tokens{1});
                    recording_label = "Concert "+repetition;
                else
                    assert(~isempty(recording_tokens),'Orchestra:UnknownRecordingOrder', ...
                        'Expected D<day>-full-R<rehearsal> or fullconcert-<number>: %s.',info.recording);
                    day = str2double(recording_tokens{1});
                    repetition = str2double(recording_tokens{2});
                    recording_label = "D"+day+" / R"+repetition;
                end
                segment_index = 0;
                segment_label = "";
                if this_stage == "segment_piece"
                    segment_index = info.segment.index;
                    segment_label = string(info.segment.label);
                end
                observation_label = info.piece+" | "+recording_label;
                if this_stage == "segment_piece"
                    observation_label = observation_label+" | segment "+segment_index+": "+segment_label;
                end
                source_stat = dir(core_files(filei));
                visual_info = struct('source',info,'source_bytes',source_stat.bytes, ...
                    'source_modified',source_stat.datenum,'settings',visual_settings, ...
                    'idx_peak',idx_peak,'actual_frex',peak_frequency,'peak_value',peak_value, ...
                    'boundary_peak',boundary_peak,'peak_tie_count',peak_tie_count, ...
                    'spatial_display',spatial_display);
                if this_frequency_reference == "beat"
                    visual_info.frequency_reference = "beat";
                    visual_info.frex_norm = this_frex_norm;
                    visual_info.plot_frex = this_plot_frex;
                    visual_info.beat_frex = info.beat_frex;
                    visual_info.peak_frequency_normalized = peak_frequency_normalized;
                    visual_info.frequency_support = info.frequency_support;
                    visual_info.tempo_provenance = info.tempo_provenance;
                end
                relative_core = erase(core_files(filei),string(path_core)+filesep);
                [relative_folder,core_name] = fileparts(relative_core);
                path_figure = fullfile(CFG.block3.output_path,this_stage,relative_folder,core_name);
                visual_file = fullfile(path_figure,'visualization_info.mat');
                figure_files = strings(2+CFG.block3.plot_matrix_flag,1);
                figure_roles = ["activation"; "xy_norm"];
                if CFG.block3.plot_matrix_flag
                    figure_files(1) = fullfile(path_figure, ...
                        sprintf('pattern_matrix_peak_f%.6gHz_comp1.png',peak_frequency));
                    figure_roles = ["matrix"; figure_roles];
                end
                figure_files(end-1) = fullfile(path_figure, ...
                    sprintf('activation_peak_f%.6gHz_comp1.png',peak_frequency));
                figure_files(end) = fullfile(path_figure, ...
                    sprintf('activation_xy_norm_peak_f%.6gHz_comp1.png',peak_frequency));
                reuse_figures = false;
                if CFG.block3.save_flag && isfile(visual_file) && ~CFG.block3.overwrite_flag
                    saved_visual = load(visual_file,'visual_info','figure_files','figure_roles');
                    assert(isequaln(saved_visual.visual_info,visual_info), ...
                        'Orchestra:IncompatibleVisualization', ...
                        'Visualization settings differ: %s. Inspect before setting overwrite_flag.',visual_file);
                    reuse_figures = isfield(saved_visual,'figure_roles') && ...
                        isequal(saved_visual.figure_roles,figure_roles) && ...
                        isequal(saved_visual.figure_files,figure_files) && all(isfile(figure_files));
                elseif CFG.block3.save_flag && ~CFG.block3.overwrite_flag && any(isfile(figure_files))
                    error('Orchestra:UnidentifiedFigures','Figures lack provenance: %s.',path_figure);
                end
                if ~reuse_figures
                    % Rectification affects this static display copy only.
                    % Signed cores, eigenvectors and component time series stay intact.
                    FREQvis = FREQ;
                    FREQvis.pats = abs(raw_patterns);
                    Patterns = struct('frex',peak_frequency,'comp',1, ...
                        'labels',{saved_core.marklabels},'markerData',saved_core.marker_position, ...
                        'srate',info.srate,'start',.25,'animate',false, ...
                        'plot_bones',false,'plot_matrix',CFG.block3.plot_matrix_flag);
                    % Empty Landscape suppresses per-observation multicomponent
                    % figures. Chronological component-1/H2 overlays follow below.
                    figures = FREQNESS_Visualizer_Mocap(FREQvis,[],Patterns);
                    dimension_titles = {'|X activation|','|Y activation|','|Z| (not measured; placeholder)'};
                    for figurei = 1:numel(figures.patterns)
                        set(figures.patterns(figurei),'Units','pixels','Position',[50 90 1460 640])
                        axes_handles = findall(figures.patterns(figurei),'Type','axes');
                        axes_positions = vertcat(axes_handles.Position);
                        [~,idx_axes] = sort(axes_positions(:,1));
                        axes_handles = axes_handles(idx_axes);
                        for axi = 1:numel(axes_handles)
                            view(axes_handles(axi),2)
                            set(axes_handles(axi),'YDir','reverse','YAxisLocation','left', ...
                                'Projection','orthographic','CameraViewAngleMode','auto', ...
                                'PlotBoxAspectRatioMode','auto', ...
                                'Position',[.055+.29*(axi-1) .18 .235 .65])
                            xlabel(axes_handles(axi),'X (image coordinates)')
                            ylabel(axes_handles(axi),'Y (image coordinates)')
                            title(axes_handles(axi),dimension_titles{axi},'FontSize',11)
                            clim(axes_handles(axi),[0 1])
                            colormap(axes_handles(axi),parula(256))
                        end
                        colorbar_handles = findall(figures.patterns(figurei),'Type','colorbar');
                        for cbi = 1:numel(colorbar_handles)
                            colorbar_handles(cbi).Label.String = '|Weight| / max |coordinate weight|';
                        end
                        sgtitle(figures.patterns(figurei),{char(observation_label); ...
                            sprintf('Component 1 | %s | %s',pattern_frequency_label,peak_note)},'FontSize',14)
                    end
                    for figurei = 1:numel(figures.pattern_matrix)
                        set(figures.pattern_matrix(figurei),'Units','pixels', ...
                            'Position',[80 80 1100 max(500,150+15*numel(saved_core.marklabels))])
                        axes_handles = findall(figures.pattern_matrix(figurei),'Type','axes');
                        for axi = 1:numel(axes_handles)
                            title(axes_handles(axi),dimension_titles{axes_handles(axi).Layout.Tile},'FontSize',11)
                            clim(axes_handles(axi),[0 coordinate_denominator])
                        end
                        colormap(figures.pattern_matrix(figurei),parula(256))
                        colorbar_handles = findall(figures.pattern_matrix(figurei),'Type','colorbar');
                        for cbi = 1:numel(colorbar_handles)
                            colorbar_handles(cbi).Label.String = 'Absolute activation weight (raw units)';
                        end
                        title(axes_handles(1).Parent,{char(observation_label); ...
                            sprintf('Component 1 | %s | %s',pattern_frequency_label,peak_note)},'FontSize',14)
                    end
                    % A separate map combines raw X/Y weights before scaling.
                    % This norm is invariant to rotations of the image axes;
                    % it does not correct perspective or recover out-of-plane motion.
                    xy_figure = figure('Color','w','Units','pixels','Position',[80 90 950 750]);
                    xy_axes = axes('Parent',xy_figure);
                    marker_position = reshape(saved_core.marker_position,3,ntracks)';
                    scatter(xy_axes,marker_position(:,1),marker_position(:,2),95, ...
                        spatial_display.xy_normalized,'filled','MarkerEdgeColor','k','LineWidth',.6)
                    axis(xy_axes,'equal')
                    set(xy_axes,'YDir','reverse','Box','on','FontSize',12)
                    xlabel(xy_axes,'X (image coordinates)')
                    ylabel(xy_axes,'Y (image coordinates)')
                    clim(xy_axes,[0 1]); colormap(xy_axes,parula(256))
                    xy_colorbar = colorbar(xy_axes);
                    xy_colorbar.Label.String = 'sqrt(X weight^2 + Y weight^2) / max across tracks';
                    title(xy_axes,{char(observation_label); ...
                        sprintf('XY pattern magnitude | Component 1 | %s | %s',pattern_frequency_label,peak_note)}, ...
                        'FontSize',14,'Interpreter','none')
                    handles = [figures.pattern_matrix(:); figures.patterns(:); xy_figure];
                    if CFG.block3.save_flag && ~isfolder(path_figure); mkdir(path_figure); end
                    for figurei = 1:numel(handles)
                        set(handles(figurei),'Name',char(observation_label), ...
                            'Tag',char("Orchestra_"+figure_roles(figurei)))
                        set(findall(handles(figurei),'-property','Interpreter'),'Interpreter','none')
                        set(findall(handles(figurei),'-property','TickLabelInterpreter'),'TickLabelInterpreter','none')
                        if CFG.block3.save_flag
                            exportgraphics(handles(figurei),figure_files(figurei),'Resolution',200)
                        end
                        if CFG.block3.close_figures_flag; close(handles(figurei)); end
                    end
                    if CFG.block3.save_flag; save(visual_file,'visual_info','figure_files','figure_roles'); end
                end
                % A labelled matrix is a separate presentation artifact. Keep
                % the established per-observation and landscape caches intact;
                % only the final explorer catalog selects this additional PNG.
                if matrix_labels_flag
                    this_track_ids = info.track_ids(:);
                    validateattributes(this_track_ids,{'numeric'}, ...
                        {'real','finite','vector','nonempty','integer','positive','numel',ntracks});
                    [mask_labelled,idx_label] = ismember(this_track_ids,label_map.track_id);
                    assert(all(mask_labelled) && numel(unique(this_track_ids)) == ntracks, ...
                        'Orchestra:UnmappedMatrixTrack', ...
                        'Expected unique track IDs covered by %s; recording %s has unsupported IDs.', ...
                        CFG.block3.matrix_label_file,info.recording);
                    matrix_labels = "Track_"+string(this_track_ids);
                    matrix_labels(mask_labelled) = matrix_labels(mask_labelled)+" | "+ ...
                        label_map.label(idx_label(mask_labelled));
                    matrix_label_info = struct('settings',matrix_label_settings, ...
                        'source_visualization',visual_info, ...
                        'track_ids',this_track_ids,'labels',matrix_labels, ...
                        'mapped_flag',mask_labelled,'unmapped_ids',this_track_ids(~mask_labelled));
                    matrix_label_png = fullfile(path_figure,sprintf( ...
                        'pattern_matrix_provisional_labels_%s_peak_f%.6gHz_comp1.png', ...
                        matrix_label_signature(1:12),peak_frequency));
                    matrix_label_file = fullfile(path_figure,sprintf( ...
                        'matrix_labels_%s_info.mat',matrix_label_signature(1:12)));
                    reuse_labelled_matrix = false;
                    if CFG.block3.save_flag && isfile(matrix_label_file) && ~CFG.block3.overwrite_flag
                        saved_labels = load(matrix_label_file,'matrix_label_info');
                        assert(isequaln(saved_labels.matrix_label_info,matrix_label_info), ...
                            'Orchestra:IncompatibleMatrixLabels', ...
                            'Labelled matrix provenance differs: %s.',matrix_label_file);
                        reuse_labelled_matrix = isfile(matrix_label_png);
                    elseif CFG.block3.save_flag && ~CFG.block3.overwrite_flag && isfile(matrix_label_png)
                        error('Orchestra:UnidentifiedMatrixLabels', ...
                            'Labelled matrix lacks provenance: %s.',matrix_label_png);
                    end
                    if ~reuse_labelled_matrix
                        % Display [tracks x XYZ] absolute weights unchanged,
                        % using the same shared raw-unit scale as the original.
                        matrix_figure = figure('Color','w','Units','pixels', ...
                            'Position',[80 80 1460 max(580,210+16*ntracks)], ...
                            'Name',char(observation_label),'Tag','Orchestra_matrix_provisional');
                        matrix_layout = tiledlayout(matrix_figure,1,3,'TileSpacing','compact', ...
                            'Padding','compact');
                        matrix_dimension_titles = {'|X activation|','|Y activation|', ...
                            '|Z| (not measured; placeholder)'};
                        for axi = 1:3
                            matrix_axes = nexttile(matrix_layout,axi);
                            imagesc(matrix_axes,pattern_abs(:,axi))
                            set(matrix_axes,'YTick',1:ntracks,'YTickLabel',cellstr(matrix_labels), ...
                                'TickLabelInterpreter','none','FontSize',10,'XTick',1, ...
                                'XTickLabel',{'Component 1'},'YDir','reverse')
                            title(matrix_axes,matrix_dimension_titles{axi},'Interpreter','none','FontSize',12)
                            clim(matrix_axes,[0 coordinate_denominator])
                        end
                        colormap(matrix_figure,parula(256))
                        matrix_colorbar = colorbar(matrix_axes);
                        matrix_colorbar.Layout.Tile = 'east';
                        matrix_colorbar.Label.String = 'Absolute activation weight (raw units)';
                        title(matrix_layout,{char(observation_label); ...
                            sprintf('Component 1 | %s | %s',pattern_frequency_label,peak_note); ...
                            'PROVISIONAL instrument labels: Peter Keller visual review pending'}, ...
                            'Interpreter','none','FontSize',14)
                        if CFG.block3.save_flag
                            if ~isfolder(path_figure); mkdir(path_figure); end
                            exportgraphics(matrix_figure,matrix_label_png,'Resolution',200)
                            save(matrix_label_file,'matrix_label_info')
                        end
                        if CFG.block3.close_figures_flag; close(matrix_figure); end
                    end
                    matrix_label_records{selected_count+1} = struct( ...
                        'status',"provisional",'review_status',"pending_visual_inspection", ...
                        'reviewer',"Peter Keller",'review_required',"Peter Keller visual inspection", ...
                        'track_ids',this_track_ids, ...
                        'labels',matrix_labels,'mapped_flag',mask_labelled, ...
                        'source_file',matrix_label_settings.source_file, ...
                        'source_sha256',string(label_sha256), ...
                        'mapping_sha256',string(matrix_label_signature), ...
                        'provenance_file',string(matrix_label_file), ...
                        'figure_file',string(matrix_label_png));
                end
                selected_count = selected_count+1;
                observations{selected_count} = struct('stage',this_stage,'piece',info.piece, ...
                    'recording',info.recording,'recording_label',recording_label, ...
                    'concert_flag',concert_flag,'day',day,'repetition',repetition, ...
                    'segment_index',segment_index,'segment_label',segment_label, ...
                    'ntracks',numel(info.track_ids),'npnts',info.npnts, ...
                    'srate',info.srate,'srate_confirmed',info.srate_confirmed, ...
                    'filter_width_calibration',string(info.filterWidthCalibration), ...
                    'filter_type',string(info.filter),'timing_provenance',this_timing_provenance, ...
                    'frex',FREQ.frex,'component1',FREQ.evals(1,:), ...
                    'H2',H2(:)','ED',ED(:)','idx_peak',idx_peak,'peak_frequency',peak_frequency, ...
                    'peak_value',peak_value,'boundary_peak',boundary_peak, ...
                    'peak_tie_count',peak_tie_count,'core_file',core_files(filei), ...
                    'source_bytes',source_stat.bytes,'source_modified',source_stat.datenum, ...
                    'figure_files',figure_files,'figure_roles',figure_roles, ...
                    'spatial_display',spatial_display);
                if this_frequency_reference == "beat"
                    observations{selected_count}.frequency_reference = "beat";
                    observations{selected_count}.frex_norm = this_frex_norm;
                    observations{selected_count}.plot_frex = this_plot_frex;
                    observations{selected_count}.beat_frex = info.beat_frex;
                    observations{selected_count}.peak_frequency_normalized = peak_frequency_normalized;
                    observations{selected_count}.frequency_support = info.frequency_support;
                    observations{selected_count}.support_cycles = this_support_cycles;
                    observations{selected_count}.insufficient_cycles = this_insufficient_cycles;
                    observations{selected_count}.bandwidth_below_resolution = this_bandwidth_below_resolution;
                    observations{selected_count}.tempo_provenance = info.tempo_provenance;
                end
                fprintf('%s: %s | peak %.3g Hz%s\n',this_stage,observation_label, ...
                    peak_frequency,repmat(' [boundary]',1,boundary_peak));
                clear FREQ FREQvis raw_patterns saved_core
            end
            if selected_count == 0
                warning('Orchestra:NoCoreOutputs','No selected saved cores in %s.',path_core);
                continue
            end
            observations = vertcat(observations{1:selected_count});
            order = table(string({observations.piece})',[observations.concert_flag]', ...
                [observations.day]',[observations.repetition]',[observations.segment_index]');
            [~,idx_order] = sortrows(order,1:5);
            observations = observations(idx_order);
            if matrix_labels_flag
                matrix_label_records = matrix_label_records(1:selected_count);
                matrix_label_records = matrix_label_records(idx_order);
            end

            % One overlay per piece for full recordings; one per recording
            % for musical segments. These are individual curves, never means.
            if this_stage == "full_piece"
                group_keys = string({observations.piece});
            else
                group_keys = string({observations.piece})+"/"+string({observations.recording});
            end
            groups = unique(group_keys,'stable');
            overlays = cell(numel(groups),1);
            for groupi = 1:numel(groups)
                idx_group = find(group_keys == groups(groupi));
                this_observations = observations(idx_group);
                ncurves = numel(idx_group);
                colors = zeros(ncurves,3);
                labels = strings(ncurves,1);
                styles = repmat("-",ncurves,1);
                if this_stage == "full_piece"
                    idx_rehearsal = find(~[this_observations.concert_flag]);
                    progression = linspace(0,1,max(2,numel(idx_rehearsal)))';
                    if isscalar(idx_rehearsal); progression = 0; end
                    colors(idx_rehearsal,:) = (1-progression(1:numel(idx_rehearsal)))*CFG.block3.color_first + ...
                        progression(1:numel(idx_rehearsal))*CFG.block3.color_last;
                    idx_concert = find([this_observations.concert_flag]);
                    colors(idx_concert,:) = repmat(CFG.block3.color_concert,numel(idx_concert),1);
                    if numel(idx_concert) > 1; styles(idx_concert(2:2:end)) = "--"; end
                    labels(:) = string({this_observations.recording_label});
                    group_title = this_observations(1).piece+" | full recordings in temporal order";
                    relative_folder = this_observations(1).piece;
                else
                    % Preserve the manifest order, including a gap for a missing
                    % first segment; do not re-label the next segment as first.
                    progression = ([this_observations.segment_index]'-1)/ ...
                        max(1,max([this_observations.segment_index])-1);
                    colors = (1-progression)*CFG.block3.color_first + progression*CFG.block3.color_last;
                    labels(:) = compose('%02d | %s',[this_observations.segment_index]', ...
                        string({this_observations.segment_label})');
                    group_title = this_observations(1).piece+" | "+ ...
                        this_observations(1).recording_label+" | musical segments in score order";
                    relative_folder = fullfile(this_observations(1).piece,this_observations(1).recording);
                end
                if display_frequency_reference == "beat"
                    assert(all(arrayfun(@(x) isequal(x.plot_frex,this_observations(1).plot_frex) && ...
                        x.frequency_reference == "beat" && x.srate == this_observations(1).srate && ...
                        x.srate_confirmed == this_observations(1).srate_confirmed,this_observations)), ...
                        'Beat overlays must share the beat-ratio grid and sampling assumptions.');
                    support_thresholds = arrayfun(@(x) x.frequency_support.minimum_cycles,this_observations);
                    if numel(unique(support_thresholds)) > 1
                        labels = labels+compose(' [minimum %g cycles]',support_thresholds(:));
                    end
                else
                    assert(all(arrayfun(@(x) isequal(x.frex,this_observations(1).frex) && ...
                        x.srate == this_observations(1).srate && ...
                        x.srate_confirmed == this_observations(1).srate_confirmed,this_observations)), ...
                        'Overlaid observations must share frequency grid and sampling assumptions.');
                end
                path_overlay = fullfile(CFG.block3.output_path,this_stage,relative_folder,'overlays');
                overlay_files = fullfile(path_overlay,["landscape_component1.png";"landscape_H2.png"]);
                overlay_file = fullfile(path_overlay,'landscape_data.mat');
                overlay_info = struct('settings',visual_settings,'observations',this_observations, ...
                    'colors',colors,'labels',labels,'styles',styles,'font_sizes',[24 24 28]);
                if display_frequency_reference == "beat"; overlay_info.font_sizes(3) = 18; end
                reuse_overlay = false;
                if CFG.block3.save_flag && isfile(overlay_file) && ~CFG.block3.overwrite_flag
                    saved_overlay = load(overlay_file,'overlay_info');
                    assert(isequaln(saved_overlay.overlay_info,overlay_info), ...
                        'Orchestra:IncompatibleVisualization', ...
                        'Overlay selection/settings differ: %s. Inspect before setting overwrite_flag.',overlay_file);
                    reuse_overlay = all(isfile(overlay_files));
                elseif CFG.block3.save_flag && ~CFG.block3.overwrite_flag && any(isfile(overlay_files))
                    error('Orchestra:UnidentifiedFigures','Overlay lacks provenance: %s.',path_overlay);
                end
                if ~reuse_overlay
                    if CFG.block3.save_flag && ~isfolder(path_overlay); mkdir(path_overlay); end
                    for measurei = 1:2
                        this_figure = figure('Color','w','Position',[50 50 1250 700]);
                        ax = axes('Parent',this_figure); hold(ax,'on')
                        for curvei = 1:ncurves
                            if measurei == 1
                                this_values = this_observations(curvei).component1;
                            else
                                this_values = this_observations(curvei).H2;
                            end
                            curve_frex = this_observations(curvei).frex;
                            if display_frequency_reference == "beat"
                                curve_frex = this_observations(curvei).plot_frex;
                            end
                            plot(ax,curve_frex,this_values,'Color',colors(curvei,:), ...
                                'LineStyle',styles(curvei),'LineWidth',1.8,'DisplayName',labels(curvei));
                            if display_frequency_reference == "beat"
                                mask_short = this_observations(curvei).insufficient_cycles;
                                plot(ax,curve_frex(mask_short),this_values(mask_short), ...
                                    'LineStyle','none','Marker','x','MarkerSize',7, ...
                                    'Color',colors(curvei,:),'LineWidth',1.2,'HandleVisibility','off');
                                mask_narrow = this_observations(curvei).bandwidth_below_resolution;
                                plot(ax,curve_frex(mask_narrow),this_values(mask_narrow), ...
                                    'LineStyle','none','Marker','^','MarkerSize',9, ...
                                    'Color',colors(curvei,:),'LineWidth',1.2,'HandleVisibility','off');
                            end
                        end
                        % Plot native analyzed bins without smoothing/interpolation.
                        xlim(ax,[curve_frex(1) curve_frex(end)])
                        if measurei == 1
                            ylabel(ax,'Component 1 (% of complete eigenvalue sum)')
                            ylim(ax,[0 100]); measure_title = "Leading-component landscape";
                        else
                            ylabel(ax,'H2 entropy (nats; complete eigenspectrum)')
                            ylim(ax,[0 log(3*max([observations.ntracks]))]); measure_title = "H2 entropy landscape";
                        end
                        if display_frequency_reference == "beat"
                            xlabel(ax,'Frequency / segment beat frequency (dimensionless)')
                        elseif this_observations(1).srate_confirmed
                            xlabel(ax,'Frequency (Hz)')
                        else
                            xlabel(ax,sprintf('Nominal frequency (Hz; assumed sampling rate %g Hz)',this_observations(1).srate))
                        end
                        title_lines = {char(group_title);char(measure_title)};
                        if display_frequency_reference == "beat" && ...
                                any(arrayfun(@(x) any(x.insufficient_cycles),this_observations))
                            if numel(unique(support_thresholds)) == 1
                                title_lines{end+1} = sprintf( ...
                                    'x: fewer than %g motion cycles; descriptive support warning',support_thresholds(1));
                            else
                                title_lines{end+1} = ...
                                    'x: below saved segment-specific cycle threshold (see legend)';
                            end
                        end
                        title_font_size = 28;
                        if display_frequency_reference == "beat"
                            title_font_size = 18; % Make both support warnings readable.
                            if any(arrayfun(@(x) any(x.bandwidth_below_resolution),this_observations))
                                title_lines{end+1} = ...
                                    'Triangles: filter FWHM < 1/duration; limited frequency resolution';
                            end
                        end
                        title(ax,title_lines,'Interpreter','none','FontSize',title_font_size)
                        legend(ax,'Location','eastoutside','Interpreter','none','FontSize',24)
                        set(ax,'FontSize',24,'Box','off','TickDir','out'); grid(ax,'on')
                        if CFG.block3.save_flag
                            exportgraphics(this_figure,overlay_files(measurei),'Resolution',200)
                        end
                        if CFG.block3.close_figures_flag; close(this_figure); end
                    end
                    if CFG.block3.save_flag; save(overlay_file,'overlay_info','overlay_files'); end
                end
                overlays{groupi} = struct('stage',this_stage,'piece',this_observations(1).piece, ...
                    'recording',"",'title',group_title,'ncurves',ncurves,'labels',labels, ...
                    'colors',colors,'figure_files',overlay_files);
                if this_stage == "segment_piece"; overlays{groupi}.recording = this_observations(1).recording; end
                if display_frequency_reference == "beat"
                    overlays{groupi}.frequency_reference = "beat";
                    overlays{groupi}.insufficient_cycles_flag = ...
                        any(arrayfun(@(x) any(x.insufficient_cycles),this_observations));
                    overlays{groupi}.bandwidth_below_resolution_flag = ...
                        any(arrayfun(@(x) any(x.bandwidth_below_resolution),this_observations));
                end
            end
            if CFG.block3.save_flag
                catalog = struct('stage',this_stage,'settings',visual_settings, ...
                    'observations',observations,'overlays',vertcat(overlays{:}));
                if matrix_labels_flag
                    catalog.matrix_label_settings = matrix_label_settings;
                    for obsi = 1:numel(catalog.observations)
                        label_record = matrix_label_records{obsi};
                        mask_matrix = catalog.observations(obsi).figure_roles == "matrix";
                        catalog.observations(obsi).figure_files(mask_matrix) = label_record.figure_file;
                        catalog.observations(obsi).matrix_labels = label_record;
                    end
                end
                catalog_file = fullfile(CFG.block3.output_path,this_stage,'figure_catalog.json');
                file_id = fopen(catalog_file,'w');
                assert(file_id >= 0,'Cannot write %s.',catalog_file);
                fprintf(file_id,'%s',jsonencode(catalog));
                fclose(file_id);
            end
        end
    catch exception
        set(groot,'DefaultFigureVisible',original_visibility)
        rethrow(exception)
    end
    set(groot,'DefaultFigureVisible',original_visibility)
end
