function out = run_microsim(T, GpCh_all, FpCh_all, CV_all, TaxRev_all, ...
                            Map, CPmod, rescaling, ...
                            WeightSF_choice, ...
                            nT, nCom, cntIdx, n_cnt, idxIT, n_inc, ...
                            Sum_ScaleWeight, rw_cols, DclNames, varNames, PPS_2015)
% RUN_MICROSIM  One microsimulation run for a given methodological configuration.
%
% Called by: main.m, once per rescaling method (macro and micro).
%
% ------------------------------------------------------------------
% WHAT THIS FUNCTION DOES
% ------------------------------------------------------------------
% For each of the four policy scenarios (REG, MIX, CPRICE, MIX_NoSubsidies), 
% it computes household-level welfare impacts, rescales them to match the 
% GEM-E3 macro welfare targets, and evaluates a social welfare function over 
% a grid of distributional parameters.
%
%   Section 1  Household welfare impacts (consumption and factor income)
%   Section 2  Carbon revenue recycling
%   Section 3  Channel-specific rescaling to macro targets
%   Section 4  EU-wide mean impacts by expenditure decile
%   Section 5  Social welfare over the (epsilon, gamma, rho, tau) grid
%
% ------------------------------------------------------------------
% THE WELFARE MEASURE
% ------------------------------------------------------------------
% All welfare impacts are expressed as a share of total household
% expenditure (the "relative welfare" RW). Expenditure is used as the
% denominator throughout, at both micro and macro level, because it is
% available for every household including Italy.
%
% ------------------------------------------------------------------
% THE ARGUMENTS THAT VARY FOR THE SENSITIVITY ANALYSES
% ------------------------------------------------------------------
%   Rescaling 
%     macro     rescaled to be consistent with macro outcomes [central]
%     micro     no rescaling; pure microsimulation result [sensitivity]
%
%   We follow a channel-specific rescaling method set in Section 3 below:
%     expenditure       country-relative
%     factor income     country-relative
%     carbon transfers  country-absolute
%
%   WeightSF_choice          'number of persons' | otherwise
%       Weights used in the social welfare function. 'number of persons'
%       gives HA10 .* HB05 (individual weights); otherwise ScaleWeight
%       (equivalent-adult weights) is used. Individual weights are the
%       appropriate choice: equivalence scales represent within-household
%       resource sharing, not differential moral worth.
%
% ------------------------------------------------------------------
% ITALY
% ------------------------------------------------------------------
% Italy has no usable HBS income variable (EUR_HH095). The income
% denominator switches to DispInc_avg for Italian households only. This
% happens once, in the construction of inc_all immediately below, and
% affects the labour and capital income impacts in Section 1.
%
% ------------------------------------------------------------------
% OUTPUT
% ------------------------------------------------------------------
%   out.AW_all              per-scenario household absolute welfare impacts
%   out.RW_geme3_all        per-scenario household relative welfare impacts
%   out.EU_wMeanRW_exp_all   per-scenario decile means (%)
%   out.SocialWelfare_all    per-scenario SWF grid, euros
%   out.SocialWelfare_PPS_all per-scenario SWF grid, PPS
%
% Local functions defined at the end of this file:
%   apply_rescaling, compute_SWF_grid

scen_names = fieldnames(GpCh_all);
n_sc       = length(scen_names);

% Income denominator: HBS net income, with Italy switched to the
% average matched SILC disposable income.
inc_all        = T.EUR_HH095;
inc_all(idxIT) = T.DispInc_avg(idxIT);

AW_all                = struct();
RW_geme3_all          = struct();
EU_wMeanRW_exp_all    = struct();
SocialWelfare_all     = struct();
SocialWelfare_PPS_all = struct();

