% Shared figure implementation; computations and visual styles are unchanged.
% Called by the main/supplementary pipeline with figure_scope set explicitly.
assert(ismember(figure_scope,{'Main','Supplementary'}));
assert(isequal(CFG.common.list_dyads,1:35),'Final figures require all 35 dyads.');
%% BLOCK 7 - GROUP-LEVEL VISUALIZATION

path_data = CFG.block2.output_path;

% Restore plotting metadata cleared before the coordination analyses.
prefix = {'';'_onlyX';'_onlyY';'_onlyZ'};
srate = 250;
ndyads = 35;
nconds = 4;
ntrials = CFG.common.ntrials;
nsubs = 2;
list_dyads = CFG.common.list_dyads;
condlabels = {'NOvis-DIFFmus','NOvis-SAMEmus', ...
    'YESvis-DIFFmus','YESvis-SAMEmus'};
meter = [.25 .5 1 2];
nmeters = length(meter);
marklabels = {'LB Head','LF Head','RF Head','RB Head','Sternum', ...
    'L Shoulder','R Shoulder','L Elbow','L Wrist','L Hand', ...
    'R Elbow','R Wrist','R Hand','Pelvis','L Hip','R Hip', ...
    'L Knee','L Ankle','L Foot','R Knee','R Ankle','R Foot'};
bones = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10; ...
    7,11;11,12;12,13;14,15;14,16;15,16;15,17;17,18;18,19; ...
    16,20;20,21;21,22];

% Import the compact component summaries saved by BLOCKS 3 and 6. Keeping
% the component dimension here ensures that every requested coordination
% analysis is represented in the consolidated group figures.
coordination_components = CFG.block3.components;
coordination_results = cell(1,numel(coordination_components));
for componenti = 1:numel(coordination_components)
    which_comp = coordination_components(componenti);
    coordination_summary_file = fullfile(CFG.block3.output_path, ...
        ['Component_' num2str(which_comp)], ...
        ['FREQNESS_SPATIAL_SUMMARY_Comp#' ...
        num2str(which_comp) '.mat']);
    assert(isfile(coordination_summary_file), ...
        'Missing BLOCK 3 summary: %s',coordination_summary_file);
    S = load(coordination_summary_file,'MIRROR','which_comp','list_dyads','CFG');
    assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Spatial group summary does not cover the configured dyads/trials.');
    coordination_results{componenti} = S;

end

phase_components = CFG.block6.components;
phase_results = cell(1,numel(phase_components));
for componenti = 1:numel(phase_components)
    which_comp = phase_components(componenti);
    phase_summary_file = fullfile(CFG.block6.output_path, ...
        ['Component_' num2str(which_comp)], ...
        ['FREQNESS_PHASERQA_SUMMARY_Comp#' num2str(which_comp) '.mat']);
    assert(isfile(phase_summary_file), ...
        'Missing BLOCK 6 summary: %s',phase_summary_file);
    S = load(phase_summary_file,'PhaseRQA','list_dyads','CFG');
    assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Phase-space group summary does not cover the configured dyads/trials.');
    phase_results{componenti} = S;
end

% Select method: 'GED' or 'PCA'
which_method = 'GED';

% Choose whether you want one dimension
idx_XYZ = 1; % 1 = '', all axes included

close all

% Import group-level data
S = load(fullfile(path_data, ...
    ['FREQNESS_GroupNetworkSummary' prefix{idx_XYZ} '.mat']),'list_dyads','CFG');
assert(isequal(S.list_dyads,CFG.common.list_dyads) && ...
    isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
    'Network group summary does not cover the configured dyads/trials.');
load(fullfile(path_data, ...
    ['FREQNESS_GroupNetworkSummary' prefix{idx_XYZ} '.mat']), ...
    'all_evals','all_pats','all_frex_norm','ED', ...
    'marker_reference')
markData = marker_reference;
nmarks = size(markData,1);


% Select the final cohort while preserving the original dyad identifiers.
all_evals = all_evals(list_dyads,:,:,:,:,:);
all_pats = abs(all_pats(list_dyads,:,:,:,:,:,:));
all_frex_norm = all_frex_norm(list_dyads,:,:,:,:);
ED = ED(:,list_dyads,:,:,:);

