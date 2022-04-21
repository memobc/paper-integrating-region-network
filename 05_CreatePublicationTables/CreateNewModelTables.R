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
    select(-est_se) -> unstand

  x$parameters$stdyx.standardized %>%
    as_tibble() %>%
    select(-est_se) %>%
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

grab_and_formatParams <- function(x){
createParamTbl(x) %>% 
  filter(str_detect(paramHeader, 'ON')) %>%
  filter(!param %in% c('VPMN', 'DPMN'))  %>%
  arrange(paramHeader) %>%
  select(-BetweenWithin, -ends_with('.unstand'))
}

createParamTbl(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.ToFeatures_ColCorr.out) %>% 
filter(BetweenWithin == 'Within') %>%
select(paramHeader, param, est.stand, se.stand, pval.stand) %>% 
mutate(paramHeader = remove_dup(paramHeader)) -> ColCorr

createParamTbl(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.ToFeatures_SceCorr.out) %>% 
filter(BetweenWithin == 'Within') %>%
select(paramHeader, param, est.stand, se.stand, pval.stand) %>%
mutate(paramHeader = remove_dup(paramHeader)) -> SceCorr

createParamTbl(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.ToFeatures_EmoCorr.out) %>% 
filter(BetweenWithin == 'Within') %>%
select(paramHeader, param, est.stand, se.stand, pval.stand) %>%
mutate(paramHeader = remove_dup(paramHeader)) -> EmoCorr

#grab_and_formatParams(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.Features_Model1.out) -> pHIPP
#grab_and_formatParams(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.Features_Model2.out) -> PREC
#grab_and_formatParams(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.Features_Model3.out) -> PCC
#grab_and_formatParams(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.Features_Model4.out) -> MPFC
#grab_and_formatParams(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.Features_Model5.out) -> PHC
#grab_and_formatParams(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.Features_Model6.out) -> RSC
#grab_and_formatParams(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.Features_Model7.out) -> PAG
#grab_and_formatParams(M$data.all_modelType.Structural_measureModel.TwoFactor_modelName.Features_Model8.out) -> AAG

#bind_rows(pHIPP, PREC, PCC, MPFC, PHC, RSC, PAG, AAG, .id = 'Model') %>%
#  mutate(Model = factor(Model, labels = c('pHIPP', 'PREC', 'PCC', 'MPFC', 'PHC', 'RSC', 'PAG', 'AAG'))) -> KeyParameterTbl

#write_csv(modelFitInformation, 'intermediate/05_Revision_ModelFitInformation.csv')
#write_csv(BaseModel, 'intermediate/05_Revision_BaseModelParams.csv')
#write_csv(KeyParameterTbl, 'intermediate/05_Revision_ROIContributions.csv')
