function FREQNESS_Visualizer_Mocap(GED,Landscape,Patterns)
% ========================================================================
%  FREQNESS VISUALIZER: BODILY NETWORK LANDSCAPE & BODILY ACTIVATION PATTERNS
%
%  This visualization is meant to scale from one to multiple participants,
%  as long as they share the same reference point and spatial coordinates
%  as defined during data acquisition.
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


%% Define visualization for N participants

% Check input size to verify if more than one participant is being analyzed
if length(size(GED.evals)) < 3 % no extra dimension in the input
    nsubs = 1;
else
    nsubs = size(GED.evals,3);
end
disp(['Visualization will include ' num2str(nsubs) ' participants']);



%% Output #1: NETWORK LANDSCAPE




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

% Define colormap
colors = flipud([linspace(0,1,Landscape.ncomps)', zeros(Landscape.ncomps,1), linspace(1,0,Landscape.ncomps)']);

% Plot all participants
figure
for subi = 1:nsubs

    % Interpolate GED data onto this uniform log2 frequency axis
    resampled_GED = zeros(Landscape.ncomps, nPoints);
    for i = 1:Landscape.ncomps
        resampled_GED(i,:) = interp1(Landscape.frex, GED.evals(i,idx_frex2plot,subi), frex_uniform, 'linear', 'extrap');
    end

    subplot(nsubs,1,subi), hold on
    for i = 1:Landscape.ncomps
        if i == 1
            plot(log2(frex_uniform), resampled_GED(i,:), 'Color', colors(i,:), 'LineWidth', 3);
        else
            plot(log2(frex_uniform), resampled_GED(i,:), 'Color', colors(i,:), 'LineWidth', 2);
        end
    end
    xlim([min(log2(frex_uniform)) , max(log2(frex_uniform))])
    ylim([0 100]) % assuming eigenvalues normalized in %
    title(['Participant #' num2str(subi)])

    % Define octave ticks
    octave_ticks = unique(2.^round(log2(Landscape.frex)));
    octave_ticks = octave_ticks(octave_ticks >= min(Landscape.frex) & octave_ticks <= max(Landscape.frex));
    % Apply to plot
    xticks(log2(octave_ticks))        % visualize as log spaced
    xticklabels(string(octave_ticks)) % read as linear
    xtickangle(45)
    xlabel('Frequency (Hz)', 'FontSize', 14, 'FontWeight', 'bold')
    ylabel('Explained variance (%)', 'FontSize', 14, 'FontWeight', 'bold')
    sgtitle('Bodily networks prominence across frequencies', 'FontSize', 16, 'FontWeight', 'bold')
    grid on
    hold off

    % Create custom legend with 'GED component #' labels
    legendLabels = arrayfun(@(x) sprintf('GED component #%d', x), 1:Landscape.ncomps, 'UniformOutput', false);
    legend(legendLabels, 'Location', 'Northeast', 'FontSize', 12)
    grid minor
    set(gca, 'FontSize', 12, 'LineWidth', 1.5) % Make axis and labels more visible
    box on
    set(gcf, 'Color', 'w'); % Set figure background to white

end

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
x_idx = 1:3:nmarks-2;
y_idx = 2:3:nmarks-1;
z_idx = 3:3:nmarks;

% Assign separately X,Y,Z data, per participant
for subi = 1:nsubs
    xData(:,:,subi) = markData(x_idx,:,subi);
    yData(:,:,subi) = markData(y_idx,:,subi);
    zData(:,:,subi) = markData(z_idx,:,subi);