% Settings
ncomps2keep = 4;                 % number of components
nfrex = size(all_evals, 5);      % number of frequencies
colors = [0.90 0.22 0.16; ...
          0.36 0.69 0.88; ...
          0.22 0.45 0.78; ...
          0.12 0.25 0.55];

% Average over trials
avg_evals = squeeze(mean(all_evals, 3, 'omitnan'));   %  [dyads,conds,trials,comps,frex,subs]
avg_pats  = squeeze(mean(all_pats, 3, 'omitnan'));    %  [dyads,conds,trials,markers,comps,frex,subs]

% Compute group mean & SEM over dyads
avg_evals = squeeze(mean(avg_evals,length(size(avg_evals))));  % average over subjects(partners) first
sem_evals = squeeze(std(avg_evals,0,1)) / sqrt(size(avg_evals,1));
avg_evals = squeeze(mean(avg_evals,1));

sem_pats  = squeeze(std(avg_pats,0,1)) / sqrt(size(avg_pats,1));
avg_pats  = squeeze(mean(avg_pats,1));

% Assign any normalized frequency vector
frex2plot = squeeze(all_frex_norm(1,1,1,1,:));


idx_frex = find(ismember(frex2plot,[0.25 0.5 1 2]));

% Log-spaced visualization
% ====== X-axis: build a log2-uniform frequency grid ======
% Assign any normalized frequency vector
frex2plot = squeeze(all_frex_norm(1,1,1,1,:));
frex2plot = sort(frex2plot(:),'ascend');

% Log2-uniform grid across available span
nPoints  = 200;                                   % resolution along x
log2_min = log2(min(frex2plot));
log2_max = log2(max(frex2plot));
log2_frex_uniform = linspace(log2_min,log2_max,nPoints).';
frex_uniform      = 2.^log2_frex_uniform;         % back to linear (×Beat)

% ====== Resample group means & SEM onto that grid ======
% avg_evals & sem_evals are [cond, comp, frex]
avg_evals_rs = zeros(nconds, ncomps2keep, nPoints);
sem_evals_rs = zeros(nconds, ncomps2keep, nPoints);

for condi = 1:nconds
    for compi = 1:ncomps2keep
        y  = squeeze(avg_evals(condi,compi,:));
        se = squeeze(sem_evals(condi,compi,:));
        avg_evals_rs(condi,compi,:) = interp1(frex2plot, y,  frex_uniform, 'linear','extrap');
        sem_evals_rs(condi,compi,:) = interp1(frex2plot, se, frex_uniform, 'linear','extrap');
    end
end

if strcmp(figure_scope,'Supplementary')
% ====== Plot: x in log2 units (equal octave spacing), labels in linear ======
figure
for condi = 1:nconds
    subplot(2,2,condi); hold on

    for compi = 1:ncomps2keep
        this_y   = squeeze(avg_evals_rs(condi,compi,:));
        this_sem = squeeze(sem_evals_rs(condi,compi,:));

        xx = [log2_frex_uniform; flipud(log2_frex_uniform)];
        yy = [this_y(:)-this_sem(:); flipud(this_y(:)+this_sem(:))];

        fill(xx, yy, colors(compi,:), ...
            'FaceAlpha', 0.22, ...
            'EdgeColor', 'none');

        plot(log2_frex_uniform, this_y, ...
            'Color', colors(compi,:), ...
            'LineWidth', 2.5);
    end

    % Octave ticks within range (adjust set as you like)
    octave_set  = [0.125 0.25 0.5 1 2 4 8];
    in_range    = octave_set >= min(frex_uniform) & octave_set <= max(frex_uniform);
    octave_vals = octave_set(in_range);
    if numel(octave_vals) >= 2
        xticks(log2(octave_vals));                 % positions (log2)
        xticklabels(string(octave_vals));          % show linear freq
    end
    xtickangle(45)

    xlim([min(log2_frex_uniform) max(log2_frex_uniform)])
    ylim([0 80])

    xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')   % linear label
    ylabel('Explained variance (%)', 'FontSize', 14, 'FontWeight', 'bold')
    legend(arrayfun(@(x) sprintf([which_method ' #%d'],x), 1:ncomps2keep, 'UniformOutput', false))
    title(condlabels{condi})

    grid on; grid minor; box on
    set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
    set(gcf, 'Color', 'w');
