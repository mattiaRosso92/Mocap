function summary = EmpaticMirroring_RunGroupAnalysis(dyadManifest,config)
%EMPATICMIRRORING_RUNGROUPANALYSIS Build BLOCK 5 group summaries.
%   Individual FREQ and landscape files are streamed one condition at a
%   time. Repetitions are averaged within participant before group mean/SEM.

validateBlock5Inputs(dyadManifest,config);
ensureFolder(config.block5.output_path);
if config.block5.make_figures
    ensureFolder(config.block5.figure_path);
end

coreFiles = resolveCoreFiles(dyadManifest);
landscapeFiles = resolveLandscapeFiles(coreFiles,dyadManifest,config);
eligibleRows = find(strlength(coreFiles) > 0 & isfile(coreFiles) & ...
    strlength(landscapeFiles) > 0 & isfile(landscapeFiles));
if isfinite(config.block5.max_dyads)
    eligibleRows = eligibleRows(1:min( ...
        numel(eligibleRows),config.block5.max_dyads));
end
if isempty(eligibleRows)
    error('EmpaticMirroring:GroupMissingInputs', ...
        'BLOCK 5 requires existing BLOCK 1 and BLOCK 2 outputs.');
end
[analysisRows,design] = EmpaticMirroring_IndexAnalysisRows( ...
    dyadManifest,eligibleRows);

firstCore = load(coreFiles(eligibleRows(1)),'FREQ','marker_reference');
firstLandscape = load(landscapeFiles(eligibleRows(1)),'ED_trial');
validateNetworkInputs(firstCore,firstLandscape,config);
nCoordinates = size(firstCore.FREQ.evals,1);
nfrex = size(firstCore.FREQ.evals,2);
nsubs = size(firstCore.FREQ.evals,3);
ncomps = config.block5.ncomps2keep;

avg_evals = nan(design.nconds,nCoordinates,nfrex);
sem_evals = nan(design.nconds,nCoordinates,nfrex);
avg_pats = nan(design.nconds,nCoordinates,ncomps,nfrex,nsubs);
sem_pats = nan(design.nconds,nCoordinates,ncomps,nfrex,nsubs);
avg_ED = nan(design.nconds,nfrex);
sem_ED = nan(design.nconds,nfrex);
avg_pattern_correlation = nan(design.nconds,nfrex,nsubs);
sem_pattern_correlation = nan(design.nconds,nfrex,nsubs);
participantCounts = zeros(design.nconds,1);
frex2plot = firstCore.FREQ.frex_norm(:,1);
marker_reference = firstCore.marker_reference;
marklabels = defaultMarkerLabels(nCoordinates);
firstDyadFile = string(dyadManifest.DyadFile(eligibleRows(1)));
if isfile(firstDyadFile)
    labelInput = load(firstDyadFile,'marklabels');
    if isfield(labelInput,'marklabels') && ...
            numel(labelInput.marklabels) == nCoordinates/3
        marklabels = labelInput.marklabels;
    end
end

