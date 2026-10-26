function figures = FREQNESS_Visualizer_Mocap(FREQ,Landscape,Patterns,varargin)

% ========================================================================
%  FREQNESS VISUALIZER: BODILY NETWORK LANDSCAPE & ACTIVATION PATTERNS
%
%  This function mirrors the organization of the MEEG FREQNESS visualizer
%  while retaining MoCap-specific outputs: labelled XYZ patterns, static
%  skeletal projections, and synchronized movement animations.
%
%  If multiple participants are provided, the landscape is shown as a
%  grand average with shaded SEM. Set 'plot_all' to true to additionally
%  show individual landscapes. Static patterns overlay the participants in
%  their common acquisition space and use one normalization across them.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ.evals : normalized eigenspectrum
%                [nEigenvalues x nFrex x (nParticipants)]
%  - FREQ.pats  : spatial activation patterns
%                [nChannels x nComponents x nFrex x (nParticipants)]
%  - FREQ.ts    : component time series, required only for animation
%  - FREQ.method : optional GED/PCA provenance for landscape labels.
%  - FREQ.kinematics : velocity outputs support static plots, not positional
%                     animation (no implicit integration is performed).
%  - FREQ.frex  : analyzed frequencies
%
%  - Landscape.frex   : frequencies to visualize
%  - Landscape.ncomps : number of components to visualize
%
%    Optional Landscape fields:
%  - Landscape.sem    : externally computed SEM [nComponents x nFrex]
%  - Landscape.xlabel : x-axis label (default: 'Frequency (Hz)')
%  - Landscape.title  : figure title
%
%  - Patterns.frex       : frequencies to visualize
%  - Patterns.labels     : one label per XYZ marker triplet
%  - Patterns.markerData : motion data [nChannels x nTime x nParticipants]
%  - Patterns.comp       : component to visualize
%  - Patterns.srate      : original sampling rate
%  - Patterns.start      : animation starting point in [0,1]
%
%    Optional Patterns fields:
%  - Patterns.bones              : marker links [nLinks x 2]
%  - Patterns.plot_bones         : show marker links (default: true)
%  - Patterns.animate            : true/false; if absent, ask interactively
%  - Patterns.plot_matrix        : show labelled XYZ matrices (default: true)
%  - Patterns.animation_duration : maximum displayed seconds (default: Inf)
%  - Patterns.frequency_unit     : frequency suffix (default: 'Hz')
%
%  Optional name-value pair:
%  - 'plot_all' : additionally plot every participant's landscape.
%                 Default: false.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENT:
% ------------------------------------------------------------------------
%  - figures : structure containing handles to the generated figures.
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
% ========================================================================


%% Handle optional arguments

if nargin < 3
    Patterns = [];
end

opts = struct('plot_all',false);
opts = parse_name_value_pairs(opts,varargin{:});
plot_all = opts.plot_all;

if ~islogical(plot_all) || ~isscalar(plot_all)
    error('plot_all must be one logical value (true or false).');
end

figures = struct('landscape',gobjects(0),'pattern_matrix',gobjects(0), ...
    'patterns',gobjects(0),'animation',gobjects(0));


%% Check FREQ and Landscape inputs

if ~isstruct(FREQ) || ~(isstruct(Landscape) || isempty(Landscape))
    error('FREQ must be a structure; Landscape must be a structure or [].');
end

required_ged_fields = {'evals','frex'};
for fieldi = 1:numel(required_ged_fields)
    if ~isfield(FREQ,required_ged_fields{fieldi}) || ...
            isempty(FREQ.(required_ged_fields{fieldi}))
        error('FREQ.%s is missing or empty.',required_ged_fields{fieldi});
    end
end

if ~isnumeric(FREQ.evals) || ~isreal(FREQ.evals) || ...
        ndims(FREQ.evals) > 3 || any(~isfinite(FREQ.evals(:)))
    error(['FREQ.evals must be a real finite numeric array in ' ...
        '[nEigenvalues x nFrex x (nParticipants)] format.']);
end

frex = FREQ.frex(:)';
if ~isnumeric(frex) || ~isreal(frex) || isempty(frex) || ...
        any(~isfinite(frex)) || any(frex <= 0)
    error('FREQ.frex must contain positive finite frequencies.');
