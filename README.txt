README — Replication Package
================================================================================
Paper:   Enhancing fairness in climate action through policy packages
Authors: Toon Vandyck, Umed Temursho, Florian Landis, David Klenert,
         Matthias Weitzel


1. OVERVIEW
--------------------------------------------------------------------------------
This package contains the MATLAB code to reproduce the main figures in the
paper. It combines household-level microdata (EU Household Budget Survey
matched to EU-SILC, 25 member states) with output from the GEM-E3 computable
general equilibrium model to compute the distributional welfare impacts of
EU climate policy scenarios.

All calculations are carried out for four scenarios:

    REG              regulation-based instruments
    MIX              mixed instrument package
    CPRICE           carbon pricing with revenue recycling
    MIX_NoSubsidies  mixed instruments without subsidies

The main paper figures show only the first three. Which scenarios are plotted is
set by scen_plot in main.m; edit that list to plot a different subset. All
four are simulated regardless, so the structures returned by run_microsim
contain a field for every scenario, including any not plotted.

For every household the code computes the welfare impact of (i) consumer goods
price changes, (ii) labour and capital income changes, and (iii) recycling of
carbon tax revenue. These micro impacts are rescaled so that their weighted
national means match the GEM-E3 macro welfare changes, and are then evaluated
through a social welfare function that trades off efficiency, vertical equity
and horizontal equity. The Supplementary Info of the paper also contains results
without rescaling (robustness check).


2. SOFTWARE
--------------------------------------------------------------------------------
MATLAB R2025b. Requires R2016b or later, since the code uses local functions
inside script files. Beyond base MATLAB, only the Statistics and Machine
Learning Toolbox is used.

Memory: the full grid holds several copies of the household table in memory
at once; 16 GB RAM is sufficient.

Runtime: under 1 minute. Measured on an AMD Ryzen 9 PRO 8945HS (8 cores, 4 GHz), 
64 GB RAM, Windows 11, x64.


3. DATA
--------------------------------------------------------------------------------
The analysis requires matched HBS and EU-SILC microdata. See the Data Availability
Statement in the paper for details on how to access these sources.

Required input files, all in the working directory:

    T_with_income.mat            Matched HBS-SILC household dataset. Contains
                                 100 statistically matched income draws per
                                 household (LabInc_silc_*, CapInc_*, TrnInc_*,
                                 DispInc_*), expenditure by COICOP category,
                                 sampling weights (HA10), household size
                                 (HB05) and the modified OECD equivalence
                                 scale (HB062).

    CGEoutputs.xlsx              GEM-E3 model output. Sheets: PriceChange,
                                 dINC, Welfare, TRA.

    GEME3_COICOP_mapping.xlsx    Mapping from the 14 GEM-E3 goods to the
                                 COICOP expenditure categories.

Note: the path to T_with_income.mat is set at the top of data_preparation.m
and must be adjusted to your machine.


4. INSTRUCTIONS
--------------------------------------------------------------------------------
    - Place all files in the same folder
    - Set that folder as your MATLAB working directory
    - Adjust the data path at the top of data_preparation.m
    - Run the master script main.m


5. FILES
--------------------------------------------------------------------------------
    main.m                 Master script. Defines the sensitivity grid, calls
                           everything else, exports the results.

    data_preparation.m     Loads and cleans the microdata; computes income
                           shares, equivalized expenditure, PPS conversion and
                           EU-wide expenditure deciles; produces Figure S1.
                           Local functions: assignDeciles, wNegative,
                           medianIQRplot_EU.

    load_cge_outputs.m     Reads the GEM-E3 outputs and aligns them with the
                           microdata country set.
                           Local function: renamevars_rows.

    run_microsim.m         The microsimulation engine. One call = one policy
                           scenario set under one methodological configuration.
                           Local functions: apply_rescaling, compute_SWF_grid.

    build_figures.m        Dispatcher producing all four figure families.
                           Local functions: fig_boxplot, fig_ver_decomp,
                           fig_hor_decomp, fig_heatmap.

    compose_and_export.m   Saves figures as PNGs and writes an HTML index.

    wprct.m                Weighted percentiles (column-wise).
    wMeanSem.m             Weighted mean and standard error.
    wboxplot.m             Weighted boxplot with grouping and colour groups.