end

sgtitle(['Bodily network prominence across beat-normalized frequencies - ' which_method])


end

%%%% ED: SAME LOG2 AXIS APPEARANCE, NO RESAMPLING, SHADED SEM %%%%

% Average ED
ED = squeeze(mean(ED,3,'omitnan'));                   % across trials
ED = squeeze(mean(ED,length(size(ED))));    % across subjects (partners)
avg_ED = squeeze(mean(ED,2));               % avg across dyads
sem_ED = squeeze(std(ED,0,2)) / sqrt(size(ED,2)); % SEM

% Use the original frequency vector (no interpolation)
x_lin  = frex2plot(:);
x_log2 = log2(x_lin);

if strcmp(figure_scope,'Supplementary')
figure
for condi = 1:nconds
    subplot(2,2,condi); hold on

    % Data for this condition
    y  = squeeze(avg_ED(condi,:)).';
    se = squeeze(sem_ED(condi,:)).';

    % --- shaded SEM band ---
    xx = [x_log2;           flipud(x_log2)];
    yy = [y - se;           flipud(y + se)];
    fh = fill(xx, yy, colors(1,:), 'FaceAlpha', 0.22, 'EdgeColor', 'none');

    % --- mean curve on top ---
    plot(x_log2, y, 'Color', colors(1,:), 'LineWidth', 2.5);

    % Octave ticks within range (same tick style as before)
    octave_set  = [0.125 0.25 0.5 1 2 4 8];
    in_range    = octave_set >= min(x_lin) & octave_set <= max(x_lin);
    octave_vals = octave_set(in_range);
    if numel(octave_vals) >= 2
        xticks(log2(octave_vals));          % positions in log2
        xticklabels(string(octave_vals));    % labels in linear freq
    end
    xtickangle(45)

    xlim([min(x_log2) max(x_log2)])
    ylim([1 9])

    xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')
    ylabel('Effective Dimensionality', 'FontSize', 14, 'FontWeight', 'bold')
    title(condlabels{condi})

    grid on; grid minor; box on
    set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
    set(gcf, 'Color', 'w');
end

sgtitle(['Effective dimensionality of the network landscape across beat-normalized frequencies - ' which_method])



end

if strcmp(figure_scope,'Main')
%% GRAND-GRANDAVERAGE LANDSCAPE AND ED ACROSS CONDITIONS

%%%% GRAND-GRANDAVERAGE LANDSCAPE %%%%

% Recompute dyad-level eigenspectra before condition averaging
gg_evals = squeeze(mean(all_evals, 3, 'omitnan'));                         % average over trials
gg_evals = squeeze(mean(gg_evals, length(size(gg_evals))));     % average over subjects/partners
gg_evals = squeeze(mean(gg_evals, 2));                          % average over conditions
% gg_evals: [dyads x comps x frex]

avg_evals_gg = squeeze(mean(gg_evals, 1));                      % average over dyads
sem_evals_gg = squeeze(std(gg_evals, 0, 1)) / sqrt(size(gg_evals,1)); % SEM across dyads

% Delegate the Figure 2 landscape to the toolbox visualizer. The externally
% computed SEM retains the inferential unit used here (dyads).
GED_figure = [];
GED_figure.evals = avg_evals_gg;
GED_figure.frex = frex2plot;

Landscape_figure = [];
Landscape_figure.frex = frex2plot;
Landscape_figure.ncomps = ncomps2keep;
Landscape_figure.sem = sem_evals_gg;
Landscape_figure.xlabel = 'Frequency (× Beat)';
Landscape_figure.title = ['Grand-grandaverage bodily network landscape across conditions - ' which_method];

FREQNESS_Visualizer_Mocap(GED_figure,Landscape_figure,[]);


%%%% GRAND-GRANDAVERAGE ED %%%%

% ED at this point is already: [conditions x dyads x frequencies]
gg_ED = squeeze(mean(ED, 1));                                    % average over conditions
% gg_ED: [dyads x frex]

