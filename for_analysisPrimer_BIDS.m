function for_analysisPrimer_BIDS
%% FOR_ANALYSISPRIMER_BIDS 
% This function provides an example on how confetti-cannon-task data can be 
% analyzed in Matlab using BIDS-formatted data.
%
% The code is based on Nassar, Bruckner, Frank (2019) eLife and applied to 
% confetti-cannon pilot data. Please note that this pipeline is not the full 
% analysis that you will apply to your full data sets.
%
% Also, please note that the methods can be improved in some cases, including 
% multiple starting points for regression estimation. We are also planning to 
% use the BIDS standard, and soon provide code to translate data to BIDS. Please 
% run these types of analyses with BIDS-formatted data in the future.
%
% Moreover, please note that the way cannon data is organized is a bit 
% different. We actually simplified the data class and translated everything 
% into a structure with slightly updated variable names (this is why you 
% currently need the al_taskDataMain.m class).
%
% Another important analysis that we're not covering today is validating 
% the regression based on the RBM simulations, where we know what the 
% coefficients should look like. Similarly, it is important that we add 
% parameter recovery analyses later on.
% 
% Disclaimer: As always, be sure to critically check everything and 
% don't just assume the code is working perfectly. This is supposed to be 
% a primer and a paper requires additional analyses and validation checks.
%
% Main steps:
%   1. Prepare analyses
%   2. Run analyses
%   3. Plot results

%% 1. Prepare analyses

clear all
close all

% Set BIDS directory where data are stored in BIDS format.
parentDirectory = fileparts(mfilename('fullpath'));
bidsDir = fullfile(parentDirectory, 'helicopter', 'for_bids_data');

% List subject folders (assumed to be named like 'sub_01', 'sub_02', etc.)
subFolders = dir(fullfile(bidsDir, 'sub_*'));
subFolders = subFolders([subFolders.isdir]);

% Preallocate a variable to hold combined subject data
allSubBehavData = [];

%% 2. Run Analyses

for s = 1:length(subFolders)
    
    subFolder = subFolders(s).name;
    fprintf('Starting subject: %s\n', subFolder);
    
    behavDir = fullfile(bidsDir, subFolder, 'behav');
    % Assume file is named like: sub_XX_task-cannon_behav.tsv
    behavFile = fullfile(behavDir, [subFolder, '_task-cannon_behav.tsv']);
    
    if ~exist(behavFile, 'file')
        warning('Behavioral file not found: %s', behavFile);
        continue;
    end
    
    T = readtable(behavFile, 'FileType', 'text', 'Delimiter', '\t');
    
    % Convert table to structure array (one element per trial)
    allBehavData = table2struct(T, 'ToScalar', false);
    
    % --- Combine structure array into a scalar structure ---
    fields = fieldnames(allBehavData);
    combinedData = struct();
    for iField = 1:length(fields)
        currentField = fields{iField};
        try
            combinedData.(currentField) = vertcat(allBehavData.(currentField));
        catch
            combinedData.(currentField) = cell2mat({allBehavData.(currentField)});
        end
    end
    allBehavData = combinedData;
    % ---------------------------------------------------------
    
    % Use the BIDS field names:
    % x_t: current outcome, b_t: current prediction, a_t: update,
    % cp: change point remains as is, kappa_t: concentration, r_t: hit,
    % v_t: catch trials.
    
    % Recode outcome: change 360 to 0
    allSub = allBehavData.x_t;
    allSub(allSub == 360) = 0;
    allBehavData.x_t = allSub;
    
    % Add subject number (extract numeric part from 'sub_XX')
    subNum = sscanf(subFolder, 'sub_%d');
    allBehavData.subNum = repmat(subNum, length(allBehavData.x_t), 1);
    
    % Flatten structure (assuming straightStruct is available)
    allBehavData = straightStruct(allBehavData);
    
    % Identify blocks (assuming block field remains the same)
    newBlock = [true; diff(allBehavData.block) ~= 0];
    newB = find(newBlock(1:end));
    blockCond = ones(length(allBehavData.x_t),1);
    
    % Compute empirical hazard rate and get noise from condition.
    % (Assuming cp field is still named 'cp')
    simHaz = mean(nanmean(allBehavData.cp));
    simNoise = unique(allBehavData.kappa_t);
    
    % Compute circular prediction error (PE) using x_t and b_t:
    outcomeRad = deg2rad(allBehavData.x_t);
    predRad = deg2rad(allBehavData.b_t);
    % Compute update (UP) from consecutive predictions (assuming a_t is available):
    origUP = deg2rad(allBehavData.a_t);
    % Compute prediction error (PE) as circular distance:
    PE = circ_dist(outcomeRad, predRad);
    % Compute update as difference between consecutive predictions:
    UP = [circ_dist(predRad(2:end), predRad(1:end-1)); nan];
    UP(newB(2:end)-1) = nan;
    
    % Get RT (same field name)
    RT = allBehavData.RT;
    
    % Translate van Mises concentration into Gaussian standard deviation.
    vmVar = 1 ./ allBehavData.kappa_t;
    gaussStd = vmVar .^ 0.5;
    gaussDriftStd = nan(1, length(outcomeRad));
    
    % Hit field: use r_t
    hit = allBehavData.r_t;
    
    % Compute useful averages (these remain as in your original script)
    meanHit = nanmean(hit);
    meanUP = nanmean(abs(UP));
    meanPE = nanmean(abs(PE));
    meanPE_deg = nanmean(abs(rad2deg(PE)));
    meanRT = nanmean(RT);
    
    % Condition-specific variables for noise types (if needed)
    if simNoise == 8
        % (Store if needed.)
    elseif simNoise == 16
        % (Store if needed.)
    end
    
    % Get surprise and relative uncertainty from optimal model
    [modSurp, modRU, ~, errBased_UP] = getTrialVarsFromPEs_cannon(...
        gaussStd, PE, simHaz, newBlock', false, ...
        0.99, 0, 1, 1, gaussDriftStd, ~blockCond, 2*pi);
    
    % Plug new variables back into structure
    allBehavData.modPred = predRad + errBased_UP;
    allBehavData.modSurp = modSurp;
    allBehavData.modRU = modRU;
    % Use length of x_t for replication
    allBehavData.subNum = repmat(subNum, length(allBehavData.x_t), 1);
    allBehavData.UP = UP;
    allBehavData.PE = PE;
    % Compute ST_LR (using update and prediction error)
    % Note: origUP was taken from a_t. Here we compute ST_LR accordingly.
    allBehavData.ST_LR = UP ./ PE;
    allBehavData.ST_LR = origUP(2:end) ./ PE(1:end-1);
    
    allBehavData = straightStruct(allBehavData);
    
    % Combine subject data
    if s == 1
        combinedData = allBehavData;
    else
        combinedData = catBehav(allBehavData, combinedData);
    end
    close all
