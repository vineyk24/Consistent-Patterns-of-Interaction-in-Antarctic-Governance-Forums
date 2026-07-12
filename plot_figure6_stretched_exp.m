% plot_figure6_stretched_exp.m
% Figure 6: Stretched exponential fit + W_max growth (ATCM only)
% Requires: Fitting_results_ATCM.mat
% No Statistics Toolbox needed.
 
clear; close all
 
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
 
% --- Manual ECDF with unique steps ---
sorted_w   = sort(emp_weights);
[x_uniq, ~, ic] = unique(sorted_w);
counts     = accumarray(ic, 1);
cum_counts = cumsum(counts);
x_emp = [0; x_uniq];
f_emp = [0; cum_counts / n_emp];
 
fprintf('lambda_hat = %.4f, n_edges = %d, max_weight = %d\n', ...
    lambda_hat, n_emp, max(emp_weights));
 
% ======================== FIGURE ========================
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
legend({'Empirical ECDF', ...
        sprintf('Stretched-exponential fit')}, ...
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
 
% Theoretical curve: W_max ~ (log(m/c0))^(1/(1-lambda))
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
set(gcf,'PaperPositionMode','auto');
print('-dpdf','Figure6_stretched_exp.pdf');
fprintf('Saved Figure6_stretched_exp.pdf\n');