function tests = testOrchestraSpatialDisplays
% Exercise the real display block using signed, rotated and zero core patterns.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
path_study = fileparts(fileparts(mfilename('fullpath')));
path_toolbox = fullfile(fileparts(path_study),'FREQNESS_Mocap_Toolbox');
testCase.TestData.original_path = path;
addpath(genpath(fullfile(path_toolbox,'FREQNESS_Functions')))
addpath(fullfile(path_toolbox,'FREQNESS_ExternalFunctions'))
fixture = make_fixture();
testCase.TestData.fixture = fixture;
testCase.TestData.core_hashes = cellfun(@file_hash,cellstr(fixture.core_files), ...
    'UniformOutput',false);
pipeline = fileread(fullfile(path_study,'FREQNESS_Orchestra_Main.m'));
start = strfind(pipeline,'%% BLOCK 3 -');
testCase.TestData.visualization_code = pipeline(start(1):end);
testCase.TestData.state = execute_visualization(testCase.TestData.visualization_code,fixture.CFG);
end

function teardownOnce(testCase)
figures = findall(groot,'Type','figure');
for figurei = 1:numel(figures)
    if startsWith(string(figures(figurei).Tag),"Orchestra_") || ...
            startsWith(string(figures(figurei).Name),"carmen |")
        close(figures(figurei))
    end
end
% The two synthetic landscape overlays have no tag/name.
state = testCase.TestData.state;
if isgraphics(state.overlay_figure); close(state.overlay_figure); end
if isfield(state,'all_figures')
    close(state.all_figures(isgraphics(state.all_figures)))
end
path(testCase.TestData.original_path)
rmdir(testCase.TestData.fixture.root,'s')
end

function testAbsoluteAndMagnitudeValuesReachFigures(testCase)
state = testCase.TestData.state;
observation = state.observations(1);
spatial = observation.spatial_display;
expected_signed = [-3 4 0;8 -6 0;0 -5 0];
verifyEqual(testCase,spatial.signed_weights,expected_signed);
verifyEqual(testCase,spatial.absolute_weights,abs(expected_signed));
verifyEqual(testCase,spatial.xy_magnitude,[5;10;5],'AbsTol',1e-12);
verifyEqual(testCase,spatial.coordinate_denominator,8);
verifyEqual(testCase,spatial.xy_denominator,10);
verifyEqual(testCase,spatial.coordinate_normalized,abs(expected_signed)/8);
verifyEqual(testCase,spatial.xy_normalized,[.5;1;.5]);
verifyEqual(testCase,observation.figure_roles,["matrix";"activation";"xy_norm"]);
verifyTrue(testCase,contains(observation.figure_files(3),'activation_xy_norm_'));
verifyTrue(testCase,all(isfile(observation.figure_files)));

label = 'carmen | D2 / R1';
matrix_figure = findall(groot,'Type','figure','Tag','Orchestra_matrix','Name',label);
matrix_axes = findall(matrix_figure,'Type','axes');
for axi = 1:numel(matrix_axes)
    image_handle = findall(matrix_axes(axi),'Type','image');
    dimi = matrix_axes(axi).Layout.Tile;
    verifyEqual(testCase,image_handle.CData,abs(expected_signed(:,dimi)));
    verifyEqual(testCase,matrix_axes(axi).CLim,[0 8]);
end
activation_figure = findall(groot,'Type','figure','Tag','Orchestra_activation','Name',label);
activation_axes = findall(activation_figure,'Type','axes');
positions = vertcat(activation_axes.Position);
[~,idx_order] = sort(positions(:,1));
activation_axes = activation_axes(idx_order);
for axi = 1:3
    scatter_handle = findall(activation_axes(axi),'Type','scatter');
    verifyEqual(testCase,scatter_handle.CData,abs(expected_signed(:,axi))/8,'AbsTol',1e-12);
    verifyEqual(testCase,activation_axes(axi).CLim,[0 1]);
end
xy_figure = findall(groot,'Type','figure','Tag','Orchestra_xy_norm','Name',label);
xy_scatter = findall(xy_figure,'Type','scatter');
verifyEqual(testCase,xy_scatter.CData,[.5;1;.5],'AbsTol',1e-12);
end

function testXyMagnitudeIsRotationInvariant(testCase)
observations = testCase.TestData.state.observations;
verifyEqual(testCase,observations(2).spatial_display.xy_magnitude, ...
    observations(1).spatial_display.xy_magnitude,'AbsTol',1e-12);
verifyEqual(testCase,observations(2).spatial_display.xy_normalized, ...
    observations(1).spatial_display.xy_normalized,'AbsTol',1e-12);
verifyEqual(testCase,observations(2).spatial_display.xy_denominator,10,'AbsTol',1e-12);
end

