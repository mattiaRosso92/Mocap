clear all
close all


%% Startup

% Choose if you want to enable visualizations
vis_flag = 1;

% Choose if you want to enable saving of FREQNESS output
save_flag = 0;

% Choose the method youn want to use for FREQNESS (GED or PCA)
which_method = 'GED';

% Define home path
path_home = '/Users/au658766/Documents/MIB/Projects/NESS_withLBPD/2025_FreqNESS_Mocap/';

% NOTE: this will be replaced by a Startup function
addpath(path_home)
addpath([path_home '/crptool'])

% Filter data by experimental conditions
% 	- 'cond_vis': each cell informs about the condition of a trial (0='No Visual Contact', 1='Visual Contact')
% 	- 'cond_mus': each cell informs about the condition of a trial (0='Different Music', 1='Same Music')
lbl_vis = csvread([path_home 'cond_vis.csv'], 1, 1);
lbl_mus = csvread([path_home 'cond_mus.csv'], 1, 1);


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


%% Run FREQNESS
 
% Loop over conditions
for condi = 1:nconds

    % Select dyad and subject
    for dyadi = 2%list_dyads
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
                frex(:,subi) = beat_frex(subi)/8:beat_frex(subi)/8:beat_frex(subi)*4; % above beat

                % Import data (skip 1st row and column)
                tempData = csvread(['tr' id_trial_str '.csv'], 1, 1);
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

            % Initialize ED output upon first iteration
            if condi == 1 && dyadi == list_dyads(1) && triali == 1 
                nfrex = size(frex,1);
                ED = zeros(nconds,length(list_dyads),ntrials,nfrex,nsubs);
            end


            %% OPTIONAL: convert data to velocity
            % 
            % % NOTE: Ask Petri & Felix whether they project the position
            % % data after the eigendecomposition
            % 
            % dt = 1/srate; % differentiate by time units
            % markData = diff(markData,1,2) / dt; % compute velocity


            %% Run network decomposition on the dyad

            % NOTE: if you are going to save the GED output, select few ncomps; in
            % order to estimate ED, you need them to equal nmarks

            if strcmp(which_method,'GED')

                % Compute FREQNESS with GED
                GED = []; % refresh for loop iterations
                GED = FREQNESS_NetworkEstimation_Mocap(markData, frex, srate,'ncomps',4); % networks estimation
                %ED(condi,dyadi,triali,:,:)  = FREQNESS_EffectDim(GED.evals); % effective dimensionality
                % Normalize frequencies by beat
                GED.frex_norm = GED.frex ./ beat_frex;

            elseif strcmp(which_method,'PCA')

                % Compute FREQNESS with PCA
                PCA = []; % refresh for loop iterations
                PCA = FREQNESS_NetworkEstimation_Mocap_PCA(markData, frex, srate,'ncomps',4); % networks estimation
                %ED(condi,dyadi,triali,:,:)  = FREQNESS_EffectDim(PCA.evals); % effective dimensionality
                % Normalize frequencies by beat
                PCA.frex_norm = PCA.frex ./ beat_frex;

            else

                error('Double-check your method: it must be GED or PCA')
            
            end


            % Save output
            if save_flag == 1
                mkdir([path_home, which_method '_output']);
                save([path_home, which_method '_output/' which_method '_dyad_' num2str(dyadi) '_cond_' num2str(condi) '_trial_' num2str(triali) prefix{idx_XYZ}]);
                %save([path_home, which_method '_EffectDim' prefix{idx_XYZ}], 'ED');
            end



            %% FREQNESS VISUALIZATION

            % Enable visualization
            if vis_flag == 1

                %%% ------------------- USER SETTINGS ------------------- %%%

                % Settings (visualization of network landscape)
                Landscape = [];
                Landscape.frex   = frex;
                Landscape.ncomps = 4;

                % Settings (visualization of network activation patterns)
                Patterns = [];
                Patterns.frex   = beat_frex(1);    % MAX beat*2
                Patterns.labels = marklabels;   % insert marker labels, in format X1,Y1,Z1,X2,Y2,Z2,[...]
                Patterns.markerData = markData; % used to compute the backprojection
                Patterns.comp   = 1;            % choose the component to inspect
                Patterns.srate  = srate;        % necessary for the animation
                Patterns.start  = .25;           % starting point of the animation (0-1)
                Patterns.bones  = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10;7,11;11,12;12,13;
                                   14,15;14,16;15,16;15,17;17,18;18,19;16,20;20,21;21,22];
                                    % bone sticks for visualization
                                    % pre-shifted links (MATLAB 1-based indexing already applied)
        

                %%% ------------------ COMPUTATION --------------------- %%%

                % Plot bodily network landscape, spatial activation in XYZ
                FREQNESS_Visualizer_Mocap(GED,Landscape,Patterns)


            end



        end

    end

