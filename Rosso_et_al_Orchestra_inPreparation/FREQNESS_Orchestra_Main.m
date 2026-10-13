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
% Component 1 only; H2 always uses the complete saved eigenspectrum.
% Patterns use the maximum observed component-1 bin (first bin for ties).
CFG.block3.color_first = [.85 .12 .15]; % First rehearsal / musical segment.
CFG.block3.color_last = [.35 .75 .94];  % Last rehearsal / musical segment.
CFG.block3.color_concert = [.50 .22 .70]; % Concerts follow all rehearsals.
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
CFG.block3.output_path = fullfile(CFG.common.results_path, ...
    '03_Visualization','leading_H2_empirical_peak');

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


%% BLOCK 3 - CHRONOLOGICAL LANDSCAPES AND EMPIRICAL-PEAK PATTERNS

if CFG.block3.run_flag
    assert(all(ismember(string(CFG.block3.stages),["full_piece" "segment_piece"])), ...
        'CFG.block3.stages must contain full_piece and/or segment_piece.');
    assert(CFG.block3.save_flag || ~CFG.block3.close_figures_flag, ...
        'Unsaved figures must remain open: disable close_figures_flag.');
    original_visibility = get(groot,'DefaultFigureVisible');
    set(groot,'DefaultFigureVisible',CFG.block3.figure_visibility)
    visual_settings = struct('presentation_version',2, ...
        'component',1,'peak_method',"maximum_analyzed_bin_first_tie", ...
        'entropy_method',"complete_eigenspectrum_H2_natural_log", ...
        'color_first',CFG.block3.color_first,'color_last',CFG.block3.color_last, ...
        'color_concert',CFG.block3.color_concert,'plot_matrix',CFG.block3.plot_matrix_flag, ...
        'visualizer_source',fileread(which('FREQNESS_Visualizer_Mocap')), ...
        'entropy_source',fileread(which('FREQNESS_EffectDim_Mocap')));
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
                    'boundary_peak',boundary_peak,'peak_tie_count',peak_tie_count);
                relative_core = erase(core_files(filei),string(path_core)+filesep);
                [relative_folder,core_name] = fileparts(relative_core);
                path_figure = fullfile(CFG.block3.output_path,this_stage,relative_folder,core_name);
                visual_file = fullfile(path_figure,'visualization_info.mat');
                figure_files = strings(1+CFG.block3.plot_matrix_flag,1);
                if CFG.block3.plot_matrix_flag
                    figure_files(1) = fullfile(path_figure, ...
                        sprintf('pattern_matrix_peak_f%.6gHz_comp1.png',peak_frequency));
                end
                figure_files(end) = fullfile(path_figure, ...
                    sprintf('activation_peak_f%.6gHz_comp1.png',peak_frequency));
                reuse_figures = false;
                if CFG.block3.save_flag && isfile(visual_file) && ~CFG.block3.overwrite_flag
                    saved_visual = load(visual_file,'visual_info','figure_files');
                    assert(isequaln(saved_visual.visual_info,visual_info), ...
                        'Orchestra:IncompatibleVisualization', ...
                        'Visualization settings differ: %s. Inspect before setting overwrite_flag.',visual_file);
                    reuse_figures = isequal(saved_visual.figure_files,figure_files) && all(isfile(figure_files));
                elseif CFG.block3.save_flag && ~CFG.block3.overwrite_flag && any(isfile(figure_files))
                    error('Orchestra:UnidentifiedFigures','Figures lack provenance: %s.',path_figure);
                end
                if ~reuse_figures
                    FREQ.pats = h5read(core_files(filei),'/GED/pats');
                    Patterns = struct('frex',peak_frequency,'comp',1, ...
                        'labels',{saved_core.marklabels},'markerData',saved_core.marker_position, ...
                        'srate',info.srate,'start',.25,'animate',false, ...
                        'plot_bones',false,'plot_matrix',CFG.block3.plot_matrix_flag);
                    % Empty Landscape suppresses per-observation multicomponent
                    % figures. Chronological component-1/H2 overlays follow below.
                    figures = FREQNESS_Visualizer_Mocap(FREQ,[],Patterns);
                    dimension_titles = {'X activation','Y activation','Z (not measured; zero placeholder)'};
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
                        end
                        sgtitle(figures.patterns(figurei),{char(observation_label); ...
                            sprintf('Component 1 | %.3g Hz | %s',peak_frequency,peak_note)},'FontSize',14)
                    end
                    for figurei = 1:numel(figures.pattern_matrix)
                        set(figures.pattern_matrix(figurei),'Units','pixels', ...
                            'Position',[80 80 1100 max(500,150+15*numel(saved_core.marklabels))])
                        axes_handles = findall(figures.pattern_matrix(figurei),'Type','axes');
                        for axi = 1:numel(axes_handles)
                            title(axes_handles(axi),dimension_titles{axes_handles(axi).Layout.Tile},'FontSize',11)
                        end
                        title(axes_handles(1).Parent,{char(observation_label); ...
                            sprintf('Component 1 | %.3g Hz | %s',peak_frequency,peak_note)},'FontSize',14)
                    end
                    handles = [figures.pattern_matrix(:); figures.patterns(:)];
                    if CFG.block3.save_flag && ~isfolder(path_figure); mkdir(path_figure); end
                    for figurei = 1:numel(handles)
                        set(handles(figurei),'Name',char(observation_label))
                        set(findall(handles(figurei),'-property','Interpreter'),'Interpreter','none')
                        set(findall(handles(figurei),'-property','TickLabelInterpreter'),'TickLabelInterpreter','none')
                        if CFG.block3.save_flag
                            exportgraphics(handles(figurei),figure_files(figurei),'Resolution',200)
                        end
                        if CFG.block3.close_figures_flag; close(handles(figurei)); end
                    end
                    if CFG.block3.save_flag; save(visual_file,'visual_info','figure_files'); end
                end
                selected_count = selected_count+1;
                observations{selected_count} = struct('stage',this_stage,'piece',info.piece, ...
                    'recording',info.recording,'recording_label',recording_label, ...
                    'concert_flag',concert_flag,'day',day,'repetition',repetition, ...
                    'segment_index',segment_index,'segment_label',segment_label, ...
                    'ntracks',numel(info.track_ids),'npnts',info.npnts, ...
                    'srate',info.srate,'srate_confirmed',info.srate_confirmed, ...
                    'frex',FREQ.frex,'component1',FREQ.evals(1,:), ...
                    'H2',H2(:)','ED',ED(:)','idx_peak',idx_peak,'peak_frequency',peak_frequency, ...
                    'peak_value',peak_value,'boundary_peak',boundary_peak, ...
                    'peak_tie_count',peak_tie_count,'core_file',core_files(filei), ...
                    'source_bytes',source_stat.bytes,'source_modified',source_stat.datenum, ...
                    'figure_files',figure_files);
                fprintf('%s: %s | peak %.3g Hz%s\n',this_stage,observation_label, ...
                    peak_frequency,repmat(' [boundary]',1,boundary_peak));
                clear FREQ saved_core
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
                assert(all(arrayfun(@(x) isequal(x.frex,this_observations(1).frex) && ...
                    x.srate == this_observations(1).srate && ...
                    x.srate_confirmed == this_observations(1).srate_confirmed,this_observations)), ...
                    'Overlaid observations must share frequency grid and sampling assumptions.');
                path_overlay = fullfile(CFG.block3.output_path,this_stage,relative_folder,'overlays');
                overlay_files = fullfile(path_overlay,["landscape_component1.png";"landscape_H2.png"]);
                overlay_file = fullfile(path_overlay,'landscape_data.mat');
                overlay_info = struct('settings',visual_settings,'observations',this_observations, ...
                    'colors',colors,'labels',labels,'styles',styles,'font_sizes',[24 24 28]);
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
                            plot(ax,this_observations(curvei).frex,this_values,'Color',colors(curvei,:), ...
                                'LineStyle',styles(curvei),'LineWidth',1.8,'DisplayName',labels(curvei));
                        end
                        % Plot native analyzed bins without smoothing/interpolation.
                        xlim(ax,[this_observations(1).frex(1) this_observations(1).frex(end)])
                        if measurei == 1
                            ylabel(ax,'Component 1 (% of complete eigenvalue sum)')
                            ylim(ax,[0 100]); measure_title = "Leading-component landscape";
                        else
                            ylabel(ax,'H2 entropy (nats; complete eigenspectrum)')
                            ylim(ax,[0 log(3*max([observations.ntracks]))]); measure_title = "H2 entropy landscape";
                        end
                        if this_observations(1).srate_confirmed
                            xlabel(ax,'Frequency (Hz)')
                        else
                            xlabel(ax,sprintf('Nominal frequency (Hz; assumed sampling rate %g Hz)',this_observations(1).srate))
                        end
                        title(ax,{char(group_title);char(measure_title)},'Interpreter','none','FontSize',28)
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
            end
            if CFG.block3.save_flag
                catalog = struct('stage',this_stage,'settings',visual_settings, ...
                    'observations',observations,'overlays',vertcat(overlays{:}));
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
