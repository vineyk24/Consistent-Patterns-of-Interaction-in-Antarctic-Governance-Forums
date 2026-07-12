%% ================================================================
%  Choose dataset: 'ATCM' or 'CCAMLR'  (reads Excel .xlsx with columns: Year, Authors)
%    ATCM_WP_Authors.xlsx
%    CCAMLR_Authors.xlsx
% ================================================================
clear all

%dataset    = 'CCAMLR';  % <-- set to 'ATCM' or 'CCAMLR'
dataset = 'ATCM';     % <-- uncomment to run ATCM
doAnalyses = 0;         % 1 = re-fit models, 0 = load existing Fitting_results_*.mat


% ================== MAX YEAR PARAMETER ==================
% Include only working papers with Year <= maxYear.
% Set maxYear = Inf to include all years in the spreadsheet.
% Example: maxYear = 2020;   % truncate up to and including 2020
maxYear = 2024;
% Use a maxYear-specific .mat file so a truncated run is not confused with
% an all-years run. The legacy filename is also written for compatibility
% with plotting helpers that expect Fitting_results_<dataset>.mat.
if isinf(maxYear)
    maxYearTag = 'all';
else
    maxYearTag = regexprep(sprintf('%.15g', maxYear), '\.', 'p');
end
resultsFile       = sprintf('Fitting_results_%s_maxYear_%s.mat', dataset, maxYearTag);
legacyResultsFile = sprintf('Fitting_results_%s.mat', dataset);


if doAnalyses == 1
    %% ===================== LOAD & PREPARE DATA =====================
    switch upper(dataset)
        case 'ATCM'
            infile = 'ATCM_WP_Authors.xlsx';
        case 'CCAMLR'
            infile = 'CCAMLR_Authors.xlsx';
        otherwise
            error('dataset must be ''ATCM'' or ''CCAMLR''');
    end

    % Robust Excel read: raw cell array (includes header row)
    [~,~,raw] = xlsread(infile);
    if size(raw,2) < 2
        error('Expected at least two columns (Year, Authors) in %s.', infile);
    end

    % Detect header row: if first row, col1 is non-numeric or col2 is not char
    isHeader = false;
    if ~isempty(raw)
        c1 = raw{1,1};
        c2 = raw{1,2};
        if ~(isnumeric(c1) || (ischar(c1) && ~isnan(str2double(c1)))) || ~ischar(c2)
            isHeader = true;
        end
    end

    data = raw(1+isHeader:end, 1:2);  % [Year, Authors] rows (no header)

    % Year: allow numeric or numeric-string
    Year_wp = nan(size(data,1),1);
    for r = 1:size(data,1)
        yr = data{r,1};
        if isnumeric(yr)
            Year_wp(r) = yr;
        elseif ischar(yr)
            Year_wp(r) = str2double(yr);
        else
            Year_wp(r) = NaN;
        end
    end

    % Authors: char only; coauthors separated by commas
    Author_wp = data(:,2);
    Author_wp = cellfun(@(s) ifelse(ischar(s), s, ''), Author_wp, 'uni', false);

     % Drop rows with missing year or empty author cell; apply maxYear cut
    if isinf(maxYear)
        keep = ~isnan(Year_wp) & ~cellfun(@isempty, Author_wp);
    else
        keep = ~isnan(Year_wp) & ~cellfun(@isempty, Author_wp) & (Year_wp <= maxYear);
    end
    Year_wp   = Year_wp(keep);
    Author_wp = Author_wp(keep);
    

    %% ===================== ELIGIBILITY MAPS =====================
    switch upper(dataset)
        case 'ATCM'
            countries = { ...
                'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','China', ...
                'Colombia','Czechia','Ecuador','Finland','France','Germany','Greece','India', ...
                'Italy','Japan','Korea (ROK)','Malaysia','Monaco','Netherlands','New Zealand','Norway', ...
                'Peru','Poland','Romania','Russian Federation','San Marino','Saudi Arabia','Slovakia','Slovenia', ...
                'South Africa','Spain','Sweden','Switzerland','Türkiye','Ukraine','United Kingdom', ...
                'United States','Uruguay','Venezuela', ...
                'SCAR','COMNAP','CCAMLR','IPY-IPO','IHO','IAATO','WMO','ASOC','Portugal','Estonia'};
            eligibility_year = [ ...
                1961,1961,1961,1975,1978,1988,1961,1985, ...
                2020,2014,1990,1989,1961,1981,1968,1983, ...
                1987,1961,1987,2016,2009,1990,1961,1961, ...
                1989,1977,2003,1961,2023,2024,1993,2019, ...
                1961,1988,1988,1990,1996,1992,1961, ...
                1961,1985,1999, ...
                1987,1991,1991,2006,2008,1994,2013,1991,2010,2001];
            eligibilityYearMap = containers.Map(countries, num2cell(eligibility_year));

        case 'CCAMLR'
            ccamlr_countries = { ...
                'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','European Union', ...
                'Finland','France','Germany','Greece','India','Italy','Japan','Namibia','Netherlands', ...
                'New Zealand','Norway','Peru','Poland','Korea (ROK)','Russian Federation', ...
                'South Africa','Spain','Sweden','Ukraine','United Kingdom','United States','Uruguay','Vanuatu','China'};
            ccamlr_year = [ ...
                1982,1982,1984,1986,1992,1988,1982,1982, ...
                1989,1982,1983,1987,1985,1989,1982,2000,1990, ...
                1982,1984,1989,1984,1985,1982, ...
                1982,1984,1984,2000,1982,1982,1985,2001,2007];
            eligibilityYearMap = containers.Map(ccamlr_countries, num2cell(ccamlr_year));
    end

    % CONTINENT MAP (for Model 4: geographic covariate)
    switch upper(dataset)
        case 'ATCM'
            continentMap = containers.Map( ...
                {'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','China', ...
                 'Colombia','Czechia','Ecuador','Finland','France','Germany','Greece','India', ...
                 'Italy','Japan','Korea (ROK)','Malaysia','Monaco','Netherlands','New Zealand','Norway', ...
                 'Peru','Poland','Romania','Russian Federation','San Marino','Saudi Arabia','Slovakia','Slovenia', ...
                 'South Africa','Spain','Sweden','Switzerland','Türkiye','Ukraine','United Kingdom', ...
                 'United States','Uruguay','Venezuela', ...
                 'SCAR','COMNAP','CCAMLR','IPY-IPO','IHO','IAATO','WMO','ASOC','Portugal','Estonia'}, ...
                {'South America','Oceania','Europe','South America','Europe','North America','South America','Asia', ...
                 'South America','Europe','South America','Europe','Europe','Europe','Europe','Asia', ...
                 'Europe','Asia','Asia','Asia','Europe','Europe','Oceania','Europe', ...
                 'South America','Europe','Europe','Europe','Europe','Asia','Europe','Europe', ...
                 'Africa','Europe','Europe','Europe','Europe','Europe','Europe', ...
                 'North America','South America','South America', ...
                 'International','International','International','International','International','International','International','International','Europe','Europe'});

        case 'CCAMLR'
            continentMap = containers.Map( ...
                {'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','European Union', ...
                 'Finland','France','Germany','Greece','India','Italy','Japan','Namibia','Netherlands', ...
                 'New Zealand','Norway','Peru','Poland','Korea (ROK)','Russian Federation', ...
                 'South Africa','Spain','Sweden','Ukraine','United Kingdom','United States','Uruguay','Vanuatu','China'}, ...
                {'South America','Oceania','Europe','South America','Europe','North America','South America','Europe', ...
                 'Europe','Europe','Europe','Europe','Asia','Europe','Asia','Africa','Europe', ...
                 'Oceania','Europe','South America','Europe','Asia','Europe', ...
                 'Africa','Europe','Europe','Europe','Europe','North America','South America','Oceania','Asia'});
    end

    % INCOME CLASSIFICATION MAP (for Model 5: High/Low GNI per capita)
    % World Bank FY2025 classification: 'High' = High-income economy;
    % 'Low' = upper-middle, lower-middle, or low-income economy.
    % International organisations are left unclassified ('__UNKNOWN__').
    switch upper(dataset)
        case 'ATCM'
            incomeClassMap = containers.Map( ...
                {'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','China', ...
                 'Colombia','Czechia','Ecuador','Finland','France','Germany','Greece','India', ...
                 'Italy','Japan','Korea (ROK)','Malaysia','Monaco','Netherlands','New Zealand','Norway', ...
                 'Peru','Poland','Romania','Russian Federation','San Marino','Saudi Arabia','Slovakia','Slovenia', ...
                 'South Africa','Spain','Sweden','Switzerland','Türkiye','Ukraine','United Kingdom', ...
                 'United States','Uruguay','Venezuela', ...
                 'SCAR','COMNAP','CCAMLR','IPY-IPO','IHO','IAATO','WMO','ASOC','Portugal','Estonia'}, ...
                {'Low','High','High','Low','Low','High','High','Low', ...
                 'Low','High','Low','High','High','High','High','Low', ...
                 'High','High','High','Low','High','High','High','High', ...
                 'Low','High','High','Low','High','High','High','High', ...
                 'Low','High','High','High','Low','Low','High', ...
                 'High','High','Low', ...
                 '__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','High','High'});

        case 'CCAMLR'
            incomeClassMap = containers.Map( ...
                {'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','European Union', ...
                 'Finland','France','Germany','Greece','India','Italy','Japan','Namibia','Netherlands', ...
                 'New Zealand','Norway','Peru','Poland','Korea (ROK)','Russian Federation', ...
                 'South Africa','Spain','Sweden','Ukraine','United Kingdom','United States','Uruguay','Vanuatu','China'}, ...
                {'Low','High','High','Low','Low','High','High','__UNKNOWN__', ...
                 'High','High','High','High','Low','High','High','Low','High', ...
                 'High','High','Low','High','High','Low', ...
                 'Low','High','High','Low','High','High','High','Low','Low'});
    end

    % ORIGINAL SIGNATORY YEAR
    if strcmpi(dataset,'ATCM')
        originalYear = 1961;
    elseif strcmpi(dataset,'CCAMLR')
        originalYear = 1982;
    else
        error('dataset must be ATCM or CCAMLR');
    end

    %% ===================== GRIDS (dataset-specific) =====================
    switch upper(dataset)
        case 'ATCM'
            G = 40;
            % Model 1 (linear)
            delta1_grid = linspace(1, 4, G);
            % Model 2 (δ + exponent)
            delta_grid  = linspace(1, 4, round(G/2));
            exp_grid    = linspace(0.5, 1, round(G/2));
            % Model 3b grids
            delta1_grid2 = linspace(1, 4, round(G/2));  % δ1
            delta2_grid2 = linspace(1, 4, round(G/2));  % δ2
            exp1_grid2   = linspace(0.5, 1, round(G/2));% λ1 (OO)
            exp2_grid2   = linspace(0.5, 1, round(G/2));% λ2 (other)
            % Model 4 grids (geographic: same-continent vs cross-continent)
            delta1_grid4 = linspace(1, 4, round(G/2));   % δ_same
            delta2_grid4 = linspace(1, 4, round(G/2));   % δ_cross
            exp1_grid4   = linspace(0.5, 1, round(G/2)); % λ_same
            exp2_grid4   = linspace(0.5, 1, round(G/2)); % λ_cross
            % Model 5 grids (income: same-group vs cross-group)
            delta1_grid5 = linspace(1, 4, round(G/2));   % δ_same_inc
            delta2_grid5 = linspace(1, 4, round(G/2));   % δ_cross_inc
            exp1_grid5   = linspace(0.5, 1, round(G/2)); % λ_same_inc
            exp2_grid5   = linspace(0.5, 1, round(G/2)); % λ_cross_inc
            minDelta = 1.0;  maxDelta = 4.0;

        case 'CCAMLR'
            G = 40;
            % Model 1 (linear)
            delta1_grid = linspace(1.5, 5.0, G);
            % Model 2 (δ + exponent)
            % Keep these grids/bounds identical to fit_models_on_window so
            % maxYear = 2022 and window [1982,2022] runs align.
            delta_grid  = linspace(2.0, 7.0, round(G/2));
            exp_grid    = linspace(0.25, 1.25, round(G/2));
            % Model 3b grids
            delta1_grid2 = linspace(2.0, 7.0, round(G/2));   % δ1
            delta2_grid2 = linspace(2.0, 7.0, round(G/2));   % δ2
            exp1_grid2   = linspace(0.25, 1.25, round(G/2)); % λ1 (OO)
            exp2_grid2   = linspace(0.25, 1.25, round(G/2)); % λ2 (other)
            % Model 4 grids (geographic: same-continent vs cross-continent)
            delta1_grid4 = linspace(2.0, 7.0, round(G/2));   % δ_same
            delta2_grid4 = linspace(2.0, 7.0, round(G/2));   % δ_cross
            exp1_grid4   = linspace(0.25, 1.25, round(G/2)); % λ_same
            exp2_grid4   = linspace(0.25, 1.25, round(G/2)); % λ_cross
            % Model 5 grids (income: same-group vs cross-group)
            delta1_grid5 = linspace(2.0, 7.0, round(G/2));   % δ_same_inc
            delta2_grid5 = linspace(2.0, 7.0, round(G/2));   % δ_cross_inc
            exp1_grid5   = linspace(0.25, 1.25, round(G/2)); % λ_same_inc
            exp2_grid5   = linspace(0.25, 1.25, round(G/2)); % λ_cross_inc
            minDelta = 2.0;  maxDelta = 10.0;
    end

    %% ===================== PRECOMPUTE DATASET =====================
    pre = build_precomputed_dataset_fast(Author_wp, Year_wp, eligibilityYearMap, originalYear, continentMap, incomeClassMap);

    %% ===================== MODEL 1: Linear (exponent = 1) =====================
    logL_lin = zeros(numel(delta1_grid),1);
    for i = 1:numel(delta1_grid)
        params = struct('delta1', delta1_grid(i), 'delta2', delta1_grid(i), 'exponent', 1);
        logL_lin(i) = loglik_twoDelta_fast(pre, params, false);
    end
    [logL_lin_max, idx_lin_max] = max(logL_lin);

    %% ===================== MODEL 2: Single δ + λ (with edge zoom) =====================
    [bestVal_single, best_delta_eq, best_exponent_single, logL_single, ...
        delta_grid, exp_grid] = search_model2_with_zoom( ...
            pre, delta_grid, exp_grid, minDelta, maxDelta, 0.1, 2.0);

    %% ===================== MODEL 3b: Two δ + two λ (4-D) with edge zoom =====================
    [bestVal_two4D, best_delta1, best_delta2, best_lambda1_two, best_lambda2_two, ...
        logL_two, delta1_grid2, delta2_grid2, exp1_grid2, exp2_grid2] = ...
        search_model3b_with_zoom(pre, delta1_grid2, delta2_grid2, ...
                                 exp1_grid2, exp2_grid2, ...
                                 minDelta, maxDelta, 0.1, 2.0);

    %% ===================== MODEL 4: Geographic (same vs cross continent, 4-D) =====================
    [bestVal_geo4D, best_delta_same, best_delta_cross, best_lambda_same, best_lambda_cross, ...
        logL_geo, delta1_grid4, delta2_grid4, exp1_grid4, exp2_grid4] = ...
        search_model4_geo_with_zoom(pre, delta1_grid4, delta2_grid4, ...
                                    exp1_grid4, exp2_grid4, ...
                                    minDelta, maxDelta, 0.1, 2.0);

    %% ===================== MODEL 5: Income (same vs cross group, 4-D) =====================
    [bestVal_inc4D, best_delta_same_inc, best_delta_cross_inc, best_lambda_same_inc, best_lambda_cross_inc, ...
        logL_inc, delta1_grid5, delta2_grid5, exp1_grid5, exp2_grid5] = ...
        search_model5_income_with_zoom(pre, delta1_grid5, delta2_grid5, ...
                                       exp1_grid5, exp2_grid5, ...
                                       minDelta, maxDelta, 0.1, 2.0);

    % Save everything.
    % resultsFile avoids mixing different maxYear runs; legacyResultsFile keeps
    % compatibility with helper functions that still load Fitting_results_<dataset>.
    save(resultsFile);
    save(legacyResultsFile);

