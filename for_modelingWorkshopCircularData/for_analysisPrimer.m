function for_analysisPrimer
%%FOR_ANALYSISPRIMER This function provides an example on how
% confetti-cannon-task data can be analyzen in Matlab
%
% The code is based an Nassar, Bruckner, Frank (2019) eLife and applied to
% confetti-cannon pilot data. Please note that this pipeline is not the
% full analysis that you will apply to your full data sets.
%
% Also, please note that the methods can be improved in some cases,
% including multiple starting points for regression estimation. We are also
% planning to use the BIDS standard, and soon provide code to translate
% data to BIDS. Please run these types of analyses with BIDS-formatted data
% in the future.
%
% Moreover, please note that the way cannon data is organized is not a bit
% different. We actually simplified the data class and translated everthing
% into a structure with slightly updated variable names (this is why you
% currently need the al_taskDataMain.m class).
%
% Another important analysis that we're not covering today is validating
% the regression based on the RBM simulations, where we know what the
% coefficients should look like. Similarly, it is important that we add
% parameter recovery analyses later on.
% 
% Disclaimer: As always, be sure to critically check everything and
% dont't just assume the code is working perfectly. This is supposed to be
% a primer and a paper requires additional analyes and validation checks.
%
% Main steps:
%   1. Prepare analyses
%   2. Run analyses
%   3. Plot results


% -------------------
% 1. Prepare analyses
% -------------------

% Clear workspace
clear all
close all

% Data directory with example data (not yet in BIDS)
% Todo: Use BIDS in future
currentDir = '/Users/felix/Desktop/for_Pilot_analysis/data_Pilot1/rawDataforBIDS';
addpath(currentDir);

% Select data files
whichFilenames = dir(fullfile(currentDir, '*confetti*'));
allFilenames = {whichFilenames.name};

% ---------------
% 2. Run Analyses
% ---------------

% Counter for condition to deal with potentially missing conditions
counter8 = 0;
counter16 = 0;

% Preallocate some variables
meanHit = nan(length(allFilenames),1);
hit_16 = nan(length(allFilenames)/2,1);
hit_8 = nan(length(allFilenames)/2,1);
meanUP = nan(length(allFilenames),1);
meanPE = nan(length(allFilenames),1);
PE_16 = nan(length(allFilenames)/2,1);
PE_8 = nan(length(allFilenames)/2,1);
meanPE_deg = nan(length(allFilenames),1);
PE_deg_16 = nan(length(allFilenames)/2,1);
PE_deg_8 = nan(length(allFilenames)/2,1);
meanRT = nan(length(allFilenames),1);

