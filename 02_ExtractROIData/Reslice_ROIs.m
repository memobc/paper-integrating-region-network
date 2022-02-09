% Extract single trial estimates from select ROIs. Write output to a csv file for further analysis

% full path to the directory this script is stored in
root = fileparts(mfilename('fullpath'));

% add spm12 to the search path
spm_dir = fullfile(root, 'spm12');
addpath(spm_dir);

%% Parameters

roi_dir       = fullfile(root, 'rois');
roi_file      = 'PM_voxel_clusters.nii';
roi_full_file = fullfile(roi_dir, roi_file);

PM_rois_names = {'pHipp' 'PREC', 'PCC', 'MPFC', 'PHC', 'RSC', 'aAG', 'pAG'};
n_rois        = length(PM_rois_names);
PM_rois_indx  = cell(1, n_rois);

single_trial_est_dir = fullfile(root, 'st_estimates_4s');

%% Routine

% relice ROIs
first_sub_first_st_est_dir = fullfile(single_trial_est_dir, 'sub-s001', 'Ts');
ref = spm_select('FPList', first_sub_first_st_est_dir, 'Sess01_Retrieval_001_T.nii');
matlabbatch{1}.spm.spatial.coreg.write.ref             = {ref};
matlabbatch{1}.spm.spatial.coreg.write.source          = {roi_full_file};
matlabbatch{1}.spm.spatial.coreg.write.roptions.interp = 4;
matlabbatch{1}.spm.spatial.coreg.write.roptions.wrap   = [0 0 0];
matlabbatch{1}.spm.spatial.coreg.write.roptions.mask   = 0;
matlabbatch{1}.spm.spatial.coreg.write.roptions.prefix = 'r';
spm_jobman('run', matlabbatch);

