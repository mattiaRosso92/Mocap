function [FREQrqa,figures] = compute_phase_space_rqa( ...
    FREQ,target_frex,varargin)

% ========================================================================
%  FREQ-NESS MOCAP: GROUP PHASE-SPACE RECURRENCE QUANTIFICATION ANALYSIS
% ========================================================================
%  This function estimates temporal coordination by representing every
%  participant's selected FREQ-NESS network time series as one dimension
%  of a joint group phase space. It therefore avoids scalar delay
%  embedding: at time t, the system state is the N-participant vector
%  [participant_1(t), ..., participant_N(t)].
%
%  The implementation adapts BROADNESS_PhaseSpace_RQA to the MoCap group
%  framework. Euclidean distances between group states are thresholded to
%  form one recurrence plot per requested metric level, from which eight
%  RQA measures are computed by FREQNESS_RQA_Mocap.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ : Structure output by FREQNESS_NetworkEstimation_Mocap.
%      - FREQ.ts   : [nComponents x nTime x nFrex x nParticipants]
%      - FREQ.frex : shared frequency vector, or participant-specific
%                    [nFrex x nParticipants] frequency matrix.
%      - FREQ.bad_segments : optional shared sample indices to exclude.
%
%  - target_frex : positive target frequency. A scalar is reused for all
%                  participants; a vector assigns one value per participant.
%
%  Optional name-value pairs:
%  - 'metric_levels'    : target-frequency multipliers. Default: 1.
%  - 'component'        : network component. A scalar is reused for all
%                         participants; a vector assigns one component per
%                         participant. Default: component 1 for everyone.
%  - 'duration'         : proportional interval in [0,1]. Default: full.
%  - 'downsample'       : positive integer decimation factor. Default: 1.
%  - 'bad_segments'     : additional shared sample indices to exclude.
%                         These are combined with FREQ.bad_segments.
%  - 'standardize'      : z-score each participant dimension. Default: false.
%  - 'threshold_method' : 'max_fraction' (BROADNESS) or 'fixed_rr'.
%                         Default: 'max_fraction'.
%  - 'threshold'        : fraction of maximum distance, or target RR,
%                         depending on threshold_method. Default: 0.1.
%  - 'theiler_window'   : excluded half-width around identity. Default: 0.
%  - 'lmin'             : minimum diagonal-line length. Default: 2.
%  - 'vmin'             : minimum vertical-line length. Default: 2.
%  - 'store_matrices'   : retain distance/RP matrices. Default: false.
%  - 'figure'           : show phase space, distance matrix, and RP.
%                         Default: false.
%  - 'animate'          : animate phase space for two or three participants.
%                         Default: false.
%  - 'srate'            : sampling rate for time axes. Default: sample index.
%  - 'animation_pause'  : seconds between animation frames. Default: 0.01.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQrqa : structure array, one element per metric level, containing
%              RR, L, DET, ENTR, TT, LAM, Vmax, DIV, PhaseSpace,
%              SelectedFrequencies, SelectedComponents, Threshold, Time,
%              bad-sample coverage, and optional matrices.
%  - figures : handles to phase-space, distance, recurrence, and animation
%              figures.
%
% ------------------------------------------------------------------------
%  EXTERNAL DEPENDENCIES:
% ------------------------------------------------------------------------
%  - dl.m, tt.m, and entropy.m from the included CRP Toolbox subset.
%
% ------------------------------------------------------------------------
%  AUTHORS:
%  Mattia Rosso, Felix Bigand, Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  felix.bigand@iit.it
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
% ========================================================================


%% Handle optional arguments

opts = struct('metric_levels',1,'component',1,'duration',[], ...
    'downsample',1,'bad_segments',[],'standardize',false, ...
    'threshold_method','max_fraction','threshold',0.1, ...
    'theiler_window',0,'lmin',2,'vmin',2,'store_matrices',false, ...
    'figure',false,'animate',false,'srate',[], ...
    'animation_pause',0.01);
opts = parse_name_value_pairs(opts,varargin{:});


%% Validate inputs

if ~isstruct(FREQ) || ~isfield(FREQ,'ts') || isempty(FREQ.ts) || ...
        ~isfield(FREQ,'frex') || isempty(FREQ.frex)
    error('FREQ must contain non-empty FREQ.ts and FREQ.frex fields.');
