%% ================================================================
%  Choose dataset: 'ATCM' or 'CCAMLR'  (reads Excel .xlsx with columns: Year, Authors)
%    ATCM_WP_Authors.xlsx
%    CCAMLR_Authors.xlsx
% ================================================================
clear all

%dataset    = 'CCAMLR';  % <-- set to 'ATCM' or 'CCAMLR'
dataset = 'ATCM';     % <-- uncomment to run ATCM
doAnalyses = 0;         % 1 = re-fit models, 0 = load existing Fitting_results_*.mat

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

    % Drop rows with missing year or empty author cell
    if strcmp(dataset,'CCAMLR') == 1
        keep = ~isnan(Year_wp) & ~cellfun(@isempty, Author_wp) & Year_wp < 2021;
    else
        keep = ~isnan(Year_wp) & ~cellfun(@isempty, Author_wp);
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
            minDelta = 1.0;  maxDelta = 4.0;

        case 'CCAMLR'
            G = 40;
            % Model 1 (linear)
            delta1_grid = linspace(1.5, 5.0, G);
            % Model 2 (δ + exponent)
            delta_grid  = linspace(5, 6.5, round(G/2));
            exp_grid    = linspace(0.25, 1, round(G/2));
            % Model 3b grids
            delta1_grid2 = linspace(5, 7, round(G/2));   % δ1
            delta2_grid2 = linspace(5, 7, round(G/2));   % δ2
            exp1_grid2   = linspace(0.5, 1.5, round(G/2)); % λ1 (OO)
            exp2_grid2   = linspace(0.5, 1.5, round(G/2)); % λ2 (other)
            minDelta = 4.0;  maxDelta = 8.0;
    end

    %% ===================== PRECOMPUTE DATASET =====================
    pre = build_precomputed_dataset_fast(Author_wp, Year_wp, eligibilityYearMap, originalYear);

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

    % Save everything
    eval(['save Fitting_results_' dataset])

else
    %% ===================== LOAD PREVIOUS FITS =====================
    eval(['load Fitting_results_' dataset ...
          ' logL* delta* idx_lin_max exp_grid exp* best* *_wp eligibilityYearMap originalYear pre'])

    % If precompute missing, rebuild
    if ~exist('pre','var')
        pre = build_precomputed_dataset_fast(Author_wp, Year_wp, ...
                                             eligibilityYearMap, originalYear);
    end

    switch upper(dataset)
        case 'ATCM'
            minDelta = 1.0; maxDelta = 4.0;
        case 'CCAMLR'
            minDelta = 4.0; maxDelta = 8.0;
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

AIC0  = 2*k0  - 2*LL0;
AIC1  = 2*k1  - 2*LL1;
AIC2  = 2*k2  - 2*LL2;
AIC3b = 2*k3b - 2*LL3b;

fprintf('\n=== %s | Likelihood & AIC Summary ===\n', upper(dataset));
fprintf('Model 0 (Null):            logL = %.6f,  AIC = %.6f\n', LL0, AIC0);
fprintf('Model 1 (Linear):          MLE delta = %.6f | logL = %.6f, AIC = %.6f\n', ...
        delta1_grid(idx_lin_max), LL1, AIC1);
fprintf('Model 2 (δ+λ):             MLE delta = %.6f, λ = %.6f | logL = %.6f, AIC = %.6f\n', ...
        best_delta_eq, best_exponent_single, LL2, AIC2);
fprintf('Model 3b (δ1,δ2,λ1,λ2):    MLE δ1 = %.6f, δ2 = %.6f, λ1 = %.6f, λ2 = %.6f | logL = %.6f, AIC = %.6f\n', ...
        best_delta1, best_delta2, best_lambda1_two, best_lambda2_two, LL3b, AIC3b);

AICs = [AIC0 AIC1 AIC2 AIC3b];
dAIC = AICs - min(AICs);
w    = exp(-0.5*dAIC); w = w/sum(w);
labels = {'Null','Linear','Single δ','Two δ (λ1,λ2)'};
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

LL_year = [ll_y0 ll_y1 ll_y2 ll_y3b];   % rows: years, cols: models
k_vec   = [0 1 2 4];
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

% Reorder models so stack = [Two δ, Single δ, Linear, Null]
% w_y columns are [Null, Linear, Single, Two] => [4 3 2 1]
w_stack = w_y_plot(:, [4 3 2 1]);

figure(2); clf
ax = gca;

% LEFT AXIS: AIC weights
yyaxis left
ax.YAxis(1).Color = 'k';

