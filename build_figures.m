function f = build_figures(kind, out, T, n_inc, scen_names, varargin)
% BUILD_FIGURES  Dispatcher for all figure families in the package.
%
% Called by: main.m, once per figure family per sensitivity cell.
%
%   f = build_figures(kind, out, T, n_inc, scen_names, ...)
%
%   kind :
%     'boxplot'    Single-panel weighted boxplot of the total welfare
%                  impact after revenue recycling, by expenditure decile
%                  (horizontal orientation). This is the main paper figure.
%
%     'ver_decomp' Three-panel decomposition of rescaled welfare channels
%                  (consumption, factor income, transfers), vertical 
%                  boxplots.
%
%     'hor_decomp' Median absolute deviation of the welfare impact within
%                  each decile, by component. Measures horizontal
%                  inequity: how differently households with similar
%                  resources are treated.
%
%     'heatmap'    Social welfare across the (epsilon, gamma) plane, one
%                  panel per scenario, with the winning scenario outlined
%                  in red. Requires the name-value pair 'PPS'.
%
%   Name-value pairs:
%     'PPS'  'no' (euros, default) or 'pps' (purchasing power standards).
%            Only used by 'heatmap'; it selects the welfare column AND
%            the colorbar label.
%
%   Output:
%     f - handle to an invisible figure, to be saved by compose_and_export
%
% All figures share the scenario colour scheme:
%     REG    teal
%     MIX    yellow
%     CPRICE magenta
%
% Local functions defined at the end of this file:
%   fig_boxplot, fig_ver_decomp, fig_hor_decomp, fig_heatmap

p = inputParser;
addParameter(p, 'PPS', 'no');
parse(p, varargin{:});
PPS = p.Results.PPS;

nT = height(T);

switch lower(kind)
    case 'boxplot'
        f = fig_boxplot(out.RW_geme3_all, out.EU_wMeanRW_exp_all, T, nT, n_inc, scen_names);
    case 'ver_decomp'
        f = fig_ver_decomp(out.RW_geme3_all, out.EU_wMeanRW_exp_all, T, nT, n_inc, scen_names);
    case 'hor_decomp'
        f = fig_hor_decomp(out.RW_geme3_all, T, n_inc, scen_names);
    case 'heatmap'
        if strcmpi(PPS, 'pps')
            f = fig_heatmap(out.SocialWelfare_PPS_all, 'pps', scen_names);
        else
            f = fig_heatmap(out.SocialWelfare_all, 'no', scen_names);
        end
    otherwise
        error('build_figures: unknown figure kind "%s".', kind);
end
end


%% ==================================================================
%% LOCAL FUNCTIONS
%% ==================================================================

function f = fig_boxplot(RW_geme3_all, EU_wMeanRW_exp_all, T, nT, n_inc, scens)
% Single-panel weighted boxplot of the total welfare impact after
% revenue recycling (RWtot_rev), by EU-wide expenditure decile.
%
% Boxes show the weighted 25th, 50th and 75th percentiles; whiskers
% span the weighted 10th to 90th percentiles. Diamond markers give the
% weighted mean, which can sit outside the box when the distribution is
% skewed. The box width and offsets place the three scenarios
% side by side within each decile.

itemName     = 'RWtot_rev';       % fixed: this is the headline measure
BoxOrientation = 'horizontal';
customColors = [0 0.5 0.5; 1 0.8 0; 0.8 0 0.4];
mkr_colors   = {[0 0.5 0.5], [1 0.8 0], [0.8 0 0.4]};
boxW         = 0.15;

% Stack the three scenarios into one long vector, tagged by scenario
vals_d = []; w_d = []; decile_d = []; variant_d = [];
for s = 1:length(scens)
    sc = scens{s};
    vals_d    = [vals_d;    100 * RW_geme3_all.(sc).(itemName)];  
    w_d       = [w_d;       T.HA10];                              
    decile_d  = [decile_d;  T.ExpDcl_eu];                         
    variant_d = [variant_d; repmat(string(sc), nT, 1)];           
end
decile_d = categorical(decile_d, 1:n_inc, string(1:n_inc));

% Pre-computed weighted decile means (already in %)
wm_exp = cell(1, length(scens));
for s = 1:length(scens)
    wm_exp{s} = EU_wMeanRW_exp_all.(scens{s}){itemName, :};
end

f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2, 5, 18, 14]);
[~, off] = wboxplot(vals_d, w_d, decile_d, 'GroupByColor', variant_d, ...
    'Colors', customColors, 'WhiskerMethod', [10 90], 'MarkerStyle', 'none', ...
    'BoxWidth', boxW, 'Orientation', BoxOrientation);