end
if size(FREQ.evals,2) ~= numel(frex)
    error('The frequency dimension of FREQ.evals does not match FREQ.frex.');
end

if ~isempty(Landscape)

if ~isfield(Landscape,'frex') || ~isfield(Landscape,'ncomps')
    error('Landscape must contain the fields frex and ncomps.');
end

landscape_frex = validate_frequency_vector(Landscape.frex,'Landscape.frex');
landscape_ncomps = validate_component_number( ...
    Landscape.ncomps,'Landscape.ncomps');
if landscape_ncomps > size(FREQ.evals,1)
    error('Landscape.ncomps exceeds the number of estimated networks.');
end

[idx_landscape,landscape_frex_actual] = map_frequencies( ...
    frex,landscape_frex,'Landscape');
nsubs_landscape = size(FREQ.evals,3);

if isfield(Landscape,'xlabel') && ~isempty(Landscape.xlabel)
    landscape_xlabel = char(Landscape.xlabel);
else
    landscape_xlabel = 'Frequency (Hz)';
end
if isfield(Landscape,'title') && ~isempty(Landscape.title)
    landscape_title = char(Landscape.title);
else
    landscape_title = 'Bodily network landscape';
end

external_sem = [];
if isfield(Landscape,'sem') && ~isempty(Landscape.sem)
    external_sem = Landscape.sem;
    if ~isnumeric(external_sem) || ~isreal(external_sem) || ...
            size(external_sem,1) < landscape_ncomps || ...
            size(external_sem,2) ~= numel(frex) || ...
            any(~isfinite(external_sem(:))) || any(external_sem(:) < 0)
        error(['Landscape.sem must be a non-negative finite array in ' ...
            '[nComponents x nFrex] format.']);
    end
end

fprintf('\nFREQNESS Visualizer: visualizing %d participants.\n', ...
    nsubs_landscape);


%% Output #1: Network landscape

colors = component_colors(landscape_ncomps);
method_label = 'FREQ';
landscape_ylabel = 'Relative eigenvalue contribution (%)';
if isfield(FREQ,'method') && strcmpi(FREQ.method,'pca')
    method_label = 'PCA';
    landscape_ylabel = 'Narrowband variance (%)';
elseif isfield(FREQ,'method') && strcmpi(FREQ.method,'ged')
    method_label = 'GED';
end

if plot_all || nsubs_landscape == 1
    for subi = 1:nsubs_landscape
        this_evals = squeeze(FREQ.evals(1:landscape_ncomps, ...
            idx_landscape,subi));
        if landscape_ncomps == 1
            this_evals = reshape(this_evals,1,[]);
        end

        this_sem = [];
        if nsubs_landscape == 1 && ~isempty(external_sem)
            this_sem = external_sem(1:landscape_ncomps,idx_landscape);
        end

        if nsubs_landscape == 1
            this_title = landscape_title;
        else
            this_title = sprintf('%s - Participant #%d', ...
                landscape_title,subi);
        end

        fig = plot_network_landscape(landscape_frex_actual,this_evals, ...
            this_sem,colors,landscape_xlabel,this_title,method_label,landscape_ylabel);
        figures.landscape(end+1) = fig;
    end
end

if nsubs_landscape > 1
    all_evals = FREQ.evals(1:landscape_ncomps,idx_landscape,:);
    avg_evals = mean(all_evals,3,'omitnan');
    sem_evals = std(all_evals,0,3,'omitnan')/sqrt(nsubs_landscape);
    fig = plot_network_landscape(landscape_frex_actual,avg_evals, ...
        sem_evals,colors,landscape_xlabel, ...
        [landscape_title ' - Grand average'],method_label,landscape_ylabel);
    figures.landscape(end+1) = fig;
end

end

if isempty(Patterns)
    return
end


%% Check Patterns inputs

if ~isstruct(Patterns)
    error('Patterns must be a structure or an empty array.');
end

required_pattern_fields = {'frex','labels','markerData','comp','srate','start'};
for fieldi = 1:numel(required_pattern_fields)
    if ~isfield(Patterns,required_pattern_fields{fieldi}) || ...
            isempty(Patterns.(required_pattern_fields{fieldi}))
        error('Patterns.%s is missing or empty.',required_pattern_fields{fieldi});
    end
end

