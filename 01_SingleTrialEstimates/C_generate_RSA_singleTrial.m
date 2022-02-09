function generate_RSA_singleTrial(i)

% adapted from generate_encoding_singleTrial to accomodate running both
% encoding and retrieval phases for Orbit RSA analyses

% edited by Rose Cooper - Dec 2020

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% SPM info
rootdir = fileparts(fileparts(mfilename('fullpath')));
spmdir  = fullfile(rootdir, spmdir);
addpath(spmdir);
spm_jobman('initcfg')
spm('defaults', 'FMRI');

%first level models for RSA:
modDir = fullfile(rootdir, 'orbit-rsa-dir', 'first-level', 'unsmoothed');

% SUBJECTS
% define all subjects who have regressors:
subjs = struct2cell(dir(modDir));

% clear rows that are not subjects:
subjs = subjs(1,contains(subjs(1,:),'sub'));

%% loop through subjects

curSubj = subjs{i};

% where are the first-level model files?
spmDir  = [modDir curSubj];

% where should my models go?
outDir  = fullfile(rootdir, 'st_estimates_1s', curSubj);

%create out directory if it does not exist
if ~exist(outDir, 'dir')
    mkdir(outDir)
end

%% Load SPM.mat file and get info

% Load pre-existing SPM file containing model information
fprintf('\nLoading univariate model for %s:\n%s\n', curSubj, fullfile(spmDir, 'SPM.mat'));
if exist(fullfile(spmDir, 'SPM.mat'),'file')
    origSPM = load(fullfile(spmDir, 'SPM.mat'));
else
    error('Cannot find SPM.mat file.');
end

% Get model information from SPM file
fprintf('\n    Getting model information...\n');

% original fMRI data files:
files = cellstr(origSPM.SPM.xY.P);

fprintf('    Modeling %i timepoints across %i sessions.\n', size(files,1), length(origSPM.SPM.Sess));

% Make directory for T images and per trial
TDir = [outDir 'Ts/'];
if ~exist(TDir, 'dir')
    mkdir(TDir)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% MULTI-MODEL APPROACH