for condi = 1:design.nconds
    evalSum = zeros(design.nparticipants,nCoordinates,nfrex,nsubs);
    patSum = zeros(design.nparticipants,nCoordinates,ncomps,nfrex,nsubs);
    edSum = zeros(design.nparticipants,nfrex,nsubs);
    correlationSum = zeros(design.nparticipants,nfrex,nsubs);
    correlationCount = zeros(design.nparticipants,nfrex,nsubs);
    repetitionCount = zeros(design.nparticipants,1);
    rows = find(analysisRows.ConditionIndex == condi);

    for rowPosition = rows'
        rowIndex = eligibleRows(rowPosition);
        S = load(coreFiles(rowIndex),'FREQ');
        L = load(landscapeFiles(rowIndex),'ED_trial');
        validateNetworkInputs(S,L,config);
        [FREQ,~] = EmpaticMirroring_CorrectNumericalEigenvalues( ...
            S.FREQ,config.block2.eigenvalue_negative_tolerance);
        participanti = analysisRows.ParticipantIndex(rowPosition);
        evalSum(participanti,:,:,:) = ...
            evalSum(participanti,:,:,:) + reshape(FREQ.evals, ...
            [1 nCoordinates nfrex nsubs]);
        patSum(participanti,:,:,:,:) = ...
            patSum(participanti,:,:,:,:) + ...
            reshape(abs(FREQ.pats(:,1:ncomps,:,:)), ...
            [1 nCoordinates ncomps nfrex nsubs]);
        edSum(participanti,:,:) = ...
            edSum(participanti,:,:) + reshape(L.ED_trial, ...
            [1 nfrex nsubs]);
        if ncomps >= 2
            for subi = 1:nsubs
                for frexi = 1:nfrex
                    value = corr(abs(FREQ.pats(:,1,frexi,subi)), ...
                        abs(FREQ.pats(:,2,frexi,subi)));
                    if isfinite(value)
                        correlationSum(participanti,frexi,subi) = ...
                            correlationSum(participanti,frexi,subi) + value;
                        correlationCount(participanti,frexi,subi) = ...
                            correlationCount(participanti,frexi,subi) + 1;
                    end
                end
            end
        end
        repetitionCount(participanti) = repetitionCount(participanti) + 1;
    end

    [evalParticipant,patParticipant,edParticipant] = deal( ...
        nan(size(evalSum)),nan(size(patSum)),nan(size(edSum)));
    retainedParticipants = find(repetitionCount > 0);
    for participanti = retainedParticipants'
        evalParticipant(participanti,:,:,:) = ...
            evalSum(participanti,:,:,:)/repetitionCount(participanti);
        patParticipant(participanti,:,:,:,:) = ...
            patSum(participanti,:,:,:,:)/repetitionCount(participanti);
        edParticipant(participanti,:,:) = ...
            edSum(participanti,:,:)/repetitionCount(participanti);
    end
    participantCounts(condi) = numel(retainedParticipants);

    evalParticipant = mean(evalParticipant,4,'omitnan');
    edParticipant = mean(edParticipant,3,'omitnan');
    [mu,se] = meanSemFirstDimension(evalParticipant);
    avg_evals(condi,:,:) = reshape(mu,[1 nCoordinates nfrex]);
    sem_evals(condi,:,:) = reshape(se,[1 nCoordinates nfrex]);
    [mu,se] = meanSemFirstDimension(patParticipant);
    avg_pats(condi,:,:,:,:) = reshape(mu, ...
        [1 nCoordinates ncomps nfrex nsubs]);
    sem_pats(condi,:,:,:,:) = reshape(se, ...
        [1 nCoordinates ncomps nfrex nsubs]);
    [mu,se] = meanSemFirstDimension(edParticipant);
    avg_ED(condi,:) = reshape(mu,[1 nfrex]);
    sem_ED(condi,:) = reshape(se,[1 nfrex]);
    correlationParticipant = correlationSum./max(correlationCount,1);
    correlationParticipant(correlationCount == 0) = NaN;
    [mu,se] = meanSemFirstDimension(correlationParticipant);
    avg_pattern_correlation(condi,:,:) = reshape(mu,[1 nfrex nsubs]);
    sem_pattern_correlation(condi,:,:) = reshape(se,[1 nfrex nsubs]);
end

designTable = design.designTable;
participantIds = design.participantIds;
networkSummaryFile = fullfile(config.block5.output_path, ...
    'FREQNESS_GroupAnalysisSummary.mat');
if config.block5.save_flag
    save(networkSummaryFile,'avg_evals','sem_evals','avg_pats', ...
        'sem_pats','avg_ED','sem_ED','avg_pattern_correlation', ...
        'sem_pattern_correlation','frex2plot','participantCounts', ...
        'analysisRows','designTable','participantIds', ...
        'marker_reference','marklabels','-v7.3');
end

