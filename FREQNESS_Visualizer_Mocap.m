function FREQNESS_Visualizer_Mocap(GED,Landscape,Patterns)
% ========================================================================
%  FREQNESS VISUALIZER: BODILY NETWORK LANDSCAPE & BODILY ACTIVATION PATTERNS
%
%
% ========================================================================
%
%  This script visualizes:
%
%  - Bodily network prominence across frequencies
%    Quantified as % variance explained based on the associated
%    eigenvalues, producing a frequency-resolved network landscape
%
%  - Spatial activation patterns of the networks
%    - The requested network is plotted in a 2D visualization 
%      of the labelled bodily districts, sorted from high to low,
%      separately for X,Y,and Z. The scale is not normalized.
%     - The requested network is plotted in a 3D visualization 
%      of the skeleton with all mocap markers, color-coded by activation
%      magnitude along X,Y,and Z directions. The scale is normalized.
%     - Upon user's request, an animation is displayed. The animation
%     shows the activation timeseries of the selected bodily network
%     component. The red ball is constantly updated to track how the
%     activation over time maps onto the XYZ space via backprojection of
%     the component in the markers' space. For comparison, the animation of
%     the original data (i.e., including the sum of all components) is also
%     synchronized with he component's activation.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - GED              : Structure outputted by FREQNESS_NetworkEstimation function.
%                       We recommend not to modify this structure before giving it
%                       as input to the current function (FREQNESS_Visualizer).
%      - GED.evals    : Normalized eigenvalues (variance explained in % points).
%      - GED.pats     : Spatial activation patterns used to generate NIFTI files
%                       for visualizing network topographies.
%      - GED.frex     : Vector of frequencies analyzed; used to select subsets
%                       for visualization.
%
%
%  - Landscape                : Structure containing settings for network landscape visualization
%      - Landscape.frex       : Vector of frequencies to visualize in the network landscape.
%      - Landscape.ncomps     : Number of components (networks) to visualize in the landscape.
%
%
%  - Patterns                 : Structure containing settings for activation patterns visualization
%      - Patterns.frex        : Vector of frequencies to visualize the associated
%                               networks' spatial activation patterns.
%      - Patterns.labels      : Mocap marker labels, in format X1,Y1,Z1,X2,Y2,Z2,[...]
%      - Patterns.markerData  : Mocap marker data, in format
%                               X1,Y1,Z1,X2,Y2,Z2,[...]. Used to backproject and animate.
%      - Patterns.comp        : index of the component # to inspect
%      - Patterns.srate       : original sampling rate, for time info in the animation
%      - Patterns.start       : starting point of the animation (0-1)
%
%
%  NOTE 1: At the moment, only the BONE STRUCTURE used in Bigand et al.
%  (2024) is supported for visualizing the skeleton (consider asking the
%  user to input their own)
%

% NOTE2 : the 'booster' for animation should relate to the variance in the
% data, rather than being hard-coded

% NOTE 3: include an optional argument for setting the starting point of
% the animation (in % of the recording length)

% NOTE 5: re-normalize the activation pattern scale from -1 to 1 (rather
% than 0 to 1)??? Maybe it's actually better to bottom at 0, so that the 
% skeleton does not fold over itself?

% NOTE 6: the SIGN ARBITRARITY seems to affect the spatial activation
% pattern. In some cases, the component is clearly in anti-phase with the
% original data animation. HP: the sign adjustment should correct all XYZ
% dimensions at ones, because of how the input data are structured.


% ------------------------------------------------------------------------
%  AUTHORS:
%  Mattia Rosso, Leonardo Bonetti, Felix Bigand
%  mattia.rosso@clin.au.dk
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%  felix.bigand@iit.it
%  Center for Music in the Brain, Aarhus University
%  Centre for Eudaimonia and Human Flourishing, Linacre College, University of Oxford
%  Neuroscience of Perception & Action Lab, Italian Institute of Technology (IIT)
%
%  Rome (IT), 11/04/2025
% ========================================================================




