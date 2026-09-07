%% LOAD_CGE_OUTPUTS  Read GEM-E3 macro model outputs and prepare shocks.
%
% Called by: main.m (second step of the pipeline, after data_preparation.m)
%
% WHAT THIS SCRIPT DOES
%   Reads the GEM-E3 computable general equilibrium (CGE) outputs that
%   drive the microsimulation, and aligns them with the microdata country
%   set. Four blocks are read from CGEoutputs.xlsx:
%
%     PriceChange -> GpCh_all   Consumer goods price changes (%), by
%                               country and by the 14 GEM-E3 goods.
%     dINC        -> FpCh_all   Factor price changes (%): capital ('cap')
%                               and labour ('lab').
%     Welfare     -> CV_all     Macro welfare change (%), decomposed into
%                               four channels plus the total:
%                                 exp        - expenditure / consumption
%                                 fac        - factor income
%                                 tra_carbon - carbon revenue transfers
%                                 tot        - total
%     TRA         -> TaxRev_all Additional carbon tax revenue available
%                               for redistribution
%
%   A separate mapping file (GEME3_COICOP_mapping.xlsx) links the 14
%   GEM-E3 goods to the COICOP expenditure categories in CPmod.
%
% KEY OUTPUTS CONSUMED DOWNSTREAM
%   GpCh_all, FpCh_all, CV_all, TaxRev_all, 
%   Map, nCom, cntIdx, n_cnt, idx_IT, idxIT, n_inc
%   Sum_ScaleWeight, rw_cols, DclNames, varNames, scen_names
%
% Local function defined at the end of this file: renamevars_rows

%% ------------------------------------------------------------------
%% 0. GEM-E3 to COICOP mapping
%% ------------------------------------------------------------------
% Rows correspond to the COICOP categories in CPmod (same order);
% columns 3:end give the weight of each GEM-E3 good in that category.
Map = readtable('GEME3_COICOP_mapping.xlsx', ...
    'Sheet', 'GEM-E3 COICOP mapping', 'Range', 'A3:P56');

