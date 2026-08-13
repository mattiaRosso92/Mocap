clear
close all
clc


%% BLOCK 0 - USER SETTINGS, STARTUP, AND OUTPUT ROUTING

% All raw inputs and all newly generated outputs stay on the local drive in
% Dance_Data. The dedicated results root prevents this replication from
% modifying any legacy analyses currently stored directly in Dance_Data.
path_script = fileparts(mfilename('fullpath'));
path_repo = fileparts(path_script);

CFG = [];
CFG.common.data_path = fullfile(path_repo,'Dance_Data');
CFG.common.results_folder = ...
    'FREQNESS_Results_Rosso_et_al_inPreparation';
CFG.common.results_path = fullfile( ...
    CFG.common.data_path,CFG.common.results_folder);
CFG.common.ncomps = 4;

CFG.block1.output_path = fullfile( ...
    CFG.common.results_path,'01_Core');
CFG.block1.overwrite_flag = false;
CFG.block2.output_path = fullfile( ...
    CFG.common.results_path,'02_Landscape');
CFG.block2.overwrite_flag = false;
CFG.block3.output_path = fullfile( ...
    CFG.common.results_path,'03_Coordination');
CFG.block3.overwrite_flag = false;
CFG.block4.output_path = fullfile( ...
    CFG.common.results_path,'04_PhaseSpaceRQA');
CFG.block4.overwrite_flag = false;
CFG.block5.output_path = fullfile( ...
    CFG.common.results_path,'05_Group');
CFG.block5.figure_path = fullfile(CFG.block5.output_path,'Figures');
CFG.block5.overwrite_flag = false;
CFG.block6.output_path = fullfile( ...
    CFG.common.results_path,'06_Statistics_R');
CFG.block6.overwrite_flag = false;

% Core analysis settings. Visualizing every single trial would open more
% than one thousand figures, so trial visualization is optional in BLOCK 1
% and group visualization is consolidated in BLOCK 5.
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

required_metadata = {'cond_vis.csv','cond_mus.csv', ...
    'song_subj_LEFT.csv','song_subj_RIGHT.csv'};
for filei = 1:numel(required_metadata)
    assert(isfile(fullfile(path_home,required_metadata{filei})), ...
        'Missing Dance input file: %s',required_metadata{filei});
end

output_paths = {CFG.block1.output_path,CFG.block2.output_path, ...
    CFG.block3.output_path,CFG.block4.output_path, ...
    CFG.block5.output_path,CFG.block5.figure_path, ...
    CFG.block6.output_path};
for pathi = 1:numel(output_paths)
    if ~isfolder(output_paths{pathi})
        mkdir(output_paths{pathi})
    end
end

% Save the exact run configuration in the new results root. Do not replace
% a previous configuration unless overwrite_flag is explicitly enabled.
configuration_file = fullfile( ...
    CFG.common.results_path,'FREQNESS_Dance_RunConfiguration.mat');
if ~isfile(configuration_file) || CFG.block1.overwrite_flag
    save(configuration_file,'CFG')
end

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
list_dyads = [1:12 14:31 33:ndyads]; % Issue with dyad #13: one trial is missing in condi #1 | dyad#32 returns an error with RPparam in condi #4
sublabels= {'_LEFT', '_RIGHT'};
nsubs = length(sublabels);
% Design matrix (label_visual, labels_music)
desMat = [ 0 0 ;  % 'No Visual'  , 'Different Music'ta
    0 1 ;  % 'No Visual'  , 'Same Music'
    1 0 ;  % 'Yes Visual' , 'Different Music'
    1 1 ]; % 'Yes Visual' , 'Same Music'
