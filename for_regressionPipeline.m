% FOR Regression pipeline
%
% 1. Preprocessing
% 2. Run reduced Bayesian model over the data
% 3. Run regression
% 4. Compare actual and predicted update distributions

% Number of random starting points for regression estimation
n_sp = 5;
rand_sp = true;

% Identify parent directory of this config script
parentDirectory = fileparts(mfilename('fullpath'));
cd(parentDirectory)
addpath(genpath(parentDirectory));

% This is the BIDS folder
bidsDir = strcat(parentDirectory, filesep, 'Leipzig_Behav_Pilot_Heli', filesep, 'for_bids_data');

% ----------------
% 1. Preprocessing
% ----------------

% Run preprocessing to get all behavioral data
allSubBehavData = for_preprocessing(bidsDir);

% Number of subjects
n_subj = length(unique(allSubBehavData.ID));

% -------------------------------------------
% 2. Run reduced Bayesian model over the data
% -------------------------------------------

% Independent normative model parameter initialization
df_model = table();
df_model.omikron_0 = repmat(100, n_subj, 1);
df_model.omikron_1 = zeros(n_subj, 1);
df_model.h = repmat(0.1, n_subj, 1);
df_model.s = ones(n_subj, 1);
df_model.u = zeros(n_subj, 1);
df_model.sigma_H = repmat(0.01, n_subj, 1);
df_model.subj_num = (1:n_subj)';

sim = false; % don't generate predictions
plot_data = false; % no plotting for now

% Run RBM
[~, df_data] = for_simulation(allSubBehavData, df_model, n_subj, plot_data, sim);

% Add RU and CPP to data frame
allSubBehavData.tau_t = df_data.tau_t;
allSubBehavData.omega_t = df_data.omega_t;

% -----------------
% 3. Run regression
% -----------------

% Initialize regression variables
reg_vars = ForRegVars();
reg_vars.n_subj = n_subj;
reg_vars.n_sp = n_sp;
reg_vars.rand_sp = rand_sp;
reg_vars.usePrior = true;

% Determine which parameters should be estimated
reg_vars.which_vars.beta_0 = true; % intercept
reg_vars.which_vars.beta_1 = true; % PE (fixed learning rate)
reg_vars.which_vars.beta_2 = true; % interaction PE and RU
reg_vars.which_vars.beta_3 = true; % interaction PE and CPP
reg_vars.which_vars.beta_4 = true; % interaction PE and hit
reg_vars.which_vars.beta_5 = true; % interaction PE and noise condition
reg_vars.which_vars.beta_6 = false; % interaction PE and visible
reg_vars.which_vars.beta_7 = false; % interaction EE and visible
reg_vars.which_vars.omikron_0 = true; % motor noise (independent of PE)
reg_vars.which_vars.omikron_1 = true; % learning-rate noise (dependent on PE)
reg_vars.which_vars.uniform = false; % uniform component for outlier predictions
reg_vars.regressionComponents = [reg_vars.which_vars.beta_0, reg_vars.which_vars.beta_1,...
    reg_vars.which_vars.beta_2, reg_vars.which_vars.beta_3, reg_vars.which_vars.beta_4,...
    reg_vars.which_vars.beta_5, reg_vars.which_vars.beta_6, reg_vars.which_vars.beta_7];

% Create regression-object instance
regression = ForRegression(reg_vars);

% Estimate regression model
results = regression.run_estimation(allSubBehavData);

% Simple plots of key coefficients
behavLabels = {'Int', 'PE', 'PE*RU', 'PE*CPP', 'PE*Hit', 'PE*Noise',...
    'PE*Visible', 'EE*Visble', 'Motor noise', 'LR noise', 'uniform'};
which_vars_vec = struct2array(reg_vars.which_vars);
behavLabels = behavLabels(which_vars_vec);
gridSize = [3,3];
for_parameterSummary(results.parameters, behavLabels, gridSize)

% ----------------------------------------------------
% 4. Compare actual and predicted update distributions
% ----------------------------------------------------
 
% Take actual parameter values given specified free parameters
df_params = table();
if reg_vars.which_vars.beta_0
    df_params.beta_0 = results.parameters.beta_0;
end