set(gca, 'YDir', 'normal');

hold on;
if strcmpi(BoxOrientation, 'horizontal')
    for i = 1:n_inc-1
        yl = yline(i + 0.5, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
        yl.HandleVisibility = 'off';
    end
    for c = 1:length(scens)
        hm = plot(wm_exp{c}, (1:n_inc) + off(c), '-kd', 'MarkerSize', 3, ...
                  'MarkerFaceColor', mkr_colors{c}, 'Color', mkr_colors{c}, 'LineWidth', 1.2);
        hm.HandleVisibility = 'off';
    end
    h1_ = xline(0, '--k', 'LineWidth', 0.5); h1_.HandleVisibility = 'off';
    hold off;
    ylim([0.5, n_inc + 0.5]);
    set(gca, 'XGrid', 'on', 'XMinorGrid', 'on');
    xlabel('Welfare impacts (% of total expenditure)');
    ylabel('Expenditure decile');
else
    for i = 1:n_inc-1
        xl = xline(i + 0.5, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
        xl.HandleVisibility = 'off';
    end
    for c = 1:length(scens)
        hm = plot((1:n_inc) + off(c), wm_exp{c}, '-kd', 'MarkerSize', 3, ...
                  'MarkerFaceColor', mkr_colors{c}, 'Color', mkr_colors{c}, 'LineWidth', 1.2);
        hm.HandleVisibility = 'off';
    end
    h1_ = yline(0, '--k', 'LineWidth', 0.5); h1_.HandleVisibility = 'off';
    hold off;
    xlim([0.5, n_inc + 0.5]);
    set(gca, 'YGrid', 'on', 'YMinorGrid', 'on');
    ylabel('Welfare impacts (% of total expenditure)');
    xlabel('Expenditure decile');
end
set(gca, 'FontSize', 7);

% Suppress the automatic legend from wboxplot; the legend is added at
% the composite level by compose_and_export.
lg = findall(f, 'Type', 'Legend');
if ~isempty(lg), delete(lg); end
end

function f = fig_ver_decomp(RW_geme3_all, EU_wMeanRW_exp_all, T, nT, n_inc, scens)
% Decomposition of the welfare impact, vertical boxplots.

targetVars = {'CON_resc', 'FAC_resc', 'Trnsf_resc'};
Titles     = {'Consumption','Factor income', 'Transfers'};

customColors = [0 0.5 0.5; 1 0.8 0; 0.8 0 0.4];
mkr_colors   = {[0 0.5 0.5], [1 0.8 0], [0.8 0 0.4]};
boxW         = 0.15;

f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2, 2, 25, 14]);
tiledlayout(1, 3, 'TileSpacing', 'tight', 'Padding', 'tight');

