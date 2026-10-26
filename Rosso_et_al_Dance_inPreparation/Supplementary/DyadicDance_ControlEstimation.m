function CONTROL = DyadicDance_ControlEstimation(data,frex,srate,fwidth,settings)
% Study-only compact GED/PCA controls; no change to the public toolbox.
% Inputs: coordinates x time x partners; frequencies/widths x partners.
% Outputs: all 66 eigenvalues x frequencies x partners x control; axis-only
% patterns retain four components. No component time series are constructed.
% GED uses the toolbox covariances/shrinkage; PCA uses eig(covS), exactly as
% in FREQNESS_NetworkEstimation_Mocap with method='pca'. Eigenvalues are
% normalized separately within each participant, frequency and control.
% Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti

raw_data = data;
[data,bad_segments,gap_info] = FREQNESS_InterpolateGaps_Mocap(data,srate);
assert(size(data,1)==66 && size(data,3)==2 && isequal(size(frex),size(fwidth)));
nfrex = size(frex,1);
nwidths = numel(settings.width_multipliers);
assert(isequal(settings.width_multipliers,[.25 .5 1 2 4]));
CONTROL.evals = nan(66,nfrex,2,2*nwidths+5);
CONTROL.axis_pats = nan(66,settings.ncomps,nfrex,2,3);
CONTROL.frex = frex;
CONTROL.fwidth = fwidth;
CONTROL.gap_info = gap_info;
CONTROL.labels = {'GED_bw025','GED_bw050','GED_bw100','GED_bw200','GED_bw400', ...
    'PCA_bw025','PCA_bw050','PCA_bw100','PCA_bw200','PCA_bw400', ...
    'GED_velocity','PCA_velocity','GED_X','GED_Y','GED_Z'};

for inputi = 1:2
    this_data = data;
    idx2remove = bad_segments;
    if inputi==2
        % Position derivative in units/second; no extra smoothing. Exclude
        % both differences adjacent to every reconstructed position sample.
        this_data = diff(data,1,2)*srate;
        idx2remove = unique([bad_segments bad_segments-1]);
        idx2remove = idx2remove(idx2remove>=1 & idx2remove<=size(this_data,2));
    end
    npnts = size(this_data,2);
    idx2cov = setdiff(1:npnts,idx2remove);
    for subi = 1:2
        broadData = this_data(:,:,subi);
        covR = cov(broadData(:,idx2cov)');
        covR_reg = regularise_reference(covR,settings.regularisation);
        data_fft = fft(broadData,[],2);
        hz = linspace(0,srate,npnts);
        for frexi = 1:nfrex
            if inputi==1, width_indices = 1:nwidths; else, width_indices = 3; end
            for widthi = width_indices
                this_width = fwidth(frexi,subi)*settings.width_multipliers(widthi);
                % Same Gaussian and normalization as filterFGx. With no
                % excluded samples, Parseval gives the identical centered
                % covariance without constructing thousands of time points.
                % Only exactly-zero spectral bins are omitted; no cutoff or
                % approximation is introduced. Gapped trials use filterFGx.
                if isempty(idx2remove)
                    width_sd = this_width*(2*pi-1)/(4*pi);
                    fx = exp(-.5*((hz-frex(frexi,subi))/width_sd).^2);
                    fx = fx/max(fx);
                    fx = fx + fx([1 npnts:-1:2]); % spectrum of 2*real(ifft(...))
                    fx(1) = 0; % subtract the temporal mean (DC component)
                    idx_active = find(fx~=0);
                    narrow_fft = data_fft(:,idx_active).*fx(idx_active);
                    covS = real(narrow_fft*narrow_fft')/(npnts*(npnts-1));
                else
                    narrowData = filterFGx(broadData,srate, ...
                        frex(frexi,subi),this_width,0);
                    covS = cov(narrowData(:,idx2cov)');
                end
                covS_reg = covS+1e-6*eye(66);
                if inputi==1
                    gedi = widthi; pcai = nwidths+widthi;
                else
                    gedi = 11; pcai = 12;
                end
                CONTROL.evals(:,frexi,subi,gedi) = spectrum(covS_reg,covR_reg);
                CONTROL.evals(:,frexi,subi,pcai) = spectrum(covS_reg,[]);
                if inputi==1 && widthi==3
                    for axisi = 1:3
                        idx_axis = axisi:3:66;
                        % Keep all 66 coordinates and zero the other axes,
                        % exactly as the original study axis selector did.
                        covS_axis = zeros(66); covR_axis = zeros(66);
                        covS_axis(idx_axis,idx_axis) = covS(idx_axis,idx_axis);
                        covR_axis(idx_axis,idx_axis) = covR(idx_axis,idx_axis);
                        covS_axis = covS_axis+1e-6*eye(66);
                        [evals,pats] = spectrum(covS_axis, ...
                            regularise_reference(covR_axis,settings.regularisation), ...
                            settings.ncomps);
                        CONTROL.evals(:,frexi,subi,12+axisi) = evals;
                        CONTROL.axis_pats(:,:,frexi,subi,axisi) = pats;
                    end
                end
            end
        end
    end
end
if ~isempty(bad_segments)
    % For axis-only estimates, gaps in discarded coordinates must not remove
    % otherwise valid samples. Apply zeroing BEFORE the toolbox gap policy.
    for axisi = 1:3
        this_data = raw_data;
        this_data(setdiff(1:66,axisi:3:66),:,:) = 0;
        FREQ = FREQNESS_NetworkEstimation_Mocap(this_data,frex,srate, ...
            'fwidth',fwidth,'ncomps',settings.ncomps, ...
            'regularisation',settings.regularisation);
        CONTROL.evals(:,:,:,12+axisi) = FREQ.evals;
        CONTROL.axis_pats(:,:,:,:,axisi) = FREQ.pats;
    end
end
assert(all(isfinite(CONTROL.evals),'all') && all(CONTROL.evals>=0,'all'));
assert(max(abs(sum(CONTROL.evals,1)-100),[],'all')<1e-10);
CONTROL.ED = reshape(sum(CONTROL.evals,1).^2./sum(CONTROL.evals.^2,1), ...
    nfrex,2,15);
end

function covR = regularise_reference(covR,regularisation)
covR = (1-regularisation)*covR + regularisation*mean(eig(covR))*eye(size(covR));
end

function [evals,pats] = spectrum(covS,covR,ncomps)
if isempty(covR), [evecs,evals] = eig(covS); else, [evecs,evals] = eig(covS,covR); end
[evals,sidx] = sort(diag(evals),'descend');
evals = evals*100/sum(evals);
if nargout>1
    pats = covS*evecs(:,sidx(1:ncomps));
    for compi = 1:ncomps
        [~,idxmax] = max(abs(pats(:,compi)));
        pats(:,compi) = pats(:,compi)*sign(pats(idxmax,compi));
    end
end
end
