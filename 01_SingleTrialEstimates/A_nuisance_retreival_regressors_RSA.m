function [] = nuisance_retrieval_regressors_RSA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Takes data that has been completely preprocessed
% and loads csv files geneated from fmriprep to generate nuisance
% regressors per scan run **ONLY** for retrieval data (350 TRs)

% saves as a matrix R in a .mat file as required by spm.
% including 6 motion parameters, FD, and acompcor (all PCs) - with constant
% = 14 nuisance regressors per model.

% also adds spike regressors (one per spike TR) = data censoring

% saves regressors by run in preparation for LSS single trial models
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clearvars; clc;

rootdir = fileparts(fileparts(mfilename('fullpath')));

addpath('/gsfs0/data/cooperrn/Documents');

%where is regressor information (.tsv files from fmriprep)
b.derivDir  = fullfile(rootdir, 'orbit-data', 'derivs', 'fmriprep');

%where to save regressor csv files:
b.saveDir   = fullfile(rootdir, 'orbit-rsa-dir', 'regressors');

% load in file from exclude runs to determine which runs will be modeled
% for each subject:
% 1  = valid run
% -1 = never processed - excluded before data processing
% 0  = excluded after data processing due to motion
myRuns   = readtable(fullfile(rootdir, 'orbit-data', 'derivs', 'excluded-runs-elife.csv');
subjects = table2cell(myRuns(:,1))';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% just need to change this list to add more regressors:
motnames = {'FramewiseDisplacement',...
    'aCompCor00','aCompCor01','aCompCor02','aCompCor03','aCompCor04','aCompCor05',...
    'X','Y','Z','RotX','RotY','RotZ'};
numScans = 350; %retrieval TRs per run -- note fmriprep has nuisance regressors for whole scan run (including prior encoding)

spike_threshold = 0.6; % note that this is double the thrshold used to evaluate run (at least 80% < 0.3mm).

fprintf('\nCreating nuisance regressors including spikes > %0.2f mm...\n', spike_threshold);

%% loop through subjects -----------------------------------------------
for i = 1:length(subjects)

    %determine if include this subject (col 8 marks is subject valid, overall):
    curRuns  = table2cell(myRuns(i,:));
    taskRuns = cell2mat(curRuns(2:7)); %6 orbit runs
    %now remove any runs that were excluded before data processing
    taskRuns(taskRuns == -1) = [];


    % only run if have at least 4/6 memory runs
    if curRuns{8} == 1 % -------------------------------------------

        fprintf('\nCreating nuisance regressors for %s for %d/6 retrieval runs...\n',subjects{i},sum(taskRuns));
        b.curSubj = subjects{i};

        %make folder for subject's regressors:
        subjDir = fullfile(b.saveDir, b.curSubj);
        if ~exist(subjDir,'dir'), mkdir(subjDir); end

        %% loop through runs
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        for r = 1:length(taskRuns)
            
	    % only process runs that are still valid after motion exclusion:
            if taskRuns(r) == 1

                % create motion regressors -----------------------------------------------
                motionFile = fullfile(b.derivDir, b.curSubj, 'func', [b.curSubj '_task-Memory_run-0' num2str(r) '_bold_confounds.tsv']);
                [~, ~, motionData] = tsvread(motionFile);
                
                % find regressor columns:
                regCols = ismember(motionData(1,:), motnames); %col number in tsv file per run from fmriprep (6 motion regressors, FD, and acompcor00)
                
                regressorData = motionData(2:end, regCols);
                % replace first FD value (n/a) with 0, or mean also fine (found this recommended)
                regressorData(1,1) = {'0'};
                
                fclose('all');
                
                % convert to double format
                motionNew = [];
                regressorData(1:(size(regressorData,1)-numScans),:) = []; %remove encoding TRs
                for ev = 1:numScans
                    for c = 1:size(regressorData, 2)
                        motionNew(ev, c) = str2num(regressorData{ev,c});
                    end
                end
                
                % add to motion matrix if concatenating:
                R = motionNew;
                
                % now create spike regressors for this subject (first column = FD)
                spike_regs = []; spike_names = {}; spike_count = 0;
                for tr = 1:size(R,1)
                    if R(tr,1) > spike_threshold
                        spike_count = spike_count + 1;
                        new_reg     = zeros(size(R, 1), 1);
                        new_reg(tr) = 1;
                        spike_regs  = [spike_regs, new_reg];
                        spike_names = [spike_names, {['spike' num2str(spike_count, '%03.f')]}];
                    end
                end
                fprintf('   Spike regressors, run %d = %d\n', r, size(spike_regs, 2));
                
                % save concatenated file:
                names = {};
                names = [motnames, spike_names];
                R = [R, spike_regs];

                % now save out text file for concatenated motion regressors -------------------------------
                fileName = fullfile(subjDir, [b.curSubj '_task-Retrieval_run-0' num2str(r) '_nuisance_regressors.mat']);
                if(~exist(fileName, 'file'))
		     save(fileName, 'R','names');
		end
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            end %end of loop to only process valid runs

        end %end of loop through memory runs ------------------------------------

    end %end of loop that only runs for included subjects -------------------

end %end of loop through subjects ---------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
