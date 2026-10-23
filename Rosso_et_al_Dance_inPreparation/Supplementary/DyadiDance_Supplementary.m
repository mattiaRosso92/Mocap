% Dyadic Dance supplementary analyses, all 35 dyads.
% Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
% Run the main pipeline first to produce the shared core and group summaries.
% Blocks 4/5 can also run after configuration alone when core files exist.
% Original block IDs, formulas, saved variables and numerical output paths are unchanged.
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


%% BLOCK 7 - SUPPLEMENTARY GROUP-LEVEL VISUALIZATION

figure_scope = 'Supplementary';
run(fullfile(fileparts(CFG.common.data_path),'Rosso_et_al_Dance_inPreparation', ...
    'Supporting','DyadiDance_GroupFigures.m'));
