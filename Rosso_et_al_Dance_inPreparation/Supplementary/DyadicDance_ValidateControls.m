function DyadicDance_ValidateControls
% Deterministic numerical regression of the study-only compact controls.
% Run after FREQNESS_Startup_Mocap. No study data or outputs are modified.
rng(47);
srate = 250;
data = randn(66,2048,2);
data = data + reshape(randn(66,1,2),66,1,2).*sin(2*pi*(0:2047)/250);
frex = (1:6)' .* [.3 .32];
fwidth = repmat(linspace(.03,.2,6)',1,2).*[1 1.1];
settings = struct('width_multipliers',[.25 .5 1 2 4],'ncomps',4,'regularisation',.01);
for gapi = 1:2
    if gapi==2, data(2,201:204,1) = NaN; end
    CONTROL = DyadicDance_ControlEstimation(data,frex,srate,fwidth,settings);
    for widthi = 1:5
        this_width = fwidth*settings.width_multipliers(widthi);
        FREQ = FREQNESS_NetworkEstimation_Mocap(data,frex,srate, ...
            'fwidth',this_width,'ncomps',4);
        assert(max(abs(FREQ.evals-CONTROL.evals(:,:,:,widthi)),[],'all')<1e-8);
        PCA = FREQNESS_NetworkEstimation_Mocap(data,frex,srate, ...
            'method','pca','fwidth',this_width,'ncomps',4);
        assert(max(abs(PCA.evals-CONTROL.evals(:,:,:,5+widthi)),[],'all')<1e-8);
    end
    for axisi = 1:3
        this_data = data; this_data(setdiff(1:66,axisi:3:66),:,:) = 0;
        FREQ = FREQNESS_NetworkEstimation_Mocap(this_data,frex,srate, ...
            'fwidth',fwidth,'ncomps',4);
        assert(max(abs(FREQ.evals-CONTROL.evals(:,:,:,12+axisi)),[],'all')<1e-8);
    end
    methods = {'ged','pca'};
    for methodi = 1:2
        FREQ = FREQNESS_NetworkEstimation_Mocap(data,frex,srate, ...
            'method',methods{methodi},'kinematics','velocity', ...
            'fwidth',fwidth,'ncomps',4);
        assert(max(abs(FREQ.evals-CONTROL.evals(:,:,:,10+methodi)),[],'all')<1e-8);
        [~,ED] = FREQNESS_EffectDim_Mocap(FREQ,'figure',false);
        assert(max(abs(ED-CONTROL.ED(:,:,10+methodi)),[],'all')<1e-10);
    end
end
fprintf('PASS: full eigenspectra, five widths, participant widths, axes, gaps and velocity.\n');
end