hb = bar(yrs_plot, w_stack, 1.0, 'stacked');
box on; grid on
ylim([0 1]);

hb(1).FaceColor = [0.60 0.85 0.60];   % Two δ
hb(2).FaceColor = [0.00 0.60 0.60];   % Single δ
hb(3).FaceColor = [0.25 0.35 0.70];   % Linear
hb(4).FaceColor = [0.40 0.00 0.40];   % Null

xlim([min(yrs_plot)-0.5, max(yrs_plot)+0.5]);
xticks(yrs_plot);
xtickangle(60);

xlabel('\textit{Year}','Interpreter','latex');
ylabel('$\mathrm{AIC\ weight}$','Interpreter','latex');
set(gca,'TickLabelInterpreter','latex');

% RIGHT AXIS: share of total collaborations
yyaxis right
ax.YAxis(2).Color = 'k';

hline = plot(yrs_plot, share_collab, '-o', ...
    'Color','k', ...
    'LineWidth',1.5, ...
    'MarkerFaceColor','k', ...
    'MarkerSize',3);

ylabel('\textit{Share of total collaborations}','Interpreter','latex');
ylim([0, max(share_collab)*1.05]);

set(gca,'Layer','top');

legend([hb(1) hb(2) hb(3) hb(4) hline], ...
    {'Two $\delta$', ...
     'Single $\delta$', ...
     'Linear', ...
     'Null', ...
     'Share of total collaborations'}, ...
    'Interpreter','latex', ...
    'Location','eastoutside');

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

%% ===================== ECDF ENVELOPE PANELS (1000 sims) =====================
% Make sure you have run this for BOTH datasets ("ATCM" and "CCAMLR")
% so that Fitting_results_ATCM.mat and Fitting_results_CCAMLR.mat exist.
plot_ecdf_two_delta_both(1000, 12345);

%% ============================= FAST CORE (precompute + evaluate) =============================
function pre = build_precomputed_dataset_fast(Author_wp, Year_wp, eligibilityMap, originalYear)
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
            pre.obs{yix}         = struct('i',[],'j',[],'cnt',[],'isOO',[]);
            pre.n_y(yix)         = 0;
            pre.gammaln_const(yix) = 0;
            continue
        end

        [ii, jj] = find(triu(true(m),1));
        gi = elig(ii); gj = elig(jj);
        pre.baseEdges(yix) = numel(gi);
        pre.all_lin{yix}   = sub2ind([N,N], gi, gj);
        pre.isOO_mask{yix} = isOriginal(gi) & isOriginal(gj);

        pair_list = [];
        for t = i0:i1
            A = sort(papers{t}(:))';
            if numel(A) < 2, continue, end
            A = A(eligYearById(A) <= y);
            if numel(A) < 2, continue, end
            E = nchoosek(A,2);
            pair_list = [pair_list; E]; %#ok<AGROW>
        end

        if isempty(pair_list)
            pre.obs{yix}           = struct('i',[],'j',[],'cnt',[],'isOO',[]);
            pre.n_y(yix)           = 0; %#ok<*NBRAK> (we will correct this)
            pre.n_y(yix)           = 0;
            pre.gammaln_const(yix) = 0;
        else
            lin  = sub2ind([N,N], pair_list(:,1), pair_list(:,2));
            [u_lin, ~, g] = unique(lin);
            cnt = accumarray(g, 1);
            [ri, rj] = ind2sub([N,N], u_lin);
            pre.obs{yix} = struct('i',ri, 'j',rj, 'cnt',cnt, ...
                                  'isOO', isOriginal(ri) & isOriginal(rj));
            pre.n_y(yix)           = sum(cnt);
            pre.gammaln_const(yix) = gammaln(pre.n_y(yix) + 1) - sum(gammaln(cnt + 1));
        end
    end
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

        % Ensure 'pre' exists
        if ~isfield(S,'pre') || isempty(S.pre)
            S.pre = build_precomputed_dataset_fast( ...
                S.Author_wp, S.Year_wp, S.eligibilityYearMap, S.originalYear);
        end

        % ---------- 1. Identify best AIC model globally ----------
        % Model 0: Null
        null_params = struct('delta1',0,'delta2',0,'exponent',1);
        LL0 = loglik_twoDelta_fast(S.pre, null_params, false);
        k0  = 0;

        % Model 1: Linear (single δ, exponent = 1)
        LL1 = S.logL_lin_max;
        k1  = 1;

        % Model 2: single δ + λ (nonlinear)
        LL2 = S.bestVal_single;
        k2  = 2;

        % Model 3b: two δ + two λ
        LL3 = S.bestVal_two4D;
        k3  = 4;

        AIC  = [2*k0 - 2*LL0, 2*k1 - 2*LL1, 2*k2 - 2*LL2, 2*k3 - 2*LL3];
        dAIC = AIC - min(AIC);
        w    = exp(-0.5*dAIC); 
        w    = w / sum(w);

        [~, idxBest] = min(AIC);

        labelsConsole = { ...
            'Null', ...
            'Linear', ...
            'Single (delta + lambda)', ...
            'Two delta + two lambda'};

        labelsLatex = { ...
            'Null', ...
            'Linear', ...
            'Single $\delta + \lambda$', ...
            'Two $\delta$ + two $\lambda$'};

        bestLabelLatex = labelsLatex{idxBest};

        % Pack parameters of the best-AIC model for simulation
        switch idxBest
            case 1  % Null
                params = struct('delta1',0, 'delta2',0, 'exponent',1);

            case 2  % Linear
                delta_hat = S.delta1_grid(S.idx_lin_max);
                params = struct('delta1',delta_hat, ...
                                'delta2',delta_hat, ...
                                'exponent',1);

            case 3  % Single δ + λ
                params = struct('delta1',S.best_delta_eq, ...
                                'delta2',S.best_delta_eq, ...
                                'exponent',S.best_exponent_single);

            case 4  % Two δ + two λ
                params = struct('delta1',S.best_delta1, ...
                                'delta2',S.best_delta2, ...
                                'lambda1',S.best_lambda1_two, ...
                                'lambda2',S.best_lambda2_two);
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
        [F_lo, F_hi] = ecdf_envelope(S.pre, params, R, x_grid);

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

        title(sprintf('Best AIC Model fit to Observed Data', ds, bestLabelLatex), ...
              'Interpreter','latex');
    end

    sgtitle('Empirical Network vs. Best Fit Model Simulation Envelopes', ...
            'Interpreter','latex');
    
    % Save (optional; adjust filenames if you like)
    exportgraphics(f, 'fig_ecdf_bestAIC_panels.png', 'Resolution', 300);
    exportgraphics(f, 'fig_ecdf_bestAIC_panels.pdf', 'ContentType','vector');
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

