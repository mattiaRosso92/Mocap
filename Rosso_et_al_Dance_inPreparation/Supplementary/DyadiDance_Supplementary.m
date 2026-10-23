% Dyadic Dance supplementary analyses, all 35 dyads.
% Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
% Run the main pipeline first to produce the shared core and group summaries.
% Blocks 4/5 can also run after configuration alone when core files exist.
% Blocks 4/5 keep their original formulas and output paths. S1 writes only new
% controls; Block 7 reproduces publication panels. Run the R scripts afterwards
% and assemble the Word supplement with DyadiDance_SupplementDocument.py.
clear
close all
clc

%% BLOCK 0 - SHARED STUDY CONFIGURATION

script_file = mfilename('fullpath');
if isempty(script_file)
    script_file = matlab.desktop.editor.getActiveFilename;
end
path_study = fileparts(fileparts(script_file));
run(fullfile(path_study,'Supporting','DyadiDance_Configuration.m'));
addpath(fullfile(path_study,'Supplementary'));
% New controls are isolated from all primary/legacy outputs and cover all
% 35 dyads. The excluded empty recording stays excluded.
CFG.supplementary.output_path = fullfile(CFG.common.results_path,'Supplementary_35');
CFG.supplementary.overwrite_flag = false;
CFG.supplementary.width_multipliers = [.25 .5 1 2 4];
CFG.supplementary.ncomps = 4;
CFG.supplementary.regularisation = .01;

%% BLOCK 4 - METRIC PROMINENCE

% Individual prominence is averaged across partners, then across trials.
% This is dyad-mean individual prominence, not a coordination measure.
clearvars -except CFG
addpath(fullfile(fileparts(CFG.common.data_path),'FREQNESS_Mocap_Toolbox'))
FREQNESS_Startup_Mocap();
component_path = fullfile(CFG.block4.output_path, ...
    ['Component_' num2str(CFG.block4.component)]);
if ~isfolder(component_path), mkdir(component_path); end
settings = struct('component',CFG.block4.component, ...
    'metric_levels',CFG.block4.metric_levels, ...
    'global_metric_levels',CFG.block4.global_metric_levels);
assert(isequal(settings.metric_levels,[.25 .5 1 2]), ...
    'The five-outcome Dance export requires metric_levels = [.25 .5 1 2].');
prominence = nan(35,4,CFG.common.ntrials,5); % dyad x condition x trial x outcome
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for triali = 1:CFG.common.trial_counts(dyadi,condi)
            id_trial = CFG.common.trial_indices{dyadi,condi}(triali);
            output_file = fullfile(component_path,sprintf( ...
                'FREQNESS_METRIC_D%d_C%d_T%d.mat',dyadi,condi,triali));
            if isfile(output_file) && ~CFG.block4.overwrite_flag
                S = load(output_file,'METER','id_trial','settings');
                assert(S.id_trial == id_trial && ...
                    S.settings.component == settings.component && ...
                    isequaln(S.settings.metric_levels,settings.metric_levels) && ...
                    isequaln(S.settings.global_metric_levels,settings.global_metric_levels), ...
                    'Saved prominence settings/trial differ: %s',output_file);
                METER = S.METER;
            else
                core_name = sprintf('FREQNESS_CORE_D%d_C%d_T%d.mat',dyadi,condi,triali);
                input_file = fullfile(CFG.block1.output_path,core_name);
                if ~isfile(input_file) && ~isempty(CFG.block4.reuse_core_path)
                    input_file = fullfile(CFG.block4.reuse_core_path,core_name);
                end
                assert(isfile(input_file),'Missing core output: %s',input_file);
                S = load(input_file,'GED','beat_frex','id_trial');
                if isfield(S,'id_trial'), assert(S.id_trial == id_trial); end
                METER = FREQNESS_MetricProminence_Mocap(S.GED,S.beat_frex, ...
                    'component',CFG.block4.component, ...
                    'metric_levels',CFG.block4.metric_levels, ...
                    'global_metric_levels',CFG.block4.global_metric_levels);
                save(output_file,'METER','settings','input_file', ...
                    'dyadi','condi','triali','id_trial');
            end
            assert(isequal(size(METER.MetricProminence),[4 2]));
            prominence(dyadi,condi,triali,:) = reshape( ...
                mean([METER.GlobalProminence;METER.MetricProminence],2),1,1,1,5);
        end
    end
end
summary_file = fullfile(component_path,'FREQNESS_METRIC_SUMMARY.mat');
if ~isfile(summary_file) || CFG.block4.overwrite_flag
    save(summary_file,'prominence','CFG');