nconds  = size(desMat,1);
condlabels = {'NOvis-DIFFmus', 'NOvis-SAMEmus', 'YESvis-DIFFmus', 'YESvis-SAMEmus'};
ntrials = 8; % hard-coded for this experiment


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
        list_trials = find(lbl_vis(id_dyad,:) == desMat(condi,1) & (lbl_mus(id_dyad,:) == desMat(condi,2))); % retain uncoupled conditions
        if length(list_trials) ~= ntrials
            error('Mismatch between expected and actual trials!')
        end

        % Analyse trial by trial
        for triali = 1:ntrials
            id_trial = list_trials(triali);
            id_trial_str = sprintf('%02d', id_trial); % to add the '0' before numbers < 10

            output_file = fullfile(CFG.block1.output_path,sprintf( ...
                'FREQNESS_CORE_D%d_C%d_T%d%s.mat', ...
                dyadi,condi,triali,prefix{idx_XYZ}));
            if isfile(output_file) && ~CFG.block1.overwrite_flag
                fprintf('BLOCK 1 output exists; skipping %s.\n',output_file);
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
                GED = []; % refresh for loop iterations
                GED = FREQNESS_NetworkEstimation_Mocap(markData, frex, srate, ...
                    'ncomps',CFG.common.ncomps); % networks estimation
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
                        'triali','id_trial','srate','marker_reference','-v7.3')
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

        for triali = 1:ntrials

            % Load into a struct so variable name (GED or PCA) becomes a field
            input_file = fullfile(CFG.block1.output_path,sprintf( ...
                'FREQNESS_CORE_D%d_C%d_T%d%s.mat', ...
                dyadi,condi,triali,prefix{idx_XYZ}));
            assert(isfile(input_file),'Missing BLOCK 1 output: %s',input_file);
            S = load(input_file,which_method,'marker_reference');

            % Alias to the chosen method struct (either S.GED or S.PCA)
            M = S.(which_method);

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
            [this_H2,this_ED] = FREQNESS_EffectDim_Mocap(M,'figure',false);
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
            'ED','list_dyads','marker_reference','-v7.3')
    end
end



%% BLOCK 3 - JRQA TEMPORAL COORDINATION AND SPATIAL COORDINATION

clearvars -except CFG

% Pick component
which_comp = 2;

% Choose wheteher you want to attune JRQA
attune_flag = 0;

% Restore repository-relative paths after clearing the large group arrays.
path_home = CFG.common.data_path;
path_repo = fileparts(fileparts(mfilename('fullpath')));
path_toolbox = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');
addpath(path_toolbox)
FREQNESS_Startup_Mocap();

% Re-initialize settings to import GED outputs from the folder
ndyads = 35;
nconds  = 4;
ntrials = 8;
nsubs   = 2;
list_dyads = [1:12 14:31 33:ndyads]; % Issue with dyad #13: one trial is missing in condi #1 | dyad#32 gives arror with RPparam in condi #4
srate = 250;

% This full-experiment script always consumes the new BLOCK 1 outputs.
validation_flag = false;
assert(isfolder(CFG.block1.output_path), ...
    'BLOCK 1 output folder is missing: %s',CFG.block1.output_path);
condlabels = {'NOvis-DIFFmus','NOvis-SAMEmus', ...
    'YESvis-DIFFmus','YESvis-SAMEmus'};

% Define metric levels of interest
meter = [.25 .5 1 2];
nmeters = length(meter);
idx_frex = zeros(nsubs,nmeters);

% Downsampling with correction for aliasing
dwn = 10;
srate = round(srate/dwn); % update sampling rate
% Low-pass Butterworth filter to avoid aliasing by downsampling
nyquist = round(srate/2);
lp_order = 4;        % Filter order
lp_cutoff_norm = .8; % Normalized cutoff frequency (.8 of the nyquist, when normalized to 1)
[b_butt, a_butt] = butter(lp_order, lp_cutoff_norm, 'low'); % Coefficients for high-pass filter
%     % Visualize the filter's freqency response
%     figure; freqz(b_butt, a_butt, 100, srate); % Frequency response

% Define duration
duration = [.15 .85];