avg_ED_gg = squeeze(mean(gg_ED, 1));                             % average over dyads
sem_ED_gg = squeeze(std(gg_ED, 0, 1)) / sqrt(size(gg_ED,1));      % SEM across dyads

figure
hold on

y  = avg_ED_gg(:);
se = sem_ED_gg(:);

xx = [x_log2; flipud(x_log2)];
yy = [y - se; flipud(y + se)];

fill(xx, yy, colors(1,:), ...
    'FaceAlpha', 0.22, ...
    'EdgeColor', 'none');

plot(x_log2, y, ...
    'Color', colors(1,:), ...
    'LineWidth', 2.5);

octave_set  = [0.125 0.25 0.5 1 2 4 8];
in_range    = octave_set >= min(x_lin) & octave_set <= max(x_lin);
octave_vals = octave_set(in_range);
if numel(octave_vals) >= 2
    xticks(log2(octave_vals));
    xticklabels(string(octave_vals));
end
xtickangle(45)

xlim([min(x_log2) max(x_log2)])
ylim([1 9])

xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')
ylabel('Effective Dimensionality', 'FontSize', 14, 'FontWeight', 'bold')
title('Grand-grandaverage')

grid on; grid minor; box on
set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
set(gcf, 'Color', 'w');

sgtitle(['Grand-grandaverage effective dimensionality across conditions - ' which_method])




end

if strcmp(figure_scope,'Supplementary')
%% VISUALIZATION: Group-level Activation Patterns (Static Scatterplot)

% Setup
nscale     = 1000;
col_static = .95 * jet(nscale);
linewidth  = 1.7;
ndims      = 3;
min_marksize = 30;
max_marksize = 100;

% Component index and frequency index to visualize
idx_frex = find(ismember(frex2plot, [0.25 0.5 1 2]));

% Indexing for axes
x_idx = 1:3:nmarks-2;
y_idx = 2:3:nmarks-1;
z_idx = 3:3:nmarks;


% Loop over components and frequencies
for frexi = 1:length(idx_frex)

    for condi = 1:nconds

   % Global normalization values, within condition and frex, across components
   global_max_pat = max(avg_pats(condi,:,1:ncomps2keep,idx_frex(frexi),:), [], 'all');
   global_max_sem = max(sem_pats(condi,:,1:ncomps2keep,idx_frex(frexi),:), [], 'all');

    figure('Color','w'), clf

    for compi = 1:ncomps2keep

        % One row per component, 3 columns = XYZ
        for dimi = 1:ndims
            subplotidx = (compi - 1)*ndims + dimi;
            subplot(ncomps2keep, ndims, subplotidx), hold on

            for subi = 1:nsubs

                % Extract and normalize activation pattern using global max
                this_pat = squeeze(avg_pats(condi,:,compi,idx_frex(frexi),subi));
                this_pat = this_pat / global_max_pat;

                % Extract SEM and normalize/invert using global max
                this_sem = squeeze(sem_pats(condi,:,compi,idx_frex(frexi),subi));
                this_sem = this_sem / global_max_sem;
                this_sem = 1 - this_sem;
                this_sem = min_marksize + this_sem * (max_marksize - min_marksize);

                % Position data
                x_pos = markData(x_idx,1,subi);
                y_pos = markData(y_idx,1,subi);
                z_pos = markData(z_idx,1,subi);

                % Color indices
                x_pats = this_pat(x_idx);
                y_pats = this_pat(y_idx);
                z_pats = this_pat(z_idx);
                cidx_x = min(max(round((x_pats + 1) * (nscale - 1) / 2) + 1, 1), nscale);
                cidx_y = min(max(round((y_pats + 1) * (nscale - 1) / 2) + 1, 1), nscale);
                cidx_z = min(max(round((z_pats + 1) * (nscale - 1) / 2) + 1, 1), nscale);

                % Marker sizes (per point)
                msize = this_sem(x_idx);

                % Choose colors and plot
                switch dimi
                    case 1
                        scatter3(x_pos, y_pos, z_pos, msize, col_static(cidx_x,:), 'filled');
                        title('X-axis activation')
                    case 2
                        scatter3(x_pos, y_pos, z_pos, msize, col_static(cidx_y,:), 'filled');
                        title('Y-axis activation')
                    case 3
                        scatter3(x_pos, y_pos, z_pos, msize, col_static(cidx_z,:), 'filled');
                        title('Z-axis activation')
                end

                % Plot bones
                for k = 1:size(bones,1)
                    p1 = bones(k,1); p2 = bones(k,2);
                    plot3([x_pos(p1) x_pos(p2)], ...
                          [y_pos(p1) y_pos(p2)], ...
                          [z_pos(p1) z_pos(p2)], 'k-', 'LineWidth', linewidth);
                end
            end

            % Format subplot
            axis vis3d
            daspect([1 1 1])
            xlabel('X'), ylabel('Y'), zlabel('Z')
            colorbar
            view(60,30)
        end
    end

    sgtitle(['Group-level Activation Patterns  - ' which_method ' | Freq = ' num2str(frex2plot(idx_frex(frexi)), '%.2f') ' × Beat. ' condlabels{condi}])

    end
