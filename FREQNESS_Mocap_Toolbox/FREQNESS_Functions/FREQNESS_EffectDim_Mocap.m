function [H2,ED] = FREQNESS_EffectDim_Mocap(GED,varargin)

% ========================================================================
%
%  FREQUENCY-RESOLVED NETWORK ESTIMATION TOOLBOX - MOCAP VERSION
%
% ========================================================================
%  This function estimates quadratic Rényi entropy (H2) and effective
%  dimensionality (ED) across frequencies from the complete eigenspectrum
%  of a covariance matrix. It uses the entropy-based index derived by Pirk
%  et al. (2012) to estimate the effective number of uncorrelated
%  measurements, as described in Del Giudice (2021).
%
%  Both H2 and ED are returned for numerical analyses. In the MoCap
%  framework, the visualization shows ED because dimensionality is
%  interpreted as the effective number of frequency-specific body networks.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - GED : structure with fields
%          • GED.evals -> complete eigenvalue array
%                         [nEigenvalues x nFrex x (nParticipants)]
%          • GED.frex  -> frequency vector [nFrex x 1] (optional)
%
%  - Optional name-value pair:
%      - 'plot_all' : when true, additionally plot the ED landscape for
%                     every participant. Default: false.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - H2 : Quadratic Rényi entropy of the eigenvalue distribution.
%
%  - ED : Effective dimensionality.
%
% ------------------------------------------------------------------------
%  REFERENCES:
% ------------------------------------------------------------------------
%  - Del Giudice, M. (2021). Effective dimensionality: A tutorial.
%    Multivariate Behavioral Research, 56(3), 527–542.
%
%  - Pirk, R. J., Remley, K. A., & Patané, C. S. L. (2012).
%    Reverberation chamber measurement correlation.
%    IEEE Transactions on Electromagnetic Compatibility, 54(3), 533–545.
%
% ------------------------------------------------------------------------
%  AUTHORS:
%  Mattia Rosso, Felix Bigand, Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  felix.bigand@iit.it
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%  Center for Music in the Brain, Aarhus University
%  Neuroscience of Perception & Action Lab, Italian Institute of Technology (IIT)
%  Centre for Eudaimonia and Human Flourishing, Linacre College, University of Oxford
%
% ========================================================================


%% Handle optional arguments

opts = struct('plot_all',false);
opts = parse_name_value_pairs(opts,varargin{:});
plot_all = opts.plot_all;

if ~islogical(plot_all) || ~isscalar(plot_all)
    error('plot_all must be one logical value (true or false).');
end


%% Map and validate inputs from GED

if ~isstruct(GED)
    error('Input must be a GED structure.');
end

if ~isfield(GED,'evals') || isempty(GED.evals)
    error('GED.evals is missing or empty.');
end

eigenspectrum = GED.evals;
if ~isnumeric(eigenspectrum) || ~isreal(eigenspectrum) || ...
        ndims(eigenspectrum) > 3 || any(isinf(eigenspectrum(:))) || ...
        any(eigenspectrum(:) < 0)
    error(['GED.evals must be a real numeric array of non-negative, ' ...
        'non-infinite eigenvalues in ' ...
        '[nEigenvalues x nFrex x (nParticipants)] format.']);
end

if isvector(eigenspectrum)
    eigenspectrum = eigenspectrum(:);
end

nfrex = size(eigenspectrum,2);
nsubs = size(eigenspectrum,3);

% Use the analyzed frequencies when valid; otherwise use frequency indices
if isfield(GED,'frex') && isnumeric(GED.frex) && isreal(GED.frex) && ...
        isvector(GED.frex) && numel(GED.frex)==nfrex && ...
        all(isfinite(GED.frex))
    x = GED.frex(:);
    xlab = 'Frequency (Hz)';
else
    x = (1:nfrex)';
    xlab = 'Frequency index';
end

fprintf(['\nFREQNESS Effect Dimensionality: computing Rényi entropy (H2) ' ...
    'and effective dimensionality (ED) for %d participants.\n'],nsubs);


%% Compute quadratic Rényi entropy and effective dimensionality

sumtemp = sum(eigenspectrum,1);
sumtemp = max(sumtemp,realmin);
p = eigenspectrum./sumtemp;

% Quadratic Rényi entropy: H2 = -log(sum(p_i^2))
H2 = reshape(-log(sum(p.^2,1)),nfrex,nsubs);

% Effective dimensionality: ED = sum(lambda)^2/sum(lambda^2)
num = sum(eigenspectrum,1).^2;
denom = max(sum(eigenspectrum.^2,1),realmin);
ED = reshape(num./denom,nfrex,nsubs);


%% Visualize effective dimensionality

avg_ED = mean(ED,2,'omitnan');
if nsubs > 1
    sem_ED = std(ED,0,2,'omitnan')/sqrt(nsubs);
else
    sem_ED = [];
end

cmap = parula(256);
col_line = cmap(1,:);

figure('Color','w','Units','normalized','Position',[0.3 0.3 0.35 0.5]);
hold on
if nsubs > 1 && ~all(isnan(sem_ED))
    fill([x; flipud(x)],[avg_ED-sem_ED; flipud(avg_ED+sem_ED)], ...
        [0 0 0],'FaceAlpha',0.1,'EdgeColor','none');
end
plot(x,avg_ED,'Color',col_line,'LineWidth',2);
xlabel(xlab,'FontSize',13,'FontWeight','bold');
ylabel('Effective dimensionality','FontSize',13,'FontWeight','bold');
title('Effective Dimensionality - Grand Average', ...
    'FontSize',14,'FontWeight','bold');
set(gca,'FontSize',12,'LineWidth',1.2,'Box','off');
grid on
grid minor
set_frequency_limits(x)


%% Optional individual-participant plots

if plot_all
    for subi = 1:nsubs
        figure('Color','w','Units','normalized','Position',[0.3 0.3 0.35 0.5]);
        plot(x,ED(:,subi),'Color',col_line,'LineWidth',1.5);
        xlabel(xlab,'FontSize',13,'FontWeight','bold');
        ylabel('Effective dimensionality','FontSize',13,'FontWeight','bold');
        title(sprintf('Effective Dimensionality - Participant #%d',subi), ...
            'FontSize',14,'FontWeight','bold');
        set(gca,'FontSize',12,'LineWidth',1.2,'Box','off');
        grid on
        grid minor
        set_frequency_limits(x)
    end
end


%% Adjust scalar outputs

if numel(H2) == 1 %#ok<ISCL>
    H2 = H2(1);
    ED = ED(1);
end

end


%% Helper function: Set frequency limits
function set_frequency_limits(frex)

if numel(frex) == 1 %#ok<ISCL>
    padding = max(abs(frex(1))*0.05,0.5);
    xlim([frex(1)-padding frex(1)+padding])
else
    xlim([min(frex) max(frex)])
end

end


%% Helper function: Parse name-value pairs
function opts = parse_name_value_pairs(opts,varargin)

if mod(length(varargin),2) ~= 0
    error('Arguments must be given as name-value pairs.');
end

for i = 1:2:length(varargin)
    if ~(ischar(varargin{i}) || (isstring(varargin{i}) && isscalar(varargin{i})))
        error('Optional argument names must be text.');
    end
    name = lower(char(varargin{i}));
    if isfield(opts,name)
        opts.(name) = varargin{i+1};
    else
        error(['Unrecognized argument: ' name]);
    end
end

end
