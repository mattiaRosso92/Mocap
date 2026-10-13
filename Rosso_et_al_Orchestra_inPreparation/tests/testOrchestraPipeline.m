function tests = testOrchestraPipeline
% Exercise the actual study script on deterministic temporary CSV inputs.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.pipeline_file = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'FREQNESS_Orchestra_Main.m');
testCase.TestData.pipeline_text = fileread(testCase.TestData.pipeline_file);
end

function testCoreContractsAndNoPreprocessing(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
original_csv = fileread(fixture.full_files(1));
state = execute_pipeline(testCase,fixture,[true true false]);
verifyEqual(testCase,state.FULL.Status,repmat("saved",2,1));
verifyEqual(testCase,nnz(state.SEG.Status == "saved"),2);
verifyEqual(testCase,nnz(state.SEG.Status == "missing_source"),1);
verifyEqual(testCase,fileread(fixture.full_files(1)),original_csv);
for filei = 1:height(state.FULL)
    saved = load(state.FULL.CoreFile(filei));
    input = readmatrix(state.FULL.SourceFile(filei),'NumHeaderLines',1);
    ntracks = (size(input,2)-1)/2;
    npnts = size(input,1);
    markData = zeros(3*ntracks,npnts);
    markData(1:3:end,:) = input(:,2:2:end)';
    markData(2:3:end,:) = input(:,3:2:end)';
    verifyEqual(testCase,saved.marker_position,markData(:,1));
    verifyEqual(testCase,saved.analysis_info.track_ids,1:ntracks);
    verifyEqual(testCase,saved.analysis_info.frame_first,1);
    verifyEqual(testCase,saved.analysis_info.frame_last,npnts);
    verifySize(testCase,saved.GED.evals,[3*ntracks 3]);
    verifySize(testCase,saved.GED.ts,[2 npnts 3]);
    verifyEqual(testCase,sum(saved.GED.evals,1),100*ones(1,3),'AbsTol',1e-9);
    verifyTrue(testCase,all(diff(saved.GED.evals,1,1) <= 1e-10,'all'));
    verifyEmpty(testCase,saved.GED.bad_segments);
    verifyEqual(testCase,saved.GED.filter_width_calibration,"legacy");
    evalc(['expected = FREQNESS_NetworkEstimation_Mocap(markData,' ...
        'saved.frex,saved.srate,''ncomps'',2,''interpolate_gaps'',false,' ...
        '''fwidth'',saved.GED.fwhm,''regularisation'',.01);']);
    verifyEqual(testCase,saved.GED.evals,expected.evals,'AbsTol',1e-10);
end
saved = load(state.SEG.CoreFile(find(state.SEG.Status == "saved",1)));
verifyEqual(testCase,saved.analysis_info.stage,"segment_piece");
verifyEqual(testCase,saved.analysis_info.frame_first,26);
verifyEqual(testCase,saved.analysis_info.frame_last,175);
verifyEqual(testCase,size(saved.GED.ts,2),150);
verifyEqual(testCase,saved.analysis_info.segment.audio_start_s,1);
verifyEqual(testCase,saved.marklabels,{'Track_1','Track_2','Track_3'});
verifyEqual(testCase,saved.marker_position(3:3:end),zeros(3,1));
end

function testResumeAndRejectChangedSource(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
first = execute_pipeline(testCase,fixture,[true true false]);
before = dir(first.FULL.CoreFile(1));
second = execute_pipeline(testCase,fixture,[true true false]);
after = dir(first.FULL.CoreFile(1));
verifyEqual(testCase,second.FULL.Status,repmat("existing",2,1));
verifyEqual(testCase,nnz(second.SEG.Status == "existing"),2);
verifyEqual(testCase,after.datenum,before.datenum);
data = readtable(fixture.full_files(1),'VariableNamingRule','preserve');
data{1,2} = 987654.321;
writetable(data,fixture.full_files(1));
verifyError(testCase,@() execute_pipeline(testCase,fixture,[true false false]), ...
    'Orchestra:IncompatibleCore');
end

function testRejectNonfiniteAndMismatchedCoordinates(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
data = readtable(fixture.full_files(1),'VariableNamingRule','preserve');
original_value = data{1,2};
data{1,2} = NaN;
writetable(data,fixture.full_files(1));
verifyError(testCase,@() execute_pipeline(testCase,fixture,[true false false]), ...
    'Orchestra:InvalidMovementData');
data{1,2} = original_value;
data.Properties.VariableNames{3} = '99y';
writetable(data,fixture.full_files(1));
verifyError(testCase,@() execute_pipeline(testCase,fixture,[true false false]), ...
    'Orchestra:InvalidCoordinates');
end

function testSegmentsRunWithoutFullPieceInputs(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
rmdir(fullfile(fixture.data_path,'full-piece-data-fixed-despiked'),'s');
state = execute_pipeline(testCase,fixture,[false true false]);
verifyEqual(testCase,nnz(state.SEG.Status == "saved"),2);
verifyEqual(testCase,nnz(state.SEG.Status == "missing_source"),1);
end

function testMixedTextAndNumericSectionLabels(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
files = dir(fullfile(fixture.data_path,'segment-piece-data-fixed-despiked', ...
    '*','*','segments_manifest.csv'));
manifest_file = fullfile(files(1).folder,files(1).name);
manifest = readtable(manifest_file,'TextType','string');
manifest = manifest(ones(14,1),:);
manifest.index = (1:14)';
manifest.label = ["Start"; string((2:14)')];
manifest.file = ["01_A.csv"; compose('%02d_MISSING.csv',(2:14)')];
writetable(manifest,manifest_file);
state = execute_pipeline(testCase,fixture,[false true false]);
verifyEqual(testCase,state.SEG.SegmentLabel(1:14),manifest.label);
saved = load(state.SEG.CoreFile(1),'analysis_info');
verifyEqual(testCase,saved.analysis_info.segment.label,"Start");
end

function testVisualizationRunsFromSavedCoresWithoutInputs(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
execute_pipeline(testCase,fixture,[true true false]);
rmdir(fixture.data_path,'s');
state = execute_pipeline(testCase,fixture,[false false true]);
files = dir(fullfile(state.CFG.block3.output_path,'**','*.png'));
verifyNumElements(testCase,files,12);
metadata = dir(fullfile(state.CFG.block3.output_path,'**','visualization_info.mat'));
verifyNumElements(testCase,metadata,4);
saved = load(fullfile(metadata(1).folder,metadata(1).name));
verifyEqual(testCase,saved.visual_info.requested_frex,1.1);
verifyEqual(testCase,saved.visual_info.actual_frex,1);
verifyTrue(testCase,all(isfile(saved.figure_files)));
verifyEmpty(testCase,findall(groot,'Type','figure'));
before = files(1).datenum;
execute_pipeline(testCase,fixture,[false false true]);
after = dir(fullfile(files(1).folder,files(1).name));
verifyEqual(testCase,after.datenum,before);
end

function testPhysicalCalibrationUsesSeparateOutputRoute(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
legacy = execute_pipeline(testCase,fixture,[true false false]);
physical = execute_pipeline(testCase,fixture,[true false false],true);
verifyNotEqual(testCase,legacy.CFG.common.results_path,physical.CFG.common.results_path);
saved = load(physical.FULL.CoreFile(1));
verifyEqual(testCase,saved.GED.filter_width_calibration,"physical");
verifyEqual(testCase,saved.GED.fwhm, ...
    FREQNESS_ComputeFilterWidths_Mocap(saved.frex,'logarithmic'));
end

function fixture = make_fixture()
fixture.root = tempname;
fixture.data_path = fullfile(fixture.root,'data');
fixture.output_path = fullfile(fixture.root,'outputs');
recordings = ["carmenD2-full-R1_swapfixed_intervalfixed" ...
    "carmenfullconcert-1_swapfixed_intervalfixed"];
fixture.full_files = strings(2,1);
for filei = 1:2
    ntracks = filei+2;
    npnts = 225+25*filei;
    time = (0:npnts-1)'/25;
    values = zeros(npnts,1+2*ntracks);
    values(:,1) = (1:npnts)';
    names = cell(1,1+2*ntracks);
    names{1} = 'frame';
    for marki = 1:ntracks
        values(:,2*marki) = 100*marki+sin(2*pi*time)+.3*cos(2*pi*(.6+.1*marki)*time);
        values(:,2*marki+1) = 50*marki+cos(2*pi*time+.2*marki)+.2*sin(2*pi*2*time);
        names{2*marki} = sprintf('%dx',marki);
        names{2*marki+1} = sprintf('%dy',marki);
    end
    data = array2table(values,'VariableNames',names);
    path_full = fullfile(fixture.data_path,'full-piece-data-fixed-despiked','carmen');
    if ~isfolder(path_full); mkdir(path_full); end
    fixture.full_files(filei) = fullfile(path_full,recordings(filei)+".csv");
    writetable(data,fixture.full_files(filei));
    path_segment = fullfile(fixture.data_path,'segment-piece-data-fixed-despiked', ...
        'Carmen',recordings(filei));
    mkdir(path_segment)
    writetable(data(26:175,:),fullfile(path_segment,'01_A.csv'));
    manifest = table(1,"A",1,7,25,175,150,"01_A.csv", ...
        'VariableNames',{'index','label','audio_start_s','audio_end_s', ...
        'start_row_index','end_row_index_exclusive','frames','file'});
    if filei == 1
        manifest(2,:) = {2,"Missing",7,8,175,200,25,"02_MISSING.csv"};
    end
    writetable(manifest,fullfile(path_segment,'segments_manifest.csv'));
end
end

function state = execute_pipeline(testCase,fixture,run_blocks,physical_flag)
% Override settings in memory, then execute the real script without clear.
if nargin < 4; physical_flag = false; end
code = testCase.TestData.pipeline_text;
start = strfind(code,'%% BLOCK 0 -');
code = code(start(1):end);
code = strrep(code,'script_file = mfilename(''fullpath'');', ...
    sprintf('script_file = ''%s'';',testCase.TestData.pipeline_file));
code = strrep(code, ...
    'CFG.common.data_path = fullfile(path_study,''concertproject_kiersten'',''data'');', ...
    sprintf('CFG.common.data_path = ''%s'';',fixture.data_path));
code = strrep(code,'CFG.common.output_path = fullfile(path_study,''FREQNESS_Output'');', ...
    sprintf('CFG.common.output_path = ''%s'';',fixture.output_path));
code = strrep(code,'CFG.common.frex = .5:.1:10;','CFG.common.frex = [.5 1 2];');
code = strrep(code,'CFG.common.ncomps = 4;','CFG.common.ncomps = 2;');
code = strrep(code,'CFG.block3.pattern_frex = 2;','CFG.block3.pattern_frex = 1.1;');
for blocki = 1:3
    code = regexprep(code,sprintf('CFG.block%d.run_flag = (true|false);',blocki), ...
        sprintf('CFG.block%d.run_flag = logical(%d);',blocki,run_blocks(blocki)));
end
if physical_flag
    code = strrep(code,'''legacy'',{''physical'',''legacy''}', ...
        '''physical'',{''physical'',''legacy''}');
end
evalc(code);
state.CFG = CFG;
if exist('FULL','var'); state.FULL = FULL; end
if exist('SEG','var'); state.SEG = SEG; end
end
