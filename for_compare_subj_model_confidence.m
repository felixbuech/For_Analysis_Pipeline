% Script: run_compare_confidence_noZscore.m
% Purpose: Run model, then compare model and human confidence around changepoints (raw scale)

% ----------------------------
% Setup
% ----------------------------

% Set paths
parentDirectory = 'C:\Users\fb74loha\Desktop\For_Analysis_Clone\for_analysisPipeline';
cd(parentDirectory)
addpath(genpath(parentDirectory));

% Define BIDS directory
bidsDir = fullfile(parentDirectory, 'Leipzig', 'for_pilot_data', 'commonConfidence', 'for_bids_data');

% ----------------------------
% Load and preprocess data
% ----------------------------

allSubBehavData = for_preprocessing(bidsDir);
subjectIDs = unique(allSubBehavData.ID);
n_subj = length(subjectIDs);

% ----------------------------
% Model parameter setup
% ----------------------------

df_model = table();
df_model.omikron_0 = repmat(100, n_subj, 1);
df_model.omikron_1 = zeros(n_subj, 1);
df_model.h = repmat(0.1, n_subj, 1);
df_model.s = ones(n_subj, 1);
df_model.u = zeros(n_subj, 1);
df_model.sigma_H = repmat(0.01, n_subj, 1);
df_model.subj_num = subjectIDs;  % match real IDs

% ----------------------------
% Run the model
% ----------------------------

sim = false;       % use actual participant behavior
plot_data = false; % no need to plot during simulation

[~, df_data] = for_simulation(allSubBehavData, df_model, n_subj, plot_data, sim);

% ----------------------------
% Confidence around change points
% ----------------------------

nBefore = 4;
nAfter = 4;
xAxis = -nBefore:nAfter;

% ----------------------------
% Human Confidence (raw values)
% ----------------------------

validConf = ~isnan(allSubBehavData.confidenceRT);
confValues = allSubBehavData.confidence(validConf);
c_t_valid = allSubBehavData.c_t(validConf);
changeIdx_human = find(c_t_valid == 1);
nTrials = length(confValues);

periConf_human = [];

for i = 1:length(changeIdx_human)
    idx = changeIdx_human(i);
    if idx - nBefore >= 1 && idx + nAfter <= nTrials
        window = confValues(idx - nBefore : idx + nAfter);
        periConf_human = [periConf_human; window'];
    end
end

meanConf_human = mean(periConf_human, 1, 'omitnan');
semConf_human = std(periConf_human, 0, 1, 'omitnan') ./ sqrt(size(periConf_human, 1));

% ----------------------------
% Model Confidence (raw values)
% ----------------------------

modelConf = df_data.confidence_model;
c_t_model = allSubBehavData.c_t;  % use human changepoints for alignment
changeIdx_model = find(c_t_model == 1);
nTrials_model = length(modelConf);

periConf_model = [];

for i = 1:length(changeIdx_model)
    idx = changeIdx_model(i);
    if idx - nBefore >= 1 && idx + nAfter <= nTrials_model
        window = modelConf(idx - nBefore : idx + nAfter);
        periConf_model = [periConf_model; window'];
    end
end

meanConf_model = mean(periConf_model, 1, 'omitnan');
semConf_model = std(periConf_model, 0, 1, 'omitnan') ./ sqrt(size(periConf_model, 1));

% ----------------------------
% Plot both
% ----------------------------

% Safety checks
assert(numel(xAxis) == numel(meanConf_human), 'xAxis and human size mismatch');
assert(numel(xAxis) == numel(meanConf_model), 'xAxis and model size mismatch');

figure;
hold on;

% Human confidence
fill([xAxis, fliplr(xAxis)], ...
     [meanConf_human + semConf_human, fliplr(meanConf_human - semConf_human)], ...
     [0.7 0.7 1], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
plot(xAxis, meanConf_human, '-ob', 'LineWidth', 2, 'MarkerFaceColor', 'b');

% Model confidence
fill([xAxis, fliplr(xAxis)], ...
     [meanConf_model*100 + semConf_model*100, fliplr(meanConf_model*100 - semConf_model*100)], ...
     [1 0.7 0.7], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
plot(xAxis, meanConf_model*100, '-or', 'LineWidth', 2, 'MarkerFaceColor', 'r');

% Vertical line at CP
xline(0, '--k', 'LineWidth', 1.5);

% Plot settings
xlabel('Trials Relative to Change Point');
ylabel('Confidence (0–100)');
title('Human vs Model Confidence Around Change Points (Raw)');
legend('Human ± SEM', 'Human Mean', 'Model ± SEM', 'Model Mean', 'Location', 'Best');
grid on;
xlim([-nBefore nAfter]);
ylim([0 100]);
hold off;