end


% Compute correlation between 1st and 2nd component
pat1 = squeeze( all_pats(:,:,:,:,1,:,:) ); % component #1
pat2 = squeeze( all_pats(:,:,:,:,2,:,:) ); % component #2
corrs2avg = nan(length(list_dyads),nconds,ntrials,nfrex,nsubs);

% Correlate all markers in the innermost loop
for dyadi = 1:length(list_dyads)
    for condi = 1:nconds
        for triali = 1:CFG.common.trial_counts(list_dyads(dyadi),condi)
            for frexi = 1:nfrex
                for subi = 1:nsubs
                    corrs2avg(dyadi,condi,triali,frexi,subi) = corr( squeeze(pat1(dyadi,condi,triali,:,frexi,subi)), squeeze(pat2(dyadi,condi,triali,:,frexi,subi)) );
                end
            end
        end
    end
end

% Put frequency first (due to reshape() behavior): [nfrex × ndyads × nconds × ntrials × nsubs]
tmp = permute(corrs2avg, [4 1 2 3 5]);
% Flatten all non-frequency dims, then average across them
corrs2plot = reshape(tmp, nfrex, []);
corrs2plot = mean(corrs2plot, 2, 'omitnan');

% Visualize
figure
plot(frex2plot,corrs2plot,'Color',colors(1,:),'LineWidth',2.5)
hold on
yline(0,'k','LineWidth',linewidth)
% Cosmetics
ylim([-1 1])
xtickangle(45)
xlabel('Frequency (× Beat)', 'FontSize', 14, 'FontWeight', 'bold')
ylabel('Correlation coefficient', 'FontSize', 14, 'FontWeight', 'bold')
grid on
grid minor
box on
set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'GridAlpha', 0.18, 'MinorGridAlpha', 0.10)
set(gcf, 'Color', 'w');
sgtitle('Spatial correlation between component#1 and component#2')


end

if strcmp(figure_scope,'Main')
%% VISUALIZATION: Grand-grandaverage Activation Patterns Across Conditions

% Select spatial-pattern component to visualize without changing the
% coordination component identifier used by the statistical export.
which_pattern_comp = 1;

% Average activation patterns across trials
gg_pats = squeeze(mean(all_pats, 3, 'omitnan'));
% gg_pats: [dyads x conds x markers x comps x frex x subs]

% Average activation patterns across conditions
gg_pats = squeeze(mean(gg_pats, 2));
% gg_pats: [dyads x markers x comps x frex x subs]

% Average activation patterns across dyads
avg_pats_gg = squeeze(mean(gg_pats, 1));
% avg_pats_gg: [markers x comps x frex x subs]

% Delegate Figure 2 spatial patterns to the toolbox visualizer.
GED_figure.pats = avg_pats_gg;

Patterns_figure = [];
Patterns_figure.frex = frex2plot(idx_frex);
Patterns_figure.labels = marklabels;
Patterns_figure.markerData = markData;
Patterns_figure.comp = which_pattern_comp;
Patterns_figure.srate = srate;
Patterns_figure.start = 0.25;
Patterns_figure.bones = bones;
Patterns_figure.plot_matrix = false;
Patterns_figure.animate = false;
Patterns_figure.frequency_unit = '× Beat';

FREQNESS_Visualizer_Mocap(GED_figure,[],Patterns_figure);



