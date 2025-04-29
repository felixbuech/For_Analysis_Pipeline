function for_compare_model_confidence(df_data, allSubBehavData)
% Compare model confidence (from RBM) to actual participant confidence ratings
%
% Input:
%   df_data: output from for_simulation (with confidence_model column)
%   allSubBehavData: preprocessed subject data (with confidence ratings)
%
% Output:
%   Scatter plots and correlation summary for each subject

% Get subject IDs
subjectIDs = intersect(unique(df_data.ID), unique(allSubBehavData.ID));

% Initialize correlation results
correlations = NaN(length(subjectIDs), 1);

% Loop over subjects
for i = 1:length(subjectIDs)
    subj = subjectIDs(i);
    
    % Get subject's data
    modelIdx = df_data.ID == subj;
    humanIdx = allSubBehavData.ID == subj;

    modelConf = df_data.confidence_model(modelIdx);
    humanConf = allSubBehavData.confidence(humanIdx);

    % Match trial lengths
    n = min(length(modelConf), length(humanConf));
    modelConf = modelConf(1:n);
    humanConf = humanConf(1:n);

    % Only valid human ratings
    valid = ~isnan(humanConf);

    if sum(valid) > 5
        % Compute correlation
        r = corr(modelConf(valid), humanConf(valid), 'rows', 'complete');
        correlations(i) = r;
    else
        r = NaN;
    end

    % Plot
    figure;
    scatter(modelConf(valid), humanConf(valid), 30, 'filled');
    xlabel('Model Confidence');
    ylabel('Human Confidence');
    title(sprintf('Subject %d — r = %.2f', subj, r));
    xlim([0 1]); ylim([0 100]);
    grid on;
end

% Print group result
fprintf('-------------------------------\n');
fprintf('Average r across subjects: %.2f\n', mean(correlations, 'omitnan'));
fprintf('Valid subjects: %d of %d\n', sum(~isnan(correlations)), length(subjectIDs));
fprintf('-------------------------------\n');
end