%% ================================================================
% ATCM: empirical W distribution, ECDF with theory overlay, and W_max scaling
% (Requires 'pre' from build_precomputed_dataset_fast; set dataset='ATCM')
% ================================================================
if ~strcmpi(dataset,'ATCM')
    warning('This block is configured for ATCM. Set dataset=''ATCM'' to run.');
end
if ~exist('pre','var') || isempty(pre)
    pre = build_precomputed_dataset_fast(Author_wp, Year_wp, eligibilityYearMap, originalYear);
end

% ---- Build cumulative W by year; track m(t) and W_max(t)
N = pre.N; Y = pre.Y;
W = sparse(N,N);
m_series    = zeros(Y,1);   % active edges count (i<j with W>0) up to year y
Wmax_series = zeros(Y,1);   % max edge weight up to year y

for yix = 1:Y
    obs = pre.obs{yix};
    if ~isempty(obs.i)
        W = W + sparse(obs.i, obs.j, obs.cnt, N,N) + sparse(obs.j, obs.i, obs.cnt, N,N);
    end
    U = triu(W,1);
    m_series(yix)    = nnz(U);
    Wmax_series(yix) = (m_series(yix) > 0) * full(max(U(:)));
end

% ---- Final edge-weight vector (upper triangle, positive weights)
w_vec = full(nonzeros(triu(W,1)));
if isempty(w_vec)
    error('No active edges found for ATCM; check parsing/eligibility inputs.');
end

% ===================== Empirical density (discrete) =====================
f1 = figure('Color','w'); clf
edges   = (0.5 : 1 : (max(w_vec)+0.5));
centers = edges(1:end-1) + 0.5;
dens    = histcounts(w_vec, edges, 'Normalization','pdf');
bar(centers, dens, 1.0, 'FaceColor',[0.2 0.5 0.8], 'EdgeColor','none'); grid on
xlabel('Total collaborations per pair, W'); ylabel('Empirical density');
set(gca,'FontName','Times','FontSize',11)
set(f1, 'PaperPositionMode','auto'); print(f1,'-dpdf','ATCM_weight_density.pdf');

