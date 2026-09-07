%% DATA_PREPARATION  Load and prepare the matched HBS-SILC household dataset.
%
% Called by: main.m (first step of the pipeline)
%
% WHAT THIS SCRIPT DOES
%   1. Loads the statistically matched HBS-SILC dataset (T).
%   2. Drops Sweden (missing income source data) and households with
%      missing, zero or negative gross income, or negative net income.
%   3. Defines the COICOP expenditure categories used in the analysis
%      (CPmod), excluding imputed rents.
%   4. Computes average income-source shares (labour / capital / transfers)
%      across the 100 matched SILC draws.
%   5. Computes equivalized expenditure and income (modified OECD scale)
%      and their PPS-adjusted counterparts.
%   6. Assigns EU-wide expenditure deciles (ExpDcl_eu) — the decile
%      variable used throughout the rest of the pipeline.
%   7. Produces Figure S1 (budget shares and income shares by decile).
%
% KEY OUTPUTS CONSUMED DOWNSTREAM
%   T            - cleaned household table with all derived variables
%   CPmod        - cell array of COICOP expenditure variable names
%   PPS_2015     - table of 2015 purchasing power parities by country
%   T.ExpDcl_eu  - EU-wide expenditure decile (1 = poorest, 10 = richest)
%   T.LABsh, T.CAPsh, T.TRNsh - income source shares
%   T.TotExp, T.EqvTotExp     - total and equivalized expenditure
%   T.DispInc_avg             - average disposable income across 100 draws
%
% ITALY NOTE
%   Italy has no usable HBS income variable (EUR_HH095). Downstream code
%   (run_microsim.m) substitutes DispInc_avg for Italy. That
%   substitution happens there, not here; here we only ensure DispInc_avg
%   exists for all countries. Income-based deciles are set to NaN for IT.
%
% Local functions defined at the end of this file:
%   assignDeciles, wNegative, medianIQRplot_EU

%% ------------------------------------------------------------------
%% 0. Options
%% ------------------------------------------------------------------
make_figure_S1 = true;   % set false to skip Figure S1 (saves ~10 s)

%% ------------------------------------------------------------------
%% 1. Load the matched HBS-SILC dataset
%% ------------------------------------------------------------------
% Adjust this path to the location of the matched dataset on your machine.
load('T_with_income.mat')

% Sweden is dropped. The HBS-2015 data lack the reference person variable
% required by the HBS-SILC matching procedure, so no income source data
% can be constructed for Swedish households.
T(T.COUNTRY == "SE", :) = [];

%% ------------------------------------------------------------------
%% 2. COICOP categories used in the analysis
%% ------------------------------------------------------------------
% Imputed rents (EUR_HE042) are deliberately excluded: they are not an
% actual cash outlay and would distort the expenditure denominator used
% for all relative welfare impacts.
CPmod = {'EUR_HE011','EUR_HE012',...                                    % food, non-alcoholic beverages
    'EUR_HE021','EUR_HE022',...                                         % alcoholic beverages, tobacco
    'EUR_HE031','EUR_HE032',...                                         % clothing, footwear
    'EUR_HE041','EUR_HE043','EUR_HE044',...                             % housing (excl. imputed rents)
    'EUR_HE0451','EUR_HE0452','EUR_HE0453','EUR_HE0454','EUR_HE0455',...% EGOF: residential energy
    'EUR_HE051','EUR_HE052','EUR_HE053','EUR_HE054','EUR_HE055','EUR_HE056',...  % furnishings
    'EUR_HE061','EUR_HE062','EUR_HE063',...                             % health products & services
    'EUR_HE071',...                                                     % purchase of vehicles
    'EUR_HE0721','EUR_HE0722','EUR_HE0723','EUR_HE0724',...             % OPTE: operation of personal transport
    'EUR_HE0731','EUR_HE0732','EUR_HE0733','EUR_HE0734','EUR_HE0735','EUR_HE0736',...  % transport services
    'EUR_HE081','EUR_HE082','EUR_HE083',...                             % communication
    'EUR_HE091','EUR_HE092','EUR_HE093','EUR_HE094','EUR_HE095','EUR_HE096',...  % recreation & culture
    'EUR_HE10',...                                                      % education
    'EUR_HE111','EUR_HE112',...                                         % catering, accommodation
    'EUR_HE121','EUR_HE123','EUR_HE124','EUR_HE125','EUR_HE126','EUR_HE127',...  % misc goods & services
    'CP073rem',...                                                      % Germany: missing categories
    };

EGOF = {'EUR_HE0451','EUR_HE0452','EUR_HE0453','EUR_HE0454','EUR_HE0455'};  % residential energy
OPTE = {'EUR_HE0721','EUR_HE0722','EUR_HE0723','EUR_HE0724'};               % personal transport fuels

