function [allData, dataLabels, path_home] = FREQNESS_Startup_Mocap()
% ========================================================================
%  FREQ-NESS MOCAP STARTUP FUNCTION
% ========================================================================
%
%  This function initializes the FREQ-NESS MoCap toolbox by automatically
%  determining its installation directory, adding the required subfolders
%  to the MATLAB path, and loading convention-based motion-capture data.
%
%  The FREQNESS_Data directory contains one folder per dataset to analyze.
%  A dataset can represent one participant, one dyad, or a larger group.
%  Each dataset folder must use one of these two layouts:
%
%  1) One .mat file containing one real finite numeric array in
%     [XYZ marker coordinates x time x participants] format.
%
%  2) One .mat file per participant, each containing one real finite
%     numeric [XYZ marker coordinates x time] matrix. Participant files are
%     sorted alphabetically and concatenated along the third dimension.
%
%  In both layouts, rows must follow the repeated order
%  [X_marker1; Y_marker1; Z_marker1; X_marker2; ...].
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - allData    : Cell array with one entry per dataset folder. Each entry
%                 contains [XYZ marker coordinates x time x participants].
%
%  - dataLabels : Dataset-folder names, in the same order as allData.
%
%  - path_home  : Absolute path of the FREQ-NESS MoCap toolbox.
%
% ------------------------------------------------------------------------
%  AUTHORS:
% ------------------------------------------------------------------------
%  Mattia Rosso, Felix Bigand, Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  felix.bigand@iit.it
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%
% ========================================================================

%% Define main path based on the directory of this function

path_home = fileparts(mfilename('fullpath'));


%% Add toolbox directories

addpath(path_home);
addpath(fullfile(path_home, 'FREQNESS_Functions'));
addpath(fullfile(path_home, 'FREQNESS_ExternalFunctions'));
addpath(fullfile(path_home, 'FREQNESS_ExampleScripts'));
addpath(fullfile(path_home, 'FREQNESS_Data'));

fprintf('\nFREQ-NESS MoCap Startup: loading motion-capture datasets.\n');
fprintf('\nFREQ-NESS MoCap successfully initialized.\n');
fprintf('Base directory: %s\n\n', path_home);


%% Report external dependencies

required_external = {'filterFGx','FREQNESS_AnalyticSignal'};
optional_external = {'RPparam','jrqa'};

for funi = 1:numel(required_external)
    if exist(required_external{funi}, 'file') ~= 2
        warning('FREQNESS:MissingExternalFunction', ...
            ['Required external function %s was not found. Add it to ' ...
            'FREQNESS_ExternalFunctions before running network estimation.'], ...
            required_external{funi});
    end
end

for funi = 1:numel(optional_external)
    if exist(optional_external{funi}, 'file') ~= 2
        warning('FREQNESS:MissingGroupDependency', ...
            ['Optional temporal-coordination function %s was not found. Add the ' ...
            'CRP Toolbox dependency to FREQNESS_ExternalFunctions before ' ...
            'running FREQNESS_TimeCoord_Mocap.'], ...
            optional_external{funi});
    end
end


%% Fetch motion-capture data

folder_data = dir(fullfile(path_home, 'FREQNESS_Data'));
folder_data = folder_data([folder_data.isdir] & ...
    ~ismember({folder_data.name},{'.','..'}) & ...
    ~startsWith({folder_data.name},'.'));

if ~isempty(folder_data)
    [~,folder_order] = sort(lower({folder_data.name}));
    folder_data = folder_data(folder_order);
end

nfolds = numel(folder_data);
allData = cell(nfolds,1);
dataLabels = reshape({folder_data.name},[],1);

for foldi = 1:nfolds

    this_folder = fullfile(folder_data(foldi).folder,folder_data(foldi).name);
    files_mat = dir(fullfile(this_folder,'*.mat'));

    if ~isempty(files_mat)
        [~,file_order] = sort(lower({files_mat.name}));
        files_mat = files_mat(file_order);
    end

    nfiles = numel(files_mat);
    if nfiles == 0
        warning('No .mat files found in dataset folder: %s',this_folder);
        allData{foldi} = [];
        continue
    end

    if nfiles == 1

        % One file can contain a single participant or a complete group.
        this_data = load_single_numeric_array(files_mat(1));
        validate_xyz_data(this_data,files_mat(1).name,true);
        allData{foldi} = this_data;

    else

        % Multiple files represent participants in the same interacting group.
        for subi = 1:nfiles

            this_data = load_single_numeric_array(files_mat(subi));
            validate_xyz_data(this_data,files_mat(subi).name,false);

            if subi == 1
                [nfeatures,ntime] = size(this_data);
                groupData = nan(nfeatures,ntime,nfiles);
            elseif ~isequal(size(this_data),[nfeatures ntime])
                error(['Size mismatch in file %s relative to the first ' ...
                    'participant in dataset folder %s.'], ...
                    files_mat(subi).name,this_folder);
            end

            groupData(:,:,subi) = this_data;

        end

        allData{foldi} = groupData;

    end

end


end


%% Helper function: load exactly one numeric array

function data = load_single_numeric_array(file_info)

S = load(fullfile(file_info.folder,file_info.name));
fn = fieldnames(S);

if numel(fn) ~= 1
    error('File %s must contain exactly one data array.',file_info.name);
end

data = S.(fn{1});

end


%% Helper function: validate MoCap data convention

function validate_xyz_data(data,file_name,allow_group_array)

valid_dimensions = ismatrix(data) || (allow_group_array && ndims(data) == 3);

if ~isnumeric(data) || ~isreal(data) || isempty(data) || ...
        ~valid_dimensions || any(~isfinite(data(:)))
    if allow_group_array
        expected = ['a non-empty real finite numeric array in ' ...
            '[XYZ marker coordinates x time x participants] format'];
    else
        expected = ['a non-empty real finite numeric matrix in ' ...
            '[XYZ marker coordinates x time] format'];
    end
    error('File %s must contain %s.',file_name,expected);
end

if mod(size(data,1),3) ~= 0
    error(['The first dimension of file %s must be divisible by three ' ...
        'because X, Y, and Z coordinates are interleaved by marker.'], ...
        file_name);
end

if size(data,2) < 2
    error('File %s must contain at least two time points.',file_name);
end

end
