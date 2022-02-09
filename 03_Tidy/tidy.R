# Data Tidying

# requirements ------------------------------------------------------------

shhh <- suppressPackageStartupMessages

shhh(library(tidyverse))

numeric_to_bids <- function(NumericID, BIDS.prepend = "s") {
  # Converts a numeric subject ID to a BIDS formatted one.
  # Zero pads the numeric ID and place 'sub-s' in front
  # NumericID can be a character or a numeric.

  Zero.Pad.ID <- str_pad(NumericID, width = 3, side = "left", pad = "0")
  BIDS.SubID <- str_c(BIDS.prepend, Zero.Pad.ID)
}

calc_quality <- function(x, thresh) {
  # calculate "Quality" by excluding high error trials above a
  # predefined threshold and scaling the remaining low error
  # trials on a scale of 0 - 1.

  thresholded <- ifelse(x > thresh, NA, x)
  thresholded <- 1 - thresholded / max(thresholded, na.rm = T)
  if_else(is.na(thresholded), 0, thresholded)
}

# parameters --------------------------------------------------------------
# define full paths to key directories and files

root <- "~/Desktop/Additive_Redundant_Manuscript/"
extracted_data_file <- file.path(root, "intermediate", "01_Extracted_ROI_data_1s.csv")
orbit_data_dir <- file.path(root, "orbit-data")
SS_exclusions_file <- file.path(orbit_data_dir, "derivs", "excluded-runs-elife.csv")
behav_file <- file.path(orbit_data_dir, "behavior", "AllData_OrbitfMRI-behavior.csv")

# body --------------------------------------------------------------------

# ROI data
cat("Loading ROI Data:\n")
read_csv(extracted_data_file) %>%
  mutate(across("subject", factor)) -> roi_df

# Subject exclusions data
select_cols <- cols_only(SubID = col_character(), Memory = col_logical())
SS_exclusions_df <- read_csv(SS_exclusions_file, col_types = select_cols)

# Behavioral data
behav_df <- read_csv(file = behav_file) %>%
  mutate(Run = as.integer(Run))

# Changes the numeric subject ID system of `behav_df`
# to BIDS format. Example: 01 -> sub-s001.
behav_df %>%
  mutate(SubID = map_chr(SubID, numeric_to_bids, BIDS.prepend = "sub-s")) -> behav_df

# Subject sub-s009 is missing the first session (i.e., Run = 1). The Run column of the
# behavioral data (`behav_df`) has Runs 2-6 for subject sub-s009. The session column
# of the betas data frame (`roi_df`) has sessions 1-5 for subejct sub-s009. By
# subtracting 1 from the Run column just for subject sub-s009, these columns now match.
behav_df %>%
  mutate(Run = if_else(SubID == "sub-s009", as.integer(Run - 1), Run)) -> behav_df

# Round onsetRemember to 3 decimal places. This allows for better matching of the
# behav_df and the roi_df using dplyr::left_join() below.
behav_df %>%
  mutate(onsetRemember = round(onsetRemember, 3)) -> behav_df

# Using the calc_quality function defined above, calculate memory quality for each feature
# The 57 and 30 cutoffs are from Cooper & Ritchey (2019).
behav_df %>%
  mutate(ColQuality = calc_quality(ColAbsError, thresh = 57)) %>%
  mutate(SceQuality = calc_quality(SceAbsError, thresh = 30)) %>%
  mutate(MemoryQuality = ColQuality + SceQuality + EmotionCorrect) -> behav_df

# Only include Ss included in Cooper & Ritchey (2019)
SS_exclusions_df %>%
  filter(Memory) %>%
  pull(SubID) -> GoodSs

behav_df %>%
  filter(SubID %in% GoodSs) -> behav_df

if(str_detect(extracted_data_file, 'old', negate = TRUE)){
  # remove 174 seconds from the onset times to account for encoding
  behav_df %>%
    mutate(onsetRemember = onsetRemember - 174) -> behav_df
}

# round the onsetRemember column
behav_df %>%
  mutate(onsetRemember = round(onsetRemember, 3)) -> behav_df

# Tidy the roi_df to have a session column
roi_df %>%
  mutate(
    sess = str_extract(sess, "(?<=Sess)0[1-6]"),
    sess = as.integer(sess)
  ) %>%
  mutate(ons = round(ons, 3)) -> roi_df

# Match the behavioral data to the roi data
roi_df <- left_join(roi_df, behav_df,
  by = c(
    "subject" = "SubID",
    "sess" = "Run",
    "ons" = "onsetRemember"
  )
)

# Select only the variables of interest; make SceQuality and ColQuality binary; coerce
# subject to be numeric.
roi_df %>%
  select(subject, pHipp:pAG, SceQuality, ColQuality, EmotionCorrect) %>%
  mutate(ColQuality = as.double(ColQuality > 0), SceQuality = as.double(SceQuality > 0)) %>%
  mutate(subject = as.factor(subject)) %>%
  mutate(subject = as.double(subject)) -> roi_df

# write -------------------------------------------------------------------

cat("Writing:\n")
fullFile <- file.path(root, 'intermediate', '03_tidy_roi_data_1s.dat')
write_delim(roi_df, fullFile, col_names = F)