end

% GROUP-LEVEL COORDINATION VISUALIZATION

coordination_fields = {'MIRROR'};
coordination_labels = {'Spatial correlation'};

for componenti = 1:numel(coordination_results)
    if (strcmp(figure_scope,'Main') && coordination_components(componenti) ~= 1) || ...
            (strcmp(figure_scope,'Supplementary') && coordination_components(componenti) == 1)
        continue
    end
    which_comp = coordination_results{componenti}.which_comp;
    for metrici = 1:numel(coordination_fields)
        metric_data = coordination_results{componenti}.( ...
            coordination_fields{metrici});
        avg_metric = squeeze(mean(metric_data(list_dyads,:,:,:),4,'omitnan'));
        figure;
        for metri = 1:nmeters
            subplot(ceil(nmeters/3),3,metri);
            meter_data = squeeze(avg_metric(:,:,metri));
            mu = mean(meter_data,1);
            sem = std(meter_data,0,1)/sqrt(size(meter_data,1));
            bar(mu);
            hold on;
            errorbar(1:nconds,mu,sem,'.k');
            if ~strcmp(coordination_fields{metrici},'MIRROR')
                ylim([0 1])
            end
            title(['Meter ' num2str(metri)]);
            xlabel('Condition');
            ylabel('Mean ± SEM');
            xticks(1:nconds);
            xtickangle(45)
            xticklabels(condlabels)
            sgtitle([coordination_labels{metrici} ...
                ' - Component #' num2str(which_comp)])
        end
    end
end

% GROUP-LEVEL PHASE-SPACE RQA VISUALIZATION

phase_metric_fields = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
phase_metric_labels = {'Recurrence rate','Average diagonal length', ...
    'Determinism','Diagonal-line entropy','Trapping time', ...
    'Laminarity','Maximum vertical length','Divergence'};

for componenti = 1:numel(phase_results)
    if (strcmp(figure_scope,'Main') && phase_components(componenti) ~= 1) || ...
            (strcmp(figure_scope,'Supplementary') && phase_components(componenti) == 1)
        continue
    end
    for metrici = 1:numel(phase_metric_fields)
        % Validated RR/DET imports do not contain the six auxiliary metrics.
        if ~isfield(phase_results{componenti}.PhaseRQA.output,phase_metric_fields{metrici})
            continue
        end
        phase_metric = phase_results{componenti}.PhaseRQA.output.( ...
            phase_metric_fields{metrici});
        avg_phase_metric = squeeze(mean(phase_metric(list_dyads,:,:,:),4,'omitnan'));
        figure;
        for metri = 1:nmeters
            subplot(ceil(nmeters/3),3,metri);
            meter_data = squeeze(avg_phase_metric(:,:,metri));
            mu = mean(meter_data,1);
            sem = std(meter_data,0,1)/sqrt(size(meter_data,1));
            bar(mu);
            hold on;
            errorbar(1:nconds,mu,sem,'.k');
            title(['Meter ' num2str(metri)]);
            xlabel('Condition');
            ylabel('Mean ± SEM');
            xticks(1:nconds);
            xtickangle(45)
            xticklabels(condlabels)
            sgtitle(['Phase-space RQA: ' phase_metric_labels{metrici} ...
                ' - Component #' num2str(phase_components(componenti))])
        end
    end
end


% Export every group-level image only after all numerical analysis blocks
% have completed. Existing figures remain untouched unless requested.
% Separate new figure collections; never reuse legacy GROUP_NN names for different plots.
figure_path = fullfile(CFG.block7.figure_path,figure_scope);
if ~isfolder(figure_path), mkdir(figure_path); end
figure_handles = findall(groot,'Type','figure');
for figurei = 1:numel(figure_handles)
    figure_name = fullfile(figure_path,sprintf( ...
        'GROUP_%02d',figurei));
    if ~isfile([figure_name '.fig']) || CFG.block7.overwrite_flag
        savefig(figure_handles(figurei),[figure_name '.fig'])
    end
    if ~isfile([figure_name '.png']) || CFG.block7.overwrite_flag
        exportgraphics(figure_handles(figurei),[figure_name '.png'], ...
            'Resolution',200)
    end
end
close all