if ~isfield(FREQ,'pats') || isempty(FREQ.pats) || ...
        ~isnumeric(FREQ.pats) || ~isreal(FREQ.pats) || ...
        ndims(FREQ.pats) > 4 || any(isinf(FREQ.pats(:)))
    error(['FREQ.pats must be a real numeric array in ' ...
        '[nChannels x nComponents x nFrex x (nParticipants)] format.']);
end
if size(FREQ.pats,3) ~= numel(frex)
    error('The frequency dimension of FREQ.pats does not match FREQ.frex.');
end

if ~isnumeric(Patterns.srate) || ~isscalar(Patterns.srate) || ...
        ~isfinite(Patterns.srate) || Patterns.srate <= 0
    error('Patterns.srate must be one positive finite scalar.');
end

markData = Patterns.markerData;
if ~isnumeric(markData) || ~isreal(markData) || ndims(markData) > 3 || ...
        any(isinf(markData(:)))
    error(['Patterns.markerData must be a real numeric array without Inf ' ...
        'values in [nChannels x nTime x (nParticipants)] format.']);
end
if isfield(FREQ,'ts') && ~isempty(FREQ.ts)
    markData = markData(:,1:min(size(markData,2),size(FREQ.ts,2)),:);
end
if any(isnan(markData),'all')
    maximum_interpolated_gap = 0.05;
    maximum_reconstructed_gap = [];
    if isfield(FREQ,'gap_info') && isstruct(FREQ.gap_info)
        if isfield(FREQ.gap_info,'maximum_interpolated_gap_seconds')
            maximum_interpolated_gap = ...
                FREQ.gap_info.maximum_interpolated_gap_seconds;
        end
        if isfield(FREQ.gap_info,'maximum_reconstructed_gap_seconds')
            maximum_reconstructed_gap = ...
                FREQ.gap_info.maximum_reconstructed_gap_seconds;
        end
    end
    markData = FREQNESS_InterpolateGaps_Mocap( ...
        markData,Patterns.srate, ...
        'maximum_interpolated_gap',maximum_interpolated_gap, ...
        'maximum_reconstructed_gap',maximum_reconstructed_gap);
end

nchannels = size(markData,1);
if mod(nchannels,3) ~= 0 || size(FREQ.pats,1) ~= nchannels
    error(['Motion data must contain XYZ triplets, and FREQ.pats must have ' ...
        'one row per motion-data channel.']);
end
nmarkers = nchannels/3;

if numel(Patterns.labels) ~= nmarkers
    error('Patterns.labels must contain one label per XYZ marker triplet.');
end

pattern_frex = validate_frequency_vector(Patterns.frex,'Patterns.frex');
pattern_comp = validate_component_number(Patterns.comp,'Patterns.comp');
if pattern_comp > size(FREQ.pats,2)
    error('Patterns.comp exceeds the number of estimated networks.');
end
[idx_patterns,pattern_frex_actual] = map_frequencies( ...
    frex,pattern_frex,'Patterns');

nsubs_patterns = size(FREQ.pats,4);
if size(markData,3) ~= nsubs_patterns
    error('FREQ.pats and Patterns.markerData contain different participant counts.');
end

if ~isnumeric(Patterns.start) || ~isscalar(Patterns.start) || ...
        ~isfinite(Patterns.start) || Patterns.start < 0 || Patterns.start > 1
    error('Patterns.start must be one finite scalar in [0,1].');
end

if isfield(Patterns,'plot_matrix') && ~isempty(Patterns.plot_matrix)
    plot_matrix = Patterns.plot_matrix;
else
    plot_matrix = true;
end
if ~islogical(plot_matrix) || ~isscalar(plot_matrix)
    error('Patterns.plot_matrix must be one logical value.');
end

if isfield(Patterns,'frequency_unit') && ~isempty(Patterns.frequency_unit)
    frequency_unit = char(Patterns.frequency_unit);
else
    frequency_unit = 'Hz';
end

if isfield(Patterns,'plot_bones') && ~isempty(Patterns.plot_bones)
    plot_bones = Patterns.plot_bones;
else
    plot_bones = true;
end
if ~islogical(plot_bones) || ~isscalar(plot_bones)
    error('Patterns.plot_bones must be one logical value.');
end
if plot_bones
    if isfield(Patterns,'bones') && ~isempty(Patterns.bones)
        bones = Patterns.bones;
    else
        bones = default_bones(nmarkers);
    end