The three w*.m utilities are called from more than one file, so they remain
standalone. All other helpers are provided as local functions into the file
that uses them.


6. PIPELINE
--------------------------------------------------------------------------------
    main.m
      |
      |-- data_preparation.m
      |     Loads matched HBS-SILC microdata; drops Sweden and households
      |     with missing, zero or negative income; defines the COICOP
      |     categories used (CPmod, excluding imputed rents); computes
      |     average income-source shares across the 100 matched draws;
      |     computes equivalized expenditure (modified OECD scale) and its
      |     PPS-adjusted counterpart; assigns EU-wide expenditure deciles
      |     (ExpDcl_eu); produces Figure S1.
      |
      |-- load_cge_outputs.m
      |     Reads GEM-E3 CGE outputs from CGEoutputs.xlsx: goods price
      |     changes, factor price changes, the macro welfare decomposition
      |     by channel, and carbon tax revenue. Maps GEM-E3 goods to 
      |     COICOP and filters to the 25-country microdata sample.
      |
      |-- loop over 2 rescaling methods
      |     |
      |     |-- run_microsim.m    one microsimulation run (see section 7)
      |     |-- build_figures.m   the four figure families for that run
      |
      |-- compose_and_export.m
            Writes PNGs plus an index.html per figure family.


7. STEPS INSIDE run_microsim.m
--------------------------------------------------------------------------------
Section 1  Household-level welfare impacts, expenditure denominator

           AWL / AWK  factor income effects
                      = income x factor share x factor price change
                      Capital: capital value added, including
                      volume changes and windfall profits.

           AWC        consumption effect
                      = -expenditure x price change, by COICOP category
                      Negative because a price increase is a welfare loss.

           ITALY      Italy has no usable HBS income variable (EUR_HH095).
                      The income denominator switches to DispInc_avg for
                      Italian households. This happens once, in the
                      construction of inc_all at the top of the function.

Section 2  Carbon revenue recycling
           Revenue is returned lump-sum, uniformly per equivalent adult
           within each country.

Section 3  Channel rescaling to GEM-E3 macro welfare targets

           The microsimulation reproduces the distribution of impacts but
           not their exact national aggregate, because the microdata and the
           CGE model have different underlying aggregates. Rescaling closes
           this gap channel by channel.

           Three channels: consumption (exp), factor income (fac), carbon
           transfers (tra_carbon). 
           Each channel's micro-macro gap is distributed by apply_rescaling
           using either a uniform relative shift (every household gets the
           same percentage-point adjustment) or a uniform absolute amount
           per equivalent adult (progressive, since a fixed euro amount is
           a larger share of a small budget).

Section 4  EU-wide mean impacts by expenditure decile

Section 5  Social welfare over a four-dimensional grid
           epsilon (inequality aversion) x gamma (horizontal equity weight)
           x rho x tau. Computed in euros and in PPS.


8. THE SOCIAL WELFARE FUNCTION
--------------------------------------------------------------------------------
    Welfare = [general income inequality aversion term] 
		- gamma x [horizontal equity penalty]

INCOME INEQUALITY is the change in the equally-distributed-equivalent (EDE)
income under an Atkinson social welfare function with inequality aversion
epsilon:

    y_EDE(eps) = ( sum_h w_h y_h^(1-eps) / sum_h w_h )^(1/(1-eps))
    vertical   = y_EDE(y0 + delta_y) - y_EDE(y0)

epsilon = 0 gives the unweighted mean (pure efficiency); higher epsilon puts
progressively more weight on the poor.

HORIZONTAL EQUITY penalises dispersion of impacts WITHIN each decile, that is,
households with similar baseline resources being treated differently:

    horizontal = ( sum_h w_h (mean_y/y0_h)^(tau rho)
                            |delta_y_h - dclmean_h|^(1+rho)
                   / sum_h w_h )^(1/(1+rho))

rho controls the curvature of the penalty in the size of the deviation; tau
controls how much extra weight deviations among poor households receive;
gamma sets the overall weight of the horizontal term relative to vertical.

Parameter grid:
    epsilon  0 to 2  step 0.1   (21 values)
    gamma    0 to 1  step 0.05  (21 values)
    rho      0 to 2  step 0.5   (5 values)
    tau      0 to 2  step 0.5   (5 values)
Total: 21 x 21 x 5 x 5 = 11,025 rows per scenario.

