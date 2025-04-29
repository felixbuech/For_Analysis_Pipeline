
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


% Empirical LR calculation

% % Only values between 0 and 1 are viewd as valid resposnes 
% 
% % Extract
% predictionError = allSubBehavData.delta_t;  % X_t - b_t
% update = allSubBehavData.a_t;               % b_{t+1} - b_t
% 
% % Compute learning rate
% learningRate_rigid = update ./ predictionError;
% 
% % Step 1: Invalidate learning rates where prediction error is near zero
% learningRate_rigid(abs(predictionError) < 1e-6) = NaN;
% 
% % Step 2: Invalidate learning rates outside [0, 1]
% learningRate_rigid(learningRate_rigid < 0 | learningRate_rigid > 1) = NaN;
% 
% 
% % if we only use 0 to 1 as correct LR we exclude that much data:
% 
% % Total number of trials
% nTotalTrials = length(learningRate_rigid);
% 
% % Number of valid learning rates
% nValidLR_rigid = sum(~isnan(learningRate_rigid));
% 
% % Number of NaNs (invalid LRs)
% nInvalidLR_rigid = sum(isnan(learningRate_rigid));
% 
% % Percent invalid
% percentInvalid_rigid = (nInvalidLR_rigid / nTotalTrials) * 100;
% 
% % Display
% fprintf('Total trials: %d\n', nTotalTrials);
% fprintf('Valid learning rates: %d\n', nValidLR_rigid);
% fprintf('Invalid learning rates (NaN): %d (%.2f%%)\n', nInvalidLR_rigid, percentInvalid_rigid);
% 

%% Alternative Approach:

% % Define a still accaptable range: counted as valid: -0.1 and 1.1 
% 
% % Extract
% predictionError = allSubBehavData.delta_t;  % X_t - b_t
% update = allSubBehavData.a_t;               % b_{t+1} - b_t
% 
% % Compute learning rate
% learningRate_flex = update ./ predictionError;
% 
% % Step 1: Invalidate learning rates where prediction error is near zero
% learningRate_flex(abs(predictionError) < 1e-6) = NaN;
% 
% % Step 2: Invalidate learning rates outside [0, 1]
% learningRate_flex(learningRate_flex < -0.1 | learningRate_flex > 1.1) = NaN;
% 
% 
% % if we are a bit more flexible ans still count -0.1 - 1.1 as valid: we
% % exclude this much data:
% 
% % Total number of trials
% nTotalTrials = length(learningRate_flex);
% 
% % Number of valid learning rates
% nValidLR_flex = sum(~isnan(learningRate_flex));
% 
% % Number of NaNs (invalid LRs)
% nInvalidLR_flex = sum(isnan(learningRate_flex));
% 
% % Percent invalid
% percentInvalid_flex = (nInvalidLR_flex / nTotalTrials) * 100;
% 
% % Display
% fprintf('Total trials: %d\n', nTotalTrials);
% fprintf('Valid learning rates: %d\n', nValidLR_flex);
% fprintf('Invalid learning rates (NaN): %d (%.2f%%)\n', nInvalidLR_flex, percentInvalid_flex);
% 


%% And now the Vaghi et al. (2017) way: Exclude 99th percentile

% Extract
predictionError = allSubBehavData.delta_t;
update = allSubBehavData.a_t;

% Compute learning rate
learningRate_99 = update ./ predictionError;

% Step 1: Invalidate if prediction error is zero (or near-zero)
learningRate_99(abs(predictionError) < 1e-6) = NaN;

% Step 2: Find the 99th percentile threshold
percentile99 = prctile(learningRate_99, 99, 'all');  % across all subjects

% Step 3: Invalidate learning rates above 99th percentile
learningRate_99(learningRate_99 > percentile99) = NaN;

% (Optional) Also clean negative LRs if you want
learningRate_99(learningRate_99 < 0) = NaN;


%how much data is excluded: 

% Total number of trials
nTotalTrials = length(learningRate_99);

% Number of valid learning rates
nValidLR_99 = sum(~isnan(learningRate_99));

% Number of NaNs (invalid LRs)
nInvalidLR_99 = sum(isnan(learningRate_99));

