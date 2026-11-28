% Estimate empirical tempo for the EXISTING WAV segments, independently of
% the newer score sections. No score-section/playing annotation is applied.
% Accepted beat frequencies can be consumed by the motion pipeline; review
% candidates remain available but are never exported as approved beat rates.
% Optional orchestra_tempo_overrides struct overrides named CFG settings for
% a reduced run or test without editing this script. Unknown fields error.
% Execution and automatic acceptance are OFF until the coordinated MATLAB
% synthetic/real-audio pilot has validated the pinned MIR output contract.


%% BLOCK 0 - SETTINGS, PINNED DEPENDENCY, AND OUTPUT CONTRACT

tempo_script_file = mfilename('fullpath');
tempo_study_path = fileparts(tempo_script_file);
CFG = struct;
CFG.data_path = fullfile(tempo_study_path,'concertproject_kiersten','data', ...
    'segment-piece-data-fixed-despiked');
CFG.annotations_file = fullfile(tempo_study_path,'Sections_annotations', ...
    'tidy_subgroups.csv');
CFG.mir_commit = '71d6265151ec4f6bd24773e1412193c4ab9ef972';
CFG.mir_path = fullfile(tempo_study_path,'FREQNESS_Output','_Dependencies', ...
    ['mirtoolbox-' CFG.mir_commit],'MIRToolbox');
CFG.output_path = fullfile(tempo_study_path,'FREQNESS_Output', ...
    '04_Tempo_ExistingSegments');
CFG.pieces = ["carmen" "giant" "juliet" "siviglia" "strings"];
CFG.recordings = strings(0,1);
CFG.segment_labels = strings(0,1);
CFG.run_flag = false;
CFG.overwrite_flag = false;
CFG.enable_automatic_acceptance_flag = false;

% These are audio-analysis settings, not changes to the supplied motion.
% Mean stereo channels, then antialias-resample to limit MIR memory use.
CFG.analysis_srate = 11025;
CFG.frame_seconds = 8;
CFG.hop_seconds = 1;
CFG.bounds_bpm = [40 300]; % Includes the score's 244 BPM; no section priors.
CFG.ncandidates = 3;
CFG.track_tolerance = .1;
CFG.peak_contrast = .1;

% Conservative, explicit screening rules; these are not confidence levels.
% A candidate with unstable/ambiguous metrical level requires review.
CFG.min_audio_seconds = 4;
CFG.min_valid_frames = 3;
CFG.min_valid_fraction = .8;
CFG.max_relative_mad = .1;
CFG.max_relative_range = .25;
CFG.octave_relative_tolerance = .08;
CFG.competing_peak_ratio = .8;
CFG.max_octave_ambiguity_fraction = .2;
CFG.boundary_fraction = .03;
CFG.min_rms = 1e-5;

if exist('orchestra_tempo_overrides','var')
    override_names = fieldnames(orchestra_tempo_overrides);
    assert(all(ismember(override_names,fieldnames(CFG))), ...
        'OrchestraTempo:UnknownSetting','Unknown orchestra tempo setting.');
    for settingi = 1:numel(override_names)
        CFG.(override_names{settingi}) = ...
            orchestra_tempo_overrides.(override_names{settingi});
    end
end
validateattributes(CFG.bounds_bpm,{'numeric'}, ...
    {'real','finite','row','numel',2,'positive','increasing'});
validateattributes(CFG.analysis_srate,{'numeric'}, ...
    {'scalar','integer','positive'});
validateattributes(CFG.frame_seconds,{'numeric'}, ...
    {'scalar','real','finite','positive'});
validateattributes(CFG.hop_seconds,{'numeric'}, ...
    {'scalar','real','finite','positive','<=',CFG.frame_seconds});
validateattributes(CFG.ncandidates,{'numeric'},{'scalar','integer','>=',2});
validateattributes(CFG.min_valid_frames,{'numeric'},{'scalar','integer','positive'});
fraction_settings = {'min_valid_fraction','max_relative_mad','max_relative_range', ...
    'octave_relative_tolerance','competing_peak_ratio', ...
    'max_octave_ambiguity_fraction','boundary_fraction'};
for settingi = 1:numel(fraction_settings)
    validateattributes(CFG.(fraction_settings{settingi}),{'numeric'}, ...
        {'scalar','real','finite','>=',0,'<=',1});
