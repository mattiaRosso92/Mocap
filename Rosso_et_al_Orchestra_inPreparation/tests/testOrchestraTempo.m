function tests = testOrchestraTempo
% Exercise the actual tempo script with known pulses and missing/silent WAVs.
% Requires the pinned, unmodified MIR dependency in ignored study outputs.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.study_path = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.pipeline_file = fullfile(testCase.TestData.study_path, ...
    'FREQNESS_Orchestra_Tempo.m');
end

function testSyntheticTempoAndExplicitAcceptanceGate(testCase)
fixture = make_tempo_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s')); %#ok<NASGU>
overrides = fixture_overrides(fixture);
overrides.segment_labels = "pulse";
% For this synthetic test only, the truth is 120 BPM. Restricting the
% search to 80-180 excludes its half/double alternatives by construction.
overrides.bounds_bpm = [80 180];
state = execute_tempo(testCase,overrides);
row = state.TEMPO(1);
verifyGreaterThan(testCase,row.nvalid_frames,10);
verifyLessThan(testCase,abs(row.tempo_bpm_candidate-120),2);
verifyEqual(testCase,numel(row.frame_times_s),row.nframes);
verifySize(testCase,row.candidate_bpm,[3 row.nframes]);
verifySize(testCase,row.candidate_strength,[3 row.nframes]);
verifyTrue(testCase,all(diff(row.frame_times_s) > 0));
verifyEqual(testCase,row.status,"needs_review");
verifyTrue(testCase,ismember("automatic_acceptance_disabled",row.review_reasons));
verifyFalse(testCase,row.eligible_flag);
verifyTrue(testCase,isnan(row.beat_hz));
verifyTrue(testCase,isnan(row.tempo_bpm));
verifyEqual(testCase,row.score_prior_bpm_range,[100 152]);
verifyEqual(testCase,row.score_prior_policy, ...
    "piece_context_only_not_applied_to_old_segments");

% Identical inputs resume their cache without rewriting estimation output.
before = dir(row.cache_file);
second = execute_tempo(testCase,overrides);
after = dir(second.TEMPO(1).cache_file);
verifyEqual(testCase,before.datenum,after.datenum);
verifyEqual(testCase,second.TEMPO(1).audio_sha256,row.audio_sha256);
verifyEqual(testCase,second.TEMPO(1).frame_bpm,row.frame_bpm);

% A deliberate acceptance switch is separate from estimating a candidate.
overrides.enable_automatic_acceptance_flag = true;
accepted = execute_tempo(testCase,overrides);
verifyEqual(testCase,accepted.TEMPO(1).status,"accepted");
verifyTrue(testCase,accepted.TEMPO(1).eligible_flag);
verifyEqual(testCase,accepted.TEMPO(1).beat_hz, ...
    accepted.TEMPO(1).tempo_bpm/60,'AbsTol',1e-12);
verifyNotEqual(testCase,accepted.TEMPO(1).settings_signature,row.settings_signature);
end

function testShortSilentAndMissingAudioStayIneligible(testCase)
fixture = make_tempo_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s')); %#ok<NASGU>
overrides = fixture_overrides(fixture);
overrides.segment_labels = ["short" "silent" "missing"];
overrides.enable_automatic_acceptance_flag = true;
state = execute_tempo(testCase,overrides);
verifyEqual(testCase,state.TEMPO(2).status,"needs_review");
verifyTrue(testCase,ismember("too_short_for_tempo",state.TEMPO(2).review_reasons));
verifyEqual(testCase,state.TEMPO(3).status,"needs_review");
verifyTrue(testCase,ismember("near_silent_audio",state.TEMPO(3).review_reasons));
verifyEqual(testCase,state.TEMPO(4).status,"missing_audio");
verifyFalse(testCase,any([state.TEMPO.eligible_flag]));
verifyTrue(testCase,all(isnan([state.TEMPO.beat_hz])));
catalog = jsondecode(fileread(state.catalog_file));
verifyFalse(testCase,catalog.score_section_mapping_applied);
verifyFalse(testCase,catalog.complete_flag); % Pulse row was not selected.
verifyEqual(testCase,string(catalog.analysis_unit),"existing_wav_segment");
end