else
    %% ===================== LOAD PREVIOUS FITS =====================
    loadVars = {'logL*','delta*','idx_lin_max','exp_grid','exp*','best*', ...
                '*_wp','eligibilityYearMap','originalYear','pre', ...
                'continentMap','incomeClassMap'};
    if exist(resultsFile, 'file')
        load(resultsFile, loadVars{:});
    elseif exist(legacyResultsFile, 'file')
        warning('Using legacy results file %s. Rerun with doAnalyses = 1 to create %s.', ...
                legacyResultsFile, resultsFile);
        load(legacyResultsFile, loadVars{:});
    else
        error('No fitting results file found. Expected %s or %s. Set doAnalyses = 1.', ...
              resultsFile, legacyResultsFile);
    end

    % Construct continentMap if missing from older save file
    if ~exist('continentMap','var')
        continentMap = local_build_continentMap(dataset);
    end

    % Construct incomeClassMap if missing from older save file
    if ~exist('incomeClassMap','var')
        incomeClassMap = local_build_incomeClassMap(dataset);
    end

    % If precompute is missing or stale, rebuild it.
    % Older Fitting_results_*.mat files may contain a pre struct without
    % fields added later, e.g. isGeo_mask for Model 4 or isIncome_mask for Model 5.
    if ~exist('pre','var') || isempty(pre) || ...
       ~isfield(pre, 'isGeo_mask') || ~isfield(pre, 'id2name') || ...
       ~isfield(pre, 'isIncome_mask')
        pre = build_precomputed_dataset_fast(Author_wp, Year_wp, ...
                                             eligibilityYearMap, originalYear, continentMap, incomeClassMap);
    end

    switch upper(dataset)
        case 'ATCM'
            minDelta = 1.0; maxDelta = 4.0;
        case 'CCAMLR'
            minDelta = 2.0; maxDelta = 10.0;
    end

    % If Model 5 estimates are missing, fit them now.
    if ~exist('bestVal_inc4D','var') || ~exist('best_delta_same_inc','var')
        switch upper(dataset)
            case 'ATCM'
                delta1_grid5 = linspace(1, 4, 20); delta2_grid5 = delta1_grid5;
                exp1_grid5   = linspace(0.5, 1, 20); exp2_grid5  = exp1_grid5;
            case 'CCAMLR'
                delta1_grid5 = linspace(2.0, 7.0, 20); delta2_grid5 = delta1_grid5;
                exp1_grid5   = linspace(0.25, 1.25, 20); exp2_grid5 = exp1_grid5;
        end
        [bestVal_inc4D, best_delta_same_inc, best_delta_cross_inc, ...
            best_lambda_same_inc, best_lambda_cross_inc] = ...
            search_model5_income_with_zoom(pre, delta1_grid5, delta2_grid5, ...
                                           exp1_grid5, exp2_grid5, ...
                                           minDelta, maxDelta, 0.1, 2.0);

        if exist(resultsFile, 'file')
            save(resultsFile, ...
                 'bestVal_inc4D', 'best_delta_same_inc', 'best_delta_cross_inc', ...
                 'best_lambda_same_inc', 'best_lambda_cross_inc', '-append');
        end
        if exist(legacyResultsFile, 'file')
            save(legacyResultsFile, ...
                 'bestVal_inc4D', 'best_delta_same_inc', 'best_delta_cross_inc', ...
                 'best_lambda_same_inc', 'best_lambda_cross_inc', '-append');
        end
    end
end

%% ===================== FIGURE 1: LIKELIHOOD SURFACES =====================
figure(1); clf

% (1,3,1) Linear cross-section
subplot(1,3,1)
plot(delta1_grid, logL_lin, 'LineWidth', 2); grid on
hold on
plot(delta1_grid(idx_lin_max), logL_lin_max, 'bo', 'MarkerFaceColor','b')
hold off
xlabel('$\delta$','Interpreter','latex')
ylabel('log-likelihood','Interpreter','latex')
title(sprintf('Model 1 (%s): Linear, single $\\delta$', upper(dataset)), ...
      'Interpreter','latex')