% Loop across sessions
for iSess = 1:length(origSPM.SPM.Sess)
    
    rows       = origSPM.SPM.Sess(iSess).row;
    sessFiles  = files(rows', :);
    sessFiles  = cellstr(sessFiles);
    covariates = origSPM.SPM.Sess(iSess).C.C;
    covarNames = origSPM.SPM.Sess(iSess).C.name;
    
    % get names, onsets, durations - no loop because only encoding event
    originalNames     = origSPM.SPM.Sess(iSess).U(1).name{1};
    originalOnsets    = origSPM.SPM.Sess(iSess).U(1).ons;
    originalDurations = origSPM.SPM.Sess(iSess).U(1).dur;
    
    %%% Make single-trial regressors: ----------------------------------
    lssNames     = cell(1, length(originalOnsets));
    lssOnsets    = cell(1, length(originalOnsets));
    lssDurations = cell(1, length(originalOnsets));
    
    for jOnset = 1:length(originalOnsets)
        
        % (e.g. ConditionA_001, Other_ConditionA, ConditionB, ConditionC, etc.)
        lssNames{jOnset} = {[originalNames '_' sprintf('%03d', jOnset)]...
            ['Other_' originalNames]};
        
        % Single trial onset
        lssOnsets{jOnset}{1}    = originalOnsets(jOnset);
        lssDurations{jOnset}{1} = originalDurations(jOnset);
        
        % Other trials of same condition
        lssOnsets{jOnset}{2} = originalOnsets;
        lssOnsets{jOnset}{2}(jOnset) = []; %remove single trial from 'other'
        lssDurations{jOnset}{2} = originalDurations;
        lssDurations{jOnset}{2}(jOnset) = [];

    end
    
    % CREATE MODEL PER TRIAL -------------------------------------
    parfor kTrial = 1:length(lssOnsets)
        
        singleName = lssNames{kTrial}{1};
        names      = lssNames{kTrial};
        onsets     = lssOnsets{kTrial};
        durations  = lssDurations{kTrial};
        
        % Make trial directory
        trialDir = [outDir 'Sess' sprintf('%02d', iSess) '/' singleName '/'];
        if ~exist(trialDir,'dir')
            mkdir(trialDir)
        end
        
        % Save regressor onset files
        regFile = [trialDir 'st_regs.mat'];
        parsaveReg(regFile, names, onsets, durations);
        
        covFile = [trialDir 'st_covs.mat'];
        parsaveCov(covFile, covariates, covarNames);
        
        % Run matlabbatch to create new SPM.mat file using SPM batch tools
        if ~exist([trialDir 'spmT_0001.nii'], 'file')
            
            % Model specification:
            matlabbatch = create_matlabbatch(trialDir, sessFiles, regFile, covFile)
            spmFile = [trialDir 'SPM.mat'];
            fprintf('\n\tCreating SPM.mat file:\n%s\n', spmFile);
            
            % Estimate model
            matlabbatch{2}.spm.stats.fmri_est.spmmat = {spmFile};
            matlabbatch{2}.spm.stats.fmri_est.write_residuals  = 0;
            matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
            fprintf('\tEstimating model from SPM.mat file\n');
            
            % Run contrast to get T value
            matlabbatch{3}.spm.stats.con.spmmat = {spmFile};
            matlabbatch{3}.spm.stats.con.delete = 0;
            matlabbatch{3}.spm.stats.con.consess{1}.tcon.name    = 'singleTrial';
            matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = 1; %target trial always first regressor, rest auto-padded with zeros
            matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
            fprintf('\tEstimating T contrast from SPM.mat file\n');
            
            % RUN
            spm_jobman('run', matlabbatch);
            
            % ------------------------------------------------- %
            % Copy single trial T image to Ts directory -
            % will always be first regressor
            Tfile_move = [trialDir 'spmT_0001.nii'];
            system(['cp ' Tfile_move ' ' TDir 'Sess' sprintf('%02d', iSess) '_' singleName '.nii']);
            
        end
        
    end %end of loop through (parallel) trials
    
end %end of loop over sessions

end % end of main function


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SUBFUNCTIONS

function parsaveReg(outFile, names, onsets, durations)
     save(outFile, 'names', 'onsets', 'durations');
end

function parsaveCov(outFile, R, names)
     save(outFile, 'R', 'names');
end

function matlabbatch = create_matlabbatch(trialDir, sessFiles, regFile, covFile)

% Create matlabbatch for new SPM.mat file (general parameters)
matlabbatch{1}.spm.stats.fmri_spec.dir              = {trialDir};
matlabbatch{1}.spm.stats.fmri_spec.timing.units     = 'secs';
matlabbatch{1}.spm.stats.fmri_spec.timing.RT        = 1.5;
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t    = 16; % default - the number of time bins spm divides into
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0   = 8;  % default - the time bin modeled (middle if reference scan middle for slice time correction)
matlabbatch{1}.spm.stats.fmri_spec.fact             = struct('name', {}, 'levels', {});
matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
matlabbatch{1}.spm.stats.fmri_spec.volt             = 1;
matlabbatch{1}.spm.stats.fmri_spec.global           = 'None';
matlabbatch{1}.spm.stats.fmri_spec.mthresh          = -Inf;
matlabbatch{1}.spm.stats.fmri_spec.mask 	    = {fullfile(rootdir, 'rois', wb_graymatter_mask.nii,1')};
matlabbatch{1}.spm.stats.fmri_spec.cvi              = 'AR(1)';

% add model-specific files
matlabbatch{1}.spm.stats.fmri_spec.sess.scans     = sessFiles;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond      = struct('name', {}, 'onset', {}, 'duration', {}, 'tmod', {}, 'pmod', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.multi     = {regFile};
matlabbatch{1}.spm.stats.fmri_spec.sess.regress   = struct('name', {}, 'val', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg = {covFile};
matlabbatch{1}.spm.stats.fmri_spec.sess.hpf       = 128;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
