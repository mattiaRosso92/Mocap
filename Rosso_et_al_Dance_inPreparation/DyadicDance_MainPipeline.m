% Dyadic Dance study: 35 dyads, 1119 retained trials.
% Public motion-capture dataset, musical stimuli and metadata:
% https://doi.org/10.48557/UR2GBG (IIT Dataverse; verified 2026-10-23).
% Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
% Main: position-based GED, ED, spatial coordination and corrected phase-space RQA.
% Supplementary/DyadicDance_Supplementary.m contains the additional analyses.
% Existing CFG.block* IDs and numerical output names are retained for cache compatibility.

clear
close all
clc

%% BLOCK 0 - SHARED STUDY CONFIGURATION

script_file = mfilename('fullpath');
if isempty(script_file)
    script_file = matlab.desktop.editor.getActiveFilename;
end
path_study = fileparts(script_file);
run(fullfile(path_study,'Supporting','DyadicDance_Configuration.m'));

%% BLOCK 1 - NETWORK ESTIMATION

which_method = validatestring(which_method,{'GED','PCA'});
% PCA is an optional BLOCK 1 control, never a replacement for manuscript GED.
core_suffix = prefix{idx_XYZ};
if strcmp(which_method,'PCA'), core_suffix = [core_suffix '_PCA']; end

