clear all
close all


%% Startup

% Choose if you want to enable visualizations
vis_flag = 1;

% Choose if you want to enable saving of FREQNESS output
save_flag = 0;

% Define home path
path_home = '/Users/au658766/Documents/MIB/Projects/NESS_withLBPD/2025_FreqNESS_Mocap/';

% NOTE: this will be replaced by a Startup function
addpath(path_home)

% Filter data by experimental conditions
% 	- 'cond_vis': each cell informs about the condition of a trial (0='No Visual Contact', 1='Visual Contact')
% 	- 'cond_mus': each cell informs about the condition of a trial (0='Different Music', 1='Same Music')
lbl_vis = csvread([path_home 'cond_vis.csv'], 1, 1);
lbl_mus = csvread([path_home 'cond_mus.csv'], 1, 1);


%% Prepare data

% Define sampling rate
srate = 250;

% % Define downsampling
% dwn = 1;
% srate = round(srate/dwn); % downsample

% Design settings
ndyads = 35;
list_dyads = [1:12 14:31 33:ndyads]; % Issue with dyad #13: one trial is missing in condi #1 | dyad#32 gives arror with RPparam in condi #4
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

% Expand with X, Y, Z prefixes
xyz_marklabels = cell(1, length(marklabels) * 3);

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



%% Run FREQNESS

% Loop over conditions
for condi = 4 %1:nconds

    % Select dyad and subject
    for dyadi = 1%list_dyads
        disp(['Condition#' num2str(condi) ' - Dyad #' num2str(dyadi)])
        id_dyad = dyadi;
        id_dyad_str = sprintf('%02d', id_dyad); % to add the '0' before numbers < 10

        % Filter trials by condition
        list_trials = find(lbl_vis(id_dyad,:) == desMat(condi,1) & (lbl_mus(id_dyad,:) == desMat(condi,2))); % retain uncoupled conditions
        if length(list_trials) ~= ntrials
            error('Mismatch between expected and actual trials!')
        end

        % Analyse trial by trial
        for triali = ntrials %1:ntrials
            id_trial = list_trials(triali);
            id_trial_str = sprintf('%02d', id_trial); % to add the '0' before numbers < 10

            % Refresh data matrix for every iteration
            markData = [];

            % Loop over partners
            for subi = 1:nsubs
                id_sub = sublabels{subi};

                % Define path
                path_data = [path_home 'Data/Dyad_' id_dyad_str '/subj' id_sub];
                cd(path_data);

                % Import info on songs, per single participant
                song_info = csvread([path_home '/song_subj' id_sub '.csv'], 1, 1) + 1; % already add +1 to compensate Python 0-indexing
                songs_frex = 1 ./ (60 ./ song_bpms); % convert to Hz
                % Find beat frequency (find song in 'song_subj_LEFT/RIGHT.csv')
                idx_beat = song_info(id_dyad,id_trial);
                beat_frex(subi) = songs_frex( idx_beat );
                % Define vector of frequencies
                %frex = beat_frex(subi)/8:beat_frex(subi)/8:beat_frex(subi)*4; % above beat
                frex = beat_frex(subi)/8:beat_frex(subi)/8:beat_frex(subi)*4; % above beat

                % Import data (skip 1st row and column)
                tempData = csvread(['tr' id_trial_str '.csv'], 1, 1);
                %tempData = tempData(:,1:dwn:end);  % Downsample the data
                tempData = tempData(1:end-3,:);  % Remove last marker
                markData = cat(3,markData,tempData); % Assign to 3rd dimension of input data matrix
                nmarks = size(markData,1);       % Updated number of markers
                npnts = size(markData,2);


            end


            %% Run network decomposition on the dyad

            GED = []; % refresh for loop iterations
            GED = FREQNESS_NetworkEstimation_Mocap(markData, frex, srate);

            % Save output
            if save_flag == 1
                mkdir([path_home 'GED_output']);
                save([path_home 'GED_output/GED_dyad_' num2str(dyadi) '_cond_' num2str(condi) '_trial_' num2str(triali)]);
            end



            %% FREQNESS VISUALIZATION

            % Enable visualization
            if vis_flag == 1

                %%% ------------------- USER SETTINGS ------------------- %%%

                % Settings (visualization of network landscape)
                Landscape = [];
                Landscape.frex   = frex;
                Landscape.ncomps = 20;

                % Settings (visualization of network activation patterns)
                Patterns = [];
                Patterns.frex   = beat_frex(1);    % MAX beat*2
                Patterns.labels = marklabels;   % insert marker labels, in format X1,Y1,Z1,X2,Y2,Z2,[...]
                Patterns.markerData = markData; % used to compute the backprojection
                Patterns.comp   = 1;            % choose the component to inspect
                Patterns.srate  = srate;        % necessary for the animation
                Patterns.start  = .25;           % starting point of the animation (0-1)


                %%% ------------------ COMPUTATION --------------------- %%%

                % Plot bodily network landscape, spatial activation in XYZ
                FREQNESS_Visualizer_Mocap(GED,Landscape,Patterns)


            end



        end

    end