else
    bones = zeros(0,2);
end
validate_bones(bones,nmarkers)

x_idx = 1:3:nchannels-2;
y_idx = 2:3:nchannels-1;
z_idx = 3:3:nchannels;


%% Output #2: Bodily spatial activation patterns

for freqi = 1:numel(idx_patterns)
    this_frex = pattern_frex_actual(freqi);
    this_pats = squeeze(FREQ.pats(:,pattern_comp,idx_patterns(freqi),:));
    if nsubs_patterns == 1
        this_pats = reshape(this_pats,nchannels,1);
    end

    if plot_matrix
        fig = plot_pattern_matrix(this_pats,Patterns.labels,x_idx,y_idx,z_idx, ...
            this_frex,frequency_unit,pattern_comp);
        figures.pattern_matrix(end+1) = fig;
    end

    fig = plot_static_patterns(this_pats,markData,x_idx,y_idx,z_idx, ...
        bones,this_frex,frequency_unit,pattern_comp);
    figures.patterns(end+1) = fig;
end


%% Output #3: Bodily spatial activation-pattern animation

if isfield(Patterns,'animate') && ~isempty(Patterns.animate)
    animate_flag = Patterns.animate;
else
    animate_flag = logical(input(['Please inspect the static representation ' ...
        'of the motion patterns. Visualize the animation? (0 or 1): ']));
end
if ~islogical(animate_flag) || ~isscalar(animate_flag)
    error('Patterns.animate must be one logical value (true or false).');
end

if animate_flag
    if isfield(FREQ,'kinematics') && strcmpi(FREQ.kinematics,'velocity')
        error('FREQNESS:Visualizer:VelocityAnimation', ...
            ['Velocity-derived components cannot be animated as positions. ' ...
            'Use Patterns.animate=false for static visualization.']);
    end
    if numel(idx_patterns) > 1
        error(['The animation supports one frequency at a time. Disable ' ...
            'animation or provide one frequency in Patterns.frex.']);
    end
    if ~isfield(FREQ,'ts') || isempty(FREQ.ts)
        error('FREQ.ts is required when Patterns.animate is true.');
    end

    if isfield(Patterns,'animation_duration') && ...
            ~isempty(Patterns.animation_duration)
        animation_duration = Patterns.animation_duration;
    else
        animation_duration = Inf;
    end
    if ~isnumeric(animation_duration) || ~isscalar(animation_duration) || ...
            animation_duration <= 0 || isnan(animation_duration)
        error('Patterns.animation_duration must be one positive scalar.');
    end

    figures.animation = plot_motion_animation(FREQ,markData, ...
        idx_patterns(1),pattern_comp,Patterns.srate,Patterns.start, ...
        animation_duration,x_idx,y_idx,z_idx,bones, ...
        pattern_frex_actual(1),frequency_unit);
end

end


%% Helper function: Plot a network landscape
function fig = plot_network_landscape(frex,evals,sem,colors,xlabel_text,title_text, ...
    method_label,ylabel_text)

ncomps = size(evals,1);
npoints = 200;

if numel(frex) > 1
    x_uniform = 2.^linspace(log2(min(frex)),log2(max(frex)),npoints);
else
    x_uniform = frex;
end
x_plot = log2(x_uniform);

fig = figure('Color','w','Units','pixels');
if ~strcmp(fig.WindowStyle,'docked')
    fig.Position = [120 120 880 590];
end
ax = axes('Parent',fig);
hold(ax,'on')
line_handles = gobjects(ncomps,1);
upper_limit = 0;

for compi = 1:ncomps
    y = reshape(evals(compi,:),1,[]);
    if numel(frex) > 1
        y = interp1(frex,y,x_uniform,'linear','extrap');
    end

    if ~isempty(sem)
        se = reshape(sem(compi,:),1,[]);
        if numel(frex) > 1
            se = interp1(frex,se,x_uniform,'linear','extrap');
        end
        fill(ax,[x_plot fliplr(x_plot)], ...
            [y-se fliplr(y+se)],colors(compi,:), ...
            'FaceAlpha',0.22,'EdgeColor','none','HandleVisibility','off');
        upper_limit = max(upper_limit,max(y+se,[],'omitnan'));
    else
        upper_limit = max(upper_limit,max(y,[],'omitnan'));
    end

    line_handles(compi) = plot(ax,x_plot,y,'Color',colors(compi,:), ...
        'LineWidth',2.5,'DisplayName',sprintf('%s #%d',method_label,compi));