%% ------------------------------------------------------------------
%% 3. Drop households with unusable income across the 100 SILC draws
%% ------------------------------------------------------------------
% A household is dropped if, in ANY of the 100 matched draws, its gross
% income is missing, zero, or negative. In practice this affects a very
% small share of the sample (max ~1.95% in Spain).
nT = height(T);
hh_nan_any = false(nT, 1);
hh_neg_any = false(nT, 1);
for r = 1:100
    gross = T.(sprintf('LabInc_silc_%d', r)) + ...
            T.(sprintf('CapInc_%d', r))      + ...
            T.(sprintf('TrnInc_%d', r));
    hh_nan_any = hh_nan_any | (gross == 0 | isnan(gross));
    hh_neg_any = hh_neg_any | (gross < 0);
end

to_delete = hh_nan_any | hh_neg_any;
fprintf('Deleting: %d NaN + %d negative = %d total (%.2f%%)\n', ...
    sum(hh_nan_any), sum(hh_neg_any & ~hh_nan_any), sum(to_delete), 100*mean(to_delete));
T(to_delete, :) = [];

% Negative net income affects at most 0.53% of the population (Poland).
% Uncomment to inspect the country breakdown before deleting:
% wNegative(T(:, {'COUNTRY','EUR_HH095'}), T(:, 'HA10'))
T(T.EUR_HH095 < 0, :) = [];

nT = height(T);
fprintf('Remaining: %d households\n', nT);

% Observations, households and population by country after cleaning
T.Pop = T.HB05 .* T.HA10;
NumObsHhPop = groupsummary(T, 'COUNTRY', {'sum'}, {'HA10', 'Pop'});
NumObsHhPop.Properties.VariableNames = {'COUNTRY', 'NumObs', 'NumHH', 'NumPop'};
disp(NumObsHhPop);

%% ------------------------------------------------------------------
%% 4. Average income shares across the 100 matched draws
%% ------------------------------------------------------------------
% These shares allocate each household's income between labour, capital
% and transfers. They are applied to the factor price changes from GEM-E3
% in run_microsim.m to obtain income-side welfare impacts.
LABsh_sum = zeros(nT, 1);
CAPsh_sum = zeros(nT, 1);
TRNsh_sum = zeros(nT, 1);
for r = 1:100
    lab_col = sprintf('LabInc_silc_%d', r);
    cap_col = sprintf('CapInc_%d', r);
    trn_col = sprintf('TrnInc_%d', r);
    gross_r = T.(lab_col) + T.(cap_col) + T.(trn_col);

    LABsh_r = T.(lab_col) ./ gross_r;
    CAPsh_r = T.(cap_col) ./ gross_r;
    TRNsh_r = T.(trn_col) ./ gross_r;

    % Guard against division by zero (should not occur after cleaning)
    LABsh_r(gross_r == 0) = 0;
    CAPsh_r(gross_r == 0) = 0;
    TRNsh_r(gross_r == 0) = 0;

    LABsh_sum = LABsh_sum + LABsh_r;
    CAPsh_sum = CAPsh_sum + CAPsh_r;
    TRNsh_sum = TRNsh_sum + TRNsh_r;
end
T.LABsh = LABsh_sum / 100;
T.CAPsh = CAPsh_sum / 100;
T.TRNsh = TRNsh_sum / 100;

% Average disposable income across the 100 matched draws.
% Used as the income denominator for Italy (no HBS income variable).
DispInc_cols  = compose('DispInc_%d', 1:100);
T.DispInc_avg = mean(T{:, DispInc_cols}, 2);

%% ------------------------------------------------------------------
%% 5. Equivalized variables and PPS conversion
%% ------------------------------------------------------------------
% 2015 purchasing power parities by country (EU28 = 1).
CntPPS = {'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'EL', 'ES', ...
          'FI', 'FR', 'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', ...
          'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK'};
PPS = [1.04173; 1.05408; 0.46938; 0.87712; 0.62633; 1.00308; 1.35729; ...
       0.72891; 0.84962; 0.90722; 1.19032; 1.04645; 0.64855; 0.56847; ...
       1.22172; 1.00094; 0.60842; 1.20478; 0.68761; 0.80194; 1.08289; ...
       0.54228; 0.81973; 0.51067; 1.21534; 0.79532; 0.66161];
