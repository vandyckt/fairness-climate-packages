function [h, offsets] = wboxplot(X, w, groups, varargin)
% WBOXPLOT Weighted boxplot using weighted percentiles.
%
%   [h, offsets] = wboxplot(X, w, groups) creates weighted boxplots.
%
%   Inputs:
%     X      - data vector (n x 1)
%     w      - weight vector (n x 1), e.g. household sampling weights
%     groups - grouping variable (n x 1) for primary axis
%              (numeric, cell/string array, string array, or categorical)
%
%   Optional name-value pairs:
%     'GroupByColor'  - vector (n x 1) for side-by-side coloring within groups
%                       (numeric, cell/string array, string array, or categorical)
%     'BoxWidth'      - width of each box (default 0.2)
%     'Colors'        - Nx3 RGB matrix, one row per color group
%     'MarkerStyle'   - outlier marker style, 'none' to hide (default '+')
%     'WhiskerMethod' - 'iqr' (default, Tukey's 1.5*IQR) or [lo, hi] percentiles
%     'Orientation'   - 'vertical' (default, boxes along x-axis, values on y-axis)
%                       'horizontal' (boxes along y-axis, values on x-axis)
%
%   Outputs:
%     h       - figure handle
%     offsets - vector of x (or y) offsets for each color group, useful for
%               overlaying means at the correct positions
%
%   Examples:
%     % Vertical (default)
%     [h, off] = wboxplot(vals, w, groups, 'GroupByColor', variant, 'BoxWidth', 0.15);
%
%     % Horizontal orientation
%     [h, off] = wboxplot(vals, w, groups, 'Orientation', 'horizontal');
%
%     % Then plot means at correct positions:
%     plot((1:nGroups) + off(c), means, '-kd');   % vertical
%     plot(means, (1:nGroups) + off(c), '-kd');   % horizontal

    %% =====================================================================
    %% Parse optional inputs
    %% =====================================================================
    p = inputParser;
    addParameter(p, 'GroupByColor', []);
    addParameter(p, 'BoxWidth', 0.2);
    addParameter(p, 'Colors', []);
    addParameter(p, 'MarkerStyle', '+');
    addParameter(p, 'WhiskerMethod', 'iqr');
    addParameter(p, 'Orientation', 'vertical');
    parse(p, varargin{:});

    colorVar      = p.Results.GroupByColor;
    boxW          = p.Results.BoxWidth;
    colors        = p.Results.Colors;
    mrkStyle      = p.Results.MarkerStyle;
    whiskerMethod = p.Results.WhiskerMethod;
    orientation   = p.Results.Orientation;

    isHoriz = strcmpi(orientation, 'horizontal');

    % Determine whisker mode
    if ischar(whiskerMethod) || isstring(whiskerMethod)
        useIQR = true;
    else
        useIQR = false;
        whiskerPctLo = whiskerMethod(1);
        whiskerPctHi = whiskerMethod(2);
    end

    %% =====================================================================
    %% Identify group categories and color categories
    %% =====================================================================
    if iscategorical(groups)
        cats = cellstr(categories(groups));
    elseif isnumeric(groups) || islogical(groups)
        cats = num2cell(unique(groups, 'stable'));
    elseif isstring(groups)
        cats = cellstr(unique(groups, 'stable'));
    else  % cell array of chars
        cats = unique(groups, 'stable');
    end
    nCats = length(cats);

    if isempty(colorVar)
        colorCats = {''};
        nColors = 1;
    else
        if iscategorical(colorVar)
            colorCats = cellstr(categories(colorVar));
        elseif isnumeric(colorVar) || islogical(colorVar)
            colorCats = num2cell(unique(colorVar, 'stable'));
        elseif isstring(colorVar)
            colorCats = cellstr(unique(colorVar, 'stable'));
        else  % cell array of chars
            colorCats = unique(colorVar, 'stable');
        end
        nColors = length(colorCats);
    end

    if isempty(colors)
        colors = lines(nColors);
    end

    %% =====================================================================
    %% Compute offsets for side-by-side boxes
    %% =====================================================================
    gap     = 0.05;
    totalW  = boxW * nColors + gap * (nColors - 1);
    offsets = linspace(-totalW/2 + boxW/2, totalW/2 - boxW/2, nColors);

    %% =====================================================================
    %% Draw boxplots
    %% =====================================================================
    cla;
    hold on;
    h_leg = gobjects(nColors, 1);

    for c = 1:nColors
        for g = 1:nCats

            %% Step 1: Select data
            if iscategorical(groups)
                gmask = strcmp(cellstr(groups), cats{g});
            elseif isnumeric(groups) || islogical(groups)
                gmask = groups == cats{g};
            else  % string array or cell array of chars — both work with strcmp
                gmask = strcmp(groups, cats{g});
            end

            if isempty(colorVar)
                mask = gmask;
            else
                if iscategorical(colorVar)
                    cmask = strcmp(cellstr(colorVar), colorCats{c});
                elseif isnumeric(colorVar) || islogical(colorVar)
                    cmask = colorVar == colorCats{c};
                else  % string array or cell array of chars
                    cmask = strcmp(colorVar, colorCats{c});
                end
                mask = gmask & cmask;
            end

            xi = X(mask);
            wi = w(mask);

            if isempty(xi) || all(isnan(xi))
                continue
            end

            valid = ~isnan(xi);
            xi = xi(valid);
            wi = wi(valid);

            %% Step 2: Weighted box statistics
            pcts    = wprct(xi, wi, [25 50 75]);
            q1      = pcts(1);
            med     = pcts(2);
            q3      = pcts(3);
            iqr_val = q3 - q1;

            %% Step 3: Whisker endpoints
            if useIQR
                lower_fence = q1 - 1.5 * iqr_val;
                upper_fence = q3 + 1.5 * iqr_val;
                whi_lo = min(xi(xi >= lower_fence));
                whi_hi = max(xi(xi <= upper_fence));
            else
                whi_pcts    = wprct(xi, wi, [whiskerPctLo, whiskerPctHi]);
                whi_lo      = whi_pcts(1);
                whi_hi      = whi_pcts(2);
                lower_fence = whi_lo;
                upper_fence = whi_hi;
            end

            if isempty(whi_lo), whi_lo = q1; end
            if isempty(whi_hi), whi_hi = q3; end

            %% Step 4: Position with offset
            pos = g + offsets(c);

            %% Steps 5-8: Draw box, median, whiskers, outliers
            if isHoriz
                % Horizontal: groups on y-axis, values on x-axis
                bx = [q1,  q3,  q3,  q1,  q1];
                by = [pos-boxW/2, pos-boxW/2, pos+boxW/2, pos+boxW/2, pos-boxW/2];
                hp = fill(bx, by, colors(c,:), 'FaceAlpha', 0.4, ...
                          'EdgeColor', colors(c,:), 'LineWidth', 1);
                if g == 1, h_leg(c) = hp; end

                plot([med, med], [pos-boxW/2, pos+boxW/2], '-', ...
                     'Color', colors(c,:), 'LineWidth', 1.5);
                plot([whi_lo, q1],   [pos, pos], '-', 'Color', colors(c,:), 'LineWidth', 0.8);
                plot([q3,    whi_hi],[pos, pos], '-', 'Color', colors(c,:), 'LineWidth', 0.8);
                plot([whi_lo, whi_lo],[pos-boxW/4, pos+boxW/4], '-', ...
                     'Color', colors(c,:), 'LineWidth', 0.8);
                plot([whi_hi, whi_hi],[pos-boxW/4, pos+boxW/4], '-', ...
                     'Color', colors(c,:), 'LineWidth', 0.8);

                if ~strcmp(mrkStyle, 'none')
                    outliers = xi(xi < lower_fence | xi > upper_fence);
                    if ~isempty(outliers)
                        plot(outliers, pos*ones(size(outliers)), mrkStyle, ...
                             'Color', colors(c,:), 'MarkerSize', 3);
                    end
                end

            else
                % Vertical (default): groups on x-axis, values on y-axis
                bx = [pos-boxW/2, pos+boxW/2, pos+boxW/2, pos-boxW/2, pos-boxW/2];
                by = [q1, q1, q3, q3, q1];
                hp = fill(bx, by, colors(c,:), 'FaceAlpha', 0.4, ...
                          'EdgeColor', colors(c,:), 'LineWidth', 1);
                if g == 1, h_leg(c) = hp; end

                plot([pos-boxW/2, pos+boxW/2], [med, med], '-', ...
                     'Color', colors(c,:), 'LineWidth', 1.5);
                plot([pos, pos], [whi_lo, q1],   '-', 'Color', colors(c,:), 'LineWidth', 0.8);
                plot([pos, pos], [q3,    whi_hi], '-', 'Color', colors(c,:), 'LineWidth', 0.8);
                plot([pos-boxW/4, pos+boxW/4], [whi_lo, whi_lo], '-', ...
                     'Color', colors(c,:), 'LineWidth', 0.8);
                plot([pos-boxW/4, pos+boxW/4], [whi_hi, whi_hi], '-', ...
                     'Color', colors(c,:), 'LineWidth', 0.8);

                if ~strcmp(mrkStyle, 'none')
                    outliers = xi(xi < lower_fence | xi > upper_fence);
                    if ~isempty(outliers)
                        plot(pos*ones(size(outliers)), outliers, mrkStyle, ...
                             'Color', colors(c,:), 'MarkerSize', 3);
                    end
                end
            end

        end  % end groups loop
    end  % end colors loop

    hold off;

    %% =====================================================================
    %% Set axis ticks and legend
    %% =====================================================================
    if isnumeric(cats{1})
        tickLabels = arrayfun(@num2str, cell2mat(cats), 'UniformOutput', false);
    else
        tickLabels = cats;
    end

    if isHoriz
        set(gca, 'YTick', 1:nCats, 'YTickLabel', tickLabels, ...
                 'YLim', [0.5, nCats+0.5], 'YDir', 'normal');
    else
        set(gca, 'XTick', 1:nCats, 'XTickLabel', tickLabels, ...
                 'XLim', [0.5, nCats+0.5], 'YDir', 'normal');
    end

    if nColors > 1
        if isnumeric(colorCats{1})
            legendLabels = arrayfun(@num2str, cell2mat(colorCats), 'UniformOutput', false);
        else
            legendLabels = colorCats;
        end
        legend(h_leg, legendLabels, 'Orientation', 'horizontal', ...
               'Location', 'southoutside', 'FontSize', 7);
    end

    h = gcf;
end