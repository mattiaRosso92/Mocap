# Historical Dance analysis: DyadicDance_Recovered35_Legacy_Stats.R
# Not the default manuscript workflow. See Historical/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/Historical/DyadicDance_StatisticalModels_Historical.R')))
setwd(repo)

suppressPackageStartupMessages({library(readxl);library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})
bonferroni_tests <- 4
bonferroni_alpha <- .05/4
configured_metric_levels <- c(M1=.25,M2=.5,M3=1,M4=2)
expressions <- parse(file.path(repo,'Rosso_et_al_Dance_inPreparation/Historical/DyadicDance_StatisticalModels_Historical.R'))
for(e in expressions) if(is.call(e) && identical(e[[1]],as.name('<-')) &&
  is.call(e[[3]]) && identical(e[[3]][[1]],as.name('function'))) eval(e)
base <- file.path(repo,'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation')
input <- file.path(base,'legacy_logarithmic_recovered_dyads/06_Statistics_R/JRQA_Legacy')
out <- file.path(repo,'Dance_Data/FREQNESS_Mocap_Stats_Results/Recovered35_LegacyJRQA')
stopifnot(!dir.exists(out))
dir.create(out,recursive=TRUE)
all_factorial <- list(); all_posthoc <- list(); all_diagnostics <- list()
for(co in 1:2) {
  file <- file.path(input,paste0('OUT2R_Comp#',co,'.xlsx'))
  data <- read_excel(file)
  old <- read_excel(file.path(base,'06_Statistics_R',paste0('OUT2R_Comp#',co,'.xlsx')))
  if('Subject' %in% names(old)) names(old)[names(old)=='Subject'] <- 'Dyad'
  keys <- c('Dyad','Visual','Music','Meter')
  subset <- data[!data$Dyad %in% c(13,32),]
  stopifnot(nrow(data)==560,length(unique(data$Dyad))==35,
    identical(as.data.frame(subset[keys]),as.data.frame(old[keys])),
    max(abs(subset$RR-old$RR))<1e-14,max(abs(subset$DET-old$DET))<1e-14)
  dest <- file.path(out,paste0('Component_',co));dir.create(dest)
  analyse_component(file,co,dest,'JRQA')
  for(dv in c('RR','DET')) {
    f <- read.csv(file.path(dest,dv,'All_Meters/Factorial_Type_III_ANOVA.csv'),check.names=FALSE)
    p <- read.csv(file.path(dest,dv,'PostHoc_Type_III_ANOVA_Bonferroni.csv'),check.names=FALSE)
    d <- read.csv(file.path(dest,dv,'All_Meters/Factorial_Residual_Shapiro_Wilk.csv'))
    all_factorial[[paste(co,dv)]] <- mutate(f,Component=co,Outcome=dv)
    all_posthoc[[paste(co,dv)]] <- mutate(p,Component=co,Outcome=dv)
    all_diagnostics[[paste(co,dv)]] <- mutate(d,Component=co,Outcome=dv)
  }
}
f <- bind_rows(all_factorial);p <- bind_rows(all_posthoc);d <- bind_rows(all_diagnostics)
write.csv(f,file.path(out,'All_Factorial_Tests.csv'),row.names=FALSE)
write.csv(p,file.path(out,'All_PostHoc_Tests.csv'),row.names=FALSE)
write.csv(d,file.path(out,'Residual_Normality.csv'),row.names=FALSE)
fmt <- function(x) ifelse(x<.001,formatC(x,format='e',digits=3),formatC(x,format='f',digits=5))
md <- function(x) c(paste0('| ',paste(names(x),collapse=' | '),' |'),paste0('| ',paste(rep('---',ncol(x)),collapse=' | '),' |'),apply(x,1,function(r)paste0('| ',paste(r,collapse=' | '),' |')))
lines <- c('# Legacy JRQA — 35 dyads','',
'Original legacy implementation, not FaithfulAdaptiveMax. Both components use m=2 and tau=10 samples at 25 Hz. Historical Butterworth(4, 0.8) filtering at the original sampling rate and 10-fold downsampling are preserved, followed by the central 15–85% window. RPparam estimates the participant-specific radius in its own embedding; the larger partner radius is passed to the legacy jrqa routine with its original defaults. This is a historical replication, not a corrected-method validation.','',
'Only the 63 retained trials from dyads 13 and 32 were computed (126 trial/component files). Original 33-dyad results are reused unchanged. A representative original trial was recomputed for each component and RR/DET matched within 1e-12. Both exported tables match the original 33-dyad RR/DET values within 1e-14.','',
'All 35 dyads contribute equally at the model level: trials are averaged within dyad, condition and meter. Dyad 13 has 7/8/9/8 trials; dyad 32 has 8/8/8/7. Dataset: 1,119 trials, 560 dyad-condition-meter observations per component. Only original trial 32 of dyad 32 is excluded.','',
'Models: natural-log RR and natural-log DET ~ Visual * Music * Meter + (1 | Dyad). Meter-specific models: log outcome ~ Visual * Music + (1 | Dyad). Type III tests; Bonferroni adjustment across four meters separately for each effect, alpha .05. No transformation/correction chosen based on significance.','',
'## All omnibus tests','')
a <- f[,c('Component','Outcome','Term','NumDF','DenDF','F value','Pr(>F)')]
a$DenDF <- round(a$DenDF,2);a[['F value']] <- round(a[['F value']],4);a[['Pr(>F)']] <- fmt(a[['Pr(>F)']])
lines <- c(lines,md(a),'','## All meter-specific tests','')
a <- p[,c('Component','Outcome','Meter','Term','PValueRaw','PValueBonferroni')]
a$PValueRaw <- fmt(a$PValueRaw);a$PValueBonferroni <- fmt(a$PValueBonferroni)
lines <- c(lines,md(a),'','## Residual diagnostics','',md(d),'',
'Residual normality tests are diagnostic, not proof of validity or invalidity of the full model. Significant within-meter effects alone do not establish that an effect differs between meters; inspect the corresponding Meter interaction.','',
'All plots, model summaries, polynomial models and diagnostics are retained in the component/outcome folders. Previous analyses have not been overwritten. No tracked toolbox or pipeline code changed.')
writeLines(lines,file.path(out,'Legacy35_Report.md'))
cat('OMNIBUS\n');print(f[,c('Component','Outcome','Term','F value','Pr(>F)')],row.names=FALSE)
cat('POSTHOC\n');print(p[,c('Component','Outcome','Meter','Term','PValueBonferroni')],row.names=FALSE)
cat('DIAGNOSTICS\n');print(d,row.names=FALSE)
cat('LEGACY35 STATISTICS COMPLETE\n')
