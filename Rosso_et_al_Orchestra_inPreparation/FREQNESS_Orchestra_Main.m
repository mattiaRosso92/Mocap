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
addpath(fullfile(path_toolbox,'FREQNESS_Functions'))
addpath(fullfile(path_toolbox,'FREQNESS_ExternalFunctions'))

CFG = [];
CFG.common.data_path = fullfile(path_study,'concertproject_kiersten','data');
CFG.common.output_path = fullfile(path_study,'FREQNESS_Output');
CFG.common.pieces = ["carmen" "giant" "juliet" "siviglia" "strings"];
CFG.common.recordings = strings(0,1); % Empty = all; otherwise exact file stems.

% Retain the original orchestra script's sampling rate. The handover also
% contains ~30 fps audio/CSV mappings and 40 fps display metadata. This is
% an explicit analysis assumption until the processed-data clock is agreed;
% the pipeline does not resample, time-warp, despike, or repair input data.
CFG.common.srate = 25;
CFG.common.srate_confirmed_flag = false;
CFG.common.frex = .5:.1:10;
CFG.common.ncomps = 4; % Spatial patterns/time series; all eigenvalues survive.
CFG.common.regularisation = .01;
CFG.common.filter_width_calibration = validatestring( ...
    'legacy',{'physical','legacy'});
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
CFG.block3.landscape_ncomps = 20;
CFG.block3.pattern_frex = 2;
CFG.block3.pattern_comp = 1;
CFG.block3.plot_matrix_flag = true;
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
if ~CFG.common.srate_confirmed_flag
    warning('Orchestra:UnconfirmedSamplingRate', ...
        ['Using the configured %g Hz analysis clock. Confirm it against ' ...
         'the processed-data timing before interpreting Hz or seconds.'], ...
        CFG.common.srate);
end

% A settings signature separates arbitrary frequency grids and parameter
% choices, including changes that share the same first/last frequencies.
core_settings = struct('srate',CFG.common.srate, ...
    'srate_confirmed',CFG.common.srate_confirmed_flag, ...
    'frex',CFG.common.frex(:),'ncomps',CFG.common.ncomps, ...
    'regularisation',CFG.common.regularisation, ...
    'filter_width_calibration',CFG.common.filter_width_calibration, ...
    'filter_type',CFG.common.filter_type, ...
    'coordinate_policy','all_csv_xy_tracks_zero_z_no_preprocessing');
signature_engine = java.security.MessageDigest.getInstance('SHA-256');
signature_engine.update(uint8(jsonencode(core_settings)));
signature_bytes = typecast(signature_engine.digest(),'uint8');
settings_signature = lower(reshape(dec2hex(signature_bytes,2)',1,[]));
filter_output_tag = [CFG.common.filter_width_calibration '_' ...
    CFG.common.filter_type];
analysis_tag = sprintf('fs%g_f%g-%g_n%d_%s',CFG.common.srate, ...
    CFG.common.frex(1),CFG.common.frex(end),numel(CFG.common.frex), ...
    settings_signature(1:12));
CFG.common.results_path = fullfile(CFG.common.output_path, ...
    filter_output_tag,analysis_tag);
CFG.block1.output_path = fullfile(CFG.common.results_path,'01_Core_FullPiece');
CFG.block2.output_path = fullfile(CFG.common.results_path,'02_Core_SegmentPiece');
CFG.block3.output_path = fullfile(CFG.common.results_path,'03_Visualization');

% Keep the estimator source with each core for version provenance. This
% reads the currently installed toolbox; no toolbox function is modified.
core_source = fileread(which('FREQNESS_NetworkEstimation_Mocap'));


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
        analysis_info = struct('contract_version',1,'stage',"full_piece", ...
            'piece',this_piece,'recording',this_recording, ...
            'source_file',string(source_file),'source_bytes',source_info.bytes, ...
            'source_modified',source_info.datenum,'track_ids',track_ids, ...
            'frame_first',frame(1),'frame_last',frame(end),'npnts',npnts, ...
            'srate',srate,'srate_confirmed',CFG.common.srate_confirmed_flag, ...
            'frex',frex,'ncomps',CFG.common.ncomps, ...
            'regularisation',CFG.common.regularisation, ...
            'filterWidthCalibration',string(filter_width_calibration), ...
            'filter',string(filter_type),'fwidth',expected_filter_width, ...
            'coordinate_policy',"all_csv_xy_tracks_zero_z_no_preprocessing", ...
            'segment',struct(),'core_source',core_source);

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
            'fwidth',filter_width,'filter',filter_type, ...
            'ncomps',CFG.common.ncomps,'regularisation',CFG.common.regularisation, ...
            'interpolate_gaps',false);
        assert(isequal(GED.fwhm,expected_filter_width), ...
            'Core output did not use the requested filter-width calibration.');
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
            analysis_info = struct('contract_version',1,'stage',"segment_piece", ...
                'piece',this_piece,'recording',this_recording, ...
                'source_file',string(source_file),'source_bytes',source_info.bytes, ...
                'source_modified',source_info.datenum,'track_ids',track_ids, ...
                'frame_first',frame(1),'frame_last',frame(end),'npnts',npnts, ...
                'srate',srate,'srate_confirmed',CFG.common.srate_confirmed_flag, ...
                'frex',frex,'ncomps',CFG.common.ncomps, ...
                'regularisation',CFG.common.regularisation, ...
                'filterWidthCalibration',string(filter_width_calibration), ...
                'filter',string(filter_type),'fwidth',expected_filter_width, ...
                'coordinate_policy',"all_csv_xy_tracks_zero_z_no_preprocessing", ...
                'segment',segment_info,'core_source',core_source);

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
                'fwidth',filter_width,'filter',filter_type, ...
                'ncomps',CFG.common.ncomps,'regularisation',CFG.common.regularisation, ...
                'interpolate_gaps',false);
            assert(isequal(GED.fwhm,expected_filter_width), ...
                'Core output did not use the requested filter-width calibration.');
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
            SEG.Status(segi) = "saved";
            clear GED markData this_data this_values saved_core

        end
        segment_tables{filei} = SEG;
    end
    SEG = vertcat(segment_tables{:});
    if ~isfolder(CFG.block2.output_path); mkdir(CFG.block2.output_path); end
    writetable(SEG,fullfile(CFG.block2.output_path,'core_index.csv'))
    fprintf('\nSections: %d saved, %d reused, %d missing, %d not selected.\n', ...
        nnz(SEG.Status == "saved"),nnz(SEG.Status == "existing"), ...
        nnz(SEG.Status == "missing_source"),nnz(SEG.Status == "not_selected"));