end

set_log2_frequency_axis(ax,x_uniform)
if upper_limit <= 0 || ~isfinite(upper_limit)
    upper_limit = 1;
end
ylim(ax,[0 min(100,max(10,ceil(1.1*upper_limit/10)*10))])
xlabel(ax,xlabel_text,'FontSize',14,'FontWeight','bold');
ylabel(ax,ylabel_text,'FontSize',14,'FontWeight','bold');
title(ax,title_text,'FontSize',16,'FontWeight','bold');
legend(ax,line_handles,'Location','northeast','FontSize',11);
format_figure_axes(ax)

end


%% Helper function: Plot labelled XYZ pattern matrices
function fig = plot_pattern_matrix(patterns,labels,x_idx,y_idx,z_idx, ...
    frex,frequency_unit,component)

nsubs = size(patterns,2);
max_abs = max(abs(patterns(:)),[],'omitnan');
if max_abs <= 0 || ~isfinite(max_abs)
    max_abs = 1;
end

fig = figure('Color','w','Units','pixels');
if ~strcmp(fig.WindowStyle,'docked')
    fig.Position = [80 80 1050 max(430,250*nsubs)];
end
layout = tiledlayout(fig,nsubs,3,'TileSpacing','compact','Padding','compact');
dimensions = {x_idx,y_idx,z_idx};
dimension_labels = {'X','Y','Z'};

for subi = 1:nsubs
    for dimi = 1:3
        ax = nexttile(layout);
        imagesc(ax,patterns(dimensions{dimi},subi));
        clim(ax,[-max_abs max_abs])
        xticks(ax,[])
        yticks(ax,1:numel(labels))
        yticklabels(ax,labels)
        if dimi > 1
            yticklabels(ax,[])
        end
        title(ax,sprintf('Participant #%d - %s',subi,dimension_labels{dimi}), ...
            'FontWeight','bold')
        set(ax,'FontSize',10,'LineWidth',1,'Box','on')
    end
end

colormap(fig,.95*jet(1000))
cb = colorbar(ax);
cb.Layout.Tile = 'east';
cb.Label.String = 'Activation weight';
cb.Label.FontWeight = 'bold';
title(layout,sprintf(['Labelled activation patterns | Component #%d | ' ...
    'Frequency = %.3g %s'],component,frex,frequency_unit), ...
    'FontSize',15,'FontWeight','bold')

end


%% Helper function: Plot static skeletal activation patterns
function fig = plot_static_patterns(patterns,markData,x_idx,y_idx,z_idx, ...
    bones,frex,frequency_unit,component)

nsubs = size(patterns,2);
valid_patterns = patterns(isfinite(patterns));
if isempty(valid_patterns)
    global_max = 1;
else
    % Retain the Figure 2 normalization: one positive maximum across all
    % markers and participants at the selected component and frequency.
    global_max = max(valid_patterns);
    if global_max <= 0
        global_max = max(abs(valid_patterns));
        if global_max == 0
            global_max = 1;
        end
    end
end
patterns = patterns/global_max;

fig = figure('Color','w','Units','pixels');
if ~strcmp(fig.WindowStyle,'docked')
    fig.Position = [50 90 1460 570];
end
axes_handles = gobjects(3,1);
axis_titles = {'X-axis activation','Y-axis activation','Z-axis activation'};
axis_indices = {x_idx,y_idx,z_idx};
cmap = .95*jet(1000);

for dimi = 1:3
    axes_handles(dimi) = subplot(3,3,(dimi-1)*3+dimi,'Parent',fig);
    ax = axes_handles(dimi);
    hold(ax,'on')

    for subi = 1:nsubs
        x_pos = markData(x_idx,1,subi);
        y_pos = markData(y_idx,1,subi);
        z_pos = markData(z_idx,1,subi);
        activation = patterns(axis_indices{dimi},subi);

        scatter3(ax,x_pos,y_pos,z_pos,95,activation,'filled', ...
            'MarkerEdgeColor','k','LineWidth',0.6);
        plot_bones(ax,x_pos,y_pos,z_pos,bones,[0 0 0],2.6)
    end

    format_skeleton_axes(ax,markData,x_idx,y_idx,z_idx)
    title(ax,axis_titles{dimi},'FontSize',13,'FontWeight','bold')
    colormap(ax,cmap)
    clim(ax,[-1 1])