else
    S = load(summary_file,'prominence','CFG');
    assert(isequaln(S.prominence,prominence) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Existing prominence summary has different data/trials.');
end
% Export independently: no JRQA, phase-space or visualization block is required.
prominence_avg = mean(prominence,3,'omitnan');
visual_labels = ["No" "No" "Yes" "Yes"];
music_labels = ["Diff" "Same" "Diff" "Same"];
outcome_labels = ["Global" "M1" "M2" "M3" "M4"];
[Dyad,Prominence] = deal(zeros(numel(CFG.common.list_dyads)*20,1));
[Visual,Music,Level] = deal(strings(size(Dyad)));
rowi = 0;
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for leveli = 1:5
            rowi = rowi+1;
            Dyad(rowi) = dyadi; Visual(rowi) = visual_labels(condi);
            Music(rowi) = music_labels(condi); Level(rowi) = outcome_labels(leveli);
            Prominence(rowi) = prominence_avg(dyadi,condi,1,leveli);
        end
    end
end
assert(all(isfinite(Prominence) & Prominence > 0));
export_file = fullfile(component_path,'OUT2R_MetricProminence.csv');
if ~isfile(export_file) || CFG.block4.overwrite_flag
    writetable(table(Dyad,Visual,Music,Level,Prominence),export_file);
else
    S = readtable(export_file,'TextType','string');
    assert(isequal(S(:,1:4),table(Dyad,Visual,Music,Level)) && ...
        max(abs(S.Prominence-Prominence)) < 1e-12, ...
        'Existing prominence export has different dyads/data.');
end

%% BLOCK 5 - LANDSCAPE SIMILARITY

clearvars -except CFG
addpath(fullfile(fileparts(CFG.common.data_path),'FREQNESS_Mocap_Toolbox'))
FREQNESS_Startup_Mocap();
component_path = fullfile(CFG.block5.output_path, ...
    ['Component_' num2str(CFG.block5.component)]);
if ~isfolder(component_path), mkdir(component_path); end
settings = struct('component',CFG.block5.component,'frequency_axis','beat_relative');
similarity = nan(35,4,CFG.common.ntrials,2); % dyad x condition x trial x outcome
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for triali = 1:CFG.common.trial_counts(dyadi,condi)
            id_trial = CFG.common.trial_indices{dyadi,condi}(triali);
            output_file = fullfile(component_path,sprintf( ...
                'FREQNESS_SIMILARITY_D%d_C%d_T%d.mat',dyadi,condi,triali));
            if isfile(output_file) && ~CFG.block5.overwrite_flag
                S = load(output_file,'similarity_comp','similarity_entropy','id_trial','settings');
                assert(S.id_trial == id_trial && isequaln(S.settings,settings), ...
                    'Saved similarity settings/trial differ: %s',output_file);
                similarity_comp = S.similarity_comp;
                similarity_entropy = S.similarity_entropy;
            else
                core_name = sprintf('FREQNESS_CORE_D%d_C%d_T%d.mat',dyadi,condi,triali);
                input_file = fullfile(CFG.block1.output_path,core_name);
                if ~isfile(input_file) && ~isempty(CFG.block5.reuse_core_path)
                    input_file = fullfile(CFG.block5.reuse_core_path,core_name);
                end
                assert(isfile(input_file),'Missing core output: %s',input_file);
                S = load(input_file,'GED','beat_frex','id_trial');
                if isfield(S,'id_trial'), assert(S.id_trial == id_trial); end
                relative_frex = S.GED.frex./reshape(S.beat_frex,1,[]);
                assert(isequal(size(relative_frex),[32 2]) && ...
                    max(abs(relative_frex-(1:32)'/8),[],'all') < 1e-12, ...
                    'Expected both partners on the 1/8-to-4x beat grid: %s',input_file);
                % Align corresponding beat multiples, NOT absolute Hz: keep
                % eigenvalues unchanged; no interpolation or re-estimation.
                FREQ = struct('evals',S.GED.evals,'frex',(1:32)'/8);
                [similarity_comp,similarity_entropy,selected_frex] = ...
                    FREQNESS_LandscapeSimilarity(FREQ,'component',settings.component);
                save(output_file,'similarity_comp','similarity_entropy', ...
                    'selected_frex','settings','input_file','dyadi','condi','triali','id_trial');
            end
            this_similarity = [similarity_comp similarity_entropy];
            assert(numel(this_similarity)==2 && all(isfinite(this_similarity)) && ...
                all(abs(this_similarity)<1), ...
                'Undefined or perfect correlation; inspect D%d C%d T%d before Fisher transformation.', ...
                dyadi,condi,triali);
            similarity(dyadi,condi,triali,:) = reshape(this_similarity,1,1,1,2);
        end
    end
end
summary_file = fullfile(component_path,'FREQNESS_SIMILARITY_SUMMARY.mat');
if ~isfile(summary_file) || CFG.block5.overwrite_flag
    save(summary_file,'similarity','CFG');
else
    S = load(summary_file,'similarity','CFG');
    assert(isequaln(S.similarity,similarity) && ...
        isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Existing similarity summary has different data/trials.');
end
% Average trial correlations in Fisher-z space, retaining signed similarity.
similarity_z = mean(atanh(similarity),3,'omitnan');
visual_labels = ["No" "No" "Yes" "Yes"];
music_labels = ["Diff" "Same" "Diff" "Same"];
outcome_labels = ["Component" "Entropy"];
[Dyad,FisherZ] = deal(zeros(numel(CFG.common.list_dyads)*8,1));
[Visual,Music,Outcome] = deal(strings(size(Dyad)));
rowi = 0;
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for outcomei = 1:2
            rowi = rowi+1;
            Dyad(rowi) = dyadi; Visual(rowi) = visual_labels(condi);
            Music(rowi) = music_labels(condi); Outcome(rowi) = outcome_labels(outcomei);
            FisherZ(rowi) = similarity_z(dyadi,condi,1,outcomei);
        end
    end
end
assert(all(isfinite(FisherZ)));
export_file = fullfile(component_path,'OUT2R_LandscapeSimilarity.csv');
if ~isfile(export_file) || CFG.block5.overwrite_flag
    writetable(table(Dyad,Visual,Music,Outcome,FisherZ),export_file);
else
    S = readtable(export_file,'TextType','string');
    assert(isequal(S(:,1:4),table(Dyad,Visual,Music,Outcome)) && ...
        max(abs(S.FisherZ-FisherZ)) < 1e-12, ...
        'Existing similarity export has different dyads/data.');
end


%% BLOCK S1 - GED/PCA, BANDWIDTH, VELOCITY AND AXIS-ONLY CONTROLS

clearvars -except CFG
assert(isequal(CFG.common.list_dyads,1:35) && sum(CFG.common.trial_counts,'all')==1119);
assert(strcmp(CFG.common.filter_output_tag,'legacy_logarithmic'), ...
    'These manuscript controls are relative to the primary legacy-logarithmic widths.');
control_path = fullfile(CFG.supplementary.output_path,'Controls');
if ~isfolder(control_path), mkdir(control_path); end
settings = rmfield(CFG.supplementary,{'output_path','overwrite_flag'});
settings.version = 1;
settings.velocity = 'first_difference_times_250';
settings.axis_policy = 'zero_other_coordinates';
settings.filter_width_calibration = CFG.common.filter_output_tag;
song_bpms = [111.03 116.07 118.23 118.95 120.47 125.93 128.27 129.06];
sublabels = {'_LEFT','_RIGHT'};
song_info = cell(1,2);
for subi = 1:2
    song_info{subi} = readmatrix(fullfile(CFG.common.data_path, ...
        ['song_subj' sublabels{subi} '.csv']),'NumHeaderLines',1);
end
for dyadi = CFG.common.list_dyads
    for condi = 1:4
        for triali = 1:CFG.common.trial_counts(dyadi,condi)
            id_trial = CFG.common.trial_indices{dyadi,condi}(triali);
            output_file = fullfile(control_path,sprintf( ...
                'DyadiDance_CONTROLS_D%d_C%d_T%d.mat',dyadi,condi,triali));
            if isfile(output_file) && ~CFG.supplementary.overwrite_flag
                S = load(output_file,'id_trial','settings');
                assert(S.id_trial==id_trial && isequaln(S.settings,settings), ...
                    'Existing control settings/trial differ: %s',output_file);
                continue
            end
            markData = [];
            beat_frex = zeros(1,2);
            for subi = 1:2
                trial_file = fullfile(CFG.common.data_path,sprintf('Dyad_%02d',dyadi), ...
                    ['subj' sublabels{subi}],sprintf('tr%02d.csv',id_trial));
                this_data = readmatrix(trial_file,'NumHeaderLines',1);
                if subi==1, markData = zeros(66,size(this_data,2)-1,2); end
                markData(:,:,subi) = this_data(1:end-3,2:end); %#ok<SAGROW> preallocated for subi==1
                beat_frex(subi) = song_bpms(song_info{subi}(dyadi,id_trial+1)+1)/60;
            end
            % Match each partner's own stimulus beat, including Different Music.
            frex = (1:32)'/8.*beat_frex;
            fwidth = FREQNESS_ComputeLegacyFilterWidths_Mocap(frex,'logarithmic');
            tic
            CONTROL = DyadiDance_ControlEstimation(markData,frex,250,fwidth,settings);
            computation_seconds = toc;
            core_name = sprintf('FREQNESS_CORE_D%d_C%d_T%d.mat',dyadi,condi,triali);
            input_file = fullfile(CFG.block1.output_path,core_name);
            if ~isfile(input_file), input_file = fullfile(CFG.common.reuse_core_path,core_name); end
            S = load(input_file,'id_trial');
            assert(S.id_trial==id_trial);
            core_evals = h5read(input_file,'/GED/evals');
            baseline_error = max(abs(CONTROL.evals(:,:,:,3)-core_evals),[],'all');
            assert(baseline_error<1e-7, ...
                'Control baseline differs from saved primary core: %s',input_file);
            save(output_file,'CONTROL','settings','id_trial','dyadi','condi', ...
                'triali','beat_frex','input_file','baseline_error','computation_seconds');
            fprintf('Supplementary controls: D%d C%d T%d, %.1f s; core error %.3g.\n', ...
                dyadi,condi,triali,computation_seconds,baseline_error);
        end
    end
end

%% BLOCK 7 - SUPPLEMENTARY GROUP-LEVEL VISUALIZATION

% All publication panels below are generated here, not in temporary scripts.
% Main figures and their original files remain unchanged.
clearvars -except CFG
figure_path = fullfile(CFG.supplementary.output_path,'Figures');
if ~isfolder(figure_path), mkdir(figure_path); end
S = load(fullfile(CFG.block2.output_path,'FREQNESS_GroupNetworkSummary.mat'), ...
    'all_evals','all_pats','ED','marker_reference','CFG','list_dyads');
assert(isequal(S.list_dyads,1:35) && ...
    isequal(S.CFG.common.trial_indices,CFG.common.trial_indices));
% Trial means first, then partner means; each dyad has equal group weight.
evals_avg = reshape(mean(mean(S.all_evals,3,'omitnan'),6),35,4,66,32);
ED_avg = permute(reshape(mean(mean(S.ED,3,'omitnan'),5),4,35,32),[2 1 3]);
pats_avg = reshape(mean(abs(S.all_pats),3,'omitnan'),35,4,66,4,32,2);
marker_reference = S.marker_reference;
% Preserve the original trial-weighted component-pattern correlation curve.
pat1 = S.all_pats(:,:,:,:,1,:,:); pat2 = S.all_pats(:,:,:,:,2,:,:);
pat1 = abs(pat1)-mean(abs(pat1),4); pat2 = abs(pat2)-mean(abs(pat2),4);
pattern_r = sum(pat1.*pat2,4)./sqrt(sum(pat1.^2,4).*sum(pat2.^2,4));
pattern_r = reshape(pattern_r,35,4,CFG.common.ntrials,32,2);
pattern_r_mean = mean(reshape(permute(pattern_r,[4 1 2 3 5]),32,[]),2,'omitnan');
clear S pat1 pat2
condlabels = {'No visual / Different music','No visual / Same music', ...
    'Visual / Different music','Visual / Same music'};
meterlabels = {'Beat / 4','Beat / 2','Beat','2 x beat'};
colors = [.90 .22 .16; .36 .69 .88; .22 .45 .78; .12 .25 .55];

fig = figure('Color','w','Position',[50 50 1100 650]);
tiledlayout(2,4,'TileSpacing','compact','Padding','compact');
for condi = 1:4
    nexttile(condi); landscape_panel(reshape(evals_avg(:,condi,:,:),35,66,32),colors);
    title(condlabels{condi},'FontSize',11);
    nexttile(condi+4); ed_panel(reshape(ED_avg(:,condi,:),35,32),colors(1,:)); ylim([1 10]);
end
save_panel(fig,'S01_Conditions_Landscapes_ED',figure_path,CFG);

% Summarize the new controls only after all 1119 trial files are present.
control_evals = nan(35,4,66,32,15);
control_ED = nan(35,4,32,15);
axis_pats = nan(35,4,66,4,32,2,3);
baseline_error = zeros(35,4,CFG.common.ntrials);
for dyadi = 1:35
    for condi = 1:4
        ntrials = CFG.common.trial_counts(dyadi,condi);
        this_evals = nan(66,32,2,15,ntrials);
        this_ED = nan(32,2,15,ntrials);
        this_pats = nan(66,4,32,2,3,ntrials);
        for triali = 1:ntrials
            input_file = fullfile(CFG.supplementary.output_path,'Controls', ...
                sprintf('DyadiDance_CONTROLS_D%d_C%d_T%d.mat',dyadi,condi,triali));
            assert(isfile(input_file),'Missing supplementary control: %s',input_file);
            S = load(input_file,'CONTROL','id_trial','baseline_error','settings');
            assert(S.id_trial==CFG.common.trial_indices{dyadi,condi}(triali));
            this_evals(:,:,:,:,triali) = S.CONTROL.evals;
            this_ED(:,:,:,triali) = S.CONTROL.ED;
            this_pats(:,:,:,:,:,triali) = abs(S.CONTROL.axis_pats);
            baseline_error(dyadi,condi,triali) = S.baseline_error;
        end
        control_evals(dyadi,condi,:,:,:) = reshape(mean(mean(this_evals,5),3),1,1,66,32,15);
        control_ED(dyadi,condi,:,:) = reshape(mean(mean(this_ED,4),2),1,1,32,15);
        axis_pats(dyadi,condi,:,:,:,:,:) = reshape(mean(this_pats,6),1,1,66,4,32,2,3);
    end
end
assert(all(isfinite(control_evals),'all') && all(isfinite(control_ED),'all'));
assert(max(abs(control_evals(:,:,:,:,3)-evals_avg),[],'all')<1e-7);
summary_file = fullfile(CFG.supplementary.output_path,'DyadiDance_ControlSummary.mat');
if ~isfile(summary_file) || CFG.supplementary.overwrite_flag
    save(summary_file,'control_evals','control_ED','axis_pats','baseline_error','CFG');
else
    S = load(summary_file,'control_evals','control_ED','axis_pats','CFG');
    assert(isequaln(S.control_evals,control_evals) && isequaln(S.control_ED,control_ED) && ...
        isequaln(S.axis_pats,axis_pats) && isequal(S.CFG.common.trial_indices,CFG.common.trial_indices), ...
        'Existing control summary differs from the retained trial files.');
end

% GED/PCA comparison and bandwidth controls, shown for No visual/Different
% music as in the presentation. All conditions remain in ControlSummary.
fig = figure('Color','w','Position',[50 50 1000 650]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for methodi = 1:2
    idx = 3+(methodi-1)*5;
    nexttile(methodi); landscape_panel(reshape(control_evals(:,1,:,:,idx),35,66,32),colors);
    if methodi==1, title('GED'); else, title('PCA'); end
    nexttile(methodi+2); ed_panel(reshape(control_ED(:,1,:,idx),35,32),colors(1,:));
end
save_panel(fig,'S02_GED_PCA',figure_path,CFG);
for methodi = 1:2
    fig = figure('Color','w','Position',[50 50 1100 850]);
    tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
    for widthi = 1:5
        idx = widthi+(methodi-1)*5;
        nexttile; landscape_panel(reshape(control_evals(:,1,:,:,idx),35,66,32),colors);
        title(sprintf('Bandwidth x %g',CFG.supplementary.width_multipliers(widthi)));
    end
    nexttile; hold on
    width_colors = parula(5);
    for widthi = 1:5
        idx = widthi+(methodi-1)*5;
        plot(log2((1:32)/8),reshape(mean(control_ED(:,1,:,idx),1),1,32), ...
            'Color',width_colors(widthi,:),'LineWidth',2);
    end
    frequency_axis; ylabel('Effective dimensionality'); title('ED across bandwidths');
    legend({'x 0.25','x 0.5','x 1','x 2','x 4'},'Location','best','FontSize',9);
    save_panel(fig,sprintf('S%02d_Bandwidth_Method%d',2+methodi,methodi),figure_path,CFG);
end

fig = figure('Color','w','Position',[50 50 1100 850]);
tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
input_labels = {'Position GED','Position PCA','Velocity GED','Velocity PCA'};
for inputi = 1:4
    indices = [3 8 11 12]; idx = indices(inputi);
    nexttile; landscape_panel(reshape(control_evals(:,1,:,:,idx),35,66,32),colors);
    title(input_labels{inputi});
end
for methodi = 1:2
    nexttile; hold on
    indices = [3+(methodi-1)*5 10+methodi];
    for inputi = 1:2
        plot(log2((1:32)/8),reshape(mean(control_ED(:,1,:,indices(inputi)),1),1,32), ...
            'Color',colors(inputi,:),'LineWidth',2.5);
    end
    frequency_axis; ylabel('Effective dimensionality'); legend({'Position','Velocity'},'Location','best');
end
save_panel(fig,'S05_Position_Velocity',figure_path,CFG);

fig = figure('Color','w','Position',[50 50 1000 850]);
tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
axislabels = {'X only','Y only','Z only'};
for axisi = 1:3
    nexttile; landscape_panel(reshape(control_evals(:,1,:,:,12+axisi),35,66,32),colors);
    title(axislabels{axisi});
    nexttile; ed_panel(reshape(control_ED(:,1,:,12+axisi),35,32),colors(1,:));
end
save_panel(fig,'S06_Axis_Landscapes_ED',figure_path,CFG);

% Spatial magnitudes and uncertainty use the original shared scale across
% components/partners, separately within each frequency and condition.
for metri = 1:4
    indices = [2 4 8 16];
    fig = figure('Color','w','Position',[50 50 1050 1100]);
    tiledlayout(4,3,'TileSpacing','compact','Padding','loose');
    avg_pats = reshape(mean(pats_avg(:,1,:,:,indices(metri),:),1),66,4,2);
    sem_pats = reshape(std(pats_avg(:,1,:,:,indices(metri),:),0,1)/sqrt(35),66,4,2);
    for compi = 1:4
        for axisi = 1:3
            nexttile;
            spatial_panel(avg_pats,sem_pats,marker_reference,compi,axisi);
            title(sprintf('Component %d / %s',compi,char('X'+axisi-1)));
        end
    end
    cb = colorbar; cb.Layout.Tile = 'east'; cb.Label.String = 'Normalized magnitude';
    save_panel(fig,sprintf('S07_%d_SpatialPatterns',metri),figure_path,CFG);
end
for axisi = 1:3
    fig = figure('Color','w','Position',[50 50 1100 1050]);
    tiledlayout(4,4,'TileSpacing','compact','Padding','loose');
    for compi = 1:4
        for metri = 1:4
            indices = [2 4 8 16];
            avg_pats = reshape(mean(axis_pats(:,1,:,:,indices(metri),:,axisi),1),66,4,2);
            sem_pats = reshape(std(axis_pats(:,1,:,:,indices(metri),:,axisi),0,1)/sqrt(35),66,4,2);
            nexttile; spatial_panel(avg_pats,sem_pats,marker_reference,compi,axisi);
            title(sprintf('C%d / %s',compi,meterlabels{metri}));
        end
    end
    cb = colorbar; cb.Layout.Tile = 'east'; cb.Label.String = 'Normalized magnitude';
    save_panel(fig,sprintf('S08_%d_AxisPatterns',axisi),figure_path,CFG);
end
fig = figure('Color','w','Position',[50 50 950 420]);
plot((1:32)/8,pattern_r_mean,'Color',colors(1,:),'LineWidth',2.5);
yline(0,'k'); ylim([-1 1]); grid on; box on;
xlabel('Frequency (x beat)'); ylabel('Pattern correlation');
title('Within-participant spatial similarity of components 1 and 2');
set(gca,'FontSize',13,'GridAlpha',.18);
save_panel(fig,'S09_ComponentPatternCorrelation',figure_path,CFG);

% Match the original-scale means/SEMs used in R. Read the same final MATLAB
% summaries, so first-time replication does not require R before plotting.
stats_path = fullfile(CFG.common.data_path,'FREQNESS_Mocap_Stats_Results', ...
    [CFG.common.filter_output_tag '_recovered_dyads']);
for compi = 1:2
    for outcomei = 1:3
        outcomes = {'RR','DET','Mirror'}; outcome = outcomes{outcomei};
        if outcomei<3
            this_path = fullfile(stats_path,CFG.block6.output_tag, ...
                sprintf('Component_%d',compi),outcome);
            S = load(fullfile(CFG.block6.output_path,sprintf('Component_%d',compi), ...
                sprintf('FREQNESS_PHASERQA_SUMMARY_Comp#%d.mat',compi)), ...
                'PhaseRQA','list_dyads','CFG');
            metric = S.PhaseRQA.output.(outcome);
        else
            this_path = fullfile(stats_path,'SpatialCoordination','Raw', ...
                sprintf('Component_%d',compi),outcome);
            S = load(fullfile(CFG.block3.output_path,sprintf('Component_%d',compi), ...
                sprintf('FREQNESS_SPATIAL_SUMMARY_Comp#%d.mat',compi)), ...
                'MIRROR','list_dyads','CFG');
            metric = S.MIRROR;
        end
        assert(isequal(S.list_dyads,1:35) && isequal(S.CFG.common.trial_indices,CFG.common.trial_indices));
        metric = mean(metric,4,'omitnan'); % dyad x condition x metric level
        fig = figure('Color','w','Position',[50 50 1000 700]);
        tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
        levels = [.25 .5 1 2];
        for metri = 1:4
            mu = reshape(mean(metric(:,:,metri),1),4,1);
            sem = reshape(std(metric(:,:,metri),0,1)/sqrt(35),4,1);
            % When existing R outputs are present, verify identical plotted values.
            csv_file = fullfile(this_path,sprintf('Meter_%gx',levels(metri)), ...
                'Descriptive_Statistics_Raw_Scale.csv');
            if isfile(csv_file)
                T = readtable(csv_file);
                assert(all(T.n==35) && max(abs(mu-T.mean))<1e-12 && max(abs(sem-T.sem))<1e-12);
            end
            nexttile; condition_panel(["No" "No" "Yes" "Yes"], ...
                ["Diff" "Same" "Diff" "Same"],mu,mu-sem,mu+sem);
            title(meterlabels{metri}); ylabel(outcome);
        end
        save_panel(fig,sprintf('S10_C%d_%s',compi,outcome),figure_path,CFG);
    end
end
fig = figure('Color','w','Position',[50 50 1100 750]);
tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
levels = {'Global','M1','M2','M3','M4'};
labels = [{'Global'},meterlabels];
S = load(fullfile(CFG.block4.output_path,'Component_1','FREQNESS_METRIC_SUMMARY.mat'), ...
    'prominence','CFG');
assert(isequal(S.CFG.common.trial_indices,CFG.common.trial_indices));
metric = reshape(mean(S.prominence,3,'omitnan'),35,4,5);
for leveli = 1:5
    mu = reshape(mean(metric(:,:,leveli),1),4,1);
    sem = reshape(std(metric(:,:,leveli),0,1)/sqrt(35),4,1);
    nexttile; condition_panel(["No" "No" "Yes" "Yes"], ...
        ["Diff" "Same" "Diff" "Same"],mu,mu-sem,mu+sem);
    title(labels{leveli}); ylabel('Metric prominence');
end
save_panel(fig,'S11_MetricProminence',figure_path,CFG);
fig = figure('Color','w','Position',[50 50 1000 420]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
outcomes = {'Component','Entropy'};
S = load(fullfile(CFG.block5.output_path,'Component_1','FREQNESS_SIMILARITY_SUMMARY.mat'), ...
    'similarity','CFG');
assert(isequal(S.CFG.common.trial_indices,CFG.common.trial_indices));
metric = reshape(mean(atanh(S.similarity),3,'omitnan'),35,4,2);
for outcomei = 1:2
    mu = reshape(mean(metric(:,:,outcomei),1),4,1);
    sem = reshape(std(metric(:,:,outcomei),0,1)/sqrt(35),4,1);
    nexttile; condition_panel(["No" "No" "Yes" "Yes"], ...
        ["Diff" "Same" "Diff" "Same"],tanh(mu),tanh(mu-sem),tanh(mu+sem));
    title([outcomes{outcomei} ' landscape']); ylabel('Landscape correlation');
end
save_panel(fig,'S12_LandscapeSimilarity',figure_path,CFG);

% Numerical provenance for the Word supplement; no inferential tests on
% re-estimation controls are implied by these descriptive summaries.
REPORT.ndyads = 35;
REPORT.ntrials = sum(CFG.common.trial_counts,'all');
REPORT.maximum_baseline_error = max(baseline_error,[],'all');
REPORT.top_two_metric_percent = reshape(mean(sum(evals_avg(:,:,:, [2 4 8 16]).* ...
    reshape([1 1 zeros(1,64)],1,1,66,1),3),[1 2]),1,4);
REPORT.ed_metric_mean = reshape(mean(ED_avg(:,:,[2 4 8 16]),[1 2]),1,4);
REPORT.control_labels = {'GED_bw025','GED_bw050','GED_bw100','GED_bw200','GED_bw400', ...
    'PCA_bw025','PCA_bw050','PCA_bw100','PCA_bw200','PCA_bw400', ...
    'GED_velocity','PCA_velocity','GED_X','GED_Y','GED_Z'};
REPORT.control_first_component = reshape(mean(control_evals(:,1,1,:,:),1),32,15);
REPORT.control_ED = reshape(mean(control_ED(:,1,:,:),1),32,15);
REPORT.pattern_correlation_range = [min(pattern_r_mean) max(pattern_r_mean)];
report_file = fullfile(CFG.supplementary.output_path,'DyadiDance_FigureSummary.json');
if ~isfile(report_file) || CFG.supplementary.overwrite_flag
    fid = fopen(report_file,'w'); assert(fid~=-1);
    fprintf(fid,'%s',jsonencode(REPORT,'PrettyPrint',true)); fclose(fid);
else
    assert(isequaln(jsondecode(fileread(report_file)),jsondecode(jsonencode(REPORT))), ...
        'Existing figure summary differs from the current results.');
end

%% Local figure helpers: one implementation of the publication aesthetics
function landscape_panel(values,colors)
hold on
x = log2((1:32)/8);
for compi = 1:4
    this_values = reshape(values(:,compi,:),35,32);
    mu = mean(this_values,1); sem = std(this_values,0,1)/sqrt(35);
    fill([x fliplr(x)],[mu-sem fliplr(mu+sem)],colors(compi,:), ...
        'FaceAlpha',.18,'EdgeColor','none','HandleVisibility','off');
    plot(x,mu,'Color',colors(compi,:),'LineWidth',2);
end
frequency_axis; ylim([0 100]); ylabel('Normalized eigenvalue (%)');
legend({'C1','C2','C3','C4'},'Location','northeast','FontSize',9,'NumColumns',2);
end

function ed_panel(values,color)
hold on
x = log2((1:32)/8); mu = mean(values,1); sem = std(values,0,1)/sqrt(35);
fill([x fliplr(x)],[mu-sem fliplr(mu+sem)],color,'FaceAlpha',.18,'EdgeColor','none');
plot(x,mu,'Color',color,'LineWidth',2.5);
frequency_axis; ylabel('Effective dimensionality');
end

function frequency_axis
set(gca,'XTick',-3:2,'XTickLabel',{'1/8','1/4','1/2','1','2','4'}, ...
    'XLim',[-3 2],'FontSize',12,'LineWidth',1,'GridAlpha',.18);
xlabel('Frequency (x beat)'); grid on; box on
end

function condition_panel(visual,music,mu,lo,hi)
hold on
visual = string(visual); music = string(music);
colors = [.6 0 0; 0 .2 .6]; groups = ["No" "Yes"];
for groupi = 1:2
    idx = [find(visual==groups(groupi) & music=="Diff"), ...
        find(visual==groups(groupi) & music=="Same")];
    assert(numel(idx)==2);
    errorbar(1:2,mu(idx),mu(idx)-lo(idx),hi(idx)-mu(idx),'-o', ...
        'Color',colors(groupi,:),'LineWidth',1.7,'MarkerFaceColor',colors(groupi,:), ...
        'MarkerSize',6,'CapSize',8);
end
set(gca,'XTick',[1 2],'XTickLabel',{'Different','Same'},'XLim',[.6 2.4], ...
    'FontSize',13,'GridAlpha',.18,'Box','off');
xlabel('Music'); grid on
legend({'No visual contact','Visual contact'},'Location','best','FontSize',10);
end

function spatial_panel(avg_pats,sem_pats,marker_reference,compi,axisi)
hold on
bones = [1 2;1 4;2 3;3 4;5 6;5 7;6 7;6 8;8 9;9 10; ...
    7 11;11 12;12 13;14 15;14 16;15 16;15 17;17 18;18 19;16 20;20 21;21 22];
this_max = max(avg_pats,[],'all'); sem_max = max(sem_pats,[],'all');
for subi = 1:2
    xyz = reshape(marker_reference(:,1,subi),3,22)';
    % Orthographic projection of view(60,30), avoiding 3-D export clipping.
    projection = [cosd(60) sind(60) 0; ...
        -sind(60)*sind(30) cosd(60)*sind(30) cosd(30)];
    xy = xyz*projection';
    activation = avg_pats(axisi:3:66,compi,subi)/max(this_max,realmin);
    % As in the source figures, marker size reflects inverse normalized SEM.
    marker_size = 30+70*(1-sem_pats(1:3:66,compi,subi)/max(sem_max,realmin));
    for bonei = 1:size(bones,1)
        p = xy(bones(bonei,:),:);
        plot(p(:,1),p(:,2),'k-','LineWidth',1);
    end
    scatter(xy(:,1),xy(:,2),marker_size,activation,'filled');
end
% The original magnitude maps used the positive (green-to-red) half of jet.
map = .95*jet(1000); colormap(gca,map(501:end,:)); clim([0 1]);
axis equal; axis tight; axis off
% Leave room for marker discs at the projected edges of each panel.
limits = axis;
padding = .12*[diff(limits(1:2)) diff(limits(3:4))];
axis(limits+reshape([-padding; padding],1,4));
set(gca,'FontSize',10);
end

function save_panel(fig,name,figure_path,CFG)
drawnow
if ~isfile(fullfile(figure_path,[name '.png'])) || CFG.supplementary.overwrite_flag
    exportgraphics(fig,fullfile(figure_path,[name '.png']),'Resolution',300);
    exportgraphics(fig,fullfile(figure_path,[name '.pdf']),'ContentType','vector');
end
close(fig)
end