% Loop over conditions
for condi = 1:nconds

    % Select dyad and subject
    for dyadi = list_dyads
        disp(['Condition#' num2str(condi) ' - Dyad #' num2str(dyadi)])
        id_dyad = dyadi;
        id_dyad_str = sprintf('%02d', id_dyad); % to add the '0' before numbers < 10

        % Filter trials by condition
        list_trials = CFG.common.trial_indices{dyadi,condi};

        % Analyse trial by trial
        for triali = 1:CFG.common.trial_counts(dyadi,condi)
            id_trial = list_trials(triali);
            id_trial_str = sprintf('%02d', id_trial); % to add the '0' before numbers < 10

            output_file = fullfile(CFG.block1.output_path,sprintf( ...
                'FREQNESS_CORE_D%d_C%d_T%d%s.mat', ...
                dyadi,condi,triali,core_suffix));
            input_file = output_file;
            if strcmp(which_method,'GED') && ~isfile(input_file) && ...
                    ~isempty(CFG.common.reuse_core_path)
                input_file = fullfile(CFG.common.reuse_core_path,sprintf( ...
                    'FREQNESS_CORE_D%d_C%d_T%d%s.mat', ...
                    dyadi,condi,triali,prefix{idx_XYZ}));
            end
            if isfile(input_file) && ~CFG.block1.overwrite_flag
                % Read only compact fields; do not reload saved time series.
                saved_core = load(input_file,'id_trial');
                assert(saved_core.id_trial == id_trial,'Saved core trial ID differs.');
                saved_frex = h5read(input_file,['/' which_method '/frex']);
                saved_fwhm = h5read(input_file,['/' which_method '/fwhm']);
                if strcmp(CFG.common.filter_width_calibration,'legacy')
                    saved_expected_filter_width = ...
                        FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
                        saved_frex,CFG.common.filter_type);
                else
                    saved_expected_filter_width = ...
                        FREQNESS_ComputeFilterWidths_Mocap( ...
                        saved_frex,CFG.common.filter_type);
                end
                assert(isequal(size(saved_fwhm),size(saved_expected_filter_width)) && ...
                    max(abs(saved_fwhm-saved_expected_filter_width),[],'all') < 1e-12, ...
                    'Existing core output uses an incompatible filter calibration.');
                fprintf('BLOCK 1 output exists; skipping %s.\n',input_file);
                continue
            end

            % Refresh data matrix for every iteration
            markData = [];
            beat_frex = zeros(1,nsubs);
            frex = [];

            % Loop over partners
            for subi = 1:nsubs
                id_sub = sublabels{subi};

                % Define path
                path_data = fullfile(path_home,['Dyad_' id_dyad_str],['subj' id_sub]);

                % Import info on songs, per single participant
                song_file = fullfile(path_home,['song_subj' id_sub '.csv']);
                song_info = readmatrix(song_file,'NumHeaderLines',1);
                song_info = song_info(:,2:end) + 1; % compensate Python 0-indexing
                songs_frex = 1 ./ (60 ./ song_bpms); % convert to Hz
                % Find beat frequency (find song in 'song_subj_LEFT/RIGHT.csv')
                idx_beat = song_info(id_dyad,id_trial);
                beat_frex(subi) = songs_frex( idx_beat );
                % Define vector of frequencies
                %frex = beat_frex(subi)/8:beat_frex(subi)/8:beat_frex(subi)*4; % above beat
                frex(:,subi) = beat_frex(subi)/8:beat_frex(subi)/8:beat_frex(subi)*4; % above beat

                % Import data (skip 1st row and column)
                trial_file = fullfile(path_data,['tr' id_trial_str '.csv']);
                assert(isfile(trial_file),'Missing raw trial: %s',trial_file);
                tempData = readmatrix(trial_file,'NumHeaderLines',1);
                tempData = tempData(:,2:end);
                %tempData = tempData(:,1:dwn:end);  % Downsample the data
                tempData = tempData(1:end-3,:);  % Remove last marker
                markData = cat(3,markData,tempData); % Assign to 3rd dimension of input data matrix
                nmarks = size(markData,1);       % Updated number of markers
                npnts = size(markData,2);

                % Zero the discarded dimensions, if any was chosen in the
                % previous block
                if idx_XYZ == 2 % only X
                    markData([y_idx,z_idx],:,:) = 0;
                end
                if idx_XYZ == 3 % only Y
                    markData([x_idx,z_idx],:,:) = 0;
                end
                if idx_XYZ == 4 % only Z
                    markData([x_idx,y_idx],:,:) = 0;
                end

            end

            %% Run network decomposition on the dyad

            % ncomps controls retained eigenvectors, patterns, and time
            % series only. The complete eigenspectrum is always retained
            % and remains available to EffectDimensionality.

            % Both decompositions use the selected study filter calibration.
            if strcmp(CFG.common.filter_width_calibration,'legacy')
                filter_width = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
                    frex,CFG.common.filter_type);
                expected_filter_width = filter_width;
            else
                filter_width = [];
                expected_filter_width = FREQNESS_ComputeFilterWidths_Mocap( ...
                    frex,CFG.common.filter_type);
            end
            if strcmp(which_method,'GED')

                % Compute FREQNESS with GED (unchanged default: positions).
                GED = []; % refresh for loop iterations
                GED = FREQNESS_NetworkEstimation_Mocap(markData, frex, srate, ...
                    'fwidth',filter_width,'filter',CFG.common.filter_type, ...
                    'ncomps',CFG.common.ncomps); % networks estimation
                assert(isequal(GED.fwhm,expected_filter_width), ...
                    'Core output did not use the requested filter-width calibration.');
                GED.filter_width_calibration = string( ...
                    CFG.common.filter_width_calibration);
                GED.filter_type = string(CFG.common.filter_type);
                analysis_info = struct( ...
                    'filterWidthCalibration', ...
                    string(CFG.common.filter_width_calibration), ...
                    'filter',string(CFG.common.filter_type), ...
                    'fwidth',GED.fwhm);
                assert(size(GED.evals,1) == size(markData,1), ...
                    'NetworkEstimation did not retain the complete eigenspectrum.');
                assert(size(GED.evecs,2) == CFG.common.ncomps, ...
                    'NetworkEstimation retained an unexpected component count.');
                % Normalize frequencies by beat
                GED.frex_norm = GED.frex ./ beat_frex;

            elseif strcmp(which_method,'PCA')

                % Compute FREQNESS with PCA
                PCA = []; % refresh for loop iterations
                PCA = FREQNESS_NetworkEstimation_Mocap(markData, frex, srate, ...
                    'method','pca','kinematics','position', ...
                    'fwidth',filter_width,'filter',CFG.common.filter_type, ...
                    'ncomps',CFG.common.ncomps); % networks estimation
                assert(isequal(PCA.fwhm,expected_filter_width));
                PCA.filter_width_calibration = string(CFG.common.filter_width_calibration);
                PCA.filter_type = string(CFG.common.filter_type);
                % Normalize frequencies by beat
                PCA.frex_norm = PCA.frex ./ beat_frex;

            else

                error('Double-check your method: it must be GED or PCA')
            
            end


            % Save output
            if save_flag == 1
                marker_reference = markData(:,1,:);
                if strcmp(which_method,'GED')
                    save(output_file,'GED','beat_frex','id_dyad','condi', ...
                        'triali','id_trial','srate','marker_reference', ...
                        'analysis_info','-v7.3')
                else
                    save(output_file,'PCA','beat_frex','id_dyad','condi', ...
                        'triali','id_trial','srate','marker_reference','-v7.3')
                end
            end



            %% FREQNESS VISUALIZATION

            % Enable visualization
            if vis_flag == 1

                %%% ------------------- USER SETTINGS ------------------- %%%

                % Settings (visualization of network landscape)
                Landscape = [];
                Landscape.frex   = frex;
                Landscape.ncomps = CFG.common.ncomps;

                % Settings (visualization of network activation patterns)
                Patterns = [];
                Patterns.frex   = beat_frex(1);    % MAX beat*2
                Patterns.labels = marklabels;   % insert marker labels, in format X1,Y1,Z1,X2,Y2,Z2,[...]
                Patterns.markerData = markData; % used to compute the backprojection
                Patterns.comp   = 1;            % choose the component to inspect
                Patterns.srate  = srate;        % necessary for the animation
                Patterns.start  = .25;           % starting point of the animation (0-1)
                Patterns.bones  = bones;
        

                %%% ------------------ COMPUTATION --------------------- %%%

                % Optionally inspect this individual dyad and trial before
                % proceeding to the group-level analysis blocks.
                if strcmp(which_method,'GED'), FREQvis = GED; else, FREQvis = PCA; end
                % Shared beat-relative axis aligns each partner's own song.
                FREQvis.frex = FREQvis.frex_norm(:,1);
                Landscape.frex = FREQvis.frex;
                Landscape.xlabel = 'Frequency / beat';
                Patterns.frex = 1;
                Patterns.frequency_unit = 'x beat';
                FREQNESS_Visualizer_Mocap(FREQvis,Landscape,Patterns)


            end



        end

    end

end




%% BLOCK 2 - NETWORK LANDSCAPES AND EFFECTIVE DIMENSIONALITY

% Publication blocks retain GED; PCA comparisons belong in Supplementary.
assert(strcmp(which_method,'GED'), ...
    ['BLOCKS 2-8 use manuscript GED outputs. For PCA, run BLOCK 1 only ' ...
    'or use DyadicDance_Supplementary.m for the comparisons.']);

% Choose if you want to enable saving of FREQNESS output
save_flag = 1;

% Number of top components to retain
ncomps2keep = 4;