% Cycle over filenames
for j = 1:length(allFilenames)

    % Select current subject
    currentFilename = allFilenames{j};
    subID = currentFilename(end-8:end-4); % in FOR, ID currently at the end
    fprintf('starting subject: %s\n', num2str(subID)); % inform user

    % Load data
    behavData = load(currentFilename);

    % Put data in struct
    clear allBehavData
    eval(sprintf('allBehavData=behavData.taskData;'));
    allBehavData = straightStruct(allBehavData);

    % Identify blocks
    newBlock = [true; diff(allBehavData.block) ~= 0];
    newB = find(newBlock(1:end));
    blockCond = ones(length(allBehavData.outcome),1);
    allBehavData.outcome(allBehavData.outcome == 360) = 0; % recode 360 to 0

    % Empirical hazard rate
    simHaz = mean(nanmean(allBehavData.cp));

    % Get noise from condition
    simNoise = unique(allBehavData.concentration);

    % Compute circular PE and UP:
    outcomeRad = deg2rad(allBehavData.outcome);
    predRad = deg2rad(allBehavData.pred);
    origUP = deg2rad(allBehavData.UP);
    origPE = deg2rad(allBehavData.predErr);
    PE = circ_dist(outcomeRad, predRad);
    UP = [circ_dist(predRad(2:end), predRad(1:end-1)); nan];
    UP(newB(2:end)-1) = nan; % ensure that update is nan on last trial

    % Get RT
    RT = allBehavData.RT;

    % Translate van Mises concentration into Gaussin standard deviation
    vmVar = 1./allBehavData.concentration;
    gaussStd = vmVar.^.5;
    gaussDriftStd = nan(1, length(outcomeRad));

    % Catch trial and hit
    allHeliVis = false(size(PE));
    hit = allBehavData.hit;

    % Some usefuls averages
    meanHit(j) = nanmean(hit);
    meanUP(j) = nanmean(abs(UP));
    meanPE(j) = nanmean(abs(PE));
    meanPE_deg(j) = nanmean(abs(rad2deg(PE)));
    meanRT(j) = nanmean(RT);

    % Compute condition-specific variables (for different noise types)
    if simNoise == 8
        counter8 = counter8 + 1;
        PE_8(counter8) = meanPE(j);
        PE_deg_8(counter8) = meanPE_deg(j);
        hit_8(counter8) = meanHit(j);
    elseif simNoise == 16
        counter16 = counter16 + 1;
        PE_16(counter16) = meanPE(j);
        PE_deg_16(counter16) = meanPE_deg(j);
        hit_16(counter16) = meanHit(j);
    end

    % Get surprise and relative uncertainty from optimal model
    [modSurp, modRU, ~, errBased_UP] = getTrialVarsFromPEs_cannon...
        (gaussStd, PE, simHaz,  newBlock', allHeliVis,...
        .99, 0, 1, 1, gaussDriftStd, ~blockCond, 2*pi);

    % Plug new variables back into data structure
    allBehavData = struct(allBehavData);
    allBehavData.modPred = predRad+errBased_UP;
    allBehavData.modSurp = modSurp;
    allBehavData.modRU = modRU;
    allBehavData.subNum = repmat(j, length(allBehavData.rew), 1);
    allBehavData.UP = UP;
    allBehavData.PE = PE;
    allBehavData.ST_LR = UP./PE;
    allBehavData.ST_LR = origUP(2:end)./origPE(1:end-1);

    % hist(allBehavData.ST_LR, 100)
    allBehavData = straightStruct(allBehavData);

    % Combine data of all subjects
    if j ==1
        allSubBehavData = allBehavData;
    else
        allSubBehavData = catBehav(allBehavData, allSubBehavData);
    end
    close all
end

% Extract all subject IDs
allID = unique(allSubBehavData.ID);

% Preallocate regression variables only including trials with updates
subBehavConc_anyUp = nan(length(allID),1);
subBehavCoeffs_anyUp = nan(length(allID),5);

% Ensure IDs are numeric
if iscell(allSubBehavData.ID)
    allSubBehavData.ID = cellfun(@str2double, allSubBehavData.ID);
end

% Get unique subject IDs
allID = unique(allSubBehavData.ID);
allID(isnan(allID)) = [];  % Remove NaNs


% Cycle over subjects and fit circular regression model
for h=1:length(allID)

    % Select current subject
    sel = allSubBehavData.ID == allID(h);

    % Extract variables for regression model
    PE = allSubBehavData.PE(sel);
    UP = allSubBehavData.UP(sel);
    modRU = allSubBehavData.modRU(sel);
    modSurp = allSubBehavData.modSurp(sel);
    hit = allSubBehavData.hit(sel);
    concentration = allSubBehavData.concentration(sel);

    % Run regression model
    % Parameters:
    % 1) concentration
    % 2) intercept
    % 3) PE
    % 4) RU
    % 5) CPP
    % 6) Hit
    % 7) Concentration

    % There are different ways to do this: without mean centering,
    % regression is closer to RBM but we also use mean centering to
    % ensure that results are similar. In Python version, we also
    % correct surprise in cases where surprise + relative uncertainty > 1
    % Also, currently no catch trials considered. Here w/o mean centering

    rawX = [ones(size(PE)), PE, modRU .* PE, modSurp .* PE, PE.* hit, PE.* concentration];
    sel = isfinite(UP) & all(isfinite(rawX), 2);
    anyUp = UP~=0;
    data.Y = UP(sel);
    data.X = (rawX(sel,:));
    data.priorWidth = ones(1, size((rawX(sel,:)), 2)).*5;
    data.priorMean =  [0, 0.5 ,0, 0, 0, 0];
    data.startPoint = [0, 0,   0, 0, 0, 0, 0];
    data.includeUniform = 0; % don't include uniform for now

    % Only include updates in this version
    sel = sel & anyUp;
    data.Y = UP(sel);
    data.X = (rawX(sel,:));
    data.multiStart = false;
    [params, negLogLike] = fitLinearModWCircErrs(data);

    subBehavConc_anyUp(h) = params(1);
    subBehavCoeffs_anyUp(h,1:6) = params(2:end);