function testZeroPatternsStayZeroAndFinite(testCase)
spatial = testCase.TestData.state.observations(3).spatial_display;
verifyTrue(testCase,spatial.coordinate_all_zero);
verifyTrue(testCase,spatial.xy_all_zero);
verifyEqual(testCase,spatial.coordinate_max,0);
verifyEqual(testCase,spatial.xy_max,0);
verifyEqual(testCase,spatial.coordinate_denominator,1);
verifyEqual(testCase,spatial.xy_denominator,1);
verifyEqual(testCase,spatial.coordinate_normalized,zeros(3,3));
verifyEqual(testCase,spatial.xy_normalized,zeros(3,1));
xy_figure = findall(groot,'Type','figure','Tag','Orchestra_xy_norm','Name','carmen | Concert 1');
xy_scatter = findall(xy_figure,'Type','scatter');
verifyEqual(testCase,xy_scatter.CData,zeros(3,1));
end

function testCoreFilesAndSignedEstimatesRemainUnchanged(testCase)
fixture = testCase.TestData.fixture;
hashes_after = cellfun(@file_hash,cellstr(fixture.core_files),'UniformOutput',false);
verifyEqual(testCase,hashes_after,testCase.TestData.core_hashes);
saved = load(fixture.core_files(1),'GED');
verifyLessThan(testCase,min(saved.GED.pats,[],'all'),0);
catalog = jsondecode(fileread(fullfile(fixture.CFG.block3.output_path, ...
    'full_piece','figure_catalog.json')));
verifyEqual(testCase,catalog.settings.presentation_version,3);
verifyEqual(testCase,string(catalog.settings.pattern_transform),"absolute_display_copy");
verifyEqual(testCase,string(catalog.observations(1).filter_width_calibration),"physical");
verifyEqual(testCase,catalog.observations(1).spatial_display.xy_magnitude,[5;10;5]);
verifyFalse(testCase,isfield(catalog.settings,'frequency_reference'));
verifyFalse(testCase,isfield(catalog.observations,'frex_norm'));
end

function testBeatOverlayUsesSharedRatiosAndPreservesHzPeak(testCase)
fixture = make_beat_fixture();
figures_before = findall(groot,'Type','figure');
cleanup = onCleanup(@() remove_fixture(fixture.root,figures_before));
state = execute_visualization(testCase.TestData.visualization_code,fixture.CFG);
observations = state.observations;
verifyEqual(testCase,[observations.beat_frex],[2 3 1]);
verifyEqual(testCase,[observations.peak_frequency],[.5 .75 .25],'AbsTol',1e-12);
verifyEqual(testCase,[observations.peak_frequency_normalized],[.25 .25 .25],'AbsTol',1e-12);
for obsi = 1:3
    verifyEqual(testCase,observations(obsi).plot_frex,[.125 .25 .5]);
    verifyEqual(testCase,observations(obsi).frex_norm, ...
        observations(obsi).frex/observations(obsi).beat_frex,'AbsTol',1e-12);
end
verifyEqual(testCase,observations(1).insufficient_cycles,[true true true]);
verifyEqual(testCase,observations(2).insufficient_cycles,[false false false]);
verifyEqual(testCase,observations(3).insufficient_cycles,[true true false]);
overlay_axes = findall(state.overlay_figure,'Type','axes');
verifyEqual(testCase,overlay_axes.XLabel.String, ...
    'Frequency / segment beat frequency (dimensionless)');
curves = findall(overlay_axes,'Type','line','HandleVisibility','on');
verifyNumElements(testCase,curves,3);
for curvei = 1:3
    verifyEqual(testCase,curves(curvei).XData,[.125 .25 .5]);
end
verifyTrue(testCase,any(contains(string(overlay_axes.Title.String), ...
    'fewer than 3 motion cycles')));
catalog = jsondecode(fileread(fullfile(fixture.CFG.block3.output_path, ...
    'segment_piece','figure_catalog.json')));
verifyEqual(testCase,string(catalog.settings.frequency_reference),"beat");
verifyTrue(testCase,catalog.overlays.insufficient_cycles_flag);
end

function testBeatDisplayRejectsFullPieceAndInvalidNormalization(testCase)
fixture = make_beat_fixture();
figures_before = findall(groot,'Type','figure');
cleanup = onCleanup(@() remove_fixture(fixture.root,figures_before));
invalid_CFG = fixture.CFG;
invalid_CFG.block3.stages = "full_piece";
verifyError(testCase,@() execute_visualization( ...
    testCase.TestData.visualization_code,invalid_CFG),'Orchestra:FullPieceBeatDisplay');
saved = load(fixture.core_files(1));
saved.GED.frex_norm(1) = saved.GED.frex_norm(1)+.01;
save(fixture.core_files(1),'-struct','saved','-v7.3')
verifyError(testCase,@() execute_visualization( ...
    testCase.TestData.visualization_code,fixture.CFG),'Orchestra:InvalidBeatNormalization');
