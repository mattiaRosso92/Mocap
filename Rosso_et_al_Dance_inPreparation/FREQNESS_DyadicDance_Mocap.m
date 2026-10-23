clear
close all
clc


%% BLOCK 0 - USER SETTINGS, STARTUP, AND OUTPUT ROUTING

% All raw inputs and all newly generated outputs stay on the local drive in
% Dance_Data. The dedicated results root prevents this replication from
% modifying any legacy analyses currently stored directly in Dance_Data.
script_file = mfilename('fullpath');
if isempty(script_file)
    % MATLAB can return an empty mfilename when an editor section is run
    % interactively rather than by running the complete script.
    try
        script_file = matlab.desktop.editor.getActiveFilename;
    catch
        script_file = '';
    end
end
if isempty(script_file)
    script_candidates = { ...
        fullfile(pwd,'FREQNESS_DyadicDance_Mocap.m'), ...
        fullfile(pwd,'Rosso_et_al_Dance_inPreparation', ...
        'FREQNESS_DyadicDance_Mocap.m')};
    candidate_idx = find(cellfun(@isfile,script_candidates),1);
    assert(~isempty(candidate_idx), ...
        ['Could not locate FREQNESS_DyadicDance_Mocap.m. Open the script ' ...
        'in the MATLAB Editor or run it from the Mocap repository.']);
    script_file = script_candidates{candidate_idx};
end
path_script = fileparts(script_file);
path_repo = fileparts(path_script);

% Locate the repository data folder robustly. Depending on how a script
% section is launched, MATLAB may report the active file or working folder
% differently, so validate candidates by their Dance metadata contents.
required_metadata = {'cond_vis.csv','cond_mus.csv', ...
    'song_subj_LEFT.csv','song_subj_RIGHT.csv'};
data_candidates = unique({ ...
    fullfile(path_repo,'Dance_Data'), ...
    fullfile(path_script,'Dance_Data'), ...
    fullfile(pwd,'Dance_Data'), ...
    fullfile(fileparts(pwd),'Dance_Data'), ...
    fullfile(getenv('HOME'),'Documents','GitHub','Mocap', ...
    'Dance_Data')},'stable');
valid_data_folder = false(size(data_candidates));
for candidatei = 1:numel(data_candidates)
    valid_data_folder(candidatei) = isfolder(data_candidates{candidatei}) && ...
        all(cellfun(@(filename) isfile(fullfile( ...
        data_candidates{candidatei},filename)),required_metadata));
end
data_idx = find(valid_data_folder,1);
assert(~isempty(data_idx), ...
    ['Dance_Data could not be located from the active script or current ' ...
    'MATLAB folder.']);
data_path = data_candidates{data_idx};
path_repo = fileparts(data_path);

CFG = [];
CFG.common.data_path = data_path;
% Preserve the study's historical filtering by default. Select 'physical'
% to use the toolbox's frequency-calibrated widths for a new GED analysis.
CFG.common.filter_width_calibration = validatestring( ...
    'legacy',{'physical','legacy'});
CFG.common.filter_type = validatestring( ...
    'logarithmic',{'logarithmic','linear'});
CFG.common.filter_output_tag = [CFG.common.filter_width_calibration ...
    '_' CFG.common.filter_type];
CFG.common.results_folder = fullfile( ...
    'FREQNESS_Results_Rosso_et_al_inPreparation', ...
    [CFG.common.filter_output_tag '_recovered_dyads']);
CFG.common.results_path = fullfile( ...
    CFG.common.data_path,CFG.common.results_folder);
CFG.common.ncomps = 4;
CFG.common.list_dyads = 1:35;
% Original recording IDs, not within-condition trial slots.
% Dyad 32 trial 32 contains no recorded marker coordinates for either partner.
CFG.common.excluded_trials = [32 32];
% Reuse matching original outputs across ALL blocks, not only temporal RQA.
CFG.common.reuse_results_path = '';
if strcmp(CFG.common.filter_output_tag,'legacy_logarithmic')
    CFG.common.reuse_results_path = fullfile(CFG.common.data_path, ...
        'FREQNESS_Results_Rosso_et_al_inPreparation');
end
CFG.common.reuse_core_path = '';
if ~isempty(CFG.common.reuse_results_path)
    CFG.common.reuse_core_path = fullfile(CFG.common.reuse_results_path,'01_Core');
end

CFG.block1.output_path = fullfile( ...
    CFG.common.results_path,'01_Core');
CFG.block1.overwrite_flag = false;
CFG.block2.output_path = fullfile( ...
    CFG.common.results_path,'02_Landscape');
CFG.block2.overwrite_flag = false;
CFG.block3.output_path = fullfile( ...
    CFG.common.results_path,'03_Coordination');
CFG.block3.overwrite_flag = false;
CFG.block3.components = 1:2;
CFG.block3.reuse_legacy_jrqa = false; % Plot saved historical JRQA only; never recompute.
CFG.block4.output_path = fullfile(CFG.common.results_path,'04_MetricProminence');
CFG.block4.component = 1;
CFG.block4.metric_levels = [.25 .5 1 2];
CFG.block4.global_metric_levels = []; % Toolbox default: all available metric levels.
CFG.block4.overwrite_flag = false;
CFG.block4.reuse_core_path = CFG.common.reuse_core_path;
CFG.block5.output_path = fullfile(CFG.common.results_path,'05_LandscapeSimilarity');
CFG.block5.component = 1;
CFG.block5.overwrite_flag = false;
CFG.block5.reuse_core_path = CFG.common.reuse_core_path;
% Manuscript phase-space RQA: the validated 25 Hz, non-standardised analysis.
% These settings affect only downstream RQA, not core network estimation.
CFG.block6.overwrite_flag = false;
CFG.block6.components = 1:2;
CFG.block6.srate = 250;
CFG.block6.downsample = 10;
CFG.block6.lowpass_hz = 10; % Fixed physical cutoff, independent of downsample.
CFG.block6.filter_order = 4;
CFG.block6.duration = [.15 .85];
CFG.block6.metric_levels = [.25 .5 1 2];
CFG.block6.standardize = false;
CFG.block6.threshold_method = 'max_fraction';
CFG.block6.threshold = .1; % 10% of each trial's maximum JOINT Euclidean distance.
CFG.block6.theiler_window = 0; % Retain the identity diagonal, as in the validated run.
CFG.block6.lmin = 2;
CFG.block6.vmin = 2;
CFG.block6.output_tag = sprintf( ...
    'PhaseSpaceRQA_AA%gHz_Dwn%d_Radius%g_Standardize%d', ...
    CFG.block6.lowpass_hz,CFG.block6.downsample, ...
    100*CFG.block6.threshold,CFG.block6.standardize);
CFG.block6.output_path = fullfile( ...
    CFG.common.results_path,['04_' CFG.block6.output_tag]);
