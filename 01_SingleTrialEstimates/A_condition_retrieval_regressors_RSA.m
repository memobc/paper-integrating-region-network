function [] = condition_retrieval_regressors_RSA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Loads behavioral data csv files to generate regressors for my
% conditions of interest for RSA first-level models.
% outputs .mat file per run:

% names     (of condition regressors)
% onsets    (onset times of events per condition)
% durations (duration of each event per condition - should be the same
% within each condition unless RT is being accounted for)

% onsets entered in order of run and onset time

% for analysis of retrieval time series, just marking each retrieval trial

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clearvars; clc;

% the base of the analysis directory
rootdir = fileparts(fileparts(mfilename('fullpath')));

% path to the orbit data directory
b.orbitDir = fullfile(rootdir, 'orbit-data')

% load in behavioral data:
behavFile = fullfile(b.orbitDir, 'behavior', 'AllData_OrbitfMRI-behavior.csv');
allData   = readtable(behavFile);

% define columns in allData for onset:
onsCols   = [30]; %columns in raw data csv file for retrieval event onsets
removeTRs = 116; %116 encoding TRs

%where to save regressor csv files:
b.saveDir = fullfile(rootdir, 'orbit-rsa-dir', 'regressors');

% load in file from exclude runs to determine which runs will be modeled
% for each subject:
% 1  = valid run
% -1 = never processed - excluded before data processing
% 0  = excluded after data processing due to motion
myRuns   = readtable(fullfile(b.orbitDir, 'derivs', 'excluded-runs-elife.csv'));
subjects = table2cell(myRuns(:,1))';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% regressor parameters
names       = {'Retrieval'};
evDurations = zeros(1,length(names)); %duration to assign to events, per regressor
%evDurations = repmat(4,1,length(names)); %duration to assign to events, per regressor

%% loop through subjects %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

subCount = 0;
for i = 1:length(subjects)
    
    % determine if include this subject (col 8 marks is subject valid, overall):
    curRuns  = table2cell(myRuns(i,:));
    taskRuns = cell2mat(curRuns(2:7)); %6 orbit runs

    % get numbers of valid memory runs:
    b.memoryRuns = find(taskRuns > -1); %NOTE these are the original block numbers that we ran - important
    % for getting the right onsets
    % now remove any runs that were excluded before data processing
    taskRuns(taskRuns == -1) = [];

    % only run if have at least 4/6 memory runs
    if curRuns{8} == 1 % -------------------------------------------
        
        subCount = subCount + 1;
        
        fprintf('\nCreating task regressors for sub-%s...\n',subjects{i});
        b.curSubj = subjects{i};
        
        % make folder for subject's regressors:
        subjDir = fullfile(b.saveDir, b.curSubj);
        if ~exist(subjDir), mkdir(subjDir); end
        
        % get behavioral data:
        % subject number in string:
        curNum    = str2num(cell2mat(regexp(b.curSubj, '\d*', 'Match')));
        behavData = allData(table2array(allData(:,1)) == curNum,:);
        
        %% loop through memory task runs ------------------------------------------
        runCount = 0;
        for r = 1:length(taskRuns)

            %only process runs that are still valid after motion exclusion:
            if taskRuns(r) == 1

                runCount = runCount + 1;
                
                % NOTE - for subjects who are missing runs BEFORE PROCESSING, the scan runs are always
                % labeled continuously from 1 - e.g. runs will be 1-5 if subject lost run 6 or
                % run 4 before processing (marked as -1). So, it's important to grab the
                % correct onsets according to the ORIGINAL block IDs.
                blkNum = b.memoryRuns(r);
                
                % now get behav data that corresponds to this block:
                clear curData
                curData = behavData(table2array(behavData(:,4))==blkNum,:);
                curData = table2cell(curData);
                
                % define output variables:
                onsets    = cell([1 length(names)]); 
		durations = cell([1 length(names)]);
                
                % ----------------------------------------------------------------------- %
                for reg = 1:length(onsCols) % loop through each trial type ----
                    
                    onsCol = onsCols(reg);
                    %sort curData by current onsets and valence:
                    curData = sortrows(curData, onsCol);
                    clear curOnsets
                    
                    %add onsets
                    curOnsets      = cell2mat(curData(:,onsCol));
                    % adjust onset times for encoding now removed
                    curOnsets      = curOnsets - (removeTRs*1.5);
                    onsets{reg}    = curOnsets';
                    durations{reg} = repmat(evDurations(reg), 1, length(curOnsets));
		    
                end %end of loop through onset cols (regs) -------------------------------
                
                % ---------------------------------------------------------------------
                % save .mat file for this run:
                fileName = fullfile(subjDir, [b.curSubj '_task-Retrieval_run-0' num2str(r) '_task-onsets_RSA.mat']);
		if(~exist(fileName, 'file'))
                	save(fileName, 'names', 'onsets', 'durations');
		end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
            end %end of loop to only process valid runs
            
        end %end of loop through memory runs ----------------------------------
        
    end %end of loop that only processes included subjects -------------------
    
end %end of loop through subjects ---------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
