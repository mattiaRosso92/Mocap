% Shared configuration for the main and supplementary Dance pipelines.
% Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
%% BLOCK 0 - USER SETTINGS, STARTUP, AND OUTPUT ROUTING

% All raw inputs and all newly generated outputs stay on the local drive in
% Dance_Data. The dedicated results root prevents this replication from
% modifying any legacy analyses currently stored directly in Dance_Data.
% Shared study configuration; run this complete script, not a selection.
path_script = fileparts(fileparts(mfilename('fullpath')));
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
CFG.common.list_dyads = 1:35; % Final main and supplementary cohort; no dyad-level exclusions.
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
CFG.block6.window_seconds = [10 45]; % From recording onset, inclusive.
% The toolbox rounds proportional endpoints on the downsampled 60 s trial.
% Include the first sample at t = 0: indices 251:1126 at 25 Hz (876 samples).
CFG.block6.duration = (CFG.block6.window_seconds* ...
    (CFG.block6.srate/CFG.block6.downsample)+1)/ ...
    (60*CFG.block6.srate/CFG.block6.downsample);
CFG.block6.metric_levels = [.25 .5 1 2];
CFG.block6.standardize = false;
CFG.block6.threshold_method = 'max_fraction';
CFG.block6.threshold = .1; % 10% of each trial's maximum JOINT Euclidean distance.
CFG.block6.theiler_window = 0; % Retain the identity diagonal, as in the validated run.
CFG.block6.lmin = 2;
CFG.block6.vmin = 2;
CFG.block6.output_tag = sprintf( ...
    'PhaseSpaceRQA_AA%gHz_Dwn%d_Radius%g_Standardize%d_Window%gto%gs', ...
    CFG.block6.lowpass_hz,CFG.block6.downsample, ...
    100*CFG.block6.threshold,CFG.block6.standardize, ...
    CFG.block6.window_seconds(1),CFG.block6.window_seconds(2));
CFG.block6.output_path = fullfile( ...
    CFG.common.results_path,['04_' CFG.block6.output_tag]);
CFG.block6.reuse_core_path = CFG.common.reuse_core_path;
% Optional import of matching RR/DET results; disabled by default.
CFG.block6.reuse_rqa_path = '';
CFG.block7.output_path = fullfile( ...
    CFG.common.results_path,'05_Group');
CFG.block7.figure_path = fullfile( ...
    CFG.block7.output_path,'Figures',CFG.block6.output_tag);
CFG.block7.overwrite_flag = false;
CFG.block8.output_path = fullfile( ...
    CFG.common.results_path,'06_Statistics_R');
CFG.block8.overwrite_flag = false;

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

% Manuscript default: GED. PCA is an optional BLOCK 1-only control saved
% with a separate _PCA suffix; downstream publication blocks remain GED.
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
