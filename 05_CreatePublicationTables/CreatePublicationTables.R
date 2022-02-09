# Create Publication Ready Tables of Models

# requirements ------------------------------------------------------------

shh <- suppressPackageStartupMessages

shh(library(MplusAutomation))
shh(library(tidyverse))
shh(library(kableExtra))

options(knitr.kable.NA = "")

createModelCompTbl <- function(unformatted_model_summary_tbl, Model1Title) {
  # Create Model Comparisons Table

  unformatted_model_summary_tbl %>%
    select(Title, ChiSqM_Value, ChiSqM_DF, ChiSqM_PValue, WaldChiSq_Value, WaldChiSq_DF, WaldChiSq_PValue, CFI, TLI, RMSEA_Estimate, SRMR.Within, SRMR.Between) %>%
    mutate(ChiSqM_PValue = format.pval(ChiSqM_PValue, eps = .001)) %>%
    mutate(`Chi-square` = str_glue("{ChiSqM_Value} ({ChiSqM_DF}), p: {ChiSqM_PValue}")) %>%
    mutate(WaldChiSq_PValue = p.adjust(WaldChiSq_PValue, method = "bonferroni")) %>%
    mutate(WaldChiSq_PValue = format.pval(WaldChiSq_PValue, eps = .001, digits = 1)) %>%
    mutate(`Wald's Test` = str_glue("{WaldChiSq_Value} ({WaldChiSq_DF}), p: {WaldChiSq_PValue}")) %>%
    mutate(`Wald's Test` = case_when(
      Title == Model1Title ~ NA_character_,
      TRUE ~ as.character(`Wald's Test`)
    )) %>%
    mutate(modNum = as.double(str_extract(Title, "[0-9]{1,2}"))) %>%
    arrange(modNum) %>%
    select(Title, `Chi-square`, `Wald's Test`, everything(), -starts_with("ChiSq"), -starts_with("WaldChi"), -modNum) %>%
    rename(RMSEA = RMSEA_Estimate) 
}

createParamTbl <- function(x) {
  # function that
  # 1.) extracts the unstandardized and standardized parameter estimates
  # from a mplus.model.list object created by MplusAutomation::readModels()
  # 2.) perfoms minor tidying by filtering out the between parameter estimates,
  # removing the est_se column, and formating the pval column
  # 3.) joins the two data.frames together

  x$parameters$unstandardized %>%
    as_tibble() %>%
    select(-est_se) %>%
    mutate(pval = format.pval(pval, eps = .001)) -> unstand

  x$parameters$stdyx.standardized %>%
    as_tibble() %>%
    select(-est_se) %>%
    mutate(pval = format.pval(pval, eps = .001)) %>%
    select(BetweenWithin, everything()) -> stand

  left_join(unstand, stand, by = c("paramHeader", "param", "BetweenWithin"), suffix = c(".unstand", ".stand")) %>%
    select(BetweenWithin, everything())
}

createCommunTbl <- function(x) {
  # function that
  # 1.) extracts the communality values from a mplus.model.list objects created by MplusAutomation::readModels()
  # 2.) performs some minor tidying

  x$parameters$r2 %>%
    as_tibble() %>%
    mutate(pval = format.pval(pval, eps = .001)) %>%
    select(-BetweenWithin)
}

remove_dup <- function(str_vct){
  out_vct <- str_vct
  uniq <- unique(str_vct)
  for(u in uniq){
    str_detect(u, str_vct) %>%
      which.max() -> first.instance
    str_detect(u, str_vct) %>%
      which() -> all.instances
    all.instances[!(all.instances %in% first.instance)] -> elements.2.remove
    out_vct[elements.2.remove] <- ''
  }
  return(out_vct)
}

# Parameters --------------------------------------------------------------

M <- readModels(target = file.path(getwd(), "mplus"))

# extract model summary information
map_dfr(M, ~ .x$summaries) %>%
  as_tibble() -> model_summaries

ModelComp_col_names <- c("Title", "Chi-square", paste0("Wald's Test", footnote_marker_alphabet(1)), "CFI", "TLI", "RMSEA_Estimate", "SRMR.Within", "SRMR.Between")

# Two Factor Model -- Model Comparisons -----------------------------------

# A summary of model fit statistics
model_summaries %>%
  filter(str_detect(Filename, "TwoFactor_modelName-Model[0-8].out")) %>%
  createModelCompTbl(Model1Title = "Model 0: Baseline") %>%
  mutate(Title = str_remove(Title, 'Two Factor ')) -> twofactor_summary_tbl

# write to a csv file
write_csv(x = twofactor_summary_tbl, path = "intermediate/05_type-ModelComparisons_model-TwoFactor_tbl.csv", na = "")

# Two Factor Measurement Model -- Parameters ------------------------------

createParamTbl(M$data.all_modelType.Measurement_measureModel.TwoFactor.out) -> two_factor_param_tbl

two_factor_param_tbl %>%
  filter(BetweenWithin == 'Within') %>%
  filter(str_detect(paramHeader, 'Variances', negate = TRUE)) %>%
  mutate(param = str_replace(param, 'SCECORR', 'SCENE')) %>%
  mutate(param = str_replace(param, 'COLCORR', 'COLOR')) %>%
  mutate(param = str_replace(param, 'EMOCORR', 'SOUND')) %>%
  mutate(param = str_replace(param, 'PAG', 'pAG')) %>%
  mutate(param = str_replace(param, 'AAG', 'aAG')) %>%
  mutate(param = str_replace(param, 'PHIPP', 'pHipp')) %>%
  mutate(param = str_replace(param, 'PREC', 'Prec')) %>%
  mutate(param = str_replace(param, 'VPMN', 'vPMN')) %>%
  mutate(param = str_replace(param, 'DPMN', 'dPMN')) %>%
  mutate(paramHeader = str_replace(paramHeader, 'VPMN', 'vPMN')) %>%
  mutate(paramHeader = str_replace(paramHeader, 'DPMN', 'dPMN')) %>%
  mutate(paramHeader = str_replace(paramHeader, 'MEMQ', 'Memory')) %>%
  select(-BetweenWithin, -ends_with('.unstand')) %>%
  rename(est = est.stand, se = se.stand, pval = pval.stand) %>%
  mutate(paramHeader = remove_dup(paramHeader))  -> two_factor_param_tbl_truncated

two_factor_param_tbl %>%
  mutate(paramHeader = remove_dup(paramHeader)) %>%
  mutate(BetweenWithin = remove_dup(BetweenWithin)) -> two_factor_param_tbl

# write to csv
write_csv(x = two_factor_param_tbl_truncated, "intermediate/05_type-Parameters_model-TwoFactorMeasure_detail-truncated_tbl.csv")

# Communality Table -------------------------------------------------------

createCommunTbl(M$data.neural_modelType.Measurement_measureModel.SingleFactor.out) -> SingleFactor
createCommunTbl(M$data.neural_modelType.Measurement_measureModel.TwoFactor.out) -> TwoFactor

left_join(SingleFactor, TwoFactor, by = c("param"), suffix = c(".SingleFactor", ".TwoFactor")) %>%
   mutate(param = str_replace(param, 'PHIPP', 'pHipp')) %>%
   mutate(param = str_replace(param, 'PREC', 'Prec')) %>%
   mutate(param = str_replace(param, 'AAG', 'aAG')) %>%
   mutate(param = str_replace(param, 'PAG', 'pAG')) %>%
   select(-starts_with('est_se')) -> JointTbl

write_csv(JointTbl, path = "intermediate/05_type-Communality_model-All_tbl.csv")