coordinationGroup = summarizeCoordination(config,designTable);
phaseGroup = summarizePhaseRQA(config,designTable);
secondarySummaryFile = fullfile(config.block5.output_path, ...
    'FREQNESS_GroupCoordinationSummary.mat');
if config.block5.save_flag
    save(secondarySummaryFile,'coordinationGroup','phaseGroup', ...
        'designTable','-v7.3');
end

figureFiles = strings(0,1);
if config.block5.make_figures
    figureFiles = createGroupFigures(avg_evals,sem_evals,avg_pats, ...
        avg_ED,sem_ED,avg_pattern_correlation,frex2plot, ...
        marker_reference,marklabels,coordinationGroup,phaseGroup, ...
        designTable,config);
end

summary = struct( ...
    'recordingCount',numel(eligibleRows), ...
    'participantCount',design.nparticipants, ...
    'conditionCount',design.nconds, ...
    'networkSummaryFile',string(networkSummaryFile), ...
    'secondarySummaryFile',string(secondarySummaryFile), ...
    'figureFiles',figureFiles);

fprintf('BLOCK 5 group summaries created from %d recordings.\n', ...
    summary.recordingCount);

end


function labels = defaultMarkerLabels(nCoordinates)

if mod(nCoordinates,3) ~= 0
    error('EmpaticMirroring:GroupMarkerTriplets', ...
        'MoCap coordinates must be organized in XYZ triplets.');
end
labels = cellstr("Marker " + string(1:nCoordinates/3));

end


function validateBlock5Inputs(dyadManifest,config)

requiredManifest = {'DyadFile','Subject','TrialIndex','Instruction', ...
    'Complexity','Version','Movement'};
required = {'output_path','figure_path','overwrite_flag','save_flag', ...
    'make_figures','ncomps2keep','pattern_components', ...
    'pattern_frequencies','plot_pattern_bones','max_dyads'};
if ~istable(dyadManifest) || ...
        ~all(ismember(requiredManifest,dyadManifest.Properties.VariableNames))
    error('EmpaticMirroring:GroupManifest', ...
        'dyadManifest is missing fields required for BLOCK 5.');
end
if ~isstruct(config) || ~isfield(config,'block5') || ...
        ~all(isfield(config.block5,required))
    error('EmpaticMirroring:GroupConfiguration', ...
        'The BLOCK 5 configuration is incomplete.');
end
logicalFields = {'overwrite_flag','save_flag','make_figures', ...
    'plot_pattern_bones'};
for fieldi = 1:numel(logicalFields)
    value = config.block5.(logicalFields{fieldi});
    if ~islogical(value) || ~isscalar(value)
        error('EmpaticMirroring:GroupFlags', ...
            'config.block5.%s must be one logical value.', ...
            logicalFields{fieldi});
    end
end
if ~isnumeric(config.block5.ncomps2keep) || ...
        ~isscalar(config.block5.ncomps2keep) || ...
        ~isfinite(config.block5.ncomps2keep) || ...
        config.block5.ncomps2keep < 1 || ...
        config.block5.ncomps2keep ~= round(config.block5.ncomps2keep)
    error('EmpaticMirroring:GroupComponents', ...
        'ncomps2keep must be one positive integer.');
end
if ~isnumeric(config.block5.pattern_components) || ...
        isempty(config.block5.pattern_components) || ...
        any(~isfinite(config.block5.pattern_components)) || ...
        any(config.block5.pattern_components < 1) || ...
        any(config.block5.pattern_components ~= ...
        round(config.block5.pattern_components)) || ...
        any(config.block5.pattern_components > config.block5.ncomps2keep) || ...
        numel(unique(config.block5.pattern_components)) ~= ...
        numel(config.block5.pattern_components)
    error('EmpaticMirroring:GroupPatternComponents', ...
        ['pattern_components must contain unique positive integers no ' ...
        'greater than ncomps2keep.']);