end
if ~isnumeric(FREQ.ts) || ~isreal(FREQ.ts) || ...
        ndims(FREQ.ts) > 4 || any(~isfinite(FREQ.ts(:)))
    error(['FREQ.ts must be a real finite numeric array in ' ...
        '[nComponents x nTime x nFrex x nParticipants] format.']);
end
ntime_original = size(FREQ.ts,2);

stored_bad_segments = [];
if isfield(FREQ,'bad_segments')
    stored_bad_segments = validate_bad_segments( ...
        FREQ.bad_segments,ntime_original,'FREQ.bad_segments');
end
additional_bad_segments = validate_bad_segments( ...
    opts.bad_segments,ntime_original,'bad_segments');
bad_segments = unique( ...
    [stored_bad_segments additional_bad_segments],'stable');

nsubs = size(FREQ.ts,4);
if nsubs < 2
    error('Phase-space group RQA requires at least two participants.');
end

valid_shared_frex = isvector(FREQ.frex) && ...
    numel(FREQ.frex) == size(FREQ.ts,3);
valid_participant_frex = ismatrix(FREQ.frex) && ...
    isequal(size(FREQ.frex),[size(FREQ.ts,3) nsubs]);
if ~isnumeric(FREQ.frex) || ~isreal(FREQ.frex) || ...
        any(~isfinite(FREQ.frex(:))) || any(FREQ.frex(:) <= 0) || ...
        ~(valid_shared_frex || valid_participant_frex)
    error(['FREQ.frex must be a shared positive frequency vector or an ' ...
        '[nFrex x nParticipants] frequency matrix.']);
end

if ~isnumeric(target_frex) || ~isreal(target_frex) || ...
        ~isvector(target_frex) || isempty(target_frex) || ...
        ~ismember(numel(target_frex),[1 nsubs]) || ...
        any(~isfinite(target_frex)) || ...
        any(target_frex <= 0)
    error(['target_frex must be one positive finite scalar or contain one ' ...
        'positive finite frequency per participant.']);
end
target_frex = reshape(target_frex,1,[]);
if isscalar(target_frex)
    target_frex = repmat(target_frex,1,nsubs);
end

if ~isnumeric(opts.component) || ~isreal(opts.component) || ...
        ~isvector(opts.component) || isempty(opts.component) || ...
        ~ismember(numel(opts.component),[1 nsubs]) || ...
        any(~isfinite(opts.component)) || any(opts.component < 1) || ...
        any(opts.component ~= round(opts.component))
    error(['component must be one positive integer or contain one positive ' ...
        'integer per participant.']);
end
selected_components = reshape(opts.component,1,[]);
if isscalar(selected_components)
    selected_components = repmat(selected_components,1,nsubs);
end
if any(selected_components > size(FREQ.ts,1))
    error('A requested component exceeds the first dimension of FREQ.ts.');
end
validate_positive_vector(opts.metric_levels,'metric_levels')
metric_levels = reshape(opts.metric_levels,1,[]);
validate_duration(opts.duration)
validate_positive_integer(opts.downsample,'downsample')
validate_logical(opts.standardize,'standardize')
validate_threshold(opts.threshold_method,opts.threshold)
validate_nonnegative_integer(opts.theiler_window,'theiler_window')
validate_positive_integer(opts.lmin,'lmin')
validate_positive_integer(opts.vmin,'vmin')
validate_logical(opts.store_matrices,'store_matrices')
validate_logical(opts.figure,'figure')
validate_logical(opts.animate,'animate')
if ~isempty(opts.srate) && (~isnumeric(opts.srate) || ...
        ~isscalar(opts.srate) || ~isfinite(opts.srate) || opts.srate <= 0)
    error('srate must be empty or one positive finite scalar.');
end
if ~isnumeric(opts.animation_pause) || ~isscalar(opts.animation_pause) || ...
        ~isfinite(opts.animation_pause) || opts.animation_pause < 0
    error('animation_pause must be one non-negative finite scalar.');
end

required_dependencies = {'dl','tt','entropy'};
for dependencyi = 1:numel(required_dependencies)
    if exist(required_dependencies{dependencyi},'file') ~= 2
        error('%s.m is required in FREQNESS_ExternalFunctions.', ...
            required_dependencies{dependencyi});
    end
end


%% Select duration and construct time vector

if isempty(opts.duration)
    first_point = 1;
    last_point = ntime_original;
else
    first_point = max(1,round(opts.duration(1)*ntime_original));
    last_point = min(ntime_original,round(opts.duration(2)*ntime_original));
