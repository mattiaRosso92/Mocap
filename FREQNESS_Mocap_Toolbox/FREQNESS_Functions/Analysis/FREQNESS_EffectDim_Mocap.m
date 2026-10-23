function [H2,ED] = FREQNESS_EffectDim_Mocap(FREQ,varargin)

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
%  - FREQ : structure with fields
%          • FREQ.evals -> complete eigenvalue array
%                         [nEigenvalues x nFrex x (nParticipants)]
%          • FREQ.frex  -> frequency vector [nFrex x 1] (optional)
%
%  - Optional name-value pair:
%      - 'figure'   : when true, plot the grand-average ED landscape.
%                     Default: true.
%
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

opts = struct('figure',true,'plot_all',false);
opts = parse_name_value_pairs(opts,varargin{:});
figure_flag = opts.figure;
plot_all = opts.plot_all;

if ~islogical(figure_flag) || ~isscalar(figure_flag)
    error('figure must be one logical value (true or false).');
end
if ~islogical(plot_all) || ~isscalar(plot_all)
    error('plot_all must be one logical value (true or false).');
end


%% Map and validate inputs from FREQ

if ~isstruct(FREQ)
    error('Input must be a FREQ structure.');
end

if ~isfield(FREQ,'evals') || isempty(FREQ.evals)
    error('FREQ.evals is missing or empty.');
end

eigenspectrum = FREQ.evals;
if ~isnumeric(eigenspectrum) || ~isreal(eigenspectrum) || ...
        ndims(eigenspectrum) > 3 || any(isinf(eigenspectrum(:))) || ...
        any(eigenspectrum(:) < 0)
    error(['FREQ.evals must be a real numeric array of non-negative, ' ...
        'non-infinite eigenvalues in ' ...
        '[nEigenvalues x nFrex x (nParticipants)] format.']);
end

if isvector(eigenspectrum)
    eigenspectrum = eigenspectrum(:);
end

nfrex = size(eigenspectrum,2);
nsubs = size(eigenspectrum,3);

% Use the analyzed frequencies when valid; otherwise use frequency indices
if isfield(FREQ,'frex') && isnumeric(FREQ.frex) && isreal(FREQ.frex) && ...
        isvector(FREQ.frex) && numel(FREQ.frex)==nfrex && ...
        all(isfinite(FREQ.frex))
    x = FREQ.frex(:);
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

% Match the visual language used for the Dance-study network landscapes:
% the leading network color, a translucent SEM ribbon, and a log2-spaced
% frequency axis whose labels remain in linear units.
col_line = [0.90 0.22 0.16];

if strcmp(xlab,'Frequency (Hz)') && all(x > 0)
    x_plot = log2(x);
else
    x_plot = x;
end
if figure_flag
    figure('Color','w','Units','normalized','Position',[0.3 0.3 0.35 0.5]);
    hold on
    if nsubs > 1 && ~all(isnan(sem_ED))
        fill([x_plot; flipud(x_plot)], ...
            [avg_ED-sem_ED; flipud(avg_ED+sem_ED)], ...
            col_line,'FaceAlpha',0.22,'EdgeColor','none');
    end
    plot(x_plot,avg_ED,'Color',col_line,'LineWidth',2.5);
    xlabel(xlab,'FontSize',14,'FontWeight','bold');
    ylabel('Effective dimensionality','FontSize',14,'FontWeight','bold');
    title('Effective Dimensionality - Grand Average', ...
        'FontSize',16,'FontWeight','bold');
    set(gca,'FontSize',12,'LineWidth',1.2,'Box','on', ...
        'GridAlpha',0.18,'MinorGridAlpha',0.10);
    grid on
    grid minor
    set_frequency_axis(x,x_plot,xlab)
end


%% Optional individual-participant plots

if figure_flag && plot_all
    for subi = 1:nsubs
        figure('Color','w','Units','normalized','Position',[0.3 0.3 0.35 0.5]);
        plot(x_plot,ED(:,subi),'Color',col_line,'LineWidth',2.5);
        xlabel(xlab,'FontSize',14,'FontWeight','bold');
        ylabel('Effective dimensionality','FontSize',14,'FontWeight','bold');
        title(sprintf('Effective Dimensionality - Participant #%d',subi), ...
            'FontSize',16,'FontWeight','bold');
        set(gca,'FontSize',12,'LineWidth',1.2,'Box','on', ...
            'GridAlpha',0.18,'MinorGridAlpha',0.10);
        grid on
        grid minor
        set_frequency_axis(x,x_plot,xlab)
    end
end


%% Adjust scalar outputs

if numel(H2) == 1 %#ok<ISCL>
    H2 = H2(1);
    ED = ED(1);
end

end


%% Helper function: Set frequency-axis limits and octave ticks
function set_frequency_axis(x,x_plot,xlab)

if numel(x) == 1 %#ok<ISCL>
    padding = 0.5;
    xlim([x_plot(1)-padding x_plot(1)+padding])
    xticks(x_plot(1))
    xticklabels(string(x(1)))
elseif strcmp(xlab,'Frequency (Hz)') && all(x > 0)
    octave_set = 2.^(-6:8);
    octave_values = octave_set(octave_set >= min(x) & octave_set <= max(x));
    if numel(octave_values) >= 2
        xticks(log2(octave_values))
        xticklabels(string(octave_values))
    end
    xtickangle(45)
    xlim([min(x_plot) max(x_plot)])
else
    xlim([min(x_plot) max(x_plot)])
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
