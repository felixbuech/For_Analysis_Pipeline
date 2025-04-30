%% (De-)Coupling Action and Confidence 

% Vaghi et al.: 
% Such mismatching was formally tested by a new regression model 
% in which action updating was predicted by confidence updating. In OCD patients, 
% there was a weakened relationship between action control and metacognitive reports of 
% confidence (OCD, 0.05 ± 0.01; CTL, 0.12 ± 0.02; Wilcoxon rank-sum test, z = 2.690, p = 0.007) 
% (Figure 4A). Reduced coupling between action and belief was most prominent in more severely ill p
% atients (OCD, n = 24, Pearson’s correlation, r = 0.426, p = 0.038) (Figure 4B), thus relating 
% inter-individual patient variability to symptom severity and suggesting that this computational 
% deficit is a  core feature of the multifaceted OCD psychiatric manifestation
% (Robbins et al., 2012; Stephan and Mathys, 2014).

% Identify parent directory of this config script
parentDirectory = 'C:\Users\fb74loha\Desktop\For_Analysis_Clone\for_analysisPipeline';
cd(parentDirectory)
addpath(genpath(parentDirectory));

% This is the BIDS folder
bidsDir = strcat(parentDirectory, filesep, 'Leipzig', filesep, 'for_pilot_data', filesep, 'commonConfidence', filesep, 'for_bids_data');

% 1. Preprocessing
% ----------------

% Run preprocessing to get all behavioral data
allSubBehavData = for_preprocessing(bidsDir);

% Number of subjects
n_subj = length(unique(allSubBehavData.ID));


subjectIDs = unique(allSubBehavData.ID);
n_subj = length(subjectIDs);


beta_vals = nan(n_subj, 1);

for i = 1:n_subj
    subjID = subjectIDs(i);  % get the actual ID
    rows = allSubBehavData.ID == subjID;

    conf = allSubBehavData.confidence(rows);
    conf_z = zscore(conf);
    conf_diff = abs(diff(conf_z));
    a_t = allSubBehavData.a_t(rows);
    a_diff = abs(a_t(2:end));

    valid = ~isnan(conf_diff) & ~isnan(a_diff);

    if sum(valid) > 5
        X = conf_diff(valid);
        Y = a_diff(valid);
        beta_vals(i) = regress(Y, X);  % zero intercept
    end
end



% Compute group statistics
groupMean = mean(beta_vals);
groupSEM = std(beta_vals) / sqrt(length(beta_vals));

% Start figure
figure;
hold on;

% Plot individual beta values as scatter
scatter(ones(size(beta_vals)), beta_vals, 60, 'filled', 'MarkerFaceColor', [0.6 0.6 0.6]);

% Plot group mean ± SEM
errorbar(1.1, groupMean, groupSEM, 'bo', 'MarkerFaceColor', 'b', 'CapSize', 10, 'LineWidth', 1.5);

% Plot formatting
xlim([0.5 1.5]);
xticks(1);
xticklabels({'Pilot Group'});
ylabel('Regression Coefficient (Beta)');
title('Coupling Between Confidence and Action Updating');
yline(0, '--k');
ylim([-1 1]);
set(gca, 'FontSize', 12);

hold off;