% Percent invalid
percentInvalid_99 = (nInvalidLR_99 / nTotalTrials) * 100;

% Display
fprintf('Total trials: %d\n', nTotalTrials);
fprintf('Valid learning rates: %d\n', nValidLR_99);
fprintf('Invalid learning rates (NaN): %d (%.2f%%)\n', nInvalidLR_99, percentInvalid_99);



%% last but not least: the Marzuki et al. (2022) (VaghiLAB) way: exlude the 95th percentile

% % Extract
% predictionError = allSubBehavData.delta_t;
% update = allSubBehavData.a_t;
% 
% % Compute learning rate
% learningRate_marzuki = update ./ predictionError;
% 
% % Step 1: Invalidate if prediction error is zero (or near-zero)
% learningRate_marzuki(abs(predictionError) < 1e-6) = NaN;
% 
% % Step 2: Find the 99th percentile threshold
% percentile95 = prctile(learningRate_marzuki, 95, 'all');  % across all subjects
% 
% % Step 3: Invalidate learning rates above 99th percentile
% learningRate_marzuki(learningRate > percentile95) = NaN;
% 
% % (Optional) Also clean negative LRs if you want
% learningRate_marzuki(learningRate < 0) = NaN;
% 
% 
% %how much data is excluded: 
% 
% % Total number of trials
% nTotalTrials = length(learningRate_marzuki);
% 
% % Number of valid learning rates
% nValidLR_marzuki = sum(~isnan(learningRate_marzuki));
% 
% % Number of NaNs (invalid LRs)
% nInvalidLR_marzuki = sum(isnan(learningRate_marzuki));
% 
% % Percent invalid
% percentInvalid_marzuki = (nInvalidLR_marzuki / nTotalTrials) * 100;
% 
% % Display
% fprintf('Total trials: %d\n', nTotalTrials);
% fprintf('Valid learning rates: %d\n', nValidLR_marzuki);
% fprintf('Invalid learning rates (NaN): %d (%.2f%%)\n', nInvalidLR_marzuki, percentInvalid_marzuki);



%% Change-Point Anylsis 


% 2. Get ALL trials
c_t = allSubBehavData.c_t;  % full change point vector (no masking)

% 3. Find change points
changeIdx = find(c_t == 1);

% 4. Build peri-change-point learning rate matrix
nBefore = 4;
nAfter = 4;
windowSize = nBefore + 1 + nAfter;

periChangeLR = [];
nTrials = length(learningRate_99);

for i = 1:length(changeIdx)
    idx = changeIdx(i);

    % Check bounds
    if idx - nBefore >= 1 && idx + nAfter <= nTrials
        lrWindow = [learningRate_99(idx - nBefore : idx - 1); learningRate_99(idx + 1 : idx + nAfter)];

        periChangeLR = [periChangeLR; lrWindow'];
    end
end

% Build x-axis
xAxis = [-4, -3, -2, -1, 1, 2, 3, 4];

% Build periChangeLR (already done earlier)

% Compute mean and SEM
meanLR = mean(periChangeLR, 1, 'omitnan');
semLR = std(periChangeLR, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(periChangeLR), 1));  % use count per point

% Remove potential NaNs for plotting
validIdx = ~isnan(meanLR) & ~isnan(semLR);

xAxis_plot = xAxis(validIdx);
meanLR_plot = meanLR(validIdx);
semLR_plot = semLR(validIdx);

% Shaded area
xFill = [xAxis_plot, fliplr(xAxis_plot)];
yFill = [meanLR_plot + semLR_plot, fliplr(meanLR_plot - semLR_plot)];

% Now plot
figure;
hold on;

fill(xFill, yFill, [0.8 0.8 1], 'FaceAlpha', 0.5, 'EdgeColor', 'none');

plot(xAxis_plot, meanLR_plot, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');

% Vertical line at 0
xline(0, '--k', 'LineWidth', 1.5);

xlabel('Trials Relative to Change Point');
ylabel('Learning Rate');
title('Learning Rate Timecourse Around Change Points');
grid on;
xlim([-4 4]);
ylim([0 1]); % set higher for very noisy data
hold off;