end

function testBeatDisplayUsesSavedNondefaultCycleThreshold(testCase)
fixture = make_beat_fixture(6);
% Display provenance must come from the saved core, even if current settings differ.
fixture.CFG.common.minimum_cycles = 3;
figures_before = findall(groot,'Type','figure');
cleanup = onCleanup(@() remove_fixture(fixture.root,figures_before));
state = execute_visualization(testCase.TestData.visualization_code,fixture.CFG);
verifyEqual(testCase,state.observations(2).insufficient_cycles,[true false false]);
verifyEqual(testCase,state.observations(3).insufficient_cycles,[true true true]);
verifyEqual(testCase,state.observations(2).frequency_support.minimum_cycles,6);
verifyTrue(testCase,contains(string(state.console_output),'fewer than 6 motion cycles'));
overlay_axes = findall(state.overlay_figure,'Type','axes');
verifyTrue(testCase,any(contains(string(overlay_axes.Title.String),'fewer than 6 motion cycles')));
xy_figure = findall(groot,'Type','figure','Tag','Orchestra_xy_norm', ...
    'Name','carmen | D2 / R1 | segment 1: A');
xy_axes = findall(xy_figure,'Type','axes');
verifyTrue(testCase,any(contains(string(xy_axes.Title.String),'fewer than 6 motion cycles at peak')));
end

function testBeatBandwidthWarningIsDistinctFromCycleCount(testCase)
fixture = make_beat_fixture();
figures_before = findall(groot,'Type','figure');
cleanup = onCleanup(@() remove_fixture(fixture.root,figures_before));
state = execute_visualization(testCase.TestData.visualization_code,fixture.CFG);
observation = state.observations(2);
verifyFalse(testCase,any(observation.insufficient_cycles));
verifyEqual(testCase,observation.bandwidth_below_resolution,[true false false]);
verifyEqual(testCase,observation.frequency_support.fft_resolution_hz,.1,'AbsTol',1e-12);
verifyEqual(testCase,observation.frequency_support.bins_per_fwhm, ...
    observation.frequency_support.fwhm_hz/.1,'AbsTol',1e-12);
overlay_axes = findall(state.overlay_figure,'Type','axes');
triangles = findall(overlay_axes,'Type','line','Marker','^');
verifyNumElements(testCase,triangles,3);
verifyEqual(testCase,sort(arrayfun(@(x) numel(x.XData),triangles)),[1;2;3]);
verifyTrue(testCase,any(contains(string(overlay_axes.Title.String),'Triangles: filter FWHM')));
xy_figure = findall(groot,'Type','figure','Tag','Orchestra_xy_norm', ...
    'Name','carmen | D2 / R1 | segment 1: A');
xy_axes = findall(xy_figure,'Type','axes');
verifyTrue(testCase,any(contains(string(xy_axes.Title.String),'peak filter narrower than Fourier spacing')));
catalog = jsondecode(fileread(fullfile(fixture.CFG.block3.output_path, ...
    'segment_piece','figure_catalog.json')));
verifyTrue(testCase,catalog.overlays.bandwidth_below_resolution_flag);
verifyTrue(testCase,contains(string(catalog.settings.bandwidth_warning),'Fourier_spacing'));

% The displayed warnings must be derived from actual saved filter widths.
saved = load(fixture.core_files(1));
saved.analysis_info.frequency_support.fwhm_hz(1) = ...
    saved.analysis_info.frequency_support.fwhm_hz(1)+.1;
save(fixture.core_files(1),'-struct','saved','-v7.3')
verifyError(testCase,@() execute_visualization( ...
    testCase.TestData.visualization_code,fixture.CFG),'Orchestra:InvalidFrequencySupport');
end

function fixture = make_fixture()
fixture.root = tempname;
fixture.CFG.common.pieces = "carmen";
fixture.CFG.common.filter_width_calibration = 'physical';
fixture.CFG.common.filter_type = 'logarithmic';
fixture.CFG.block1.output_path = fullfile(fixture.root,'full_core');
fixture.CFG.block2.output_path = fullfile(fixture.root,'segment_core');
fixture.CFG.block3 = struct('run_flag',true,'stages',"full_piece", ...
    'recordings',strings(0,1),'segment_labels',strings(0,1), ...
    'color_first',[.85 .12 .15],'color_last',[.35 .75 .94], ...
    'color_concert',[.50 .22 .70],'plot_matrix_flag',true, ...
    'save_flag',true,'overwrite_flag',false,'close_figures_flag',false, ...
    'figure_visibility','off','output_path',fullfile(fixture.root,'figures'));