for s = 1:n_sc
    scenario = scen_names{s};

    % Convert percentage changes to fractions
    GpCh = GpCh_all.(scenario){:, :} / 100;
    FpCh = FpCh_all.(scenario){:, {'cap','lab'}} / 100;   % [cap, lab]

    % Channel-specific macro welfare targets (% -> fraction)
    CV_con     = CV_all.(scenario){:, 'exp'}        / 100;   % consumption channel
    CV_fac     = CV_all.(scenario){:, 'fac'}        / 100;   % factor income channel
    CV_tra_co2 = CV_all.(scenario){:, 'tra_carbon'} / 100;   % carbon transfer channel
    CV_tot     = CV_all.(scenario){:, 'tot'}        / 100;   % total

    % Carbon revenue to recycle
    TaxRev = TaxRev_all.(scenario){:, 'taxrevaddMSM'};

    %% ==============================================================
    %% 1. Household-level absolute and relative welfare impacts
    %% ==============================================================
    % AW* = absolute impact in euros; RW* = same, divided by total
    % expenditure.
    %
    %   Labour   : income x labour share x labour price change
    %   Capital  : income x capital share x capital value-added change
    %   Consumption: -expenditure_by_category x category price change
    %     (negative because a price increase is a welfare loss)
    %
    % Category price changes PrD are obtained by mapping the 14 GEM-E3
    % goods price changes onto the COICOP categories via Map.

    AWL = zeros(nT, 1);  AWK = zeros(nT, 1);  AWC = zeros(nT, nCom);
    RWL = zeros(nT, 1);  RWK = zeros(nT, 1);  RWC = zeros(nT, nCom);

    for j = 1:n_cnt
        idx = cntIdx == j;
        exp = T{idx, 'TotExp'};
        inc = inc_all(idx);

        AWL(idx)    = inc .* T{idx, 'LABsh'} * FpCh(j, 2);
        RWL(idx)    = AWL(idx) ./ exp;
        AWK(idx)    = inc .* T{idx, 'CAPsh'} * FpCh(j, 1);
        RWK(idx)    = AWK(idx) ./ exp;

        PrD         = Map{:, 3:end} * GpCh(j, :)';       % COICOP price changes
        AWC(idx, :) = -T{idx, CPmod} * diag(PrD);
        RWC(idx, :) = AWC(idx, :) ./ exp;
    end

    AW = [T(:, 'COUNTRY'), array2table([AWL, AWK, sum(AWC, 2), AWC], 'VariableNames', varNames)];
    RW = [T(:, 'COUNTRY'), array2table([RWL, RWK, sum(RWC, 2), RWC], 'VariableNames', varNames)];

    AW.AWtot = AW.LAB + AW.CAP + AW.CON;
    RW.RWtot = RW.LAB + RW.CAP + RW.CON;

    %% ==============================================================
    %% 2. Carbon revenue recycling
    %% ==============================================================
    % Revenue is returned lump-sum, uniformly per equivalent adult
    % within each country. A household with HB062 equivalent adults
    % receives HB062 x (national revenue / national equivalent adults).
    Trnsf = zeros(nT, 1);
    for j = 1:n_cnt
        idx        = cntIdx == j;
        Trnsf(idx) = T{idx, 'HB062'} * TaxRev(j) / Sum_ScaleWeight(j);
    end
    AW.Trnsf     = Trnsf;
    AW.AWtot_rev = AW.AWtot + AW.Trnsf;
    RW.Trnsf     = AW.Trnsf ./ T.TotExp;
    RW.RWtot_rev = RW.RWtot + RW.Trnsf;

    %% ==============================================================
    %% 3. Channel-specific rescaling to GEM-E3 macro targets
    %% ==============================================================
    % The microsimulation reproduces the distribution of impacts but
    % not their exact national aggregate, because the microdata and the
    % CGE model have different underlying aggregates. Rescaling closes
    % this gap channel by channel, so that the weighted micro mean of
    % each channel matches the corresponding GEM-E3 macro welfare change.
    %
    % Three channels: consumption, factor income (labour + capital
    % jointly), and carbon transfers.

    RW_geme3 = RW(:, {'COUNTRY','RWtot','RWtot_rev','CON','LAB','CAP','Trnsf'});

    % ---- Rescaling method per channel ----
    %   'country-relative' : uniform shift in relative terms; every
    %                        household gets the same percentage-point
    %                        adjustment.
    %   'country-absolute' : uniform absolute euros per equivalent adult,
    %                        then converted to relative terms. This is
    %                        progressive, since a fixed euro amount is a
    %                        larger share of a small budget.
    RescaleMethod_exp        = 'country-relative';   % consumption channel
    RescaleMethod_fac        = 'country-relative';   % factor income channel
    RescaleMethod_tra_carbon = 'country-absolute';   % carbon transfers

    % Per-channel residuals
    RW_geme3.ResCon     = zeros(nT, 1);   % consumption channel
    RW_geme3.ResFac     = zeros(nT, 1);   % factor income channel (LAB + CAP)
    RW_geme3.ResTrCO2   = zeros(nT, 1);   % carbon transfer channel

    % ---- Country-level micro means per channel ----
    % Columns: [CON, LAB, CAP, Trnsf]
    RW_mean = zeros(n_cnt, 4);
    for j = 1:n_cnt
        idx = cntIdx == j;
        w   = T{idx, 'HA10'};
        exp = T{idx, 'TotExp'};

        % Aggregation: sum(w .* AW_channel) / sum(w .* exp).
        % This matches the GEM-E3 macro welfare definition.
        denom = sum(w .* exp);
        RW_mean(j, 1) = sum(w .* AW{idx, 'CON'})   / denom;
        RW_mean(j, 2) = sum(w .* AW{idx, 'LAB'})   / denom;
        RW_mean(j, 3) = sum(w .* AW{idx, 'CAP'})   / denom;
        RW_mean(j, 4) = sum(w .* AW{idx, 'Trnsf'}) / denom;
    end