end




%% FREQNESS GROUP-LEVEL
% Run up to the '%% Prepare Data' section before running this section

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
            S = load([path_home, which_method '_output/' which_method ...
                      '_dyad_' num2str(dyadi) '_cond_' num2str(condi) ...
                      '_trial_' num2str(triali) prefix{idx_XYZ}]);

            % Alias to the chosen method struct (either S.GED or S.PCA)
            M = S.(which_method);

            % Initialize group-level outputs once, using the loaded struct sizes
            if dyadi == list_dyads(1) && condi == 1 && triali == 1
                all_evals     = zeros([ndyads, nconds, ntrials, size(M.evals)]);
                all_pats      = zeros([ndyads, nconds, ntrials, size(M.pats)]);
                all_frex_norm = zeros([ndyads, nconds, ntrials, nsubs, length(M.frex)]);
            end

            % Assign normalized frequency axis (based on beat of each subject and trial)
            for subi = 1:nsubs
                all_frex_norm(dyadi,condi,triali,subi,:) = M.frex_norm(:,subi);
            end

            % Assign outputs (retain top components)
            all_evals(dyadi,condi,triali,1:ncomps2keep,:,:)  = M.evals(1:ncomps2keep,:,:);
            all_pats(dyadi,condi,triali,:,1:ncomps2keep,:,:) = M.pats(:,1:ncomps2keep,:,:);

        end
    end
end

% Save output
if save_flag == 1
    save([path_home, which_method '_output/' which_method '_All' prefix{idx_XYZ} '.mat'], ...
         'all_evals', 'all_pats', 'all_frex_norm');
end



%% VISUALIZATION: Eigenspectra & Activation Patterns (Group-level)