end
sample_indices = first_point:opts.downsample:last_point;
ntime = numel(sample_indices);
if ntime < 3
    error('The selected duration and downsample factor retain fewer than three samples.');
end
if ntime > 10000
    error(['Phase-space RQA would require a distance matrix larger than ' ...
        '10000 x 10000. Increase the downsample factor or shorten duration.']);
end
valid_original = true(1,ntime_original);
valid_original(bad_segments) = false;
valid_sample_mask = valid_original(sample_indices);
if nnz(valid_sample_mask) < 3
    error(['The selected duration and downsample factor retain fewer than ' ...
        'three valid samples after bad_segments exclusion.']);
end

if isempty(opts.srate)
    time = sample_indices;
    time_label = 'Sample';
else
    time = (sample_indices-1)/opts.srate;
    time_label = 'Time (s)';
end


%% Find participant-specific frequencies

nlevels = numel(metric_levels);
idx_frex = zeros(nsubs,nlevels);
selected_frex = zeros(nsubs,nlevels);
for subi = 1:nsubs
    if valid_shared_frex
        this_frex = FREQ.frex(:);
    else
        this_frex = FREQ.frex(:,subi);
    end
    for leveli = 1:nlevels
        requested_frex = target_frex(subi)*metric_levels(leveli);
        [~,idx_frex(subi,leveli)] = min(abs(this_frex-requested_frex));
        selected_frex(subi,leveli) = this_frex(idx_frex(subi,leveli));
    end
end

fprintf(['\nFREQNESS Phase-Space RQA: analysing %d participants across ' ...
    '%d metric levels.\n'],nsubs,nlevels);


%% Initialize outputs

empty_output = struct('RR',[],'L',[],'DET',[],'ENTR',[], ...
    'TT',[],'LAM',[],'Vmax',[],'DIV',[],'PhaseSpace',[], ...
    'SelectedFrequencies',[],'SelectedComponents',[], ...
    'MetricLevel',[],'Threshold',[], ...
    'ThresholdMethod','','ActualRR',[],'Time',[], ...
    'BadSegments',[],'SelectedSampleIndices',[], ...
    'ValidSampleMask',[],'ValidSampleCount',[], ...
    'ExcludedSampleCount',[],'EligiblePairCount',[], ...
    'EligiblePairFraction',[],'DistanceMatrix',[], ...
    'RecurrencePlot',[],'EligiblePairMask',[], ...
    'Method','phase_space','Standardized',opts.standardize);
FREQrqa = repmat(empty_output,1,nlevels);
figures = struct('phase_space',gobjects(0),'distance_matrix',gobjects(0), ...
    'recurrence_plot',gobjects(0),'animation',gobjects(0));


%% Compute group phase-space recurrence