if strcmp(rescaling, 'macro-consistent')
        for j = 1:n_cnt
            idx = cntIdx == j;
            w   = T{idx, 'HA10'};
            exp = T{idx, 'TotExp'};
            scl = T{idx, 'HB062'};

            micro = RW_mean(j, :);   % [CON, LAB, CAP, Trnsf]           

            % (A) Consumption channel
            gap_exp = CV_con(j) - micro(1);
            RW_geme3{idx, 'ResCon'} = apply_rescaling(gap_exp, RescaleMethod_exp, ...
                w, exp, scl);

            % (B) Factor income channel: labour and capital rescaled
            %     jointly, because GEM-E3 reports a single combined
            %     factor income welfare target (CV_fac).
            gap_fac = CV_fac(j) - sum(micro(2:3));
            RW_geme3{idx, 'ResFac'} = apply_rescaling(gap_fac, RescaleMethod_fac, ...
                w, exp, scl);

            % (C) Carbon transfers.
            %     With 'country-absolute', ResTrCO2 ./ HB062 .* TotExp is
            %     an identical euro amount per equivalent adult for every
            %     household, consistent with lump-sum recycling.
            gap_tra_carbon = CV_tra_co2(j) - micro(4);
            RW_geme3{idx, 'ResTrCO2'} = apply_rescaling(gap_tra_carbon, RescaleMethod_tra_carbon, ...
                w, exp, scl);

        end

        % Rescaled totals. Note that CON, LAB and CAP are kept at their
        % unrescaled values in RW_geme3; the residuals are added at the
        % level of the totals and of the *_resc columns below.
        RW_geme3.RWtot     = RW.CON + RW_geme3.ResCon + RW.LAB + RW.CAP + RW_geme3.ResFac;
        RW_geme3.RWtot_rev = RW_geme3.RWtot + RW.Trnsf + RW_geme3.ResTrCO2 ;
    else
        % No rescaling: pure microsimulation result.
        RW_geme3.RWtot     = RW.RWtot;
        RW_geme3.RWtot_rev = RW.RWtot_rev;
    end

    % Rescaled channel totals (used in the figures)
    RW_geme3.CON_resc   = RW.CON + RW_geme3.ResCon;
    RW_geme3.FAC_resc   = RW.LAB + RW.CAP + RW_geme3.ResFac;
    RW_geme3.Trnsf_resc = RW.Trnsf + RW_geme3.ResTrCO2;

    % Rescaled absolute change, in euros
    AW.AWtot_rev_rescaled = RW_geme3.RWtot_rev .* T.TotExp;

    %% ==============================================================
    %% 4. EU-wide mean impacts by expenditure decile
    %% ==============================================================
    EU_wMeanRW_exp = zeros(length(rw_cols), n_inc);
    for d = 1:n_inc
        idx  = T.ExpDcl_eu == d;
        wOut = wMeanSem(RW_geme3{idx, rw_cols}, T{idx, 'HA10'});
        EU_wMeanRW_exp(:, d) = 100 * wOut(1, :)';    % in %
    end
    EU_wMeanRW_exp = array2table(EU_wMeanRW_exp, ...
        'RowNames', rw_cols, 'VariableNames', DclNames);

    %% ==============================================================
    %% 5. Social welfare
    %% ==============================================================
    % Weights for the social welfare function.
    if strcmp(WeightSF_choice, 'number of persons')
        T.Weight = T.HA10 .* T.HB05;      % individual weights
    else
        T.Weight = T.ScaleWeight;         % equivalent-adult weights
    end

    % The SWF operates on equivalized values per equivalent adult:
    %   y0      baseline equivalized expenditure
    %   delta_y change in equivalized expenditure-equivalent welfare
    AW.y0      = T.EqvTotExp;
    AW.delta_y = AW.AWtot_rev_rescaled ./ T.HB062;

    % Decile mean of delta_y, needed for the horizontal equity term,
    % which penalises dispersion of impacts WITHIN each decile.
    AW.delta_y_dclmean = NaN(nT, 1);
    for d = 1:n_inc
        idx = T.ExpDcl_eu == d;
        AW{idx, 'delta_y_dclmean'} = sum(T{idx, 'Weight'} .* AW{idx, 'delta_y'}) ...
                                   / sum(T{idx, 'Weight'});
    end

    SW = compute_SWF_grid(AW.y0, AW.delta_y, AW.delta_y_dclmean, T.Weight, 'Welfare');

    % Repeat in purchasing power standards, so that welfare levels are
    % comparable across countries with different price levels.
    [~, idx_pps] = ismember(T.COUNTRY, PPS_2015.Country);
    pps            = PPS_2015.PPS(idx_pps);
    AW.y0_pps      = AW.y0      ./ pps;
    AW.delta_y_pps = AW.delta_y ./ pps;

    AW.delta_y_pps_dclmean = NaN(nT, 1);
    for d = 1:n_inc
        idx = T.ExpDcl_eu == d;
        AW{idx, 'delta_y_pps_dclmean'} = sum(T{idx, 'Weight'} .* AW{idx, 'delta_y_pps'}) ...
                                       / sum(T{idx, 'Weight'});
    end

    SW_pps = compute_SWF_grid(AW.y0_pps, AW.delta_y_pps, AW.delta_y_pps_dclmean, ...
                              T.Weight, 'Welfare_PPS');

    %% ---- Store ----
    % AW_all.(scenario)              = AW;
    RW_geme3_all.(scenario)          = RW_geme3;
    EU_wMeanRW_exp_all.(scenario)    = EU_wMeanRW_exp;
    SocialWelfare_all.(scenario)     = SW;
    SocialWelfare_PPS_all.(scenario) = SW_pps;
