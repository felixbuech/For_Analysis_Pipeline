function [sim_est_err, df_sim, true_params] = for_simulation(allSubBehavData, df_model, n_subj, plot_data, sim)
% FOR_SIMULATION This function simulates data using the reduced Bayesian model
%
% Input:
%   allSubBehavData: Data frame containing participant data
%   df_model: Data frame containing model parameters
%   n_subj: Number of participants
%   plot_data: Boolean indicating if plots should be generated
%   sim: Boolean indicating if prediction errors are simulated
%
% Output:
%   sim_est_err: Simulated estimation errors
%   df_sim: Data frame with simulation results
%   true_params: Set of true parameters

% Initialize agent variables
agent_vars = ForAgentVars();
agent_vars.max_x = 2 * pi;

% Initialize simulation variables
df_sim = table();
sim_est_err = NaN(n_subj, 1);
true_params = NaN;

% Cycle over subjects
for i = 1:n_subj

    % Get real subject ID
    subjID = df_model.subj_num(i);

    % Select current subject's data from allSubBehavData
    subsetIdx = allSubBehavData.ID == subjID;
    df_subj = structfun(@(x) x(subsetIdx, :), allSubBehavData, 'UniformOutput', false);

    % Extract model parameters for this subject
    sel_coeffs = df_model(df_model.subj_num == subjID, :);

    
    % Save parameters for parameter-recovery analysis
    if i == 1
        true_params = sel_coeffs;
    else
        true_params = [true_params; sel_coeffs];
    end

    % Set agent variables
    agent_vars.h = sel_coeffs.h;
    agent_vars.s = sel_coeffs.s;
    agent_vars.u = exp(sel_coeffs.u);
    agent_vars.sigma_H = sel_coeffs.sigma_H;
    agent_vars.tau_0 = 0.999;
    agent_vars.sigma_0 = 6.1875;
    agent_vars.mu_0 = pi;

    % Create agent instance
    agent = AlAgentRBM(agent_vars);

    % Create simple parameter array for RBM
    sel_coeffs = table2array(sel_coeffs);

    % Run task-agent interaction
    [~, df_data] = for_task_agent_int(df_subj, agent, agent_vars, sel_coeffs, sim);

    % Store results
    df_data.ID = repmat(i, height(df_data), 1);
    df_sim = [df_sim; df_data];

    % Extract estimation error
    if sim
        sim_est_err(i) = nanmean(abs(circ_dist(df_subj.mu_t, df_data.mu_t)));
    end

    % Plot data if needed

    % TODO: Implement for validation
    % and add for belief too
    % if plot_data
    %     figure;
    %     plot(1:height(df_subj), df_subj.a_t, 1:height(df_data), df_data.a_t_hat_rad);
    %     legend({'a_t', 'a_t_hat'});
    %     saveas(gcf, sprintf('for_figures/single_trial/up_%d.pdf', i));
    %     close;
    % end
end
end

function [all_sim_est_errs, all_data] = simulation_loop(df_exp, df_model, n_subj, plot_data, sim, n_sim)
% SIMULATION_LOOP This function runs the simulation across multiple cycles
%
% Input:
%   df_exp: Data frame containing participant data
%   df_model: Data frame containing model parameters
%   n_subj: Number of participants
%   plot_data: Boolean indicating if plots should be generated
%   sim: Boolean indicating if prediction errors are simulated
%   n_sim: Number of simulations
%
% Output:
%   all_sim_est_errs: Simulated estimation errors of all cycles
%   all_data: Data from all simulation cycles

% Initialize variables
all_sim_est_errs = NaN;
all_data = NaN;

% Cycle over simulation
for i = 1:n_sim
    [sim_est_err, df_sim, ~] = simulation(df_exp, df_model, n_subj, plot_data, sim);

    if i == 1
        all_sim_est_errs = sim_est_err;
        all_data = df_sim;
    else
        all_sim_est_errs = [all_sim_est_errs; sim_est_err];
        all_data = [all_data; df_sim];
    end
end
end