function for_bidsMain(dataDir, bidsDir)
% FOR_BIDSMAIN Converts cannon data to BIDS format by grouping subject files.
%
%   Input
%       dataDir: Directory with raw data (.mat files).
%                Each subject should have 4 files named like:
%                commonConfetti_exp_g1_conc8_12823_b1.mat, commonConfetti_exp_g1_conc8_12823_b2.mat, ...
%       bidsDir: Directory for BIDS data.
%
%   Output
%       None

% Add data directory and jsonlab library to path
addpath(genpath(dataDir));
addpath(genpath('JSONLAB'));

% Get list of all .mat files in dataDir (non-recursive)
allFiles = dir(fullfile(dataDir, '*.mat'));

% Filter out hidden files starting with '._'
fileNames = {allFiles.name};
isHidden = cellfun(@(f) strncmp(f, '._', 2), fileNames);
allFiles = allFiles(~isHidden);

if isempty(allFiles)
    error('No .mat files found in %s', dataDir);
end

% Prepare to group files by subject.
% We assume filenames like: commonConfetti_exp_g1_conc8_12823_b1.mat
% Use a regexp to extract subject number. The pattern looks for _conc followed by digits,
% then an underscore, then the subject id (one or more digits), then _b followed by block.
subjectIDs = cell(size(allFiles));
blockIDs   = cell(size(allFiles));
pattern = '.*_conc\d+_(\d+)_b(\d)\.mat'; % capturing subject and block numbers

for i = 1:length(allFiles)
    fname = allFiles(i).name;
    tokens = regexp(fname, pattern, 'tokens');
    if isempty(tokens)
        warning('File %s does not match naming pattern. Skipping.', fname);
        continue;
    end
    % tokens is a cell array of cells: {{subjectID, blockID}}
    subjectIDs{i} = tokens{1}{1};
    blockIDs{i}   = tokens{1}{2};
end

% Remove files that did not match the pattern
validIdx = ~cellfun('isempty', subjectIDs);
allFiles = allFiles(validIdx);
subjectIDs = subjectIDs(validIdx);
blockIDs   = blockIDs(validIdx);

% Get unique subject IDs
uniqueSubjects = unique(subjectIDs);

% Loop over each subject
for s = 1:length(uniqueSubjects)
    subjID = uniqueSubjects{s};
    
    % Find files for this subject
    subjFileIdx = strcmp(subjectIDs, subjID);
    subjFiles = allFiles(subjFileIdx);
    
    if length(subjFiles) < 1
        warning('No valid files for subject %s. Skipping.', subjID);
        continue;
    end
    
    % Initialize a structure to accumulate subject data
    clear subData;
    
    % Process each file (block) for the subject
    for i = 1:length(subjFiles)
        fullFileName = fullfile(dataDir, subjFiles(i).name);
        blockStruct = load(fullFileName);
        if ~isfield(blockStruct, 'taskData')
            warning('File %s does not contain "taskData". Skipping.', fullFileName);
            continue;
        end
        blockData = blockStruct.taskData;
        
        % Recode 360 outcome to 0
        if isfield(blockData, 'outcome')
            blockData.outcome(blockData.outcome == 360) = 0;
        end
        
        % Add subject number as a numeric value using the extracted subject id
        % (convert to number if possible; otherwise, use string)
        subjNumeric = str2double(subjID);
        if isnan(subjNumeric)
            blockData.ID = repmat({subjID}, length(blockData.rew), 1);
        else
            blockData.ID = repmat(subjNumeric, length(blockData.rew), 1);
        end
        
        % Combine block data across files using catStruct (assumed available)
        if ~exist('subData', 'var')
            subData = blockData;
        else
            subData = catStruct(subData, blockData);
        end
    end
    
    if ~exist('subData', 'var')
        fprintf('No valid taskData for subject %s. Skipping.\n', subjID);
        continue;
    end
    
    % Set up BIDS output folder for this subject using subject id (e.g., sub_12823)
    subFolder = fullfile(bidsDir, ['sub_' subjID], 'behav');
    if ~exist(subFolder, 'dir')
        mkdir(subFolder);
    end
    
    % Extract variables of interest from subData
    ID      = subData.ID;
    block   = subData.block;
    x_t     = subData.outcome;
    b_t     = subData.pred;
    delta_t = subData.predErr;
    a_t     = subData.UP;
    e_t     = subData.estErr;
    mu_t    = subData.distMean;
    c_t     = subData.cp;
    tac     = subData.TAC;
    r_t     = subData.hit;
    kappa_t = subData.concentration;
    v_t     = subData.catchTrial;
    RT      = subData.RT;
    initRT  = subData.initiationRTs;
    
    % Compute new-block index (assuming subData.block is numeric or categorical)
    new_block = [true; diff(subData.block) ~= 0];
    
    % Combine variables into an events table
    events_t = table(ID, block, new_block, x_t, b_t, delta_t, a_t, e_t, mu_t, c_t, tac, r_t, kappa_t, v_t, RT, initRT);
    
    % Define file names for events output (.tsv)
    events_tsv = fullfile(subFolder, ['sub_' subjID '_task-cannon_behav.tsv']);
    
    % If an events file exists, compare; otherwise, write new file.
    if exist(events_tsv, 'file')
        existingBidsFile = readtable(events_tsv, 'FileType', 'text', 'Delimiter', '\t');
        createNewFile = false;
        isEqual = safeSave(existingBidsFile, events_t);
    else
        createNewFile = true;
    end
    
    if createNewFile
        % Save temporary .csv then copy to .tsv (for compatibility)
        events_csv = fullfile(subFolder, ['sub_' subjID '_task-cannon_behav.csv']);
        writetable(events_t, events_csv, 'Delimiter', '\t');
        copyfile(events_csv, events_tsv);
        delete(events_csv);
        fprintf('sub_%s: BIDS file did not exist. Creating it now.\n', subjID);
    elseif ~isEqual
        % If existing file differs, save with a _new suffix.
        events_csv = fullfile(subFolder, ['sub_' subjID '_task-cannon_behav_new.csv']);
        events_tsv = fullfile(subFolder, ['sub_' subjID '_task-cannon_behav_new.tsv']);
        writetable(events_t, events_csv, 'Delimiter', '\t');
        copyfile(events_csv, events_tsv);
        delete(events_csv);
        fprintf('sub_%s: BIDS file exists but is incompatible with the new one! Saving with suffix "_new".\n', subjID);
    else
        fprintf('sub_%s: BIDS file exists and is consistent. No need to update.\n', subjID);
    end
    
    % Add metadata file
    metadata_beh = for_bidsEventsDescr();
    savejson('', metadata_beh, fullfile(subFolder, ['sub_' subjID '_task-cannon_behav.json']));
end

% Add supplementary information function later
% for_bidsSupplnf(bidsDir)

    function isEqual = safeSave(existingTable, newTable)
        % SAFESAVE compares two tables to ensure that the new table is saved safely.
        %
        %   Input
        %       existingTable: Table read from disk.
        %       newTable: Table to be saved.
        %
        %   Output
        %       isEqual: Binary indicator if tables are equal.
        tolerance = 1e-6;
        if isequal(size(existingTable), size(newTable)) && ...
           isequal(existingTable.Properties.VariableNames, newTable.Properties.VariableNames)
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
