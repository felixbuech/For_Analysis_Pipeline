% FOR Modeling pipeline
%
% 1. Preprocessing
% 2. Estimate reduced Bayesian model
% 3. Plot estimated parameters

% Number of random starting points for model estimation
n_sp = 50;
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

% ----------------------------------
% 2. Estimate reduced Bayesian model
% ----------------------------------

% Initialize estimation variables
est_vars = ForEstVars();
est_vars.n_subj = n_subj;
est_vars.n_sp = n_sp;
est_vars.rand_sp = rand_sp;
est_vars.use_prior = true;

% Select estimated parameters
est_vars.which_vars.omikron_0 = true;
est_vars.which_vars.omikron_1 = true;
est_vars.which_vars.h = true;
est_vars.which_vars.s = true;
est_vars.which_vars.u = true;
est_vars.which_vars.sigma_H = true;
% Todo: examine plausible boundaries, currently not really plausuble for radians

% Set agent variables
agent_vars = ForAgentVars();
agent_vars.tau_0 = 0.999;
agent_vars.sigma_0 = 6.1875;
agent_vars.mu_0 = 3.1416;
agent_vars.max_x = 2 * pi;

% Create estimation-object instance
estimation = ForEstimation(est_vars);

% Estimate RBM
results = estimation.run_estimation(allSubBehavData, agent_vars);

% ----------------------------
% 3. Plot estimated parameters
% ----------------------------

behavLabels = {est_vars.omikron_0, est_vars.omikron_1, est_vars.h, est_vars.s, est_vars.u, est_vars.sigma_H};
whichParamsVec = struct2array(est_vars.which_vars);
behavLabels = behavLabels(whichParamsVec);
gridSize = [3,2];
for_parameterSummary(results.parameters, behavLabels, gridSize)




%--------------------------------
% Quick MODEL (and Subject?) variable check plots
%-----------------------------------
figure
subplot(3,1,1)
subSel = allSubBehavData.ID == 99999;
hold on
plot(allSubBehavData.mu_t(subSel), '--', 'color', 'r')  % using mu_t for cannon aim
plot(allSubBehavData.x_t(subSel), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'LineWidth', 1)
plot(allSubBehavData.b_t(subSel), '-', 'color', 'b')
plot(allSubBehavData.a_t(subSel), 'o', 'color', 'y')
plotCatch = allSubBehavData.v_t(subSel);
plotCatch(plotCatch == 0) = nan;
catchPred = allSubBehavData.mu_t(subSel);
catchPred(isnan(plotCatch)) = nan;
plot(catchPred, 'o', 'color', 'm')
ylabel('Angle (deg)')
xlabel('Trial')
set(gca, 'box', 'off')

subplot(3,1,2)
plot(rad2deg(allSubBehavData.delta_t(subSel)), '-', 'color', 'r')
xlabel('Trial')
ylabel('Angle (deg)')
set(gca, 'box', 'off')

subplot(3,1,3)
hold on
plot(allSubBehavData.modSurp(subSel), '-', 'color', 'r')
plot(allSubBehavData.modRU(subSel), '-', 'color', 'b')
xlabel('Trial')
set(gca, 'box', 'off')