end

% ----------------
% 3. Plot Analyses
% ----------------

% Learning-rate schematic
% -----------------------
exPE = -pi:.1:pi;
simUncCP = nanmean(allBehavData.modRU);

errBased_LR_CP = nan;
for i = 1:length(exPE)
    [modSurp, modRU, errBased_LR_CP(i), errBased_UP] = getTrialVarsFromPEs_cannon...
        (gaussStd(1), exPE(i), simHaz,  true, false,...
        simUncCP, 0, 1, 1, gaussDriftStd(1), false, 2*pi);
end

hold on
plot([-pi, pi], [-pi, pi], '--k')
plot([-pi, pi], [0, 0], '--k')
for i = .1:.1:.9
    plot([-pi, pi], i.*[-pi, pi]+ (1-i).* [0, 0], 'color', [.5 .5 .5]);
end
plot(exPE, exPE.*errBased_LR_CP, 'color', 'r')
ylabel('Update')
xlabel('Prediction Error')
set(gca, 'box', 'off')

% Updates and prediction errors
% -----------------------------

al_compareConditions(PE_16, PE_8)
title('Prediction Error (Radians)')
ylabel('Prediction Error')

al_compareConditions(PE_deg_16, PE_deg_8);
title('Prediction Error (Degrees)')
ylabel('Prediction Error')

al_compareConditions(hit_16, hit_8);
title('Hits')
ylabel('Probability')

% Quickly check model variables
% -----------------------------

figure
subplot(3, 1, 1)
subSel=allSubBehavData.subNum==7;
hold on
plot(allSubBehavData.distMean(subSel), '--', 'color', 'r');
plot(allSubBehavData.outcome(subSel), 'o', 'markerSize', 8,...
    'markerFaceColor', 'g', 'markerEdgeColor', 'k', 'lineWidth', 1);
plot(allSubBehavData.pred(subSel), '-', 'color', 'b');
plotCatch = allSubBehavData.catchTrial(subSel);
plotCatch(plotCatch == 0) = nan;
catchPred = allSubBehavData.distMean(subSel);
catchPred(isnan(plotCatch)) = nan;
plot(catchPred, 'o', 'color', 'm');
ylabel('Angle (deg)')
xlabel('Trial')
set(gca, 'box', 'off')

subplot(3, 1, 2)
plot(rad2deg(allSubBehavData.PE(subSel)), '-', 'color', 'r');
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
% -------------------------------

% Variability of coefficients for jittering
varNormCoeffs=subBehavCoeffs_anyUp(:,1:end-1)./repmat((std(subBehavCoeffs_anyUp(:,1:end-1))), size(subBehavCoeffs_anyUp(:,1:end-1), 1), 1);

figure
behavLabels={'Int', 'PE', 'PE*RU', 'PE*surp', 'PE*Noise'};
xJit = smartJitter(varNormCoeffs,.1,.4);
[r, p]=corr(subBehavCoeffs_anyUp(:,1:end-1));
ll=size(varNormCoeffs, 1);
plot([0, size(subBehavCoeffs_anyUp, 2)], [0 0], '--k')

