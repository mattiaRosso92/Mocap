function [data_filled,bad_segments,gap_info] = ...
    FREQNESS_InterpolateGaps_Mocap(data,srate,varargin)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP VERSION
%
% ========================================================================
%  This function detects NaN gaps in motion-capture marker coordinates and
%  reconstructs supported internal gaps so the data remain continuous for
%  filtering. Reconstructed samples remain listed in bad_segments and must
%  be excluded from covariance and downstream time-resolved analyses.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - data  : [XYZ marker coordinates x time x (participants)] array. Rows
%            must contain consecutive XYZ triplets. NaN denotes missing
%            data; Inf is invalid.
%
%  - srate : positive sampling rate in Hz.
%
%  - Optional name-value pairs:
%      - 'maximum_interpolated_gap' : maximum gap duration in seconds for
%                                     linear interpolation. Default: 0.05.
%
%      - 'maximum_reconstructed_gap': maximum gap duration in seconds for
%                                     cubic-spline reconstruction. Default:
%                                     [] (long-gap reconstruction disabled).
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - data_filled : input data with supported gaps reconstructed. Observed
%                  coordinate values are unchanged.
%
%  - bad_segments : sorted 1-based sample indices affected in any marker
%                   or participant. This row vector can be passed directly
%                   to FREQNESS_NetworkEstimation_Mocap using the existing
%                   'bad_segments' option.
%
%  - gap_info : gap provenance and QC, including participant-specific
%               bad samples and marker-level interpolation masks.
%
%  Boundary gaps and gaps exceeding the configured limits are unresolved
%  and produce an error. Filled values support filtering only; they are not
%  restored observations.
%
% ------------------------------------------------------------------------
%  AUTHORS:
%  Mattia Rosso, Felix Bigand, Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  felix.bigand@iit.it
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%  Center for Music in the Brain, Aarhus University
%  Neuroscience of Perception & Action Lab, Italian Institute of Technology (IIT)
%  Centre for Eudaimonia and Human Flourishing, Linacre College, University of Oxford
%
% ========================================================================


%% Handle and validate inputs

if nargin < 2
    error('data and srate are required inputs.');
end

opts = struct('maximum_interpolated_gap',0.05, ...
    'maximum_reconstructed_gap',[]);
opts = parse_name_value_pairs(opts,varargin{:});

if ~isnumeric(data) || ~isreal(data) || isempty(data) || ...
        ndims(data) > 3 || any(isinf(data(:)))
    error(['data must be a non-empty real numeric array without Inf values ' ...
        'in [XYZ marker coordinates x time x (participants)] format.']);
end
if mod(size(data,1),3) ~= 0
    error('The first data dimension must contain complete XYZ marker triplets.');
end
if size(data,2) < 2
    error('data must contain at least two time samples.');
end
if ~isnumeric(srate) || ~isreal(srate) || ~isscalar(srate) || ...
        ~isfinite(srate) || srate <= 0
    error('srate must be one positive finite scalar.');
end
validate_positive_scalar(opts.maximum_interpolated_gap, ...
    'maximum_interpolated_gap');
if ~isempty(opts.maximum_reconstructed_gap)
    validate_positive_scalar(opts.maximum_reconstructed_gap, ...
        'maximum_reconstructed_gap');
    if opts.maximum_reconstructed_gap < opts.maximum_interpolated_gap
        error(['maximum_reconstructed_gap must be empty or greater than or ' ...
            'equal to maximum_interpolated_gap.']);
    end
end


%% Detect marker and participant gaps

input_was_2d = ismatrix(data);
ncoordinates = size(data,1);
nsamples = size(data,2);
nparticipants = size(data,3);
nmarkers = ncoordinates/3;

original_missing_coordinate_mask = isnan(data);
marker_missing_mask = reshape(any(reshape( ...
    original_missing_coordinate_mask,3,nmarkers,nsamples,nparticipants),1), ...
    nmarkers,nsamples,nparticipants);

bad_segments_by_participant = cell(1,nparticipants);
for participant_index = 1:nparticipants
    bad_segments_by_participant{participant_index} = find( ...
        any(marker_missing_mask(:,:,participant_index),1));
end
bad_segments = find(any(marker_missing_mask,[1 3]));

interpolated_mask = false(nmarkers,nsamples,nparticipants);
reconstructed_mask = false(nmarkers,nsamples,nparticipants);
unresolved_mask = false(nmarkers,nsamples,nparticipants);

maximum_interpolated_frames = floor( ...
    opts.maximum_interpolated_gap*srate+1e-9);
if isempty(opts.maximum_reconstructed_gap)
    maximum_reconstructed_frames = maximum_interpolated_frames;
else
    maximum_reconstructed_frames = floor( ...
        opts.maximum_reconstructed_gap*srate+1e-9);
end


%% Reconstruct supported internal gaps

