%% Load your data

clear
addpath(genpath('/Users/au658766/Documents/GitHub/Mocap/FREQNESS_Mocap_Toolbox'))

path_data = fullfile(fileparts(mfilename('fullpath')),'Example_data');
files = dir(fullfile(path_data,'**','*.csv'));
FREQ = cell(numel(files),1); % One output per file, in the same order as files.

for filei = 1:numel(files)
    data = readtable(fullfile(files(filei).folder,files(filei).name),'VariableNamingRule','preserve');

    % Position coordinates (mm), excluding angles and centre of gravity.
    names = data.Properties.VariableNames;
    x_names = names(contains(names,'Position') & endsWith(names,'_X (mm)'));
    marklabels = regexprep(x_names,'Positions?_X \(mm\)$','');
    [marklabels,idx] = unique(marklabels,'stable'); % Keep the duplicated RShoulder only once.
    x_names = x_names(idx);
    xyz_names = [x_names; strrep(x_names,'_X (mm)','_Y (mm)'); strrep(x_names,'_X (mm)','_Z (mm)')];
    markData = data{:,xyz_names(:)}'; % [3*nMarkers x nSamples]: X1,Y1,Z1,X2,Y2,Z2,...

    %% FREQNESS settings

    srate  = 1/median(diff(data.time_s)); % Sampling rate from the CSV time column (Hz)
    frex   = .1:.1:10;                  % Frequencies to analyse (Hz)
    ncomps = 4;                         % Components to retain

    Landscape = [];
    Landscape.frex   = frex;
    Landscape.ncomps = ncomps;
    Landscape.title  = sprintf('%s | %s | Block %d', ...
        string(data.participant_id(1)),string(data.condition(1)),data.block(1));

    Patterns = [];
    Patterns.frex       = 1.6; % Frequency to visualize (Hz)
    Patterns.comp       = 1; % Component to visualize
    Patterns.markerData = markData;
    Patterns.srate      = srate;
    Patterns.start      = .25;
    Patterns.animate    = true; % Set true for animation
    Patterns.labels     = marklabels;
    Patterns.plot_bones = false; % These CSVs do not specify skeleton links.

    %% Run functions

    % Core function
    FREQ{filei} = FREQNESS_NetworkEstimation_Mocap(markData,frex,srate,'ncomps',ncomps);

    % Visualizer
    FREQNESS_Visualizer_Mocap(FREQ{filei},Landscape,Patterns);
end