% ===================== Empirical CCDF (log-log) =====================
uw   = unique(w_vec);                        % support values
ccdf = arrayfun(@(x) mean(w_vec >= x), uw);
f2 = figure('Color','w'); clf
loglog(uw, ccdf, 'o', 'MarkerFaceColor',[0 0 0], 'MarkerEdgeColor','k','MarkerSize',4); grid on
xlabel('w'); ylabel('P(W \ge w)');
set(gca,'FontName','Times','FontSize',11)
set(f2, 'PaperPositionMode','auto'); print(f2,'-dpdf','ATCM_weight_ccdf.pdf');

% ===================== Tail fit: -log CCDF ~ c * w^k =====================
% Heuristic tail threshold (adjust if desired)
w_min = max(5, prctile(w_vec,80));
u_tail   = uw(uw >= w_min);
cc_tail  = arrayfun(@(x) mean(w_vec >= x), u_tail);
mask     = (cc_tail > 0) & (cc_tail < 1);
u_tail   = u_tail(mask);
cc_tail  = cc_tail(mask);

x = log(u_tail(:));
y = log(-log(cc_tail(:)));
p = polyfit(x, y, 1);         % y ≈ p(1)*x + p(2)
k_hat = max(p(1), 1e-6);      % shape for stretched exponential
c_hat = exp(p(2));            % scale
fprintf('\nATCM tail fit: w_min=%g, tail n=%d,  k_hat=%.3f, c_hat=%.3f (implied lambda=%.3f)\n', ...
        w_min, numel(u_tail), k_hat, c_hat, 1-k_hat);

% ===================== Empirical CDF with theoretical overlay ===========
% Empirical CDF (sorted)
w_sorted = sort(w_vec);
n = numel(w_sorted);
ecdf_y = (1:n)/n;                         % F_hat(w) = P(W \le w)
% Theoretical CDF: F(w) ≈ 1 - exp(-c_hat * w^k_hat)
F_theory = @(x) 1 - exp(-c_hat * max(x,0).^k_hat);

f3 = figure('Color','w'); clf
stairs(w_sorted, ecdf_y, 'k-', 'LineWidth',1.2); hold on
w_line = linspace(0, max(w_sorted), 500);
plot(w_line, F_theory(w_line), 'r--', 'LineWidth',1.8);
grid on; xlim([0, max(w_sorted)])
xlabel('w'); ylabel('Empirical CDF  F(W \le w)');
legend({'Empirical ECDF','Stretched-exponential fit'}, 'Location','southeast','Box','off');
set(gca,'FontName','Times','FontSize',11)
set(f3, 'PaperPositionMode','auto'); print(f3,'-dpdf','ATCM_weight_ecdf_with_fit.pdf');

% ===================== W_max vs theoretical prediction ==================
% Theory: W_max(m) ~ (log m / c)^(1/k).
m_pos          = m_series;            % by year
m_pos(m_pos<2) = NaN;                 % avoid early trivial phase
W_pred         = ((log(m_pos)./c_hat).^(1./k_hat));

f4 = figure('Color','w'); clf
plot(pre.years, Wmax_series, '-o', 'LineWidth',1.4, 'Color',[0.1 0.4 0.7], 'MarkerSize',4); hold on
plot(pre.years, W_pred, '--', 'LineWidth',2.0, 'Color',[0.85 0.33 0.1]);
grid on
xlabel('Year'); ylabel('W_{\rm max}');
legend({'Observed max','Predicted (\log m / c)^{1/k}'}, 'Location','northwest','Box','off');
set(gca,'FontName','Times','FontSize',11)
set(f4, 'PaperPositionMode','auto'); print(f4,'-dpdf','ATCM_Wmax_vs_year.pdf');

% Also versus m on log axes
f5 = figure('Color','w'); clf
loglog(max(m_series,1), max(Wmax_series,1), 'o', 'MarkerFaceColor',[0.1 0.4 0.7], ...
       'MarkerEdgeColor','none','MarkerSize',4); hold on
loglog(max(m_series,1), max(W_pred,1), '--', 'LineWidth',2.0, 'Color',[0.85 0.33 0.1]);
grid on
xlabel('m = \# active edges'); ylabel('W_{\rm max}');
legend({'Observed','Predicted'}, 'Location','northwest','Box','off');
set(gca,'FontName','Times','FontSize',11)
set(f5, 'PaperPositionMode','auto'); print(f5,'-dpdf','ATCM_Wmax_vs_m.pdf');

% Console summary
W_max_final = max(w_vec);
m_final     = m_series(end);
W_pred_final = ((log(max(m_final,2))/c_hat)^(1/k_hat));
fprintf('Final year: m=%d,  W_max(obs)=%d,  W_max(pred)≈%.1f\n', m_final, W_max_final, W_pred_final);