for dyadi = list_dyads
    for condi = 1:nconds
        disp(['Condition#' num2str(condi) ' - Dyad #' num2str(dyadi)])

        for triali = 1:CFG.common.trial_counts(dyadi,condi)

            % Load into a struct so variable name (GED or PCA) becomes a field
            input_file = fullfile(CFG.block1.output_path,sprintf( ...
                'FREQNESS_CORE_D%d_C%d_T%d%s.mat', ...
                dyadi,condi,triali,prefix{idx_XYZ}));
            if ~isfile(input_file) && ~isempty(CFG.common.reuse_core_path)
                input_file = fullfile(CFG.common.reuse_core_path,sprintf( ...
                    'FREQNESS_CORE_D%d_C%d_T%d%s.mat', ...
                    dyadi,condi,triali,prefix{idx_XYZ}));
            end
            assert(isfile(input_file),'Missing BLOCK 1 output: %s',input_file);
            S = load(input_file,'marker_reference','id_trial');
            assert(S.id_trial == CFG.common.trial_indices{dyadi,condi}(triali));
            % Group landscapes need no sample-resolved time series.
            M = [];
            for field = {'evals','pats','frex','frex_norm'}
                M.(field{1}) = h5read(input_file,['/' which_method '/' field{1}]);
            end

            % Initialize group-level outputs once, using the loaded struct sizes
            if dyadi == list_dyads(1) && condi == 1 && triali == 1
                all_evals = nan([ndyads,nconds,ntrials,size(M.evals)]);
                all_pats = nan([ndyads,nconds,ntrials,size(M.pats)]);
                all_frex_norm = nan( ...
                    ndyads,nconds,ntrials,nsubs,size(M.frex,1));
                ED = nan(nconds,ndyads,ntrials,size(M.evals,2),nsubs);
                marker_reference = S.marker_reference;
            end

            % Assign normalized frequency axis (based on beat of each subject and trial)
            for subi = 1:nsubs
                all_frex_norm(dyadi,condi,triali,subi,:) = M.frex_norm(:,subi);
            end

            % Retain the complete eigenspectrum for EffectDimensionality;
            % retain only the requested spatial components for visualization.
            all_evals(dyadi,condi,triali,:,:,:) = M.evals;
            all_pats(dyadi,condi,triali,:,1:ncomps2keep,:,:) = M.pats(:,1:ncomps2keep,:,:);
            legacy_landscape_file = fullfile(CFG.common.reuse_results_path, ...
                '02_Landscape',sprintf('FREQNESS_LANDSCAPE_D%d_C%d_T%d%s.mat', ...
                dyadi,condi,triali,prefix{idx_XYZ}));
            if ~CFG.block2.overwrite_flag && ~isempty(CFG.common.reuse_results_path) && ...
                    isfile(legacy_landscape_file)
                S = load(legacy_landscape_file,'H2','ED_trial','frex');
                assert(max(abs(S.frex-M.frex),[],'all') < 1e-12);
                this_H2 = S.H2;
                this_ED = S.ED_trial;
            else
                [this_H2,this_ED] = FREQNESS_EffectDim_Mocap(M,'figure',false);
            end
            ED(condi,dyadi,triali,:,:) = this_ED;

            % Match the HYPER-NESS stage convention: one compact landscape
            % file per analysis unit (here: dyad, condition, and trial).
            landscape_file = fullfile(CFG.block2.output_path,sprintf( ...
                'FREQNESS_LANDSCAPE_D%d_C%d_T%d%s.mat', ...
                dyadi,condi,triali,prefix{idx_XYZ}));
            if ~isfile(landscape_file) || CFG.block2.overwrite_flag
                H2 = this_H2;
                ED_trial = this_ED;
                frex = M.frex;
                frex_norm = M.frex_norm;
                save(landscape_file,'H2','ED_trial','frex','frex_norm', ...
                    'dyadi','condi','triali','-v7.3')
            end

        end
    end
end

% Save output
if save_flag == 1
    group_output_file = fullfile(CFG.block2.output_path, ...
        ['FREQNESS_GroupNetworkSummary' prefix{idx_XYZ} '.mat']);
    if ~isfile(group_output_file) || CFG.block2.overwrite_flag
        save(group_output_file,'all_evals','all_pats','all_frex_norm', ...
            'ED','list_dyads','marker_reference','CFG','-v7.3')
    else
        S = load(group_output_file,'list_dyads','CFG');
        assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
            isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
            'Existing group summary has different dyads/trials; use a new folder.');
    end
end



%% BLOCK 3 - SPATIAL COORDINATION

clearvars -except CFG

% Coordination is intentionally configured independently of the number of
% components retained by NetworkEstimation.
components = CFG.block3.components;
assert(all(components >= 1 & components <= CFG.common.ncomps & ...
    components == fix(components)), ...
    'CFG.block3.components must contain valid retained component indices.');


% Restore repository-relative paths after clearing the large group arrays.
path_repo = fileparts(CFG.common.data_path);
path_toolbox = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');
addpath(path_toolbox)
FREQNESS_Startup_Mocap();

% Re-initialize settings to import GED outputs from the folder
ndyads = 35;
nconds  = 4;
ntrials = CFG.common.ntrials;
list_dyads = CFG.common.list_dyads;

% Recovered and original dyads share the same retained-trial list.
validation_flag = false;
assert(isfolder(CFG.block1.output_path), ...
    'BLOCK 1 output folder is missing: %s',CFG.block1.output_path);
condlabels = {'NOvis-DIFFmus','NOvis-SAMEmus', ...
    'YESvis-DIFFmus','YESvis-SAMEmus'};

% Define metric levels of interest
meter = [.25 .5 1 2];
nmeters = length(meter);


% Run each component independently so outputs can never be confused.
for componenti = 1:numel(components)

which_comp = components(componenti);
component_output_path = fullfile( ...
    CFG.block3.output_path,['Component_' num2str(which_comp)]);
if ~isfolder(component_output_path)
    mkdir(component_output_path)
end

disp(['BLOCK 3: Component #' num2str(which_comp)])



% Pre-allocate group-level output
MIRROR = nan(ndyads,nconds,nmeters,ntrials);