for i = 1:length(targetVars)
    itemName = targetVars{i};

    vals_d = []; w_d = []; decile_d = []; variant_d = [];
    for s = 1:length(scens)
        sc = scens{s};
        vals_d    = [vals_d;    100 * RW_geme3_all.(sc).(itemName)];  
        w_d       = [w_d;       T.HA10];                              
        decile_d  = [decile_d;  T.ExpDcl_eu];                         
        variant_d = [variant_d; repmat(string(sc), nT, 1)];          
    end
    decile_d_cat = categorical(decile_d, 1:n_inc, string(1:n_inc));

    wm_exp = cell(1, length(scens));
    for s = 1:length(scens)
        wm_exp{s} = EU_wMeanRW_exp_all.(scens{s}){itemName, :};
    end

    nexttile;
    [~, off] = wboxplot(vals_d, w_d, decile_d_cat, 'GroupByColor', variant_d, ...
        'Colors', customColors, 'WhiskerMethod', [10 90], 'MarkerStyle', 'none', ...
        'BoxWidth', boxW, 'Orientation', 'vertical');

    hold on;
    for d = 1:n_inc-1
        xl = xline(d + 0.5, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
        xl.HandleVisibility = 'off';
    end
    for c = 1:length(scens)
        hm = plot((1:n_inc) + off(c), wm_exp{c}, '-kd', 'MarkerSize', 3, ...
                  'MarkerFaceColor', mkr_colors{c}, 'Color', mkr_colors{c}, 'LineWidth', 1.2);
        hm.HandleVisibility = 'off';
    end
    h_zero = yline(0, '--k', 'LineWidth', 0.5); h_zero.HandleVisibility = 'off';
    hold off;

    xlim([0.5, n_inc + 0.5]);
    ylim([-2, 2]);
    set(gca, 'YGrid', 'on', 'YMinorGrid', 'on', 'XTick', 1:n_inc, 'FontSize', 7);
    title(Titles{i}, 'FontSize', 8);
    if i == 1, ylabel('RW (% of total expenditure)', 'FontSize', 8); end
    xlabel('Expenditure decile', 'FontSize', 8);
end

lg = findall(f, 'Type', 'Legend');
if ~isempty(lg), delete(lg); end

% Shared scenario legend along the bottom, built from dummy handles.
hold on;
h_leg = gobjects(1, length(scens));
for c = 1:length(scens)
    h_leg(c) = plot(NaN, NaN, '-s', 'Color', customColors(c,:), ...
        'MarkerFaceColor', customColors(c,:), 'MarkerSize', 6, 'LineWidth', 1.2);
end
hold off;
lgd = legend(h_leg, scens, 'FontSize', 8, 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';
end

function f = fig_hor_decomp(RW_geme3_all, T, n_inc, scens)
% Median absolute deviation (MAD) of the welfare impact within each
% expenditure decile, by component.
%
% MAD is computed as the weighted median of |x - weighted median(x)|
% within the decile. It is a robust measure of horizontal inequity:
% a high value means households in the same decile — with similar
% resources — experience very different impacts.
%
% The REG scenario typically shows high MAD in the lower deciles,
% driven by bimodal solid-fuel consumption among poorer households in
% Central and Eastern Europe.

madVars = {'RWtot_rev','LAB','CAP','FAC_resc','CON','CON_resc','Trnsf','Trnsf_resc'};
Titles  = {'Total welfare','Labour income','Capital income','Factor income (rescaled)', ...
           'Consumption','Consumption (rescaled)','Transfers','Transfers (rescaled)'};

customColors = [0 0.5 0.5; 1 0.8 0; 0.8 0 0.4];
markers      = {'o', 's', '^'};
n_var        = length(madVars);
n_sc         = length(scens);

EU_MAD = zeros(n_var, n_inc, n_sc);
for s = 1:n_sc
    for d = 1:n_inc
        idx = T.ExpDcl_eu == d;
        X   = RW_geme3_all.(scens{s}){idx, madVars};
        w   = T{idx, 'HA10'};
        EU_MAD(:, d, s) = 100 * wprct(abs(X - wprct(X, w, 50)), w, 50)';
    end
end

f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2, 2, 25, 8]);
tiledlayout(2, 4, 'TileSpacing', 'tight', 'Padding', 'tight');

x = 1:n_inc;
for i = 1:n_var
    nexttile;
    h = plot(x, squeeze(EU_MAD(i, :, :)), 'LineWidth', 1.2);
    for c = 1:n_sc
        set(h(c), 'Color', customColors(c,:), 'Marker', markers{c}, 'MarkerSize', 4);
    end
    xlim([0.5, n_inc + 0.5]);
    set(gca, 'XTick', 1:n_inc, 'FontSize', 7, 'FontName', 'Arial');
    title(Titles{i}, 'FontSize', 8);
    grid on;
    if mod(i-1, 4) == 0, ylabel('MAD in RWs', 'FontSize', 8);        end
    if i > 4,            xlabel('Expenditure decile', 'FontSize', 8); end
end

hold on;
h_leg = gobjects(1, n_sc);
for c = 1:n_sc
    h_leg(c) = plot(NaN, NaN, '-s', 'Color', customColors(c,:), ...
        'MarkerFaceColor', customColors(c,:), 'MarkerSize', 6, 'LineWidth', 1.2);