% Optimize JRQA parameters (if requested)
if attune_flag ==1

    % Initialize JRQA parameters
    [tau,m,ps] = deal(zeros(nsubs,ndyads,nconds,nmeters,ntrials));

    % Loop over conditions
    for condi = 1:nconds

        % Select dyad and subject
        for dyadi = list_dyads
            disp(['Condition#' num2str(condi) ' - Dyad #' num2str(dyadi)])

            % Analyse trial by trial
            for triali = 1:ntrials

                % Import GED output
                input_file = fullfile(CFG.block1.output_path,sprintf( ...
                    'FREQNESS_CORE_D%d_C%d_T%d.mat', ...
                    dyadi,condi,triali));
                assert(isfile(input_file),'Missing BLOCK 1 output: %s',input_file);
                S = load(input_file,'GED','beat_frex');
                GED = S.GED;
                beat_frex = S.beat_frex;

                for subi = 1:nsubs

                    % Loop over metric levels (hamronics of the target frequency);
                    for metri = 1:nmeters

                        % Find frequency in vector
                        [~,idx_frex(subi,metri)] = min(abs(beat_frex(subi)*meter(metri) - GED.frex(:,subi)));

                        % Assign timeseries
                        gedTs = GED.ts(which_comp,:,idx_frex(subi,metri),subi); % assign component corresponding to the frequency of interest

                        % Apply Butterworth filter for aliasing correction
                        gedTs = filtfilt(b_butt, a_butt, gedTs); % Zero-phase filtering

                        % Downsample
                        gedTs = gedTs(1:dwn:end);

                        % Retain window of interest
                        gedTs = gedTs( round(duration(1)*srate) : round(duration(end)*srate) );

                        % Optimize embedding parameters
                        %disp(['Optimizing embedding parameters for participant #' num2str(subi)])
                        [tau(subi,dyadi,condi,metri,triali), m(subi,dyadi,condi,metri,triali), ps(subi,dyadi,condi,metri,triali)] = RPparam(gedTs');

                    end

                end

            end

        end

    end

    % Average optimal parameters (assign to input structure)
    JRQA.tau = round(mean(tau(:)));
    JRQA.m   = round(mean(m(:)));
    JRQA.ps  = round(mean(ps(:)),1);

    % Save output
    parameter_file = fullfile(CFG.block3.output_path, ...
        ['JRQA_Parameters_Comp#' num2str(which_comp) '.mat']);
    if ~isfile(parameter_file) || CFG.block3.overwrite_flag
        save(parameter_file,'JRQA')
    end

else

    % Import JRQA parapemeters
    parameter_file = fullfile(CFG.block3.output_path, ...
        ['JRQA_Parameters_Comp#' num2str(which_comp) '.mat']);
    if isfile(parameter_file)
        load(parameter_file,'JRQA')
    else
        legacy_parameter_file = fullfile(path_home,'JRQA_Parameters.mat');
        assert(isfile(legacy_parameter_file), ...
            ['No JRQA parameters were found. Enable attune_flag or provide ' ...
            'the legacy JRQA_Parameters.mat input.']);
        load(legacy_parameter_file,'JRQA')
    end

end

% Pre-allocate group-level output
[MIRROR,RR,DET] = deal(zeros(ndyads,nconds,nmeters,ntrials));

% Run analyses
for condi = 1:nconds
    for dyadi = list_dyads
        disp(['Condition#' num2str(condi) ' - Dyad #' num2str(dyadi)])
        for triali = 1:ntrials

            coordination_file = fullfile(CFG.block3.output_path,sprintf( ...
                'FREQNESS_COORDINATION_D%d_C%d_T%d.mat', ...
                dyadi,condi,triali));
            if isfile(coordination_file) && ~CFG.block3.overwrite_flag
                S = load(coordination_file,'FREQjrqa','FREQmirror');
                for metri = 1:nmeters
                    MIRROR(dyadi,condi,metri,triali) = S.FREQmirror(metri);
                    RR(dyadi,condi,metri,triali) = S.FREQjrqa(metri).RR;
                    DET(dyadi,condi,metri,triali) = S.FREQjrqa(metri).DET;
                end
                continue
            end

            % Import GED output
            input_file = fullfile(CFG.block1.output_path,sprintf( ...
                'FREQNESS_CORE_D%d_C%d_T%d.mat', ...
                dyadi,condi,triali));
            assert(isfile(input_file),'Missing BLOCK 1 output: %s',input_file);
            S = load(input_file,'GED','beat_frex');
            GED = S.GED;
            beat_frex = S.beat_frex;

            % Extract and process time series
            gedTs = squeeze(GED.ts(which_comp,:,:,:)); % [original_time x nfrex x nsubs]
            for subi = 1:nsubs
                for frexi = 1:size(gedTs,2)
                    gedTs(:,frexi,subi) = filtfilt(b_butt, a_butt, gedTs(:,frexi,subi));  % Butterworth filter for aliasing correction
                end
            end
            gedTs = gedTs(1:dwn:end,:,:);  % Downsampling both subs
            % Overwrite back into GED.ts — shrink time dimension
            GED.ts = GED.ts(:,1:dwn:end,:,:);  % Shrink time dimension
            for subi = 1:nsubs
                for frexi = 1:size(gedTs,2)
                    GED.ts(which_comp,:,frexi,subi) = gedTs(:,frexi,subi); % re-assign
                end
            end

            % Compute temporal coordination
            FREQjrqa = FREQNESS_TimeCoord_Mocap( ...
                GED,JRQA,beat_frex, ...
                'metric_levels',meter, ...
                'component',which_comp, ...
                'duration',duration);

            % Compute spatial coordination
            FREQmirror = FREQNESS_SpaceCoord_Mocap( ...
                GED,beat_frex, ...
                'metric_levels',meter, ...
                'component',which_comp);

            % Assign to group-level variables
            for metri = 1:nmeters
                MIRROR(dyadi,condi,metri,triali) = FREQmirror(metri);
                RR(dyadi,condi,metri,triali)     = FREQjrqa(metri).RR;
                DET(dyadi,condi,metri,triali)    = FREQjrqa(metri).DET;
            end

            save(coordination_file,'FREQjrqa','FREQmirror','JRQA', ...
                'which_comp','meter','dyadi','condi','triali','-v7.3')

        end
    end
end

%% BLOCK 4 - PHASE-SPACE RQA (ALTERNATIVE TEMPORAL COORDINATION)

% This is intentionally a separate analysis block following the current
% GroupAnalyses workflow. It permits direct comparison with JRQA while
% keeping the two temporal-coordination formulations independent.

% Phase-space RQA settings
PhaseRQA = [];
% A scalar frequency/component is shared across the dyad; use one value per
% participant to analyze participant-specific frequencies or components.
PhaseRQA.target_frex      = [];
PhaseRQA.component        = which_comp;
PhaseRQA.standardize      = true;
PhaseRQA.threshold_method = 'max_fraction';
PhaseRQA.threshold        = 0.1;
PhaseRQA.theiler_window   = 0;
PhaseRQA.lmin             = 2;
PhaseRQA.vmin             = 2;
PhaseRQA.figure           = validation_flag;
PhaseRQA.animate          = false;

% Pre-allocate one group-level variable for each RQA output
[RR_phase,L_phase,DET_phase,ENTR_phase,TT_phase,LAM_phase, ...
    Vmax_phase,DIV_phase] = deal( ...
    nan(ndyads,nconds,nmeters,ntrials));

for condi = 1:nconds
    for dyadi = list_dyads
        disp(['Phase-space RQA: condition #' num2str(condi) ...
            ' - dyad #' num2str(dyadi)])
        for triali = 1:ntrials

            phase_rqa_file = fullfile(CFG.block4.output_path,sprintf( ...
                'FREQNESS_PHASERQA_D%d_C%d_T%d.mat', ...
                dyadi,condi,triali));
            if isfile(phase_rqa_file) && ~CFG.block4.overwrite_flag
                S = load(phase_rqa_file,'FREQrqa');
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

            % Import the same FREQ network output used by GroupAnalyses
            input_file = fullfile(CFG.block1.output_path,sprintf( ...
                'FREQNESS_CORE_D%d_C%d_T%d.mat', ...
                dyadi,condi,triali));
            assert(isfile(input_file),'Missing BLOCK 1 output: %s',input_file);
            S = load(input_file,'GED','beat_frex');
            GED = S.GED;
            beat_frex = S.beat_frex;

            if isempty(PhaseRQA.target_frex)
                this_target_frex = beat_frex;
            else
                this_target_frex = PhaseRQA.target_frex;
            end

            % Apply the same anti-aliasing filter and downsampling used in
            % the JRQA block so the methods receive matched time series.
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
                    this_ts = squeeze(GED.ts(phase_components(subi), ...
                        :,frexi,subi));
                    GED.ts(phase_components(subi),:,frexi,subi) = ...
                        filtfilt(b_butt,a_butt,this_ts);
                end
            end
            GED.ts = GED.ts(:,1:dwn:end,:,:);

            % Compute the joint phase-space recurrence analysis. The saved
            % study variable is named GED but follows the public FREQ API.
            make_figure = PhaseRQA.figure && condi == 1 && ...
                dyadi == list_dyads(1) && triali == 1;
            FREQrqa = FREQNESS_PhaseSpaceRQA_Mocap( ...
                GED,this_target_frex, ...
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

            % Assign every RQA output returned by its dedicated function
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
                'condi','triali','-v7.3')

        end
    end
end

% Keep the alternative analysis together as a study-level result.
PhaseRQA.output.RR   = RR_phase;
PhaseRQA.output.L    = L_phase;
PhaseRQA.output.DET  = DET_phase;
PhaseRQA.output.ENTR = ENTR_phase;
PhaseRQA.output.TT   = TT_phase;
PhaseRQA.output.LAM  = LAM_phase;
PhaseRQA.output.Vmax = Vmax_phase;
PhaseRQA.output.DIV  = DIV_phase;

%% BLOCK 5 - GROUP-LEVEL VISUALIZATION

% TODO: SEM are fixed, but still do the following for other plots:
% After fixing, if needed, do the same in FREQNESS_SI_FIlters.m (what about
% all other plots? massive fix with chatGPT

path_data = CFG.block2.output_path;

% Restore plotting metadata cleared before the coordination analyses.
prefix = {'';'_onlyX';'_onlyY';'_onlyZ'};
srate = 250;
ndyads = 35;
nconds = 4;
ntrials = 8;
nsubs = 2;
list_dyads = [1:12 14:31 33:ndyads];
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

% Import the saved dyadic coordination outputs so this block aggregates
% every completed analysis stage rather than relying on workspace state.
[MIRROR,RR,DET] = deal(nan(ndyads,nconds,nmeters,ntrials));
[RR_phase,L_phase,DET_phase,ENTR_phase,TT_phase,LAM_phase, ...
    Vmax_phase,DIV_phase] = deal( ...
    nan(ndyads,nconds,nmeters,ntrials));

for condi = 1:nconds
    for dyadi = list_dyads
        for triali = 1:ntrials
            coordination_file = fullfile(CFG.block3.output_path,sprintf( ...
                'FREQNESS_COORDINATION_D%d_C%d_T%d.mat', ...
                dyadi,condi,triali));
            assert(isfile(coordination_file), ...
                'Missing BLOCK 3 output: %s',coordination_file);
            S = load(coordination_file,'FREQjrqa','FREQmirror');

            phase_rqa_file = fullfile(CFG.block4.output_path,sprintf( ...
                'FREQNESS_PHASERQA_D%d_C%d_T%d.mat', ...
                dyadi,condi,triali));
            assert(isfile(phase_rqa_file), ...
                'Missing BLOCK 4 output: %s',phase_rqa_file);
            P = load(phase_rqa_file,'FREQrqa');

            for metri = 1:nmeters
                MIRROR(dyadi,condi,metri,triali) = S.FREQmirror(metri);
                RR(dyadi,condi,metri,triali) = S.FREQjrqa(metri).RR;
                DET(dyadi,condi,metri,triali) = S.FREQjrqa(metri).DET;
                RR_phase(dyadi,condi,metri,triali) = P.FREQrqa(metri).RR;
                L_phase(dyadi,condi,metri,triali) = P.FREQrqa(metri).L;
                DET_phase(dyadi,condi,metri,triali) = P.FREQrqa(metri).DET;
                ENTR_phase(dyadi,condi,metri,triali) = P.FREQrqa(metri).ENTR;
                TT_phase(dyadi,condi,metri,triali) = P.FREQrqa(metri).TT;
                LAM_phase(dyadi,condi,metri,triali) = P.FREQrqa(metri).LAM;
                Vmax_phase(dyadi,condi,metri,triali) = P.FREQrqa(metri).Vmax;
                DIV_phase(dyadi,condi,metri,triali) = P.FREQrqa(metri).DIV;
            end
        end
    end
end

% Select method: 'GED' or 'PCA'
which_method = 'GED';

% Choose whether you want one dimension
idx_XYZ = 1; % 1 = '', all axes included

close all

% Import group-level data
load(fullfile(path_data, ...
    ['FREQNESS_GroupNetworkSummary' prefix{idx_XYZ} '.mat']), ...
    'all_evals','all_pats','all_frex_norm','ED','list_dyads', ...
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
avg_evals = squeeze(mean(all_evals, 3));   %  [dyads,conds,trials,comps,frex,subs]
avg_pats  = squeeze(mean(all_pats, 3));    %  [dyads,conds,trials,markers,comps,frex,subs]

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
ED = squeeze(mean(ED,3));                   % across trials
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
gg_evals = squeeze(mean(all_evals, 3));                         % average over trials
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
corrs2avg = zeros(length(list_dyads),nconds,ntrials,nfrex,nsubs);

% Correlate all markers in the innermost loop
for dyadi = 1:length(list_dyads)
    for condi = 1:nconds
        for triali = 1:ntrials
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

% Select component to visualize
which_comp = 1;

% Average activation patterns across trials
gg_pats = squeeze(mean(all_pats, 3));
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
Patterns_figure.comp = which_comp;
Patterns_figure.srate = srate;
Patterns_figure.start = 0.25;
Patterns_figure.bones = bones;
Patterns_figure.plot_matrix = false;
Patterns_figure.animate = false;
Patterns_figure.frequency_unit = '× Beat';

FREQNESS_Visualizer_Mocap(GED_figure,[],Patterns_figure);



% GROUP-LEVEL COORDINATION VISUALIZATION

% Average over trials dimension
avg_MIRROR = squeeze( mean(MIRROR([1:12 14:31 33:ndyads],:,:,:), 4) ); 
avg_RR  = squeeze( mean(RR([1:12 14:31 33:ndyads],:,:,:), 4) );
avg_DET = squeeze( mean(DET([1:12 14:31 33:ndyads],:,:,:), 4) ); 

% Update ndyads with factually analyzed dyads
ndyads = size(avg_MIRROR,1);

figure;
for metri = 1:nmeters
    subplot(ceil(nmeters/3), 3, metri);
    
    % Extract [nrep x nconds] data for this meter
    meter_data = squeeze(avg_MIRROR(:,:,metri));  % 
    
    % Compute mean and SEM across dyads 
    mu  = mean(meter_data, 1);                    
    sem = std(meter_data, 0, 1) / sqrt(ndyads);     

    % Plot with error bars
    bar(mu);
    hold on;
    errorbar(1:nconds, mu, sem, '.k');
    ylim([0 3*mean(avg_MIRROR(:))])
    title(['Meter ' num2str(metri)]);
    xlabel('Condition');
    ylabel('Mean ± SEM');
    xticks(1:nconds);
    xtickangle(45)
    xticklabels(condlabels)
    sgtitle('Spatial correlation')
end

figure;
for metri = 1:nmeters
    subplot(ceil(nmeters/3), 3, metri);
    
    % Extract [nrep x nconds] data for this meter
    meter_data = squeeze(avg_RR(:,:,metri));  % 
    
    % Compute mean and SEM across dyads 
    mu  = mean(meter_data, 1);                    
    sem = std(meter_data, 0, 1) / sqrt(ndyads);     

    % Plot with error bars
    bar(mu);
    hold on;
    errorbar(1:nconds, mu, sem, '.k');
    ylim([0 1])
    title(['Meter ' num2str(metri)]);
    xlabel('Condition');
    ylabel('Mean ± SEM');
    xticks(1:nconds);
    xtickangle(45)
    xticklabels(condlabels)
    sgtitle('Recurrence rate')
end

figure;
for metri = 1:nmeters
    subplot(ceil(nmeters/3), 3, metri);
    
    % Extract [nrep x nconds] data for this meter
    meter_data = squeeze(avg_DET(:,:,metri));  % 
    
    % Compute mean and SEM across dyads 
    mu  = mean(meter_data, 1);                    
    sem = std(meter_data, 0, 1) / sqrt(ndyads);     

    % Plot with error bars
    bar(mu);
    hold on;
    errorbar(1:nconds, mu, sem, '.k');
    ylim([0 1])
    title(['Meter ' num2str(metri)]);
    xlabel('Condition');
    ylabel('Mean ± SEM');
    xticks(1:nconds);
    xtickangle(45)
    xticklabels(condlabels)
    sgtitle('Determinism')
end

% GROUP-LEVEL PHASE-SPACE RQA VISUALIZATION

phase_metric_data = {RR_phase,L_phase,DET_phase,ENTR_phase, ...
    TT_phase,LAM_phase,Vmax_phase,DIV_phase};
phase_metric_labels = {'Recurrence rate','Average diagonal length', ...
    'Determinism','Diagonal-line entropy','Trapping time', ...
    'Laminarity','Maximum vertical length','Divergence'};

for metrici = 1:numel(phase_metric_data)
    avg_phase_metric = squeeze(mean( ...
        phase_metric_data{metrici}([1:12 14:31 33:35],:,:,:),4));
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
        sgtitle(['Phase-space RQA: ' phase_metric_labels{metrici}])
    end
end


% Export every group-level image only after all numerical analysis blocks
% have completed. Existing figures remain untouched unless requested.
figure_handles = findall(groot,'Type','figure');
for figurei = 1:numel(figure_handles)
    figure_name = fullfile(CFG.block5.figure_path,sprintf( ...
        'GROUP_%02d',figurei));
    if ~isfile([figure_name '.fig']) || CFG.block5.overwrite_flag
        savefig(figure_handles(figurei),[figure_name '.fig'])
    end
    if ~isfile([figure_name '.png']) || CFG.block5.overwrite_flag
        exportgraphics(figure_handles(figurei),[figure_name '.png'], ...
            'Resolution',200)
    end
end
close all



%% BLOCK 6 - R-READY STATISTICAL EXPORT

% Preallocate
nRows = ndyads * nconds * nmeters;
subject_col = zeros(nRows,1);
visual_col = strings(nRows,1);
music_col = strings(nRows,1);
meter_col = strings(nRows,1);
mirror_col = zeros(nRows,1);
rr_col = zeros(nRows,1);
det_col = zeros(nRows,1);

% Labels
meter_labels = "M" + string(1:nmeters);  % "M1", "M2", ..., "Mn"
visual_labels = ["No", "No", "Yes", "Yes"];
music_labels = ["Diff", "Same", "Diff", "Same"];

% Fill rows
row = 1;
for dyadi = 1:ndyads
    for condi = 1:nconds
        for metri = 1:nmeters
            subject_col(row) = list_dyads(dyadi);
            visual_col(row) = visual_labels(condi);
            music_col(row) = music_labels(condi);
            meter_col(row) = meter_labels(metri);
            mirror_col(row) = avg_MIRROR(dyadi, condi, metri);
            rr_col(row) = avg_RR(dyadi, condi, metri);
            det_col(row) = avg_DET(dyadi, condi, metri);
            row = row + 1;
        end
    end
end

% Create table
T = table(subject_col, visual_col, music_col, meter_col, ...
          mirror_col, rr_col, det_col, ...
          'VariableNames', {'Subject', 'Visual', 'Music', 'Meter', ...
                            'Mirror', 'RR', 'DET'});

% Export to Excel
statistics_file = fullfile(CFG.block6.output_path, ...
    ['OUT2R_Comp#' num2str(which_comp) '.xlsx']);
if ~isfile(statistics_file) || CFG.block6.overwrite_flag
    writetable(T,statistics_file)
end