function testChangedWaveBytesCannotReuseOldCache(testCase)
fixture = make_tempo_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s')); %#ok<NASGU>
overrides = fixture_overrides(fixture);
overrides.segment_labels = "short"; % No MIR cost needed for provenance test.
first = execute_tempo(testCase,overrides);
old_cache = first.TEMPO(2).cache_file;
old_hash = first.TEMPO(2).audio_sha256;
audiowrite(fullfile(fixture.recording_folder,'02_short.wav'), ...
    .2*ones(2*11025,1),11025);
second = execute_tempo(testCase,overrides);
verifyNotEqual(testCase,second.TEMPO(2).audio_sha256,old_hash);
verifyNotEqual(testCase,second.TEMPO(2).cache_file,old_cache);
verifyTrue(testCase,isfile(old_cache));
verifyTrue(testCase,isfile(second.TEMPO(2).cache_file));
end

function testUnknownConfigurationIsRejected(testCase)
fixture = make_tempo_fixture();
cleanup = onCleanup(@() rmdir(fixture.root,'s')); %#ok<NASGU>
overrides = fixture_overrides(fixture);
overrides.unknown_setting = true;
verifyError(testCase,@() execute_tempo(testCase,overrides), ...
    'OrchestraTempo:UnknownSetting');
end

function state = execute_tempo(testCase,overrides)
pipeline_file = testCase.TestData.pipeline_file;
orchestra_tempo_overrides = overrides; %#ok<NASGU>
original_path = path;
cleanup = onCleanup(@() path(original_path)); %#ok<NASGU>
evalc('run(pipeline_file)');
state = struct('TEMPO',TEMPO,'catalog_file',catalog_file); %#ok<NODEF>
end

function overrides = fixture_overrides(fixture)
overrides = struct('data_path',fixture.data_path, ...
    'output_path',fullfile(fixture.root,'outputs'), ...
    'annotations_file',fixture.annotations_file,'run_flag',true, ...
    'enable_automatic_acceptance_flag',false,'pieces',"carmen", ...
    'recordings',"synthetic",'segment_labels',strings(0,1));
end

function fixture = make_tempo_fixture()
fixture.root = tempname;
fixture.data_path = fullfile(fixture.root,'segments');
fixture.recording_folder = fullfile(fixture.data_path,'Carmen','synthetic');
mkdir(fixture.recording_folder);
srate = 11025;
audio = zeros(32*srate,1);
pulse_time = (0:round(.07*srate)-1)'/srate;
pulse = .8*sin(2*pi*1000*pulse_time).*exp(-60*pulse_time);
for beati = 0:63
    idx_samples = round(beati*.5*srate) + (1:numel(pulse));
    audio(idx_samples) = pulse;
end
audiowrite(fullfile(fixture.recording_folder,'01_pulse.wav'),audio,srate);
audiowrite(fullfile(fixture.recording_folder,'02_short.wav'),audio(1:2*srate),srate);
audiowrite(fullfile(fixture.recording_folder,'03_silent.wav'),zeros(12*srate,1),srate);
manifest = table((1:4)',["pulse";"short";"silent";"missing"], ...
    ["01_pulse.wav";"02_short.wav";"03_silent.wav";"04_missing.wav"], ...
    [0;32;34;46],[32;34;46;50],'VariableNames', ...
    {'index','label','audio_file','audio_start_s','audio_end_s'});
writetable(manifest,fullfile(fixture.recording_folder,'segments_manifest.csv'));
score_table = table(["Bizet";"Bizet"],[1;9],[100;152], ...
    'VariableNames',{'Piece','SectionNr','TempoBPM'});
fixture.annotations_file = fullfile(fixture.root,'score_context.csv');
writetable(score_table,fixture.annotations_file);
end
