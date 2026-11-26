function generate_matlab_reference(output_file)
% Deterministic MATLAB oracle for the Python port. Generated MAT files are
% ignored; commit this generator, not scientific data or generated figures.
toolbox = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(toolbox,'FREQNESS_Functions')));
addpath(genpath(fullfile(toolbox,'FREQNESS_ExternalFunctions')));
t = (0:499)/50;
data = zeros(6,numel(t),2);
for subi = 1:2
    for coordi = 1:6
        data(coordi,:,subi) = sin(2*pi*(.25+coordi/8)*t+subi/3) ...
            +.3*cos(2*pi*(.8+subi/5)*t+coordi/4)+.01*t.^2/coordi;
    end
end
frex = [.25 .3; .5 .6; 1 1.2; 2 2.4; 4 4.8];
srate = 50;
physical = FREQNESS_ComputeFilterWidths_Mocap(frex);
legacy = FREQNESS_ComputeLegacyFilterWidths_Mocap(frex);
[filtered,empirical,kernel] = filterFGx(data(:,:,1),srate,1.2,.3,0);
ged = FREQNESS_NetworkEstimation_Mocap(data,frex,srate,'ncomps',3);
pca = FREQNESS_NetworkEstimation_Mocap(data,frex,srate,'ncomps',6,'method','pca');
velocity = FREQNESS_NetworkEstimation_Mocap(data,frex,srate,'ncomps',3,'kinematics','velocity');
gap_data = data;
gap_data(2,101:102,1) = NaN;
gap_data(4:6,151:155,2) = NaN;
gap = FREQNESS_NetworkEstimation_Mocap(gap_data,frex,srate,'ncomps',3, ...
    'maximum_reconstructed_gap',.12,'bad_segments',[211 212], ...
    'kinematics','velocity');
[H2,ED] = FREQNESS_EffectDim_Mocap(ged,'figure',false);
space = FREQNESS_SpaceCoord_Mocap(ged,[1 1.2],'metric_levels',[.5 1 2]);
fisher = FREQNESS_SpaceCoord_Mocap(ged,[1 1.2],'metric_levels',[.5 1 2],'Fisher',true);
aligned = ged; aligned.frex = frex(:,1);
[landscape_comp,landscape_entropy,selected_frex] = FREQNESS_LandscapeSimilarity(aligned);
% A denser spectrum is needed to leave nonmetric baseline frequencies.
dense = ged; dense.frex = (.125:.125:2)';
dense.evals = zeros(6,16,2);
for subi = 1:2
    for frexi = 1:16
        v = (1:6)'+.3*sin(frexi*(1:6)'/subi);
        dense.evals(:,frexi,subi) = 100*v/sum(v);
    end
end
meter = FREQNESS_MetricProminence_Mocap(dense,1,'metric_levels',[.25 .5 1 2]);
[processed,preprocessing] = FREQNESS_PreprocessTimeCoord_Mocap(data(1:2,:,1)',50, ...
    'target_srate',10,'lowpass_cutoff',4,'duration',[.1 .9],'standardize',true);
phase = FREQNESS_TimeCoord_Mocap(ged,[1 1.2],'downsample',5, ...
    'metric_levels',[.5 1],'store_matrices',true);
phase_gap = FREQNESS_TimeCoord_Mocap(ged,[1 1.2],'downsample',5, ...
    'bad_segments',[11 16 21],'standardize',true,'store_matrices',true, ...
    'threshold_method','fixed_rr','threshold',.2,'theiler_window',2);
parameters = struct('m',2,'tau',3,'ps',1,'RadiusFraction',.1);
joint = FREQNESS_TimeCoord_Mocap(ged,[1 1.2],'method','jrqa','parameters',parameters, ...
    'srate',50,'target_srate',10,'lowpass_cutoff',4,'standardize',true, ...
    'store_matrices',true,'threshold_method','adaptive_max_radius');
joint_fixed = FREQNESS_TimeCoord_Mocap(ged,[1 1.2],'method','jrqa','parameters',parameters, ...
    'srate',50,'target_srate',10,'lowpass_cutoff',4,'store_matrices',true, ...
    'threshold_method','fixed_rr','threshold',.2,'theiler_window',2);
tuned = FREQNESS_JRQAParameters_Mocap(ged,[1 1.2],50, ...
    'target_srate',10,'lowpass_cutoff',4,'maximum_lag',12,'maximum_dimension',4);
[observed,surrogates] = FREQNESS_JRQASurrogates_Mocap(ged,parameters,[1 1.2], ...
    'srate',50,'target_srate',10,'lowpass_cutoff',4,'threshold_method','adaptive_max_radius', ...
    'n_surrogates',7,'random_seed',1);
plots = {eye(8),ones(8),zeros(8),mod((1:12)'*(1:12),5)<2, ...
    [1 0 1;0 0 1;1 1 1]};
rqa = cell(size(plots));
for i=1:numel(plots)
    rqa{i} = FREQNESS_RQA_Mocap(plots{i});
end
save(output_file,'data','frex','srate','physical','legacy','filtered','empirical','kernel', ...
    'ged','pca','velocity','gap_data','gap','H2','ED','space','fisher', ...
    'landscape_comp','landscape_entropy','selected_frex','dense','meter', ...
    'processed','preprocessing','phase','phase_gap','parameters','joint','joint_fixed', ...
    'tuned','observed','surrogates','plots','rqa','-v7');
fprintf('MATLAB parity reference saved to %s\n',output_file);
end