end

cb = colorbar(axes_handles(3));
cb.Position = [0.945 0.16 0.014 0.68];
cb.Label.String = 'Normalized activation';
cb.Label.FontWeight = 'bold';
cb.FontSize = 10;
sgtitle(fig,sprintf(['Bodily activation pattern | Component #%d | ' ...
    'Frequency = %.3g %s'],component,frex,frequency_unit), ...
    'FontSize',16,'FontWeight','bold')

end


%% Helper function: Animate component backprojection and original motion
function fig = plot_motion_animation(FREQ,markData,frequency_index,component, ...
    srate,start_fraction,duration,x_idx,y_idx,z_idx,bones,frex,frequency_unit)

nsubs = size(markData,3);
npnts = min(size(markData,2),size(FREQ.ts,2));
booster = 10;

xData = markData(x_idx,1:npnts,:);
yData = markData(y_idx,1:npnts,:);
zData = markData(z_idx,1:npnts,:);
ts2plot = zeros(npnts,nsubs);
x_component = zeros(numel(x_idx),npnts,nsubs);
y_component = zeros(numel(y_idx),npnts,nsubs);
z_component = zeros(numel(z_idx),npnts,nsubs);

for subi = 1:nsubs
    this_ts = squeeze(FREQ.ts(component,1:npnts,frequency_index,subi));
    this_ts = booster*(this_ts(:)-mean(this_ts,'omitnan'));
    ts2plot(:,subi) = this_ts;
    remeaner = mean(markData(:,1:npnts,subi),2,'omitnan');

    x_component(:,:,subi) = ...
        FREQ.pats(x_idx,component,frequency_index,subi)*this_ts' + remeaner(x_idx);
    y_component(:,:,subi) = ...
        FREQ.pats(y_idx,component,frequency_index,subi)*this_ts' + remeaner(y_idx);
    z_component(:,:,subi) = ...
        FREQ.pats(z_idx,component,frequency_index,subi)*this_ts' + remeaner(z_idx);
end

dwn = max(1,10+5*nsubs);
sample_idx = 1:dwn:npnts;
ts2plot = ts2plot(sample_idx,:);
x_component = x_component(:,sample_idx,:);
y_component = y_component(:,sample_idx,:);
z_component = z_component(:,sample_idx,:);
xData = xData(:,sample_idx,:);
yData = yData(:,sample_idx,:);
zData = zData(:,sample_idx,:);

srate_animation = srate/dwn;
tvec = (0:numel(sample_idx)-1)/srate_animation;
idx_start = max(1,min(numel(tvec),round(start_fraction*numel(tvec))+1));
if isfinite(duration)
    idx_end = min(numel(tvec),idx_start+round(duration*srate_animation)-1);
else
    idx_end = numel(tvec);
end

participant_colors = participant_colormap(nsubs);
fig = figure('Color','w','Units','pixels', ...
    'Name','FREQNESS MoCap animation','NumberTitle','off');
if ~strcmp(fig.WindowStyle,'docked')
    fig.Position = [70 70 1280 780];
end
layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
ax_time = nexttile(layout,[1 2]);
ax_component = nexttile(layout);
ax_original = nexttile(layout);
hold(ax_time,'on'); hold(ax_component,'on'); hold(ax_original,'on')

cursor_handles = gobjects(nsubs,1);
component_markers = gobjects(nsubs,1);
original_markers = gobjects(nsubs,1);
component_bones = cell(nsubs,1);
original_bones = cell(nsubs,1);

