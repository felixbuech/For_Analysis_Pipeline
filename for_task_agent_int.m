function [llh_rbm, df_data] = for_task_agent_int(df, agent, agent_vars, sel_coeffs, sim)
% Models the interaction between task and agent (RBM)
%
% Input:
%   df: Data frame with relevant data
%   agent: Agent-object instance
%   agent_vars: Agent-variables-object instance
%   sel_coeffs: Free parameters
%   sim: Boolean indicating if function is used for simulations
%
% Output:
%   llh_rbm: Negative log-likelihoods of RBM
%   df_data: Data frame with simulation results

% Extract and initialize relevant variables
n_trials = length(df.delta_t);
mu = NaN(n_trials, 1);
a_hat = NaN(n_trials, 1);
omega = NaN(n_trials, 1);
tau = NaN(n_trials, 1);
alpha = NaN(n_trials, 1);
sigma_t_sq = NaN(n_trials, 1);

if ~sim
    delta = df.delta_t;
else
    delta = NaN(n_trials, 1);
end

n_new_block = sum(df.new_block == 1);
llh_rbm = NaN(n_trials - n_new_block, 1);

sim_b_t = NaN(n_trials, 1);
sim_a_t = NaN(n_trials, 1);

llh_counter = 1;
corrected_0_p = 1e-10;

% Cycle over trials
for t = 1:n_trials-1

    % Outcome noise
    agent.sigma = df.sigma(t);

    % Reset agent on new blocks
    if df.new_block(t)
        agent.sigma_t_sq = agent_vars.sigma_0;
        agent.tau_t = agent_vars.tau_0;
        agent.omega_t = agent_vars.omega_0;
        sigma_t_sq(t) = agent_vars.sigma_0;

        if sim
            sim_b_t(t) = agent_vars.mu_0;
        end
    end

    % Record relative and estimation uncertainty
    tau(t) = agent.tau_t;
    sigma_t_sq(t) = agent.sigma_t_sq;

    % Update agent belief
    if ~df.new_block(t+1)

        % In research unit, we currently don't model value effects on the LR
        high_val = 0;

        if sim
            % For simulations, computed simulated prediction error
            delta(t) = circ_dist(df.x_t(t), sim_b_t(t));
            agent = agent.learn(delta(t), sim_b_t(t), df.v_t(t), df.mu_t(t), high_val);
        else
            % When extracting normative parameters, use participant
            % prediction errors
            agent = agent.learn(delta(t), df.b_t(t), df.v_t(t), df.mu_t(t), high_val);
        end

        % Record trial's agent parameters
        mu(t) = agent.mu_t;
        a_hat(t) = agent.a_t;
        omega(t) = agent.omega_t;
        alpha(t) = agent.alpha_t;

        % Compute updating noise based on common function
        abs_pred_up = abs(a_hat(t));
        concentration = residual_fun(abs_pred_up, sel_coeffs(1), sel_coeffs(2));

        % Compute probability of current update
        p_a_t = circ_vmpdf(df.a_t(t), a_hat(t), concentration);

        % Correct for zero likelihoods
        if p_a_t == 0.0
            p_a_t = corrected_0_p;
        end

        if isnan(p_a_t)
            error('llh contains NaN')
        end

        % Compute log-likelihood
        llh_rbm(llh_counter) = log(p_a_t);

        % Simulate belief update
        if sim

            % Tranlate into sqrt of updating variance (= standard deviation)
            sim_a_t(t) = normrnd(a_hat(t), sqrt(1/concentration));
            sim_b_t(t + 1) = mod(sim_b_t(t) + sim_a_t(t), agent.max_x);
        end

        % Update likelihood counter
        llh_counter = llh_counter + 1;
    end
end

confidence_model = 1 - tau;  % Model confidence = 1 - relative uncertainty


df_data = table(mu, a_hat, delta, omega, tau, alpha, sigma_t_sq, confidence_model, ...
    'VariableNames', {'mu_t', 'a_t_hat', 'delta_t', 'omega_t', 'tau_t',...
    'alpha_t', 'sigma_t_sq', 'confidence_model'});
if sim
    df_data.b_t = sim_b_t;
    df_data.a_t = sim_a_t;
    df_data.sigma = df.sigma;
    df_data.new_block = df.new_block;
    df_data.x_t = df.x_t;
    df_data.v_t = df.v_t;
end
end