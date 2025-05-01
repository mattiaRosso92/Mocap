clear all
close all


%% Startup

% Define home path
path_home = '/Users/mattiaipem/Documents/IPEM/Projects/NESS_withLBPD/2025_FreqNESS_Mocap/';

% NOTE: this will be replaced by a Startup function
cd(path_home) 

% Filter data by experimental conditions
% 	- 'cond_vis': each cell informs about the condition of a trial (0='No Visual Contact', 1='Visual Contact')
% 	- 'cond_mus': each cell informs about the condition of a trial (0='Different Music', 1='Same Music')
lbl_vis = csvread([path_home 'cond_vis.csv'], 1, 1);
lbl_mus = csvread([path_home 'cond_mus.csv'], 1, 1);

%% Prepare data

% NOTE: I suspect that this first example prticipant has X and Y swapped


% Select dyad and subject
id_dyad  = 2;
id_sub   = '_LEFT';

% Select trial
list_trials = find(lbl_vis(id_dyad,:) == 0 & (lbl_mus(id_dyad,:) == 1)); % retain uncoupled conditions
id_trial = input(['Input a trial among the following: ' num2str(list_trials) '   - ']);
id_str = sprintf('%02d', id_trial); % to add the '0' before numbers < 10

% Define path
path_data = [path_home 'Data/Dyad_' num2str(id_dyad) '/subj' id_sub];
cd(path_data);

% Import data (skip 1st row and column)
markData   = csvread(['tr' id_str '.csv'], 1, 1);

% Define sampling rate
srate = 250;

% Remove last marker
markData = markData(1:end-3,:);

% Updated number of markers
nmarks = size(markData,1);
npnts = size(markData,2);

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



%% Info on song

% Import info on all songs
song_info = csvread([path_home '/song_subj' id_sub '.csv'], 1, 1) + 1; % already add +1 to compensate Python 0-indexing

% Song BPM (all songs)
song_bpms = [111.03, 116.07, 118.23, 118.95, 120.47, 125.93, 128.27, 129.06]; 
% Convert to Hz
songs_frex = 1 ./ (60 ./ song_bpms);

% Find beat frequency (find song in song_subj_LEFT.csv) 
idx_beat = song_info(id_dyad,id_trial);
beat_frex = songs_frex( idx_beat ); % hard-coded for this participant

% Vector of frequencies
frex = [beat_frex/8:beat_frex/8:beat_frex*4]; % above beat*


%% Run network decomposition


GED = FREQNESS_NetworkEstimation_Mocap(markData, frex, srate);



%% FREQNESS VISUALIZATION


%%% ------------------- USER SETTINGS ------------------- %%%

% Settings (visualization of network landscape)
Landscape = [];
Landscape.frex   = frex; 
Landscape.ncomps = 20;

% Settings (visualization of network activation patterns)
Patterns = [];
Patterns.frex   = beat_frex/4;  % MAX beat*2
Patterns.labels = marklabels;   % insert marker labels, in format X1,Y1,Z1,X2,Y2,Z2,[...]
Patterns.markerData = markData; % used to compute the backprojection
Patterns.comp   = 1;            % choose the component to inspect
Patterns.srate  = srate;        % necessary for the animation
Patterns.start  = .25;           % starting point of the animation (0-1)


%%% ------------------ COMPUTATION --------------------- %%%

% Plot network landscape and save nifti images
FREQNESS_Visualizer_Mocap(GED,Landscape,Patterns)