end
if ~isnumeric(config.block5.pattern_frequencies) || ...
        isempty(config.block5.pattern_frequencies) || ...
        any(~isfinite(config.block5.pattern_frequencies)) || ...
        any(config.block5.pattern_frequencies <= 0)
    error('EmpaticMirroring:GroupPatternFrequencies', ...
        'pattern_frequencies must contain positive finite values.');
end
if ~isnumeric(config.block5.max_dyads) || ...
        ~isscalar(config.block5.max_dyads) || ...
        ~(config.block5.max_dyads == Inf || ...
        (isfinite(config.block5.max_dyads) && ...
        config.block5.max_dyads >= 1 && ...
        config.block5.max_dyads == round(config.block5.max_dyads)))
    error('EmpaticMirroring:GroupMaximum', ...
        'max_dyads must be a positive integer or Inf.');
end

end


function ensureFolder(path)

if ~isfolder(path)
    mkdir(path);
end

end


function coreFiles = resolveCoreFiles(dyadManifest)

nRows = height(dyadManifest);
coreFiles = strings(nRows,1);
if ismember('CoreFile',dyadManifest.Properties.VariableNames)
    coreFiles = string(dyadManifest.CoreFile);
end
dyadFiles = string(dyadManifest.DyadFile);
for rowIndex = 1:nRows
    if strlength(coreFiles(rowIndex)) == 0 && ...
            strlength(dyadFiles(rowIndex)) > 0
        [inputFolder,inputStem] = fileparts(dyadFiles(rowIndex));
        coreFiles(rowIndex) = string(fullfile(inputFolder, ...
            "FREQNESS_CORE_" + inputStem + ".mat"));
    end
end

end


function landscapeFiles = resolveLandscapeFiles(coreFiles,dyadManifest,config)

nRows = height(dyadManifest);
landscapeFiles = strings(nRows,1);
if ismember('LandscapeFile',dyadManifest.Properties.VariableNames)
    landscapeFiles = string(dyadManifest.LandscapeFile);
end
for rowIndex = 1:nRows
    if strlength(landscapeFiles(rowIndex)) == 0 && ...
            strlength(coreFiles(rowIndex)) > 0
        [~,inputStem] = fileparts(coreFiles(rowIndex));
        unitStem = erase(string(inputStem),"FREQNESS_CORE_");
        landscapeFiles(rowIndex) = string(fullfile( ...
            config.block2.output_path, ...
            "FREQNESS_LANDSCAPE_" + unitStem + ".mat"));
    end
end

end


function validateNetworkInputs(S,L,config)

required = {'evals','pats','frex_norm'};
if ~isfield(S,'FREQ') || ~all(isfield(S.FREQ,required)) || ...
        ~isfield(L,'ED_trial') || ...
        size(S.FREQ.evals,3) ~= 2 || size(S.FREQ.pats,4) ~= 2 || ...
        size(S.FREQ.pats,2) < config.block5.ncomps2keep || ...
        ~isequal(size(L.ED_trial), ...
        [size(S.FREQ.evals,2) size(S.FREQ.evals,3)])
    error('EmpaticMirroring:GroupNetworkInput', ...
        'A BLOCK 1 or BLOCK 2 result is incompatible with BLOCK 5.');
end

end


function [mu,se] = meanSemFirstDimension(data)

n = sum(~isnan(data),1);
mu = mean(data,1,'omitnan');
se = std(data,0,1,'omitnan')./sqrt(max(n,1));
se(n == 0) = NaN;

end


function output = summarizeCoordination(config,designTable)

components = config.block3.components(:)';
output = repmat(struct('Component',[],'Mean',struct(), ...
    'SEM',struct()),1,numel(components));