CFG.block6.reuse_core_path = CFG.common.reuse_core_path;
% Reuse the validated RR/DET comparison if present; never import older filters.
CFG.block6.reuse_rqa_path = '';
if strcmp(CFG.common.filter_output_tag,'legacy_logarithmic') && ...
        isfolder(fullfile(CFG.common.results_path, ...
        'PhaseSpaceRQA_AA10Hz_Downsample_20261017'))
    CFG.block6.reuse_rqa_path = fullfile(CFG.common.results_path, ...
        'PhaseSpaceRQA_AA10Hz_Downsample_20261017');
end
CFG.block7.output_path = fullfile( ...
    CFG.common.results_path,'05_Group');
CFG.block7.figure_path = fullfile( ...
    CFG.block7.output_path,'Figures',CFG.block6.output_tag);
CFG.block7.overwrite_flag = false;
CFG.block8.output_path = fullfile( ...
    CFG.common.results_path,'06_Statistics_R');
CFG.block8.overwrite_flag = false;
CFG.block8.export_jrqa = false; % Historical JRQA only; spatial exports always run.

% Core analysis settings. Visualizing every single trial would open more
% than one thousand figures, so trial visualization is optional in BLOCK 1
% and group visualization is consolidated in BLOCK 7.
CFG.block1.visualize = false;
CFG.block1.save = true;

% Confirm that this run is isolated from the legacy result locations.
path_home = CFG.common.data_path;
assert(isfolder(path_home), ...
    'Dance_Data was not found at the repository-relative local path.');
assert(~strcmp(CFG.common.results_path,path_home), ...
    'The results root must differ from the raw-data root.');
assert(startsWith(CFG.common.results_path,[path_home filesep]), ...
    'The results root must be a child folder of Dance_Data.');

for filei = 1:numel(required_metadata)
    assert(isfile(fullfile(path_home,required_metadata{filei})), ...
        'Missing Dance input file: %s',required_metadata{filei});
end

output_paths = {CFG.block1.output_path,CFG.block2.output_path,CFG.block4.output_path, ...
    CFG.block5.output_path, ...
    CFG.block3.output_path,CFG.block6.output_path, ...
    CFG.block7.output_path,CFG.block7.figure_path, ...
    CFG.block8.output_path};
for pathi = 1:numel(output_paths)
    if ~isfolder(output_paths{pathi})
        mkdir(output_paths{pathi})
    end
end

% Save the exact run configuration in the new results root. Do not replace
% a previous configuration unless overwrite_flag is explicitly enabled.
configuration_file = fullfile( ...
    CFG.common.results_path,'FREQNESS_Dance_RunConfiguration.mat');

% Choose if you want to enable visualizations
vis_flag = CFG.block1.visualize;

% Choose if you want to enable saving of FREQNESS output
save_flag = CFG.block1.save;

% Choose the method youn want to use for FREQNESS (GED or PCA)
which_method = 'GED';

% Initialize the MoCap toolbox and external dependencies
path_toolbox = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');
addpath(path_toolbox)
FREQNESS_Startup_Mocap();

% Filter data by experimental conditions
% 	- 'cond_vis': each cell informs about the condition of a trial (0='No Visual Contact', 1='Visual Contact')
% 	- 'cond_mus': each cell informs about the condition of a trial (0='Different Music', 1='Same Music')
lbl_vis = readmatrix(fullfile(path_home,'cond_vis.csv'), ...
    'NumHeaderLines',1);
lbl_vis = lbl_vis(:,2:end);
lbl_mus = readmatrix(fullfile(path_home,'cond_mus.csv'), ...
    'NumHeaderLines',1);
lbl_mus = lbl_mus(:,2:end);


%% Prepare data

% Define sampling rate
srate = 250;

% Design settings
ndyads = 35;
list_dyads = CFG.common.list_dyads;
sublabels= {'_LEFT', '_RIGHT'};
nsubs = length(sublabels);
% Design matrix (label_visual, labels_music)
desMat = [ 0 0 ;  % 'No Visual'  , 'Different Music'ta
    0 1 ;  % 'No Visual'  , 'Same Music'
    1 0 ;  % 'Yes Visual' , 'Different Music'
    1 1 ]; % 'Yes Visual' , 'Same Music'
nconds  = size(desMat,1);
condlabels = {'NOvis-DIFFmus', 'NOvis-SAMEmus', 'YESvis-DIFFmus', 'YESvis-SAMEmus'};
% Preserve the recorded condition labels, including dyad 13's 7/8/9/8 split.
% Unused trial slots are NaN, never zero-valued observations.
CFG.common.trial_indices = cell(ndyads,nconds);
for dyadi = list_dyads
    for condi = 1:nconds
        list_trials = find(lbl_vis(dyadi,:) == desMat(condi,1) & ...
            lbl_mus(dyadi,:) == desMat(condi,2));
        excluded_trials = CFG.common.excluded_trials( ...
            CFG.common.excluded_trials(:,1) == dyadi,2);
        CFG.common.trial_indices{dyadi,condi} = ...
            setdiff(list_trials,excluded_trials,'stable');
        assert(~isempty(CFG.common.trial_indices{dyadi,condi}), ...
            'No usable trials for dyad %d, condition %d.',dyadi,condi);
    end
end
CFG.common.trial_counts = cellfun(@numel,CFG.common.trial_indices);
CFG.common.ntrials = max(CFG.common.trial_counts,[],'all');
ntrials = CFG.common.ntrials;
if ~isfile(configuration_file) || CFG.block1.overwrite_flag
    save(configuration_file,'CFG')
end


% Base labels (already excluded the last marker)
marklabels = {'LB Head','LF Head','RF Head','RB Head','Sternum','L Shoulder','R Shoulder', ...
    'L Elbow','L Wrist','L Hand','R Elbow','R Wrist','R Hand','Pelvis','L Hip', ...
    'R Hip','L Knee','L Ankle','L Foot','R Knee','R Ankle','R Foot'};

% Dance-study 22-marker skeleton, shared by all visualization blocks.
bones = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10; ...
    7,11;11,12;12,13;14,15;14,16;15,16;15,17;17,18;18,19; ...
    16,20;20,21;21,22];

% Expand with X, Y, Z prefixes
xyz_marklabels = cell(1, length(marklabels) * 3);
nmarks = size(xyz_marklabels,2);

for i = 1:length(marklabels)
    xyz_marklabels{3*(i-1)+1} = ['X_' marklabels{i}];
    xyz_marklabels{3*(i-1)+2} = ['Y_' marklabels{i}];
    xyz_marklabels{3*(i-1)+3} = ['Z_' marklabels{i}];
end

% Song BPM (all songs)
song_bpms = [111.03, 116.07, 118.23, 118.95, 120.47, 125.93, 128.27, 129.06];

% Define metric levels of interest
meter = [.25 .5 1 2];
nmeters = length(meter);



%% Select spatial dimensions (all included by default)

% Choose whether you want one dimension
idx_XYZ = 1; % 1 = '', all axes included

% Prefixes for saving the output
prefix = {'';'_onlyX';'_onlyY';'_onlyZ'};