for leveli = 1:nlevels

    % Keep the original time grid: NaN rows exclude bad states without
    % concatenating valid runs across gaps.
    phase_space = nan(ntime,nsubs);
    for subi = 1:nsubs
        selected_ts = squeeze(FREQ.ts(selected_components(subi), ...
            sample_indices,idx_frex(subi,leveli),subi));
        phase_space(valid_sample_mask,subi) = ...
            selected_ts(valid_sample_mask);
    end

    if opts.standardize
        phase_mean = mean(phase_space(valid_sample_mask,:),1);
        phase_sd = std(phase_space(valid_sample_mask,:),0,1);
        if any(phase_sd == 0)
            error(['Cannot standardize metric level %g because at least one ' ...
                'participant time series has zero variance.'],metric_levels(leveli));
        end
        phase_space(valid_sample_mask,:) = ...
            (phase_space(valid_sample_mask,:)-phase_mean)./phase_sd;
    end

    distance_matrix = nan(ntime);
    valid_distance_matrix = euclidean_distance_matrix( ...
        phase_space(valid_sample_mask,:));
    distance_matrix(valid_sample_mask,valid_sample_mask) = ...
        valid_distance_matrix;
    [recurrence_plot,effective_threshold,eligible_pair_mask] = ...
        threshold_distances( ...
        distance_matrix,opts.threshold_method,opts.threshold, ...
        opts.theiler_window,valid_sample_mask);

    RQA = FREQNESS_RQA_Mocap(recurrence_plot,opts.lmin,opts.vmin);
    % Excluded pairs are absent from both numerator and denominator.
    FREQrqa(leveli).RR = sum(recurrence_plot(eligible_pair_mask))/ ...
        nnz(eligible_pair_mask);
    FREQrqa(leveli).L = RQA.l;
    FREQrqa(leveli).DET = RQA.det;
    FREQrqa(leveli).ENTR = RQA.entr;
    FREQrqa(leveli).TT = RQA.tt;
    FREQrqa(leveli).LAM = RQA.lam;
    FREQrqa(leveli).Vmax = RQA.vmax;
    FREQrqa(leveli).DIV = RQA.div;

    FREQrqa(leveli).PhaseSpace = phase_space;
    FREQrqa(leveli).SelectedFrequencies = selected_frex(:,leveli)';
    FREQrqa(leveli).SelectedComponents = selected_components;
    FREQrqa(leveli).MetricLevel = metric_levels(leveli);
    FREQrqa(leveli).Threshold = effective_threshold;
    FREQrqa(leveli).ThresholdMethod = lower(char(opts.threshold_method));
    FREQrqa(leveli).ActualRR = FREQrqa(leveli).RR;
    FREQrqa(leveli).Time = time;
    FREQrqa(leveli).BadSegments = bad_segments;
    FREQrqa(leveli).SelectedSampleIndices = sample_indices;
    FREQrqa(leveli).ValidSampleMask = valid_sample_mask;
    FREQrqa(leveli).ValidSampleCount = nnz(valid_sample_mask);
    FREQrqa(leveli).ExcludedSampleCount = nnz(~valid_sample_mask);
    FREQrqa(leveli).EligiblePairCount = nnz(eligible_pair_mask);
    FREQrqa(leveli).EligiblePairFraction = ...
        nnz(eligible_pair_mask)/numel(eligible_pair_mask);
    if opts.store_matrices
        FREQrqa(leveli).DistanceMatrix = distance_matrix;
        FREQrqa(leveli).RecurrencePlot = recurrence_plot;
        FREQrqa(leveli).EligiblePairMask = eligible_pair_mask;
    end

    if opts.figure
        figures = append_static_figures(figures,phase_space,distance_matrix, ...
            recurrence_plot,time,time_label,metric_levels(leveli), ...
            effective_threshold);
    end

    if opts.animate
        if nsubs <= 3
            fig_animation = animate_phase_space(phase_space,time,time_label, ...
                metric_levels(leveli),opts.animation_pause);
            figures.animation(end+1) = fig_animation;
        else
            warning('FREQNESS:AnimationDimension', ...
                ['Phase-space animation is available only for two or three ' ...
                'participants; static RQA outputs were still computed.']);
        end
    end
end

end


%% Helper function: Euclidean distance matrix
function distance_matrix = euclidean_distance_matrix(phase_space)

squared_norm = sum(phase_space.^2,2);
squared_distance = squared_norm+squared_norm'-2*(phase_space*phase_space');
squared_distance(squared_distance < 0) = 0;
distance_matrix = sqrt(squared_distance);

end


%% Helper function: Threshold distances
function [recurrence_plot,effective_threshold,eligible_pair_mask] = ...
    threshold_distances(distance_matrix,method,threshold,theiler_window, ...
    valid_sample_mask)

method = lower(char(method));
ntime = size(distance_matrix,1);
eligible_pair_mask = valid_sample_mask(:) & valid_sample_mask(:)';
if theiler_window > 0
    [row_idx,column_idx] = ndgrid(1:ntime,1:ntime);
    eligible_pair_mask(abs(row_idx-column_idx) <= theiler_window) = false;
end
if ~any(eligible_pair_mask(:))
    error('No eligible sample pairs remain after exclusions.');
end

switch method
    case 'max_fraction'
        effective_threshold = ...
            max(distance_matrix(eligible_pair_mask))*threshold;
    case 'fixed_rr'
        eligible_upper = triu(eligible_pair_mask,theiler_window+1);
        eligible_distances = sort(distance_matrix(eligible_upper));
        if isempty(eligible_distances)
            error(['No unique eligible sample pairs remain for ' ...
                'fixed_rr threshold estimation.']);
        end
        threshold_index = max(1,min(numel(eligible_distances), ...
            ceil(threshold*numel(eligible_distances))));
        effective_threshold = eligible_distances(threshold_index);
    otherwise
        error('threshold_method must be ''max_fraction'' or ''fixed_rr''.');
end

recurrence_plot = false(ntime);
recurrence_plot(eligible_pair_mask) = ...
    distance_matrix(eligible_pair_mask) < effective_threshold;

end


%% Helper function: Static phase-space and recurrence figures
function figures = append_static_figures(figures,phase_space,distance_matrix, ...
    recurrence_plot,time,time_label,metric_level,effective_threshold)