%% Output #1: NETWORK LANDSCAPE
% 
% OLD VERSION (Before the log2 spacing) 
%
% figure
% hold on
% 
% % Define frequencies to plot
% nfrex = length(Landscape.frex);
% 
% % Re-sort frequencies in ascending order
% Landscape.frex = sort(Landscape.frex,'ascend');
% 
% % Find indices of GED.frex that match elements in Landscape.frex
% [~, idx_frex2plot] = ismembertol(Landscape.frex, GED.frex, 1e-4);
% 
% % Define a red-to-blue colormap
% numLines = Landscape.ncomps;
% % If you don't have cbrewer, use this alternative:
% colors = flipud([linspace(0,1,numLines)', zeros(numLines,1), linspace(1,0,numLines)']); % Custom red-blue gradient
% 
% % Plot each line with increasing thickness and a gradient color
% for i = 1:numLines
%     if i == 1
%         plot(log2(GED.frex(idx_frex2plot)),GED.evals(i,idx_frex2plot), 'Color', colors(i,:), 'LineWidth', 3); % First line is bolder
%     else
%         plot(log2(GED.frex(idx_frex2plot)),GED.evals(i,idx_frex2plot)', 'Color', colors(i,:), 'LineWidth', 2);
%     end
% end
% %xlim([Landscape.frex(1) Landscape.frex(end)])
% xticks(log2(Landscape.frex))
% xticklabels(string(Landscape.frex))
% xtickangle(45)
% xlabel('Frequency (Hz)', 'FontSize', 14, 'FontWeight', 'bold')
% ylabel('Explained variance (%)', 'FontSize', 14, 'FontWeight', 'bold')
% title('Bodily networks prominence across frequencies', 'FontSize', 16, 'FontWeight', 'bold')
% 
% % Create custom legend with 'GED component #' labels
% legendLabels = arrayfun(@(x) sprintf('GED component #%d', x), 1:numLines, 'UniformOutput', false);
% legend(legendLabels, 'Location', 'Northeast', 'FontSize', 12)
% grid minor
% set(gca, 'FontSize', 12, 'LineWidth', 1.5) % Make axis and labels more visible
% box on
% set(gcf, 'Color', 'w'); % Set figure background to white

figure
hold on

% Sort Landscape frequencies
Landscape.frex = sort(Landscape.frex,'ascend');

% Match GED.frex to Landscape.frex
[~, idx_frex2plot] = ismembertol(Landscape.frex, GED.frex, 1e-4);

% Create a log2-evenly spaced frequency vector
log2_min = log2(min(Landscape.frex));
log2_max = log2(max(Landscape.frex));
nPoints = 100; % you can pick how fine you want the interpolation
log2_frex_uniform = linspace(log2_min, log2_max, nPoints);
frex_uniform = 2.^log2_frex_uniform; % back to Hz

% Interpolate GED data onto this uniform log2 frequency axis
resampled_GED = zeros(Landscape.ncomps, nPoints);
for i = 1:Landscape.ncomps
    resampled_GED(i,:) = interp1(Landscape.frex, GED.evals(i,idx_frex2plot), frex_uniform, 'linear', 'extrap');
end

% Define colormap
colors = flipud([linspace(0,1,Landscape.ncomps)', zeros(Landscape.ncomps,1), linspace(1,0,Landscape.ncomps)']);

% Plot
for i = 1:Landscape.ncomps
    if i == 1
        plot(log2(frex_uniform), resampled_GED(i,:), 'Color', colors(i,:), 'LineWidth', 3);
    else
        plot(log2(frex_uniform), resampled_GED(i,:), 'Color', colors(i,:), 'LineWidth', 2);
    end
end

% Define octave ticks 
octave_ticks = unique(2.^round(log2(Landscape.frex))); 
octave_ticks = octave_ticks(octave_ticks >= min(Landscape.frex) & octave_ticks <= max(Landscape.frex));
% Apply to plot
xticks(log2(octave_ticks))        % visualize as log spaced
xticklabels(string(octave_ticks)) % read as linear
xtickangle(45)
xlabel('Frequency (Hz)', 'FontSize', 14, 'FontWeight', 'bold')
ylabel('Explained variance (%)', 'FontSize', 14, 'FontWeight', 'bold')
title('Bodily networks prominence across frequencies', 'FontSize', 16, 'FontWeight', 'bold')
grid on
hold off

% Create custom legend with 'GED component #' labels
legendLabels = arrayfun(@(x) sprintf('GED component #%d', x), 1:Landscape.ncomps, 'UniformOutput', false);
legend(legendLabels, 'Location', 'Northeast', 'FontSize', 12)
grid minor
set(gca, 'FontSize', 12, 'LineWidth', 1.5) % Make axis and labels more visible
box on
set(gcf, 'Color', 'w'); % Set figure background to white


%% Output #2: BODILY SPATIAL ACTIVATION PATTERNS (3D static visualization)

% NOTE: because we decomposend the positions in terms of distance fomr the
% origin, the space is in the activation timeseries! And in the weights.
% Because of the demeaning, I might have to 'inflate' the skeleton based on
% the data ('re-inject' the mean)

% NOTE2: THE SIGNS in the patterns ARE VERY IMPORTANT!! 

% Assign input data
markData = Patterns.markerData;
nmarks = size(markData,1);
npnts  = size(markData,2);

% Define X,Y,Z indexes
x_idx = [1:3:nmarks-2];
y_idx = [2:3:nmarks-1];
z_idx = [3:3:nmarks];
% % Assign separately X,Y,Z data
xData = markData(x_idx,:);
yData = markData(y_idx,:);
zData = markData(z_idx,:);

% Re-sort frequencies in ascending order (allows for input in random order)
Patterns.frex = sort(Patterns.frex,'ascend');
nfrex = length(Patterns.frex);

% Find indices of GED.frex that match elements in Patterns.frex
[~, idxfrex] = ismembertol(Patterns.frex, GED.frex, 1e-4);

% Produce one output per input frequency
for frexi = 1:nfrex
    
    % Assing current frequency to temporary variable
    thisfrex = Patterns.frex(frexi);
        
    %% Visualize by labelled matrix
    figure, clf
    % X
    subplot(131)
    imagesc(GED.pats(x_idx,Patterns.comp,idxfrex(frexi)))
    xticks([])
    yticks(1:nmarks/3)
    yticklabels(Patterns.labels)
    title('X')
    colorbar
    % Y
    subplot(132)
    imagesc(GED.pats(y_idx,Patterns.comp,idxfrex(frexi)))
    xticks([])
    yticks(1:nmarks/3)
    yticklabels(Patterns.labels)
    title('Y')
    colorbar
    % Z
    subplot(133)
    imagesc(GED.pats(z_idx,Patterns.comp,idxfrex(frexi)))
    xticks([])
    yticks(1:nmarks/3)
    yticklabels(Patterns.labels)
    title('Z')
    colorbar
    % General
    sgtitle(['Movement frequency: ' num2str(thisfrex) 'Hz'])
    
    
    %% Static skeleton
    
    % Inflate the de-meaned projection
    remeaner = 1*squeeze( mean(markData,2) ); % compute teh means by channel
    
    % Demean and boost the component timeseries, for visualization
    booster = 10; % I guess this should be proportional to the VARIANCE instead, but the componets is demeaned 
    % NOTE: booster previously hard-coded to 15, seemed to work for the tested
    % particiapnts
    ts2plot = booster * (GED.ts(Patterns.comp,:,idxfrex(frexi))-mean(GED.ts(Patterns.comp,:,idxfrex(frexi))));
    
    % Backprojection on 3 dimensions
    x_comp2plot = GED.pats(x_idx,Patterns.comp,idxfrex(frexi)) * ts2plot + remeaner(x_idx);
    y_comp2plot = GED.pats(y_idx,Patterns.comp,idxfrex(frexi)) * ts2plot + remeaner(y_idx);
    z_comp2plot = GED.pats(z_idx,Patterns.comp,idxfrex(frexi)) * ts2plot + remeaner(z_idx);
      
    % Define limits
    xmin = min(x_comp2plot(:));
    ymin = min(y_comp2plot(:));
    zmin = min(z_comp2plot(:));
    xmax = max(x_comp2plot(:));
    ymax = max(y_comp2plot(:));
    zmax = max(z_comp2plot(:));
    
    % Static scatterplot 3D (hack: use initial position and map the act patterns on the marker color, by XYZ) 
    nscale = 1000;                    % Number of colors in the colormap
    col_static = .95*jet(nscale);      % Create a jet colormap
    marksize = 100;
    
    % Normalize all activation patterns to [-1, 1]
    all_pats2see = GED.pats(:,Patterns.comp,idxfrex(frexi)) / max(abs(GED.pats(:,Patterns.comp,idxfrex(frexi))));
    
    
    % Select the activation values relevant to each axis
    x_pats2see = all_pats2see(x_idx);
    y_pats2see = all_pats2see(y_idx);
    z_pats2see = all_pats2see(z_idx);
    
    % Convert [-1, 1] values to indices in [1, nscale] to map into the colormap
    % Step-by-step:
    % - Shift range from [-1, 1] to [0, 2] with (val + 1)
    % - Scale to [0, nscale-1] by multiplying by (nscale-1)/2
    % - Add 1 to get final index range [1, nscale]
    color_idx_x = round((x_pats2see + 1) * (nscale - 1) / 2) + 1;
    color_idx_y = round((y_pats2see + 1) * (nscale - 1) / 2) + 1;
    color_idx_z = round((z_pats2see + 1) * (nscale - 1) / 2) + 1;
    
    % Clamp to make sure indices are within bounds
    color_idx_x = min(max(color_idx_x, 1), nscale);
    color_idx_y = min(max(color_idx_y, 1), nscale);
    color_idx_z = min(max(color_idx_z, 1), nscale);
    
    % Pre-shifted links (MATLAB 1-based indexing already applied)
    bones = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10;7,11;11,12;12,13;
        14,15;14,16;15,16;15,17;17,18;18,19;16,20;20,21;21,22];

    
    figure, clf
    linewidth = 1.7;
    % Plot for X dimension
    subplot(131)
    scatter3(x_comp2plot(:,1), y_comp2plot(:,1), z_comp2plot(:,1), marksize, col_static(color_idx_x,:), 'filled');
    hold on
    for k = 1:size(bones,1)
        p1 = bones(k,1);
        p2 = bones(k,2);
        plot3([x_comp2plot(p1,1), x_comp2plot(p2,1)], ...
            [y_comp2plot(p1,1), y_comp2plot(p2,1)], ...
            [z_comp2plot(p1,1), z_comp2plot(p2,1)], 'k-', 'Linewidth', linewidth);
    end
    colorbar
    xlim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
    ylim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
    zlim([min(zData(:)) max(zData(:))]);
    xlabel('X')
    ylabel('Y')
    zlabel('Z')
    title('X')
    axis square
    % Plot for Y dimension
    subplot(132)
    scatter3(x_comp2plot(:,1), y_comp2plot(:,1), z_comp2plot(:,1), marksize, col_static(color_idx_y,:), 'filled');
    hold on
    for k = 1:size(bones,1)
        p1 = bones(k,1);
        p2 = bones(k,2);
        plot3([x_comp2plot(p1,1), x_comp2plot(p2,1)], ...
            [y_comp2plot(p1,1), y_comp2plot(p2,1)], ...
            [z_comp2plot(p1,1), z_comp2plot(p2,1)], 'k-', 'Linewidth', linewidth);
    end
    xlim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
    ylim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
    zlim([min(zData(:)) max(zData(:))]);    
    xlabel('X')
    ylabel('Y')
    zlabel('Z')
    title('Y')
    axis square    
    colorbar
    % Plot for Z dimension
    subplot(133)
    scatter3(x_comp2plot(:,1), y_comp2plot(:,1), z_comp2plot(:,1), marksize, col_static(color_idx_z,:), 'filled');
    hold on
    for k = 1:size(bones,1)
        p1 = bones(k,1);
        p2 = bones(k,2);
        plot3([x_comp2plot(p1,1), x_comp2plot(p2,1)], ...
            [y_comp2plot(p1,1), y_comp2plot(p2,1)], ...
            [z_comp2plot(p1,1), z_comp2plot(p2,1)], 'k-', 'Linewidth', linewidth);
    end
    xlim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
    ylim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
    zlim([min(zData(:)) max(zData(:))]);
    xlabel('X')
    ylabel('Y')
    zlabel('Z')
    title('Z')
    axis square
    colorbar
    % General title
    sgtitle(['Movement frequency: ' num2str(thisfrex) 'Hz'])
    
