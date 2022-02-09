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

% load ROIs
resliced_roi_full_file = fullfile(roi_dir, ['r' roi_file]);
ROIs_V                 = spm_vol(resliced_roi_full_file);
[ROIs_Y, ROIs_XYZmm]   = spm_read_vols(ROIs_V);

% specify single trial estimates
st_estimate_files = cellstr(spm_select('FPListRec', single_trial_est_dir, '.*Retrieval.*_T\.nii'));
st_estimate_mats  = cellstr(spm_select('FPListRec', single_trial_est_dir, 'SPM.mat'));
st_estimate_mats  = st_estimate_mats(contains(st_estimate_mats, 'Retrieval'));

assert(length(st_estimate_files) == length(st_estimate_mats), 'error')

% initalize loop variables
n_st_estimates = length(st_estimate_files);
subject_list   = cell(n_st_estimates, 1);
sess_list      = cell(n_st_estimates, 1);
trialNum_list  = cell(n_st_estimates, 1);
ons_list       = nan(n_st_estimates, 1);
roi_tbl        = array2table(nan(n_st_estimates, n_rois), 'VariableNames', PM_rois_names);

for s = 1:n_st_estimates

   % update the user on progress
   fprintf('\n%d/%d\n', s, n_st_estimates);

   cur_st_estimate_file = st_estimate_files{s};

   % use regular expressions to extract subject, session, and trial number
   % from the single trial estimate file name
   subject  = regexp(cur_st_estimate_file, 'sub-s[0-9]{3}', 'match', 'once');
   sess     = regexp(cur_st_estimate_file, 'Sess[0-9]{2}', 'match', 'once');
   trialNum = regexp(cur_st_estimate_file, '(?<=_)[0-9]{3}(?=_)', 'match', 'once');

   % define a set of boolean vectors to pick the correct combination of
   % subject, session, and trial number
   subF      = contains(st_estimate_mats, subject);
   sesF      = contains(st_estimate_mats, sess);
   triF      = contains(st_estimate_mats, ['Retrieval_' trialNum]);
   trial_mat = st_estimate_mats{subF & sesF & triF};
   assert(size(trial_mat, 1) == 1, 'error')

   % load the SPM.mat file for this trial's model. Grab the trial's onset
   load(trial_mat)
   ons = SPM.Sess.U(1).ons;

   % extract and take the average within each ROI
   for i = 1:n_rois

      cur_roi = PM_rois_names{i};

      % extract voxels in this ROI. Take the mean. Add to the table
      indx    = find(ROIs_Y == i);
      [x,y,z] = ind2sub(size(ROIs_Y), indx);
      XYZ     = [x y z]';
      roi_tbl{s, cur_roi} = mean(spm_get_data(cur_st_estimate_file, XYZ), 2);

   end

  % store everything in the appropriate vector
  subject_list{s}  = subject;
  sess_list{s}     = sess;
  trialNum_list{s} = trialNum;
  ons_list(s)      = ons;

  clc;

end

% create a table of the meta data
metaData_tbl = table(subject_list, sess_list, trialNum_list, ons_list, ...
                     'VariableName', {'subject', 'sess', 'trialNum', 'ons'});

% concatenate columns to create final table
final_tbl = [metaData_tbl, roi_tbl];

% write
writetable(final_tbl, 'intermediate/01_Extracted_ROI_data_4s_twoeight.csv', 'Filetype', 'text');