Implementation note: epsilon = 1 is a removable singularity of the Atkinson
function (the limit is the geometric mean). It is nudged to 1 + 1e-6, which
is numerically indistinguishable at the resolution of the figures.

The heatmap figures slice this grid at rho = tau = 1. Change rho_fixed and
tau_fixed inside build_figures.m to view a different slice.


9. SENSITIVITY 
--------------------------------------------------------------------------------
The whole analysis is run for the two different rescaling configurations:

    macro     		rescaled to be consistent with macro outcomes [central]
    micro     		no rescaling; pure microsimulation result [sensitivity]

The rescaling for the three channels is set inside run_microsim.m, Section 3:

    expenditure       country-relative
    factor income     country-relative
    carbon transfers  country-absolute

The social welfare weighting is also held fixed, at individual weights
(HA10 x HB05). Equivalence scales represent within-household resource
sharing, not differential moral worth, so individual weights are the
appropriate choice for the SWF.


10. OUTPUT
--------------------------------------------------------------------------------
Written to ./sensitivity_results/, one subfolder per figure family:

   Boxplots/          Single-panel weighted boxplot of the total welfare impact
                      after revenue recycling, by expenditure decile. Boxes show
                      weighted quartiles; whiskers span the weighted 10th to
                      90th percentiles; diamonds mark the weighted mean.

   VerticalDecomp/    Three-panel decomposition of rescaled welfare channels
                      (consumption, factor income, transfers), by expenditure
                      decile. Vertical boxplots.

   HorizontalDecomp/  Median absolute deviation of the welfare impact within
                      each decile, by component. A robust measure of horizontal
                      inequity.

   Heatmaps_PPS/      Social welfare across the (gamma, epsilon) plane, one
                      panel per scenario, in PPS euros. The red outline marks the
                      scenario achieving the highest social welfare in each
                      cell.

Each subfolder contains R{row}.png for either rescaling option plus an
index.html laying them out in a grid. Open the index in a browser to
compare configurations at a glance.

Figure S1 (FigS1_EU_EGOF_OPTE.png) is written to the working directory by
data_preparation.m. Set make_figure_S1 = false at the top of that file to
skip it.

RESULTS AVAILABLE FOR FURTHER ANALYSIS
--------------------------------------------------------------------------------
Each call to run_microsim returns a struct `out` containing four fields,
each with one entry per scenario. main.m passes these to build_figures and
then discards them; to analyse them, save `out` inside the grid loop or
break after a single configuration.

  out.RW_geme3_all.(scenario)
      Household-level table, one row per household, with the columns listed
      in rw_cols: the total welfare impact before and after revenue
      recycling (RWtot, RWtot_rev), the unrescaled channel impacts (LAB,
      CAP, CON, Trnsf), the three rescaling residuals (ResCon, ResFac,
      ResTrCO2) and the rescaled channel totals (CON_resc,
      FAC_resc, Trnsf_resc). All are relative impacts, expressed as a
      fraction of total household expenditure. Row order matches T, so
      this table can be concatenated with T directly to cross-tabulate by
      country, decile, household composition or any other microdata
      variable.

  out.EU_wMeanRW_exp_all.(scenario)
      Weighted mean of each rw_cols component by EU-wide expenditure
      decile, in percent. Rows are components, columns are deciles D1-D10.
      This is the table underlying the diamond markers in the boxplot
      figures.

  out.SocialWelfare_all.(scenario)
      Long-format table of 11,025 rows: every combination of epsilon,
      gamma, rho and tau, with the resulting social welfare level in
      euros. The heatmap figures slice this at rho = tau = 1; the full
      table supports any other slice, or scenario rankings as a function
      of the distributional parameters.

  out.SocialWelfare_PPS_all.(scenario)
      The same grid, in purchasing power standards.

Quantities computed inside run_microsim but not returned:

  AW    Absolute welfare impacts in euros, by channel and by COICOP
        category, plus the equivalized values y0 and delta_y that enter
        the social welfare function. These are computed inside the
        scenario loop but not retained. Two lines in run_microsim.m are
        commented out:

            %AW_all.(scenario) = AW;      (in the store block)
            %out.AW_all        = AW_all;  (in the return block)

        Uncomment both to retain them. Note this is memory-intensive: AW
        carries one column per COICOP category for every household, in
        every scenario.