nsubs = size(phase_space,2);

fig_phase = figure('Color','w','Units','pixels','Position',[100 100 760 650]);
ax_phase = axes('Parent',fig_phase);
hold(ax_phase,'on')
if nsubs == 2
    scatter(ax_phase,phase_space(:,1),phase_space(:,2),28,time,'filled');
    xlabel(ax_phase,'Participant #1 network score','FontWeight','bold')
    ylabel(ax_phase,'Participant #2 network score','FontWeight','bold')
    axis(ax_phase,'square')
elseif nsubs == 3
    scatter3(ax_phase,phase_space(:,1),phase_space(:,2),phase_space(:,3), ...
        28,time,'filled');
    xlabel(ax_phase,'Participant #1 network score','FontWeight','bold')
    ylabel(ax_phase,'Participant #2 network score','FontWeight','bold')
    zlabel(ax_phase,'Participant #3 network score','FontWeight','bold')
    axis(ax_phase,'vis3d'); view(ax_phase,45,25)
else
    imagesc(ax_phase,time,1:nsubs,phase_space')
    xlabel(ax_phase,time_label,'FontWeight','bold')
    ylabel(ax_phase,'Participant','FontWeight','bold')
    yticks(ax_phase,1:nsubs)
end
title(ax_phase,sprintf('Group phase space | Metric level = %g',metric_level), ...
    'FontSize',15,'FontWeight','bold')
colormap(ax_phase,jet(256))
cb = colorbar(ax_phase);
if nsubs <= 3
    cb.Label.String = time_label;
    tick_indices = unique(round(linspace(1,numel(time),min(8,numel(time)))));
    if time(end) > time(1)
        clim(ax_phase,[time(1) time(end)])
    end
    cb.Ticks = time(tick_indices);
    cb.TickLabels = compose('%.3g',time(tick_indices));
else
    cb.Label.String = 'Standardized network score';
end
format_axes(ax_phase)
figures.phase_space(end+1) = fig_phase;

fig_distance = figure('Color','w','Units','pixels','Position',[130 130 700 620]);
ax_distance = axes('Parent',fig_distance);
imagesc(ax_distance,time,time,distance_matrix)
axis(ax_distance,'square')
set(ax_distance,'YDir','normal')
xlabel(ax_distance,time_label,'FontWeight','bold')
ylabel(ax_distance,time_label,'FontWeight','bold')
title(ax_distance,sprintf('Phase-space distance matrix | Metric level = %g', ...
    metric_level),'FontSize',15,'FontWeight','bold')
colormap(ax_distance,flipud(parula(256)))
cb = colorbar(ax_distance);
cb.Label.String = 'Euclidean distance';
format_axes(ax_distance)
figures.distance_matrix(end+1) = fig_distance;

fig_recurrence = figure('Color','w','Units','pixels','Position',[160 160 700 620]);
ax_recurrence = axes('Parent',fig_recurrence);
imagesc(ax_recurrence,time,time,recurrence_plot)
axis(ax_recurrence,'square')
set(ax_recurrence,'YDir','normal')
xlabel(ax_recurrence,time_label,'FontWeight','bold')
ylabel(ax_recurrence,time_label,'FontWeight','bold')
title(ax_recurrence,sprintf(['Recurrence plot | Metric level = %g | ' ...
    'threshold = %.3g'],metric_level,effective_threshold), ...
    'FontSize',15,'FontWeight','bold')
colormap(ax_recurrence,[1 1 1; 0.10 0.32 0.65])
clim(ax_recurrence,[0 1])
format_axes(ax_recurrence)
figures.recurrence_plot(end+1) = fig_recurrence;

end


%% Helper function: Animate 2D/3D group phase space
function fig = animate_phase_space(phase_space,time,time_label, ...
    metric_level,animation_pause)

nsubs = size(phase_space,2);
nframes = size(phase_space,1);
cmap = jet(nframes);
fig = figure('Color','w','Units','pixels','Position',[180 100 760 650], ...
    'Name','FREQNESS group phase-space animation','NumberTitle','off');
ax = axes('Parent',fig);
hold(ax,'on')

if nsubs == 2
    xlim(ax,[min(phase_space(:,1),[],'omitnan') ...
        max(phase_space(:,1),[],'omitnan')])
    ylim(ax,[min(phase_space(:,2),[],'omitnan') ...
        max(phase_space(:,2),[],'omitnan')])
    xlabel(ax,'Participant #1 network score','FontWeight','bold')
    ylabel(ax,'Participant #2 network score','FontWeight','bold')
    axis(ax,'square')
else
    xlim(ax,[min(phase_space(:,1),[],'omitnan') ...
        max(phase_space(:,1),[],'omitnan')])
    ylim(ax,[min(phase_space(:,2),[],'omitnan') ...
        max(phase_space(:,2),[],'omitnan')])
    zlim(ax,[min(phase_space(:,3),[],'omitnan') ...
        max(phase_space(:,3),[],'omitnan')])
    xlabel(ax,'Participant #1 network score','FontWeight','bold')
    ylabel(ax,'Participant #2 network score','FontWeight','bold')
    zlabel(ax,'Participant #3 network score','FontWeight','bold')
    axis(ax,'vis3d'); view(ax,45,25)
end
title(ax,sprintf('Group phase-space animation | Metric level = %g',metric_level), ...
    'FontSize',15,'FontWeight','bold')
format_axes(ax)

frame_step = max(1,ceil(nframes/1000));
for framei = 1:frame_step:nframes
    if ~isgraphics(fig)
        break
    end
    if nsubs == 2
        scatter(ax,phase_space(framei,1),phase_space(framei,2), ...
            34,cmap(framei,:),'filled')
    else
        scatter3(ax,phase_space(framei,1),phase_space(framei,2), ...
            phase_space(framei,3),34,cmap(framei,:),'filled')
    end
    title(ax,sprintf(['Group phase-space animation | Metric level = %g | ' ...
        '%s = %.3g'],metric_level,time_label,time(framei)), ...
        'FontSize',15,'FontWeight','bold')
    drawnow
    pause(animation_pause)
end

end


%% Helper function: Format axes
function format_axes(ax)
grid(ax,'on'); grid(ax,'minor'); box(ax,'on')
set(ax,'FontSize',12,'LineWidth',1.2, ...
    'GridAlpha',0.18,'MinorGridAlpha',0.10)
end


%% Validation helpers
function bad_segments = validate_bad_segments(value,ntime,name)
if isempty(value)
    bad_segments = zeros(1,0);
    return
end
if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
        any(~isfinite(value)) || any(value ~= round(value))
    error('%s must contain finite integer sample indices.',name);
end
bad_segments = unique(value(:)','stable');
if any(bad_segments < 1) || any(bad_segments > ntime)
    error('%s contains indices outside FREQ.ts.',name);
end
end


function validate_positive_integer(value,name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 1 || value ~= round(value)
    error('%s must be one positive integer.',name);
end
end


function validate_nonnegative_integer(value,name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 0 || value ~= round(value)
    error('%s must be one non-negative integer.',name);
end
end


function validate_positive_vector(value,name)
if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
        isempty(value) || any(~isfinite(value)) || any(value <= 0)
    error('%s must be a non-empty vector of positive finite values.',name);
end
end


function validate_duration(duration)
if ~isempty(duration) && (~isnumeric(duration) || ~isreal(duration) || ...
        numel(duration) ~= 2 || any(~isfinite(duration)) || ...
        duration(1) < 0 || duration(2) > 1 || duration(1) >= duration(2))
    error('duration must be empty or an increasing two-element interval in [0,1].');
end
end


function validate_logical(value,name)
if ~islogical(value) || ~isscalar(value)
    error('%s must be one logical value.',name);
end
end


function validate_threshold(method,threshold)
if ~(ischar(method) || (isstring(method) && isscalar(method))) || ...
        ~ismember(lower(string(method)),["max_fraction","fixed_rr"])
    error('threshold_method must be ''max_fraction'' or ''fixed_rr''.');
end
if ~isnumeric(threshold) || ~isscalar(threshold) || ...
        ~isfinite(threshold) || threshold <= 0 || threshold >= 1
    error('threshold must be one finite scalar in the open interval (0,1).');
end
end


%% Helper function: Parse name-value pairs
function opts = parse_name_value_pairs(opts,varargin)
if mod(length(varargin),2) ~= 0
    error('Arguments must be given as name-value pairs.');
end
for argi = 1:2:length(varargin)
    if ~(ischar(varargin{argi}) || ...
            (isstring(varargin{argi}) && isscalar(varargin{argi})))
        error('Optional argument names must be text.');
    end
    name = lower(char(varargin{argi}));
    if isfield(opts,name)
        opts.(name) = varargin{argi+1};
    else
        error(['Unrecognized argument: ' name]);
    end
end
end
