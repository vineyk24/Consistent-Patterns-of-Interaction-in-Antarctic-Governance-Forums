% plot_figure4_both.m
% Two-panel AIC weight stacked bars (ATCM top, CCAMLR bottom)
% Requires: Fitting_results_ATCM.mat, Fitting_results_CCAMLR.mat
% Also requires the main script LL_yearly_multinomial_V10.m on the path
% (for loglik_twoDelta_fast, loglik_geo_fast, loglik_income_fast)
 
clear; close all
 
atcm   = load('Fitting_results_ATCM.mat');
ccamlr = load('Fitting_results_CCAMLR.mat');
 
% Rebuild pre if needed (older .mat files may lack isGeo_mask / isIncome_mask)
if ~isfield(atcm.pre, 'isGeo_mask') || ~isfield(atcm.pre, 'isIncome_mask')
    error('ATCM pre struct is stale. Rerun LL_yearly_multinomial_V10 with doAnalyses=1 for ATCM.');
end
if ~isfield(ccamlr.pre, 'isGeo_mask') || ~isfield(ccamlr.pre, 'isIncome_mask')
    error('CCAMLR pre struct is stale. Rerun LL_yearly_multinomial_V10 with doAnalyses=1 for CCAMLR.');
end
 
datasets = {atcm, ccamlr};
titles   = {'ATCM', 'CCAMLR'};
 
figure('Color','w','Position',[100 100 900 700]); clf
 
for panel = 1:2
    D   = datasets{panel};
    pre = D.pre;
    N   = pre.N;
 
    fprintf('Computing per-year AIC weights for %s...\n', titles{panel});
 
    % --- Per-year log-likelihoods ---
    % Model 0: Null
    ll_y0 = compute_yearly_ll(pre, N, 0, 0, 1, 1, 'none');
    % Model 1: Linear
    ll_y1 = compute_yearly_ll(pre, N, D.delta1_grid(D.idx_lin_max), ...
        D.delta1_grid(D.idx_lin_max), 1, 1, 'none');
    % Model 2: Single delta + lambda
    ll_y2 = compute_yearly_ll(pre, N, D.best_delta_eq, D.best_delta_eq, ...
        D.best_exponent_single, D.best_exponent_single, 'none');
    % Model 3: Two delta (original signatory)
    ll_y3 = compute_yearly_ll(pre, N, D.best_delta1, D.best_delta2, ...
        D.best_lambda1_two, D.best_lambda2_two, 'OO');
    % Model 4: Geographic
    ll_y4 = compute_yearly_ll(pre, N, D.best_delta_same, D.best_delta_cross, ...
        D.best_lambda_same, D.best_lambda_cross, 'geo');
    % Model 5: Income
    ll_y5 = compute_yearly_ll(pre, N, D.best_delta_same_inc, D.best_delta_cross_inc, ...
        D.best_lambda_same_inc, D.best_lambda_cross_inc, 'income');
 
    yrs = pre.years;
 
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
    % Use categorical x-axis so bars are contiguous (no gaps for missing years)
    yrs_cat = categorical(yrs_plot);
    yrs_cat = reordercats(yrs_cat, string(yrs_plot));
    hb = bar(yrs_cat, w_y_plot, 1.0, 'stacked');
    box on; grid off
    ylim([0 1]);
 
    % Colours
    hb(1).FaceColor = [0.40 0.00 0.40];   % Null
    hb(2).FaceColor = [0.30 0.30 0.70];   % Linear
    hb(3).FaceColor = [0.20 0.60 0.60];   % Single delta
    hb(4).FaceColor = [0.45 0.75 0.35];   % Two delta
    hb(5).FaceColor = [0.85 0.60 0.15];   % Geo
    hb(6).FaceColor = [0.75 0.25 0.20];   % Income
    for kk = 1:6, hb(kk).EdgeColor = 'none'; end
 
    % Thin x-tick labels: show every nth label
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
 
% Shared legend
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
 
set(gcf,'PaperPositionMode','auto');
print('-dpdf','Figure_yearlyfit.pdf');
fprintf('Saved Figure_yearlyfit.pdf\n');
 
 
%% ======================== LOCAL LIKELIHOOD FUNCTION ========================
function ll_year = compute_yearly_ll(pre, N, delta1, delta2, lambda1, lambda2, mask_type)
    % Compute per-year log-likelihoods for a given model specification.
    % mask_type: 'none' (Models 0-2), 'OO' (Model 3), 'geo' (Model 4), 'income' (Model 5)
 
    Y = pre.Y;
    W = sparse(N,N);
    ll_year = zeros(Y,1);
 
    for yix = 1:Y
        baseEdges = pre.baseEdges(yix);
        if baseEdges == 0
            ll_year(yix) = 0;
            continue
        end
 
        all_lin = pre.all_lin{yix};
 
        % Select the mask for group 1 vs group 2
        switch mask_type
            case 'OO',     is_group1 = pre.isOO_mask{yix};
            case 'geo',    is_group1 = pre.isGeo_mask{yix};
            case 'income', is_group1 = pre.isIncome_mask{yix};
            otherwise,     is_group1 = true(size(all_lin));  % all group 1
        end
 
        if isempty(all_lin)
            S = baseEdges;
        else
            w_all = full(W(all_lin));
            sum1 = sum(w_all(is_group1).^lambda1);
            sum2 = sum(w_all(~is_group1).^lambda2);
            S = baseEdges + delta1*sum1 + delta2*sum2;
        end
 
        obs = pre.obs{yix};
        if ~isempty(obs.i)
            obs_lin = sub2ind([N,N], obs.i, obs.j);
            w_obs   = full(W(obs_lin));
 
            % Select obs mask
            switch mask_type
                case 'OO',     obs_mask = obs.isOO;
                case 'geo',    obs_mask = obs.isGeo;
                case 'income', obs_mask = obs.isIncome;
                otherwise,     obs_mask = true(size(obs.cnt));
            end
 
            deltas = delta2 * ones(size(obs.cnt));
            deltas(obs_mask) = delta1;
            expos = lambda2 * ones(size(obs.cnt));
            expos(obs_mask) = lambda1;
 
            ll_y = pre.gammaln_const(yix) ...
                 + sum(obs.cnt .* log(1 + deltas .* (w_obs.^expos))) ...
                 - pre.n_y(yix) * log(S);
            ll_year(yix) = ll_y;
 
            W = W + sparse(obs.i, obs.j, obs.cnt, N, N) ...
                  + sparse(obs.j, obs.i, obs.cnt, N, N);
        end
    end
end
 