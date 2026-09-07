%% MAIN  Master script for distributional analysis of EU climate policy scenarios.

%
% Paper: Enhancing fairness in climate action through policy packages
% Authors: Toon Vandyck, Umed Temursho, Florian Landis, David Klenert,
%          Matthias Weitzel
% DOI: 10.1038/s41558-026-02751-5
%
% ------------------------------------------------------------------
% WHAT THIS PACKAGE DOES
% ------------------------------------------------------------------
% It combines household-level microdata (EU HBS matched to EU-SILC, 25
% member states) with the output of the JRC-GEM-E3 computable general
% equilibrium model to compute the distributional welfare impacts of
% three EU climate policy scenarios:
%
%   REG     regulation-based instruments
%   MIX     mixed instrument package
%   CPRICE  carbon pricing with revenue recycling
%
% For each scenario it computes, for every household, the welfare impact
% of (i) changes in consumer goods prices, (ii) changes in labour and
% capital income, and (iii) the recycling of carbon tax revenue. Household-
% level distributional impacts are then evaluated through a social welfare 
% function that trades off efficiency, vertical equity and horizontal 
% equity.
%
% ------------------------------------------------------------------
% SENSITIVITY 
% ------------------------------------------------------------------
% For the central results, the micro impacts are rescaled so that their 
% weighted national means match the GEM-E3 macro welfare changes, ensuring
% consistency between micro- and macro-level outcomes. We also run a 
% sensitivity test without this rescaling:
%
%   ROWS 
%     macro     rescaled to be consistent with macro outcomes [central]
%     micro     no rescaling; pure microsimulation result [sensitivity]
%
% ------------------------------------------------------------------
% PIPELINE
% ------------------------------------------------------------------
%   main.m
%     |- data_preparation.m   microdata: cleaning, shares, deciles, Fig S1
%     |- load_cge_outputs.m   GEM-E3 outputs: prices, welfare, revenue
%     |- for each of the 2 configurations:
%     |    |- run_microsim.m    one microsimulation run
%     |    |- build_figures.m   boxplots, decomps, heatmaps for that run
%     |- compose_and_export.m PNGs plus a browsable HTML index
%
% ------------------------------------------------------------------
% OUTPUT
% ------------------------------------------------------------------
% Written to ./sensitivity_results/, one subfolder per figure family.
% Each subfolder contains an index.html laying the 2 configurations out
% in grid; open it in a browser to compare them at a glance.
%
% Runtime: under 1 minute, depending on machine.

clear; clc; close all;

%% ------------------------------------------------------------------
%% Sensitivity dimensions
%% ------------------------------------------------------------------
Rescaling = {'macro-consistent', ...   % rescaled to macro outcome 
                      'micro'};                 % no rescaling 

% Social welfare weights: 'number of persons' gives HA10 .* HB05, so each
% individual counts once. Individual weights are the right choice, as we 
% work with equivalised expenditures (HB062).
WeightSF_choice = 'number of persons';

n_rows = length(Rescaling);

%% ------------------------------------------------------------------
%% Load and prepare data
%% ------------------------------------------------------------------
data_preparation;      % -> T, CPmod, PPS_2015, T.ExpDcl_eu, ...
load_cge_outputs;      % -> GpCh_all, FpCh_all, CV_all, TaxRev_all, ...

%% ------------------------------------------------------------------
%% Run the sensitivity grid
%% ------------------------------------------------------------------
fig_box        = cell(n_rows, 1);
fig_ver_decomp = cell(n_rows, 1);
fig_hor_decomp = cell(n_rows, 1);
fig_heat_pps   = cell(n_rows, 1);

% Scenarios to plot. MIX_NoSubsidies is loaded and simulated but not
% shown in the main figures.
scen_plot = {'REG', 'MIX', 'CPRICE'};

tic;

for r = 1:n_rows
    fprintf('\n[%d/%d] %s\n', r, n_rows, Rescaling{r});

    out = run_microsim(T, GpCh_all, FpCh_all, CV_all, TaxRev_all, ...
        Map, CPmod, Rescaling{r}, ...
        WeightSF_choice, nT, nCom, cntIdx, n_cnt, idxIT, n_inc, ...
        Sum_ScaleWeight, rw_cols, DclNames, varNames, PPS_2015);

    fig_box{r}        = build_figures('boxplot', out, T, n_inc, scen_plot);
    fig_ver_decomp{r} = build_figures('ver_decomp', out, T, n_inc, scen_plot);
    fig_hor_decomp{r} = build_figures('hor_decomp', out, T, n_inc, scen_plot);
    fig_heat_pps{r}   = build_figures('heatmap', out, T, n_inc, scen_plot, 'PPS', 'pps');
end
fprintf('\nTotal runtime: %.1f s\n', toc);


%% ------------------------------------------------------------------
%% Compose and save
%% ------------------------------------------------------------------
tic;
output_folder = 'sensitivity_results';
if ~exist(output_folder, 'dir'), mkdir(output_folder); end

row_labels = Rescaling;

compose_and_export(fig_box,        row_labels, output_folder, 'Boxplots');
compose_and_export(fig_ver_decomp, row_labels, output_folder, 'VerticalDecomp');
compose_and_export(fig_hor_decomp, row_labels, output_folder, 'HorizontalDecomp');
compose_and_export(fig_heat_pps,   row_labels, output_folder, 'Heatmaps_PPS');

fprintf('\nTotal runtime of the export stage: %.1f s\n', toc);
fprintf('\nDone. Output: %s/\n', output_folder);