end




%% FREQNESS DYADIC ANALYSES

clear all

% Choose wheteher you want to attune JRQA
attune_flag = 0;

% Define home path
path_home = '/Users/au658766/Documents/MIB/Projects/NESS_withLBPD/2025_FreqNESS_Mocap/';

% Re-initialize settings to import GED outputs from the folder
ndyads = 35;
nconds  = 4;
ntrials = 8;
nsubs   = 2;
list_dyads = [1:12 14:31 33:ndyads]; % Issue with dyad #13: one trial is missing in condi #1 | dyad#32 gives arror with RPparam in condi #4
srate = 250;

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

% Pick component
which_comp = 1;

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
                load([path_home 'GED_output/GED_dyad_' num2str(dyadi) '_cond_' num2str(condi) '_trial_' num2str(triali)]);

                for subi = 1:nsubs

                    % Loop over metric levels (hamronics of the target frequency);
                    for metri = 1:nmeters

                        % Find frequency in vector
                        [~,idx_frex(subi,metri)] = min(abs(beat_frex(subi)*meter(metri) - GED.frex));

                        % Assign timeseries
                        gedTs = GED.ts(which_comp,:,idx_frex(subi,metri),subi); % assign component corresponding to the frequency of interest

                        % Apply Butterworth filter for aliasing correction
                        gedTs = filtfilt(b_butt, a_butt, gedTs); % Zero-phase filtering

                        % Downsample
                        gedTs = gedTs(1:dwn:end);

                        % Retain window of interest
                        gedTs = gedTs(duration(1)*srate:duration(end)*srate);

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
    mkdir([path_home 'JRQA'])
    save([path_home 'JRQA/JRQA_Parameters'],'JRQA')

else

    % Import JRQA parapemters
    load([path_home 'JRQA/JRQA_Parameters'],'JRQA')

end

% Pre-allocate group-level output
[MIRROR,RR,DET] = deal( zeros(ndyads,nconds,nmeters,ntrials) );

% Run analyses
for condi = 1:nconds
    for dyadi = list_dyads
        disp(['Condition#' num2str(condi) ' - Dyad #' num2str(dyadi)])
        for triali = 1:ntrials

            % Import GED output
            load([path_home 'GED_output/GED_dyad_' num2str(dyadi) '_cond_' num2str(condi) '_trial_' num2str(triali)]);
             
            % Extract and process time series
            gedTs = squeeze(GED.ts(which_comp,:,:,:)); % [original_time x nfrex x nsubs] 
            for subi = 1:nsubs
                for frexi = 1:size(gedTs,2)
                    gedTs(:,frexi,subi) = filtfilt(b_butt, a_butt, gedTs(:,frexi,subi));  % Butterworth filter for aliasing correction
                end
            end
            gedTs = gedTs(1:dwn:end,:,:);                                        % Downsampling both subs
            % Overwrite back into GED.ts — shrink time dimension
            GED.ts = GED.ts(:,1:dwn:end,:,:);  % Shrink time dimension
            for subi = 1:nsubs
                for frexi = 1:size(gedTs,2)
                    GED.ts(which_comp,:,frexi,subi) = gedTs(:,frexi,subi); % re-assign
                end
            end

            % Compute dyadic analysis
            [FREQjrqa,FREQmirror] = FREQNESS_GroupAnalyses_Mocap(GED,JRQA,beat_frex,srate,vis_flag,'filter_width',.2,'metric_levels',meter,'component',which_comp, 'duration',duration);

            % Assign to group-level variables
            for metri = 1:nmeters
                MIRROR(dyadi,condi,metri,triali) = FREQmirror(metri);
                RR(dyadi,condi,metri,triali)     = FREQjrqa(metri).RR;
                DET(dyadi,condi,metri,triali)    = FREQjrqa(metri).DET;
            end

        end
    end
end



%% Visualize output at the group level

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



%% Export outputs

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
            subject_col(row) = dyadi;
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
writetable(T, [path_home 'OUT2R.xlsx']);



%% Grand-average figures

list_ged = dir([path_home 'GED_output/']);
list_ged = list_ged(~ismember({list_ged.name}, {'.', '..'}));

ngeds = length(list_ged);

pat_by_freq = 

for gedi = 1:ngeds

    

end