hold on
for i = 1:size(varNormCoeffs, 2)
    plot(ones(ll, 1).*i+xJit(:,i), subBehavCoeffs_anyUp(:,i), 'o',...
        'markerSize', 10, 'markerFaceColor','b',...
        'markerEdgeColor', 'k', 'lineWidth', 1);
end
ylabel('Coefficient')
set(gca, 'xtick', 1:size(behavLabels, 2),...
    'xticklabel', behavLabels, 'box', 'off')


% Summary plot regression results with Lines between observations
% -------------------------------

% Variability of coefficients for jittering
varNormCoeffs = subBehavCoeffs_anyUp(:,1:end-1) ./ ...
    repmat(std(subBehavCoeffs_anyUp(:,1:end-1)), size(subBehavCoeffs_anyUp(:,1:end-1), 1), 1);

% Figure setup
figure;
hold on

% Labels for X-axis
behavLabels = {'Int', 'PE', 'PE*RU', 'PE*surp', 'PE*Noise'};
xJit = smartJitter(varNormCoeffs, .1, .4);  % Jitter for better visibility

% Correlation for reference (not modified)
[r, p] = corr(subBehavCoeffs_anyUp(:,1:end-1));
ll = size(varNormCoeffs, 1);

% Plot zero-reference line
plot([0, size(subBehavCoeffs_anyUp, 2)], [0 0], '--k')

% Iterate over subjects and plot **connected lines**
for subj = 1:ll
    % Ensure xVals and yVals have matching dimensions
    numCoeffs = size(varNormCoeffs, 2);
    xVals = (1:numCoeffs) + xJit(subj, 1:numCoeffs); % X positions
    yVals = subBehavCoeffs_anyUp(subj, 1:numCoeffs); % Coefficient values

    % Check that xVals and yVals are the same size
    if length(xVals) ~= length(yVals)
        warning(['Size mismatch for subject ', num2str(subj)]);
        continue; % Skip this iteration if there's a size mismatch
    end

    % **Plot connecting lines for each subject**
    plot(xVals, yVals, '-k', 'LineWidth', 1, 'Color', [0.6 0.6 0.6]); % Gray lines

    % **Plot individual subject markers**
    plot(xVals, yVals, 'o', 'MarkerSize', 10, 'MarkerFaceColor', 'b', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1);
end

% Axis Labels & Formatting
ylabel('Coefficient')
set(gca, 'XTick', 1:size(behavLabels, 2), ...
    'XTickLabel', behavLabels, 'Box', 'off')

hold off



end

% function al_compareConditions(inputData1, inputData2)
% %AL_COMPARECONDITIONS This function creates a bar plot of differences between two conditions
% 
% % Data of the 2 conditions
% dat = [inputData1 inputData2];
% 
% % Variability for jitter
% varCoeffs=dat./repmat((std(dat)), size(dat, 1), 1);
% xJit = smartJitter(varCoeffs,.1,.4);
% ll=size(dat, 1);
% 
% % Mean + SEM
% data1_mean = mean(inputData1);
% data1_stErr = std(inputData1)/sqrt(length(inputData1));
% data2_mean = mean(inputData2);
% data2_stErr = std(inputData2)/sqrt(length(inputData2));
% 
% % Plot stuff
% figure
% hold on
% bar([1,2], [data1_mean, data2_mean])
% for i = 1:size(dat, 2)
%     plot(ones(ll, 1).*i+xJit(:,i),...
%         dat(:,i), 'o',...
%         'markerSize', 10, 'markerFaceColor','b',...
%         'markerEdgeColor', 'k', 'lineWidth', 1);
% end
% plot([1 1],[data1_mean + data1_stErr/2, data1_mean - data1_stErr/2], 'k', 'linewidth',2)
% plot([2 2],[data2_mean + data2_stErr/2, data2_mean - data2_stErr/2], 'k', 'linewidth',2)
% behavLabels={'Low Noise', 'High Noise'};
% set(gca, 'xtick', 1:size(behavLabels, 2), 'xticklabel', behavLabels, 'box', 'off')
% 
% end