end

allSubBehavData = combinedData;

% Extract subject IDs
allID = unique(allSubBehavData.ID);

% Preallocate regression variables (only for trials with updates)
subBehavConc_anyUp = nan(length(allID),1);
subBehavCoeffs_anyUp = nan(length(allID),5);

% Ensure IDs are numeric
if iscell(allSubBehavData.ID)
    allSubBehavData.ID = cellfun(@str2double, allSubBehavData.ID);
end

allID = unique(allSubBehavData.ID);
allID(isnan(allID)) = [];

% Cycle over subjects and run circular regression model
for h = 1:length(allID)
    sel = allSubBehavData.ID == allID(h);
    
    % Extract variables for regression:
    PE = allSubBehavData.PE(sel);
    UP = allSubBehavData.UP(sel);
    modRU = allSubBehavData.modRU(sel);
    modSurp = allSubBehavData.modSurp(sel);
    % Use r_t for hit, and kappa_t for concentration:
    hit = allSubBehavData.r_t(sel);
    concentration = allSubBehavData.kappa_t(sel);
    
    % Regression model parameters: [Intercept, PE, PE*RU, PE*Surp, PE*Hit, PE*concentration]
    rawX = [ones(size(PE)), PE, modRU .* PE, modSurp .* PE, PE .* hit, PE .* concentration];
    sel = isfinite(UP) & all(isfinite(rawX), 2);
    anyUp = UP ~= 0;
    data.Y = UP(sel);
    data.X = rawX(sel,:);
    data.priorWidth = ones(1, size(rawX(sel,:),2)) * 5;
    data.priorMean = [0, 0.5, 0, 0, 0, 0];
    data.startPoint = [0, 0, 0, 0, 0, 0, 0];
    data.includeUniform = 0;
    
    sel = sel & anyUp;
    data.Y = UP(sel);
    data.X = rawX(sel,:);
    data.multiStart = false;
    [params, negLogLike] = fitLinearModWCircErrs(data);
    
    subBehavConc_anyUp(h) = params(1);
    subBehavCoeffs_anyUp(h,1:6) = params(2:end);