end


%% BLOCK 3 - VISUALIZE SAVED LANDSCAPES AND ACTIVATION PATTERNS

if CFG.block3.run_flag
    assert(all(ismember(string(CFG.block3.stages),["full_piece" "segment_piece"])), ...
        'CFG.block3.stages must contain full_piece and/or segment_piece.');
    validateattributes(CFG.block3.pattern_frex,{'numeric'}, ...
        {'real','finite','vector','positive','nonempty'});
    validateattributes(CFG.block3.pattern_comp,{'numeric'},{'scalar','integer','positive'});
    validateattributes(CFG.block3.landscape_ncomps,{'numeric'},{'scalar','integer','positive'});
    assert(CFG.block3.save_flag || ~CFG.block3.close_figures_flag, ...
        'Unsaved figures must remain open: disable close_figures_flag.');
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
            if isempty(files)
                warning('Orchestra:NoCoreOutputs','No saved cores found in %s.',path_core);
            end
            core_files = sort(string(fullfile({files.folder},{files.name})))';
            for filei = 1:numel(core_files)
                saved_core = load(core_files(filei),'analysis_info','marker_position','marklabels');
                info = saved_core.analysis_info;
                if ~isempty(CFG.block3.recordings) && ...
                        ~ismember(info.recording,string(CFG.block3.recordings))
                    continue
                end
                if this_stage == "segment_piece" && ...
                        ~isempty(CFG.block3.segment_labels) && ...
                        ~ismember(string(info.segment.label),string(CFG.block3.segment_labels))
                    continue
                end
                assert(CFG.block3.pattern_comp <= info.ncomps, ...
                    'Requested component was not retained in %s.',core_files(filei));
                requested_frex = CFG.block3.pattern_frex(:)';
                idx_frex = zeros(size(requested_frex));
                for frexi = 1:numel(requested_frex)
                    [frequency_error,idx_frex(frexi)] = min(abs(info.frex-requested_frex(frexi)));
                    if frequency_error > 1e-10*max(1,abs(requested_frex(frexi)))
                        warning('Orchestra:NearestFrequency', ...
                            '%s: requested %.6g Hz; visualizing %.6g Hz.', ...
                            core_files(filei),requested_frex(frexi),info.frex(idx_frex(frexi)));
                    end
                end
                actual_frex = info.frex(idx_frex);
                visual_info = struct('source',info,'requested_frex',requested_frex, ...
                    'actual_frex',actual_frex,'component',CFG.block3.pattern_comp, ...
                    'landscape_ncomps',CFG.block3.landscape_ncomps, ...
                    'plot_matrix',CFG.block3.plot_matrix_flag,'presentation_version',1);
                relative_core = erase(core_files(filei),string(path_core)+filesep);
                [relative_folder,core_name] = fileparts(relative_core);
                path_figure = fullfile(CFG.block3.output_path,this_stage, ...
                    relative_folder,core_name);
                visual_file = fullfile(path_figure,'visualization_info.mat');
                if CFG.block3.save_flag && ~CFG.block3.overwrite_flag && ...
                        ~isfile(visual_file) && ~isempty(dir(fullfile(path_figure,'*.png')))
                    error('Orchestra:UnidentifiedFigures', ...
                        'Figures exist without provenance in %s. Inspect before overwriting.',path_figure);
                end
                if CFG.block3.save_flag && isfile(visual_file) && ~CFG.block3.overwrite_flag
                    saved_visual = load(visual_file,'visual_info','figure_files');
                    assert(isequaln(saved_visual.visual_info,visual_info), ...
                        'Existing visualization settings differ: %s. Set overwrite_flag to replace.',visual_file);
                    if all(isfile(saved_visual.figure_files))
                        continue
                    end
                end
                loaded = load(core_files(filei),'GED');
                GED = loaded.GED;
                Landscape = [];
                Landscape.frex = GED.frex;
                Landscape.ncomps = min(CFG.block3.landscape_ncomps,size(GED.evals,1));
                Landscape.title = sprintf('%s | %s',this_stage,core_name);
                if ~info.srate_confirmed
                    Landscape.xlabel = sprintf('Frequency (Hz; assumed sampling rate %g Hz)',info.srate);
                end
                Patterns = [];
                Patterns.frex = unique(actual_frex,'stable');
                Patterns.comp = CFG.block3.pattern_comp;
                Patterns.labels = saved_core.marklabels;
                Patterns.markerData = saved_core.marker_position;
                Patterns.srate = info.srate;
                Patterns.start = .25;
                Patterns.animate = false; % Static patterns, no interactive prompt.
                Patterns.plot_bones = false; % Ensemble tracks are not a skeleton.
                Patterns.plot_matrix = CFG.block3.plot_matrix_flag;
                figures = FREQNESS_Visualizer_Mocap(GED,Landscape,Patterns);

                % Display coordinates as in the overhead images. This only
                % changes the viewing axes; saved data and signed patterns stay intact.
                dimension_titles = {'X activation','Y activation', ...
                    'Z (not measured; zero placeholder)'};
                for figurei = 1:numel(figures.patterns)
                    set(figures.patterns(figurei),'Units','pixels','Position',[50 90 1460 640])
                    axes_handles = findall(figures.patterns(figurei),'Type','axes');
                    axes_positions = vertcat(axes_handles.Position);
                    [~,idx_axes] = sort(axes_positions(:,1)); % Original X/Y/Z order.
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
                    end
                end
                % Allow a readable row for every track, independent of ensemble size.
                for figurei = 1:numel(figures.pattern_matrix)
                    set(figures.pattern_matrix(figurei),'Units','pixels', ...
                        'Position',[80 80 1100 max(500,150+15*numel(saved_core.marklabels))])
                    axes_handles = findall(figures.pattern_matrix(figurei),'Type','axes');
                    for axi = 1:numel(axes_handles)
                        title(axes_handles(axi), ...
                            dimension_titles{axes_handles(axi).Layout.Tile},'FontSize',11)
                    end
                end
                handles = [figures.landscape(:); figures.pattern_matrix(:); figures.patterns(:)];
                figure_names = strings(numel(handles),1);
                figure_names(1) = "landscape.png";
                nfrex = numel(Patterns.frex);
                if Patterns.plot_matrix
                    figure_names(2:1+nfrex) = compose("pattern_matrix_f%.6gHz_comp%d.png", ...
                        Patterns.frex(:),repmat(Patterns.comp,nfrex,1));
                end
                figure_names(end-nfrex+1:end) = compose("activation_f%.6gHz_comp%d.png", ...
                    Patterns.frex(:),repmat(Patterns.comp,nfrex,1));
                figure_files = strings(numel(handles),1);
                if CFG.block3.save_flag && ~isfolder(path_figure); mkdir(path_figure); end
                for figurei = 1:numel(handles)
                    set(handles(figurei),'Name',char(this_stage+" | "+info.recording))
                    % File stems and track IDs contain literal underscores.
                    set(findall(handles(figurei),'-property','Interpreter'),'Interpreter','none')
                    set(findall(handles(figurei),'-property','TickLabelInterpreter'), ...
                        'TickLabelInterpreter','none')
                    figure_files(figurei) = fullfile(path_figure,figure_names(figurei));
                    if CFG.block3.save_flag && ...
                            (~isfile(figure_files(figurei)) || CFG.block3.overwrite_flag)
                        exportgraphics(handles(figurei),figure_files(figurei),'Resolution',200)
                    end
                    if CFG.block3.close_figures_flag; close(handles(figurei)); end
                end
                if CFG.block3.save_flag
                    save(visual_file,'visual_info','figure_files')
                end
                clear GED loaded saved_core
            end
        end
    catch exception
        set(groot,'DefaultFigureVisible',original_visibility)
        rethrow(exception)
    end
    set(groot,'DefaultFigureVisible',original_visibility)
end