% Define X,Y,Z indexes
x_idx = 1:3:nmarks-2;
y_idx = 2:3:nmarks-1;
z_idx = 3:3:nmarks;


%% BLOCK 1 - NETWORK ESTIMATION
 
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
                dyadi,condi,triali,prefix{idx_XYZ}));
            input_file = output_file;
            if ~isfile(input_file) && ~isempty(CFG.common.reuse_core_path)
                input_file = fullfile(CFG.common.reuse_core_path,sprintf( ...
                    'FREQNESS_CORE_D%d_C%d_T%d%s.mat', ...
                    dyadi,condi,triali,prefix{idx_XYZ}));
            end
            if isfile(input_file) && ~CFG.block1.overwrite_flag
                if strcmp(which_method,'GED')
                    % Read only compact fields; do not reload saved time series.
                    saved_core = load(input_file,'id_trial');
                    assert(saved_core.id_trial == id_trial,'Saved core trial ID differs.');
                    saved_frex = h5read(input_file,'/GED/frex');
                    saved_fwhm = h5read(input_file,'/GED/fwhm');
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
                end
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

            %% OPTIONAL: convert data to velocity
            % 
            % % NOTE: Ask Petri & Felix whether they project the position
            % % data after the eigendecomposition
            % 
            % dt = 1/srate; % differentiate by time units
            % markData = diff(markData,1,2) / dt; % compute velocity


            %% Run network decomposition on the dyad

            % ncomps controls retained eigenvectors, patterns, and time
            % series only. The complete eigenspectrum is always retained
            % and remains available to EffectDimensionality.

            if strcmp(which_method,'GED')

                % Compute FREQNESS with GED
                if strcmp(CFG.common.filter_width_calibration,'legacy')
                    filter_width = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
                        frex,CFG.common.filter_type);
                    expected_filter_width = filter_width;
                else
                    filter_width = [];
                    expected_filter_width = FREQNESS_ComputeFilterWidths_Mocap( ...
                        frex,CFG.common.filter_type);
                end
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
                PCA = FREQNESS_NetworkEstimation_Mocap_PCA(markData, frex, srate, ...
                    'ncomps',CFG.common.ncomps); % networks estimation
                %ED(condi,dyadi,triali,:,:)  = FREQNESS_EffectDim(PCA.evals); % effective dimensionality
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
                FREQNESS_Visualizer_Mocap(GED,Landscape,Patterns)


            end



        end

    end

end




%% BLOCK 2 - NETWORK LANDSCAPES AND EFFECTIVE DIMENSIONALITY

% Select method: 'GED' or 'PCA'
which_method = 'GED';

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

% The legacy spatial summaries already contain the corrected magnitude-pattern
% correlations. Reuse these 33 dyads unchanged, never their temporal outputs.
legacy_spatial = [];
legacy_spatial_file = fullfile(CFG.common.reuse_results_path, ...
    '03_Coordination',['Component_' num2str(which_comp)], ...
    ['FREQNESS_COORDINATION_SUMMARY_Comp#' num2str(which_comp) '.mat']);
if ~isempty(CFG.common.reuse_results_path) && isfile(legacy_spatial_file) && ...
        ~CFG.block3.overwrite_flag
    legacy_spatial = load(legacy_spatial_file,'MIRROR','list_dyads','which_comp','meter');
    assert(legacy_spatial.which_comp == which_comp && isequal(legacy_spatial.meter,meter) && ...
        isequal(legacy_spatial.list_dyads,setdiff(1:35,[13 32])), ...
        'Unexpected legacy spatial summary; inspect before reuse.');
end


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
                if ~isempty(legacy_spatial) && ismember(dyadi,legacy_spatial.list_dyads)
                    assert(CFG.common.trial_counts(dyadi,condi) == 8);
                    FREQmirror = reshape(legacy_spatial.MIRROR(dyadi,condi,:,triali),1,[]);
                    input_file = legacy_spatial_file;
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
                end
                save(spatial_file,'FREQmirror','which_comp','meter', ...
                    'dyadi','condi','triali','id_trial','input_file');
            end
            assert(all(isfinite(FREQmirror)) && all(abs(FREQmirror)<1), ...
                'Undefined/perfect spatial correlation; inspect %s.',spatial_file);
            MIRROR(dyadi,condi,:,triali) = reshape(FREQmirror,1,1,nmeters);

        end
    end
end

% Historical JRQA summaries are read-only references, never produced here.
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

%% BLOCK 4 - METRIC PROMINENCE

% Individual prominence is averaged across partners, then across trials.
% This is dyad-mean individual prominence, not a coordination measure.
clearvars -except CFG
addpath(fullfile(fileparts(CFG.common.data_path),'FREQNESS_Mocap_Toolbox'))
FREQNESS_Startup_Mocap();
component_path = fullfile(CFG.block4.output_path, ...
    ['Component_' num2str(CFG.block4.component)]);
if ~isfolder(component_path), mkdir(component_path); end
settings = struct('component',CFG.block4.component, ...
    'metric_levels',CFG.block4.metric_levels, ...
    'global_metric_levels',CFG.block4.global_metric_levels);
assert(isequal(settings.metric_levels,[.25 .5 1 2]), ...
    'The five-outcome Dance export requires metric_levels = [.25 .5 1 2].');
prominence = nan(35,4,CFG.common.ntrials,5); % dyad x condition x trial x outcome
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for triali = 1:CFG.common.trial_counts(dyadi,condi)
            id_trial = CFG.common.trial_indices{dyadi,condi}(triali);
            output_file = fullfile(component_path,sprintf( ...
                'FREQNESS_METRIC_D%d_C%d_T%d.mat',dyadi,condi,triali));
            if isfile(output_file) && ~CFG.block4.overwrite_flag
                S = load(output_file,'METER','id_trial','settings');
                assert(S.id_trial == id_trial && ...
                    S.settings.component == settings.component && ...
                    isequaln(S.settings.metric_levels,settings.metric_levels) && ...
                    isequaln(S.settings.global_metric_levels,settings.global_metric_levels), ...
                    'Saved prominence settings/trial differ: %s',output_file);
                METER = S.METER;
            else
                core_name = sprintf('FREQNESS_CORE_D%d_C%d_T%d.mat',dyadi,condi,triali);
                input_file = fullfile(CFG.block1.output_path,core_name);
                if ~isfile(input_file) && ~isempty(CFG.block4.reuse_core_path)
                    input_file = fullfile(CFG.block4.reuse_core_path,core_name);
                end
                assert(isfile(input_file),'Missing core output: %s',input_file);
                S = load(input_file,'GED','beat_frex','id_trial');
                if isfield(S,'id_trial'), assert(S.id_trial == id_trial); end
                METER = FREQNESS_MetricProminence_Mocap(S.GED,S.beat_frex, ...
                    'component',CFG.block4.component, ...
                    'metric_levels',CFG.block4.metric_levels, ...
                    'global_metric_levels',CFG.block4.global_metric_levels);
                save(output_file,'METER','settings','input_file', ...
                    'dyadi','condi','triali','id_trial');
            end
            assert(isequal(size(METER.MetricProminence),[4 2]));
            prominence(dyadi,condi,triali,:) = reshape( ...
                mean([METER.GlobalProminence;METER.MetricProminence],2),1,1,1,5);
        end
    end