end

%% 3. Plot Analyses

% Learning-rate schematic
exPE = -pi:0.1:pi;
simUncCP = nanmean(allSubBehavData.modRU);
errBased_LR_CP = nan(size(exPE));
for i = 1:length(exPE)
    [modSurp, modRU, errBased_LR_CP(i), errBased_UP] = getTrialVarsFromPEs_cannon(...
        gaussStd(1), exPE(i), simHaz, true, false, ...
        simUncCP, 0, 1, 1, gaussDriftStd(1), false, 2*pi);
end

figure
hold on
plot([-pi, pi], [-pi, pi], '--k')
plot([-pi, pi], [0, 0], '--k')
for i = 0.1:0.1:0.9
    plot([-pi, pi], i * [-pi, pi], 'color', [0.5 0.5 0.5]);
end
plot(exPE, exPE .* errBased_LR_CP, 'color', 'r')
ylabel('Update')
xlabel('Prediction Error')
set(gca, 'box', 'off')

% Compare conditions (assuming al_compareConditions is compatible)
al_compareConditions(PE_16, PE_8)
title('Prediction Error (Radians)')
ylabel('Prediction Error')
al_compareConditions(PE_deg_16, PE_deg_8)
title('Prediction Error (Degrees)')
ylabel('Prediction Error')
al_compareConditions(hit_16, hit_8)
title('Hits')
ylabel('Probability')

% Quick model variable check plots
figure
subplot(3,1,1)
subSel = allSubBehavData.subNum == 7;
hold on
plot(allSubBehavData.mu_t(subSel), '--', 'color', 'r')  % using mu_t for cannon aim
plot(allSubBehavData.x_t(subSel), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'LineWidth', 1)
plot(allSubBehavData.b_t(subSel), '-', 'color', 'b')
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

% Summary plot regression results
varNormCoeffs = subBehavCoeffs_anyUp(:,1:end-1) ./ repmat(std(subBehavCoeffs_anyUp(:,1:end-1)), size(subBehavCoeffs_anyUp(:,1:end-1), 1), 1);
figure
behavLabels = {'Int', 'PE', 'PE*RU', 'PE*surp', 'PE*Noise'};
xJit = smartJitter(varNormCoeffs, 0.1, 0.4);
[r, p] = corr(subBehavCoeffs_anyUp(:,1:end-1));
ll = size(varNormCoeffs, 1);
plot([0, size(subBehavCoeffs_anyUp,2)], [0 0], '--k')
hold on
for i = 1:size(varNormCoeffs,2)
    plot(ones(ll,1).*i + xJit(:,i), subBehavCoeffs_anyUp(:,i), 'o', ...
        'MarkerSize', 10, 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'k', 'LineWidth', 1);
end
ylabel('Coefficient')
set(gca, 'XTick', 1:length(behavLabels), 'XTickLabel', behavLabels, 'box', 'off')

% Summary plot regression results with connecting lines
varNormCoeffs = subBehavCoeffs_anyUp(:,1:end-1) ./ repmat(std(subBehavCoeffs_anyUp(:,1:end-1)), size(subBehavCoeffs_anyUp(:,1:end-1), 1), 1);
figure;
hold on
behavLabels = {'Int', 'PE', 'PE*RU', 'PE*surp', 'PE*Noise'};
xJit = smartJitter(varNormCoeffs, 0.1, 0.4);
[r, p] = corr(subBehavCoeffs_anyUp(:,1:end-1));
ll = size(varNormCoeffs, 1);
plot([0, size(subBehavCoeffs_anyUp,2)], [0 0], '--k')
for subj = 1:ll
    numCoeffs = size(varNormCoeffs,2);
    xVals = (1:numCoeffs) + xJit(subj,1:numCoeffs);
    yVals = subBehavCoeffs_anyUp(subj,1:numCoeffs);
    if length(xVals) ~= length(yVals)
        warning(['Size mismatch for subject ', num2str(subj)]);
        continue;
    end
    plot(xVals, yVals, '-k', 'LineWidth', 1, 'Color', [0.6 0.6 0.6]);
    plot(xVals, yVals, 'o', 'MarkerSize', 10, 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'k', 'LineWidth', 1);
end
ylabel('Coefficient')
set(gca, 'XTick', 1:length(behavLabels), 'XTickLabel', behavLabels, 'box', 'off')
hold off

end

% function al_compareConditions(inputData1, inputData2)
% (Commented out: unchanged)