% (1,3,2) Single-δ + λ surface
subplot(1,3,2)
[DD, EE] = meshgrid(delta_grid, exp_grid);
pc = pcolor(DD, EE, logL_single'); set(pc,'edgecolor','none')
colormap parula; colorbar
hold on
plot(best_delta_eq, best_exponent_single, 'ko', ...
     'MarkerFaceColor','w', 'MarkerSize',6)
hold off
xlabel('$\delta$','Interpreter','latex')
ylabel('$\lambda$','Interpreter','latex')
title(sprintf('Model 2 (%s): single $\\delta$ + $\\lambda$', upper(dataset)), ...
      'Interpreter','latex')

% (1,3,3) Two-δ surface at best (λ1, λ2) for Model 3b
subplot(1,3,3)
[DD1, DD2] = meshgrid(delta1_grid2, delta2_grid2);
pc2 = pcolor(DD1, DD2, logL_two'); set(pc2,'edgecolor','none')
colormap parula; colorbar
hold on
plot(best_delta1, best_delta2, 'ks', ...
     'MarkerFaceColor','w', 'MarkerSize',6)
hold off
xlabel('$\delta_1$','Interpreter','latex')
ylabel('$\delta_2$','Interpreter','latex')
title(sprintf('Model 3b (%s): two $\\delta$''s ($\\lambda_1 = %.3f, \\lambda_2 = %.3f$)', ...
      upper(dataset), best_lambda1_two, best_lambda2_two), ...
      'Interpreter','latex')

%% ===================== MODEL 0: Null (delta = 0) =====================
null_params = struct('delta1', 0, 'delta2', 0, 'exponent', 1);
logL_null = loglik_twoDelta_fast(pre, null_params, false);

%% ===================== AIC COMPARISON =====================
LL0  = logL_null;        k0  = 0;
LL1  = logL_lin_max;     k1  = 1;
LL2  = bestVal_single;   k2  = 2;
LL3b = bestVal_two4D;    k3b = 4;   % (δ1, δ2, λ1, λ2)
LL4  = bestVal_geo4D;    k4  = 4;   % (δ_same, δ_cross, λ_same, λ_cross)
LL5  = bestVal_inc4D;    k5  = 4;   % (δ_same_inc, δ_cross_inc, λ_same_inc, λ_cross_inc)

AIC0  = 2*k0  - 2*LL0;
AIC1  = 2*k1  - 2*LL1;
AIC2  = 2*k2  - 2*LL2;
AIC3b = 2*k3b - 2*LL3b;
AIC4  = 2*k4  - 2*LL4;
AIC5  = 2*k5  - 2*LL5;

fprintf('\n=== %s | Likelihood & AIC Summary ===\n', upper(dataset));
fprintf('Model 0 (Null):            logL = %.6f,  AIC = %.6f\n', LL0, AIC0);
fprintf('Model 1 (Linear):          MLE delta = %.6f | logL = %.6f, AIC = %.6f\n', ...
        delta1_grid(idx_lin_max), LL1, AIC1);
fprintf('Model 2 (δ+λ):             MLE delta = %.6f, λ = %.6f | logL = %.6f, AIC = %.6f\n', ...
        best_delta_eq, best_exponent_single, LL2, AIC2);
fprintf('Model 3b (δ1,δ2,λ1,λ2):    MLE δ1 = %.6f, δ2 = %.6f, λ1 = %.6f, λ2 = %.6f | logL = %.6f, AIC = %.6f\n', ...
        best_delta1, best_delta2, best_lambda1_two, best_lambda2_two, LL3b, AIC3b);
fprintf('Model 4 (Geo δs,δx,λs,λx): MLE δ_same = %.6f, δ_cross = %.6f, λ_same = %.6f, λ_cross = %.6f | logL = %.6f, AIC = %.6f\n', ...
        best_delta_same, best_delta_cross, best_lambda_same, best_lambda_cross, LL4, AIC4);
fprintf('Model 5 (Inc δs,δx,λs,λx): MLE δ_same = %.6f, δ_cross = %.6f, λ_same = %.6f, λ_cross = %.6f | logL = %.6f, AIC = %.6f\n', ...
        best_delta_same_inc, best_delta_cross_inc, best_lambda_same_inc, best_lambda_cross_inc, LL5, AIC5);

AICs = [AIC0 AIC1 AIC2 AIC3b AIC4 AIC5];
dAIC = AICs - min(AICs);
w    = exp(-0.5*dAIC); w = w/sum(w);
labels = {'Null','Linear','Single δ','Two δ (λ1,λ2)','Geo (same/cross)','Income (same/cross)'};
fprintf('\n=== AIC Weights ===\n')
for m = 1:numel(labels)
    fprintf('  %-22s  ΔAIC = %7.3f   weight = %.3f\n', labels{m}, dAIC(m), w(m));
end

%% ---------- Per-year AIC weights (stacked bars), using best-fit params ----------
[~, ll_y0, yrs] = loglik_twoDelta_fast(pre, ...
    struct('delta1',0,'delta2',0,'exponent',1), true);
[~, ll_y1, ~  ] = loglik_twoDelta_fast(pre, ...
    struct('delta1',delta1_grid(idx_lin_max), ...
           'delta2',delta1_grid(idx_lin_max), ...
           'exponent',1), true);
[~, ll_y2, ~  ] = loglik_twoDelta_fast(pre, ...
    struct('delta1',best_delta_eq, ...
           'delta2',best_delta_eq, ...
           'exponent',best_exponent_single), true);
[~, ll_y3b, ~ ] = loglik_twoDelta_fast(pre, ...
    struct('delta1',best_delta1, ...
           'delta2',best_delta2, ...
           'lambda1',best_lambda1_two, ...
           'lambda2',best_lambda2_two), true);
[~, ll_y4, ~  ] = loglik_geo_fast(pre, ...
    struct('delta1',best_delta_same, ...
           'delta2',best_delta_cross, ...
           'lambda1',best_lambda_same, ...
           'lambda2',best_lambda_cross), true);
[~, ll_y5, ~  ] = loglik_income_fast(pre, ...
    struct('delta1',best_delta_same_inc, ...
           'delta2',best_delta_cross_inc, ...
           'lambda1',best_lambda_same_inc, ...
           'lambda2',best_lambda_cross_inc), true);

LL_year = [ll_y0 ll_y1 ll_y2 ll_y3b ll_y4 ll_y5];   % rows: years, cols: models
k_vec   = [0 1 2 4 4 4];
AIC_y   = 2*(k_vec) - 2*LL_year;        % automatic broadcasting
dAIC_y  = AIC_y - min(AIC_y, [], 2);
w_y     = exp(-0.5*dAIC_y); 
w_y     = w_y ./ sum(w_y,2);            % row-normalise

% Year counts and mask to omit years with no collaborations
year_counts = pre.n_y(:);
mask        = year_counts > 0;

yrs_plot    = yrs(mask);
w_y_plot    = w_y(mask,:);
counts_plot = year_counts(mask);

% Share of total collaborations (0–1)
share_collab = counts_plot / sum(counts_plot);

%% ---------- Figure 2: Single-panel AIC weights (current dataset) ----------
% Stack order bottom-to-top: Null, Linear, Single δ, Two δ, Geo, Income
% w_y_plot columns are [Null, Linear, Single, Two, Geo, Income] — already correct

figure(2); clf

hb = bar(yrs_plot, w_y_plot, 1.0, 'stacked');
box on; grid off
ylim([0 1]);

% Colour scheme: cool gradient for endogenous, warm accents for covariates
hb(1).FaceColor = [0.40 0.00 0.40];   % Null: dark purple
hb(2).FaceColor = [0.30 0.30 0.70];   % Linear: blue-purple
hb(3).FaceColor = [0.20 0.60 0.60];   % Single δ: teal
hb(4).FaceColor = [0.45 0.75 0.35];   % Two δ: green
hb(5).FaceColor = [0.85 0.60 0.15];   % Geo: amber
hb(6).FaceColor = [0.75 0.25 0.20];   % Income: brick red
for kk = 1:6, hb(kk).EdgeColor = 'none'; end

xlim([min(yrs_plot)-1, max(yrs_plot)+1]);
% Thin x-axis labels
tick_years = yrs_plot(1):3:yrs_plot(end);
tick_years = intersect(tick_years, yrs_plot);
xticks(tick_years);
xtickangle(0);

xlabel('Year','Interpreter','latex','FontSize',12);
ylabel('AIC weight','Interpreter','latex','FontSize',12);
title(upper(dataset),'Interpreter','latex','FontSize',14);
set(gca,'TickLabelInterpreter','latex','FontName','Times','FontSize',10);
set(gca,'YTick',0:0.2:1);

legend(hb, ...
    {'Random attachment', ...
     'Preferential; linear', ...
     'Preferential; single $\delta$', ...
     'Preferential; two $\delta$', ...
     'Preferential; geographic', ...
     'Preferential; income'}, ...
    'Interpreter','latex', ...
    'Location','eastoutside', ...
    'Box','off','FontSize',9);

%% ===================== CONFIDENCE INTERVALS (95%) =====================
alpha = 0.05; %#ok<NASGU>
z = 1.95996398454005;                 % 97.5th percentile of N(0,1)
chi2_95_1df = 3.84145882069412;
dLL_thresh  = 0.5 * chi2_95_1df;

fprintf('\n=== 95%% Confidence Intervals (Wald) ===\n');

% Model 1: δ (linear)
delta_hat_M1 = delta1_grid(idx_lin_max);
[ci_wald_M1, info_M1] = wald_ci_model1(pre, delta_hat_M1); %#ok<ASGLU>
fprintf('Model 1: delta  = %.6f  [%.6f, %.6f]\n', ...
        delta_hat_M1, ci_wald_M1(1), ci_wald_M1(2));

% Model 2: (δ, λ)
[ci_wald_M2, info_M2] = wald_ci_model2(pre, best_delta_eq, best_exponent_single); %#ok<ASGLU>
fprintf('Model 2: delta  = %.6f  [%.6f, %.6f]\n', ...
        best_delta_eq, ci_wald_M2.delta(1), ci_wald_M2.delta(2));
fprintf('         lambda = %.6f  [%.6f, %.6f]\n', ...
        best_exponent_single, ci_wald_M2.lambda(1), ci_wald_M2.lambda(2));

% Profile-likelihood CIs for Model 2
ci_prof_M2 = profile_ci_model2(pre, best_delta_eq, best_exponent_single, ...
                               minDelta, maxDelta, 0.1, 2.0, dLL_thresh);
fprintf('Model 2 (profile): delta  = [%.6f, %.6f]\n',  ci_prof_M2.delta(1),  ci_prof_M2.delta(2));
fprintf('                    lambda = [%.6f, %.6f]\n', ci_prof_M2.lambda(1), ci_prof_M2.lambda(2));

% Model 3b: (δ1, δ2, λ1, λ2)
[ci_wald_M3b, info_M3b] = wald_ci_model3b(pre, best_delta1, best_delta2, ...
                                          best_lambda1_two, best_lambda2_two); %#ok<ASGLU>
fprintf('\nModel 3b: delta1  = %.6f  [%.6f, %.6f]\n', ...
        best_delta1, ci_wald_M3b.delta1(1), ci_wald_M3b.delta1(2));
fprintf('          delta2  = %.6f  [%.6f, %.6f]\n', ...
        best_delta2, ci_wald_M3b.delta2(1), ci_wald_M3b.delta2(2));
fprintf('          lambda1 = %.6f  [%.6f, %.6f]\n', ...
        best_lambda1_two, ci_wald_M3b.lambda1(1), ci_wald_M3b.lambda1(2));
fprintf('          lambda2 = %.6f  [%.6f, %.6f]\n', ...
        best_lambda2_two, ci_wald_M3b.lambda2(1), ci_wald_M3b.lambda2(2));

% Model 4: (δ_same, δ_cross, λ_same, λ_cross) — geographic
[ci_wald_M4, info_M4] = wald_ci_model4_geo(pre, best_delta_same, best_delta_cross, ...
                                            best_lambda_same, best_lambda_cross); %#ok<ASGLU>
fprintf('\nModel 4 (Geo): delta_same   = %.6f  [%.6f, %.6f]\n', ...
        best_delta_same, ci_wald_M4.delta1(1), ci_wald_M4.delta1(2));
fprintf('               delta_cross  = %.6f  [%.6f, %.6f]\n', ...
        best_delta_cross, ci_wald_M4.delta2(1), ci_wald_M4.delta2(2));
fprintf('               lambda_same  = %.6f  [%.6f, %.6f]\n', ...
        best_lambda_same, ci_wald_M4.lambda1(1), ci_wald_M4.lambda1(2));
fprintf('               lambda_cross = %.6f  [%.6f, %.6f]\n', ...
        best_lambda_cross, ci_wald_M4.lambda2(1), ci_wald_M4.lambda2(2));

% Model 5: (δ_same, δ_cross, λ_same, λ_cross) — income classification
[ci_wald_M5, info_M5] = wald_ci_model5_income(pre, best_delta_same_inc, best_delta_cross_inc, ...
                                               best_lambda_same_inc, best_lambda_cross_inc); %#ok<ASGLU>
fprintf('\nModel 5 (Income): delta_same   = %.6f  [%.6f, %.6f]\n', ...
        best_delta_same_inc, ci_wald_M5.delta1(1), ci_wald_M5.delta1(2));
fprintf('                  delta_cross  = %.6f  [%.6f, %.6f]\n', ...
        best_delta_cross_inc, ci_wald_M5.delta2(1), ci_wald_M5.delta2(2));
fprintf('                  lambda_same  = %.6f  [%.6f, %.6f]\n', ...
        best_lambda_same_inc, ci_wald_M5.lambda1(1), ci_wald_M5.lambda1(2));
fprintf('                  lambda_cross = %.6f  [%.6f, %.6f]\n', ...
        best_lambda_cross_inc, ci_wald_M5.lambda2(1), ci_wald_M5.lambda2(2));

%% ===================== ECDF ENVELOPE PANELS (1000 sims) =====================
% Make sure you have run this for BOTH datasets ("ATCM" and "CCAMLR")
% so that Fitting_results_ATCM.mat and Fitting_results_CCAMLR.mat exist.
plot_ecdf_two_delta_both(1000, 12345);

%% ===================== TWO-PANEL AIC WEIGHTS (Fig 4) =====================
% Requires both Fitting_results_ATCM.mat and Fitting_results_CCAMLR.mat
if exist('Fitting_results_ATCM.mat','file') && exist('Fitting_results_CCAMLR.mat','file')
    plot_figure4_both();
else
    fprintf('Skipping Figure 4: need both ATCM and CCAMLR .mat files.\n');
end

%% ===================== STRETCHED EXPONENTIAL (Fig 6) =====================
% Requires Fitting_results_ATCM.mat
if exist('Fitting_results_ATCM.mat','file')
    plot_figure6_stretched_exp();
else
    fprintf('Skipping Figure 6: need ATCM .mat file.\n');
end


if doAnalyses==0
    % Ensure 'pre' exists (build if needed)
    if ~exist('pre','var') || isempty(pre)
        pre = build_precomputed_dataset_fast(Author_wp, Year_wp, eligibilityYearMap, originalYear, continentMap, incomeClassMap);
    end
    
    window = fit_models_on_window(pre, dataset, 1982, 2022);
    %years_to_check = [2023 2024]; 
    %diag = diagnose_late_arrivals(pre, years_to_check, dataset, true);
    
end



%% ============================= FAST CORE (precompute + evaluate) =============================
function pre = build_precomputed_dataset_fast(Author_wp, Year_wp, eligibilityMap, originalYear, continentMap, incomeClassMap)
    [papers, id2name, ~, ~, Year_sorted] = local_buildPapers(Author_wp, Year_wp);
    eligYearById = local_eligibilityYearById(id2name, eligibilityMap);

    if nargin < 4 || isempty(originalYear)
        finiteYears = eligYearById(isfinite(eligYearById));
        if isempty(finiteYears)
            originalYear = inf;
        else
            originalYear = min(finiteYears);
        end
    end
    isOriginal = (eligYearById == originalYear);

    % Build continent-by-ID vector for geographic model
    hasGeo = (nargin >= 5) && ~isempty(continentMap);
    continentById = cell(numel(id2name),1);
    if hasGeo
        for id = 1:numel(id2name)
            nm = normalizePartyName(id2name{id});
            if isKey(continentMap, nm)
                continentById{id} = continentMap(nm);
            else
                continentById{id} = '__UNKNOWN__';
            end
        end
    end

    % Build income-class-by-ID vector for income model (Model 5)
    hasIncome = (nargin >= 6) && ~isempty(incomeClassMap);
    incomeById = cell(numel(id2name),1);
    if hasIncome
        for id = 1:numel(id2name)
            nm = normalizePartyName(id2name{id});
            if isKey(incomeClassMap, nm)
                incomeById{id} = incomeClassMap(nm);
            else
                incomeById{id} = '__UNKNOWN__';
            end
        end
    end

    years = unique(Year_sorted, 'stable');
    [startIdx, runLen] = firstIndicesOfGroups(Year_sorted);

    N = numel(id2name);
    Y = numel(years);

    pre.N = N; pre.Y = Y;
    pre.years = years;
    pre.baseEdges     = zeros(Y,1);
    pre.n_y           = zeros(Y,1);
    pre.gammaln_const = zeros(Y,1);
    pre.all_lin       = cell(Y,1);
    pre.isOO_mask     = cell(Y,1);
    pre.isGeo_mask    = cell(Y,1);   % same-continent mask for all eligible pairs
    pre.isIncome_mask = cell(Y,1);   % same-income-group mask for all eligible pairs
    pre.obs           = cell(Y,1);

    for yix = 1:Y
        y  = years(yix);
        i0 = startIdx(yix);
        i1 = i0 + runLen(yix) - 1;

        elig = find(eligYearById <= y);
        m = numel(elig);
        if m < 2
            pre.baseEdges(yix)   = 0;
            pre.all_lin{yix}     = [];
            pre.isOO_mask{yix}   = [];
            pre.isGeo_mask{yix}  = [];
            pre.isIncome_mask{yix} = [];
            pre.obs{yix}         = struct('i',[],'j',[],'cnt',[],'isOO',[],'isGeo',[],'isIncome',[]);
            pre.n_y(yix)         = 0;
            pre.gammaln_const(yix) = 0;
            continue
        end

        [ii, jj] = find(triu(true(m),1));
        gi = elig(ii); gj = elig(jj);
        pre.baseEdges(yix) = numel(gi);
        pre.all_lin{yix}   = sub2ind([N,N], gi, gj);
        pre.isOO_mask{yix} = isOriginal(gi) & isOriginal(gj);

        % Geographic mask: same continent for the full eligible pair set
        if hasGeo
            pre.isGeo_mask{yix} = strcmp(continentById(gi), continentById(gj));
        else
            pre.isGeo_mask{yix} = false(size(gi));
        end

        % Income mask: same income group for the full eligible pair set
        if hasIncome
            pre.isIncome_mask{yix} = strcmp(incomeById(gi), incomeById(gj));
        else
            pre.isIncome_mask{yix} = false(size(gi));
        end

        pair_list = [];
        for t = i0:i1
            A = papers{t};
            if isempty(A), continue, end

            % --- De-duplicate authors WITHIN a paper ---
            % (avoid multiple mentions of same party in one WP)
            A = unique(A(:));                    % unique IDs, sorted ascending

            % Keep only authors eligible by year y
            A = A(eligYearById(A) <= y);
            if numel(A) < 2, continue, end

            % All unordered author pairs from this paper
            % (nchoosek on sorted unique A gives i<j already)
            E = nchoosek(A, 2);                  % size: [#pairs, 2]

            pair_list = [pair_list; E]; %#ok<AGROW>
        end

        % --- Canonicalise to i<j and drop any diagonal, just in case ---
        if ~isempty(pair_list)
            i_pairs = pair_list(:,1);
            j_pairs = pair_list(:,2);

            % Force i <= j orientation
            swap = i_pairs > j_pairs;
            tmp = i_pairs(swap);
            i_pairs(swap) = j_pairs(swap);
            j_pairs(swap) = tmp;

            % Drop i == j (shouldn't really occur after unique+nchoosek, but safe)
            mask_offdiag = (i_pairs ~= j_pairs);
            i_pairs = i_pairs(mask_offdiag);
            j_pairs = j_pairs(mask_offdiag);

            pair_list = [i_pairs, j_pairs];
        end

        if isempty(pair_list)
            pre.obs{yix}           = struct('i',[],'j',[],'cnt',[],'isOO',[],'isGeo',[],'isIncome',[]);
            pre.n_y(yix)           = 0;
            pre.gammaln_const(yix) = 0;
        else
            % Aggregate over all papers in this year:
            % each unordered pair (i<j) gets a count cnt_ij
            lin  = sub2ind([N,N], pair_list(:,1), pair_list(:,2));
            [u_lin, ~, g] = unique(lin);
            cnt = accumarray(g, 1);
            [ri, rj] = ind2sub([N,N], u_lin);

            % Geographic mask for observed pairs
            if hasGeo
                isGeo_obs = strcmp(continentById(ri), continentById(rj));
            else
                isGeo_obs = false(size(ri));
            end

            % Income mask for observed pairs
            if hasIncome
                isIncome_obs = strcmp(incomeById(ri), incomeById(rj));
            else
                isIncome_obs = false(size(ri));
            end

            pre.obs{yix} = struct('i',ri, 'j',rj, 'cnt',cnt, ...
                                  'isOO', isOriginal(ri) & isOriginal(rj), ...
                                  'isGeo', isGeo_obs, ...
                                  'isIncome', isIncome_obs);
            pre.n_y(yix)           = sum(cnt);
            pre.gammaln_const(yix) = gammaln(pre.n_y(yix) + 1) - sum(gammaln(cnt + 1));
        end
    end

    % Store party names for reference
    pre.id2name = id2name;
end

function [logL, ll_year, years] = loglik_twoDelta_fast(pre, params, returnYearly)
    if nargin < 3, returnYearly = false; end
    delta1 = params.delta1;
    delta2 = params.delta2;

    if isfield(params,'lambda1') && isfield(params,'lambda2')
        expo_OO    = params.lambda1;
        expo_other = params.lambda2;
    else
        expo       = params.exponent;
        expo_OO    = expo;
        expo_other = expo;
    end

    N = pre.N;
    Y = pre.Y;
    years = pre.years;

    W = sparse(N,N);
    logL = 0;
    ll_year = zeros(Y,1);

    for yix = 1:Y
        baseEdges = pre.baseEdges(yix);
        if baseEdges == 0
            ll_year(yix) = 0;
            continue
        end

        all_lin = pre.all_lin{yix};
        isOO    = pre.isOO_mask{yix};

        if isempty(all_lin)
            S = baseEdges;
        else
            w_all = full(W(all_lin));
            sumOO     = sum( (w_all(isOO)).^expo_OO );
            sumOthers = sum( (w_all(~isOO)).^expo_other );
            S = baseEdges + delta1*sumOO + delta2*sumOthers;
        end

        obs = pre.obs{yix};
        if ~isempty(obs.i)
            obs_lin = sub2ind([N,N], obs.i, obs.j);
            w_obs   = full(W(obs_lin));
            deltas  = delta2 * ones(size(obs.cnt));
            deltas(obs.isOO) = delta1;

            expos   = expo_other * ones(size(obs.cnt));
            expos(obs.isOO) = expo_OO;

            ll_y = pre.gammaln_const(yix) ...
                 + sum( obs.cnt .* log( 1 + deltas .* (w_obs.^expos) ) ) ...
                 - pre.n_y(yix) * log(S);

            ll_year(yix) = ll_y;
            logL = logL + ll_y;

            W = W + sparse(obs.i, obs.j, obs.cnt, N,N) ...
                  + sparse(obs.j, obs.i, obs.cnt, N,N);
        else
            ll_year(yix) = 0;
        end
    end

    if ~returnYearly
        ll_year = [];
        years   = [];
    end
end

function [logL, ll_year, years] = loglik_geo_fast(pre, params, returnYearly)
% LOGLIK_GEO_FAST  Same structure as loglik_twoDelta_fast, but splits edges
% by same-continent (isGeo) vs. cross-continent (~isGeo) instead of OO.
%   params.delta1  = δ_same    (same-continent reinforcement weight)
%   params.delta2  = δ_cross   (cross-continent reinforcement weight)
%   params.lambda1 = λ_same    (same-continent exponent)
%   params.lambda2 = λ_cross   (cross-continent exponent)
    if nargin < 3, returnYearly = false; end
    delta1 = params.delta1;   % δ_same
    delta2 = params.delta2;   % δ_cross

    if isfield(params,'lambda1') && isfield(params,'lambda2')
        expo_same  = params.lambda1;
        expo_cross = params.lambda2;
    else
        expo       = params.exponent;
        expo_same  = expo;
        expo_cross = expo;
    end

    N = pre.N;
    Y = pre.Y;
    years = pre.years;

    W = sparse(N,N);
    logL = 0;
    ll_year = zeros(Y,1);

    for yix = 1:Y
        baseEdges = pre.baseEdges(yix);
        if baseEdges == 0
            ll_year(yix) = 0;
            continue
        end

        all_lin = pre.all_lin{yix};
        isGeo   = pre.isGeo_mask{yix};   % same-continent mask

        if isempty(all_lin)
            S = baseEdges;
        else
            w_all = full(W(all_lin));
            sumSame  = sum( (w_all(isGeo)).^expo_same );
            sumCross = sum( (w_all(~isGeo)).^expo_cross );
            S = baseEdges + delta1*sumSame + delta2*sumCross;
        end

        obs = pre.obs{yix};
        if ~isempty(obs.i)
            obs_lin = sub2ind([N,N], obs.i, obs.j);
            w_obs   = full(W(obs_lin));
            deltas  = delta2 * ones(size(obs.cnt));
            deltas(obs.isGeo) = delta1;

            expos   = expo_cross * ones(size(obs.cnt));
            expos(obs.isGeo) = expo_same;

            ll_y = pre.gammaln_const(yix) ...
                 + sum( obs.cnt .* log( 1 + deltas .* (w_obs.^expos) ) ) ...
                 - pre.n_y(yix) * log(S);

            ll_year(yix) = ll_y;
            logL = logL + ll_y;

            W = W + sparse(obs.i, obs.j, obs.cnt, N,N) ...
                  + sparse(obs.j, obs.i, obs.cnt, N,N);
        else
            ll_year(yix) = 0;
        end
    end

    if ~returnYearly
        ll_year = [];
        years   = [];
    end
end

function [logL, ll_year, years] = loglik_income_fast(pre, params, returnYearly)
% LOGLIK_INCOME_FAST  Same structure as loglik_geo_fast, but splits edges
% by same-income-group (isIncome) vs. cross-income-group (~isIncome).
%   params.delta1  = δ_same    (same-income-group reinforcement weight)
%   params.delta2  = δ_cross   (cross-income-group reinforcement weight)
%   params.lambda1 = λ_same    (same-income-group exponent)
%   params.lambda2 = λ_cross   (cross-income-group exponent)
    if nargin < 3, returnYearly = false; end
    delta1 = params.delta1;   % δ_same
    delta2 = params.delta2;   % δ_cross

    if isfield(params,'lambda1') && isfield(params,'lambda2')
        expo_same  = params.lambda1;
        expo_cross = params.lambda2;
    else
        expo       = params.exponent;
        expo_same  = expo;
        expo_cross = expo;
    end

    N = pre.N;
    Y = pre.Y;
    years = pre.years;

    W = sparse(N,N);
    logL = 0;
    ll_year = zeros(Y,1);

    for yix = 1:Y
        baseEdges = pre.baseEdges(yix);
        if baseEdges == 0
            ll_year(yix) = 0;
            continue
        end

        all_lin  = pre.all_lin{yix};
        isIncome = pre.isIncome_mask{yix};   % same-income-group mask

        if isempty(all_lin)
            S = baseEdges;
        else
            w_all = full(W(all_lin));
            sumSame  = sum( (w_all(isIncome)).^expo_same );
            sumCross = sum( (w_all(~isIncome)).^expo_cross );
            S = baseEdges + delta1*sumSame + delta2*sumCross;
        end

        obs = pre.obs{yix};
        if ~isempty(obs.i)
            obs_lin = sub2ind([N,N], obs.i, obs.j);
            w_obs   = full(W(obs_lin));
            deltas  = delta2 * ones(size(obs.cnt));
            deltas(obs.isIncome) = delta1;

            expos   = expo_cross * ones(size(obs.cnt));
            expos(obs.isIncome) = expo_same;

            ll_y = pre.gammaln_const(yix) ...
                 + sum( obs.cnt .* log( 1 + deltas .* (w_obs.^expos) ) ) ...
                 - pre.n_y(yix) * log(S);

            ll_year(yix) = ll_y;
            logL = logL + ll_y;

            W = W + sparse(obs.i, obs.j, obs.cnt, N,N) ...
                  + sparse(obs.j, obs.i, obs.cnt, N,N);
        else
            ll_year(yix) = 0;
        end
    end

    if ~returnYearly
        ll_year = [];
        years   = [];
    end
end

%% ============================= SEARCH HELPERS WITH EDGE-ZOOM =============================
function [bestVal, best_delta, best_lambda, logL_single, delta_grid, exp_grid] = ...
    search_model2_with_zoom(pre, delta_grid, exp_grid, minDelta, maxDelta, minExp, maxExp)
    maxIters = 3; grow = 0.5;

    for it = 1:maxIters
        logL_single = zeros(numel(delta_grid), numel(exp_grid));
        for id = 1:numel(delta_grid)
            for ie = 1:numel(exp_grid)
                params = struct('delta1',delta_grid(id), ...
                                'delta2',delta_grid(id), ...
                                'exponent',exp_grid(ie));
                logL_single(id, ie) = loglik_twoDelta_fast(pre, params, false);
            end
        end

        [bestVal, bestIdx] = max(logL_single(:));
        [best_d_idx, best_e_idx] = ind2sub(size(logL_single), bestIdx);
        best_delta  = delta_grid(best_d_idx);
        best_lambda = exp_grid(best_e_idx);

        [delta_grid, changed1] = expand_grid_if_edge(delta_grid, best_delta, minDelta, maxDelta, grow);
        [exp_grid,   changed2] = expand_grid_if_edge(exp_grid,   best_lambda, minExp,   maxExp,   grow);
        if ~(changed1 || changed2), break; end
    end
end

function [bestVal, best_d1, best_d2, best_l1, best_l2, logL_surface, ...
          d1_grid, d2_grid, e1_grid, e2_grid] = ...
    search_model3b_with_zoom(pre, d1_grid, d2_grid, e1_grid, e2_grid, ...
                             minDelta, maxDelta, minExp, maxExp)
    maxIters = 3; grow = 0.5;

    for it = 1:maxIters
        nD1 = numel(d1_grid); nD2 = numel(d2_grid);
        nE1 = numel(e1_grid); nE2 = numel(e2_grid);

        logL_four = nan(nD1, nD2, nE1, nE2);
        for i1 = 1:nD1
            for i2 = 1:nD2
                for ie1 = 1:nE1
                    for ie2 = 1:nE2
                        params = struct('delta1', d1_grid(i1), ...
                                        'delta2', d2_grid(i2), ...
                                        'lambda1',e1_grid(ie1), ...
                                        'lambda2',e2_grid(ie2));
                        logL_four(i1, i2, ie1, ie2) = loglik_twoDelta_fast(pre, params, false);
                    end
                end
            end
        end

        [bestVal, bestIdx] = max(logL_four(:));
        [bi1, bi2, bie1, bie2] = ind2sub(size(logL_four), bestIdx);
        best_d1 = d1_grid(bi1);
        best_d2 = d2_grid(bi2);
        best_l1 = e1_grid(bie1);
        best_l2 = e2_grid(bie2);
        logL_surface = logL_four(:, :, bie1, bie2);

        [d1_grid, c1] = expand_grid_if_edge(d1_grid, best_d1, minDelta, maxDelta, grow);
        [d2_grid, c2] = expand_grid_if_edge(d2_grid, best_d2, minDelta, maxDelta, grow);
        [e1_grid, c3] = expand_grid_if_edge(e1_grid, best_l1, minExp, maxExp, grow);
        [e2_grid, c4] = expand_grid_if_edge(e2_grid, best_l2, minExp, maxExp, grow);
        if ~(c1 || c2 || c3 || c4), break; end
    end
end

function [bestVal, best_d1, best_d2, best_l1, best_l2, logL_surface, ...
          d1_grid, d2_grid, e1_grid, e2_grid] = ...
    search_model4_geo_with_zoom(pre, d1_grid, d2_grid, e1_grid, e2_grid, ...
                                minDelta, maxDelta, minExp, maxExp)
% Identical to search_model3b_with_zoom but calls loglik_geo_fast
% (same-continent vs cross-continent grouping).
    maxIters = 3; grow = 0.5;

    for it = 1:maxIters
        nD1 = numel(d1_grid); nD2 = numel(d2_grid);
        nE1 = numel(e1_grid); nE2 = numel(e2_grid);

        logL_four = nan(nD1, nD2, nE1, nE2);
        for i1 = 1:nD1
            for i2 = 1:nD2
                for ie1 = 1:nE1
                    for ie2 = 1:nE2
                        params = struct('delta1', d1_grid(i1), ...
                                        'delta2', d2_grid(i2), ...
                                        'lambda1',e1_grid(ie1), ...
                                        'lambda2',e2_grid(ie2));
                        logL_four(i1, i2, ie1, ie2) = loglik_geo_fast(pre, params, false);
                    end
                end
            end
        end

        [bestVal, bestIdx] = max(logL_four(:));
        [bi1, bi2, bie1, bie2] = ind2sub(size(logL_four), bestIdx);
        best_d1 = d1_grid(bi1);
        best_d2 = d2_grid(bi2);
        best_l1 = e1_grid(bie1);
        best_l2 = e2_grid(bie2);
        logL_surface = logL_four(:, :, bie1, bie2);

        [d1_grid, c1] = expand_grid_if_edge(d1_grid, best_d1, minDelta, maxDelta, grow);
        [d2_grid, c2] = expand_grid_if_edge(d2_grid, best_d2, minDelta, maxDelta, grow);
        [e1_grid, c3] = expand_grid_if_edge(e1_grid, best_l1, minExp, maxExp, grow);
        [e2_grid, c4] = expand_grid_if_edge(e2_grid, best_l2, minExp, maxExp, grow);
        if ~(c1 || c2 || c3 || c4), break; end
    end
end

function [bestVal, best_d1, best_d2, best_l1, best_l2, logL_surface, ...
          d1_grid, d2_grid, e1_grid, e2_grid] = ...
    search_model5_income_with_zoom(pre, d1_grid, d2_grid, e1_grid, e2_grid, ...
                                   minDelta, maxDelta, minExp, maxExp)
% Identical to search_model4_geo_with_zoom but calls loglik_income_fast
% (same-income-group vs cross-income-group grouping).
    maxIters = 3; grow = 0.5;

    for it = 1:maxIters
        nD1 = numel(d1_grid); nD2 = numel(d2_grid);
        nE1 = numel(e1_grid); nE2 = numel(e2_grid);

        logL_four = nan(nD1, nD2, nE1, nE2);
        for i1 = 1:nD1
            for i2 = 1:nD2
                for ie1 = 1:nE1
                    for ie2 = 1:nE2
                        params = struct('delta1', d1_grid(i1), ...
                                        'delta2', d2_grid(i2), ...
                                        'lambda1',e1_grid(ie1), ...
                                        'lambda2',e2_grid(ie2));
                        logL_four(i1, i2, ie1, ie2) = loglik_income_fast(pre, params, false);
                    end
                end
            end
        end

        [bestVal, bestIdx] = max(logL_four(:));
        [bi1, bi2, bie1, bie2] = ind2sub(size(logL_four), bestIdx);
        best_d1 = d1_grid(bi1);
        best_d2 = d2_grid(bi2);
        best_l1 = e1_grid(bie1);
        best_l2 = e2_grid(bie2);
        logL_surface = logL_four(:, :, bie1, bie2);

        [d1_grid, c1] = expand_grid_if_edge(d1_grid, best_d1, minDelta, maxDelta, grow);
        [d2_grid, c2] = expand_grid_if_edge(d2_grid, best_d2, minDelta, maxDelta, grow);
        [e1_grid, c3] = expand_grid_if_edge(e1_grid, best_l1, minExp, maxExp, grow);
        [e2_grid, c4] = expand_grid_if_edge(e2_grid, best_l2, minExp, maxExp, grow);
        if ~(c1 || c2 || c3 || c4), break; end
    end
end

function [g, changed] = expand_grid_if_edge(g, best_val, min_limit, max_limit, grow_frac)
    n = numel(g); changed = false;
    if n < 2, return; end
    span = g(end) - g(1);
    if best_val == g(1)
        new_min = max(min_limit, g(1) - grow_frac*span);
        new_max = g(end);
        if new_min < g(1)
            g = linspace(new_min, new_max, n);
            changed = true;
        end
    elseif best_val == g(end)
        new_min = g(1);
        new_max = min(max_limit, g(end) + grow_frac*span);
        if new_max > g(end)
            g = linspace(new_min, new_max, n);
            changed = true;
        end
    end
end

%% =========================== BASIC HELPERS ===========================
function [papers, id2name, authorDict, keptIdx, Year_sorted] = local_buildPapers(Author_wp, Year_wp)
    n = numel(Author_wp);
    assert(n == numel(Year_wp), 'Author_wp and Year_wp must match');

    splitAuthors = cell(n,1);
    keep = false(n,1);
    for i = 1:n
        parts = strtrim(strsplit(Author_wp{i}, ','));
        parts = parts(~cellfun(@isempty, parts));
        parts = cellfun(@normalizePartyName, parts, 'uni', false);
        splitAuthors{i} = parts;
        keep(i) = numel(parts) >= 2;
    end
    keptIdx      = find(keep);
    Author_wp    = Author_wp(keep);
    Year_wp      = Year_wp(keep);
    splitAuthors = splitAuthors(keep);

    if isempty(Author_wp)
        papers = {}; id2name = {}; authorDict = containers.Map('KeyType','char','ValueType','double');
        Year_sorted = [];
        return;
    end

    allAuthors  = [splitAuthors{:}];
    uniqueNames = unique(allAuthors, 'stable');
    ids         = num2cell(1:numel(uniqueNames));
    authorDict  = containers.Map(uniqueNames, ids);
    id2name     = uniqueNames;

    m = numel(Author_wp);
    rowIDs = cell(m,1);
    for i = 1:m
        names = splitAuthors{i};
        rowIDs{i} = cellfun(@(nm) authorDict(nm), names);
    end

    [Year_sorted, idx] = sort(Year_wp);
    papers = rowIDs(idx);
end

function yearsById = local_eligibilityYearById(id2name, mapObj)
    if ~(isa(mapObj,'containers.Map'))
        error('eligibility map must be containers.Map');
    end
    yearsById = inf(numel(id2name),1);
    for id = 1:numel(id2name)
        nm = normalizePartyName(id2name{id});
        if isKey(mapObj, nm)
            yearsById(id) = mapObj(nm);
        end
    end
end

function [firstIdx, runLen] = firstIndicesOfGroups(v)
    if isempty(v)
        firstIdx = [];
        runLen   = [];
        return;
    end
    d = [true; diff(v(:))~=0];
    firstIdx = find(d);
    nxt = [firstIdx(2:end)-1; numel(v)];
    runLen = nxt - firstIdx + 1;
end

function nm = normalizePartyName(nm)
    nm = strtrim(nm);
    nm = regexprep(nm, '\s+', ' ');
    nm = strrep(nm, 'T√ºrkiye', 'Türkiye');
    nm = strrep(nm, 'TÃ¼rkiye', 'Türkiye');
    nm = strrep(nm, 'T&uuml;rkiye', 'Türkiye');
    nm = regexprep(nm, '\bTurkiye\b', 'Türkiye', 'ignorecase');
    nm = regexprep(nm, '\bTurkey\b',  'Türkiye', 'ignorecase');

    if any(strcmpi(nm, {'USA','US','U.S.','United States of America'})), nm = 'United States'; end
    if any(strcmpi(nm, {'UK','U.K.','Great Britain'})),                   nm = 'United Kingdom'; end
    if any(strcmpi(nm, {'Russia','USSR','Soviet Union'})),                nm = 'Russian Federation'; end
    if any(strcmpi(nm, {'EEC','EU','European Economic Community'})),      nm = 'European Union'; end
    if any(strcmpi(nm, {'Republic of Korea','South Korea'})),             nm = 'Korea (ROK)'; end
    if strcmpi(nm,'Czech Republic'), nm = 'Czechia'; end
    if any(strcmpi(nm, {'CCALMR','Commission for the Conservation of Antarctic Marine Living Resources'}))
        nm = 'CCAMLR';
    end
    if strcmpi(nm,'Scientific Committee on Antarctic Research'), nm = 'SCAR'; end
end

function out = ifelse(cond, a, b)
    if cond, out = a; else, out = b; end
end

function cmap = local_build_continentMap(dataset)
% Construct the continent map for a given dataset (used as fallback).
    switch upper(dataset)
        case 'ATCM'
            cmap = containers.Map( ...
                {'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','China', ...
                 'Colombia','Czechia','Ecuador','Finland','France','Germany','Greece','India', ...
                 'Italy','Japan','Korea (ROK)','Malaysia','Monaco','Netherlands','New Zealand','Norway', ...
                 'Peru','Poland','Romania','Russian Federation','San Marino','Saudi Arabia','Slovakia','Slovenia', ...
                 'South Africa','Spain','Sweden','Switzerland','Türkiye','Ukraine','United Kingdom', ...
                 'United States','Uruguay','Venezuela', ...
                 'SCAR','COMNAP','CCAMLR','IPY-IPO','IHO','IAATO','WMO','ASOC','Portugal','Estonia'}, ...
                {'South America','Oceania','Europe','South America','Europe','North America','South America','Asia', ...
                 'South America','Europe','South America','Europe','Europe','Europe','Europe','Asia', ...
                 'Europe','Asia','Asia','Asia','Europe','Europe','Oceania','Europe', ...
                 'South America','Europe','Europe','Europe','Europe','Asia','Europe','Europe', ...
                 'Africa','Europe','Europe','Europe','Europe','Europe','Europe', ...
                 'North America','South America','South America', ...
                 'International','International','International','International','International','International','International','International','Europe','Europe'});
        case 'CCAMLR'
            cmap = containers.Map( ...
                {'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','European Union', ...
                 'Finland','France','Germany','Greece','India','Italy','Japan','Namibia','Netherlands', ...
                 'New Zealand','Norway','Peru','Poland','Korea (ROK)','Russian Federation', ...
                 'South Africa','Spain','Sweden','Ukraine','United Kingdom','United States','Uruguay','Vanuatu','China'}, ...
                {'South America','Oceania','Europe','South America','Europe','North America','South America','Europe', ...
                 'Europe','Europe','Europe','Europe','Asia','Europe','Asia','Africa','Europe', ...
                 'Oceania','Europe','South America','Europe','Asia','Europe', ...
                 'Africa','Europe','Europe','Europe','Europe','North America','South America','Oceania','Asia'});
        otherwise
            error('Unknown dataset "%s"', dataset);
    end
end

function imap = local_build_incomeClassMap(dataset)
% Construct the income classification map for a given dataset (used as fallback).
% World Bank FY2025 classification: 'High' = High-income; 'Low' = non-High-income.
    switch upper(dataset)
        case 'ATCM'
            imap = containers.Map( ...
                {'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','China', ...
                 'Colombia','Czechia','Ecuador','Finland','France','Germany','Greece','India', ...
                 'Italy','Japan','Korea (ROK)','Malaysia','Monaco','Netherlands','New Zealand','Norway', ...
                 'Peru','Poland','Romania','Russian Federation','San Marino','Saudi Arabia','Slovakia','Slovenia', ...
                 'South Africa','Spain','Sweden','Switzerland','Türkiye','Ukraine','United Kingdom', ...
                 'United States','Uruguay','Venezuela', ...
                 'SCAR','COMNAP','CCAMLR','IPY-IPO','IHO','IAATO','WMO','ASOC','Portugal','Estonia'}, ...
                {'Low','High','High','Low','Low','High','High','Low', ...
                 'Low','High','Low','High','High','High','High','Low', ...
                 'High','High','High','Low','High','High','High','High', ...
                 'Low','High','High','Low','High','High','High','High', ...
                 'Low','High','High','High','Low','Low','High', ...
                 'High','High','Low', ...
                 '__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','__UNKNOWN__','High','High'});
        case 'CCAMLR'
            imap = containers.Map( ...
                {'Argentina','Australia','Belgium','Brazil','Bulgaria','Canada','Chile','European Union', ...
                 'Finland','France','Germany','Greece','India','Italy','Japan','Namibia','Netherlands', ...
                 'New Zealand','Norway','Peru','Poland','Korea (ROK)','Russian Federation', ...
                 'South Africa','Spain','Sweden','Ukraine','United Kingdom','United States','Uruguay','Vanuatu','China'}, ...
                {'Low','High','High','Low','Low','High','High','__UNKNOWN__', ...
                 'High','High','High','High','Low','High','High','Low','High', ...
                 'High','High','Low','High','High','Low', ...
                 'Low','High','High','Low','High','High','High','Low','Low'});
        otherwise
            error('Unknown dataset "%s"', dataset);
    end
end

%% ============================= CI HELPERS =============================
function [ci, info] = wald_ci_model1(pre, d_hat)
    theta_hat = log(d_hat);
    f = @(th) loglik_twoDelta_fast(pre, ...
        struct('delta1',exp(th(1)),'delta2',exp(th(1)),'exponent',1), false);

    [H, ok] = num_hessian_cd(f, theta_hat);
    if ~ok
        warning('Hessian not negative definite for Model 1; using pseudo-inverse.');
    end
    Sigma = -pseudoinverse_pd(H);

    se_theta = sqrt(Sigma(1,1));
    z = 1.95996398454005;

    ci_theta = [theta_hat - z*se_theta, theta_hat + z*se_theta];
    ci       = exp(ci_theta);

    info.H     = H;
    info.Sigma = Sigma;
end

function [ci, info] = wald_ci_model2(pre, d_hat, e_hat)
    theta_hat = [log(d_hat); log(e_hat)];
    f = @(th) loglik_twoDelta_fast(pre, ...
        struct('delta1',exp(th(1)),'delta2',exp(th(1)),'exponent',exp(th(2))), false);

    [H, ok] = num_hessian_cd(f, theta_hat);
    if ~ok
        warning('Hessian not negative definite for Model 2; using pinv.');
    end
    Sigma = -pseudoinverse_pd(H);
    se = sqrt(diag(Sigma));
    z = 1.95996398454005;

    ci.delta  = exp([theta_hat(1) - z*se(1), theta_hat(1) + z*se(1)]);
    ci.lambda = exp([theta_hat(2) - z*se(2), theta_hat(2) + z*se(2)]);

    info.H     = H;
    info.Sigma = Sigma;
end

function [ci, info] = wald_ci_model3b(pre, d1_hat, d2_hat, e1_hat, e2_hat)
    theta_hat = [log(d1_hat); log(d2_hat); log(e1_hat); log(e2_hat)];
    f = @(th) loglik_twoDelta_fast(pre, ...
        struct('delta1',exp(th(1)), 'delta2',exp(th(2)), ...
               'lambda1',exp(th(3)),'lambda2',exp(th(4))), false);

    [H, ok] = num_hessian_cd(f, theta_hat);
    if  ok==0
        warning('Hessian not negative definite for Model 3b; using pinv.');
    end
    Sigma = -pseudoinverse_pd(H);
    se = sqrt(diag(Sigma));
    z = 1.95996398454005;

    ci.delta1  = exp([theta_hat(1) - z*se(1), theta_hat(1) + z*se(1)]);
    ci.delta2  = exp([theta_hat(2) - z*se(2), theta_hat(2) + z*se(2)]);
    ci.lambda1 = exp([theta_hat(3) - z*se(3), theta_hat(3) + z*se(3)]);
    ci.lambda2 = exp([theta_hat(4) - z*se(4), theta_hat(4) + z*se(4)]);

    info.H     = H;
    info.Sigma = Sigma;
end

function [ci, info] = wald_ci_model4_geo(pre, d1_hat, d2_hat, e1_hat, e2_hat)
% Wald CIs for Model 4 (geographic), using loglik_geo_fast.
    theta_hat = [log(d1_hat); log(d2_hat); log(e1_hat); log(e2_hat)];
    f = @(th) loglik_geo_fast(pre, ...
        struct('delta1',exp(th(1)), 'delta2',exp(th(2)), ...
               'lambda1',exp(th(3)),'lambda2',exp(th(4))), false);

    [H, ok] = num_hessian_cd(f, theta_hat);
    if  ok==0
        warning('Hessian not negative definite for Model 4 (Geo); using pinv.');
    end
    Sigma = -pseudoinverse_pd(H);
    se = sqrt(diag(Sigma));
    z = 1.95996398454005;

    ci.delta1  = exp([theta_hat(1) - z*se(1), theta_hat(1) + z*se(1)]);
    ci.delta2  = exp([theta_hat(2) - z*se(2), theta_hat(2) + z*se(2)]);
    ci.lambda1 = exp([theta_hat(3) - z*se(3), theta_hat(3) + z*se(3)]);
    ci.lambda2 = exp([theta_hat(4) - z*se(4), theta_hat(4) + z*se(4)]);

    info.H     = H;
    info.Sigma = Sigma;
end

function [ci, info] = wald_ci_model5_income(pre, d1_hat, d2_hat, e1_hat, e2_hat)
% Wald CIs for Model 5 (income classification), using loglik_income_fast.
    theta_hat = [log(d1_hat); log(d2_hat); log(e1_hat); log(e2_hat)];
    f = @(th) loglik_income_fast(pre, ...
        struct('delta1',exp(th(1)), 'delta2',exp(th(2)), ...
               'lambda1',exp(th(3)),'lambda2',exp(th(4))), false);

    [H, ok] = num_hessian_cd(f, theta_hat);
    if  ok==0
        warning('Hessian not negative definite for Model 5 (Income); using pinv.');
    end
    Sigma = -pseudoinverse_pd(H);
    se = sqrt(diag(Sigma));
    z = 1.95996398454005;

    ci.delta1  = exp([theta_hat(1) - z*se(1), theta_hat(1) + z*se(1)]);
    ci.delta2  = exp([theta_hat(2) - z*se(2), theta_hat(2) + z*se(2)]);
    ci.lambda1 = exp([theta_hat(3) - z*se(3), theta_hat(3) + z*se(3)]);
    ci.lambda2 = exp([theta_hat(4) - z*se(4), theta_hat(4) + z*se(4)]);

    info.H     = H;
    info.Sigma = Sigma;
end

function [H, ok] = num_hessian_cd(f, x)
    p = numel(x); 
    h = 1e-4;
    fx = f(x);
    H  = zeros(p,p);

    for i = 1:p
        ei = zeros(p,1); ei(i) = 1;
        f_plus  = f(x + h*ei);
        f_minus = f(x - h*ei);
        H(i,i)  = (f_plus - 2*fx + f_minus)/(h*h);
    end

    for i = 1:p
        ei = zeros(p,1); ei(i) = 1;
        for j = i+1:p
            ej = zeros(p,1); ej(j) = 1;
            f_pp = f(x + h*ei + h*ej);
            f_pm = f(x + h*ei - h*ej);
            f_mp = f(x - h*ei + h*ej);
            f_mm = f(x - h*ei - h*ej);
            H(i,j) = (f_pp - f_pm - f_mp + f_mm)/(4*h*h);
            H(j,i) = H(i,j);
        end
    end

    H = (H + H.')/2;
    eigsH = eig(-H);
    ok = all(eigsH > 1e-8);
end

function S = pseudoinverse_pd(H)
    [V,D] = eig((H+H.')/2);
    d = diag(D);
    d_abs = abs(d);
    d(d_abs < 1e-10) = -1e-10;
    S = V * diag(1./d) * V.';
end

function ci = profile_ci_model2(pre, d_hat, e_hat, minDelta, maxDelta, minExp, maxExp, dLL)
    nd = 121; ne = 121;
    d_grid = linspace(minDelta, maxDelta, nd);
    e_grid = linspace(minExp,   maxExp,   ne);

    L = zeros(nd, ne);
    for id = 1:nd
        for ie = 1:ne
            params = struct('delta1', d_grid(id), 'delta2', d_grid(id), 'exponent', e_grid(ie));
            L(id, ie) = loglik_twoDelta_fast(pre, params, false);
        end
    end
    Lmax = max(L(:));

    L_prof_delta  = max(L, [], 2);
    L_prof_lambda = max(L, [], 1)';

    ci.delta  = bracket_from_profile(d_grid, L_prof_delta,  Lmax - dLL);
    ci.lambda = bracket_from_profile(e_grid, L_prof_lambda, Lmax - dLL);
end

function ci = bracket_from_profile(grid, Lprof, thresh)
    above = (Lprof >= thresh);
    if ~any(above)
        ci = [NaN, NaN];
        return;
    end
    i1 = find(diff([false; above]) == 1, 1, 'first');
    if i1 > 1
        x0 = grid(i1-1); x1 = grid(i1);
        y0 = Lprof(i1-1); y1 = Lprof(i1);
        ci_lo = interp1([y0 y1], [x0 x1], thresh, 'linear','extrap');
    else
        ci_lo = grid(1);
    end

    i2 = find(diff([above; false]) == -1, 1, 'last');
    if i2 < numel(grid)
        x0 = grid(i2); x1 = grid(i2+1);
        y0 = Lprof(i2); y1 = Lprof(i2+1);
        ci_hi = interp1([y0 y1], [x0 x1], thresh, 'linear','extrap');
    else
        ci_hi = grid(end);
    end
    ci = [ci_lo, ci_hi];
end
%% ==================== ECDF ENVELOPE PANELS (BEST AIC MODEL) ====================
function plot_ecdf_two_delta_both(R, seed)
    % Plot ECDF envelopes for the *best AIC* model (per dataset).
    % Uses R simulated networks per dataset.
    if nargin < 1 || isempty(R),    R = 1000;     end
    if nargin < 2 || isempty(seed), seed = 12345; end
    rng(seed, 'twister');

    datasets = {'ATCM','CCAMLR'};

    f = figure('Color','w','Position',[100 100 1200 430]); clf
    set(f,'Renderer','painters');   % vector-friendly

    for d = 1:2
        ds = datasets{d};
        S  = load(['Fitting_results_' ds]);   % must exist

        % Build continentMap if missing from older save file
        if ~isfield(S,'continentMap')
            S.continentMap = local_build_continentMap(ds);
        end

        % Ensure 'pre' exists and is fresh enough for all current models.
        % Older Fitting_results_*.mat files can contain a pre struct without
        % isGeo_mask or isIncome_mask.
        if ~isfield(S,'pre') || isempty(S.pre) || ...
           ~isfield(S.pre, 'isGeo_mask') || ~isfield(S.pre, 'id2name') || ...
           ~isfield(S.pre, 'isIncome_mask')
            % Construct incomeClassMap if missing
            if ~isfield(S,'incomeClassMap')
                S.incomeClassMap = local_build_incomeClassMap(ds);
            end
            S.pre = build_precomputed_dataset_fast( ...
                S.Author_wp, S.Year_wp, S.eligibilityYearMap, S.originalYear, S.continentMap, S.incomeClassMap);
        end

        % ---------- 1. Identify best AIC model globally ----------
        % This block must include the same model set as the main AIC table.

        % Model 0: Null
        null_params = struct('delta1',0,'delta2',0,'exponent',1);
        LL0 = loglik_twoDelta_fast(S.pre, null_params, false);
        k0  = 0;

        % Model 1: Linear (single delta, exponent = 1)
        LL1 = S.logL_lin_max;
        k1  = 1;

        % Model 2: single delta + lambda (nonlinear)
        LL2 = S.bestVal_single;
        k2  = 2;

        % Model 3b: two delta + two lambda
        LL3 = S.bestVal_two4D;
        k3  = 4;

        % Model 4: geographic (same/cross continent)
        if isfield(S,'bestVal_geo4D')
            LL4 = S.bestVal_geo4D;
        else
            % Older save file: fit Model 4 on the fly
            warning('%s: bestVal_geo4D missing from saved results; fitting Model 4 now.', ds);
            switch upper(ds)
                case 'ATCM'
                    d1g4 = linspace(1,4,20); d2g4 = d1g4; e1g4 = linspace(0.5,1,20); e2g4 = e1g4;
                    [LL4, S.best_delta_same, S.best_delta_cross, S.best_lambda_same, S.best_lambda_cross] = ...
                        search_model4_geo_with_zoom(S.pre, d1g4, d2g4, e1g4, e2g4, 1.0, 4.0, 0.1, 2.0);
                case 'CCAMLR'
                    d1g4 = linspace(2.0,7.0,20); d2g4 = d1g4; e1g4 = linspace(0.25,1.25,20); e2g4 = e1g4;
                    [LL4, S.best_delta_same, S.best_delta_cross, S.best_lambda_same, S.best_lambda_cross] = ...
                        search_model4_geo_with_zoom(S.pre, d1g4, d2g4, e1g4, e2g4, 2.0, 10.0, 0.1, 2.0);
            end
        end
        k4  = 4;

        % Model 5: Income classification (same-income-group vs cross-income-group)
        if isfield(S,'bestVal_inc4D') && isfield(S,'best_delta_same_inc') && ...
           isfield(S,'best_delta_cross_inc') && isfield(S,'best_lambda_same_inc') && ...
           isfield(S,'best_lambda_cross_inc')
            LL5 = S.bestVal_inc4D;
        else
            warning('%s: bestVal_inc4D missing from saved results; fitting Model 5 now.', ds);
            switch upper(ds)
                case 'ATCM'
                    d1g5 = linspace(1,4,20); d2g5 = d1g5; e1g5 = linspace(0.5,1,20); e2g5 = e1g5;
                    [LL5, S.best_delta_same_inc, S.best_delta_cross_inc, ...
                        S.best_lambda_same_inc, S.best_lambda_cross_inc] = ...
                        search_model5_income_with_zoom(S.pre, d1g5, d2g5, e1g5, e2g5, 1.0, 4.0, 0.1, 2.0);
                case 'CCAMLR'
                    d1g5 = linspace(2.0,7.0,20); d2g5 = d1g5; e1g5 = linspace(0.25,1.25,20); e2g5 = e1g5;
                    [LL5, S.best_delta_same_inc, S.best_delta_cross_inc, ...
                        S.best_lambda_same_inc, S.best_lambda_cross_inc] = ...
                        search_model5_income_with_zoom(S.pre, d1g5, d2g5, e1g5, e2g5, 2.0, 10.0, 0.1, 2.0);
            end
        end
        k5  = 4;

        AIC  = [2*k0 - 2*LL0, ...
                2*k1 - 2*LL1, ...
                2*k2 - 2*LL2, ...
                2*k3 - 2*LL3, ...
                2*k4 - 2*LL4, ...
                2*k5 - 2*LL5];
        dAIC = AIC - min(AIC);
        w    = exp(-0.5*dAIC);
        w    = w / sum(w);

        [~, idxBest] = min(AIC);

        labelsConsole = { ...
            'Null', ...
            'Linear', ...
            'Single (delta + lambda)', ...
            'Two delta + two lambda', ...
            'Geo (same/cross continent)', ...
            'Income (same/cross)'};

        labelsLatex = { ...
            'Null', ...
            'Linear', ...
            'Single $\delta + \lambda$', ...
            'Two $\delta$ + two $\lambda$', ...
            'Geo (same/cross)', ...
            'Income (same/cross)'};

        bestLabelLatex = labelsLatex{idxBest};
        useGeoSim = false;   % flag: use geo-based simulation
        useIncSim = false;   % flag: use income-based simulation

        % Pack parameters of the best-AIC model for simulation
        switch idxBest
            case 1  % Null
                params = struct('delta1',0, 'delta2',0, 'exponent',1);

            case 2  % Linear
                delta_hat = S.delta1_grid(S.idx_lin_max);
                params = struct('delta1',delta_hat, ...
                                'delta2',delta_hat, ...
                                'exponent',1);

            case 3  % Single delta + lambda
                params = struct('delta1',S.best_delta_eq, ...
                                'delta2',S.best_delta_eq, ...
                                'exponent',S.best_exponent_single);

            case 4  % Two delta + two lambda
                params = struct('delta1',S.best_delta1, ...
                                'delta2',S.best_delta2, ...
                                'lambda1',S.best_lambda1_two, ...
                                'lambda2',S.best_lambda2_two);

            case 5  % Geo (same/cross continent)
                params = struct('delta1',S.best_delta_same, ...
                                'delta2',S.best_delta_cross, ...
                                'lambda1',S.best_lambda_same, ...
                                'lambda2',S.best_lambda_cross);
                useGeoSim = true;

            case 6  % Income (same/cross)
                params = struct('delta1',S.best_delta_same_inc, ...
                                'delta2',S.best_delta_cross_inc, ...
                                'lambda1',S.best_lambda_same_inc, ...
                                'lambda2',S.best_lambda_cross_inc);
                useIncSim = true;
        end

        fprintf('%s: best AIC model = %s (weight = %.3f)\n', ...
                ds, labelsConsole{idxBest}, w(idxBest));

        % ---------- 2. Empirical edge-weight ECDF ----------
        w_obs = compute_final_weights_from_pre(S.pre);    % upper-tri positive weights
        [x_obs, F_obs] = ecdf_discrete(w_obs);

        xmin = max(1, min(w_obs));
        xmax = max(w_obs);
        x_grid = logspace(log10(xmin), log10(xmax), 80);

        % ---------- 3. Simulation envelopes from best model ----------
        if useGeoSim
            [F_lo, F_hi] = ecdf_envelope_geo(S.pre, params, R, x_grid);
        elseif useIncSim
            [F_lo, F_hi] = ecdf_envelope_income(S.pre, params, R, x_grid);
        else
            [F_lo, F_hi] = ecdf_envelope(S.pre, params, R, x_grid);
        end

        % Smooth envelope curves in log-x space
        xx  = logspace(log10(x_grid(1)), log10(x_grid(end)), 300);
        Flo = pchip(log10(x_grid), F_lo, log10(xx));
        Fhi = pchip(log10(x_grid), F_hi, log10(xx));

        % ---------- 4. Plot ----------
        subplot(1,2,d); hold on

        % Shaded envelope
        patch([xx fliplr(xx)], [Flo fliplr(Fhi)], [0.75 0.9 0.78], ...
              'EdgeColor','none', 'FaceAlpha', 1.0);

        % Envelope boundary curves
        plot(xx, Flo, '-', 'Color',[0.25 0.55 0.30], 'LineWidth',1.0);
        plot(xx, Fhi, '-', 'Color',[0.25 0.55 0.30], 'LineWidth',1.0);

        % Empirical ECDF (dots)
        plot(x_obs, F_obs, 'k.', 'MarkerSize', 12);

        set(gca, 'XScale','log');
        grid on; box on
        xlim([0.9, xmax*1.05]); 
        ylim([0 1]);

        xlabel('\textit{Edge weight}','Interpreter','latex');
        ylabel('$F(x)$','Interpreter','latex');
        set(gca,'TickLabelInterpreter','latex');
        set(gca,'XMinorGrid','on','YMinorGrid','on');

        panelLabels = {'(a) ATCM', '(b) CCAMLR'};
        title(panelLabels{d}, 'Interpreter','latex', 'FontSize',14);
    end

    % No sgtitle — model identification belongs in the caption
    
    % Force render before saving
    drawnow;
    
    % Save with fallback for older MATLAB versions
    try
        exportgraphics(f, 'fig_ecdf_bestAIC_panels.png', 'Resolution', 300);
        exportgraphics(f, 'fig_ecdf_bestAIC_panels.pdf', 'ContentType','vector');
        fprintf('Saved fig_ecdf_bestAIC_panels.pdf (exportgraphics)\n');
    catch
        print(f, '-dpdf', 'fig_ecdf_bestAIC_panels.pdf');
        print(f, '-dpng', '-r300', 'fig_ecdf_bestAIC_panels.png');
        fprintf('Saved fig_ecdf_bestAIC_panels.pdf (print fallback)\n');
    end
end
function w_vec = compute_final_weights_from_pre(pre)
    N = pre.N;
    W = sparse(N,N);
    for yix = 1:pre.Y
        obs = pre.obs{yix};
        if ~isempty(obs.i)
            W = W + sparse(obs.i, obs.j, obs.cnt, N,N) ...
                  + sparse(obs.j, obs.i, obs.cnt, N,N);
        end
    end
    w_vec = full(nonzeros(triu(W,1)));
end

function [x, F] = ecdf_discrete(w)
    w = sort(w(:));
    n = numel(w);
    [x, ~, ic] = unique(w, 'stable');
    step = accumarray(ic, 1) / n;
    F = cumsum(step);
end

function [F_lo, F_hi] = ecdf_envelope(pre, params, R, x_grid)
    K = numel(x_grid);
    F = zeros(R, K);

    usePar = license('test','Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));

    if usePar
        parfor r = 1:R
            W = simulate_counts(pre, params);
            w = full(nonzeros(triu(W,1)));
            F(r,:) = arrayfun(@(x) mean(w <= x), x_grid);
        end
    else
        for r = 1:R
            W = simulate_counts(pre, params);
            w = full(nonzeros(triu(W,1)));
            F(r,:) = arrayfun(@(x) mean(w <= x), x_grid);
        end
    end

    F_lo = quantile(F, 0.025, 1);
    F_hi = quantile(F, 0.975, 1);
end

function W = simulate_counts(pre, params)
    N = pre.N; Y = pre.Y;
    d1 = params.delta1; d2 = params.delta2;
    %l1 = params.lambda1; l2 = params.lambda2;

    if isfield(params,'lambda1') && isfield(params,'lambda2')
        l1 = params.lambda1;
        l2 = params.lambda2;
    else
        expo = params.exponent;
        l1   = expo;
        l2   = expo;
    end

    W = sparse(N,N);
    for yix = 1:Y
        n_y = pre.n_y(yix);
        K   = pre.baseEdges(yix);
        if n_y == 0 || K == 0, continue; end

        lin  = pre.all_lin{yix};
        isOO = pre.isOO_mask{yix};
        w    = full(W(lin));

        numer = ones(K,1);
        if any(isOO)
            numer(isOO)  = numer(isOO)  + d1 * (w(isOO).^l1);
        end
        if any(~isOO)
            numer(~isOO) = numer(~isOO) + d2 * (w(~isOO).^l2);
        end
        p = numer / sum(numer);

        c = multinomial_draw(n_y, p);
        [ri, rj] = ind2sub([N,N], lin);
        W = W + sparse(ri, rj, c, N,N) + sparse(rj, ri, c, N,N);
    end
end

function c = multinomial_draw(n, p)
    p = p(:); p = p / sum(p);
    if exist('mnrnd','file') == 2
        c = mnrnd(n, p')';
    else
        edges = [0; cumsum(p)];
        edges(end) = 1;
        r  = rand(n,1);
        counts = histcounts(r, edges);
        c = counts(:);
    end
end

function [F_lo, F_hi] = ecdf_envelope_geo(pre, params, R, x_grid)
% Geo-based envelope: simulate from geographic (same/cross) model.
    K = numel(x_grid);
    F = zeros(R, K);

    usePar = license('test','Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));

    if usePar
        parfor r = 1:R
            W = simulate_counts_geo(pre, params);
            w = full(nonzeros(triu(W,1)));
            F(r,:) = arrayfun(@(x) mean(w <= x), x_grid);
        end
    else
        for r = 1:R
            W = simulate_counts_geo(pre, params);
            w = full(nonzeros(triu(W,1)));
            F(r,:) = arrayfun(@(x) mean(w <= x), x_grid);
        end
    end

    F_lo = quantile(F, 0.025, 1);
    F_hi = quantile(F, 0.975, 1);
end

function W = simulate_counts_geo(pre, params)
% Simulate counts using geographic (same/cross continent) masks.
    N = pre.N; Y = pre.Y;
    d1 = params.delta1; d2 = params.delta2;

    if isfield(params,'lambda1') && isfield(params,'lambda2')
        l1 = params.lambda1;
        l2 = params.lambda2;
    else
        expo = params.exponent;
        l1   = expo;
        l2   = expo;
    end

    W = sparse(N,N);
    for yix = 1:Y
        n_y = pre.n_y(yix);
        K   = pre.baseEdges(yix);
        if n_y == 0 || K == 0, continue; end

        lin   = pre.all_lin{yix};
        isGeo = pre.isGeo_mask{yix};   % same-continent mask
        w     = full(W(lin));

        numer = ones(K,1);
        if any(isGeo)
            numer(isGeo)  = numer(isGeo)  + d1 * (w(isGeo).^l1);
        end
        if any(~isGeo)
            numer(~isGeo) = numer(~isGeo) + d2 * (w(~isGeo).^l2);
        end
        p = numer / sum(numer);

        c = multinomial_draw(n_y, p);
        [ri, rj] = ind2sub([N,N], lin);
        W = W + sparse(ri, rj, c, N,N) + sparse(rj, ri, c, N,N);
    end
end

function [F_lo, F_hi] = ecdf_envelope_income(pre, params, R, x_grid)
% Income-based envelope: simulate from income classification (same/cross) model.
    K = numel(x_grid);
    F = zeros(R, K);

    usePar = license('test','Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));

    if usePar
        parfor r = 1:R
            W = simulate_counts_income(pre, params);
            w = full(nonzeros(triu(W,1)));
            F(r,:) = arrayfun(@(x) mean(w <= x), x_grid);
        end
    else
        for r = 1:R
            W = simulate_counts_income(pre, params);
            w = full(nonzeros(triu(W,1)));
            F(r,:) = arrayfun(@(x) mean(w <= x), x_grid);
        end
    end

    F_lo = quantile(F, 0.025, 1);
    F_hi = quantile(F, 0.975, 1);
end

function W = simulate_counts_income(pre, params)
% Simulate counts using income-classification (same/cross income-group) masks.
    N = pre.N; Y = pre.Y;
    d1 = params.delta1; d2 = params.delta2;

    if isfield(params,'lambda1') && isfield(params,'lambda2')
        l1 = params.lambda1;
        l2 = params.lambda2;
    else
        expo = params.exponent;
        l1   = expo;
        l2   = expo;
    end

    W = sparse(N,N);
    for yix = 1:Y
        n_y = pre.n_y(yix);
        K   = pre.baseEdges(yix);
        if n_y == 0 || K == 0, continue; end

        lin      = pre.all_lin{yix};
        isIncome = pre.isIncome_mask{yix};   % same-income-group mask
        w        = full(W(lin));

        numer = ones(K,1);
        if any(isIncome)
            numer(isIncome)  = numer(isIncome)  + d1 * (w(isIncome).^l1);
        end
        if any(~isIncome)
            numer(~isIncome) = numer(~isIncome) + d2 * (w(~isIncome).^l2);
        end
        p = numer / sum(numer);

        c = multinomial_draw(n_y, p);
        [ri, rj] = ind2sub([N,N], lin);
        W = W + sparse(ri, rj, c, N,N) + sparse(rj, ri, c, N,N);
    end
end

function results = analyze_weight_distribution(pre, dataset)
% ANALYZE_WEIGHT_DISTRIBUTION
%   For the given forum (dataset) and precomputed structure PRE:
%     1) Fit the empirical tail CCDF P(W >= w) to a stretched exponential
%        P(W >= w) ≈ exp(-c_hat * w^k_hat).
%     2) Compute the logarithmic bound on W_max(m):
%           W_max(m) ≈ (log m / c_hat)^(1 / k_hat).
%     3) Plot:
%           - Probability density f_W(w)
%           - CCDF P(W >= w) with fitted curve
%           - W_max vs year with log bound
%           - W_max vs m (log–log) with log bound
%
%   INPUTS
%     pre     : struct from build_precomputed_dataset_fast
%     dataset : e.g. 'ATCM' or 'CCAMLR'
%
%   OUTPUT
%     results : struct with useful fields (see bottom)

    tag = upper(dataset);   % e.g. 'ATCM' or 'CCAMLR'

    % ---------- Build cumulative W by year; track m(t) and W_max(t) ----------
    N = pre.N;
    Y = pre.Y;
    W = sparse(N,N);
    m_series    = zeros(Y,1);   % active edges count (i<j with W>0) up to year y
    Wmax_series = zeros(Y,1);   % max edge weight up to year y

    for yix = 1:Y
        obs = pre.obs{yix};
        if ~isempty(obs.i)
            W = W + sparse(obs.i, obs.j, obs.cnt, N,N) ...
                  + sparse(obs.j, obs.i, obs.cnt, N,N);
        end
        U = triu(W,1);
        m_series(yix) = nnz(U);
        if m_series(yix) > 0
            Wmax_series(yix) = full(max(U(:)));
        else
            Wmax_series(yix) = 0;
        end
    end

    % ---------- Final edge-weight vector (upper triangle, positive weights) ----------
    w_vec = full(nonzeros(triu(W,1)));
    if isempty(w_vec)
        error('No active edges found for %s; check parsing/eligibility inputs.', tag);
    end

    %% ===================== 1. Probability density f_W(w) =====================
    f1 = figure('Color','w'); clf
    edges   = (0.5 : 1 : (max(w_vec)+0.5));
    centers = edges(1:end-1) + 0.5;
    dens    = histcounts(w_vec, edges, 'Normalization','pdf');

    bar(centers, dens, 1.0, ...
        'FaceColor',[0.20 0.50 0.80], ...
        'EdgeColor','none');
    grid on; box on
    xlabel('$w$ \textit{(total collaborations per pair)}', 'Interpreter','latex');
    ylabel('$f_W(w)$', 'Interpreter','latex');
    title(sprintf('%s: Edge-weight distribution', tag), 'Interpreter','latex');
    set(gca,'FontName','Times','FontSize',11, ...
            'TickLabelInterpreter','latex');
    set(f1, 'PaperPositionMode','auto');
    print(f1,'-dpdf', sprintf('%s_weight_density.pdf', tag));

    %% ===================== 2. Empirical CCDF P(W >= w) =====================
    uw   = unique(w_vec(:));                     % support values
    ccdf = arrayfun(@(x) mean(w_vec >= x), uw);  % P(W >= w)

    f2 = figure('Color','w'); clf
    loglog(uw, ccdf, 'ko', ...
           'MarkerFaceColor','k', ...
           'MarkerSize',4); hold on
    grid on; box on
    xlabel('$w$', 'Interpreter','latex');
    ylabel('$\Pr(W \ge w)$', 'Interpreter','latex');
    title(sprintf('%s: Empirical tail $\\Pr(W \\ge w)$', tag), ...
          'Interpreter','latex');
    set(gca,'FontName','Times','FontSize',11, ...
            'TickLabelInterpreter','latex');

    %% ===================== 3. Tail fit: P(W >= w) ~ exp(-c w^k) =====================
    % Heuristic tail threshold (adjust if desired)
    w_min   = max(5, prctile(w_vec,80));
    u_tail  = uw(uw >= w_min);
    cc_tail = arrayfun(@(x) mean(w_vec >= x), u_tail);

    mask    = (cc_tail > 0) & (cc_tail < 1);
    u_tail  = u_tail(mask);
    cc_tail = cc_tail(mask);

    if numel(u_tail) < 2
        warning('%s: insufficient tail points for reliable stretched-exponential fit.', tag);
        k_hat = NaN;
        c_hat = NaN;
        ccdf_fit = NaN(size(uw));
    else
        % Fit log(-log P(W >= w)) = k * log w + log c
        x = log(u_tail(:));
        y = log(-log(cc_tail(:)));
        p = polyfit(x, y, 1);           % y ≈ p(1)*x + p(2)
        k_hat = max(p(1), 1e-6);        % shape
        c_hat = exp(p(2));              % scale

        ccdf_fit = exp(-c_hat * (uw.^k_hat));
    end

    fprintf('\n%s tail fit (P(W >= w) ~ exp(-c w^k)):\n', tag);
    fprintf('  w_min = %g, tail n = %d\n', w_min, numel(u_tail));
    fprintf('  k_hat = %.3f, c_hat = %.3f (implied lambda = %.3f)\n', ...
            k_hat, c_hat, 1 - k_hat);

    % Overlay theoretical tail on CCDF plot
    if all(~isnan(ccdf_fit))
        loglog(uw, ccdf_fit, 'r--', 'LineWidth',1.8);
        legend({'Empirical $\Pr(W \ge w)$', ...
                'Fitted $\exp(-\hat{c}\,w^{\hat{k}})$'}, ...
               'Interpreter','latex', ...
               'Location','southwest','Box','off');
    end
    set(f2, 'PaperPositionMode','auto');
    print(f2,'-dpdf', sprintf('%s_weight_ccdf_with_fit.pdf', tag));

    %% ===================== 4. ECDF with theoretical CDF overlay =====================
    % P(W <= w) = 1 - P(W >= w) ~ 1 - exp(-c w^k)
    w_sorted = sort(w_vec);
    n = numel(w_sorted);
    ecdf_y = (1:n)/n;                         % F_hat(w) = P(W <= w)

    F_theory = @(x) 1 - exp(-c_hat * max(x,0).^k_hat);

    f3 = figure('Color','w'); clf
    stairs(w_sorted, ecdf_y, 'k-', 'LineWidth',1.2); hold on
    w_line = linspace(0, max(w_sorted), 500);
    if ~isnan(c_hat) && ~isnan(k_hat)
        plot(w_line, F_theory(w_line), 'r--', 'LineWidth',1.8);
    end
    grid on; box on
    xlim([0, max(w_sorted)]);
    xlabel('$w$', 'Interpreter','latex');
    ylabel('$F_W(w) = \Pr(W \le w)$', 'Interpreter','latex');
    legend({'Empirical ECDF', ...
            'Stretched-exponential fit'}, ...
           'Interpreter','latex', ...
           'Location','southeast','Box','off');
    title(sprintf('%s: Empirical CDF and stretched-exponential fit', tag), ...
          'Interpreter','latex');
    set(gca,'FontName','Times','FontSize',11, ...
            'TickLabelInterpreter','latex');
    set(f3, 'PaperPositionMode','auto');
    print(f3,'-dpdf', sprintf('%s_weight_ecdf_with_fit.pdf', tag));

    %% ===================== 5. Logarithmic bound on W_max(m) =====================
    % From P(W >= w) ~ exp(-c w^k), for m potential edges:
    %   P(W_max >= w) <= m * exp(-c w^k).
    % Setting m * exp(-c w^k) ~ 1 gives the log bound:
    %   W_max(m) ~ (log m / c)^(1/k).
    m_pos          = m_series;
    m_pos(m_pos<2) = NaN;                          % avoid log(0) / trivial phase

    W_bound = ((log(m_pos)./c_hat).^(1./k_hat));   % log bound curve for W_max(m)

    fprintf('%s log bound on W_{max}(m):  W_{max}(m) ~ (\\log m / %.3f)^{1/%.3f}\n', ...
            tag, c_hat, k_hat);

    %% ===================== 6. W_max vs Year (with log bound) =====================
    f4 = figure('Color','w'); clf
    plot(pre.years, Wmax_series, '-o', ...
         'LineWidth',1.4, ...
         'Color',[0.10 0.40 0.70], ...
         'MarkerSize',4, ...
         'MarkerFaceColor',[0.10 0.40 0.70]); hold on
    plot(pre.years, W_bound, '--', ...
         'LineWidth',2.0, ...
         'Color',[0.85 0.33 0.10]);
    grid on; box on
    xlabel('\textit{Year}', 'Interpreter','latex');
    ylabel('$W_{\max}$', 'Interpreter','latex');
    legend({'Observed $W_{\max}$', ...
            'Logarithmic bound $(\log m / \hat{c})^{1/\hat{k}}$'}, ...
           'Interpreter','latex', ...
           'Location','northwest','Box','off');
    title(sprintf('%s: Maximum edge weight vs.\ log bound', tag), ...
          'Interpreter','latex');
    set(gca,'FontName','Times','FontSize',11, ...
            'TickLabelInterpreter','latex');
    set(f4, 'PaperPositionMode','auto');
    print(f4,'-dpdf', sprintf('%s_Wmax_vs_year.pdf', tag));

    %% ===================== 7. W_max vs m (log–log, with log bound) =====================
    f5 = figure('Color','w'); clf
    loglog(max(m_series,1), max(Wmax_series,1), 'o', ...
           'MarkerFaceColor',[0.10 0.40 0.70], ...
           'MarkerEdgeColor','none', ...
           'MarkerSize',4); hold on
    loglog(max(m_series,1), max(W_bound,1), '--', ...
           'LineWidth',2.0, ...
           'Color',[0.85 0.33 0.10]);
    grid on; box on
    xlabel('$m = \#\ \text{active edges}$', 'Interpreter','latex');
    ylabel('$W_{\max}$', 'Interpreter','latex');
    legend({'Observed', 'Theoretical Estimate'}, ...
           'Interpreter','latex', ...
           'Location','northwest','Box','off');
    title(sprintf('%s: $W_{\max}$ vs.\ number of active edges ($m$)', tag), ...
          'Interpreter','latex');
    set(gca,'FontName','Times','FontSize',11, ...
            'TickLabelInterpreter','latex');
    set(f5, 'PaperPositionMode','auto');
    print(f5,'-dpdf', sprintf('%s_Wmax_vs_m.pdf', tag));

    %% ===================== 8. Console summary at final year =====================
    W_max_final   = max(w_vec);
    m_final       = m_series(end);
    W_bound_final = ((log(max(m_final,2))/c_hat)^(1/k_hat));
    fprintf('%s final year: m = %d,  W_max(obs) = %d,  W_max(bound) ≈ %.1f\n', ...
            tag, m_final, W_max_final, W_bound_final);

    %% ===================== 9. Pack outputs =====================
    results = struct();
    results.tag          = tag;
    results.w_vec        = w_vec;
    results.m_series     = m_series;
    results.Wmax_series  = Wmax_series;

    results.pdf.edges    = edges;
    results.pdf.centers  = centers;
    results.pdf.density  = dens;

    results.ccdf.w       = uw;
    results.ccdf.emp     = ccdf;
    results.ccdf.fit     = ccdf_fit;

    results.tailFit.w_min   = w_min;
    results.tailFit.u_tail  = u_tail;
    results.tailFit.cc_tail = cc_tail;
    results.tailFit.k_hat   = k_hat;
    results.tailFit.c_hat   = c_hat;

    results.logBound.m       = m_pos;
    results.logBound.W_bound = W_bound;
    results.logBound.k       = k_hat;
    results.logBound.c       = c_hat;
    results.logBound.final_m       = m_final;
    results.logBound.final_Wmax    = W_max_final;
    results.logBound.final_Wbound  = W_bound_final;

    results.figures.f_pdf    = f1;
    results.figures.f_ccdf   = f2;
    results.figures.f_ecdf   = f3;
    results.figures.f_W_year = f4;
    results.figures.f_W_m    = f5;
end


%% ========================= WINDOWED FIT (WITH 95% CIs) =========================
function win = fit_models_on_window(pre, dataset, y_lo, y_hi)
% FIT_MODELS_ON_WINDOW  Restrict PRE to years [y_lo,y_hi] and fit all models.
% Also computes 95% CIs (Wald) for Models 1/2/3b/4 and profile CIs for Model 2.
%
% Returns 'win' with:
%   .years, .LL*, .AIC*, .AIC_weights
%   .delta_lin_hat
%   .delta_hat, .lambda_hat
%   .delta1_hat, .delta2_hat, .lambda1_hat, .lambda2_hat
%   .delta_same_hat, .delta_cross_hat, .lambda_same_hat, .lambda_cross_hat
%   .ci.M1.delta               (Wald)
%   .ci.M2.delta, .ci.M2.lambda (Wald)
%   .ci.M2_profile.delta, .ci.M2_profile.lambda (Profile)
%   .ci.M3b.delta1, .ci.M3b.delta2, .ci.M3b.lambda1, .ci.M3b.lambda2 (Wald)
%   .ci.M4.delta1, .ci.M4.delta2, .ci.M4.lambda1, .ci.M4.lambda2 (Wald)
%   .grids.* (grids actually used after edge-zoom)

    tag  = upper(dataset);
    preW = slice_pre_by_year(pre, y_lo, y_hi);

    % ========= dataset-specific grids / bounds =========
    switch tag
        case 'ATCM'
            G = 40;
            delta1_grid = linspace(1, 4, G);     % Model 1
            delta_grid  = linspace(1, 4, round(G/2));
            exp_grid    = linspace(0.5, 1.0, round(G/2));
            d1_grid2    = linspace(1, 4, round(G/2));
            d2_grid2    = linspace(1, 4, round(G/2));
            e1_grid2    = linspace(0.5, 1.0, round(G/2));
            e2_grid2    = linspace(0.5, 1.0, round(G/2));
            % Model 4 grids (geographic)
            d1_grid4    = linspace(1, 4, round(G/2));
            d2_grid4    = linspace(1, 4, round(G/2));
            e1_grid4    = linspace(0.5, 1.0, round(G/2));
            e2_grid4    = linspace(0.5, 1.0, round(G/2));
            minDelta = 1.0;  maxDelta = 4.0;
            minExp   = 0.10; maxExp   = 2.00;   % for zoom / profiles

        case 'CCAMLR'
            G = 40;
            delta1_grid = linspace(1.5, 5.0, G); % Model 1
            delta_grid  = linspace(2.0, 7.0, round(G/2));
            exp_grid    = linspace(0.25, 1.25, round(G/2));
            d1_grid2    = linspace(2.0, 7.0, round(G/2));
            d2_grid2    = linspace(2.0, 7.0, round(G/2));
            e1_grid2    = linspace(0.25, 1.25, round(G/2));
            e2_grid2    = linspace(0.25, 1.25, round(G/2));
            % Model 4 grids (geographic)
            d1_grid4    = linspace(2.0, 7.0, round(G/2));
            d2_grid4    = linspace(2.0, 7.0, round(G/2));
            e1_grid4    = linspace(0.25, 1.25, round(G/2));
            e2_grid4    = linspace(0.25, 1.25, round(G/2));
            minDelta = 2.0;  maxDelta = 10.0;
            minExp   = 0.10; maxExp   = 2.00;   % allow some headroom in profiles

        otherwise
            error('Unknown dataset "%s"', dataset);
    end

    % ========= Model fitting =========
    % Model 0: Null
    LL0 = loglik_twoDelta_fast(preW, struct('delta1',0,'delta2',0,'exponent',1), false);

    % Model 1: Linear (single δ; exponent=1)
    logL_lin = zeros(numel(delta1_grid),1);
    for i = 1:numel(delta1_grid)
        params = struct('delta1', delta1_grid(i), 'delta2', delta1_grid(i), 'exponent', 1);
        logL_lin(i) = loglik_twoDelta_fast(preW, params, false);
    end
    [LL1, idx_lin_max] = max(logL_lin);
    delta_lin_hat = delta1_grid(idx_lin_max);

    % Model 2: single (δ, λ) with edge-zoom
    [LL2, delta_hat, lambda_hat, ~, delta_grid_used, exp_grid_used] = ...
        search_model2_with_zoom(preW, delta_grid, exp_grid, minDelta, maxDelta, minExp, maxExp);

    % Model 3b: (δ1,δ2,λ1,λ2) 4-D with edge-zoom
    [LL3b, d1_hat, d2_hat, l1_hat, l2_hat, ~, ...
        d1_grid_used, d2_grid_used, e1_grid_used, e2_grid_used] = ...
        search_model3b_with_zoom(preW, d1_grid2, d2_grid2, e1_grid2, e2_grid2, ...
                                 minDelta, maxDelta, minExp, maxExp);

    % Model 4: geographic (δ_same, δ_cross, λ_same, λ_cross) 4-D with edge-zoom
    [LL4, ds_hat, dx_hat, ls_hat, lx_hat, ~, ...
        d1_grid4_used, d2_grid4_used, e1_grid4_used, e2_grid4_used] = ...
        search_model4_geo_with_zoom(preW, d1_grid4, d2_grid4, e1_grid4, e2_grid4, ...
                                    minDelta, maxDelta, minExp, maxExp);

    % Model 5: income (δ_same_inc, δ_cross_inc, λ_same_inc, λ_cross_inc) 4-D with edge-zoom
    switch tag
        case 'ATCM'
            d1_grid5 = linspace(1, 4, round(G/2));
            d2_grid5 = linspace(1, 4, round(G/2));
            e1_grid5 = linspace(0.5, 1.0, round(G/2));
            e2_grid5 = linspace(0.5, 1.0, round(G/2));
        case 'CCAMLR'
            d1_grid5 = linspace(2.0, 7.0, round(G/2));
            d2_grid5 = linspace(2.0, 7.0, round(G/2));
            e1_grid5 = linspace(0.25, 1.25, round(G/2));
            e2_grid5 = linspace(0.25, 1.25, round(G/2));
    end
    [LL5, dsi_hat, dxi_hat, lsi_hat, lxi_hat, ~, ...
        d1_grid5_used, d2_grid5_used, e1_grid5_used, e2_grid5_used] = ...
        search_model5_income_with_zoom(preW, d1_grid5, d2_grid5, e1_grid5, e2_grid5, ...
                                       minDelta, maxDelta, minExp, maxExp);

    % ========= AICs & weights =========
    k = [0 1 2 4 4 4];                   % free params per model
    LL = [LL0, LL1, LL2, LL3b, LL4, LL5];
    AIC = 2*k - 2*LL;
    dAIC = AIC - min(AIC);
    wAIC = exp(-0.5*dAIC);  wAIC = wAIC / sum(wAIC);

    % ========= 95% CIs (Wald) & profile CIs (Model 2) =========
    chi2_95_1df = 3.84145882069412;
    dLL_thresh  = 0.5 * chi2_95_1df;

    % Model 1: δ (linear)
    [ci_M1_delta, info_M1] = wald_ci_model1(preW, delta_lin_hat); %#ok<NASGU>

    % Model 2: (δ, λ)  Wald
    [ci_M2_wald, info_M2] = wald_ci_model2(preW, delta_hat, lambda_hat); %#ok<NASGU>
    % Model 2: (δ, λ)  Profile-likelihood
    ci_M2_prof = profile_ci_model2(preW, delta_hat, lambda_hat, ...
                                   minDelta, maxDelta, minExp, maxExp, dLL_thresh);

    % Model 3b: (δ1, δ2, λ1, λ2)  Wald
    [ci_M3b_wald, info_M3b] = wald_ci_model3b(preW, d1_hat, d2_hat, l1_hat, l2_hat); %#ok<NASGU>

    % Model 4: (δ_same, δ_cross, λ_same, λ_cross) Wald
    [ci_M4_wald, info_M4] = wald_ci_model4_geo(preW, ds_hat, dx_hat, ls_hat, lx_hat); %#ok<NASGU>

    % Model 5: (δ_same_inc, δ_cross_inc, λ_same_inc, λ_cross_inc) Wald
    [ci_M5_wald, info_M5] = wald_ci_model5_income(preW, dsi_hat, dxi_hat, lsi_hat, lxi_hat); %#ok<NASGU>

    % ========= Console summary =========
    fprintf('\n=== %s | Window %d–%d | Likelihoods, AIC, MLEs ===\n', tag, y_lo, y_hi);
    fprintf('Model 0 (Null):            logL = %.6f,  AIC = %.6f\n', LL0, AIC(1));
    fprintf('Model 1 (Linear):          δ = %.6f | logL = %.6f, AIC = %.6f\n', delta_lin_hat, LL1, AIC(2));
    fprintf('Model 2 (δ+λ):             δ = %.6f, λ = %.6f | logL = %.6f, AIC = %.6f\n', ...
            delta_hat, lambda_hat, LL2, AIC(3));
    fprintf('Model 3b (δ1,δ2,λ1,λ2):    δ1 = %.6f, δ2 = %.6f, λ1 = %.6f, λ2 = %.6f | logL = %.6f, AIC = %.6f\n', ...
            d1_hat, d2_hat, l1_hat, l2_hat, LL3b, AIC(4));
    fprintf('Model 4 (Geo δs,δx,λs,λx): δ_same = %.6f, δ_cross = %.6f, λ_same = %.6f, λ_cross = %.6f | logL = %.6f, AIC = %.6f\n', ...
            ds_hat, dx_hat, ls_hat, lx_hat, LL4, AIC(5));
    fprintf('Model 5 (Inc δs,δx,λs,λx): δ_same = %.6f, δ_cross = %.6f, λ_same = %.6f, λ_cross = %.6f | logL = %.6f, AIC = %.6f\n', ...
            dsi_hat, dxi_hat, lsi_hat, lxi_hat, LL5, AIC(6));

    labels = {'Null','Linear','Single δ+λ','Two δ + two λ','Geo (same/cross)','Income (same/cross)'};
    fprintf('\n=== AIC Weights (Window %d–%d) ===\n', y_lo, y_hi);
    for m = 1:numel(labels)
        fprintf('  %-22s  ΔAIC = %7.3f   weight = %.3f\n', labels{m}, dAIC(m), wAIC(m));
    end

    fprintf('\n=== 95%% Confidence Intervals (Window %d–%d) ===\n', y_lo, y_hi);
    % Model 1
    fprintf('Model 1 (Linear):    δ   = [%.6f, %.6f]  (Wald)\n', ci_M1_delta(1), ci_M1_delta(2));
    % Model 2
    fprintf('Model 2 (δ+λ):       δ   = [%.6f, %.6f]  (Wald)\n',   ci_M2_wald.delta(1),  ci_M2_wald.delta(2));
    fprintf('                    λ   = [%.6f, %.6f]  (Wald)\n',   ci_M2_wald.lambda(1), ci_M2_wald.lambda(2));
    fprintf('                    δ   = [%.6f, %.6f]  (Profile)\n', ci_M2_prof.delta(1),  ci_M2_prof.delta(2));
    fprintf('                    λ   = [%.6f, %.6f]  (Profile)\n', ci_M2_prof.lambda(1), ci_M2_prof.lambda(2));
    % Model 3b
    fprintf('Model 3b:            δ1  = [%.6f, %.6f]  (Wald)\n',  ci_M3b_wald.delta1(1),  ci_M3b_wald.delta1(2));
    fprintf('                    δ2  = [%.6f, %.6f]  (Wald)\n',  ci_M3b_wald.delta2(1),  ci_M3b_wald.delta2(2));
    fprintf('                    λ1  = [%.6f, %.6f]  (Wald)\n',  ci_M3b_wald.lambda1(1), ci_M3b_wald.lambda1(2));
    fprintf('                    λ2  = [%.6f, %.6f]  (Wald)\n',  ci_M3b_wald.lambda2(1), ci_M3b_wald.lambda2(2));
    % Model 4
    fprintf('Model 4 (Geo):       δ_same  = [%.6f, %.6f]  (Wald)\n',  ci_M4_wald.delta1(1),  ci_M4_wald.delta1(2));
    fprintf('                    δ_cross = [%.6f, %.6f]  (Wald)\n',  ci_M4_wald.delta2(1),  ci_M4_wald.delta2(2));
    fprintf('                    λ_same  = [%.6f, %.6f]  (Wald)\n',  ci_M4_wald.lambda1(1), ci_M4_wald.lambda1(2));
    fprintf('                    λ_cross = [%.6f, %.6f]  (Wald)\n',  ci_M4_wald.lambda2(1), ci_M4_wald.lambda2(2));
    % Model 5
    fprintf('Model 5 (Income):    δ_same  = [%.6f, %.6f]  (Wald)\n',  ci_M5_wald.delta1(1),  ci_M5_wald.delta1(2));
    fprintf('                    δ_cross = [%.6f, %.6f]  (Wald)\n',  ci_M5_wald.delta2(1),  ci_M5_wald.delta2(2));
    fprintf('                    λ_same  = [%.6f, %.6f]  (Wald)\n',  ci_M5_wald.lambda1(1), ci_M5_wald.lambda1(2));
    fprintf('                    λ_cross = [%.6f, %.6f]  (Wald)\n',  ci_M5_wald.lambda2(1), ci_M5_wald.lambda2(2));

    % ========= Pack outputs =========
    win = struct();
    win.years = [y_lo, y_hi];
    win.LL0 = LL0; win.LL1 = LL1; win.LL2 = LL2; win.LL3b = LL3b; win.LL4 = LL4; win.LL5 = LL5;
    win.AIC0 = AIC(1); win.AIC1 = AIC(2); win.AIC2 = AIC(3); win.AIC3b = AIC(4); win.AIC4 = AIC(5); win.AIC5 = AIC(6);
    win.AIC_weights = wAIC;

    win.delta_lin_hat = delta_lin_hat;                 % Model 1
    win.delta_hat     = delta_hat;                     % Model 2
    win.lambda_hat    = lambda_hat;
    win.delta1_hat    = d1_hat;                        % Model 3b
    win.delta2_hat    = d2_hat;
    win.lambda1_hat   = l1_hat;
    win.lambda2_hat   = l2_hat;
    win.delta_same_hat  = ds_hat;                      % Model 4
    win.delta_cross_hat = dx_hat;
    win.lambda_same_hat = ls_hat;
    win.lambda_cross_hat = lx_hat;
    win.delta_same_inc_hat  = dsi_hat;                 % Model 5
    win.delta_cross_inc_hat = dxi_hat;
    win.lambda_same_inc_hat = lsi_hat;
    win.lambda_cross_inc_hat = lxi_hat;

    win.ci.M1.delta              = ci_M1_delta;
    win.ci.M2.delta              = ci_M2_wald.delta;
    win.ci.M2.lambda             = ci_M2_wald.lambda;
    win.ci.M2_profile.delta      = ci_M2_prof.delta;
    win.ci.M2_profile.lambda     = ci_M2_prof.lambda;
    win.ci.M3b.delta1            = ci_M3b_wald.delta1;
    win.ci.M3b.delta2            = ci_M3b_wald.delta2;
    win.ci.M3b.lambda1           = ci_M3b_wald.lambda1;
    win.ci.M3b.lambda2           = ci_M3b_wald.lambda2;
    win.ci.M4.delta1             = ci_M4_wald.delta1;
    win.ci.M4.delta2             = ci_M4_wald.delta2;
    win.ci.M4.lambda1            = ci_M4_wald.lambda1;
    win.ci.M4.lambda2            = ci_M4_wald.lambda2;
    win.ci.M5.delta1             = ci_M5_wald.delta1;
    win.ci.M5.delta2             = ci_M5_wald.delta2;
    win.ci.M5.lambda1            = ci_M5_wald.lambda1;
    win.ci.M5.lambda2            = ci_M5_wald.lambda2;

    win.grids.delta1_grid_used   = delta1_grid;
    win.grids.M2_delta_grid_used = delta_grid_used;
    win.grids.M2_exp_grid_used   = exp_grid_used;
    win.grids.M3b_d1_grid_used   = d1_grid_used;
    win.grids.M3b_d2_grid_used   = d2_grid_used;
    win.grids.M3b_e1_grid_used   = e1_grid_used;
    win.grids.M3b_e2_grid_used   = e2_grid_used;
    win.grids.M4_d1_grid_used    = d1_grid4_used;
    win.grids.M4_d2_grid_used    = d2_grid4_used;
    win.grids.M4_e1_grid_used    = e1_grid4_used;
    win.grids.M4_e2_grid_used    = e2_grid4_used;
    win.grids.M5_d1_grid_used    = d1_grid5_used;
    win.grids.M5_d2_grid_used    = d2_grid5_used;
    win.grids.M5_e1_grid_used    = e1_grid5_used;
    win.grids.M5_e2_grid_used    = e2_grid5_used;
end

function preW = slice_pre_by_year(pre, y_lo, y_hi)
% SLICE_PRE_BY_YEAR  Keep only years within [y_lo, y_hi] (inclusive).
% W is reset at the start of this window (handled inside loglik function).

    mask = (pre.years >= y_lo) & (pre.years <= y_hi);
    if ~any(mask)
        error('No years in [%d,%d] exist in pre.years.', y_lo, y_hi);
    end

    preW = pre;   % shallow copy then replace windowed fields
    preW.years         = pre.years(mask);
    preW.baseEdges     = pre.baseEdges(mask);
    preW.n_y           = pre.n_y(mask);
    preW.gammaln_const = pre.gammaln_const(mask);
    preW.all_lin       = pre.all_lin(mask);
    preW.isOO_mask     = pre.isOO_mask(mask);
    preW.isGeo_mask    = pre.isGeo_mask(mask);
    preW.isIncome_mask = pre.isIncome_mask(mask);
    preW.obs           = pre.obs(mask);
    preW.Y             = numel(preW.years);

    % (N, id maps, and eligibility content remain unchanged)
end

function diag = diagnose_late_arrivals(pre, years_to_check, dataset, makePlots)
% DIAGNOSE_LATE_ARRIVALS
% Uses PRE (from build_precomputed_dataset_fast) to test whether the
% years in YEARS_TO_CHECK are dominated by "late-arriving" collaborations:
%   - Event-level: share of events with prior weight w^- = 0, 1, >=2
%   - Edge-level: number of unique pairs whose FIRST-EVER year is y
% Also reports, for YEARS_TO_CHECK combined:
%   * fraction of events that are first-time (w^-=0)
%   * fraction of unique pairs that are first-time (firstYear ∈ YEARS_TO_CHECK)
%
% INPUTS
%   pre             struct with fields: N, Y, years, obs{y}.i,j,cnt,isOO, n_y, ...
%   years_to_check  vector of calendar years to test (e.g., [2023 2024])
%   dataset         char for nice titles/labels (e.g., 'ATCM' or 'CCAMLR')
%   makePlots       logical; if true, produce per-year stacked bars
%
% OUTPUT
%   diag struct with per-year tables and combined summaries.

    if nargin < 4, makePlots = false; end
    tag = upper(dataset);

    N = pre.N;
    Y = pre.Y;
    years = pre.years(:).';
    [isIn, loc] = ismember(years_to_check, years);
    if ~all(isIn)
        warning('%s: some requested years not in dataset: %s', ...
                tag, mat2str(years_to_check(~isIn)));
        years_to_check = years_to_check(isIn);
        loc = loc(isIn);
        if isempty(years_to_check)
            error('None of the requested years are present in pre.years.');
        end
    end
    yIdxCheck = loc;

    % --- We’ll walk forward through years, tracking W (cumulative weights)
    W = sparse(N,N);

    % Per-year diagnostics containers
    per.year                 = years(:);
    per.n_events             = zeros(Y,1);  % sum(cnt)
    per.n_unique_pairs       = zeros(Y,1);  % length(cnt)

    % Event-weighted shares by prior bucket w^- ∈ {0,1,>=2}
    per.share_evt_w0         = zeros(Y,1);
    per.share_evt_w1         = zeros(Y,1);
    per.share_evt_w2p        = zeros(Y,1);

    % Pair counts by prior bucket (unweighted by cnt)
    per.pairs_w0             = zeros(Y,1);
    per.pairs_w1             = zeros(Y,1);
    per.pairs_w2p            = zeros(Y,1);

    % First-year-of-edge tracking
    firstYear_lin = containers.Map('KeyType','double','ValueType','double'); %#ok<CPROP>

    for yix = 1:Y
        obs = pre.obs{yix};
        if isempty(obs) || isempty(obs.i)
            % carry zeros
            continue
        end

        i = obs.i(:);
        j = obs.j(:);
        c = obs.cnt(:);

        lin = sub2ind([N,N], i, j);
        wprev = full(W(lin));             % prior weight W_ij(t^-)

        % Record first-ever appearances
        isFirstEver = (wprev == 0);
        new_lin = lin(isFirstEver);
        new_year = repmat(pre.years(yix), numel(new_lin), 1);
        for k = 1:numel(new_lin)
            if ~isKey(firstYear_lin, new_lin(k))
                firstYear_lin(new_lin(k)) = new_year(k);
            end
        end

        % Per-year totals
        n_events = sum(c);
        per.n_events(yix) = n_events;
        per.n_unique_pairs(yix) = numel(c);

        % Event-weighted bucket shares
        evt_w0  = sum( c(wprev==0) );
        evt_w1  = sum( c(wprev==1) );
        evt_w2p = sum( c(wprev>=2) );

        if n_events > 0
            per.share_evt_w0(yix)  = evt_w0  / n_events;
            per.share_evt_w1(yix)  = evt_w1  / n_events;
            per.share_evt_w2p(yix) = evt_w2p / n_events;
        else
            per.share_evt_w0(yix)  = 0;
            per.share_evt_w1(yix)  = 0;
            per.share_evt_w2p(yix) = 0;
        end

        % Pair counts by bucket (unweighted)
        per.pairs_w0(yix)  = sum(wprev==0);
        per.pairs_w1(yix)  = sum(wprev==1);
        per.pairs_w2p(yix) = sum(wprev>=2);

        % Update cumulative W
        W = W + sparse(i, j, c, N, N) + sparse(j, i, c, N, N);
    end

    % --- Edge first-year distribution across all years
    first_lin_keys = cell2mat(firstYear_lin.keys).';
    first_lin_vals = cell2mat(firstYear_lin.values).';
    % Count how many unique edges first appear in each calendar year
    [uYears, ~, g] = unique(first_lin_vals);
    first_count = accumarray(g, 1);
    firstYearTable = table(uYears, first_count, ...
        'VariableNames', {'Year','FirstTimeEdges'});

    % Totals for requested years
    idxMap = containers.Map(num2cell(years), num2cell(1:Y));
    req_idx = cellfun(@(z) idxMap(z), num2cell(years_to_check));

    % Event-level shares across requested years
    total_events_req = sum(per.n_events(req_idx));
    total_evt_w0     = sum(per.n_events(req_idx).*0); % init
    total_evt_w1     = sum(per.n_events(req_idx).*0);
    total_evt_w2p    = sum(per.n_events(req_idx).*0);
    % recompute by summing numerators (not averaging shares)
    for yix = req_idx
        obs = pre.obs{yix};
        if isempty(obs) || isempty(obs.i), continue; end
        i = obs.i(:); j = obs.j(:); c = obs.cnt(:);
        % rebuild prior-by-year to get correct wprev here:
        % We need prior W at start of year yix: rebuild quickly
    end
    % Instead of rebuilding, we reconstruct numerators using stored shares × totals:
    total_evt_w0  = sum(per.share_evt_w0(req_idx)  .* per.n_events(req_idx));
    total_evt_w1  = sum(per.share_evt_w1(req_idx)  .* per.n_events(req_idx));
    total_evt_w2p = sum(per.share_evt_w2p(req_idx) .* per.n_events(req_idx));

    share_evt_w0_req  = (total_events_req>0) * (total_evt_w0  / max(1,total_events_req));
    share_evt_w1_req  = (total_events_req>0) * (total_evt_w1  / max(1,total_events_req));
    share_evt_w2p_req = (total_events_req>0) * (total_evt_w2p / max(1,total_events_req));

    % Edge-level: fraction of unique edges whose first year ∈ requested set
    isFirstInReq = ismember(firstYearTable.Year, years_to_check);
    n_first_in_req = sum(firstYearTable.FirstTimeEdges(isFirstInReq));
    n_first_total  = sum(firstYearTable.FirstTimeEdges);
    frac_first_edges_in_req = n_first_in_req / max(1, n_first_total);

    % Pretty console summary
    fprintf('\n=== %s | Late-arrival diagnostics ===\n', tag);
    fprintf('Years tested: %s\n', mat2str(years_to_check));
    fprintf('Event-level (weighted by counts) in tested years:\n');
    fprintf('  share w^{-}=0   (first-time):  %.1f%%\n', 100*share_evt_w0_req);
    fprintf('  share w^{-}=1   (second hits): %.1f%%\n', 100*share_evt_w1_req);
    fprintf('  share w^{-}≥2   (repeats):     %.1f%%\n', 100*share_evt_w2p_req);
    fprintf('Edge-level:\n');
    fprintf('  First-time edges appearing in tested years: %d / %d (%.1f%%)\n', ...
        n_first_in_req, n_first_total, 100*frac_first_edges_in_req);

    if share_evt_w0_req >= 0.50 || frac_first_edges_in_req >= 0.50
        fprintf('Conclusion: The tested years are dominated by **late-arriving** collaborations.\n');
    else
        fprintf('Conclusion: The tested years are NOT dominated by late arrivals under this metric.\n');
    end

    % Optional plots
    if makePlots
        % 1) Per-year stacked bars of event-weighted shares
        figure('Color','w'); clf
        S = [per.share_evt_w2p, per.share_evt_w1, per.share_evt_w0]; % order: ≥2, 1, 0
        hb = bar(years, S, 0.95, 'stacked'); hold on; grid on; box on
        hb(1).FaceColor = [0.35 0.55 0.80]; % ≥2
        hb(2).FaceColor = [0.75 0.55 0.10]; % 1
        hb(3).FaceColor = [0.25 0.65 0.40]; % 0
        ylim([0 1]);
        xlabel('\textit{Year}','Interpreter','latex');
        ylabel('Event share by $w^{-}$ bucket','Interpreter','latex');
        title(sprintf('%s: Event composition by prior weight $w^{-}$', tag), 'Interpreter','latex');
        set(gca,'TickLabelInterpreter','latex','FontName','Times','FontSize',11);
        % highlight tested years
        yl = ylim;
        for y = years_to_check(:).'
            if ismember(y, years)
                xline(y, '--k', 'LineWidth', 1.0);
            end
        end
        legend({'$w^{-}\!\ge\!2$','$w^{-}\!=\!1$','$w^{-}\!=\!0$'}, ...
            'Interpreter','latex', 'Location','eastoutside', 'Box','off');

        % 2) First-time edges per year
        figure('Color','w'); clf
        stem(firstYearTable.Year, firstYearTable.FirstTimeEdges, 'filled'); grid on; box on
        xlabel('\textit{First year of edge}','Interpreter','latex');
        ylabel('\# new edges','Interpreter','latex');
        title(sprintf('%s: Number of first-time edges by year', tag), 'Interpreter','latex');
        set(gca,'TickLabelInterpreter','latex','FontName','Times','FontSize',11);
        for y = years_to_check(:).'
            if ismember(y, firstYearTable.Year)
                xline(y, '--k', 'LineWidth', 1.0);
            end
        end
    end

    % Pack outputs
    diag = struct();
    diag.per_year = per;
    diag.firstYearTable = firstYearTable;
    diag.requested_years = years_to_check;
    diag.event_share_req = struct('w0',share_evt_w0_req, 'w1',share_evt_w1_req, 'w2p',share_evt_w2p_req);
    diag.frac_first_edges_in_req = frac_first_edges_in_req;
end

%% ======================== FIGURE 4: TWO-PANEL AIC WEIGHTS ========================
% Call this AFTER running BOTH datasets so that .mat files exist.
%   >> plot_figure4_both()
function plot_figure4_both()
    atcm    = load('Fitting_results_ATCM.mat');
    ccamlr  = load('Fitting_results_CCAMLR.mat');

    datasets = {atcm, ccamlr};
    titles   = {'ATCM', 'CCAMLR'};

    figure('Color','w','Position',[100 100 900 700]); clf

    for panel = 1:2
        D   = datasets{panel};
        pre = D.pre;

        % --- Per-year log-likelihoods for all 6 models ---
        [~, ll_y0, yrs] = loglik_twoDelta_fast(pre, ...
            struct('delta1',0,'delta2',0,'exponent',1), true);
        [~, ll_y1, ~] = loglik_twoDelta_fast(pre, ...
            struct('delta1',D.delta1_grid(D.idx_lin_max), ...
                   'delta2',D.delta1_grid(D.idx_lin_max),'exponent',1), true);
        [~, ll_y2, ~] = loglik_twoDelta_fast(pre, ...
            struct('delta1',D.best_delta_eq,'delta2',D.best_delta_eq, ...
                   'exponent',D.best_exponent_single), true);
        [~, ll_y3, ~] = loglik_twoDelta_fast(pre, ...
            struct('delta1',D.best_delta1,'delta2',D.best_delta2, ...
                   'lambda1',D.best_lambda1_two,'lambda2',D.best_lambda2_two), true);
        [~, ll_y4, ~] = loglik_geo_fast(pre, ...
            struct('delta1',D.best_delta_same,'delta2',D.best_delta_cross, ...
                   'lambda1',D.best_lambda_same,'lambda2',D.best_lambda_cross), true);
        [~, ll_y5, ~] = loglik_income_fast(pre, ...
            struct('delta1',D.best_delta_same_inc,'delta2',D.best_delta_cross_inc, ...
                   'lambda1',D.best_lambda_same_inc,'lambda2',D.best_lambda_cross_inc), true);

        % --- AIC weights per year ---
        LL_year = [ll_y0 ll_y1 ll_y2 ll_y3 ll_y4 ll_y5];
        k_vec   = [0 1 2 4 4 4];
        AIC_y   = 2*k_vec - 2*LL_year;
        dAIC_y  = AIC_y - min(AIC_y,[],2);
        w_y     = exp(-0.5*dAIC_y);
        w_y     = w_y ./ sum(w_y,2);

        % Mask empty years
        mask     = pre.n_y(:) > 0;
        yrs_plot = yrs(mask);
        w_y_plot = w_y(mask,:);

        % --- Plot ---
        subplot(2,1,panel)
        % Categorical x-axis: contiguous bars, no gaps for missing years
        yrs_cat = categorical(yrs_plot);
        yrs_cat = reordercats(yrs_cat, string(yrs_plot));
        hb = bar(yrs_cat, w_y_plot, 1.0, 'stacked');
        box on; grid off
        ylim([0 1]);

        % Colours: cool gradient (endogenous) + warm accents (covariates)
        hb(1).FaceColor = [0.40 0.00 0.40];   % Null
        hb(2).FaceColor = [0.30 0.30 0.70];   % Linear
        hb(3).FaceColor = [0.20 0.60 0.60];   % Single δ
        hb(4).FaceColor = [0.45 0.75 0.35];   % Two δ
        hb(5).FaceColor = [0.85 0.60 0.15];   % Geo
        hb(6).FaceColor = [0.75 0.25 0.20];   % Income
        for kk = 1:6, hb(kk).EdgeColor = 'none'; end

        % Thin x-tick labels
        all_ticks = 1:numel(yrs_plot);
        if panel == 1, tick_sp = 3; else, tick_sp = 2; end
        show = all_ticks(1):tick_sp:all_ticks(end);
        lbl = strings(1, numel(yrs_plot));
        for kk = show, lbl(kk) = string(yrs_plot(kk)); end
        set(gca, 'XTickLabel', lbl);
        xtickangle(0);

        ylabel('AIC weight','Interpreter','latex','FontSize',12);
        title(titles{panel},'Interpreter','latex','FontSize',14);
        set(gca,'TickLabelInterpreter','latex','FontName','Times','FontSize',10);
        set(gca,'YTick',0:0.2:1);
    end

    % Shared legend at bottom
    lg = legend(hb, ...
        {'Random attachment', ...
         'Preferential; linear', ...
         'Preferential; single $\delta$', ...
         'Preferential; two $\delta$', ...
         'Preferential; geographic', ...
         'Preferential; income'}, ...
        'Interpreter','latex','Orientation','horizontal', ...
        'FontSize',8,'Box','off','NumColumns',3);
    lg.Position(2) = 0.01;

    drawnow;
    set(gcf,'PaperPositionMode','auto');
    print('-dpdf','Figure_yearlyfit.pdf');
    fprintf('Saved Figure_yearlyfit.pdf\n');
end

%% ======================== FIGURE 6: STRETCHED EXPONENTIAL ========================
% Call after running ATCM:
%   >> plot_figure6_stretched_exp()
function plot_figure6_stretched_exp()
    D   = load('Fitting_results_ATCM.mat');
    pre = D.pre;
    N   = pre.N;

    fprintf('Building cumulative weight matrix...\n');

    W = sparse(N,N);
    m_edges   = zeros(pre.Y,1);
    w_max_vec = zeros(pre.Y,1);
    for yix = 1:pre.Y
        obs = pre.obs{yix};
        if ~isempty(obs.i)
            W = W + sparse(obs.i,obs.j,obs.cnt,N,N) ...
                  + sparse(obs.j,obs.i,obs.cnt,N,N);
        end
        W_upper = triu(W);
        nz = nonzeros(W_upper);
        m_edges(yix) = nnz(W_upper);
        if ~isempty(nz), w_max_vec(yix) = max(nz); end
    end

    emp_weights = nonzeros(triu(W));
    lambda_hat  = D.best_exponent_single;
    n_emp       = numel(emp_weights);

    % --- Manual ECDF with unique steps (no Statistics Toolbox) ---
    sorted_w   = sort(emp_weights);
    [x_uniq, ~, ic] = unique(sorted_w);
    counts     = accumarray(ic, 1);
    cum_counts = cumsum(counts);
    x_emp = [0; x_uniq];
    f_emp = [0; cum_counts / n_emp];

    fprintf('lambda_hat = %.4f, n_edges = %d, max_weight = %d\n', ...
        lambda_hat, n_emp, max(emp_weights));

    figure('Color','w','Position',[100 100 1000 480]); clf

    % --- Panel (a): Empirical CDF + stretched-exponential fit ---
    subplot(1,2,1)
    stairs(x_emp, f_emp, 'k-', 'LineWidth',1.2);
    hold on

    % Two-parameter fit: F(w) = 1 - exp(-c * w^beta)
    x_fit = x_uniq;
    f_fit = cum_counts / n_emp;
    obj = @(p) sum((f_fit - (1 - exp(-p(1) * x_fit.^p(2)))).^2);
    beta0 = 1 - lambda_hat;
    c0    = 0.5;
    opts  = optimset('Display','off','TolFun',1e-10,'TolX',1e-10);
    p_hat = fminsearch(obj, [c0, beta0], opts);
    c_hat    = p_hat(1);
    beta_hat = p_hat(2);

    fprintf('Stretched-exp fit: c_hat = %.6f, beta_hat = %.6f\n', c_hat, beta_hat);

    w_plot = linspace(0, max(emp_weights), 500);
    cdf_fit = 1 - exp(-c_hat * w_plot.^beta_hat);
    plot(w_plot, cdf_fit, 'r--', 'LineWidth',1.5);
    hold off

    xlabel('$w$','Interpreter','latex','FontSize',12);
    ylabel('Empirical CDF $F(W \leq w)$','Interpreter','latex','FontSize',12);
    legend({'Empirical ECDF','Stretched-exponential fit'}, ...
        'Interpreter','latex','Location','northeast','Box','off','FontSize',9);
    set(gca,'TickLabelInterpreter','latex','FontName','Times','FontSize',10);
    box on;
    xlim([0 max(emp_weights)*1.05]);
    ylim([0 1]);
    title('(a) Empirical CDF of $W$','Interpreter','latex','FontSize',14);

    % --- Panel (b): W_max vs active edges (log-log) ---
    subplot(1,2,2)
    valid      = m_edges > 0;
    m_plot_b   = m_edges(valid);
    w_max_plot = w_max_vec(valid);

    exponent_wmax = 1 / (1 - lambda_hat);

    % Fit c0 using only points where W_max > 1
    use = w_max_plot > 1;
    obj_wmax = @(c0) sum((w_max_plot(use) - ...
        real((log(max(m_plot_b(use)/c0, 1.01))).^exponent_wmax)).^2);
    c0_hat = fminbnd(obj_wmax, 0.1, min(m_plot_b(use)));

    fprintf('W_max fit: c0_hat = %.4f, exponent = %.4f\n', c0_hat, exponent_wmax);

    % Theory curve: only where predicted W_max >= 1
    m_theory = logspace(log10(c0_hat*1.1), log10(max(m_plot_b)), 200);
    w_max_theory = (log(m_theory / c0_hat)).^exponent_wmax;
    keep = w_max_theory >= 1;
    m_theory = m_theory(keep);
    w_max_theory = w_max_theory(keep);

    loglog(m_plot_b, w_max_plot, 'b.', 'MarkerSize',10);
    hold on
    loglog(m_theory, w_max_theory, 'r--', 'LineWidth',1.5);
    hold off

    set(gca, 'XScale','log', 'YScale','log');
    xlabel('$m = \#$ active edges','Interpreter','latex','FontSize',12);
    ylabel('$W_{\max}$','Interpreter','latex','FontSize',12);
    legend({'Observed','Predicted'}, ...
        'Interpreter','latex','Location','northwest','Box','off','FontSize',9);
    set(gca,'TickLabelInterpreter','latex','FontName','Times','FontSize',10);
    box on;
    ylim([1, max(w_max_plot)*1.3]);
    title('(b) $W_{\max}$ vs.\ number of active edges','Interpreter','latex','FontSize',14);

    % --- Save ---
    drawnow;
    set(gcf,'PaperPositionMode','auto');
    print('-dpdf','Figure6_stretched_exp.pdf');
    fprintf('Saved Figure6_stretched_exp.pdf\n');
end
