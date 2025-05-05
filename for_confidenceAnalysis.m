% Identify parent directory of this config script
parentDirectory = 'C:\Users\fb74loha\Desktop\For_Analysis_Clone\for_analysisPipeline';
cd(parentDirectory)
addpath(genpath(parentDirectory));

% This is the BIDS folder
bidsDir = strcat(parentDirectory, filesep, 'Leipzig', filesep, 'for_pilot_data', filesep, 'helicopter', filesep, 'for_bids_data');

% ----------------
% 1. Preprocessing
% ----------------

% Run preprocessing to get all behavioral data
allSubBehavData = for_preprocessing(bidsDir);

% Number of subjects
n_subj = length(unique(allSubBehavData.ID));


% Find trials where a confidence response was made
validTrials = ~isnan(allSubBehavData.confidenceRT);  % true if response time is NOT NaN

% Select only real confidence ratings
confValues = allSubBehavData.confidence(validTrials);

% Histogram of all confidence Ratings
figure;
histogram(confValues, 'BinWidth', 1, 'Normalization', 'probability');
xlabel('Confidence Rating');
ylabel('Proportion of Trials');
title('Distribution of Confidence Ratings');
grid on;


% Plot for each subject individually:
subjectIDs = unique(allSubBehavData.ID);  
nSubjects = length(subjectIDs);

nCols = ceil(sqrt(nSubjects));
nRows = ceil(nSubjects / nCols);

figure;
for s = 1:nSubjects
    subjMask = allSubBehavData.ID == subjectIDs(s);  
    subjectValidTrials = subjMask & ~isnan(allSubBehavData.confidenceRT);  % <-- use different name here

    subjConfValues = allSubBehavData.confidence(subjectValidTrials);

    subplot(nRows, nCols, s);
    histogram(subjConfValues, 'BinWidth', 1, 'Normalization', 'probability');
    title(sprintf('Subject %d', subjectIDs(s)));
    xlabel('Confidence');
    ylabel('Proportion');
    xlim([min(allSubBehavData.confidence), max(allSubBehavData.confidence)]);
    ylim([0 1]); 
end

sgtitle('Confidence Histograms Per Subject');


%---------------------------------------------------------------------

% looking at confidence before and after a changepoint 

% ==========================
% CHANGE-POINT ANALYSIS
% ==========================

% Step 1: Z-score confidence per subject
subjectIDs = unique(allSubBehavData.ID);
nSubjects = length(subjectIDs);

confZ = NaN(size(allSubBehavData.confidence));  % initialize

for s = 1:nSubjects
    subjID = subjectIDs(s);

    % Select this subject's valid trials (confidenceRT not NaN)
    subjMask = allSubBehavData.ID == subjID & ~isnan(allSubBehavData.confidenceRT);

    subjConf = allSubBehavData.confidence(subjMask);

    % Z-score
    subjConfZ = (subjConf - mean(subjConf, 'omitnan')) / std(subjConf, 'omitnan');

    % Fill back into full vector
    confZ(subjMask) = subjConfZ;
end

% Step 2: Extract valid trials after z-scoring
validTrials = ~isnan(allSubBehavData.confidenceRT);  % true for real confidence trials
confValues_z = confZ(validTrials);                     % z-scored confidence values
c_t_valid = allSubBehavData.c_t(validTrials);         % aligned change point indicator

% Step 3: Find change points
changeIdx = find(c_t_valid == 1);

% Parameters
nBefore = 5;
nAfter = 5;
windowSize = nBefore + 1 + nAfter;  

% Step 4: Build peri-change-point confidence matrix
periChangeConf = [];  % Each row = one change point window
nTrials = length(confValues_z);

for i = 1:length(changeIdx)
    idx = changeIdx(i);

    % Make sure window is inside bounds
    if idx - nBefore >= 1 && idx + nAfter <= nTrials
        confWindow = confValues_z(idx - nBefore : idx + nAfter);  % extract window
        periChangeConf = [periChangeConf; confWindow'];         % stack as rows
    end
end

% Step 5: Compute mean across all change points
meanConf = mean(periChangeConf, 1, 'omitnan');  % mean across rows
semConf = std(periChangeConf, 0, 1, 'omitnan') ./ sqrt(size(periChangeConf, 1));  % SEM across rows Standard Error of the Mean: How much uncertainty about the mean

xAxis = -nBefore:nAfter;

% Step 6: Plot
figure;
hold on;

% Shaded error bars manually
fill([xAxis, fliplr(xAxis)], [meanConf + semConf, fliplr(meanConf - semConf)], ...
     [0.8 0.8 1], 'FaceAlpha', 0.5, 'EdgeColor', 'none');  % light blue shading

plot(xAxis, meanConf, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');

% Vertical line at CP
xline(0, '--k', 'LineWidth', 1.5);

% Labels and styling
xlabel('Trials Relative to Change Point');
ylabel('Z-scored Confidence Rating');
title('Confidence Timecourse Around Change Points (Z-scored)');
grid on;
xlim([-nBefore nAfter]);
ylim([-2 2]);  % Adjust depending on real z-score spread
hold off;