end
summary_file = fullfile(component_path,'FREQNESS_METRIC_SUMMARY.mat');
if ~isfile(summary_file) || CFG.block4.overwrite_flag
    save(summary_file,'prominence','CFG');
else
    S = load(summary_file,'prominence','CFG');
    assert(isequaln(S.prominence,prominence) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Existing prominence summary has different data/trials.');
end
% Export independently: no JRQA, phase-space or visualization block is required.
prominence_avg = mean(prominence,3,'omitnan');
visual_labels = ["No" "No" "Yes" "Yes"];
music_labels = ["Diff" "Same" "Diff" "Same"];
outcome_labels = ["Global" "M1" "M2" "M3" "M4"];
[Dyad,Prominence] = deal(zeros(numel(CFG.common.list_dyads)*20,1));
[Visual,Music,Level] = deal(strings(size(Dyad)));
rowi = 0;
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for leveli = 1:5
            rowi = rowi+1;
            Dyad(rowi) = dyadi; Visual(rowi) = visual_labels(condi);
            Music(rowi) = music_labels(condi); Level(rowi) = outcome_labels(leveli);
            Prominence(rowi) = prominence_avg(dyadi,condi,1,leveli);
        end
    end
end
assert(all(isfinite(Prominence) & Prominence > 0));
export_file = fullfile(component_path,'OUT2R_MetricProminence.csv');
if ~isfile(export_file) || CFG.block4.overwrite_flag
    writetable(table(Dyad,Visual,Music,Level,Prominence),export_file);
else
    S = readtable(export_file,'TextType','string');
    assert(isequal(S(:,1:4),table(Dyad,Visual,Music,Level)) && ...
        max(abs(S.Prominence-Prominence)) < 1e-12, ...
        'Existing prominence export has different dyads/data.');
end

%% BLOCK 5 - LANDSCAPE SIMILARITY

clearvars -except CFG
addpath(fullfile(fileparts(CFG.common.data_path),'FREQNESS_Mocap_Toolbox'))
FREQNESS_Startup_Mocap();
component_path = fullfile(CFG.block5.output_path, ...
    ['Component_' num2str(CFG.block5.component)]);
if ~isfolder(component_path), mkdir(component_path); end
settings = struct('component',CFG.block5.component,'frequency_axis','beat_relative');
similarity = nan(35,4,CFG.common.ntrials,2); % dyad x condition x trial x outcome
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for triali = 1:CFG.common.trial_counts(dyadi,condi)
            id_trial = CFG.common.trial_indices{dyadi,condi}(triali);
            output_file = fullfile(component_path,sprintf( ...
                'FREQNESS_SIMILARITY_D%d_C%d_T%d.mat',dyadi,condi,triali));
            if isfile(output_file) && ~CFG.block5.overwrite_flag
                S = load(output_file,'similarity_comp','similarity_entropy','id_trial','settings');
                assert(S.id_trial == id_trial && isequaln(S.settings,settings), ...
                    'Saved similarity settings/trial differ: %s',output_file);
                similarity_comp = S.similarity_comp;
                similarity_entropy = S.similarity_entropy;
            else
                core_name = sprintf('FREQNESS_CORE_D%d_C%d_T%d.mat',dyadi,condi,triali);
                input_file = fullfile(CFG.block1.output_path,core_name);
                if ~isfile(input_file) && ~isempty(CFG.block5.reuse_core_path)
                    input_file = fullfile(CFG.block5.reuse_core_path,core_name);
                end
                assert(isfile(input_file),'Missing core output: %s',input_file);
                S = load(input_file,'GED','beat_frex','id_trial');
                if isfield(S,'id_trial'), assert(S.id_trial == id_trial); end
                relative_frex = S.GED.frex./reshape(S.beat_frex,1,[]);
                assert(isequal(size(relative_frex),[32 2]) && ...
                    max(abs(relative_frex-(1:32)'/8),[],'all') < 1e-12, ...
                    'Expected both partners on the 1/8-to-4x beat grid: %s',input_file);
                % Align corresponding beat multiples, NOT absolute Hz: keep
                % eigenvalues unchanged; no interpolation or re-estimation.
                FREQ = struct('evals',S.GED.evals,'frex',(1:32)'/8);
                [similarity_comp,similarity_entropy,selected_frex] = ...
                    FREQNESS_LandscapeSimilarity(FREQ,'component',settings.component);
                save(output_file,'similarity_comp','similarity_entropy', ...
                    'selected_frex','settings','input_file','dyadi','condi','triali','id_trial');
            end
            this_similarity = [similarity_comp similarity_entropy];
            assert(numel(this_similarity)==2 && all(isfinite(this_similarity)) && ...
                all(abs(this_similarity)<1), ...
                'Undefined or perfect correlation; inspect D%d C%d T%d before Fisher transformation.', ...
                dyadi,condi,triali);
            similarity(dyadi,condi,triali,:) = reshape(this_similarity,1,1,1,2);
        end
    end
end
summary_file = fullfile(component_path,'FREQNESS_SIMILARITY_SUMMARY.mat');
if ~isfile(summary_file) || CFG.block5.overwrite_flag
    save(summary_file,'similarity','CFG');
else
    S = load(summary_file,'similarity','CFG');
    assert(isequaln(S.similarity,similarity) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Existing similarity summary has different data/trials.');
end
% Average trial correlations in Fisher-z space, retaining signed similarity.
similarity_z = mean(atanh(similarity),3,'omitnan');
visual_labels = ["No" "No" "Yes" "Yes"];
music_labels = ["Diff" "Same" "Diff" "Same"];
outcome_labels = ["Component" "Entropy"];
[Dyad,FisherZ] = deal(zeros(numel(CFG.common.list_dyads)*8,1));
[Visual,Music,Outcome] = deal(strings(size(Dyad)));
rowi = 0;
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for outcomei = 1:2
            rowi = rowi+1;
            Dyad(rowi) = dyadi; Visual(rowi) = visual_labels(condi);
            Music(rowi) = music_labels(condi); Outcome(rowi) = outcome_labels(outcomei);
            FisherZ(rowi) = similarity_z(dyadi,condi,1,outcomei);
        end
    end
end
assert(all(isfinite(FisherZ)));
export_file = fullfile(component_path,'OUT2R_LandscapeSimilarity.csv');
if ~isfile(export_file) || CFG.block5.overwrite_flag
    writetable(table(Dyad,Visual,Music,Outcome,FisherZ),export_file);
else
    S = readtable(export_file,'TextType','string');
    assert(isequal(S(:,1:4),table(Dyad,Visual,Music,Outcome)) && ...
        max(abs(S.FisherZ-FisherZ)) < 1e-12, ...
        'Existing similarity export has different dyads/data.');
end

%% BLOCK 6 - PHASE-SPACE RQA (MANUSCRIPT TEMPORAL COORDINATION)

% The selected manuscript analysis remains independent of historical JRQA.
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
            % the toolbox crop the 15--85% interval on the 25 Hz sample grid.
            % This ordering preserves the validated endpoints (1051 samples).
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

%% BLOCK 7 - GROUP-LEVEL VISUALIZATION

% TODO: SEM are fixed, but still do the following for other plots:
% After fixing, if needed, do the same in FREQNESS_SI_FIlters.m (what about
% all other plots? massive fix with chatGPT

path_data = CFG.block2.output_path;

% Restore plotting metadata cleared before the coordination analyses.
prefix = {'';'_onlyX';'_onlyY';'_onlyZ'};
srate = 250;
ndyads = 35;
nconds = 4;
ntrials = CFG.common.ntrials;
nsubs = 2;
list_dyads = CFG.common.list_dyads;
condlabels = {'NOvis-DIFFmus','NOvis-SAMEmus', ...
    'YESvis-DIFFmus','YESvis-SAMEmus'};
meter = [.25 .5 1 2];
nmeters = length(meter);
marklabels = {'LB Head','LF Head','RF Head','RB Head','Sternum', ...
    'L Shoulder','R Shoulder','L Elbow','L Wrist','L Hand', ...
    'R Elbow','R Wrist','R Hand','Pelvis','L Hip','R Hip', ...
    'L Knee','L Ankle','L Foot','R Knee','R Ankle','R Foot'};
bones = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10; ...
    7,11;11,12;12,13;14,15;14,16;15,16;15,17;17,18;18,19; ...
    16,20;20,21;21,22];

% Import the compact component summaries saved by BLOCKS 3 and 6. Keeping
% the component dimension here ensures that every requested coordination
% analysis is represented in the consolidated group figures.
coordination_components = CFG.block3.components;
coordination_results = cell(1,numel(coordination_components));
for componenti = 1:numel(coordination_components)
    which_comp = coordination_components(componenti);
    coordination_summary_file = fullfile(CFG.block3.output_path, ...
        ['Component_' num2str(which_comp)], ...
        ['FREQNESS_SPATIAL_SUMMARY_Comp#' ...
        num2str(which_comp) '.mat']);
    assert(isfile(coordination_summary_file), ...
        'Missing BLOCK 3 summary: %s',coordination_summary_file);
    S = load(coordination_summary_file,'MIRROR','which_comp','list_dyads','CFG');
    assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Spatial group summary does not cover the configured dyads/trials.');
    coordination_results{componenti} = S;
    if CFG.block3.reuse_legacy_jrqa
        S = load(fullfile(CFG.block3.output_path,['Component_' num2str(which_comp)], ...
            ['FREQNESS_COORDINATION_SUMMARY_Comp#' num2str(which_comp) '.mat']), ...
            'RR','DET','list_dyads','CFG');
        assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
            isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
            'Historical JRQA group summary has different dyads/trials.');
        coordination_results{componenti}.RR = S.RR;
        coordination_results{componenti}.DET = S.DET;
    end
end

phase_components = CFG.block6.components;
phase_results = cell(1,numel(phase_components));
for componenti = 1:numel(phase_components)
    which_comp = phase_components(componenti);
    phase_summary_file = fullfile(CFG.block6.output_path, ...
        ['Component_' num2str(which_comp)], ...
        ['FREQNESS_PHASERQA_SUMMARY_Comp#' num2str(which_comp) '.mat']);
    assert(isfile(phase_summary_file), ...
        'Missing BLOCK 6 summary: %s',phase_summary_file);
    S = load(phase_summary_file,'PhaseRQA','list_dyads','CFG');
    assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Phase-space group summary does not cover the configured dyads/trials.');
    phase_results{componenti} = S;
end

% Select method: 'GED' or 'PCA'
which_method = 'GED';

% Choose whether you want one dimension
idx_XYZ = 1; % 1 = '', all axes included

close all

% Import group-level data
S = load(fullfile(path_data, ...
    ['FREQNESS_GroupNetworkSummary' prefix{idx_XYZ} '.mat']),'list_dyads','CFG');
assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
    isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
    'Network group summary does not cover the configured dyads/trials.');
load(fullfile(path_data, ...
    ['FREQNESS_GroupNetworkSummary' prefix{idx_XYZ} '.mat']), ...
    'all_evals','all_pats','all_frex_norm','ED', ...
    'marker_reference')
markData = marker_reference;
nmarks = size(markData,1);


% Remove excluded dyads while preserving their actual identifiers.
all_evals = all_evals(list_dyads,:,:,:,:,:);
all_pats = abs(all_pats(list_dyads,:,:,:,:,:,:));
all_frex_norm = all_frex_norm(list_dyads,:,:,:,:);
ED = ED(:,list_dyads,:,:,:);

% Settings
ncomps2keep = 4;                 % number of components
nfrex = size(all_evals, 5);      % number of frequencies
colors = [0.90 0.22 0.16; ...
          0.36 0.69 0.88; ...
          0.22 0.45 0.78; ...
          0.12 0.25 0.55];

% Average over trials
avg_evals = squeeze(mean(all_evals, 3, 'omitnan'));   %  [dyads,conds,trials,comps,frex,subs]
avg_pats  = squeeze(mean(all_pats, 3, 'omitnan'));    %  [dyads,conds,trials,markers,comps,frex,subs]

% Compute group mean & SEM over dyads
avg_evals = squeeze(mean(avg_evals,length(size(avg_evals))));  % average over subjects(partners) first
sem_evals = squeeze(std(avg_evals,0,1)) / sqrt(size(avg_evals,1));
avg_evals = squeeze(mean(avg_evals,1));

sem_pats  = squeeze(std(avg_pats,0,1)) / sqrt(size(avg_pats,1));
avg_pats  = squeeze(mean(avg_pats,1));

% Assign any normalized frequency vector
frex2plot = squeeze(all_frex_norm(1,1,1,1,:));


% Log-spaced visualization
% ====== X-axis: build a log2-uniform frequency grid ======
% Assign any normalized frequency vector
frex2plot = squeeze(all_frex_norm(1,1,1,1,:));
frex2plot = sort(frex2plot(:),'ascend');

% Log2-uniform grid across available span
nPoints  = 200;                                   % resolution along x
log2_min = log2(min(frex2plot));
log2_max = log2(max(frex2plot));
log2_frex_uniform = linspace(log2_min,log2_max,nPoints).';
frex_uniform      = 2.^log2_frex_uniform;         % back to linear (×Beat)

% ====== Resample group means & SEM onto that grid ======
% avg_evals & sem_evals are [cond, comp, frex]
avg_evals_rs = zeros(nconds, ncomps2keep, nPoints);
sem_evals_rs = zeros(nconds, ncomps2keep, nPoints);

for condi = 1:nconds
    for compi = 1:ncomps2keep
        y  = squeeze(avg_evals(condi,compi,:));
        se = squeeze(sem_evals(condi,compi,:));
        avg_evals_rs(condi,compi,:) = interp1(frex2plot, y,  frex_uniform, 'linear','extrap');
        sem_evals_rs(condi,compi,:) = interp1(frex2plot, se, frex_uniform, 'linear','extrap');
    end
end

% ====== Plot: x in log2 units (equal octave spacing), labels in linear ======
figure
for condi = 1:nconds
    subplot(2,2,condi); hold on

    for compi = 1:ncomps2keep
        this_y   = squeeze(avg_evals_rs(condi,compi,:));
        this_sem = squeeze(sem_evals_rs(condi,compi,:));

        xx = [log2_frex_uniform; flipud(log2_frex_uniform)];
        yy = [this_y(:)-this_sem(:); flipud(this_y(:)+this_sem(:))];

        fill(xx, yy, colors(compi,:), ...
            'FaceAlpha', 0.22, ...
            'EdgeColor', 'none');

        plot(log2_frex_uniform, this_y, ...
            'Color', colors(compi,:), ...
            'LineWidth', 2.5);
    end

    % Octave ticks within range (adjust set as you like)
    octave_set  = [0.125 0.25 0.5 1 2 4 8];
    in_range    = octave_set >= min(frex_uniform) & octave_set <= max(frex_uniform);
    octave_vals = octave_set(in_range);
    if numel(octave_vals) >= 2
        xticks(log2(octave_vals));                 % positions (log2)
        xticklabels(string(octave_vals));          % show linear freq
    end
    xtickangle(45)

    xlim([min(log2_frex_uniform) max(log2_frex_uniform)])
    ylim([0 80])

    xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')   % linear label
    ylabel('Explained variance (%)', 'FontSize', 14, 'FontWeight', 'bold')
    legend(arrayfun(@(x) sprintf([which_method ' #%d'],x), 1:ncomps2keep, 'UniformOutput', false))
    title(condlabels{condi})

    grid on; grid minor; box on
    set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
    set(gcf, 'Color', 'w');
end

sgtitle(['Bodily network prominence across beat-normalized frequencies - ' which_method])


%%%% ED: SAME LOG2 AXIS APPEARANCE, NO RESAMPLING, SHADED SEM %%%%

% Average ED
ED = squeeze(mean(ED,3,'omitnan'));                   % across trials
ED = squeeze(mean(ED,length(size(ED))));    % across subjects (partners)
avg_ED = squeeze(mean(ED,2));               % avg across dyads
sem_ED = squeeze(std(ED,0,2)) / sqrt(size(ED,2)); % SEM

% Use the original frequency vector (no interpolation)
x_lin  = frex2plot(:);
x_log2 = log2(x_lin);

figure
for condi = 1:nconds
    subplot(2,2,condi); hold on

    % Data for this condition
    y  = squeeze(avg_ED(condi,:)).';
    se = squeeze(sem_ED(condi,:)).';

    % --- shaded SEM band ---
    xx = [x_log2;           flipud(x_log2)];
    yy = [y - se;           flipud(y + se)];
    fh = fill(xx, yy, colors(1,:), 'FaceAlpha', 0.22, 'EdgeColor', 'none');

    % --- mean curve on top ---
    plot(x_log2, y, 'Color', colors(1,:), 'LineWidth', 2.5);

    % Octave ticks within range (same tick style as before)
    octave_set  = [0.125 0.25 0.5 1 2 4 8];
    in_range    = octave_set >= min(x_lin) & octave_set <= max(x_lin);
    octave_vals = octave_set(in_range);
    if numel(octave_vals) >= 2
        xticks(log2(octave_vals));          % positions in log2
        xticklabels(string(octave_vals));    % labels in linear freq
    end
    xtickangle(45)

    xlim([min(x_log2) max(x_log2)])
    ylim([1 9])

    xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')
    ylabel('Effective Dimensionality', 'FontSize', 14, 'FontWeight', 'bold')
    title(condlabels{condi})

    grid on; grid minor; box on
    set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
    set(gcf, 'Color', 'w');
end

sgtitle(['Effective dimensionality of the network landscape across beat-normalized frequencies - ' which_method])



%% GRAND-GRANDAVERAGE LANDSCAPE AND ED ACROSS CONDITIONS

%%%% GRAND-GRANDAVERAGE LANDSCAPE %%%%

% Recompute dyad-level eigenspectra before condition averaging
gg_evals = squeeze(mean(all_evals, 3, 'omitnan'));                         % average over trials
gg_evals = squeeze(mean(gg_evals, length(size(gg_evals))));     % average over subjects/partners
gg_evals = squeeze(mean(gg_evals, 2));                          % average over conditions
% gg_evals: [dyads x comps x frex]

avg_evals_gg = squeeze(mean(gg_evals, 1));                      % average over dyads
sem_evals_gg = squeeze(std(gg_evals, 0, 1)) / sqrt(size(gg_evals,1)); % SEM across dyads

% Delegate the Figure 2 landscape to the toolbox visualizer. The externally
% computed SEM retains the inferential unit used here (dyads).
GED_figure = [];
GED_figure.evals = avg_evals_gg;
GED_figure.frex = frex2plot;

Landscape_figure = [];
Landscape_figure.frex = frex2plot;
Landscape_figure.ncomps = ncomps2keep;
Landscape_figure.sem = sem_evals_gg;
Landscape_figure.xlabel = 'Frequency (× Beat)';
Landscape_figure.title = ['Grand-grandaverage bodily network landscape across conditions - ' which_method];

FREQNESS_Visualizer_Mocap(GED_figure,Landscape_figure,[]);


%%%% GRAND-GRANDAVERAGE ED %%%%

% ED at this point is already: [conditions x dyads x frequencies]
gg_ED = squeeze(mean(ED, 1));                                    % average over conditions
% gg_ED: [dyads x frex]

avg_ED_gg = squeeze(mean(gg_ED, 1));                             % average over dyads
sem_ED_gg = squeeze(std(gg_ED, 0, 1)) / sqrt(size(gg_ED,1));      % SEM across dyads

figure
hold on

y  = avg_ED_gg(:);
se = sem_ED_gg(:);

xx = [x_log2; flipud(x_log2)];
yy = [y - se; flipud(y + se)];

fill(xx, yy, colors(1,:), ...
    'FaceAlpha', 0.22, ...
    'EdgeColor', 'none');

plot(x_log2, y, ...
    'Color', colors(1,:), ...
    'LineWidth', 2.5);

octave_set  = [0.125 0.25 0.5 1 2 4 8];
in_range    = octave_set >= min(x_lin) & octave_set <= max(x_lin);
octave_vals = octave_set(in_range);
if numel(octave_vals) >= 2
    xticks(log2(octave_vals));
    xticklabels(string(octave_vals));
end
xtickangle(45)

xlim([min(x_log2) max(x_log2)])
ylim([1 9])

xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')
ylabel('Effective Dimensionality', 'FontSize', 14, 'FontWeight', 'bold')
title('Grand-grandaverage')

grid on; grid minor; box on
set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
set(gcf, 'Color', 'w');

sgtitle(['Grand-grandaverage effective dimensionality across conditions - ' which_method])




%% VISUALIZATION: Group-level Activation Patterns (Static Scatterplot)

% Setup
nscale     = 1000;
col_static = .95 * jet(nscale);
linewidth  = 1.7;
ndims      = 3;
min_marksize = 30;
max_marksize = 100;

% Component index and frequency index to visualize
idx_frex = find(ismember(frex2plot, [0.25 0.5 1 2]));

% Indexing for axes
x_idx = 1:3:nmarks-2;
y_idx = 2:3:nmarks-1;
z_idx = 3:3:nmarks;


% Loop over components and frequencies
for frexi = 1:length(idx_frex)

    for condi = 1:nconds

   % Global normalization values, within condition and frex, across components
   global_max_pat = max(avg_pats(condi,:,1:ncomps2keep,idx_frex(frexi),:), [], 'all');
   global_max_sem = max(sem_pats(condi,:,1:ncomps2keep,idx_frex(frexi),:), [], 'all');

    figure('Color','w'), clf

    for compi = 1:ncomps2keep

        % One row per component, 3 columns = XYZ
        for dimi = 1:ndims
            subplotidx = (compi - 1)*ndims + dimi;
            subplot(ncomps2keep, ndims, subplotidx), hold on

            for subi = 1:nsubs

                % Extract and normalize activation pattern using global max
                this_pat = squeeze(avg_pats(condi,:,compi,idx_frex(frexi),subi));
                this_pat = this_pat / global_max_pat;

                % Extract SEM and normalize/invert using global max
                this_sem = squeeze(sem_pats(condi,:,compi,idx_frex(frexi),subi));
                this_sem = this_sem / global_max_sem;
                this_sem = 1 - this_sem;
                this_sem = min_marksize + this_sem * (max_marksize - min_marksize);

                % Position data
                x_pos = markData(x_idx,1,subi);
                y_pos = markData(y_idx,1,subi);
                z_pos = markData(z_idx,1,subi);

                % Color indices
                x_pats = this_pat(x_idx);
                y_pats = this_pat(y_idx);
                z_pats = this_pat(z_idx);
                cidx_x = min(max(round((x_pats + 1) * (nscale - 1) / 2) + 1, 1), nscale);
                cidx_y = min(max(round((y_pats + 1) * (nscale - 1) / 2) + 1, 1), nscale);
                cidx_z = min(max(round((z_pats + 1) * (nscale - 1) / 2) + 1, 1), nscale);

                % Marker sizes (per point)
                msize = this_sem(x_idx);

                % Choose colors and plot
                switch dimi
                    case 1
                        scatter3(x_pos, y_pos, z_pos, msize, col_static(cidx_x,:), 'filled');
                        title('X-axis activation')
                    case 2
                        scatter3(x_pos, y_pos, z_pos, msize, col_static(cidx_y,:), 'filled');
                        title('Y-axis activation')
                    case 3
                        scatter3(x_pos, y_pos, z_pos, msize, col_static(cidx_z,:), 'filled');
                        title('Z-axis activation')
                end

                % Plot bones
                for k = 1:size(bones,1)
                    p1 = bones(k,1); p2 = bones(k,2);
                    plot3([x_pos(p1) x_pos(p2)], ...
                          [y_pos(p1) y_pos(p2)], ...
                          [z_pos(p1) z_pos(p2)], 'k-', 'LineWidth', linewidth);
                end
            end

            % Format subplot
            axis vis3d
            daspect([1 1 1])
            xlabel('X'), ylabel('Y'), zlabel('Z')
            colorbar
            view(60,30)
        end
    end

    sgtitle(['Group-level Activation Patterns  - ' which_method ' | Freq = ' num2str(frex2plot(idx_frex(frexi)), '%.2f') ' × Beat. ' condlabels{condi}])

    end
end


% Compute correlation between 1st and 2nd component
pat1 = squeeze( all_pats(:,:,:,:,1,:,:) ); % component #1
pat2 = squeeze( all_pats(:,:,:,:,2,:,:) ); % component #2
corrs2avg = nan(length(list_dyads),nconds,ntrials,nfrex,nsubs);

% Correlate all markers in the innermost loop
for dyadi = 1:length(list_dyads)
    for condi = 1:nconds
        for triali = 1:CFG.common.trial_counts(list_dyads(dyadi),condi)
            for frexi = 1:nfrex
                for subi = 1:nsubs
                    corrs2avg(dyadi,condi,triali,frexi,subi) = corr( squeeze(pat1(dyadi,condi,triali,:,frexi,subi)), squeeze(pat2(dyadi,condi,triali,:,frexi,subi)) );
                end
            end
        end
    end
end

% Put frequency first (due to reshape() behavior): [nfrex × ndyads × nconds × ntrials × nsubs]
tmp = permute(corrs2avg, [4 1 2 3 5]);
% Flatten all non-frequency dims, then average across them
corrs2plot = reshape(tmp, nfrex, []);
corrs2plot = mean(corrs2plot, 2, 'omitnan');

% Visualize
figure
plot(frex2plot,corrs2plot,'Color',colors(1,:),'LineWidth',2.5)
hold on
yline(0,'k','LineWidth',linewidth)
% Cosmetics
ylim([-1 1])
xtickangle(45)
xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')
ylabel('Correlation coefficient', 'FontSize', 14, 'FontWeight', 'bold')
grid on
grid minor
box on
set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
set(gcf, 'Color', 'w');
sgtitle('Spatial correlation between component#1 and component#2')


%% VISUALIZATION: Grand-grandaverage Activation Patterns Across Conditions

% Select spatial-pattern component to visualize without changing the
% coordination component identifier used by the statistical export.
which_pattern_comp = 1;

% Average activation patterns across trials
gg_pats = squeeze(mean(all_pats, 3, 'omitnan'));
% gg_pats: [dyads x conds x markers x comps x frex x subs]

% Average activation patterns across conditions
gg_pats = squeeze(mean(gg_pats, 2));
% gg_pats: [dyads x markers x comps x frex x subs]

% Average activation patterns across dyads
avg_pats_gg = squeeze(mean(gg_pats, 1));
% avg_pats_gg: [markers x comps x frex x subs]

% Delegate Figure 2 spatial patterns to the toolbox visualizer.
GED_figure.pats = avg_pats_gg;

Patterns_figure = [];
Patterns_figure.frex = frex2plot(idx_frex);
Patterns_figure.labels = marklabels;
Patterns_figure.markerData = markData;
Patterns_figure.comp = which_pattern_comp;
Patterns_figure.srate = srate;
Patterns_figure.start = 0.25;
Patterns_figure.bones = bones;
Patterns_figure.plot_matrix = false;
Patterns_figure.animate = false;
Patterns_figure.frequency_unit = '× Beat';

FREQNESS_Visualizer_Mocap(GED_figure,[],Patterns_figure);



% GROUP-LEVEL COORDINATION VISUALIZATION

coordination_fields = {'MIRROR'};
coordination_labels = {'Spatial correlation'};
if CFG.block3.reuse_legacy_jrqa
    coordination_fields = [coordination_fields {'RR','DET'}];
    coordination_labels = [coordination_labels {'Recurrence rate','Determinism'}];
end
for componenti = 1:numel(coordination_results)
    which_comp = coordination_results{componenti}.which_comp;
    for metrici = 1:numel(coordination_fields)
        metric_data = coordination_results{componenti}.( ...
            coordination_fields{metrici});
        avg_metric = squeeze(mean(metric_data(list_dyads,:,:,:),4,'omitnan'));
        figure;
        for metri = 1:nmeters
            subplot(ceil(nmeters/3),3,metri);
            meter_data = squeeze(avg_metric(:,:,metri));
            mu = mean(meter_data,1);
            sem = std(meter_data,0,1)/sqrt(size(meter_data,1));
            bar(mu);
            hold on;
            errorbar(1:nconds,mu,sem,'.k');
            if ~strcmp(coordination_fields{metrici},'MIRROR')
                ylim([0 1])
            end
            title(['Meter ' num2str(metri)]);
            xlabel('Condition');
            ylabel('Mean ± SEM');
            xticks(1:nconds);
            xtickangle(45)
            xticklabels(condlabels)
            sgtitle([coordination_labels{metrici} ...
                ' - Component #' num2str(which_comp)])
        end
    end
end

% GROUP-LEVEL PHASE-SPACE RQA VISUALIZATION

phase_metric_fields = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
phase_metric_labels = {'Recurrence rate','Average diagonal length', ...
    'Determinism','Diagonal-line entropy','Trapping time', ...
    'Laminarity','Maximum vertical length','Divergence'};

for componenti = 1:numel(phase_results)
    for metrici = 1:numel(phase_metric_fields)
        % Validated RR/DET imports do not contain the six auxiliary metrics.
        if ~isfield(phase_results{componenti}.PhaseRQA.output,phase_metric_fields{metrici})
            continue
        end
        phase_metric = phase_results{componenti}.PhaseRQA.output.( ...
            phase_metric_fields{metrici});
        avg_phase_metric = squeeze(mean(phase_metric(list_dyads,:,:,:),4,'omitnan'));
        figure;
        for metri = 1:nmeters
            subplot(ceil(nmeters/3),3,metri);
            meter_data = squeeze(avg_phase_metric(:,:,metri));
            mu = mean(meter_data,1);
            sem = std(meter_data,0,1)/sqrt(size(meter_data,1));
            bar(mu);
            hold on;
            errorbar(1:nconds,mu,sem,'.k');
            title(['Meter ' num2str(metri)]);
            xlabel('Condition');
            ylabel('Mean ± SEM');
            xticks(1:nconds);
            xtickangle(45)
            xticklabels(condlabels)
            sgtitle(['Phase-space RQA: ' phase_metric_labels{metrici} ...
                ' - Component #' num2str(phase_components(componenti))])
        end
    end
end


% Export every group-level image only after all numerical analysis blocks
% have completed. Existing figures remain untouched unless requested.
figure_handles = findall(groot,'Type','figure');
for figurei = 1:numel(figure_handles)
    figure_name = fullfile(CFG.block7.figure_path,sprintf( ...
        'GROUP_%02d',figurei));
    if ~isfile([figure_name '.fig']) || CFG.block7.overwrite_flag
        savefig(figure_handles(figurei),[figure_name '.fig'])
    end
    if ~isfile([figure_name '.png']) || CFG.block7.overwrite_flag
        exportgraphics(figure_handles(figurei),[figure_name '.png'], ...
            'Resolution',200)
    end
end
close all



%% BLOCK 8 - R-READY STATISTICAL EXPORT

% This block is independent of the group-visualization workspace. It loads
% each component summary and exports the manuscript phase-space workbooks.
% Spatial export is independent of JRQA and phase-space RQA.
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

%% Optional historical JRQA export
visual_labels = ["No", "No", "Yes", "Yes"];
music_labels = ["Diff", "Same", "Diff", "Same"];
if CFG.block8.export_jrqa
components = CFG.block3.components;
for componenti = 1:numel(components)

    which_comp = components(componenti);
    component_output_path = fullfile( ...
        CFG.block3.output_path,['Component_' num2str(which_comp)]);
    coordination_summary_file = fullfile(component_output_path, ...
        ['FREQNESS_COORDINATION_SUMMARY_Comp#' ...
        num2str(which_comp) '.mat']);
    assert(isfile(coordination_summary_file), ...
        ['Missing saved historical Component %d coordination summary. ' ...
        'Historical JRQA recomputation has been removed.'],which_comp);

    S = load(coordination_summary_file, ...
        'MIRROR','RR','DET','meter','list_dyads', ...
        'nconds','ntrials','nmeters','CFG');
    assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Historical JRQA summary does not cover the configured dyads/trials.');

    % Average the available trial-level dyadic measures before statistical
    % modelling, retaining one observation per dyad/condition/metric level.
    avg_MIRROR = squeeze(mean(S.MIRROR(S.list_dyads,:,:,:),4,'omitnan'));
    avg_RR = squeeze(mean(S.RR(S.list_dyads,:,:,:),4,'omitnan'));
    avg_DET = squeeze(mean(S.DET(S.list_dyads,:,:,:),4,'omitnan'));

    nRows = numel(S.list_dyads)*S.nconds*S.nmeters;
    dyad_col = zeros(nRows,1);
    visual_col = strings(nRows,1);
    music_col = strings(nRows,1);
    meter_col = strings(nRows,1);
    mirror_col = zeros(nRows,1);
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
                mirror_col(row) = avg_MIRROR(dyad_idx,condi,metri);
                rr_col(row) = avg_RR(dyad_idx,condi,metri);
                det_col(row) = avg_DET(dyad_idx,condi,metri);
                row = row + 1;
            end
        end
    end

    T = table(dyad_col,visual_col,music_col,meter_col, ...
        mirror_col,rr_col,det_col, ...
        'VariableNames',{'Dyad','Visual','Music','Meter', ...
        'Mirror','RR','DET'});

    statistics_file = fullfile(CFG.block8.output_path, ...
        ['OUT2R_Comp#' num2str(which_comp) '.xlsx']);
    if ~isfile(statistics_file) || CFG.block8.overwrite_flag
        writetable(T,statistics_file)
    end
    fprintf('Saved Component %d statistics: %s\n', ...
        which_comp,statistics_file);

end
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
    % modelling, exactly matching the established JRQA export.
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