end

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
    for subi = 1:nsubs
        % X
        subplot(nsubs, 3, 3*(subi-1)+1)
        imagesc(GED.pats(x_idx,Patterns.comp,idxfrex(frexi),subi))
        xticks([])
        yticks(1:nmarks/3)
        yticklabels(Patterns.labels)
        title(['Participant #' num2str(subi) ' - X'])
        colorbar
        % Y
        subplot(nsubs, 3, 3*(subi-1)+2)
        imagesc(GED.pats(y_idx,Patterns.comp,idxfrex(frexi),subi))
        xticks([])
        yticks(1:nmarks/3)
        yticklabels(Patterns.labels)
        title(['Participant #' num2str(subi) ' - Y'])
        colorbar
        % Z
        subplot(nsubs, 3, 3*(subi-1)+3)
        imagesc(GED.pats(z_idx,Patterns.comp,idxfrex(frexi),subi))
        xticks([])
        yticks(1:nmarks/3)
        yticklabels(Patterns.labels)
        title(['Participant #' num2str(subi) ' - Z'])
        colorbar
    end
    set(gcf, 'Color', 'w'); % Set figure background to white
    % General
    sgtitle(['Movement frequency: ' num2str(thisfrex) 'Hz'])


    %% Static skeleton

    figure, clf
    for subi = 1:nsubs
        % Inflate the de-meaned projection
        remeaner = 1*squeeze( mean(markData(:,:,subi),2) ); % compute teh means by channel

        % Demean and boost the component timeseries, for visualization
        booster = 10; % I guess this should be proportional to the VARIANCE instead, but the componets is demeaned
        % NOTE: booster previously hard-coded to 15, seemed to work for the tested
        % particiapnts
        ts2plot(:,subi) = booster * (GED.ts(Patterns.comp,:,idxfrex(frexi),subi)-mean(GED.ts(Patterns.comp,:,idxfrex(frexi),subi)));

        % Backprojection on 3 dimensions
        x_comp2plot(:,:,subi) = GED.pats(x_idx,Patterns.comp,idxfrex(frexi),subi) * ts2plot(:,subi)' + remeaner(x_idx);
        y_comp2plot(:,:,subi) = GED.pats(y_idx,Patterns.comp,idxfrex(frexi),subi) * ts2plot(:,subi)' + remeaner(y_idx);
        z_comp2plot(:,:,subi) = GED.pats(z_idx,Patterns.comp,idxfrex(frexi),subi) * ts2plot(:,subi)' + remeaner(z_idx);

        % % Define limits
        % xmin = min(x_comp2plot(:));
        % ymin = min(y_comp2plot(:));
        % zmin = min(z_comp2plot(:));
        % xmax = max(x_comp2plot(:));
        % ymax = max(y_comp2plot(:));
        % zmax = max(z_comp2plot(:));

        % Static scatterplot 3D (hack: use initial position and map the act patterns on the marker color, by XYZ)
        nscale = 1000;                    % Number of colors in the colormap
        col_static = .95*jet(nscale);      % Create a jet colormap
        marksize = 100;

        % Normalize all activation patterns to [-1, 1]
        all_pats2see = GED.pats(:,Patterns.comp,idxfrex(frexi),subi) / max(abs(GED.pats(:,Patterns.comp,idxfrex(frexi),subi)));

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
        linewidth = 1.7;

        % Plot for X dimension
        subplot(131)
        scatter3(x_comp2plot(:,1,subi), y_comp2plot(:,1,subi), z_comp2plot(:,1,subi), marksize, col_static(color_idx_x,:), 'filled');
        hold on
        % for k = 1:size(bones,1)
        %     p1 = bones(k,1);
        %     p2 = bones(k,2);
        %     plot3([x_comp2plot(p1,1,subi), x_comp2plot(p2,1,subi)], ...
        %         [y_comp2plot(p1,1,subi), y_comp2plot(p2,1,subi)], ...
        %         [z_comp2plot(p1,1,subi), z_comp2plot(p2,1,subi)], 'k-', 'Linewidth', linewidth);
        % end
        colorbar
        xlim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]);
        ylim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]);
        zlim([min(zData(:))-.1 max(zData(:))+.1]); % tiny offset to get increasing values in the case of 2D data
        xlabel('X')
        ylabel('Y')
        zlabel('Z')
        title('X')
        axis square
        % Plot for Y dimension
        subplot(132)
        scatter3(x_comp2plot(:,1,subi), y_comp2plot(:,1,subi), z_comp2plot(:,1,subi), marksize, col_static(color_idx_y,:), 'filled');
        hold on
        % for k = 1:size(bones,1)
        %     p1 = bones(k,1);
        %     p2 = bones(k,2);
        %     plot3([x_comp2plot(p1,1,subi), x_comp2plot(p2,1,subi)], ...
        %         [y_comp2plot(p1,1,subi), y_comp2plot(p2,1,subi)], ...
        %         [z_comp2plot(p1,1,subi), z_comp2plot(p2,1,subi)], 'k-', 'Linewidth', linewidth);
        % end
        xlim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]);
        ylim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]);
        zlim([min(zData(:))-.1 max(zData(:))+.1]);
        xlabel('X')
        ylabel('Y')
        zlabel('Z')
        title('Y')
        axis square
        colorbar
        % Plot for Z dimension
        subplot(133)
        scatter3(x_comp2plot(:,1,subi), y_comp2plot(:,1,subi), z_comp2plot(:,1,subi), marksize, col_static(color_idx_z,:), 'filled');
        hold on
        % for k = 1:size(bones,1)
        %     p1 = bones(k,1);
        %     p2 = bones(k,2);
        %     plot3([x_comp2plot(p1,1,subi), x_comp2plot(p2,1,subi)], ...
        %         [y_comp2plot(p1,1,subi), y_comp2plot(p2,1,subi)], ...
        %         [z_comp2plot(p1,1,subi), z_comp2plot(p2,1,subi)], 'k-', 'Linewidth', linewidth);
        % end
        xlim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]);
        ylim([ min([xData(:);yData(:)]) , max([xData(:);yData(:)]) ]);
        zlim([min(zData(:))-.1 max(zData(:))+.1]);
        xlabel('X')
        ylabel('Y')
        zlabel('Z')
        title('Z')
        axis square
        colorbar
        % General title
        sgtitle(['Movement frequency: ' num2str(thisfrex) 'Hz'])

    end
    set(gcf, 'Color', 'w'); % Set figure background to white