for componenti = 1:numel(components)
    which_comp = components(componenti);
    file = fullfile(config.block3.output_path, ...
        ['Component_' num2str(which_comp)], ...
        ['FREQNESS_SPATIALCOORDINATION_SUMMARY_Comp#' ...
        num2str(which_comp) '.mat']);
    assert(isfile(file),'Missing BLOCK 3 summary: %s',file);
    S = load(file,'MIRROR','designTable');
    assert(isequal(S.designTable,designTable), ...
        'BLOCK 3 design table does not match BLOCK 5.');
    output(componenti).Component = which_comp;
    participantData = mean(S.MIRROR,4,'omitnan');
    [mu,se] = meanSemFirstDimension(participantData);
    output(componenti).Mean.MIRROR = ...
        reshape(mu,[size(participantData,2) size(participantData,3)]);
    output(componenti).SEM.MIRROR = ...
        reshape(se,[size(participantData,2) size(participantData,3)]);
end

end


function output = summarizePhaseRQA(config,designTable)

components = config.block4.components(:)';
fields = {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'};
output = repmat(struct('Component',[],'Mean',struct(), ...
    'SEM',struct()),1,numel(components));
for componenti = 1:numel(components)
    which_comp = components(componenti);
    file = fullfile(config.block4.output_path, ...
        ['Component_' num2str(which_comp)], ...
        ['FREQNESS_PHASERQA_SUMMARY_Comp#' num2str(which_comp) '.mat']);
    assert(isfile(file),'Missing BLOCK 4 summary: %s',file);
    S = load(file,'PhaseRQA','designTable');
    assert(isequal(S.designTable,designTable), ...
        'BLOCK 4 design table does not match BLOCK 5.');
    output(componenti).Component = which_comp;
    for fieldi = 1:numel(fields)
        participantData = mean( ...
            S.PhaseRQA.output.(fields{fieldi}),4,'omitnan');
        [mu,se] = meanSemFirstDimension(participantData);
        output(componenti).Mean.(fields{fieldi}) = ...
            reshape(mu,[size(participantData,2) size(participantData,3)]);
        output(componenti).SEM.(fields{fieldi}) = ...
            reshape(se,[size(participantData,2) size(participantData,3)]);
    end
end

end


function files = createGroupFigures(avg_evals,sem_evals,avg_pats, ...
    avg_ED,sem_ED,avg_pattern_correlation,frex,marker_reference, ...
    marklabels,coordinationGroup,phaseGroup,designTable,config)

files = strings(0,1);
conditionLabels = designTable.Instruction + "-" + ...
    designTable.Complexity + "-v" + string(designTable.Version) + ...
    "-mov" + string(designTable.Movement);
x = log2(frex(:));
ncomps = min(config.block5.ncomps2keep,size(avg_evals,2));
colors = lines(ncomps);

fig = figure('Visible',config.output.figureVisible,'Color','w');
tiledlayout(4,6,'TileSpacing','compact');
for condi = 1:height(designTable)
    nexttile; hold on
    for compi = 1:ncomps
        y = squeeze(avg_evals(condi,compi,:));
        se = squeeze(sem_evals(condi,compi,:));
        fill([x;flipud(x)],[y-se;flipud(y+se)],colors(compi,:), ...
            'FaceAlpha',.15,'EdgeColor','none');
        plot(x,y,'Color',colors(compi,:),'LineWidth',1.2);
    end
    title(conditionLabels(condi),'Interpreter','none');
end
files(end+1) = saveGroupFigure(fig,'NetworkLandscape',config);

fig = figure('Visible',config.output.figureVisible,'Color','w');
tiledlayout(4,6,'TileSpacing','compact');
for condi = 1:height(designTable)
    nexttile; hold on
    y = avg_ED(condi,:)';
    se = sem_ED(condi,:)';
    fill([x;flipud(x)],[y-se;flipud(y+se)],[.9 .22 .16], ...
        'FaceAlpha',.2,'EdgeColor','none');
    plot(x,y,'Color',[.9 .22 .16],'LineWidth',1.2);
    title(conditionLabels(condi),'Interpreter','none');
end
files(end+1) = saveGroupFigure(fig,'EffectiveDimensionality',config);

fig = figure('Visible',config.output.figureVisible,'Color','w');
plot(log2(frex),squeeze(mean(avg_pattern_correlation,[1 3],'omitnan')), ...
    'Color',[.9 .22 .16],'LineWidth',1.5);
yline(0,'k-');
ylim([-1 1]);
xlabel('Frequency (x beat)');
ylabel('Pattern correlation: components 1 and 2');
grid on
files(end+1) = saveGroupFigure( ...
    fig,'ComponentPatternCorrelation',config);

% As in the template, delegate grand-average activation patterns to the
% MoCap visualizer. Full trial patterns remain in individual FREQ files.
FREQfigure = struct();
FREQfigure.evals = squeeze(mean(avg_evals,1,'omitnan'));
FREQfigure.pats = squeeze(mean(avg_pats,1,'omitnan'));
FREQfigure.frex = frex;
patternTargets = config.block5.pattern_frequencies;
patternTargets = patternTargets(patternTargets >= min(frex) & ...
    patternTargets <= max(frex));
for compi = config.block5.pattern_components
    Patterns = struct( ...
        'frex',patternTargets, ...
        'labels',{marklabels}, ...
        'markerData',marker_reference, ...
        'comp',compi, ...
        'srate',config.sampling.outputHz, ...
        'start',.25, ...
        'bones',standardBones(numel(marklabels)), ...
        'plot_bones',config.block5.plot_pattern_bones, ...
        'plot_matrix',false, ...
        'animate',false, ...
        'frequency_unit','x beat');
    generated = FREQNESS_Visualizer_Mocap(FREQfigure,[],Patterns);
    handles = generated.patterns;
    for figurei = 1:numel(handles)
        name = sprintf('ActivationPatterns_Comp%d_Frequency%d', ...
            compi,figurei);
        files(end+1) = saveGroupFigure(handles(figurei),name,config); %#ok<AGROW>
    end
end

newFiles = metricFigures(coordinationGroup, ...
    {'MIRROR'},'SpatialCoordination',conditionLabels,config);
files = [files(:);newFiles(:)];
newFiles = metricFigures(phaseGroup, ...
    {'RR','L','DET','ENTR','TT','LAM','Vmax','DIV'}, ...
    'PhaseRQA',conditionLabels,config);
files = [files(:);newFiles(:)];
close all

end


function bones = standardBones(nmarkers)

if nmarkers == 22
    bones = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10; ...
        7,11;11,12;12,13;14,15;14,16;15,16;15,17;17,18;18,19; ...
        16,20;20,21;21,22];
