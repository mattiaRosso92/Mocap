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
%      - 'required_samples'          : sample indices that must be fully
%                                     reconstructed. Default: all samples.
%                                     Other samples may provide interpolation
%                                     context, but unresolved gaps confined to
%                                     them do not cause an error.
%
%      - 'boundary_method'           : treatment of supported gaps touching
%                                     either edge of required_samples.
%                                     'reject' (default) leaves them
%                                     unresolved; 'nearest' carries the
%                                     nearest observed coordinate into the
%                                     required interval for filter continuity.
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
%  Boundary gaps are unresolved by default. Opt-in nearest filling is useful
%  when missing boundary samples must be represented only to support
%  filtering; they remain in bad_segments. Gaps exceeding the configured
%  limits remain unresolved. An error is produced when unresolved gaps
%  intersect required_samples. Filled values are not restored observations.
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
    'maximum_reconstructed_gap',[],'required_samples',[], ...
    'boundary_method','reject');
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
boundary_method = validatestring(opts.boundary_method,{'reject','nearest'}, ...
    mfilename,'boundary_method');


%% Detect marker and participant gaps

input_was_2d = ismatrix(data);
ncoordinates = size(data,1);
nsamples = size(data,2);
nparticipants = size(data,3);
nmarkers = ncoordinates/3;
if isempty(opts.required_samples)
    required_samples = 1:nsamples;
else
    required_samples = validate_sample_indices( ...
        opts.required_samples,nsamples,'required_samples');
end

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

if strcmp(boundary_method,'nearest')
    required_mask = false(1,nsamples);
    required_mask(required_samples) = true;
    required_start = required_samples(1);
    required_end = required_samples(end);
    for participant_index = 1:nparticipants
        for marker_index = 1:nmarkers
            unresolved = unresolved_mask(marker_index,:,participant_index) & ...
                required_mask;
            [gap_starts,gap_ends] = find_runs(unresolved);
            coordinate_indices = (3*marker_index-2):(3*marker_index);
            for gap_index = 1:numel(gap_starts)
                indices = gap_starts(gap_index):gap_ends(gap_index);
                touches_required_boundary = indices(1) == required_start || ...
                    indices(end) == required_end;
                if ~touches_required_boundary || ...
                        numel(indices) > maximum_reconstructed_frames
                    continue
                end
                [filled_marker,success] = fill_marker_gap( ...
                    data_filled(coordinate_indices,:,participant_index), ...
                    indices,'nearest');
                if ~success
                    continue
                end
                data_filled(coordinate_indices,:,participant_index) = filled_marker;
                unresolved_mask(marker_index,indices,participant_index) = false;
                if numel(indices) <= maximum_interpolated_frames
                    interpolated_mask(marker_index,indices,participant_index) = true;
                else
                    reconstructed_mask(marker_index,indices,participant_index) = true;
                end
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
    'required_samples',required_samples, ...
    'boundary_method',string(boundary_method), ...
    'missing_coordinate_sample_count',nnz(original_missing_coordinate_mask), ...
    'affected_marker_sample_count',nnz(marker_missing_mask), ...
    'affected_timepoint_count',numel(bad_segments), ...
    'participant_count',nparticipants, ...
    'has_gaps',~isempty(bad_segments));

required_unresolved_mask = unresolved_mask(:,required_samples,:);
if any(required_unresolved_mask,'all')
    error('FREQNESS:GapInterpolation:UnresolvedGaps', ...
        ['%d required marker samples remain unresolved because they touch ' ...
        'a data boundary, exceed the configured gap limits, or lack ' ...
        'sufficient observations for interpolation.'], ...
        nnz(required_unresolved_mask));
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


%% Helper function: Validate a vector of sample indices
function indices = validate_sample_indices(value,nsamples,name)

if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
        isempty(value) || any(~isfinite(value)) || ...
        any(value ~= round(value)) || any(value < 1) || ...
        any(value > nsamples)
    error('%s must contain valid 1-based sample indices.',name);
end
indices = unique(double(value(:)'));

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
    if strcmp(method,'nearest')
        minimum_observations = 1;
    end
    is_internal_method = ~strcmp(method,'nearest');
    if numel(observed) < minimum_observations || ...
            (is_internal_method && ...
            (targets(1) <= observed(1) || targets(end) >= observed(end)))
        success = false;
        return
    end
    if strcmp(method,'nearest')
        for target_index = targets
            [~,closest] = min(abs(observed-target_index));
            candidate(coordinate_index,target_index) = row(observed(closest));
        end
    else
        candidate(coordinate_index,targets) = interp1( ...
            observed,row(observed),targets,method);
    end
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
