function tests = testOrchestraBeatCore
% Test beat-core integration with synthetic WAVs and an explicit catalog.
% No MIR estimation or private recordings are needed by these tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.pipeline_file = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'FREQNESS_Orchestra_Main.m');
testCase.TestData.pipeline_text = fileread(testCase.TestData.pipeline_file);
end

function testAcceptedTemposProducePhysicalGridsAndSupportFlags(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
source_hash = sha256_file(fixture.csv_files(1));
state = execute_core(testCase,fixture,'beat','physical',true);
verifyEqual(testCase,state.SEG.Status,["saved";"saved";"tempo_review";"tempo_review";"tempo_review"]);
verifyEqual(testCase,state.SEG.TempoStatus(4),"missing_catalog_row");
verifyFalse(testCase,isfolder(state.CFG.block1.output_path));
verifyEqual(testCase,sha256_file(fixture.csv_files(1)),source_hash);
for segi = 1:2
    saved = load(state.SEG.CoreFile(segi));
    beat_frex = segi;
    ratios = (1:16)'/8;
    verifyEqual(testCase,saved.GED.frex,beat_frex*ratios,'AbsTol',1e-12);
    verifyEqual(testCase,saved.GED.frex_norm,ratios,'AbsTol',1e-12);
    verifyEqual(testCase,saved.GED.beat_frex,beat_frex);
    verifyEqual(testCase,saved.GED.fwhm, ...
        FREQNESS_ComputeFilterWidths_Mocap(beat_frex*ratios,'logarithmic'));
    verifyEqual(testCase,saved.analysis_info.frequency_reference,"beat");
    verifyEqual(testCase,saved.analysis_info.tempo_provenance.catalog_sha256, ...
        string(sha256_file(fixture.tempo_file)));
    verifyEqual(testCase,saved.analysis_info.tempo_provenance.observation.audio_sha256, ...
        sha256_file(fixture.wav_files(segi)));
    verifyEqual(testCase,saved.analysis_info.tempo_provenance.wav_duration_s,6);
    verifyEqual(testCase,saved.analysis_info.tempo_provenance.motion_duration_s,8);
    verifyEqual(testCase,saved.analysis_info.tempo_provenance.audio_motion_duration_difference_s,-2);
    verifyEqual(testCase,saved.analysis_info.tempo_provenance.audio_alignment_status,"unresolved");
    support = saved.analysis_info.frequency_support;
    verifyEqual(testCase,support.cycles_observed,8*beat_frex*ratios,'AbsTol',1e-12);
    verifyEqual(testCase,support.insufficient_cycles_flag,8*beat_frex*ratios < 3);
    verifyTrue(testCase,any(support.insufficient_cycles_flag));
    verifyTrue(testCase,any(~support.insufficient_cycles_flag));
    verifyEqual(testCase,support.fft_resolution_hz,1/8,'AbsTol',1e-12);
    verifyEqual(testCase,support.fwhm_hz,saved.GED.fwhm);
    verifyEqual(testCase,support.bins_per_fwhm,8*saved.GED.fwhm,'AbsTol',1e-12);
    verifyEqual(testCase,support.bandwidth_below_resolution_flag,8*saved.GED.fwhm < 1);
    % Several carrier cycles do not establish resolution of a narrow band.
    verifyTrue(testCase,any(~support.insufficient_cycles_flag & ...
        support.bandwidth_below_resolution_flag));
    verifyEqual(testCase,size(saved.GED.ts,2),200);
    verifyEmpty(testCase,saved.GED.bad_segments);
    verifyEqual(testCase,sum(saved.GED.evals,1),100*ones(1,16),'AbsTol',1e-9);
end
end

function testBeatCalibrationAndCatalogRevisionUseNewRoutes(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
physical = execute_core(testCase,fixture,'beat','physical',true);
first_core = physical.SEG.CoreFile(1);
first_hash = sha256_file(first_core);
reused = execute_core(testCase,fixture,'beat','physical',true);
verifyEqual(testCase,reused.SEG.Status(1:2),["existing";"existing"]);
legacy = execute_core(testCase,fixture,'beat','legacy',true);
verifyNotEqual(testCase,legacy.CFG.common.results_path,physical.CFG.common.results_path);
saved = load(legacy.SEG.CoreFile(1));
verifyEqual(testCase,saved.GED.fwhm, ...
    FREQNESS_ComputeLegacyFilterWidths_Mocap(saved.frex,'logarithmic'));
catalog = jsondecode(fileread(fixture.tempo_file));
catalog.observations(1).beat_hz = 1.5;
catalog.observations(1).tempo_bpm = 90;
write_catalog(fixture.tempo_file,catalog);
revised = execute_core(testCase,fixture,'beat','physical',true);
verifyNotEqual(testCase,revised.CFG.common.results_path,physical.CFG.common.results_path);
verifyEqual(testCase,sha256_file(first_core),first_hash);
saved = load(revised.SEG.CoreFile(1));
verifyEqual(testCase,saved.GED.beat_frex,1.5);
end

function testHzSignatureIgnoresUnusedTempoConfiguration(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
before = execute_core(testCase,fixture,'hz','physical',false);
fixture.tempo_file = fullfile(fixture.root,'does_not_exist.json');
after = execute_core(testCase,fixture,'hz','physical',false);
verifyEqual(testCase,after.CFG.common.results_path,before.CFG.common.results_path);
verifyEqual(testCase,after.core_settings,before.core_settings);
verifyEqual(testCase,after.core_settings.contract_version,2);
verifyFalse(testCase,isfield(after.core_settings,'frequency_reference'));
verifyFalse(testCase,isfield(after.core_settings,'tempo_catalog_sha256'));
verifyEqual(testCase,after.core_settings.frex,[.5;1;2]);
end

function testRejectUnpinnedDuplicateOrWrongUnitCatalog(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
missing = fixture;
missing.tempo_file = '';
verifyError(testCase,@() execute_core(testCase,missing,'beat','physical',true), ...
    'Orchestra:TempoCatalogRequired');
catalog = jsondecode(fileread(fixture.tempo_file));
original = catalog;
catalog.observations(end+1) = catalog.observations(1);
write_catalog(fixture.tempo_file,catalog);
verifyError(testCase,@() execute_core(testCase,fixture,'beat','physical',true), ...
    'Orchestra:DuplicateTempoKey');
catalog = original;
catalog.score_section_mapping_applied = true;
write_catalog(fixture.tempo_file,catalog);
verifyError(testCase,@() execute_core(testCase,fixture,'beat','physical',true), ...
    'Orchestra:InvalidTempoCatalog');
end

function testRejectStaleAudioAndDoNotClipInvalidFrequencyGrid(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
catalog = jsondecode(fileread(fixture.tempo_file));
catalog.observations(1).beat_hz = 7;
catalog.observations(1).tempo_bpm = 420;
write_catalog(fixture.tempo_file,catalog);
state = execute_core(testCase,fixture,'beat','physical',true);
verifyEqual(testCase,state.SEG.Status(1),"tempo_review");
verifyTrue(testCase,contains(state.SEG.TempoReviewReason(1),'Nyquist'));
verifyEqual(testCase,state.SEG.CoreFile(1),"");
% A different source waveform cannot borrow an earlier accepted tempo.
audio = audioread(fixture.wav_files(2));
audio(1) = .5;
audiowrite(fixture.wav_files(2),audio,8000);
verifyError(testCase,@() execute_core(testCase,fixture,'beat','physical',true), ...
    'Orchestra:TempoAudioMismatch');
end

function testRejectFullPieceBeatEstimation(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
verifyError(testCase,@() execute_core(testCase,fixture,'beat','physical',true,true), ...
    'Orchestra:BeatFullPieceUnsupported');
end

function testRejectStaleMotionMapping(testCase)
fixture = make_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s'));
catalog = jsondecode(fileread(fixture.tempo_file));
original = catalog;
% Keep the segment key and WAV fixed but point the tempo to another CSV.
catalog.observations(1).source_csv = char(fixture.csv_files(2));
write_catalog(fixture.tempo_file,catalog);
verifyError(testCase,@() execute_core(testCase,fixture,'beat','physical',true), ...
    'Orchestra:TempoManifestMismatch');
write_catalog(fixture.tempo_file,original);
% A changed frame interval is detectable even when filenames remain fixed.
manifest = readtable(fixture.manifest_file,'TextType','string');
manifest.start_row_index(1) = manifest.start_row_index(1)+1;
writetable(manifest,fixture.manifest_file);
verifyError(testCase,@() execute_core(testCase,fixture,'beat','physical',true), ...
    'Orchestra:TempoManifestMismatch');
end

function fixture = make_fixture()
fixture.root = tempname;
fixture.data_path = fullfile(fixture.root,'data');
fixture.output_path = fullfile(fixture.root,'outputs');
fixture.tempo_file = fullfile(fixture.root,'tempo_catalog.json');
recording = "carmenD2-full-R1_swapfixed_intervalfixed";
folder = fullfile(fixture.data_path,'segment-piece-data-fixed-despiked','Carmen',recording);
mkdir(folder)
labels = ["Start";"A";"B";"C";"D"];
fixture.csv_files = strings(5,1);
fixture.wav_files = strings(5,1);
manifest = table((1:5)',labels,(0:4)'*6,(1:5)'*6,(0:4)'*200,(1:5)'*200, ...
    repmat(200,5,1),strings(5,1),strings(5,1),repmat(6,5,1), ...
    'VariableNames',{'index','label','audio_start_s','audio_end_s', ...
    'start_row_index','end_row_index_exclusive','frames','file','audio_file','audio_duration_s'});
time = (0:199)'/25;
audio_time = (0:47999)'/8000;
for segi = 1:5
    values = [(1:200)'+200*(segi-1), ...
        100+sin(2*pi*time),50+cos(2*pi*1.3*time), ...
        200+sin(2*pi*time+.3),100+.7*cos(2*pi*1.7*time), ...
        300+.5*sin(2*pi*2*time),150+cos(2*pi*2.1*time)];
    data = array2table(values,'VariableNames',{'frame','1x','1y','2x','2y','3x','3y'});
    manifest.file(segi) = compose('%02d_%s.csv',segi,labels(segi));
    manifest.audio_file(segi) = compose('%02d_%s.wav',segi,labels(segi));
    fixture.csv_files(segi) = fullfile(folder,manifest.file(segi));
    fixture.wav_files(segi) = fullfile(folder,manifest.audio_file(segi));
    writetable(data,fixture.csv_files(segi));
    audiowrite(fixture.wav_files(segi),.1*sin(2*pi*220*audio_time),8000);
end
fixture.manifest_file = fullfile(folder,'segments_manifest.csv');
writetable(manifest,fixture.manifest_file);
template = struct('piece','carmen','recording',char(recording), ...
    'segment_index',1,'segment_label','Start','audio_file','', ...
    'audio_sha256','','audio_duration_s',6,'tempo_bpm',60,'beat_hz',1, ...
    'source_csv','','manifest_sha256',sha256_file(fixture.manifest_file), ...
    'eligible_flag',true,'status','accepted');
observations = repmat(template,4,1);
for observationi = 1:4
    segi = observationi;
    if observationi == 4; segi = 5; end % Section C intentionally has no tempo row.
    observations(observationi).segment_index = segi;
    observations(observationi).segment_label = char(labels(segi));
    observations(observationi).audio_file = char(fixture.wav_files(segi));
    observations(observationi).audio_sha256 = sha256_file(fixture.wav_files(segi));
    observations(observationi).source_csv = char(fixture.csv_files(segi));
end
observations(2).tempo_bpm = 120;
observations(2).beat_hz = 2;
observations(3).tempo_bpm = NaN;
observations(3).beat_hz = NaN;
observations(3).eligible_flag = false;
observations(3).status = 'needs_review';
observations(4).tempo_bpm = NaN; % Even an accepted label cannot authorize invalid values.
observations(4).beat_hz = NaN;
catalog = struct('contract_version',1,'analysis_unit','existing_wav_segment', ...
    'score_section_mapping_applied',false,'settings_signature','synthetic_tempo_fixture', ...
    'mir_commit','synthetic_no_MIR_execution','mirtempo_sha256',repmat('0',1,64), ...
    'observations',observations);
write_catalog(fixture.tempo_file,catalog);
end

function state = execute_core(testCase,fixture,reference,calibration,run_segments,run_full)
if nargin < 6; run_full = false; end
code = testCase.TestData.pipeline_text;
start = strfind(code,'%% BLOCK 0 -');
finish = strfind(code,'%% BLOCK 3 -');
code = code(start(1):finish(1)-1);
code = strrep(code,'script_file = mfilename(''fullpath'');', ...
    sprintf('script_file = ''%s'';',testCase.TestData.pipeline_file));
code = strrep(code,'CFG.common.data_path = fullfile(path_study,''concertproject_kiersten'',''data'');', ...
    sprintf('CFG.common.data_path = ''%s'';',fixture.data_path));
code = strrep(code,'CFG.common.output_path = fullfile(path_study,''FREQNESS_Output'');', ...
    sprintf('CFG.common.output_path = ''%s'';',fixture.output_path));
code = strrep(code,'CFG.common.tempo_file = '''';', ...
    sprintf('CFG.common.tempo_file = ''%s'';',fixture.tempo_file));
code = strrep(code,'validatestring(''hz'',{''hz'',''beat''})', ...
    sprintf('validatestring(''%s'',{''hz'',''beat''})',reference));
code = strrep(code,'''physical'',{''physical'',''legacy''}', ...
    sprintf('''%s'',{''physical'',''legacy''}',calibration));
code = strrep(code,'CFG.common.frex = .5:.1:10;','CFG.common.frex = [.5 1 2];');
code = strrep(code,'CFG.common.ncomps = 4;','CFG.common.ncomps = 2;');
code = regexprep(code,'CFG.block1.run_flag = (true|false);', ...
    sprintf('CFG.block1.run_flag = logical(%d);',run_full));
code = regexprep(code,'CFG.block2.run_flag = (true|false);', ...
    sprintf('CFG.block2.run_flag = logical(%d);',run_segments));
code = regexprep(code,'CFG.block3.run_flag = (true|false);','CFG.block3.run_flag = false;');
evalc(code);
state = struct('CFG',CFG,'core_settings',core_settings);
if exist('SEG','var'); state.SEG = SEG; end
end

function write_catalog(path,catalog)
file_id = fopen(path,'w');
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id,'%s\n',jsonencode(catalog));
end

function digest = sha256_file(file)
file_id = fopen(file,'rb');
cleanup = onCleanup(@() fclose(file_id));
engine = java.security.MessageDigest.getInstance('SHA-256');
while ~feof(file_id)
    engine.update(fread(file_id,2^20,'*uint8'));
end
bytes = typecast(engine.digest(),'uint8');
digest = lower(reshape(dec2hex(bytes,2)',1,[]));
end