PPS_2015 = table(CntPPS', PPS, 'VariableNames', {'Country', 'PPS'});

% HB062 is the modified OECD equivalence scale (equivalent adults).
% Equivalization reflects within-household resource sharing.
T.TotExp    = sum(T{:, CPmod}, 2);      % total expenditure, excl. imputed rents
T.EqvTotExp = T.TotExp ./ T.HB062;      % equivalized total expenditure

[~, idx] = ismember(T.COUNTRY, PPS_2015.Country);
T.EqvTotExpPPS = T.EqvTotExp ./ PPS_2015.PPS(idx);

%% ------------------------------------------------------------------
%% 6. EU-wide expenditure deciles
%% ------------------------------------------------------------------
% Deciles are formed on EU-wide equivalized expenditure in PPS, using
% household sampling weights. This is the decile variable used
% downstream (ExpDcl_eu) as expenditures are a better proxy for lifetime
% income. 
weighted_deciles = "yes";
IncPrct          = 10:10:100;

T.ExpDcl_eu = assignDeciles(T.EqvTotExpPPS, T.HA10, weighted_deciles, IncPrct);

%% ------------------------------------------------------------------
%% 7. Figure S1: variation in expenditure and income patterns by decile
%% ------------------------------------------------------------------
if make_figure_S1
    % Panel A: budget shares for residential energy (EGOF) and personal
    % transport fuels (OPTE), the two carbon-intensive categories.
    BdgSh          = T(:, ['COUNTRY', CPmod]);
    BdgSh{:, 2:end} = BdgSh{:, 2:end} ./ T.TotExp;
    BdgSh.EGOF     = sum(BdgSh{:, EGOF}, 2);
    BdgSh.OPTE     = sum(BdgSh{:, OPTE}, 2);
    BdgSh.HA10     = T.HA10;

    h1 = medianIQRplot_EU(BdgSh, T.ExpDcl_eu, {'EGOF','OPTE'}, ...
        {'Residential energy','Operation of personal transport'}, ...
        'Expenditure decile', 'Expenditure share (%)', 'EU-wide budget shares by decile');
    ylim([0, 25]);

    % Panel B: income source shares.
    h2 = medianIQRplot_EU(T, T.ExpDcl_eu, {'LABsh','CAPsh','TRNsh'}, ...
        {'Labour','Capital','Transfers'}, ...
        'Expenditure decile', 'Income share (%)', 'EU-wide income shares by decile');

    % Combine the two panels side by side.
    h_combined          = figure;
    h_combined.Position = [100, 100, 1000, 350];

    objs1     = [gca(h1); findobj(h1, 'Type', 'legend')];
    new_objs1 = copyobj(objs1, h_combined);
    new_objs1(1).Position = [0.05 0.14 0.44 0.80];

    objs2     = [gca(h2); findobj(h2, 'Type', 'legend')];
    new_objs2 = copyobj(objs2, h_combined);
    new_objs2(1).Position = [0.53 0.14 0.44 0.80];

    close(h1); close(h2);
    exportgraphics(h_combined, 'FigS1_EU_EGOF_OPTE.png', 'Resolution', 300);
end

%% ------------------------------------------------------------------
%% 8. Nullify negative labour and capital income shares
%% ------------------------------------------------------------------
% A small number of households report negative labour or capital income
% (e.g. business losses). Negative shares would flip the sign of the
% welfare impact for those households, so they are set to zero.
% Uncomment to inspect the incidence by country:
% wNegative(T(:, ['COUNTRY', {'LABsh','CAPsh','TRNsh'}]), T(:, 'HA10'))
T{:, {'LABsh', 'CAPsh'}} = max(T{:, {'LABsh', 'CAPsh'}}, 0);

fprintf('Matched HBS-SILC data processed.\n');


%% ==================================================================
%% LOCAL FUNCTIONS
%% ==================================================================

function [IncGrp, PrcIncGrp] = assignDeciles(IncGrpVar, w_HA10, weighted_deciles, IncPrct)
% ASSIGNDECILES Assign households to income/expenditure decile groups.
%
%   Inputs:
%     IncGrpVar        - income or expenditure variable (n x 1)
%     w_HA10           - household sampling weights (n x 1)
%     weighted_deciles - "yes" to use weighted percentiles, otherwise unweighted
%     IncPrct          - percentile cutpoints, e.g. 10:10:100
%
%   Outputs:
%     IncGrp    - integer group assignment (1 = bottom decile, 10 = top)
%     PrcIncGrp - table of the percentile cutpoint values
%
%   Example with IncPrct = 10:10:100:
%     wprct returns 10 values, e.g. [15000 20000 ... 80000].
%     Only the first 9 are used as bin edges; the 10th (the maximum)
%     would create an empty top bin.
%       Decile 1 : (-inf, 15000]
%       Decile 2 : (15000, 20000]
%       ...
%       Decile 10: (72000, inf)

    if strcmp(weighted_deciles, "yes")
        prc_vals = wprct(IncGrpVar, w_HA10, IncPrct);
    else
        prc_vals = prctile(IncGrpVar, IncPrct);
    end

    % Force to column vector: wprct may return a row or a column depending
    % on input shape; prctile always returns a row.
    prc_vals = prc_vals(:);

    IncGrp = discretize(IncGrpVar, [-inf; prc_vals(1:end-1); inf]);

    PrcNames  = compose("P%d", 1:length(IncPrct));
    PrcIncGrp = array2table(prc_vals', 'RowNames', {'Prct value'}, 'VariableNames', PrcNames);
end


function [NegP, NegID] = wNegative(T, w)
% WNEGATIVE Weighted proportion (%) of negative entries per column, by country.
%
%   Diagnostic helper used to check the incidence of negative income
%   variables before they are deleted or truncated.
%
%   Inputs:
%     T - table with 'COUNTRY' as first column, numeric data thereafter
%     w - (optional) table with the sampling weight column 'HA10'
%
%   Outputs:
%     NegP  - table of negative proportions (%) by country
%     NegID - table with 1 for negative entries, 0 otherwise

    dataVars = T.Properties.VariableNames(2:end);
    isNeg    = T{:, dataVars} < 0;
    NegID    = [T(:, 'COUNTRY'), array2table(double(isNeg), 'VariableNames', dataVars)];

    if nargin > 1
        weighted = isNeg .* w{:, :};
        G    = groupsummary([T(:, 'COUNTRY'), array2table(weighted, 'VariableNames', dataVars)], ...
                            'COUNTRY', 'sum');
        wSum = groupsummary([T(:, 'COUNTRY'), w], 'COUNTRY', 'sum', 'HA10');
        NegP = 100 * G{:, 3:end} ./ wSum.sum_HA10;
    else
        G    = groupsummary([T(:, 'COUNTRY'), array2table(double(isNeg), 'VariableNames', dataVars)], ...
                            'COUNTRY', 'sum');
        NegP = 100 * G{:, 3:end} ./ G.GroupCount;
    end

    NegP = [G(:, 'COUNTRY'), array2table(NegP, 'VariableNames', dataVars)];
end


function h = medianIQRplot_EU(T, dclVar, vars, vars_label, xlabelStr, ylabelStr, figTitle) %#ok<INUSD>
% MEDIANIQRPLOT_EU Weighted median by decile with a shaded IQR band.
%
%   Used for Figure S1. Plots, for each variable in vars, the weighted
%   median across households in each decile, with a band spanning
%   median +/- 0.5 * weighted IQR.
%
%   Inputs:
%     T          - data table (must contain the variables and 'HA10')
%     dclVar     - decile variable (e.g. T.ExpDcl_eu)
%     vars       - cell array of variable names
%     vars_label - cell array of legend labels
%     xlabelStr  - x-axis label
%     ylabelStr  - y-axis label
%     figTitle   - figure title (currently unused; title suppressed for the paper)

    n_vars  = length(vars);
    colors  = num2cell(lines(n_vars), 2);
    n_inc   = max(dclVar(~isnan(dclVar)));
    deciles = 1:n_inc;
    h_leg   = gobjects(n_vars, 1);

    h = figure;
    hold on;
    for v = 1:n_vars
        mu  = zeros(1, n_inc);
        sig = zeros(1, n_inc);
        for d = deciles
            idx  = dclVar == d;
            data = 100 * T{idx, vars{v}};
            w    = T{idx, 'HA10'};
            if numel(data) >= 2
                mu(d)  = wprct(data, w, 50);
                sig(d) = wprct(data, w, 75) - wprct(data, w, 25);   % weighted IQR
            else
                mu(d)  = NaN;
                sig(d) = NaN;
            end
        end

        % Shaded band: median +/- 0.5 * IQR
        x_fill = [deciles, fliplr(deciles)];
        y_fill = [mu + 0.5*sig, fliplr(mu - 0.5*sig)];
        fill(x_fill, y_fill, colors{v}, 'FaceAlpha', 0.15, 'EdgeColor', 'none');

        h_leg(v) = plot(deciles, mu, '-', 'Color', colors{v}, 'LineWidth', 1.5);
    end
    hold off;

    xlabel(xlabelStr, 'FontSize', 9);
    ylabel(ylabelStr, 'FontSize', 9);
    xlim([1, n_inc]);
    ylim([0 100]);
    set(gca, 'XTick', 1:n_inc, 'XGrid', 'off', 'YMinorGrid', 'off', 'FontSize', 8);
    legend(h_leg, vars_label, 'FontSize', 8, 'Orientation', 'horizontal', 'Location', 'best');
    set(gca, 'LooseInset', get(gca, 'TightInset'));   % trim excess margins

    h.Position = [100, 100, 500, 350];
end