data_filled = data;
for participant_index = 1:nparticipants
    for marker_index = 1:nmarkers
        missing = marker_missing_mask(marker_index,:,participant_index);
        [gap_starts,gap_ends] = find_runs(missing);
        coordinate_indices = (3*marker_index-2):(3*marker_index);

        for gap_index = 1:numel(gap_starts)
            indices = gap_starts(gap_index):gap_ends(gap_index);
            is_boundary_gap = indices(1) == 1 || indices(end) == nsamples;
            if is_boundary_gap || numel(indices) > maximum_reconstructed_frames
                unresolved_mask(marker_index,indices,participant_index) = true;
                continue
            elseif numel(indices) <= maximum_interpolated_frames
                method = 'linear';
            elseif ~isempty(opts.maximum_reconstructed_gap)
                method = 'spline';
            else
                unresolved_mask(marker_index,indices,participant_index) = true;
                continue
            end

            [filled_marker,success] = fill_marker_gap( ...
                data_filled(coordinate_indices,:,participant_index), ...
                indices,method);
            if success
                data_filled(coordinate_indices,:,participant_index) = filled_marker;
                if strcmp(method,'linear')
                    interpolated_mask(marker_index,indices,participant_index) = true;
                else
                    reconstructed_mask(marker_index,indices,participant_index) = true;
                end
            else
                unresolved_mask(marker_index,indices,participant_index) = true;
            end
        end
    end
end


%% Assemble output metadata

gap_info = struct( ...
    'original_missing_coordinate_mask',original_missing_coordinate_mask, ...
    'bad_marker_sample_mask',marker_missing_mask, ...
    'interpolated_marker_sample_mask',interpolated_mask, ...
    'reconstructed_marker_sample_mask',reconstructed_mask, ...
    'unresolved_marker_sample_mask',unresolved_mask, ...
    'bad_segments',bad_segments, ...
    'bad_segments_by_participant',{bad_segments_by_participant}, ...
    'maximum_interpolated_gap_seconds',opts.maximum_interpolated_gap, ...
    'maximum_interpolated_gap_frames',maximum_interpolated_frames, ...
    'maximum_reconstructed_gap_seconds',opts.maximum_reconstructed_gap, ...
    'maximum_reconstructed_gap_frames',maximum_reconstructed_frames, ...
    'missing_coordinate_sample_count',nnz(original_missing_coordinate_mask), ...
    'affected_marker_sample_count',nnz(marker_missing_mask), ...
    'affected_timepoint_count',numel(bad_segments), ...
    'participant_count',nparticipants, ...
    'has_gaps',~isempty(bad_segments));

if any(unresolved_mask,'all')
    error('FREQNESS:GapInterpolation:UnresolvedGaps', ...
        ['%d marker samples remain unresolved because they touch a data ' ...
        'boundary, exceed the configured gap limits, or lack sufficient ' ...
        'observations for interpolation.'],nnz(unresolved_mask));
end

if ~isempty(bad_segments)
    warning('FREQNESS:GapInterpolation:MissingDataReconstructed', ...
        ['Detected %d missing coordinate samples affecting %d shared ' ...
        'timepoints across %d participants. Reconstructed values support ' ...
        'continuous filtering only; all affected timepoints remain listed ' ...
        'in bad_segments for exclusion.'], ...
        nnz(original_missing_coordinate_mask),numel(bad_segments),nparticipants);
end

if input_was_2d
    data_filled = data_filled(:,:,1);
    gap_info.original_missing_coordinate_mask = ...
        gap_info.original_missing_coordinate_mask(:,:,1);
    gap_info.bad_marker_sample_mask = gap_info.bad_marker_sample_mask(:,:,1);
    gap_info.interpolated_marker_sample_mask = ...
        gap_info.interpolated_marker_sample_mask(:,:,1);
    gap_info.reconstructed_marker_sample_mask = ...
        gap_info.reconstructed_marker_sample_mask(:,:,1);
    gap_info.unresolved_marker_sample_mask = ...
        gap_info.unresolved_marker_sample_mask(:,:,1);
end

end


%% Helper function: Fill one marker gap without changing observed values
function [marker_values,success] = fill_marker_gap(marker_values,indices,method)

success = true;
candidate = marker_values;
for coordinate_index = 1:size(marker_values,1)
    row = marker_values(coordinate_index,:);
    targets = indices(isnan(row(indices)));
    if isempty(targets)
        continue
    end
    observed = find(isfinite(row));
    minimum_observations = 2;
    if strcmp(method,'spline')
        minimum_observations = 4;
    end
    if numel(observed) < minimum_observations || ...
            targets(1) <= observed(1) || targets(end) >= observed(end)
        success = false;
        return
    end
    candidate(coordinate_index,targets) = interp1( ...
        observed,row(observed),targets,method);
end
marker_values = candidate;

end


%% Helper function: Find contiguous true runs
function [starts,ends] = find_runs(mask)

transitions = diff([false mask false]);
starts = find(transitions == 1);
ends = find(transitions == -1)-1;

end


%% Helper function: Validate positive scalar options
function validate_positive_scalar(value,name)

if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
        ~isfinite(value) || value <= 0
    error('%s must be one positive finite scalar expressed in seconds.',name);
end

end


%% Helper function: Parse name-value pairs
function opts = parse_name_value_pairs(opts,varargin)

if mod(length(varargin),2) ~= 0
    error('Arguments must be given as name-value pairs.');
end

for i = 1:2:length(varargin)
    if ~(ischar(varargin{i}) || (isstring(varargin{i}) && isscalar(varargin{i})))
        error('Optional argument names must be text.');
    end
    name = lower(char(varargin{i}));
    if isfield(opts,name)
        opts.(name) = varargin{i+1};
    else
        error(['Unrecognized argument: ' name]);
    end
end

end