% Run analyses
for condi = 1:nconds
    for dyadi = list_dyads
        disp(['Condition#' num2str(condi) ' - Dyad #' num2str(dyadi)])
        for triali = 1:CFG.common.trial_counts(dyadi,condi)

            id_trial = CFG.common.trial_indices{dyadi,condi}(triali);
            spatial_file = fullfile(component_output_path,sprintf( ...
                'FREQNESS_SPATIAL_D%d_C%d_T%d.mat',dyadi,condi,triali));
            if isfile(spatial_file) && ~CFG.block3.overwrite_flag
                S = load(spatial_file,'FREQmirror','id_trial','which_comp','meter');
                assert(S.id_trial == id_trial && S.which_comp == which_comp && ...
                    isequal(S.meter,meter),'Saved spatial settings/trial differ: %s',spatial_file);
                FREQmirror = S.FREQmirror;
            else
                core_name = sprintf('FREQNESS_CORE_D%d_C%d_T%d.mat',dyadi,condi,triali);
                input_file = fullfile(CFG.block1.output_path,core_name);
                if ~isfile(input_file) && ~isempty(CFG.common.reuse_core_path)
                    input_file = fullfile(CFG.common.reuse_core_path,core_name);
                end
                assert(isfile(input_file),'Missing core output: %s',input_file);
                S = load(input_file,'beat_frex','id_trial');
                assert(S.id_trial == id_trial);
                GED = struct('pats',h5read(input_file,'/GED/pats'), ...
                    'frex',h5read(input_file,'/GED/frex'));
                relative_frex = GED.frex./reshape(S.beat_frex,1,[]);
                assert(max(abs(relative_frex-(1:32)'/8),[],'all') < 1e-12, ...
                    'Partners must share the beat-relative grid.');
                FREQmirror = FREQNESS_SpaceCoord_Mocap(GED,S.beat_frex, ...
                    'metric_levels',meter,'component',which_comp);
                save(spatial_file,'FREQmirror','which_comp','meter', ...
                    'dyadi','condi','triali','id_trial','input_file');
            end
            assert(all(isfinite(FREQmirror)) && all(abs(FREQmirror)<1), ...
                'Undefined/perfect spatial correlation; inspect %s.',spatial_file);
            MIRROR(dyadi,condi,:,triali) = reshape(FREQmirror,1,1,nmeters);

        end
    end
end

spatial_summary_file = fullfile(component_output_path, ...
    ['FREQNESS_SPATIAL_SUMMARY_Comp#' num2str(which_comp) '.mat']);
if ~isfile(spatial_summary_file) || CFG.block3.overwrite_flag
    save(spatial_summary_file,'MIRROR','which_comp','meter','list_dyads', ...
        'nconds','ntrials','nmeters','CFG','-v7.3');
else
    S = load(spatial_summary_file,'MIRROR','list_dyads','CFG');
    assert(isequaln(S.MIRROR,MIRROR) && isequal(S.list_dyads,list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Existing spatial summary differs; use a new folder or explicitly overwrite.');
end


end

%% BLOCKS 4 AND 5 - RUN SEPARATELY IN DyadicDance_Supplementary.m
% Metric prominence and landscape similarity are supplementary analyses.

%% BLOCK 6 - PHASE-SPACE RQA (MANUSCRIPT TEMPORAL COORDINATION)

% The selected manuscript analysis uses the phase-space TimeCoord method.
% Run Block 0 then this block to reuse completed core estimates unchanged.

clearvars -except CFG

% Restore all settings needed to resume this block independently after a
% stopped MATLAB session.
path_home = CFG.common.data_path;
path_repo = fileparts(path_home);
path_toolbox = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');
addpath(path_toolbox)
FREQNESS_Startup_Mocap();

ndyads = 35;
nconds = 4;
ntrials = CFG.common.ntrials;
nsubs = 2;
list_dyads = CFG.common.list_dyads;
validation_flag = false;

meter = CFG.block6.metric_levels;
nmeters = length(meter);
duration = CFG.block6.duration;

srate = CFG.block6.srate;
dwn = CFG.block6.downsample;
validateattributes(dwn,{'numeric'},{'scalar','integer','positive'});
assert(CFG.block6.lowpass_hz > 0 && ...
    CFG.block6.lowpass_hz < srate/(2*dwn), ...
    'BLOCK 6 lowpass_hz must be positive and below the downsampled Nyquist frequency.');
lp_order = CFG.block6.filter_order;
% Design at the ORIGINAL rate: 10/(250/2) = .08, not the legacy .8.
lp_cutoff_norm = CFG.block6.lowpass_hz/(srate/2);
[b_butt,a_butt] = butter(lp_order,lp_cutoff_norm,'low');
srate = srate/dwn;

assert(isfolder(CFG.block1.output_path), ...
    'BLOCK 1 output folder is missing: %s',CFG.block1.output_path);

components = CFG.block6.components;
assert(all(components >= 1 & components <= CFG.common.ncomps & ...
    components == fix(components)), ...
    'CFG.block6.components must contain valid retained component indices.');

for componenti = 1:numel(components)

which_comp = components(componenti);
component_output_path = fullfile( ...
    CFG.block6.output_path,['Component_' num2str(which_comp)]);
if ~isfolder(component_output_path)
    mkdir(component_output_path)
end

disp(['BLOCK 6: Component #' num2str(which_comp)])

% Phase-space RQA settings
PhaseRQA = [];
% The block loop shares its selected component across the dyad. The toolbox
% function itself also accepts one component per participant when called
% independently.
PhaseRQA.target_frex      = [];
PhaseRQA.component        = which_comp;
PhaseRQA.metric_levels    = meter;
PhaseRQA.duration         = duration;
PhaseRQA.original_srate   = CFG.block6.srate;
PhaseRQA.downsample       = dwn;
PhaseRQA.srate            = srate;
PhaseRQA.lowpass_hz       = CFG.block6.lowpass_hz;
PhaseRQA.filter_order     = lp_order;
PhaseRQA.filter_method    = 'butter_filtfilt_before_decimation';
PhaseRQA.standardize      = CFG.block6.standardize;
PhaseRQA.threshold_method = CFG.block6.threshold_method;
PhaseRQA.threshold        = CFG.block6.threshold;
PhaseRQA.theiler_window   = CFG.block6.theiler_window;
PhaseRQA.lmin             = CFG.block6.lmin;
PhaseRQA.vmin             = CFG.block6.vmin;
PhaseRQA.figure           = validation_flag;
PhaseRQA.animate          = false;

phase_summary_file = fullfile(component_output_path, ...
    ['FREQNESS_PHASERQA_SUMMARY_Comp#' num2str(which_comp) '.mat']);
% Imported summaries contain only RR/DET, not fabricated auxiliary metrics.
% They are self-contained and can be reused without the original comparison.
if isfile(phase_summary_file) && ~CFG.block6.overwrite_flag
    saved_phase = load(phase_summary_file);
    if isfield(saved_phase,'reuse_source')
        assert(isequaln(rmfield(saved_phase.PhaseRQA,'output'),PhaseRQA) && ...
            isequal(saved_phase.list_dyads,list_dyads) && ...
            isequal(saved_phase.CFG.common.trial_indices,CFG.common.trial_indices) && ...
            isequal(saved_phase.CFG.common.trial_counts,CFG.common.trial_counts) && ...
            strcmp(saved_phase.CFG.common.filter_output_tag,CFG.common.filter_output_tag), ...
            'Reused phase-space summary settings/trials differ; select a new output folder.');
        for metri = {'RR','DET'}
            this_metric = saved_phase.PhaseRQA.output.(metri{1});
            assert(isequal(size(this_metric,1:4),[ndyads nconds nmeters ntrials]) && ...
                nnz(isfinite(this_metric)) == sum(CFG.common.trial_counts(list_dyads,:),'all')*nmeters, ...
                'Reused phase-space summary has incomplete RR/DET coverage.');
            for dyadi = list_dyads
                for condi = 1:nconds
                    retained = this_metric(dyadi,condi,:,1:CFG.common.trial_counts(dyadi,condi));
                    assert(all(isfinite(retained) & retained >= 0 & retained <= 1,'all'), ...
                        'Reused phase-space summary has invalid retained RR/DET values.');
                end
            end
        end
        fprintf('BLOCK 6: reusing saved RR/DET summary, Component %d; no RQA computation.\n',which_comp);
        continue
    end
end

if ~isfile(phase_summary_file) && ~CFG.block6.overwrite_flag && ...
        ~isempty(CFG.block6.reuse_rqa_path)
    reference = load(fullfile(CFG.block6.reuse_rqa_path,'Summary.mat'));
    setting_fields = {'srate','lowpass_hz','filter_order','metric_levels', ...
        'duration','threshold','standardize','lmin','theiler_window'};
    assert(all(cellfun(@(name) isequaln(reference.settings.(name), ...
        CFG.block6.(name)),setting_fields)) && ...
        strcmp(PhaseRQA.threshold_method,'max_fraction') && ...
        strcmp(reference.CFG.common.filter_output_tag,CFG.common.filter_output_tag) && ...
        isequal(reference.CFG.common.list_dyads,list_dyads) && ...
        isequal(reference.CFG.common.trial_indices,CFG.common.trial_indices) && ...
        isequal(reference.CFG.common.trial_counts,CFG.common.trial_counts), ...
        'Reference phase-space settings/trials differ; disable reuse or select matching inputs.');
    idx_component = find(reference.settings.components == which_comp);
    idx_factor = find(reference.settings.factors == dwn);
    assert(isscalar(idx_component) && isscalar(idx_factor), ...
        'Reference phase-space component/downsampling factor is unavailable.');
    [RR_phase,DET_phase] = deal(nan(ndyads,nconds,nmeters,ntrials));
    for condi = 1:nconds
        for dyadi = list_dyads
            for triali = 1:CFG.common.trial_counts(dyadi,condi)
                source_file = fullfile(CFG.block6.reuse_rqa_path,sprintf( ...
                    'D%d_C%d_T%d.mat',dyadi,condi,triali));
                source = load(source_file);
                id_trial = CFG.common.trial_indices{dyadi,condi}(triali);
                assert(isequaln(source.settings,reference.settings) && source.id_trial == id_trial, ...
                    'Reference phase-space settings/trial differ: %s',source_file);
                core_name = sprintf('FREQNESS_CORE_D%d_C%d_T%d.mat',dyadi,condi,triali);
                input_file = fullfile(CFG.block1.output_path,core_name);
                if ~isfile(input_file), input_file = fullfile(CFG.block6.reuse_core_path,core_name); end
                % Read only core metadata, never its time series or recurrence matrix.
                core = load(input_file,'id_trial','beat_frex');
                [~,source_core_name,source_core_ext] = fileparts(source.source_file);
                core_frex = h5read(input_file,'/GED/frex');
                core_fwhm = h5read(input_file,'/GED/fwhm');
                expected_fwhm = FREQNESS_ComputeLegacyFilterWidths_Mocap(core_frex,CFG.common.filter_type);
                core_info = h5info(input_file,'/GED/ts');
                reduced_length = numel(1:dwn:core_info.Dataspace.Size(2));
                expected_samples = diff(round(duration*reduced_length))+1;
                assert(core.id_trial == id_trial && strcmp([source_core_name source_core_ext],core_name) && ...
                    max(abs(core_fwhm-expected_fwhm),[],'all') < 1e-12 && ...
                    max(abs(source.selected_frequencies-reshape(core.beat_frex,[],1)*meter),[],'all') < 1e-10 && ...
                    source.sample_counts(idx_factor) == expected_samples, ...
                    'Reference phase-space core/frequencies/sample count differ: %s',source_file);
                this_RR = source.RR(idx_component,:,idx_factor);
                this_DET = source.DET(idx_component,:,idx_factor);
                assert(numel(this_RR) == nmeters && numel(this_DET) == nmeters && ...
                    all(isfinite([this_RR this_DET]) & [this_RR this_DET] >= 0 & [this_RR this_DET] <= 1), ...
                    'Reference phase-space RR/DET are incomplete or invalid: %s',source_file);
                assert(isequal(this_RR,reshape(reference.RR(dyadi,condi,triali,idx_component,:,idx_factor),1,[])) && ...
                    isequal(this_DET,reshape(reference.DET(dyadi,condi,triali,idx_component,:,idx_factor),1,[])), ...
                    'Reference phase-space trial and summary values differ: %s',source_file);
                RR_phase(dyadi,condi,:,triali) = reshape(this_RR,1,1,nmeters);
                DET_phase(dyadi,condi,:,triali) = reshape(this_DET,1,1,nmeters);
            end
        end
    end
    PhaseRQA.output.RR = RR_phase;
    PhaseRQA.output.DET = DET_phase;
    reuse_source = struct('path',CFG.block6.reuse_rqa_path, ...
        'settings',reference.settings,'metrics',{{'RR','DET'}});
    save(phase_summary_file,'PhaseRQA','which_comp','meter','list_dyads', ...
        'nconds','ntrials','nmeters','CFG','reuse_source','-v7.3')
    fprintf('BLOCK 6: imported validated RR/DET, Component %d; no RQA computation.\n',which_comp);
    continue
end

% Pre-allocate one group-level variable for each RQA output
[RR_phase,L_phase,DET_phase,ENTR_phase,TT_phase,LAM_phase, ...
    Vmax_phase,DIV_phase] = deal( ...
    nan(ndyads,nconds,nmeters,ntrials));

for condi = 1:nconds
    for dyadi = list_dyads
        disp(['Phase-space RQA: condition #' num2str(condi) ...
            ' - dyad #' num2str(dyadi)])
        for triali = 1:CFG.common.trial_counts(dyadi,condi)

            id_trial = CFG.common.trial_indices{dyadi,condi}(triali);
            phase_rqa_file = fullfile(component_output_path,sprintf( ...
                'FREQNESS_PHASERQA_D%d_C%d_T%d.mat', ...
                dyadi,condi,triali));
            if isfile(phase_rqa_file) && ~CFG.block6.overwrite_flag
                S = load(phase_rqa_file,'FREQrqa','PhaseRQA','id_trial');
                assert(isfield(S,'PhaseRQA') && isfield(S,'id_trial') && ...
                    isequaln(S.PhaseRQA,PhaseRQA) && S.id_trial == id_trial, ...
                    'Saved phase-space RQA settings/trial differ: %s',phase_rqa_file);
                for metri = 1:nmeters
                    RR_phase(dyadi,condi,metri,triali) = S.FREQrqa(metri).RR;
                    L_phase(dyadi,condi,metri,triali) = S.FREQrqa(metri).L;
                    DET_phase(dyadi,condi,metri,triali) = S.FREQrqa(metri).DET;
                    ENTR_phase(dyadi,condi,metri,triali) = S.FREQrqa(metri).ENTR;
                    TT_phase(dyadi,condi,metri,triali) = S.FREQrqa(metri).TT;
                    LAM_phase(dyadi,condi,metri,triali) = S.FREQrqa(metri).LAM;
                    Vmax_phase(dyadi,condi,metri,triali) = S.FREQrqa(metri).Vmax;
                    DIV_phase(dyadi,condi,metri,triali) = S.FREQrqa(metri).DIV;
                end
                continue
            end

            % Reuse core estimates, never older RQA results with another filter.
            core_name = sprintf('FREQNESS_CORE_D%d_C%d_T%d.mat',dyadi,condi,triali);
            input_file = fullfile(CFG.block1.output_path,core_name);
            if ~isfile(input_file) && ~isempty(CFG.block6.reuse_core_path)
                input_file = fullfile(CFG.block6.reuse_core_path,core_name);
            end
            assert(isfile(input_file),'Missing BLOCK 1 output: %s',input_file);
            S = load(input_file,'GED','beat_frex','id_trial');
            if isfield(S,'id_trial'), assert(S.id_trial == id_trial); end
            GED = S.GED;
            beat_frex = S.beat_frex;

            if strcmp(CFG.common.filter_width_calibration,'legacy')
                expected_fwhm = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
                    GED.frex,CFG.common.filter_type);
            else
                expected_fwhm = FREQNESS_ComputeFilterWidths_Mocap( ...
                    GED.frex,CFG.common.filter_type);
            end
            assert(isequal(size(GED.fwhm),size(expected_fwhm)) && ...
                max(abs(GED.fwhm-expected_fwhm),[],'all') < 1e-12, ...
                'Core filter widths do not match CFG: %s',input_file);
            if isfield(GED,'srate')
                assert(GED.srate == CFG.block6.srate, ...
                    'Core sampling rate differs from CFG.block6.srate.');
            end

            if isempty(PhaseRQA.target_frex)
                this_target_frex = beat_frex;
            else
                this_target_frex = PhaseRQA.target_frex;
            end

            % Filter the complete 250 Hz series before decimation, then let
            % the toolbox crop 10--45 s on the 25 Hz sample grid, retaining
            % inclusive indices 251:1126 (876 samples) of each 60 s trial.
            assert(~isfield(GED,'bad_segments') || isempty(GED.bad_segments), ...
                'BLOCK 6 expects the complete, gap-free Dance core time series.');
            phase_components = PhaseRQA.component;
            if isscalar(phase_components)
                phase_components = repmat(phase_components,1,nsubs);
            end
            if numel(phase_components) ~= nsubs
                error(['PhaseRQA.component must be a scalar or contain one ' ...
                    'component per participant.']);
            end
            for subi = 1:nsubs
                for frexi = 1:size(GED.ts,3)
                    this_ts = reshape(GED.ts(phase_components(subi), ...
                        :,frexi,subi),[],1);
                    GED.ts(phase_components(subi),:,frexi,subi) = ...
                        filtfilt(b_butt,a_butt,this_ts);
                end
            end
            GED.ts = GED.ts(:,1:dwn:end,:,:);

            % Compute the joint phase-space recurrence analysis. The saved
            % study variable is named GED but follows the public FREQ API.
            make_figure = PhaseRQA.figure && condi == 1 && ...
                dyadi == list_dyads(1) && triali == 1;
            FREQrqa = FREQNESS_TimeCoord_Mocap( ...
                GED,this_target_frex,'method','phase_space', ...
                'metric_levels',meter, ...
                'component',PhaseRQA.component, ...
                'duration',duration, ...
                'standardize',PhaseRQA.standardize, ...
                'threshold_method',PhaseRQA.threshold_method, ...
                'threshold',PhaseRQA.threshold, ...
                'theiler_window',PhaseRQA.theiler_window, ...
                'lmin',PhaseRQA.lmin, ...
                'vmin',PhaseRQA.vmin, ...
                'store_matrices',false, ...
                'figure',make_figure, ...
                'animate',PhaseRQA.animate && make_figure, ...
                'srate',srate);
            % Each partner's own song anchors the same beat-relative meters.
            selected_frex = vertcat(FREQrqa.SelectedFrequencies)';
            assert(max(abs(selected_frex-reshape(this_target_frex,[],1)*meter), ...
                [],'all') < 1e-10, ...
                'A requested Dance meter is absent from the core frequency grid.');

            % Assign every RQA output returned by temporal coordination
            for metri = 1:nmeters
                RR_phase(dyadi,condi,metri,triali)   = FREQrqa(metri).RR;
                L_phase(dyadi,condi,metri,triali)    = FREQrqa(metri).L;
                DET_phase(dyadi,condi,metri,triali)  = FREQrqa(metri).DET;
                ENTR_phase(dyadi,condi,metri,triali) = FREQrqa(metri).ENTR;
                TT_phase(dyadi,condi,metri,triali)   = FREQrqa(metri).TT;
                LAM_phase(dyadi,condi,metri,triali)  = FREQrqa(metri).LAM;
                Vmax_phase(dyadi,condi,metri,triali) = FREQrqa(metri).Vmax;
                DIV_phase(dyadi,condi,metri,triali)  = FREQrqa(metri).DIV;
            end

            save(phase_rqa_file,'FREQrqa','PhaseRQA','dyadi', ...
                'condi','triali','id_trial','input_file','-v7.3')

        end
    end
end

% Keep the manuscript analysis together as a study-level result.
PhaseRQA.output.RR   = RR_phase;
PhaseRQA.output.L    = L_phase;
PhaseRQA.output.DET  = DET_phase;
PhaseRQA.output.ENTR = ENTR_phase;
PhaseRQA.output.TT   = TT_phase;
PhaseRQA.output.LAM  = LAM_phase;
PhaseRQA.output.Vmax = Vmax_phase;
PhaseRQA.output.DIV  = DIV_phase;

phase_summary_file = fullfile(component_output_path, ...
    ['FREQNESS_PHASERQA_SUMMARY_Comp#' num2str(which_comp) '.mat']);
if ~isfile(phase_summary_file) || CFG.block6.overwrite_flag
    save(phase_summary_file,'PhaseRQA','which_comp','meter', ...
        'list_dyads','nconds','ntrials','nmeters','CFG','-v7.3')
else
    S = load(phase_summary_file,'PhaseRQA','list_dyads','CFG');
    assert(isequaln(S.PhaseRQA,PhaseRQA) && ...
        isequal(S.list_dyads,list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Saved phase-space summary differs; select a new output folder or explicitly overwrite.');
end

end

%% BLOCK 7 - MAIN GROUP-LEVEL VISUALIZATION

figure_scope = 'Main';
run(fullfile(fileparts(CFG.common.data_path),'Rosso_et_al_Dance_inPreparation', ...
    'Supporting','DyadicDance_GroupFigures.m'));

%% BLOCK 8 - R-READY STATISTICAL EXPORT

% This block is independent of the group-visualization workspace. It loads
% each component summary and exports the manuscript phase-space workbooks.
% Spatial export is independent of phase-space RQA.
visual_labels = ["No", "No", "Yes", "Yes"];
music_labels = ["Diff", "Same", "Diff", "Same"];

% Primary: mean raw trial r. Sensitivity: mean atanh(trial r), NOT atanh(mean r).
spatial_statistics_path = fullfile(CFG.block8.output_path,'SpatialCoordination');
if ~isfolder(spatial_statistics_path), mkdir(spatial_statistics_path); end
for which_comp = CFG.block3.components
    S = load(fullfile(CFG.block3.output_path,['Component_' num2str(which_comp)], ...
        ['FREQNESS_SPATIAL_SUMMARY_Comp#' num2str(which_comp) '.mat']), ...
        'MIRROR','list_dyads','CFG');
    assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Spatial summary does not cover the configured dyads/trials.');
    for dyadi = S.list_dyads
        for condi = 1:4
            trial_values = S.MIRROR(dyadi,condi,:,1:CFG.common.trial_counts(dyadi,condi));
            assert(all(isfinite(trial_values),'all') && all(abs(trial_values)<1,'all'), ...
                'Missing/invalid retained spatial trials for D%d C%d.',dyadi,condi);
        end
    end
    avg_MIRROR = mean(S.MIRROR,4,'omitnan');
    avg_FisherZ = mean(atanh(S.MIRROR),4,'omitnan');
    [Dyad,Mirror,FisherZ] = deal(zeros(numel(S.list_dyads)*16,1));
    [Visual,Music,Meter] = deal(strings(size(Dyad)));
    rowi = 0;
    for dyadi = S.list_dyads
        for condi = 1:4
            for metri = 1:4
                rowi = rowi+1;
                Dyad(rowi) = dyadi; Visual(rowi) = visual_labels(condi);
                Music(rowi) = music_labels(condi); Meter(rowi) = "M" + metri;
                Mirror(rowi) = avg_MIRROR(dyadi,condi,metri);
                FisherZ(rowi) = avg_FisherZ(dyadi,condi,metri);
            end
        end
    end
    T = table(Dyad,Visual,Music,Meter,Mirror,FisherZ);
    statistics_file = fullfile(spatial_statistics_path, ...
        ['OUT2R_Comp#' num2str(which_comp) '.xlsx']);
    if ~isfile(statistics_file) || CFG.block8.overwrite_flag
        writetable(T,statistics_file);
    else
        saved_table = readtable(statistics_file,'TextType','string');
        assert(isequal(saved_table(:,1:4),T(:,1:4)) && ...
            max(abs(saved_table{:,5:6}-T{:,5:6}),[],'all') < 1e-12, ...
            'Existing spatial export differs: %s',statistics_file);
    end
    fprintf('Spatial export: %d dyads, Component %d, %s\n', ...
        numel(S.list_dyads),which_comp,statistics_file);
end

%% Manuscript phase-space export
% Export manuscript phase-space RR and DET to their configuration-tagged
% folder. Earlier JRQA and phase-space workbooks remain unchanged.
visual_labels = ["No", "No", "Yes", "Yes"];
music_labels = ["Diff", "Same", "Diff", "Same"];
phase_statistics_path = fullfile( ...
    CFG.block8.output_path,CFG.block6.output_tag);
if ~isfolder(phase_statistics_path)
    mkdir(phase_statistics_path)
end

components = CFG.block6.components;
for componenti = 1:numel(components)

    which_comp = components(componenti);
    component_output_path = fullfile( ...
        CFG.block6.output_path,['Component_' num2str(which_comp)]);
    phase_summary_file = fullfile(component_output_path, ...
        ['FREQNESS_PHASERQA_SUMMARY_Comp#' num2str(which_comp) '.mat']);
    assert(isfile(phase_summary_file), ...
        ['Missing Component %d phase-space RQA summary. Run BLOCK 6 ' ...
        'before BLOCK 8.'],which_comp);

    S = load(phase_summary_file, ...
        'PhaseRQA','meter','list_dyads','nconds','ntrials','nmeters','CFG');
    phase_setting_fields = {'components','srate','downsample','lowpass_hz', ...
        'filter_order','duration','metric_levels','standardize', ...
        'threshold_method','threshold','theiler_window','lmin','vmin'};
    assert(all(cellfun(@(name) isequaln( ...
        S.CFG.block6.(name),CFG.block6.(name)),phase_setting_fields)) && ...
        isequal(S.list_dyads,CFG.common.list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Phase-space summary settings/trials differ from the current CFG.');

    % Average the available trial-level dyadic measures before statistical
    % modelling, retaining equal-weight dyad/condition/meter observations.
    avg_RR = mean(S.PhaseRQA.output.RR(S.list_dyads,:,:,:),4,'omitnan');
    avg_RR = reshape(avg_RR, ...
        [numel(S.list_dyads) S.nconds S.nmeters]);
    avg_DET = mean(S.PhaseRQA.output.DET(S.list_dyads,:,:,:),4,'omitnan');
    avg_DET = reshape(avg_DET, ...
        [numel(S.list_dyads) S.nconds S.nmeters]);

    assert(all(isfinite(avg_RR),'all') && all(avg_RR > 0,'all'), ...
        'Phase-space RR must be finite and positive for log modelling.');
    assert(all(isfinite(avg_DET),'all') && all(avg_DET >= 0 & avg_DET <= 1,'all'), ...
        'Phase-space DET must be finite and within [0,1] for raw-scale modelling.');

    nRows = numel(S.list_dyads)*S.nconds*S.nmeters;
    dyad_col = zeros(nRows,1);
    visual_col = strings(nRows,1);
    music_col = strings(nRows,1);
    meter_col = strings(nRows,1);
    rr_col = zeros(nRows,1);
    det_col = zeros(nRows,1);
    meter_labels = "M" + string(1:S.nmeters);

    row = 1;
    for dyad_idx = 1:numel(S.list_dyads)
        for condi = 1:S.nconds
            for metri = 1:S.nmeters
                dyad_col(row) = S.list_dyads(dyad_idx);
                visual_col(row) = visual_labels(condi);
                music_col(row) = music_labels(condi);
                meter_col(row) = meter_labels(metri);
                rr_col(row) = avg_RR(dyad_idx,condi,metri);
                det_col(row) = avg_DET(dyad_idx,condi,metri);
                row = row + 1;
            end
        end
    end

    T = table(dyad_col,visual_col,music_col,meter_col,rr_col,det_col, ...
        'VariableNames',{'Dyad','Visual','Music','Meter','RR','DET'});

    statistics_file = fullfile(phase_statistics_path, ...
        ['OUT2R_Comp#' num2str(which_comp) '.xlsx']);
    if ~isfile(statistics_file) || CFG.block8.overwrite_flag
        writetable(T,statistics_file)
    else
        saved_table = readtable(statistics_file,'TextType','string');
        assert(isequal(saved_table(:,1:4),T(:,1:4)) && ...
            max(abs(saved_table{:,5:6}-T{:,5:6}),[],'all') < 1e-12, ...
            'Existing phase-space export differs: %s',statistics_file);
    end
    fprintf('Saved Component %d phase-space RQA statistics: %s\n', ...
        which_comp,statistics_file);

end
