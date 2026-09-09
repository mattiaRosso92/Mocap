clear all
close all


%% Startup

% Choose if you want to enable visualizations
vis_flag = 1;

% Choose if you want to enable saving of FREQNESS output
save_flag = 0;

% New analyses use physical widths. Select 'legacy' only to reproduce the
% former bin-count-dependent filtering with an explicit width vector.
filter_width_calibration = validatestring( ...
    'physical',{'physical','legacy'});
filter_type = validatestring('logarithmic',{'logarithmic','linear'});
filter_output_tag = [filter_width_calibration '_' filter_type];

% Define paths
path_home = '/Users/au658766/Documents/MIB/Projects/NESS_withLBPD/2025_FreqNESS_Orchestra';
script_file = mfilename('fullpath');
path_study = fileparts(script_file);
path_repo = fileparts(path_study);
path_toolbox = fullfile(path_repo,'FREQNESS_Mocap_Toolbox');

addpath(path_toolbox)
addpath(fullfile(path_toolbox,'FREQNESS_Functions'))
addpath(fullfile(path_toolbox,'FREQNESS_ExternalFunctions'))


%% Prepare data

% Define sampling rate
srate = 25;

% % Define downsampling
% dwn = 1;
% srate = round(srate/dwn); % downsample

% Design settings
nconds  = 1; % Number of pieces
condlabels = {'Piece#1'};
ntrials = 1; % THINK OF HOW TO DEAL WITH PIECES AND REPETITIONS


% Base labels (already excluded the last marker)
marklabels = {
    'Conductor_L','Conductor_R','ViolinA_1','ViolinA_2','ViolinA_3','ViolinA_4',...
    'ViolinA_5','ViolinA_6','ViolinA_7','ViolinA_8','ViolinB_1','ViolinB_2',...
    'ViolinB_3','ViolinB_4','ViolinB_5','ViolinB_6','ViolinB_7','ViolinB_8',...
    'ViolinB_9','ViolinB_10','ViolinB_11','ViolinB_12','Viola_1','Viola_2',...
    'Viola_3','Viola_4','Viola_5','Viola_6','Viola_7','Cello_1','Cello_2',...
    'Cello_3','Cello_4','Cello_5','Cello_6','Bass_1','Bass_2','Bass_3',...
    'Bass_4','Bass_5','Harp_1','Flute_1','Flute_2','Flute_3','Oboe_1',...
    'Oboe_2','Clarinet_1','Clarinet_2','Bassoon_1','Bassoon_2','Horn_1',...
    'Horn_2','Horn_3','Horn_4','Trumpet_1','Trumpet_2','Trombone_1',...
    'Trombone_2','Trombone_3','Tuba_1','Timpani_1','Percussion_1',...
    'Percussion_2','Percussion_3'
    };


% Expand with X, Y, Z prefixes
xyz_marklabels = cell(1, length(marklabels) * 3);

for i = 1:length(marklabels)
    xyz_marklabels{3*(i-1)+1} = ['X_' marklabels{i}];
    xyz_marklabels{3*(i-1)+2} = ['Y_' marklabels{i}];
    xyz_marklabels{3*(i-1)+3} = ['Z_' marklabels{i}];
end
nmarks = length(xyz_marklabels);


% Define X,Y,Z indexes
x_idx = 1:3:nmarks-2;
y_idx = 2:3:nmarks-1;
z_idx = 3:3:nmarks;


% % Song BPM (all songs)
% song_bpms = [111.03, 116.07, 118.23, 118.95, 120.47, 125.93, 128.27, 129.06];
%
% % Define metric levels of interest
% meter = [.25 .5 1 2];
% nmeters = length(meter);



%% Run FREQNESS

% Loop over conditions
for condi = 1

    % Analyse trial by trial
    for triali = 1

        % Initialize data matrix for every iteration
        markData = zeros(nmarks,1); % rows only, we don't know the piece duration yet

        % Loop over partners

        % Define path
        path_data = [path_home '/Data'];

        % % Import info on songs, per single participant
        % song_info = ;
        % songs_frex = 1 ./ (60 ./ song_bpms); % convert to Hz
        % % Find beat frequency (find song in 'song_subj_LEFT/RIGHT.csv')
        % idx_beat = song_info(id_dyad,id_trial);
        % beat_frex(subi) = songs_frex( idx_beat );
        % Define vector of frequencies
        %frex = beat_frex(subi)/8:beat_frex(subi)/8:beat_frex(subi)*4; % above beat
        frex = [.5:.1:10]; % above beat

        % Import data (skip 1st row and column)
        tempData = csvread([path_data '/64track-deeplabcut-carmen.csv'], 1, 1);
        npnts = size(tempData,1);

        % Create empty matrix
        markData = repmat(markData, 1, npnts);

        % Fill in input data
        markData(sort([x_idx,y_idx]),:) = tempData'; % X & Y data
        markData(z_idx,:) = 0; % Z gets a constant value, as it was not recorded

        % Remove possible outliers
        idx2remove = 64;
        mark2remove = [x_idx(idx2remove),y_idx(idx2remove),z_idx(idx2remove)];
        markData(mark2remove,:) = [];
        xyz_marklabels(mark2remove) = [];

% TEMP: DROP THE FIRST HALF TO GET MORE CONSISTENT 2HZ, WILL GET
% ANNOTATIONS LATER ON
markData(:,end/2:end) = [];


    end


    %% Run network decomposition on the dyad

    if strcmp(filter_width_calibration,'legacy')
        filter_width = FREQNESS_ComputeLegacyFilterWidths_Mocap( ...
            frex(:),filter_type);
        expected_filter_width = filter_width;
    else
        filter_width = [];
        expected_filter_width = FREQNESS_ComputeFilterWidths_Mocap( ...
            frex(:),filter_type);
    end
    GED = []; % refresh for loop iterations
    GED = FREQNESS_NetworkEstimation_Mocap(markData, frex, srate, ...
        'fwidth',filter_width,'filter',filter_type);
    assert(isequal(GED.fwhm,expected_filter_width), ...
        'Core output did not use the requested filter-width calibration.');
    GED.filter_width_calibration = string(filter_width_calibration);
    GED.filter_type = string(filter_type);
    analysis_info = struct( ...
        'filterWidthCalibration',string(filter_width_calibration), ...
        'filter',string(filter_type),'fwidth',GED.fwhm);

    % Save output
    if save_flag == 1
        output_path = fullfile(path_home,'GED_output',filter_output_tag);
        if ~isfolder(output_path); mkdir(output_path); end
        output_file = fullfile(output_path,sprintf( ...
            'GED_cond_%d_trial_%d.mat',condi,triali));
        save(output_file,'GED','analysis_info','frex','srate','-v7.3')
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
        Patterns.frex   = frex(3);
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