end


%% Output #3: BODILY SPATIAL ACTIVATION PATTERNS (3D animation)


% Downsample for faster visualization (NOTE: it should scale with the N timepoints)
dwn = 10 + 5*nsubs;
ts2plot = ts2plot(1:dwn:end,:);
x_comp2plot = x_comp2plot(:,1:dwn:end,:);
y_comp2plot = y_comp2plot(:,1:dwn:end,:);
z_comp2plot = z_comp2plot(:,1:dwn:end,:);
xData = xData(:,1:dwn:end,:);
yData = yData(:,1:dwn:end,:);
zData = zData(:,1:dwn:end,:);
npnts = floor(npnts/dwn);

% Create time vector
srate_anim = Patterns.srate/dwn;                       % updated sampling rate
tvec = 1/srate_anim : 1/srate_anim : npnts/srate_anim; % create time vector
idx_start = round(Patterns.start*npnts);               % where the animation should start

% Ask the user if he wants the animation
animate_flag = input('Please inspect the static representation of the motion patterns. Do you want to visualize the animations? (0 or 1)');

% Run only if the flag is enables
if animate_flag == 1

    % NOTE: consider the following in case the animation lags
    % If you use this approach, you'll have to adjust the bones structure
    % % Re-shape to 3D scatter participants without a loop
    % x_comp2plot = reshape(x_comp2plot, 2*(nmarks/3),[],1 );
    % y_comp2plot = reshape(y_comp2plot, 2*(nmarks/3),[],1 );
    % z_comp2plot = reshape(z_comp2plot, 2*(nmarks/3),[],1 );
    % xData = reshape(xData, 2*(nmarks/3),[],1 );
    % yData = reshape(yData, 2*(nmarks/3),[],1 );
    % zData = reshape(zData, 2*(nmarks/3),[],1 );

    % Attribute colors to participants
    colors_subs = [0 0 1 ; 1 0 0];


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
    set(gcf, 'Color', 'w'); % Set figure background to white

    for i = idx_start:npnts
        for frexi = 1:nfrex

            % === Clear subplots once per frame ===
            subplot(2,2,[1 2]), cla
            subplot(2,2,3), cla
            subplot(2,2,4), cla

            for subi = 1:nsubs

                % Time series display
                subplot(2,2,[1 2])
                plot(tvec, ts2plot(:,subi)', 'Color', colors_subs(subi,:), 'LineWidth', linewidth), hold on
                plot(tvec(i), ts2plot(i,subi), 'o', 'MarkerSize', 10, 'MarkerFaceColor', .3*colors_subs(subi,:))
                xlabel('Time (s)')
                ylabel('Component scores (a.u.)')
                title('Component activation timeseries')

                % 3D scatter with links (movements component)
                subplot(2,2,3)
                scatter3(x_comp2plot(:,i,subi), y_comp2plot(:,i,subi), z_comp2plot(:,i,subi), marksize, 'filled', 'MarkerFaceColor', .7*colors_subs(subi,:));
                hold on
                % for k = 1:size(bones,1)
                %     p1 = bones(k,1);
                %     p2 = bones(k,2);
                %     plot3([x_comp2plot(p1,i,subi), x_comp2plot(p2,i,subi)], ...
                %         [y_comp2plot(p1,i,subi), y_comp2plot(p2,i,subi)], ...
                %         [z_comp2plot(p1,i,subi), z_comp2plot(p2,i,subi)], 'k-', 'LineWidth', linewidth);
                % end
                xlim([min([xData(:);yData(:)]), max([xData(:);yData(:)])]);
                ylim([min([xData(:);yData(:)]), max([xData(:);yData(:)])]);
                zlim([min(zData(:)), .1*max(zData(:))+max(zData(:))+.1]);
                xlabel('X'), ylabel('Y'), zlabel('Z')
                title('Component backprojection')
                axis square

                % 3D scatter with links (marker data)
                subplot(2,2,4)
                scatter3(xData(:,i,subi), yData(:,i,subi), zData(:,i,subi), marksize, 'filled', 'MarkerFaceColor', .7*colors_subs(subi,:));
                hold on
                % for k = 1:size(bones,1)
                %     p1 = bones(k,1);
                %     p2 = bones(k,2);
                %     plot3([xData(p1,i,subi), xData(p2,i,subi)], ...
                %         [yData(p1,i,subi), yData(p2,i,subi)], ...
                %         [zData(p1,i,subi), zData(p2,i,subi)], 'k-', 'LineWidth', linewidth);
                % end
                xlim([min([xData(:);yData(:)]), max([xData(:);yData(:)])]);
                ylim([min([xData(:);yData(:)]), max([xData(:);yData(:)])]);
                zlim([min(zData(:)), .1*max(max(zData(:)))+max(zData(:))+.1]);
                xlabel('X'), ylabel('Y'), zlabel('Z')
                title('Original data')
                axis square

            end

            pause(0.1) %pause(0.001)

        end
    end

end

end
