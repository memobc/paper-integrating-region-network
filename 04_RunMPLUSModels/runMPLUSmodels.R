# requirements
library(MplusAutomation)

# parameters
dataName  <- '03_tidy_roi_data_1s.dat'
root.dir  <- '/gsfs0/data/kurkela/Desktop/Additive_Redundant_Manuscript/'
data.file <- file.path(root.dir, 'intermediate', dataName)
mplus.dir <- file.path(root.dir, 'mplus')
mplus.data.file <- file.path(mplus.dir, 'tidy_roi_data.dat')

print(file.exists(data.file))

file.copy(from = data.file, to = mplus.data.file, overwrite = T)

runModels(target = mplus.dir, showOutput = TRUE, logFile = NULL)