end

%out.AW_all                = AW_all;
out.RW_geme3_all          = RW_geme3_all;
out.EU_wMeanRW_exp_all    = EU_wMeanRW_exp_all;
out.SocialWelfare_all     = SocialWelfare_all;
out.SocialWelfare_PPS_all = SocialWelfare_PPS_all;
end


%% ==================================================================
%% LOCAL FUNCTIONS
%% ==================================================================

function rel_res = apply_rescaling(gap, method, w, exp, scl)
% APPLY_RESCALING  Distribute a micro-macro gap across households.
%
%   Inputs:
%     gap    - scalar micro-macro gap, in relative terms
%              (as a fraction of expenditure)
%     method - 'country-relative' | 'country-absolute'
%     w      - household sampling weights (HA10)
%     exp    - household total expenditure (TotExp)
%     scl    - equivalence scale (HB062)
%
%   Output:
%     rel_res - column vector of per-household residuals in relative terms
%
%   RELATIVE: every household receives the same percentage-point
%     adjustment. Distributionally neutral in relative terms.
%
%   ABSOLUTE: every household receives the same euro amount per
%     equivalent adult, converted to relative terms by dividing by
%     expenditure. Progressive, since a fixed euro amount is a larger
%     share of a small budget.

    switch method
        case 'country-relative'
            rel_res = gap * ones(size(exp));

        case 'country-absolute'
            res_tot_eur = gap * sum(w .* exp);
            agg_scale   = sum(w .* scl);
            res_eqv     = res_tot_eur / agg_scale;
            rel_res     = res_eqv .* scl ./ exp;

        otherwise
            error('Unknown rescaling method: %s', method);
    end
end


