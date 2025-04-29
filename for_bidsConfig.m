% BIDS config script: This is an example script to setup BIDS
% transformation on your computer

% Identify parent directory of this config script
parentDirectory = fileparts(mfilename('fullpath'));
cd(parentDirectory)
addpath(genpath(parentDirectory));

% This is the folder where your raw data should be saved
% It should contain subfolders that are named according to the subject IDs.
% The subfolders should contain the data .mat files.

% Data directory
grandparentDir = fileparts(parentDirectory);
dataDir = strcat(grandparentDir, filesep, 'for_analysisPipeline', filesep, 'Leipzig', filesep, 'for_pilot_data', filesep, 'helicopter', filesep, 'raw_dataforBIDS');

% This is the new BIDS folder
bidsDir = strcat(parentDirectory, filesep, 'Leipzig', filesep, 'for_pilot_data', filesep, 'helicopter', filesep, 'for_bids_data');

% Check if we need a new directory
if exist(bidsDir, 'dir') == false
    mkdir(bidsDir)
end

% Run BIDS transformation
for_bidsMain(dataDir, bidsDir)