for subi = 1:nsubs
    plot(ax_time,tvec,ts2plot(:,subi),'Color',participant_colors(subi,:), ...
        'LineWidth',2,'DisplayName',sprintf('Participant #%d',subi));
    cursor_handles(subi) = plot(ax_time,tvec(idx_start),ts2plot(idx_start,subi), ...
        'o','MarkerSize',9,'MarkerFaceColor',participant_colors(subi,:), ...
        'MarkerEdgeColor','k','LineWidth',0.6,'HandleVisibility','off');

    component_markers(subi) = scatter3(ax_component, ...
        x_component(:,idx_start,subi),y_component(:,idx_start,subi), ...
        z_component(:,idx_start,subi),95,participant_colors(subi,:),'filled', ...
        'MarkerEdgeColor','k','LineWidth',0.6);
    original_markers(subi) = scatter3(ax_original, ...
        xData(:,idx_start,subi),yData(:,idx_start,subi),zData(:,idx_start,subi), ...
        95,participant_colors(subi,:),'filled', ...
        'MarkerEdgeColor','k','LineWidth',0.6);

    component_bones{subi} = initialize_bones(ax_component, ...
        x_component(:,idx_start,subi),y_component(:,idx_start,subi), ...
        z_component(:,idx_start,subi),bones);
    original_bones{subi} = initialize_bones(ax_original, ...
        xData(:,idx_start,subi),yData(:,idx_start,subi), ...
        zData(:,idx_start,subi),bones);
end

xlabel(ax_time,'Time (s)','FontWeight','bold')
ylabel(ax_time,'Component scores (a.u.)','FontWeight','bold')
title(ax_time,sprintf('Component #%d activation at %.3g %s', ...
    component,frex,frequency_unit),'FontSize',14,'FontWeight','bold')
legend(ax_time,'Location','northeastoutside')
format_figure_axes(ax_time)

format_skeleton_axes(ax_component,markData,x_idx,y_idx,z_idx)
format_skeleton_axes(ax_original,markData,x_idx,y_idx,z_idx)
title(ax_component,'Component backprojection','FontSize',13,'FontWeight','bold')
title(ax_original,'Original movement','FontSize',13,'FontWeight','bold')

for timei = idx_start:idx_end
    if ~isgraphics(fig)
        break
    end
    for subi = 1:nsubs
        set(cursor_handles(subi),'XData',tvec(timei), ...
            'YData',ts2plot(timei,subi));
        set(component_markers(subi), ...
            'XData',x_component(:,timei,subi), ...
            'YData',y_component(:,timei,subi), ...
            'ZData',z_component(:,timei,subi));
        set(original_markers(subi), ...
            'XData',xData(:,timei,subi), ...
            'YData',yData(:,timei,subi), ...
            'ZData',zData(:,timei,subi));
        update_bones(component_bones{subi},x_component(:,timei,subi), ...
            y_component(:,timei,subi),z_component(:,timei,subi),bones)
        update_bones(original_bones{subi},xData(:,timei,subi), ...
            yData(:,timei,subi),zData(:,timei,subi),bones)
    end
    drawnow
    pause(0.03)
end

end


%% Helper function: Figure 2 component colors
function colors = component_colors(ncolors)

reference_colors = [0.90 0.22 0.16; ...
                    0.36 0.69 0.88; ...
                    0.22 0.45 0.78; ...
                    0.12 0.25 0.55];
if ncolors <= size(reference_colors,1)
    colors = reference_colors(1:ncolors,:);
else
    colors = [reference_colors; .8*parula(ncolors-size(reference_colors,1))];
end

end


%% Helper function: Distinct participant colors for animation
function colors = participant_colormap(nsubs)

colors = lines(max(nsubs,2));
colors(1,:) = [0 0 1];
colors(2,:) = [1 0 0];
colors = colors(1:nsubs,:);

end


%% Helper function: Format frequency axis in log2 space
function set_log2_frequency_axis(ax,frex)

if isscalar(frex)
    padding = 0.5;
    xlim(ax,[log2(frex)-padding log2(frex)+padding])
    xticks(ax,log2(frex))
    xticklabels(ax,string(frex))
    return
end

octave_set = 2.^(-6:8);
octave_values = octave_set(octave_set >= min(frex) & octave_set <= max(frex));
if numel(octave_values) >= 2
    xticks(ax,log2(octave_values))
    xticklabels(ax,string(octave_values))
end
xlim(ax,[log2(min(frex)) log2(max(frex))])
xtickangle(ax,45)

end


%% Helper function: Shared axes aesthetics
function format_figure_axes(ax)

grid(ax,'on')
grid(ax,'minor')
box(ax,'on')
set(ax,'FontSize',12,'LineWidth',1.2, ...
    'GridAlpha',0.18,'MinorGridAlpha',0.10)

end


%% Helper function: Shared skeletal axes aesthetics
function format_skeleton_axes(ax,markData,x_idx,y_idx,z_idx)