path_core = fullfile(fixture.CFG.block1.output_path,'carmen');
mkdir(path_core)
recordings = ["carmenD2-full-R1" "carmenD3-full-R1" "carmenfullconcert-1"];
fixture.core_files = strings(3,1);
base_pattern = [-3 4 0;8 -6 0;0 -5 0];
angle = pi/5;
rotation = [cos(angle) -sin(angle);sin(angle) cos(angle)];
for filei = 1:3
    pattern = base_pattern;
    if filei == 2; pattern(:,1:2) = pattern(:,1:2)*rotation'; end
    if filei == 3; pattern(:) = 0; end
    frex = [.5 1 2];
    leading = [30 65 25];
    GED = struct('evals',[leading;repmat((100-leading)/8,8,1)], ...
        'pats',repmat(reshape(pattern',9,1),1,1,3),'frex',frex);
    analysis_info = struct('piece',"carmen",'recording',recordings(filei), ...
        'track_ids',[11 7 42],'npnts',250,'srate',25,'srate_confirmed',true, ...
        'frex',frex,'filterWidthCalibration',"physical",'filter',"logarithmic", ...
        'segment',struct(),'timing_provenance',struct( ...
        'srate_confirmation_source',"synthetic_fixture",'srate_confirmation_date',"", ...
        'camera_metadata_verified',false,'audio_alignment_status',"not_applicable"));
    marker_position = [100;50;0;200;150;0;130;220;0];
    marklabels = {'Track_11','Track_7','Track_42'};
    fixture.core_files(filei) = fullfile(path_core,"GED_"+recordings(filei)+".mat");
    save(fixture.core_files(filei),'GED','analysis_info','marker_position','marklabels','-v7.3')
end
end

function fixture = make_beat_fixture(minimum_cycles)
if nargin < 1; minimum_cycles = 3; end
fixture = make_fixture();
fixture.CFG.common.frequency_reference = 'beat';
fixture.CFG.block3.stages = "segment_piece";
recording = "carmenD2-full-R1";
path_core = fullfile(fixture.CFG.block2.output_path,'carmen',recording);
mkdir(path_core)
beat_frequencies = [2 3 1];
for filei = 1:3
    saved = load(fixture.core_files(filei));
    info = saved.analysis_info;
    info.recording = recording;
    info.segment = struct('index',filei,'label',string(char('A'+filei-1)));
    info.frequency_reference = "beat";
    info.beat_frex = beat_frequencies(filei);
    info.beat_ratios = [.125;.25;.5];
    info.frex = info.beat_frex*info.beat_ratios;
    info.frex_norm = info.frex/info.beat_frex;
    if filei == 1; info.npnts = 50; end
    motion_duration = info.npnts/info.srate;
    fwhm_hz = FREQNESS_ComputeFilterWidths_Mocap(info.frex,'logarithmic');
    fft_resolution_hz = info.srate/info.npnts;
    info.frequency_support = struct('minimum_cycles',minimum_cycles, ...
        'motion_duration_s',motion_duration,'cycles_observed',info.frex*motion_duration, ...
        'insufficient_cycles_flag',info.frex*motion_duration < minimum_cycles, ...
        'fft_resolution_hz',fft_resolution_hz,'fwhm_hz',fwhm_hz, ...
        'bins_per_fwhm',fwhm_hz/fft_resolution_hz, ...
        'bandwidth_below_resolution_flag',fwhm_hz/fft_resolution_hz < 1, ...
        'rule',"descriptive_cycle_count_not_filter_validity");
    info.tempo_provenance = struct('catalog_file',"synthetic_fixture", ...
        'observation',struct('decision',"accepted",'beat_bpm',60*info.beat_frex));
    saved.analysis_info = info;
    saved.GED.frex = info.frex;
    saved.GED.frex_norm = info.frex_norm;
    saved.GED.beat_frex = info.beat_frex;
    saved.GED.fwhm = fwhm_hz;
    fixture.core_files(filei) = fullfile(path_core,sprintf('GED_%02d.mat',filei));
    save(fixture.core_files(filei),'-struct','saved','-v7.3')
end
end

function remove_fixture(root,figures_before)
figures_after = findall(groot,'Type','figure');
close(setdiff(figures_after,figures_before))
rmdir(root,'s')
end

function state = execute_visualization(code,CFG)
% Execute Block 3 alone; no core estimation or input trajectories are needed.
figures_before = findall(groot,'Type','figure');
console_output = evalc(code);
state = struct('observations',observations,'overlay_figure',this_figure, ...
    'all_figures',setdiff(findall(groot,'Type','figure'),figures_before), ...
    'console_output',console_output);
end

function digest = file_hash(file)
fid = fopen(file,'rb');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid,Inf,'*uint8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
digest = typecast(engine.digest(),'uint8');
end