% TODO: SEM are fixed, but still do the following for other plots:
% After fixing, if needed, do the same in FREQNESS_SI_FIlters.m (what about
% all other plots? massive fix with chatGPT

path_data = '/Users/au658766/Desktop/TEMP_Mocap/';

% Select method: 'GED' or 'PCA'
which_method = 'GED';

% Choose whether you want one dimension
idx_XYZ = 1; % 1 = '', all axes included

close all

% Import group-level data
load([path_data, which_method '_output/' which_method '_All' prefix{idx_XYZ} '.mat'], 'all_evals', 'all_pats','all_frex_norm')
load(fullfile(path_data, [which_method '_EffectDim' prefix{idx_XYZ}]));
   

% Remove bad dyads
idx2keep = ismember(1:ndyads,list_dyads); 
idx2keep = 1:(ndyads-sum(~idx2keep)); % NOTE: at some point, I ended up removing the bad dyads from the GED outputs
all_evals = all_evals(idx2keep,:,:,:,:,:);
all_pats = abs( all_pats(idx2keep,:,:,:,:,:,:) ); % convert to abs() here if you want the absolute values
all_frex_norm = all_frex_norm(idx2keep,:,:,:,:);

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

% Resample group means & SEM onto log2-uniform grid
avg_evals_gg_rs = zeros(ncomps2keep, nPoints);
sem_evals_gg_rs = zeros(ncomps2keep, nPoints);

for compi = 1:ncomps2keep
    y  = squeeze(avg_evals_gg(compi,:));
    se = squeeze(sem_evals_gg(compi,:));

    avg_evals_gg_rs(compi,:) = interp1(frex2plot, y,  frex_uniform, 'linear','extrap');
    sem_evals_gg_rs(compi,:) = interp1(frex2plot, se, frex_uniform, 'linear','extrap');
end

figure
hold on

for compi = 1:ncomps2keep

    this_y   = squeeze(avg_evals_gg_rs(compi,:));
    this_sem = squeeze(sem_evals_gg_rs(compi,:));

    xx = [log2_frex_uniform; flipud(log2_frex_uniform)];
    yy = [this_y(:)-this_sem(:); flipud(this_y(:)+this_sem(:))];

    fill(xx, yy, colors(compi,:), ...
        'FaceAlpha', 0.22, ...
        'EdgeColor', 'none');

    plot(log2_frex_uniform, this_y, ...
        'Color', colors(compi,:), ...
        'LineWidth', 2.5);
end

octave_set  = [0.125 0.25 0.5 1 2 4 8];
in_range    = octave_set >= min(frex_uniform) & octave_set <= max(frex_uniform);
octave_vals = octave_set(in_range);
if numel(octave_vals) >= 2
    xticks(log2(octave_vals));
    xticklabels(string(octave_vals));
end
xtickangle(45)

xlim([min(log2_frex_uniform) max(log2_frex_uniform)])
ylim([0 80])

xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')
ylabel('Explained variance (%)', 'FontSize', 14, 'FontWeight', 'bold')
legend(arrayfun(@(x) sprintf([which_method ' #%d'],x), 1:ncomps2keep, 'UniformOutput', false))
title('Grand-grandaverage')

grid on; grid minor; box on
set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
set(gcf, 'Color', 'w');

sgtitle(['Grand-grandaverage bodily network landscape across conditions - ' which_method])


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
bones      = Patterns.bones;
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

% Fixed marker size: no variability-to-marker-size mapping
marker_size = 95;

% Marker / skeleton aesthetics
marker_edge_width = 0.6;
skeleton_linewidth = 2.6;

% Average activation patterns across trials
gg_pats = squeeze(mean(all_pats, 3));
% gg_pats: [dyads x conds x markers x comps x frex x subs]

% Average activation patterns across conditions
gg_pats = squeeze(mean(gg_pats, 2));
% gg_pats: [dyads x markers x comps x frex x subs]

% Average activation patterns across dyads
avg_pats_gg = squeeze(mean(gg_pats, 1));
% avg_pats_gg: [markers x comps x frex x subs]

% Loop over metric levels
for frexi = 1:length(idx_frex)

    % Global normalization value, within frequency and selected component,
    % across markers and subjects
    global_max_pat = max(avg_pats_gg(:,which_comp,idx_frex(frexi),:), [], 'all');

    figure('Color','w'), clf

    % Diagonal placement in a 3x3 grid = XYZ
    for dimi = 1:ndims

        subplot(ndims, ndims, (dimi-1)*ndims + dimi), hold on

        for subi = 1:nsubs

            % Extract and normalize activation pattern using global max
            this_pat = squeeze(avg_pats_gg(:,which_comp,idx_frex(frexi),subi));
            this_pat = this_pat / global_max_pat;

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

            % Choose colors and plot
            switch dimi
                case 1
                    scatter3(x_pos, y_pos, z_pos, marker_size, col_static(cidx_x,:), ...
                        'filled', ...
                        'MarkerEdgeColor','k', ...
                        'LineWidth', marker_edge_width);
                    title('X-axis activation')

                case 2
                    scatter3(x_pos, y_pos, z_pos, marker_size, col_static(cidx_y,:), ...
                        'filled', ...
                        'MarkerEdgeColor','k', ...
                        'LineWidth', marker_edge_width);
                    title('Y-axis activation')

                case 3
                    scatter3(x_pos, y_pos, z_pos, marker_size, col_static(cidx_z,:), ...
                        'filled', ...
                        'MarkerEdgeColor','k', ...
                        'LineWidth', marker_edge_width);
                    title('Z-axis activation')
            end

            % Plot bones
            for k = 1:size(bones,1)

                p1 = bones(k,1);
                p2 = bones(k,2);

                plot3([x_pos(p1) x_pos(p2)], ...
                      [y_pos(p1) y_pos(p2)], ...
                      [z_pos(p1) z_pos(p2)], ...
                      'k-', ...
                      'LineWidth', skeleton_linewidth);

            end

        end

        % Format subplot
        axis vis3d
        daspect([1 1 1])

        xlabel('X')
        ylabel('Y')
        zlabel('Z')

        view(60,30)

    end

    % Single shared colorbar
    colormap(col_static);

    cb = colorbar('Position',[0.965 0.12 0.012 0.76]);
    cb.Label.String = 'Normalized activation';
    cb.FontSize = 9;

    sgtitle(['Grand-grandaverage Activation Pattern - ' which_method ...
        ' | Component #' num2str(which_comp) ...
        ' | Freq = ' num2str(frex2plot(idx_frex(frexi)), '%.2f') ...
        ' × Beat'])

end
%% FREQNESS DYADIC ANALYSES

clear all

% Pick component
which_comp = 2;

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
    mkdir([path_home 'JRQA'])
    save([path_home 'JRQA/JRQA_Parameters_Comp#' num2str(which_comp)],'JRQA')

else

    % Import JRQA parapemeters
    load([path_home 'JRQA/JRQA_Parameters_Comp#' num2str(which_comp)],'JRQA')

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
            gedTs = gedTs(1:dwn:end,:,:);  % Downsampling both subs
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
writetable(T, [path_home 'OUT2R_Comp#' num2str(which_comp) '.xlsx']);