end
positive_settings = {'track_tolerance','min_audio_seconds','min_rms'};
for settingi = 1:numel(positive_settings)
    validateattributes(CFG.(positive_settings{settingi}),{'numeric'}, ...
        {'scalar','real','finite','positive'});
end
validateattributes(CFG.run_flag,{'logical'},{'scalar'});
validateattributes(CFG.overwrite_flag,{'logical'},{'scalar'});
validateattributes(CFG.enable_automatic_acceptance_flag,{'logical'},{'scalar'});
assert(strcmp(CFG.mir_commit,'71d6265151ec4f6bd24773e1412193c4ab9ef972'), ...
    'OrchestraTempo:UnverifiedMIRRevision','This stage requires the audited MIR revision.');
assert(isfile(fullfile(CFG.mir_path,'mirtempo.m')), ...
    'OrchestraTempo:MissingMIR','Pinned MIRtoolbox is missing: %s',CFG.mir_path);
provenance_file = fullfile(fileparts(CFG.mir_path),'source_provenance.json');
assert(isfile(provenance_file),'OrchestraTempo:MissingMIRProvenance', ...
    'The pinned MIR dependency needs its source_provenance.json.');
mir_provenance = jsondecode(fileread(provenance_file));
assert(strcmp(mir_provenance.commit,CFG.mir_commit), ...
    'OrchestraTempo:MIRProvenanceMismatch','MIR revision does not match provenance.');
assert(isfield(mir_provenance,'file_records'), ...
    'OrchestraTempo:MissingMIRProvenance','MIR provenance needs source-file hashes.');
for sourcei = 1:numel(mir_provenance.file_records)
    expected_source = mir_provenance.file_records(sourcei);
    source_path = fullfile(fileparts(CFG.mir_path),expected_source.path);
    assert(isfile(source_path) && ...
        strcmp(orchestra_tempo_sha256(source_path),expected_source.sha256), ...
        'OrchestraTempo:ModifiedMIRSource','Pinned MIR source differs: %s',source_path);
end
addpath(CFG.mir_path)
assert(strcmp(which('mirtempo'),fullfile(CFG.mir_path,'mirtempo.m')), ...
    'OrchestraTempo:UnexpectedMIR','mirtempo resolves outside the pinned dependency.');
mirtempo_sha256 = orchestra_tempo_sha256(fullfile(CFG.mir_path,'mirtempo.m'));
script_sha256 = orchestra_tempo_sha256([tempo_script_file '.m']);

% Only calculation settings enter the cache route; selections do not.
tempo_settings = rmfield(CFG,{'data_path','annotations_file','mir_path', ...
    'output_path','pieces','recordings','segment_labels','run_flag','overwrite_flag'});
