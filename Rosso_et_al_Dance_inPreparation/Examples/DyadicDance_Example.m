% Single-recording toolbox demonstration; not a group analysis.
%% Load your data

clear
path_repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(path_repo,'FREQNESS_Mocap_Toolbox'))
FREQNESS_Startup_Mocap();

% Dyad 35, left participant, trial 26. Replace this import with your own.
markData = readmatrix(fullfile(path_repo,'Dance_Data','Dyad_35','subj_LEFT','tr26.csv'),'NumHeaderLines',1);
markData = markData(1:end-3,2:end); % Remove row labels and the final ID_thigh XYZ triplet.
% Required layout: [3*nMarkers x nSamples], rows ordered X1,Y1,Z1,X2,Y2,Z2,...

%% FREQNESS settings

% For the core function
srate  = 250;       % Sampling rate (Hz)
frex   = .1:.1:10;  % Frequencies to analyse (Hz)
ncomps = 4;         % Components to retain

% For the visualization
freq2see = .5; %Frequency to visualize (Hz)

Landscape = [];
Landscape.frex   = frex;
Landscape.ncomps = ncomps;

Patterns = [];
Patterns.frex       = freq2see; % Frequency to visualize (Hz)
Patterns.comp       = 1; % Component to visualize
Patterns.markerData = markData;
Patterns.srate      = srate;
Patterns.start      = .25;
Patterns.animate    = true; % Set true for animation
% One label per XYZ triplet, in the same order as your data.
Patterns.labels = {'LB Head','LF Head','RF Head','RB Head','Sternum', ...
    'L Shoulder','R Shoulder','L Elbow','L Wrist','L Hand','R Elbow', ...
    'R Wrist','R Hand','Pelvis','L Hip','R Hip','L Knee','L Ankle', ...
    'L Foot','R Knee','R Ankle','R Foot'};
% For another marker layout, also set Patterns.bones = [marker1 marker2; ...].

%% Run functions

% Core function
FREQ = FREQNESS_NetworkEstimation_Mocap(markData,frex,srate,'ncomps',ncomps);

% Visualizer
FREQNESS_Visualizer_Mocap(FREQ,Landscape,Patterns);