% Sanity check that the mapping rows line up with CPmod:
%disp([Map(:,1), CPmod'])

infile     = 'CGEoutputs.xlsx';
scen_names = {'REG', 'MIX', 'CPRICE', 'MIX_NoSubsidies'};  

%% ------------------------------------------------------------------
%% 1. PriceChange: consumer goods prices
%% ------------------------------------------------------------------
% Sheet layout: 3 header rows, then 28 country rows (rows 4-31).
% Column A = country code; then 14 goods x 4 scenarios = 56 data columns.
raw_gp       = readcell(infile, 'Sheet', 'PriceChange');
gp_countries = raw_gp(4:end, 1);
gp_data      = cell2mat(raw_gp(4:end, 2:end));
gp_goods     = cell2mat(raw_gp(3, 2:15));      % good IDs 1..14

gp_col_map = struct('REG', 1:14, ...
                    'CPRICE', 15:28, ...
                    'MIX', 29:42, ...
                    'MIX_NoSubsidies',43:56);

GpCh_all = struct();
for i = 1:length(scen_names)
    sc = scen_names{i};
    GpCh_all.(sc) = array2table(gp_data(:, gp_col_map.(sc)), ...
        'VariableNames', compose('g%d', gp_goods), 'RowNames', gp_countries);
end
fprintf('Loaded PriceChange: %d countries x 14 goods x %d scenarios\n', ...
    size(gp_data, 1), length(scen_names));

%% ------------------------------------------------------------------
%% 2. dINC: factor prices
%% ------------------------------------------------------------------
% Sheet layout: 2 header rows, then 30 country rows (rows 3-32).
% Column A = year, column B = country; then 2 variables x 4 scenarios.
raw_fp       = readcell(infile, 'Sheet', 'dINC');
fp_countries = raw_fp(3:end, 2);
fp_data      = cell2mat(raw_fp(3:end, 3:end));
fp_vars      = raw_fp(2, 3:4);                 % {'cap','lab'}

fp_col_map = struct('REG', 1:2, ...
                    'CPRICE', 3:4, ...
                    'MIX', 5:6, ...
                    'MIX_NoSubsidies', 7:8);

FpCh_all = struct();
for i = 1:length(scen_names)
    sc = scen_names{i};
    FpCh_all.(sc) = array2table(fp_data(:, fp_col_map.(sc)), ...
        'VariableNames', fp_vars, 'RowNames', fp_countries);
end
fprintf('Loaded dINC: %d countries x 2 vars x %d scenarios\n', ...
    size(fp_data, 1), length(scen_names));

%% ------------------------------------------------------------------
%% 3. Welfare: macro welfare change by channel
%% ------------------------------------------------------------------
% Sheet layout: 2 header rows, then 30 rows (rows 3-32); the last two
% rows are EU aggregates (eu27, eu25_hbs).
% Column A = country, column B = year; then 5 components x 4 scenarios.
raw_wf       = readcell(infile, 'Sheet', 'Welfare');
wf_countries = raw_wf(3:end, 1);
wf_data      = cell2mat(raw_wf(3:end, 3:end));
wf_vars      = raw_wf(2, 3:6);   % {'exp','fac','tra_carbon','tot'}

wf_col_map = struct('REG', 1:4, ...
                    'CPRICE', 5:8, ...
                    'MIX', 9:12, ...
                    'MIX_NoSubsidies', 13:16);

CV_all = struct();
for i = 1:length(scen_names)
    sc = scen_names{i};
    CV_all.(sc) = array2table(wf_data(:, wf_col_map.(sc)), ...
        'VariableNames', wf_vars, 'RowNames', wf_countries);
end
fprintf('Loaded Welfare: %d countries x 4 components x %d scenarios\n', ...
    size(wf_data, 1), length(scen_names));

%% ------------------------------------------------------------------
%% 4. TRA: carbon tax revenue available for redistribution
%% ------------------------------------------------------------------
% rows  4-31  taxrevaddMSM            (as reported by GEM-E3)
% Column A = iso2, column B = iso3, columns C-F = REG / CPRICE / MIX / MIX-NoSubs.
% Values are in billions and converted to euros here.
raw_tr        = readcell(infile, 'Sheet', 'TRA');
tra_countries = raw_tr(4:31, 2);
tra_data      = cell2mat(raw_tr(4:31,  3:6)) * 1e9;

tra_col_map = struct('REG', 1, 'CPRICE', 2, 'MIX', 3, 'MIX_NoSubsidies', 4);

TaxRev_all   = struct();
for i = 1:length(scen_names)
    sc  = scen_names{i};
    col = tra_col_map.(sc);
    TaxRev_all.(sc)   = array2table(tra_data(:, col), ...
        'VariableNames', {'taxrevaddMSM'},           'RowNames', tra_countries);

end
fprintf('Loaded TRA: %d countries x %d scenarios \n', ...
    size(tra_data, 1), length(scen_names));

%% ------------------------------------------------------------------
%% 5. Filter CGE outputs to the microsimulation country set
%% ------------------------------------------------------------------
% The CGE workbook uses three-letter ISO codes and covers 28 countries;
% the microdata use two-letter codes and cover 25 (SE dropped, plus
% countries absent from the HBS). This block selects and relabels.
CntName     = unique(T.COUNTRY, 'stable');
[~, cntIdx] = ismember(T.COUNTRY, CntName);
n_cnt       = length(CntName);

iso2_list = {'AU','BE','BG','CY','CZ','DE','DK','ES','EE','FI', ...
             'FR','UK','EL','HU','IE','IT','LT','LU','LV','MT', ...
             'NL','PL','PT','SK','SI','SE','RO','HR'};
iso3_list = {'AUT','BEL','BGR','CYP','CZE','DEU','DNK','ESP','EST','FIN', ...
             'FRA','GBR','GRC','HUN','IRL','ITA','LTU','LUX','LVA','MLT', ...
             'NLD','POL','PRT','SVK','SVN','SWE','ROU','CRO'};
iso_map = containers.Map(iso2_list, iso3_list);

iso3_sel = cell(n_cnt, 1);
for i = 1:n_cnt
    iso3_sel{i} = iso_map(CntName{i});
end

filter_rows = @(S) structfun(@(Tbl) renamevars_rows(Tbl, iso3_sel, CntName), ...
                             S, 'UniformOutput', false);

GpCh_all     = filter_rows(GpCh_all);
FpCh_all     = filter_rows(FpCh_all);
CV_all       = filter_rows(CV_all);
TaxRev_all   = filter_rows(TaxRev_all);

fprintf('Filtered to %d countries (CntName)\n', n_cnt);

%% ------------------------------------------------------------------
%% 6. Precomputed scalars and name lists used downstream
%% ------------------------------------------------------------------
nT     = height(T);
nCom   = size(Map, 1);        % number of COICOP categories
n_inc  = 10;                  % number of decile groups

% Italy indices: Italy has no HBS income variable and is handled
% separately in run_microsim.m (DispInc_avg substituted
% for EUR_HH095 in the income denominator).
idx_IT = find(strcmp(CntName, 'IT'));
idxIT  = cntIdx == idx_IT;

% ScaleWeight = equivalent adults x household weight. Used as the
% denominator when distributing carbon revenue per equivalent adult.
T.ScaleWeight   = T.HB062 .* T.HA10;
Sum_ScaleWeight = accumarray(cntIdx, T.ScaleWeight);

% Welfare components reported in figures and decile tables.
%   RWtot      total welfare impact before revenue recycling
%   RWtot_rev  total welfare impact after revenue recycling
%   LAB, CAP   labour and capital income impacts (before rescaling)
%   CON        consumption impact (before rescaling)
%   Trnsf      carbon revenue transfer (before rescaling)
%   Res*       per-channel rescaling residuals
%   *_resc     rescaled channel totals
rw_cols = {'RWtot','RWtot_rev','LAB','CAP','CON','Trnsf', ...
           'ResCon','ResFac','ResTrCO2', ...
           'CON_resc','FAC_resc','Trnsf_resc'};

DclNames = compose("D%d", 1:n_inc);
varNames = ['LAB', 'CAP', 'CON', CPmod];

fprintf('CGE outputs loaded and aligned with microdata.\n');


%% ==================================================================
%% LOCAL FUNCTION
%% ==================================================================

function T2 = renamevars_rows(Tbl, iso3_sel, iso2_sel)
% RENAMEVARS_ROWS Select rows by ISO3 code, then relabel with ISO2 codes.
%
%   Used to align the CGE output tables (indexed by three-letter country
%   codes, 28 countries) with the microdata country set (two-letter
%   codes, 25 countries) and ordering.
    T2 = Tbl(iso3_sel, :);
    T2.Properties.RowNames = iso2_sel;
end