end
hold off;
lgd = legend(h_leg, scens, 'FontSize', 8, 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';
end

function f = fig_heatmap(SocialWelfare_all, PPS, scens)
% Social welfare across the (gamma, epsilon) plane, one panel per scenario.
%
%   x-axis: gamma   weight on the horizontal equity term
%   y-axis: epsilon inequality aversion
%
% rho and tau are held fixed at 1 (see rho_fixed / tau_fixed below);
% change them to slice the grid differently.
%
% All three panels share a common colour scale, so they are directly
% comparable. The red outline marks, for each cell, the scenario that
% achieves the highest social welfare — that is, the scenario that wins
% at that combination of distributional preferences.
%
% Boundary lines are drawn at per-cell midpoint edges (x - d_gamma/2,
% y - d_epsl/2). Using a fixed scalar offset instead would misalign the
% outline whenever the grid spacing differs between the two axes.

tau_fixed   = 1;
rho_fixed   = 1;
epsl_range  = [0, 2];
gamma_range = [0, 1];
n_sc        = length(scens);

f = figure('Visible', 'off');
set(gcf, 'Position', [100, 100, 850, 300]);
tiledlayout(1, n_sc, 'TileSpacing', 'compact', 'Padding', 'loose');

% Viridis-like colormap built from three anchor colours.
n_colors = 256;
anchors  = [80 27 81; 32 144 140; 255 255 0] / 255;
half     = floor(n_colors / 2);
cmap     = [interp1([0 1], anchors(1:2,:), linspace(0, 1, half)); ...
            interp1([0 1], anchors(2:3,:), linspace(0, 1, n_colors - half))];
colormap(cmap);

% Select the welfare column and the matching colorbar label.
if strcmpi(PPS, 'pps')
    welfareVar = 'Welfare_PPS';
    cbLabel    = 'Social welfare (PPS)';
else
    welfareVar = 'Welfare';
    cbLabel    = 'Social welfare (€)';
end

Z_all = cell(1, n_sc); epsl_all = cell(1, n_sc); gamma_all = cell(1, n_sc);
for s = 1:n_sc
    SW       = SocialWelfare_all.(scens{s});
    subsetSW = SW(SW.rho == rho_fixed & SW.tau == tau_fixed & ...
                  SW.epsilon >= epsl_range(1)  & SW.epsilon <= epsl_range(2) & ...
                  SW.gamma   >= gamma_range(1) & SW.gamma   <= gamma_range(2), :);
    epsl_u  = unique(subsetSW.epsilon);
    gamma_u = unique(subsetSW.gamma);

    Z = zeros(numel(epsl_u), numel(gamma_u));
    for i = 1:numel(epsl_u)
        for j = 1:numel(gamma_u)
            mask   = subsetSW.epsilon == epsl_u(i) & subsetSW.gamma == gamma_u(j);
            Z(i,j) = subsetSW.(welfareVar)(mask);
        end
    end
    Z_all{s} = Z;  epsl_all{s} = epsl_u;  gamma_all{s} = gamma_u;
end

% Shared colour limits across panels
all_vals    = cell2mat(cellfun(@(z) z(:), Z_all, 'UniformOutput', false)');
all_vals    = all_vals(isfinite(all_vals));
clim_shared = [min(all_vals), max(all_vals)];

% Winner mask: which scenario maximises welfare in each cell
n_eps_u = size(Z_all{1}, 1);
n_gam_u = size(Z_all{1}, 2);
Z_stack = cat(3, Z_all{:});
masks   = false(n_eps_u, n_gam_u, n_sc);
for s = 1:n_sc
    masks(:,:,s) = Z_stack(:,:,s) == max(Z_stack, [], 3);
end

for s = 1:n_sc
    epsl_u  = epsl_all{s};
    gamma_u = gamma_all{s};
    d_gamma = gamma_u(2) - gamma_u(1);
    d_epsl  = epsl_u(2)  - epsl_u(1);

    nexttile;
    imagesc(gamma_u, epsl_u, Z_all{s});
    clim(clim_shared);
    axis ij;

    % Outline the winning region: draw an edge only where the
    % neighbouring cell is not also a winner.
    hold on;
    for i = 1:n_eps_u
        for j = 1:n_gam_u
            if masks(i,j,s)
                x = gamma_u(j) - d_gamma/2;
                y = epsl_u(i)  - d_epsl/2;
                if i == 1       || ~masks(i-1,j,s), line([x, x+d_gamma], [y, y],                 'Color','r','LineWidth',2); end
                if i == n_eps_u || ~masks(i+1,j,s), line([x, x+d_gamma], [y+d_epsl, y+d_epsl],   'Color','r','LineWidth',2); end
                if j == 1       || ~masks(i,j-1,s), line([x, x],         [y, y+d_epsl],          'Color','r','LineWidth',2); end
                if j == n_gam_u || ~masks(i,j+1,s), line([x+d_gamma, x+d_gamma], [y, y+d_epsl],  'Color','r','LineWidth',2); end
            end
        end
    end
    hold off;

    ax = gca;
    ax.FontSize      = 8;
    ax.XAxisLocation = 'top';
    xticks(gamma_u(1:2:end));
    xticklabels(arrayfun(@(v) sprintf('%.1f', v), gamma_u(1:2:end), 'UniformOutput', false));
    yticks(epsl_u(1:2:end));
    yticklabels(arrayfun(@(v) sprintf('%.1f', v), epsl_u(1:2:end), 'UniformOutput', false));
    ax.XLabel.FontSize = 9;
    ax.YLabel.FontSize = 9;
    xlabel('Horizontal equity weight \gamma');
    if s == 1, ylabel('Inequality aversion \epsilon'); end
    title(scens{s}, 'Interpreter', 'none', 'FontSize', 8, 'FontWeight', 'normal');
end

cb                = colorbar;
cb.Layout.Tile    = 'east';
cb.Label.String   = cbLabel;
cb.FontSize       = 9;
cb.Label.FontSize = 10;
end