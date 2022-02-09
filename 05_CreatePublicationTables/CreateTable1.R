# Create Table 1: Descriptive Statistics

library(tidyverse)
library(corrr)
library(MplusAutomation)

col.names <- c("subject", "pHipp", "Prec", "PCC", "MPFC", "PHC", "RSC", "aAG", "pAG", "SCENE", "COLOR", "SOUND")

df <- read_delim("mplus/tidy_roi_data.dat", delim = " ", col_names = col.names)

df %>%
  select(RSC, PHC, pAG, aAG, pHipp, Prec, PCC, MPFC, SCENE, COLOR, SOUND) %>%
  correlate() %>%
  shave() -> corTbl

# taken from Mplus
M <- readModels(target = 'mplus/')

M$data.all_modelType.Measurement_measureModel.SingleFactor.out$data_summary$ICC %>%
  as_tibble() %>%
  mutate(variable = str_to_lower(variable)) %>%
  mutate(variable = str_replace(variable, 'scecorr', 'scene'),
         variable = str_replace(variable, 'colcorr', 'color'),
         variable = str_replace(variable, 'emocorr', 'sound')) -> ICCs

row.names <- c('RSC','PHC','pAG','aAG','pHipp','Prec','PCC','MPFC','SCENE','COLOR','SOUND')
row.order <- c(5,6,7,8,2,1,4,3,9,10,11)

df %>%
  summarise(across(-subject, .fns = c(mean, sd, min, max))) %>%
  pivot_longer(pHipp_1:SOUND_4, names_to = c("rowname", "stat"), names_sep = "_") %>%
  mutate(stat = factor(stat, labels = c("mean", "sd", "min", "max"))) %>%
  pivot_wider(names_from = stat, values_from = "value") %>%
  left_join(., corTbl, by = "rowname") %>%
  mutate(rowname = str_to_lower(rowname)) %>%
  left_join(., ICCs, by = c("rowname" = "variable")) %>%
  add_column(row.order) %>%
  arrange(row.order) %>%
  select(rowname, mean, sd, min, max, ICC, RSC:COLOR) %>%
  mutate(rowname = row.names) -> Tbl

write_csv(Tbl, "intermediate/05_Table1.csv", na = '')