end


%% Output #3: BODILY SPATIAL ACTIVATION PATTERNS (3D animation)


% Downsample for faster visualization (NOTE: it should scale with the N timepoints)
dwn = 15;
ts2plot = downsample(ts2plot',dwn)';
x_comp2plot = downsample(x_comp2plot',dwn)';
y_comp2plot = downsample(y_comp2plot',dwn)';
z_comp2plot = downsample(z_comp2plot',dwn)';
xData = downsample(xData',dwn)';
yData = downsample(yData',dwn)';
zData = downsample(zData',dwn)';
npnts = floor(npnts/dwn);

% Create time vector
srate_anim = Patterns.srate/dwn;                       % updated sampling rate
tvec = 1/srate_anim : 1/srate_anim : npnts/srate_anim; % create time vector
idx_start = round(Patterns.start*npnts);               % where the animation should start 

% Ask the user if he wants the animation
animate_flag = input('Please inspect the static representation of the motion patterns. Do you want to visualize the animations? (0 or 1)');

% Run only if the flag is enables
if animate_flag == 1
    
    % Check that there are not more than 1 frequency
    if nfrex > 1
        error(['The animation does not support more than 1 frequency.' ...
            ' You may disable the animation or decrease the number of frequencies'])
    end
    
    % Pre-shifted links (1-based indexing)
    bones = [1,2;1,4;2,3;3,4;5,6;5,7;6,7;6,8;8,9;9,10;7,11;11,12;12,13;
        14,15;14,16;15,16;15,17;17,18;18,19;16,20;20,21;21,22];
    
    % The animation goes all within the same figure
    figure(3000), clf
    
    
    for i = idx_start:npnts
        
        for frexi = 1:nfrex
            
            % Time series display
            subplot(2,2,[1 2])
            plot(tvec,ts2plot,'b', 'LineWidth', linewidth), hold on
            plot(tvec(i), ts2plot(i), 'o', 'MarkerSize', 10, 'MarkerFaceColor', 'r')
            xlabel('Time (s)')
            ylabel('Component scores (a.u.)')
            title('Component activation timeseries')
            hold off
            
            % 3D scatter with links (movements component)
            subplot(2,2,3)
            cla
            scatter3(x_comp2plot(:,i), y_comp2plot(:,i), z_comp2plot(:,i), marksize, 'filled');
            hold on
            for k = 1:size(bones,1)
                p1 = bones(k,1);
                p2 = bones(k,2);
                plot3([x_comp2plot(p1,i), x_comp2plot(p2,i)], ...
                    [y_comp2plot(p1,i), y_comp2plot(p2,i)], ...
                    [z_comp2plot(p1,i), z_comp2plot(p2,i)], 'k-', 'LineWidth', linewidth);
            end
            % Optional: fix axis limits if needed
            xlim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
            ylim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
            zlim([min(zData(:)) .1*max(zData(:))+max(zData(:))]);
            xlabel('X')
            ylabel('Y')
            zlabel('Z')
            title('Component backprojection')
            axis square
            
            % 3D scatter with links (marker data)
            subplot(2,2,4)
            cla
            scatter3(xData(:,i), yData(:,i), zData(:,i), marksize, 'filled', 'MarkerFaceColor', .7*[1 0 0]);
            hold on
            for k = 1:size(bones,1)
                p1 = bones(k,1);
                p2 = bones(k,2);
                plot3([xData(p1,i), xData(p2,i)], ...
                    [yData(p1,i), yData(p2,i)], ...
                    [zData(p1,i), zData(p2,i)], 'k-', 'LineWidth', linewidth);
            end
            % Optional: fix axis limits if needed
            xlim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
            ylim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]); 
            zlim([min(zData(:)) .1*max(max(zData(:)))+max(zData(:))]);
            xlabel('X')
            ylabel('Y')
            zlabel('Z')
            title('Original data')
            axis square
            
        end
        
        pause(0.001)
        
    end
    
end