else
    bones = zeros(0,2);
end

end


function files = metricFigures(results,fields,prefix,conditionLabels,config)

files = strings(0,1);
for componenti = 1:numel(results)
    for fieldi = 1:numel(fields)
        field = fields{fieldi};
        fig = figure('Visible',config.output.figureVisible,'Color','w');
        hold on
        mu = results(componenti).Mean.(field);
        se = results(componenti).SEM.(field);
        for metri = 1:size(mu,2)
            errorbar(1:size(mu,1),mu(:,metri),se(:,metri), ...
                '-o','LineWidth',1);
        end
        xticks(1:numel(conditionLabels));
        xticklabels(conditionLabels);
        xtickangle(90);
        title(sprintf('%s %s - Component %d',prefix,field, ...
            results(componenti).Component));
        legend("Metric " + string(1:size(mu,2)),'Location','best');
        grid on
        name = sprintf('%s_%s_Comp%d',prefix,field, ...
            results(componenti).Component);
        files(end+1) = saveGroupFigure(fig,name,config); %#ok<AGROW>
    end
end

end


function file = saveGroupFigure(fig,name,config)

stem = fullfile(config.block5.figure_path,name);
figFile = [stem '.fig'];
pngFile = [stem '.png'];
if ~isfile(figFile) || config.block5.overwrite_flag
    savefig(fig,figFile);
end
if ~isfile(pngFile) || config.block5.overwrite_flag
    exportgraphics(fig,pngFile,'Resolution',200);
end
file = string(pngFile);

end
