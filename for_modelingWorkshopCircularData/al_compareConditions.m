function al_compareConditions(inputData1, inputData2)
%AL_COMPARECONDITIONS This function creates a bar plot of differences between two conditions

% Data of the 2 conditions
dat = [inputData1 inputData2];

% Variability for jitter
varCoeffs=dat./repmat((std(dat)), size(dat, 1), 1);
xJit = smartJitter(varCoeffs,.1,.4);
ll=size(dat, 1);

% Mean + SEM
data1_mean = mean(inputData1);
data1_stErr = std(inputData1)/sqrt(length(inputData1));
data2_mean = mean(inputData2);
data2_stErr = std(inputData2)/sqrt(length(inputData2));

% Plot stuff
figure
hold on
bar([1,2], [data1_mean, data2_mean])
for i = 1:size(dat, 2)
    plot(ones(ll, 1).*i+xJit(:,i),...
        dat(:,i), 'o',...
        'markerSize', 10, 'markerFaceColor','b',...
        'markerEdgeColor', 'k', 'lineWidth', 1);
end
plot([1 1],[data1_mean + data1_stErr/2, data1_mean - data1_stErr/2], 'k', 'linewidth',2)
plot([2 2],[data2_mean + data2_stErr/2, data2_mean - data2_stErr/2], 'k', 'linewidth',2)
behavLabels={'Low Noise', 'High Noise'};
set(gca, 'xtick', 1:size(behavLabels, 2), 'xticklabel', behavLabels, 'box', 'off')

end