function SW = compute_SWF_grid(y0, delta_y, dclmean, w, welfareVarName)
% COMPUTE_SWF_GRID  Social welfare over a grid of distributional parameters.
%
%   Inputs:
%     y0             - baseline equivalized expenditure per equivalent adult
%     delta_y        - change in equivalized welfare per equivalent adult
%     dclmean        - decile mean of delta_y (for the horizontal equity term)
%     w              - social welfare weights (individuals or equivalent adults)
%     welfareVarName - name of the welfare column in the output table
%
%   Output:
%     SW - table with one row per (epsilon, gamma, rho, tau) combination
%
%   THE SOCIAL WELFARE FUNCTION
%
%   Welfare = [vertical equity term] - gamma * [horizontal equity term]
%
%   VERTICAL EQUITY. The change in the equally-distributed-equivalent
%   (EDE) income, using an Atkinson social welfare function with
%   inequality aversion epsilon:
%
%       y_EDE(eps) = ( sum_h w_h * y_h^(1-eps) / sum_h w_h )^(1/(1-eps))
%       vertical   = y_EDE(y0 + delta_y) - y_EDE(y0)
%
%   epsilon = 0 gives the unweighted mean (pure efficiency); higher
%   epsilon puts progressively more weight on the poor.
%
%   HORIZONTAL EQUITY. A penalty for dispersion of impacts WITHIN each
%   decile — households with similar baseline resources being treated
%   differently:
%
%       horizontal = ( sum_h w_h * (mean_y/y0_h)^(tau*rho)
%                                * |delta_y_h - dclmean_h|^(1+rho)
%                      / sum_h w_h )^(1/(1+rho))
%
%   rho controls the curvature of the penalty in the size of the
%   deviation; tau controls how much extra weight deviations among poor
%   households receive (via the mean_y/y0 ratio). gamma sets the overall
%   weight of the horizontal equity term relative to vertical equity.
%
%   PARAMETER GRID
%     epsilon 0 to 2   in steps of 0.1   (21 values)
%     rho     0 to 2   in steps of 0.5   (5 values)
%     tau     0 to 2   in steps of 0.5   (5 values)
%     gamma   0 to 1   in steps of 0.05  (21 values)
%   Total: 21 x 21 x 5 x 5 = 11,025 rows.
%
%   IMPLEMENTATION NOTE
%   The (rho, tau) block is independent of epsilon, so it is computed
%   once outside the epsilon loop rather than being recomputed for every
%   epsilon value. The four-dimensional welfare array is then assembled
%   by implicit expansion. This is substantially faster than a nested
%   quadruple loop.
%
%   The value epsilon = 1 is a removable singularity of the Atkinson
%   function (the limit is the geometric mean). Rather than special-casing
%   it, epsilon = 1 is nudged to 1 + 1e-6, which is numerically
%   indistinguishable at the resolution of the figures. A tolerance-based
%   comparison is used because exact floating-point equality against a
%   value produced by a colon expression is fragile.

epsl_vals  = 0:0.1:2;
epsl_vals(abs(epsl_vals - 1) < 1e-12) = 1 + 1e-6;
rho_vals   = 0:0.5:2;
tau_vals   = 0:0.5:2;
gamma_vals = (0:0.05:1)';

n_eps = numel(epsl_vals);  n_rho = numel(rho_vals);
n_tau = numel(tau_vals);   n_gam = numel(gamma_vals);

sum_w  = sum(w);
y      = y0 + delta_y;              % post-policy equivalized expenditure
abs_dd = abs(delta_y - dclmean);    % within-decile deviation
mean_y = sum(w .* y) / sum_w;
y0r    = mean_y ./ y0;              % relative position, for the tau weighting

% ---- (rho, tau) block: independent of epsilon, computed once ----
inner_mat = zeros(n_rho, n_tau);
for j_rho = 1:n_rho
    rho1   = 1 + rho_vals(j_rho);
    dd_pow = abs_dd.^rho1;                       % hoisted out of the tau loop
    for j_tau = 1:n_tau
        tr = tau_vals(j_tau) * rho_vals(j_rho);
        x  = y0r.^tr .* dd_pow;
        inner_mat(j_rho, j_tau) = (sum(w .* x) / sum_w)^(1/rho1);
    end
end

% ---- epsilon block: two power operations per epsilon ----
delta_yede = zeros(n_eps, 1);
for j_eps = 1:n_eps
    pw    = 1 - epsl_vals(j_eps);
    y0ede = (sum(w .* y0.^pw) / sum_w)^(1/pw);   % baseline EDE
    y1ede = (sum(w .* y .^pw) / sum_w)^(1/pw);   % post-policy EDE
    delta_yede(j_eps) = y1ede - y0ede;
end

% ---- Assemble Welfare(eps, gamma, rho, tau) by implicit expansion ----
HE4     = reshape(gamma_vals, 1, n_gam) .* reshape(inner_mat, 1, 1, n_rho, n_tau);
Welfare = reshape(delta_yede, n_eps, 1) - HE4;

% ---- Pack into a long-format table ----
[E, G, R, Tau] = ndgrid(epsl_vals, gamma_vals, rho_vals, tau_vals);
SW = table(E(:), G(:), R(:), Tau(:), Welfare(:), ...
    'VariableNames', {'epsilon','gamma','rho','tau', welfareVarName});
end