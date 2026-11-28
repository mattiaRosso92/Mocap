function tests = testOrchestraLabels
% Exercise the actual provisional-label blocks without estimating any cores.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
path_study = fileparts(fileparts(mfilename('fullpath')));
pipeline = fileread(fullfile(path_study,'FREQNESS_Orchestra_Main.m'));
start = strfind(pipeline,'    % Load optional provisional identities independently');
stop = strfind(pipeline,'    visual_settings = struct(''presentation_version'',3');
testCase.TestData.settings_code = pipeline(start(1):stop(1)-1);
start = strfind(pipeline,'                % A labelled matrix is a separate presentation artifact.');
stop = strfind(pipeline,'                selected_count = selected_count+1;');
testCase.TestData.matrix_code = pipeline(start(1):stop(1)-1);
testCase.TestData.label_file = fullfile(path_study,'orchestra_provisional_labels.csv');
end

function testNumericIdsDetermineLabelsWithoutReorderingWeights(testCase)
fixture = make_fixture(testCase);
cleanup = onCleanup(@() remove_fixture(fixture.root));
state = execute_labels(testCase,fixture);
expected_labels = ["Track_13 | ViolinA 11";"Track_3 | ViolinA 1"; ...
    "Track_22 | ViolinB 9";"Track_14 | ViolinB 1"];
verifyEqual(testCase,state.matrix_labels,expected_labels);
verifyEqual(testCase,state.record.track_ids,[13;3;22;14]);
verifyEqual(testCase,state.record.status,"provisional");
verifyEqual(testCase,state.record.review_required,"Peter Keller visual inspection");
verifyEqual(testCase,strlength(state.record.source_sha256),64);
verifyEqual(testCase,strlength(state.record.mapping_sha256),64);
verifyTrue(testCase,isfile(state.record.figure_file));
verifyTrue(testCase,isfile(state.record.provenance_file));
matrix_axes = findall(state.matrix_figure,'Type','axes');
for axi = 1:numel(matrix_axes)
    dimi = matrix_axes(axi).Layout.Tile;
    image_handle = findall(matrix_axes(axi),'Type','image');
    verifyEqual(testCase,image_handle.CData,abs(fixture.pattern_signed(:,dimi)));
    verifyEqual(testCase,string(matrix_axes(axi).YTickLabel),expected_labels);
    verifyEqual(testCase,matrix_axes(axi).CLim,[0 8]);
end
verifyTrue(testCase,any(contains(string(matrix_axes(1).Parent.Title.String),'PROVISIONAL')));
end

function testResumePreservesCoreAndOriginalPresentationFiles(testCase)
fixture = make_fixture(testCase);
cleanup = onCleanup(@() remove_fixture(fixture.root));
protected_files = [fixture.core_file fixture.base_png fixture.base_metadata];
before = arrayfun(@file_hash,protected_files);
first = execute_labels(testCase,fixture);
generated = dir(first.record.figure_file);
second = execute_labels(testCase,fixture);
verifyTrue(testCase,second.reuse_labelled_matrix);
verifyEmpty(testCase,second.matrix_figure);
verifyEqual(testCase,first.record.figure_file,second.record.figure_file);
after = dir(second.record.figure_file);
verifyEqual(testCase,after.datenum,generated.datenum);
verifyEqual(testCase,arrayfun(@file_hash,protected_files),before);
saved_core = load(fixture.core_file,'pattern_signed');
verifyEqual(testCase,saved_core.pattern_signed,fixture.pattern_signed);
end

function testUnknownAndDuplicateTrackIdsAreRejected(testCase)
fixture = make_fixture(testCase);
cleanup = onCleanup(@() remove_fixture(fixture.root));
fixture.track_ids = [13;3;65;14];
verifyError(testCase,@() execute_labels(testCase,fixture),'Orchestra:UnmappedMatrixTrack');
fixture.track_ids = [13;3;13;14];
verifyError(testCase,@() execute_labels(testCase,fixture),'Orchestra:UnmappedMatrixTrack');
end

function testSourceIdsAndDuplicateMappingRowsAreRejected(testCase)
fixture = make_fixture(testCase);
cleanup = onCleanup(@() remove_fixture(fixture.root));
label_map = readtable(fixture.CFG.block3.matrix_label_file,'TextType','string');
fixture.CFG.block3.matrix_label_file = fullfile(fixture.root,'invalid_labels.csv');
label_map.track_id(1) = 65;
writetable(label_map,fixture.CFG.block3.matrix_label_file)
verifyError(testCase,@() execute_labels(testCase,fixture),'Orchestra:InvalidMatrixLabels');
label_map.track_id(1) = 2;
writetable(label_map,fixture.CFG.block3.matrix_label_file)
verifyError(testCase,@() execute_labels(testCase,fixture),'Orchestra:InvalidMatrixLabels');
end

function fixture = make_fixture(testCase)
fixture.root = tempname;
mkdir(fixture.root)
fixture.CFG.block3 = struct('matrix_labels_flag',true,'plot_matrix_flag',true, ...
    'matrix_label_file',testCase.TestData.label_file,'save_flag',true, ...
    'overwrite_flag',false,'close_figures_flag',false);
fixture.track_ids = [13;3;22;14];
fixture.pattern_signed = [-1 2 0;3 -4 0;-5 6 0;7 -8 0];
fixture.core_file = string(fullfile(fixture.root,'signed_core.mat'));
fixture.base_png = string(fullfile(fixture.root,'original_matrix.png'));
fixture.base_metadata = string(fullfile(fixture.root,'visualization_info.mat'));
pattern_signed = fixture.pattern_signed;
save(fixture.core_file,'pattern_signed')
imwrite(uint8([0 255;255 0]),fixture.base_png)
original_labels = ["Track_13";"Track_3";"Track_22";"Track_14"];
save(fixture.base_metadata,'original_labels')
end

function state = execute_labels(testCase,fixture)
CFG = fixture.CFG;
info = struct('track_ids',fixture.track_ids,'recording',"carmenD2-full-R1");
ntracks = numel(info.track_ids);
pattern_abs = abs(fixture.pattern_signed);
coordinate_denominator = max(pattern_abs,[],'all');
visual_info = struct('source_core',fixture.core_file,'original_labels_retained',true);
path_figure = fixture.root;
peak_frequency = 1.2;
observation_label = "carmen | D2 / R1";
pattern_frequency_label = '1.2 Hz';
peak_note = 'empirical grid maximum';
selected_count = 0;
matrix_label_records = cell(1,1);
matrix_figure = gobjects(0);
original_visibility = get(groot,'DefaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot,'DefaultFigureVisible',original_visibility));
set(groot,'DefaultFigureVisible','off')
evalc(testCase.TestData.settings_code);
evalc(testCase.TestData.matrix_code);
state = struct('matrix_labels',matrix_labels,'record',matrix_label_records{1}, ...
    'matrix_figure',matrix_figure,'reuse_labelled_matrix',reuse_labelled_matrix);
end

function digest = file_hash(filename)
file_id = fopen(filename,'rb');
cleanup = onCleanup(@() fclose(file_id));
bytes = fread(file_id,Inf,'*uint8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
digest = string(lower(reshape(dec2hex(typecast(engine.digest(),'uint8'),2)',1,[])));
end

function remove_fixture(root)
close(findall(groot,'Type','figure','Tag','Orchestra_matrix_provisional'))
if isfolder(root); rmdir(root,'s'); end
end
