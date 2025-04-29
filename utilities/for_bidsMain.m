function for_bidsMain(dataDir, bidsDir)
% FOR_BIDSMAIN This function converts cannon data to BIDS format
%
%   Input
%       dataDir: Directory with raw data
%       bidsDir: Directory for BIDS data
%
%   Output
%       None

% Add data directory and jsonlab library
addpath(genpath(dataDir));
addpath(genpath('JSONLAB'));

% Define task pattern for selecting experimental files
taskPattern = '_exp';  % Match any task ending with '_exp'

% Extract all .mat files
whichFiles = dir(fullfile(dataDir, '*.mat'));
fileNames = {whichFiles.name};

% Select only experimental files
isExperiment = contains(fileNames, taskPattern, 'IgnoreCase', true);
experimentFiles = whichFiles(isExperiment);

% Extract subject IDs
subjectIDs = cell(size(experimentFiles));
for i = 1:length(experimentFiles)
    % Get subject ID (e.g., 99030) from filename
    tokens = regexp(experimentFiles(i).name, '_g\d+_conc\d+_(\d+)_b\d+\.mat$', 'tokens');
    if ~isempty(tokens)
        subjectIDs{i} = tokens{1}{1};
    else
        subjectIDs{i} = '';
    end
end

% Unique subject list
uniqueSubjects = unique(subjectIDs(~cellfun(@isempty, subjectIDs)));

% Cycle over subjects
for j = 1:length(uniqueSubjects)

    subjID = uniqueSubjects{j};  % e.g., '99030'

    % Find all files for this subject
    subjFiles = experimentFiles(strcmp(subjectIDs, subjID));

    % Sort files by block number
    blockNums = zeros(length(subjFiles), 1);
    for k = 1:length(subjFiles)
        tokens = regexp(subjFiles(k).name, '_b(\d+)\.mat$', 'tokens');
        if ~isempty(tokens)
            blockNums(k) = str2double(tokens{1}{1});
        end
    end
    [~, sortIdx] = sort(blockNums);
    subjFiles = subjFiles(sortIdx);

    % Combine data
    subData = [];  % Clear before new subject

    for i = 1:length(subjFiles)

        % Select current file
        currentFilename = subjFiles(i).name;

        % Load data (from root folder)
        blockData = load(fullfile(dataDir, currentFilename));
        blockData = blockData.taskData;

        % Recode 360 outcome to 0
        blockData.outcome(blockData.outcome == 360) = 0;

        % Add subject ID
        blockData.ID = repmat(str2double(subjID), length(blockData.rew), 1);

        % Combine blocks
        if i == 1
            subData = blockData;
        else
            subData = catStruct(subData, blockData);
        end
    end

    % Run BIDS conversion for current subject
    % ---------------------------------------

    % Full data directory
    data_dir = fullfile(bidsDir, ['sub_' subjID], 'behav');

    % Create new directory if needed
    if exist(data_dir, 'dir') == false
        mkdir(data_dir)
    end

    % Extract variables of interest
    ID = subData.ID;
    block = subData.block;
    x_t = subData.outcome;
    b_t = subData.pred;
    delta_t = subData.predErr;
    a_t = subData.UP;
    e_t = subData.estErr;
    mu_t = subData.distMean;
    c_t = subData.cp;
    tac = subData.TAC;
    r_t = subData.hit;
    kappa_t = subData.concentration;
    v_t = subData.catchTrial;
    RT = subData.RT;
    initRT = subData.initiationRTs;
    confidence = subData.confidence;
    confidenceRT = subData.confidenceRT;

    % Compute new-block index
    new_block = [true; diff(subData.block) ~= 0];

    % Combine variables into table
    events_t = table(ID, block, new_block, x_t, b_t, delta_t, a_t, e_t, mu_t, c_t, tac, r_t, kappa_t, v_t, RT, initRT, confidence, confidenceRT);

    % Events file names
    events_csv = fullfile(data_dir, ['sub_' subjID '_task-cannon_behav.csv']);
    events_tsv = fullfile(data_dir, ['sub_' subjID '_task-cannon_behav.tsv']);

    % Check if events file exists
    if exist(events_tsv, 'file')

        % Load existing BIDS file
        existingBidsFile = readtable(events_tsv, 'FileType', 'text', 'Delimiter', '\t');
        createNewFile = false;

        % Compare
        isEqual = safeSave(existingBidsFile, events_t);

    else
        createNewFile = true;
    end

    if createNewFile
        writetable(events_t, events_csv,'Delimiter', '\t');
        copyfile(events_csv, events_tsv);
        delete(events_csv);
        fprintf('sub_%s: BIDS file did not exist. Creating it now.\n', subjID);
    elseif isEqual == false
        events_csv = fullfile(data_dir, ['sub_' subjID '_task-cannon_behav_new.csv']);
        events_tsv = fullfile(data_dir, ['sub_' subjID '_task-cannon_behav_new.tsv']);
        writetable(events_t, events_csv,'Delimiter', '\t');
        copyfile(events_csv, events_tsv);
        delete(events_csv);
        fprintf('sub_%s: BIDS file exists but incompatible! Saving with "_new".\n', subjID);
    else
        fprintf('sub_%s: BIDS file exists and is consistent. No update needed.\n', subjID);
    end

    % Add metadata
    metadata_beh = for_bidsEventsDescr();
    savejson('', metadata_beh, fullfile(data_dir, ['sub_' subjID '_task-cannon_behav.json']));
end

% Add supplementary information function later
% for_bidsSupplnf(bidsDir)

    function isEqual = safeSave(existingTable, newTable)
        %SAFESAVE Compares two tables
        tolerance = 1e-6;

        if isequal(size(existingTable), size(newTable)) && isequal(existingTable.Properties.VariableNames, newTable.Properties.VariableNames)
            numericColumns = varfun(@isnumeric, existingTable, 'OutputFormat', 'uniform');
            isEqual = true;
            for c = find(numericColumns)
                col1 = existingTable{:, c};
                col2 = newTable{:, c};
                isEqualColumn = isequaln(col1, col2) || all(abs(col1 - col2) < tolerance | (isnan(col1) & isnan(col2)));
                if ~isEqualColumn
                    isEqual = false;
                    break;
                end
            end
        else
            isEqual = false;
        end
    end
end