x_values = markData(x_idx,:,:);
y_values = markData(y_idx,:,:);
z_values = markData(z_idx,:,:);
xy_values = [x_values(:); y_values(:)];
xy_padding = max(range(xy_values)*0.04,eps);
z_padding = max(range(z_values(:))*0.04,eps);

xlim(ax,[min(xy_values)-xy_padding max(xy_values)+xy_padding])
ylim(ax,[min(xy_values)-xy_padding max(xy_values)+xy_padding])
zlim(ax,[min(z_values(:))-z_padding max(z_values(:))+z_padding])
xlabel(ax,'X'); ylabel(ax,'Y'); zlabel(ax,'Z')
axis(ax,'vis3d')
daspect(ax,[1 1 1])
view(ax,60,30)
box(ax,'on')
grid(ax,'on')
set(ax,'FontSize',11,'LineWidth',1.1, ...
    'GridAlpha',0.12,'Projection','perspective')

end


%% Helper function: Plot skeleton links
function plot_bones(ax,x,y,z,bones,color,linewidth)

for bonei = 1:size(bones,1)
    p1 = bones(bonei,1);
    p2 = bones(bonei,2);
    plot3(ax,[x(p1) x(p2)],[y(p1) y(p2)],[z(p1) z(p2)], ...
        '-','Color',color,'LineWidth',linewidth,'HandleVisibility','off');
end

end


%% Helper function: Initialize animation bones
function handles = initialize_bones(ax,x,y,z,bones)

handles = gobjects(size(bones,1),1);
for bonei = 1:size(bones,1)
    p1 = bones(bonei,1);
    p2 = bones(bonei,2);
    handles(bonei) = plot3(ax,[x(p1) x(p2)],[y(p1) y(p2)], ...
        [z(p1) z(p2)],'k-','LineWidth',2.6,'HandleVisibility','off');
end

end


%% Helper function: Update animation bones
function update_bones(handles,x,y,z,bones)

for bonei = 1:size(bones,1)
    p1 = bones(bonei,1);
    p2 = bones(bonei,2);
    set(handles(bonei),'XData',[x(p1) x(p2)], ...
        'YData',[y(p1) y(p2)],'ZData',[z(p1) z(p2)]);
end

end


%% Helper function: Default Dance-study skeleton
function bones = default_bones(nmarkers)

if nmarkers == 22
    bones = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10; ...
        7,11;11,12;12,13;14,15;14,16;15,16;15,17;17,18;18,19; ...
        16,20;20,21;21,22];
else
    bones = zeros(0,2);
end

end


%% Helper function: Validate skeleton links
function validate_bones(bones,nmarkers)

if ~isnumeric(bones) || size(bones,2) ~= 2 || ...
        any(~isfinite(bones(:))) || any(bones(:) ~= round(bones(:))) || ...
        any(bones(:) < 1) || any(bones(:) > nmarkers)
    error('Patterns.bones must contain valid one-based marker pairs.');
end

end


%% Helper function: Validate frequency vector
function frex = validate_frequency_vector(frex,name)

if ~isnumeric(frex) || ~isreal(frex) || ~isvector(frex) || isempty(frex) || ...
        any(~isfinite(frex)) || any(frex <= 0)
    error('%s must be a non-empty vector of positive finite frequencies.',name);
end
frex = reshape(sort(frex(:)),1,[]);

end


%% Helper function: Validate component number
function ncomps = validate_component_number(ncomps,name)

if ~isnumeric(ncomps) || ~isreal(ncomps) || ~isscalar(ncomps) || ...
        ~isfinite(ncomps) || ncomps ~= round(ncomps) || ncomps < 1
    error('%s must be one positive integer.',name);
end

end


%% Helper function: Map frequencies
function [idx_frex,frex_actual] = map_frequencies(frex,frex_requested,label)

idx_frex = zeros(1,numel(frex_requested));
for freqi = 1:numel(frex_requested)
    [~,idx_frex(freqi)] = min(abs(frex-frex_requested(freqi)));
end
frex_actual = frex(idx_frex);

if ~all(ismembertol(frex_requested(:),frex(:),1e-3))
    warning(['Some requested frequencies in ' label ...
        '.frex are not present in FREQ.frex. Using closest matches instead.']);
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