if reg_vars.which_vars.beta_1
    df_params.beta_1 = results.parameters.beta_1;
end

if reg_vars.which_vars.beta_2
    df_params.beta_2 = results.parameters.beta_2;
end

if reg_vars.which_vars.beta_3
    df_params.beta_3 = results.parameters.beta_3;
end

if reg_vars.which_vars.beta_4
    df_params.beta_4 = results.parameters.beta_4;
end

if reg_vars.which_vars.beta_5
    df_params.beta_5 = results.parameters.beta_5;
end

if reg_vars.which_vars.beta_6
    df_params.beta_6 = results.parameters.beta_6;
end

if reg_vars.which_vars.beta_7
    df_params.beta_7 = results.parameters.beta_7;
end

% omikron_0 should be true by default
df_params.omikron_0 = results.parameters.omikron_0;

if reg_vars.which_vars.omikron_1
    df_params.omikron_1 = results.parameters.omikron_1;
end

df_params.subj_num = (1:n_subj)';

% Sample updates from regression model
n_trials = 400;
samples = regression.sample_data(df_params, n_trials, allSubBehavData);

% Tranlate table to structure
samplesStruct = table2struct(samples, 'ToScalar', true);

% Compare actual and predicted updates
% ------------------------------------

% Example subject
ID = 1;
for_plotRegUpdate(allSubBehavData,samples, ID)

% All subjects
for_plotRegUpdate(allSubBehavData,samples)



%% Additional Plots



% -------------------------------
% Quickly check model variables
% -------------------------------
figure;
subplot(3,1,1);
subSel = allSubBehavData.ID == 12823;
hold on;
% Use cannon aim (mu_t) instead of distMean
plot(allSubBehavData.mu_t(subSel), '--', 'color', 'r');
% Use current outcome (x_t) instead of outcome
plot(allSubBehavData.x_t(subSel), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'LineWidth', 1);
% Use current prediction (b_t) instead of pred
plot(allSubBehavData.b_t(subSel), '-', 'color', 'b');
% Use catch trials (v_t) instead of catchTrial
plotCatch = allSubBehavData.v_t(subSel);
plotCatch(plotCatch == 0) = nan;
catchPred = allSubBehavData.mu_t(subSel);
catchPred(isnan(plotCatch)) = nan;
plot(catchPred, 'o', 'color', 'm');
ylabel('Angle (deg)');
xlabel('Trial');
set(gca, 'box', 'off');

subplot(3,1,2);
plot(rad2deg(allSubBehavData.delta_t(subSel)), '-', 'color', 'r');
xlabel('Trial');
ylabel('Angle (deg)');
set(gca, 'box', 'off');


% -------------------------------
% Summary plot regression results
% -------------------------------
% Extract beta weights for beta_0 to beta_5 from results.parameters
betas = table2array(results.parameters(:, {'beta_0','beta_1','beta_2','beta_3','beta_4','beta_5'}));

nSubj = size(betas, 1);
nCoeffs = size(betas, 2);

% Base x-positions for each coefficient (columns 1 to 6)
xBase = repmat(1:nCoeffs, nSubj, 1);

% Compute jitter offsets using smartJitter with reduced amplitude.
% Here, we use amplitude 0.05 and range 0.1.
xJit = smartJitter(betas, 0.05, 0.1);

% Compute tentative x positions.
xPositions = xBase + xJit;

% Now restrict the xPositions for each coefficient to remain within [i-0.5, i+0.5]
for i = 1:nCoeffs
    lb = i - 0.5;
    ub = i + 0.5;
    xPositions(:, i) = min(max(xPositions(:, i), lb), ub);
end

figure;
hold on;
% Plot each subject's beta weights with jittered and clamped x-positions
for i = 1:nCoeffs
    scatter(xPositions(:, i), betas(:, i), 50, 'filled');
end

% Set the x-axis tick labels to the coefficient names.
set(gca, 'XTick', 1:nCoeffs, 'XTickLabel', {'Int', 'PE', 'PE*RU', 'PE*CPP', 'PE*Hit', 'kappa*PE'});
xlabel('Regression Coefficient');
ylabel('Beta Weight');
title('Scatter Plot of Beta Weights ');
grid on;
hold off;