tempo_settings.contract_version = 1;
tempo_settings.mirtempo_sha256 = mirtempo_sha256;
tempo_settings.script_sha256 = script_sha256;
signature_engine = java.security.MessageDigest.getInstance('SHA-256');
signature_engine.update(unicode2native(jsonencode(tempo_settings),'UTF-8'));
signature_bytes = typecast(signature_engine.digest(),'uint8');
tempo_signature = lower(reshape(dec2hex(signature_bytes,2)',1,[]));
tempo_results_path = fullfile(CFG.output_path, ...
    ['mirtempo_' CFG.mir_commit(1:12) '_' tempo_signature(1:12)]);


%% BLOCK 1 - RECORDING/SEGMENT INVENTORY AND PIECE-LEVEL SCORE CONTEXT

assert(isfolder(CFG.data_path),'OrchestraTempo:MissingData', ...
    'Existing WAV-segment directory is missing: %s',CFG.data_path);
manifest_files = dir(fullfile(CFG.data_path,'*','*','segments_manifest.csv'));
assert(~isempty(manifest_files),'OrchestraTempo:MissingManifest', ...
    'No segment manifests found below %s.',CFG.data_path);
manifest_paths = sort(string(fullfile({manifest_files.folder},{manifest_files.name})));

% These ranges document musical context only. They are not assigned to
% individual old segments and do not constrain the global search bounds.
score_piece_names = ["Bizet" "Saeverud" "Tchaikovsky" "Rossini" "Barber"];
audio_piece_names = ["carmen" "giant" "juliet" "siviglia" "strings"];
score_ranges = nan(5,2);
annotations_sha256 = "";
if isfile(CFG.annotations_file)
    score_table = readtable(CFG.annotations_file,'TextType','string');
    assert(all(ismember({'Piece','TempoBPM'},score_table.Properties.VariableNames)), ...
        'OrchestraTempo:InvalidAnnotations','Score context needs Piece and TempoBPM.');
    for piecei = 1:numel(score_piece_names)
        score_bpms = score_table.TempoBPM(score_table.Piece == score_piece_names(piecei));
        score_bpms = score_bpms(isfinite(score_bpms) & score_bpms > 0);
        if ~isempty(score_bpms)
            score_ranges(piecei,:) = [min(score_bpms),max(score_bpms)];
        end
    end
    annotations_sha256 = string(orchestra_tempo_sha256(CFG.annotations_file));
end

empty_tempo = struct('piece',"",'recording',"",'segment_index',NaN, ...
    'segment_label',"",'audio_file',"",'audio_sha256',"", ...
    'manifest_file',"",'manifest_sha256',"",'source_csv',"", ...
    'manifest_start_s',NaN,'manifest_end_s',NaN, ...
    'source_audio_srate',NaN,'audio_duration_s',NaN,'audio_channels',NaN, ...
    'score_prior_bpm_range',[NaN NaN], ...
    'score_prior_policy',"piece_context_only_not_applied_to_old_segments", ...
    'bounds_bpm',CFG.bounds_bpm,'tempo_bpm_candidate',NaN, ...
    'beat_hz_candidate',NaN,'tempo_bpm',NaN,'beat_hz',NaN, ...
    'eligible_flag',false,'status',"not_selected",'review_reasons',strings(0,1), ...
    'frame_times_s',zeros(1,0),'frame_bpm',zeros(1,0), ...
    'candidate_bpm',zeros(CFG.ncandidates,0), ...
    'candidate_strength',zeros(CFG.ncandidates,0), ...
    'valid_fraction',NaN,'relative_mad',NaN,'relative_range',NaN, ...
    'candidate_diagnostics_fraction',NaN,'octave_ambiguity_fraction',NaN, ...
    'nvalid_frames',0,'nframes',0,'audio_rms',NaN, ...
    'method',"mirtempo_spectralflux_autocor_tracked_median", ...
    'representative_rule',"median_of_finite_in_range_tracked_frame_bpms", ...
    'mir_commit',string(CFG.mir_commit),'mirtempo_sha256',string(mirtempo_sha256), ...
    'settings_signature',string(tempo_signature),'cache_file',"", ...
    'elapsed_seconds',NaN,'mir_messages',"");
TEMPO = repmat(empty_tempo,0,1);
for manifesti = 1:numel(manifest_paths)
    manifest_file = char(manifest_paths(manifesti));
    manifest_sha256 = string(orchestra_tempo_sha256(manifest_file));
    this_folder = fileparts(manifest_file);
    [piece_folder,this_recording] = fileparts(this_folder);
    [~,this_piece] = fileparts(piece_folder);
    this_piece = lower(string(this_piece));
    import_options = detectImportOptions(manifest_file,'VariableNamingRule','preserve');
    import_options = setvartype(import_options,{'label','audio_file'},'string');
    manifest = readtable(manifest_file,import_options);
    manifest = sortrows(manifest,'index');
    validateattributes(manifest.index,{'numeric'}, ...
        {'vector','real','finite','integer','positive'});
    assert(numel(unique(manifest.index)) == height(manifest), ...
        'OrchestraTempo:DuplicateSegmentIndex','Duplicate segment indices in %s.',manifest_file);
    for segmenti = 1:height(manifest)
        this_tempo = empty_tempo;
        this_tempo.piece = this_piece;
        this_tempo.recording = string(this_recording);
        this_tempo.segment_index = manifest.index(segmenti);
        this_tempo.segment_label = manifest.label(segmenti);
        [audio_parent,~,audio_ext] = fileparts(manifest.audio_file(segmenti));
        assert(strlength(audio_parent) == 0 && strcmpi(audio_ext,'.wav') && ...
            ~ismissing(this_tempo.segment_label), ...
            'OrchestraTempo:InvalidManifest','Expected local WAV names and nonmissing labels: %s',manifest_file);
        this_tempo.audio_file = string(fullfile(this_folder,manifest.audio_file(segmenti)));
        this_tempo.manifest_file = string(manifest_file);
        this_tempo.manifest_sha256 = manifest_sha256;
        if ismember('file',manifest.Properties.VariableNames)
            this_tempo.source_csv = string(fullfile(this_folder,string(manifest.file(segmenti))));
        end
        if ismember('audio_start_s',manifest.Properties.VariableNames)
            this_tempo.manifest_start_s = manifest.audio_start_s(segmenti);
            this_tempo.manifest_end_s = manifest.audio_end_s(segmenti);
        elseif ismember('eaf_start_ms',manifest.Properties.VariableNames)
            this_tempo.manifest_start_s = manifest.eaf_start_ms(segmenti)/1000;
            this_tempo.manifest_end_s = manifest.eaf_end_ms(segmenti)/1000;
        end
        idx_piece = find(audio_piece_names == this_piece,1);
        if ~isempty(idx_piece)
            this_tempo.score_prior_bpm_range = score_ranges(idx_piece,:);
        end
        TEMPO(end+1,1) = this_tempo; %#ok<SAGROW> Small manifest records only.
    end
end


%% BLOCK 2 - FRAMEWISE MIR ESTIMATION, AMBIGUITY SCREENING, AND CACHE

if CFG.run_flag
    if ~isfolder(tempo_results_path), mkdir(tempo_results_path); end
    for observationi = 1:numel(TEMPO)
        this_tempo = TEMPO(observationi);
        selected_flag = ismember(this_tempo.piece,lower(string(CFG.pieces))) && ...
            (isempty(CFG.recordings) || ismember(this_tempo.recording,string(CFG.recordings))) && ...
            (isempty(CFG.segment_labels) || ismember(this_tempo.segment_label,string(CFG.segment_labels)));
        if ~selected_flag, continue; end
        audio_file = char(this_tempo.audio_file);
        if ~isfile(audio_file)
            this_tempo.status = "missing_audio";
            this_tempo.review_reasons = "source_audio_unavailable";
            TEMPO(observationi) = this_tempo;
            continue
        end
        this_tempo.audio_sha256 = string(orchestra_tempo_sha256(audio_file));
        [~,audio_stem] = fileparts(audio_file);
        cache_folder = fullfile(tempo_results_path,this_tempo.piece,this_tempo.recording);
        this_tempo.cache_file = string(fullfile(cache_folder, ...
            ['tempo_' audio_stem '_' char(extractBefore(this_tempo.audio_sha256,13)) '.mat']));
        if isfile(this_tempo.cache_file) && ~CFG.overwrite_flag
            cached_tempo = load(this_tempo.cache_file,'tempo_observation','tempo_settings');
            assert(isequaln(cached_tempo.tempo_settings,tempo_settings) && ...
                cached_tempo.tempo_observation.audio_sha256 == this_tempo.audio_sha256 && ...
                cached_tempo.tempo_observation.recording == this_tempo.recording && ...
                cached_tempo.tempo_observation.segment_index == this_tempo.segment_index && ...
                cached_tempo.tempo_observation.segment_label == this_tempo.segment_label, ...
                'OrchestraTempo:IncompatibleCache','Incompatible tempo cache: %s',this_tempo.cache_file);
            % Refresh context and source paths; waveform/estimation identity
            % is immutable, while a moved source does not require rerunning.
            current_context = this_tempo;
            this_tempo = cached_tempo.tempo_observation;
            this_tempo.score_prior_bpm_range = current_context.score_prior_bpm_range;
            this_tempo.audio_file = current_context.audio_file;
            this_tempo.manifest_file = current_context.manifest_file;
            this_tempo.manifest_sha256 = current_context.manifest_sha256;
            this_tempo.source_csv = current_context.source_csv;
            this_tempo.cache_file = current_context.cache_file;
            this_tempo.manifest_start_s = current_context.manifest_start_s;
            this_tempo.manifest_end_s = current_context.manifest_end_s;
            TEMPO(observationi) = this_tempo;
            fprintf('Tempo cache: %s | %s\n',this_tempo.recording,this_tempo.segment_label);
            continue
        end

        fprintf('Tempo %d/%d: %s | %s\n',observationi,numel(TEMPO), ...
            this_tempo.recording,this_tempo.segment_label);
        observation_timer = tic;
        [audio_data,audio_srate] = audioread(audio_file);
        assert(ismatrix(audio_data) && ~isempty(audio_data) && all(isfinite(audio_data),'all'), ...
            'OrchestraTempo:InvalidAudio','Audio must be a finite samples-by-channels array: %s',audio_file);
        this_tempo.source_audio_srate = audio_srate;
        this_tempo.audio_duration_s = size(audio_data,1)/audio_srate;
        this_tempo.audio_channels = size(audio_data,2);
        audio_mono = mean(audio_data,2); % samples x 1; explicit stereo mean.
        clear audio_data
        this_tempo.audio_rms = sqrt(mean(audio_mono.^2,1));
        reasons = strings(0,1);
        if this_tempo.audio_duration_s < CFG.min_audio_seconds
            reasons(end+1,1) = "too_short_for_tempo";
        end
        if this_tempo.audio_rms < CFG.min_rms
            reasons(end+1,1) = "near_silent_audio";
        end

        if isempty(reasons)
            if audio_srate ~= CFG.analysis_srate
                audio_mono = resample(audio_mono,CFG.analysis_srate,audio_srate);
            end
            this_frame_seconds = min(CFG.frame_seconds, ...
                numel(audio_mono)/CFG.analysis_srate);
            hop_fraction = CFG.hop_seconds/this_frame_seconds;
            audio_object = miraudio(audio_mono,CFG.analysis_srate);
            % Spectral flux avoids external gammatone dependencies. Turning
            % off resonance avoids an implicit preference for 120 BPM.
            % Enhanced=0 is explicit because Track disables it internally.
            candidate_log = evalc(['[tempo_candidates,periodicity] = mirtempo(audio_object,' ...
                '''SpectralFlux'',''Autocor'',''Frame'',this_frame_seconds,hop_fraction,' ...
                '''Min'',CFG.bounds_bpm(1),''Max'',CFG.bounds_bpm(2),' ...
                '''Total'',CFG.ncandidates,''Enhanced'',0,''Resonance'',0,' ...
                '''Contrast'',CFG.peak_contrast);']);
            tracked_log = evalc(['[tempo_tracked,tracked_periodicity] = mirtempo(periodicity,' ...
                '''Track'',CFG.track_tolerance,''Total'',1,' ...
                '''Min'',CFG.bounds_bpm(1),''Max'',CFG.bounds_bpm(2),' ...
                '''Enhanced'',0,''Resonance'',0,''Contrast'',CFG.peak_contrast);']);
            this_tempo.mir_messages = string([candidate_log tracked_log]);
            frame_position = get(tempo_candidates,'FramePos');
            while iscell(frame_position) && numel(frame_position) == 1
                frame_position = frame_position{1};
            end
            assert(isnumeric(frame_position) && size(frame_position,1) == 2, ...
                'OrchestraTempo:UnexpectedMIRShape','Expected 2-by-frame MIR frame positions.');
            this_tempo.frame_times_s = mean(frame_position,1);
            this_tempo.nframes = size(frame_position,2);
            assert(all(isfinite(frame_position),'all') && ...
                all(diff(this_tempo.frame_times_s) > 0) && ...
                all(this_tempo.frame_times_s >= 0) && ...
                all(this_tempo.frame_times_s <= this_tempo.audio_duration_s + 1/CFG.analysis_srate), ...
                'OrchestraTempo:UnexpectedMIRTime','Invalid MIR audio-frame timestamps.');
            candidate_bpm = mirgetdata(tempo_candidates);
            tracked_bpm = mirgetdata(tempo_tracked);
            assert(isnumeric(candidate_bpm) && size(candidate_bpm,2) == this_tempo.nframes && ...
                size(candidate_bpm,1) <= CFG.ncandidates && ...
                isnumeric(tracked_bpm) && numel(tracked_bpm) == this_tempo.nframes, ...
                'OrchestraTempo:UnexpectedMIRShape','Unexpected candidate/tracked tempo dimensions.');
            this_tempo.candidate_bpm = nan(CFG.ncandidates,this_tempo.nframes);
            this_tempo.candidate_bpm(1:size(candidate_bpm,1),:) = candidate_bpm;
            this_tempo.frame_bpm = reshape(tracked_bpm,1,this_tempo.nframes);
            peak_strength = get(periodicity,'PeakPreciseVal');
            peak_strength = peak_strength{1}{1}; % one input file, one segment.
            assert(iscell(peak_strength) && numel(peak_strength) == this_tempo.nframes, ...
                'OrchestraTempo:UnexpectedMIRShape','Unexpected MIR per-frame peak strengths.');
            this_tempo.candidate_strength = nan(CFG.ncandidates,this_tempo.nframes);
            for framei = 1:this_tempo.nframes
                this_strength = peak_strength{framei};
                assert(numel(this_strength) <= CFG.ncandidates, ...
                    'OrchestraTempo:UnexpectedMIRShape','Too many MIR peak strengths.');
                this_tempo.candidate_strength(1:numel(this_strength),framei) = this_strength(:);
            end
            mask_valid = isfinite(this_tempo.frame_bpm) & ...
                this_tempo.frame_bpm >= CFG.bounds_bpm(1) & ...
                this_tempo.frame_bpm <= CFG.bounds_bpm(2);
            this_tempo.nvalid_frames = nnz(mask_valid);
            this_tempo.valid_fraction = mean(mask_valid,2);
            if this_tempo.nvalid_frames > 0
                this_tempo.tempo_bpm_candidate = median(this_tempo.frame_bpm(mask_valid),2);
                this_tempo.beat_hz_candidate = this_tempo.tempo_bpm_candidate/60;
                this_tempo.relative_mad = median(abs(this_tempo.frame_bpm(mask_valid) - ...
                    this_tempo.tempo_bpm_candidate),2)/this_tempo.tempo_bpm_candidate;
                this_tempo.relative_range = (max(this_tempo.frame_bpm(mask_valid)) - ...
                    min(this_tempo.frame_bpm(mask_valid)))/this_tempo.tempo_bpm_candidate;
                mask_diagnostics = any(isfinite(this_tempo.candidate_bpm) & ...
                    isfinite(this_tempo.candidate_strength) & this_tempo.candidate_strength > 0,1);
                this_tempo.candidate_diagnostics_fraction = ...
                    nnz(mask_diagnostics & mask_valid)/this_tempo.nvalid_frames;
            end

            % Count frames with a strong competing half/double-tempo peak.
            % This screening statistic is not a confidence probability.
            mask_octave_ambiguous = false(1,this_tempo.nframes);
            for framei = find(mask_valid)
                candidate_ratio = this_tempo.candidate_bpm(:,framei)/this_tempo.frame_bpm(framei);
                mask_octave = abs(candidate_ratio/.5-1) <= CFG.octave_relative_tolerance | ...
                    abs(candidate_ratio/2-1) <= CFG.octave_relative_tolerance;
                strongest_peak = max(this_tempo.candidate_strength(:,framei),[],'omitnan');
                mask_strong = this_tempo.candidate_strength(:,framei) >= ...
                    CFG.competing_peak_ratio*strongest_peak;
                mask_octave_ambiguous(framei) = any(mask_octave & mask_strong);
            end
            if this_tempo.nvalid_frames > 0
                this_tempo.octave_ambiguity_fraction = ...
                    nnz(mask_octave_ambiguous & mask_valid)/this_tempo.nvalid_frames;
            end
            if this_tempo.nvalid_frames < CFG.min_valid_frames
                reasons(end+1,1) = "insufficient_valid_frames";
            end
            if this_tempo.valid_fraction < CFG.min_valid_fraction
                reasons(end+1,1) = "low_tempo_coverage";
            end
            if ~isfinite(this_tempo.relative_mad) || this_tempo.relative_mad > CFG.max_relative_mad || ...
                    this_tempo.relative_range > CFG.max_relative_range
                reasons(end+1,1) = "variable_or_missing_tempo";
            end
            if ~isfinite(this_tempo.candidate_diagnostics_fraction) || ...
                    this_tempo.candidate_diagnostics_fraction < CFG.min_valid_fraction
                reasons(end+1,1) = "insufficient_periodicity_diagnostics";
            end
            if this_tempo.octave_ambiguity_fraction >= CFG.max_octave_ambiguity_fraction
                reasons(end+1,1) = "half_double_tempo_ambiguity";
            end
            if this_tempo.tempo_bpm_candidate <= CFG.bounds_bpm(1)*(1+CFG.boundary_fraction) || ...
                    this_tempo.tempo_bpm_candidate >= CFG.bounds_bpm(2)*(1-CFG.boundary_fraction)
                reasons(end+1,1) = "tempo_near_search_boundary";
            end
            clear audio_object tempo_candidates tempo_tracked periodicity tracked_periodicity
        end

        if ~CFG.enable_automatic_acceptance_flag
            reasons(end+1,1) = "automatic_acceptance_disabled";
        end
        this_tempo.review_reasons = reasons;
        this_tempo.status = "needs_review";
        if isempty(reasons) && isfinite(this_tempo.beat_hz_candidate)
            this_tempo.status = "accepted";
            this_tempo.eligible_flag = true;
            this_tempo.tempo_bpm = this_tempo.tempo_bpm_candidate;
            this_tempo.beat_hz = this_tempo.beat_hz_candidate;
        end
        this_tempo.elapsed_seconds = toc(observation_timer);
        TEMPO(observationi) = this_tempo;
        if ~isfolder(cache_folder), mkdir(cache_folder); end
        tempo_observation = this_tempo;
        temporary_cache = this_tempo.cache_file + ".partial.mat";
        save(temporary_cache,'tempo_observation','tempo_settings','CFG','-v7');
        movefile(temporary_cache,this_tempo.cache_file,'f');
        fprintf('  %s; candidate %.3f BPM; %.2f s\n', ...
            this_tempo.status,this_tempo.tempo_bpm_candidate,this_tempo.elapsed_seconds);
    end
end


%% BLOCK 3 - REVIEWABLE CATALOG, EXPORTED WITHOUT MIR OBJECTS

if CFG.run_flag
    tempo_catalog = struct('contract_version',1, ...
        'analysis_unit',"existing_wav_segment", ...
        'score_section_mapping_applied',false, ...
        'score_prior_policy',"piece_context_only_not_applied_to_old_segments", ...
        'annotations_file',string(CFG.annotations_file),'annotations_sha256',annotations_sha256, ...
        'audio_motion_alignment_status',"unresolved_independent_of_audio_tempo", ...
        'acceptance_policy',"automatic_screening_not_manual_beat_validation", ...
        'complete_flag',~any([TEMPO.status] == "not_selected"), ...
        'settings_signature',string(tempo_signature),'settings',tempo_settings, ...
        'mir_repository',"https://github.com/olivierlar/mirtoolbox", ...
        'mir_commit',string(CFG.mir_commit),'mirtempo_sha256',string(mirtempo_sha256), ...
        'observations',TEMPO);
    catalog_file = fullfile(tempo_results_path,'tempo_catalog.json');
    file_id = fopen(catalog_file,'w');
    assert(file_id ~= -1,'OrchestraTempo:CatalogWrite','Cannot write %s.',catalog_file);
    catalog_cleanup = onCleanup(@() fclose(file_id));
    fprintf(file_id,'%s\n',jsonencode(tempo_catalog,'PrettyPrint',true));
    clear catalog_cleanup
    save(fullfile(tempo_results_path,'tempo_catalog.mat'),'TEMPO','tempo_catalog','CFG','-v7');
    fprintf('Tempo catalog: %s\nAccepted %d; review %d; missing %d; unselected %d.\n', ...
        catalog_file,nnz([TEMPO.status] == "accepted"), ...
        nnz([TEMPO.status] == "needs_review"),nnz([TEMPO.status] == "missing_audio"), ...
        nnz([TEMPO.status] == "not_selected"));
end


function digest = orchestra_tempo_sha256(file_path)
% Stream original file bytes; do not hash decoded audio or rewritten text.
file_id = fopen(file_path,'rb');
assert(file_id ~= -1,'OrchestraTempo:HashRead','Cannot read %s.',file_path);
file_cleanup = onCleanup(@() fclose(file_id));
engine = java.security.MessageDigest.getInstance('SHA-256');
while ~feof(file_id)
    engine.update(fread(file_id,2^20,'*uint8'));
end
bytes = typecast(engine.digest(),'uint8');
digest = lower(reshape(dec2hex(bytes,2)',1,[]));
end
