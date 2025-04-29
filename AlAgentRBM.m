classdef AlAgentRBM
    %ALAGENTRBM This class specifies the instance variables and
    % methods of the common methods of the reduced Bayesian model

    properties

        % Model parameters
        s
        h
        u
        q
        sigma
        sigma_t_sq
        sigma_H
        tau_t
        omega_t
        mu_t
        max_x
        conf_t    % New: model confidence

        % Variables for belief updates
        a_t
        alpha_t
        tot_var
        C
    end

    methods

        function obj = AlAgentRBM(agent_vars)
            % Constructor: Initializes the agent with given parameters

            % Agent variables
            obj.s = agent_vars.s;
            obj.h = agent_vars.h;
            obj.u = agent_vars.u;
            obj.q = agent_vars.q;
            obj.sigma = agent_vars.sigma;
            obj.sigma_t_sq = agent_vars.sigma_0;
            obj.sigma_H = agent_vars.sigma_H;
            obj.tau_t = agent_vars.tau_0;
            obj.omega_t = agent_vars.omega_0;
            obj.mu_t = agent_vars.mu_0;
            obj.max_x = agent_vars.max_x;

             % Initialize model confidence
            obj.conf_t = 1 - obj.tau_t;

            % Initialize variables
            obj.a_t = NaN;
            obj.alpha_t = NaN;
            obj.tot_var = NaN;
            obj.C = NaN;
        end

        function obj = learn(obj, delta_t, b_t, v_t, mu_H, high_val)
            % LEARN This function implements the RBM learning process
            %
            %   Input
            %       obj: Agent-object instance
            %       delta_t: Current prediction error
            %       b_t: Last prediction of participant
            %       v_t: Helicopter visibility
            %       mu_H: True helicopter location
            %       high_val: High-value index

            % Ensure that delta is not NaN
            if isnan(delta_t)
                error('delta_t is NaN');
            end

            % Update variance of predictive distribution
            obj.tot_var = obj.sigma^2 + obj.sigma_t_sq;

            % Compute change-point probability
            term_1 = ((1 / obj.max_x) ^ obj.s) * obj.h;
            term_2 = (normpdf(delta_t, 0, sqrt(obj.tot_var))^obj.s) * (1 - obj.h);
            obj.omega_t = obj.safe_div(term_1, (term_2 + term_1));

            % Compute learning rate
            obj.alpha_t = obj.omega_t + obj.tau_t - obj.tau_t * obj.omega_t;
            obj.alpha_t = obj.alpha_t + obj.q * high_val;
            obj.alpha_t = max(0, min(1, obj.alpha_t));

            % Set model belief to last prediction
            obj.mu_t = b_t;

            % Update belief based on learning rate
            obj.a_t = obj.alpha_t * delta_t;
            obj.mu_t = mod(obj.mu_t + obj.a_t, obj.max_x);

            if v_t

                % Compute helicopter weight
                w_t = obj.sigma_t_sq / (obj.sigma_t_sq + obj.sigma_H^2);

                % Update belief with helicopter location
                obj.mu_t = mod((1 - w_t) * obj.mu_t + w_t * mu_H, obj.max_x);

                % Compute belief update considering helicopter cue
                obj.a_t  = circ_dist(obj.mu_t, b_t);

                % Compute mixture variance of two distributions
                term_1 = obj.safe_div(1, obj.sigma_t_sq);
                term_2 = obj.safe_div(1, obj.sigma_H^2);
                obj.C = obj.safe_div(1, term_1 + term_2);

                % Update relative uncertainty accordingly
                obj.tau_t = obj.safe_div(obj.C, obj.C + obj.sigma^2);
            end

            % Update estimation uncertainty
            term_1 = obj.omega_t * obj.sigma^2;
            term_2 = (1 - obj.omega_t) * obj.tau_t * obj.sigma^2;
            term_3 = obj.omega_t * (1 - obj.omega_t) * ((delta_t * (1 - obj.tau_t))^2);
            obj.sigma_t_sq = obj.safe_div((term_1 + term_2 + term_3), obj.u);

            % Update relative uncertainty for the next trial
            obj.tau_t = obj.safe_div(obj.sigma_t_sq, (obj.sigma_t_sq + obj.sigma^2));

            % Update model confidence
            obj.conf_t = 1 - obj.tau_t;


        end

        function result = safe_div(~, numerator, denominator)
            % SAfE_DIV This function handles zero denominator cases
            %
            %   Input
            %       numerator: Numerator of fraction
            %       denominator: Denominator of fraction
            %
            %   Output
            %       result: Result of safe division

            if denominator == 0
                result = 0.0;
            else
                result = numerator / denominator;
            end
        end
    end
end
