# Run from the repository root. Real-data checks skip when local inputs are absent.
suppressPackageStartupMessages({library(readxl);library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})
repo <- normalizePath(getwd())
script <- file.path(repo,"Rosso_et_al_Dance_inPreparation","FREQNESS_Mocap_Stats.R")
env <- new.env(parent=globalenv())
for(e in parse(script)) {
  if(is.call(e) && identical(e[[1]],as.name("<-")) &&
      (as.character(e[[2]]) %in% c("bonferroni_tests","bonferroni_alpha","configured_metric_levels") ||
       (is.call(e[[3]]) && identical(e[[3]][[1]],as.name("function"))))) eval(e,env)
}
root <- file.path(repo,"Dance_Data","FREQNESS_Results_Rosso_et_al_inPreparation",
  "legacy_logarithmic_recovered_dyads")
spatial <- file.path(root,"06_Statistics_R","SpatialCoordination","OUT2R_Comp#1.xlsx")
if(file.exists(spatial)) {
  input <- read_excel(spatial)
  for(case in c("missing_dyad","duplicate_key","missing_value")) {
    fixture <- input
    if(case=="missing_dyad") fixture <- fixture[fixture$Dyad!=13,]
    if(case=="duplicate_key") fixture[2,] <- fixture[1,]
    if(case=="missing_value") fixture$FisherZ[1] <- NA_real_
    env$read_excel <- function(...) fixture
    rejected <- tryCatch({env$analyse_component("fixture.xlsx",1,tempdir(),"SpatialRaw");FALSE},
      error=function(e) TRUE)
    stopifnot(rejected)
    message("PASS spatial input guard: ",case)
  }
  rm("read_excel",envir=env)
} else message("SKIP spatial real-data guards: local export absent")

reference <- file.path(root,"PhaseSpaceRQA_AA10Hz_Downsample_20261017")
if(file.exists(file.path(reference,"Factor10_Component1.xlsx"))) {
  output <- tempfile("dance-stat-regression-");dir.create(output)
  f_ref <- read.csv(file.path(reference,"R_Statistics","Primary_Factorial_Tests.csv"),check.names=FALSE)
  p_ref <- read.csv(file.path(reference,"R_Statistics","Primary_PostHoc_Tests.csv"),check.names=FALSE)
  for(component in 1:2) {
    folder <- file.path(output,paste0("Component_",component))
    input <- file.path(root,"06_Statistics_R","PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0",
      paste0("OUT2R_Comp#",component,".xlsx"))
    if(!file.exists(input)) input <- file.path(reference,paste0("Factor10_Component",component,".xlsx"))
    env$analyse_component(input,component,folder,"PhaseSpaceRQACorrected")
    for(dv in c("RR","DET")) {
      f <- read.csv(file.path(folder,dv,"All_Meters","Factorial_Type_III_ANOVA.csv"),check.names=FALSE)
      p <- read.csv(file.path(folder,dv,"PostHoc_Type_III_ANOVA_Bonferroni.csv"),check.names=FALSE)
      expected_f <- filter(f_ref,Component==component,Outcome==dv,Method=="10 Hz filter / 25 Hz")
      expected_p <- filter(p_ref,Component==component,Outcome==dv,Method=="10 Hz filter / 25 Hz")
      f <- f[match(expected_f$Term,f$Term),]
      p <- p[match(paste(expected_p$Term,expected_p$Meter),paste(p$Term,p$Meter)),]
      stopifnot(nrow(f)==7,nrow(p)==12,
        max(abs(f[["F value"]]-expected_f[["F value"]]))<1e-6,
        max(abs(f[["Pr(>F)"]]-expected_f[["Pr(>F)"]]))<1e-8,
        max(abs(p$PValueBonferroni-expected_p$PValueBonferroni))<1e-8)
      message("PASS unchanged corrected phase-space models: C",component," ",dv)
    }
  }
} else message("SKIP temporal regression: local reference absent")
