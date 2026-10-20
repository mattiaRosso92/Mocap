# Historical Dance analysis: landscape_flagged_dyads_sensitivity.R
# Not the default manuscript workflow. See statistics_history/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_Stats.R')))
setwd(repo)

suppressPackageStartupMessages({library(dplyr);library(lme4);library(lmerTest)})
root <- file.path(repo,'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/legacy_logarithmic_recovered_dyads/05_LandscapeSimilarity/Component_1')
d <- read.csv(file.path(root,'Sensitivity_RawVsFisher/ModelData.csv'))
out <- file.path(root,'Sensitivity_FlaggedDyads')
stopifnot(!dir.exists(out));dir.create(out)
scenarios <- list(All35=integer(),Without15=15,Without5=5,Without15And5=c(15,5))
results <- list();diagnostics <- list()
for(scenario in names(scenarios)) for(scale in c('FisherZ','RawR')) for(outcome in c('Component','Entropy')) {
 x <- d %>% filter(!Dyad %in% scenarios[[scenario]],Outcome==outcome) %>%
  mutate(Dyad=factor(Dyad),Visual=factor(Visual,levels=c('No','Yes')),Music=factor(Music,levels=c('Diff','Same')))
 x$Y <- x[[scale]]
 stopifnot(nrow(x)==4*nlevels(x$Dyad))
 fit <- lmer(Y~Visual*Music+(1|Dyad),data=x)
 a <- as.data.frame(anova(fit,type=3));a$Term <- rownames(a);rownames(a)<-NULL
 cells <- with(x,tapply(Y,list(Visual,Music),mean))
 effects <- c(Visual=mean(cells['Yes',])-mean(cells['No',]),
  Music=mean(cells[,'Same'])-mean(cells[,'Diff']),
  'Visual:Music'=cells['Yes','Same']-cells['Yes','Diff']-cells['No','Same']+cells['No','Diff'])
 results[[paste(scenario,scale,outcome)]] <- mutate(a,Scenario=scenario,Scale=scale,Outcome=outcome,
  NDyads=nlevels(x$Dyad),Estimate=unname(effects[Term]))
 sh <- shapiro.test(residuals(fit))
 diagnostics[[paste(scenario,scale,outcome)]] <- data.frame(Scenario=scenario,Scale=scale,Outcome=outcome,
  W=unname(sh$statistic),PValue=sh$p.value,Singular=isSingular(fit),Convergence=paste(fit@optinfo$conv$lme4$messages,collapse='; '))
}
r <- bind_rows(results) %>% group_by(Scenario,Scale,Term) %>%
 mutate(PHolm=p.adjust(`Pr(>F)`,'holm')) %>% ungroup()
reference <- read.csv(file.path(root,'Sensitivity_RawVsFisher/MixedModels.csv'),check.names=FALSE)
check <- merge(filter(r,Scenario=='All35'),reference,by=c('Scale','Outcome','Term'),suffixes=c('_new','_old'))
stopifnot(nrow(check)==12,max(abs(check$PHolm_new-check$PHolm_old))<1e-10)
write.csv(r,file.path(out,'All_Tests.csv'),row.names=FALSE)
write.csv(bind_rows(diagnostics),file.path(out,'Residual_Diagnostics.csv'),row.names=FALSE)
md <- function(x) c(paste0('| ',paste(names(x),collapse=' | '),' |'),paste0('| ',paste(rep('---',ncol(x)),collapse=' | '),' |'),apply(x,1,function(y)paste0('| ',paste(y,collapse=' | '),' |')))
table <- r %>% select(Scenario,NDyads,Scale,Outcome,Term,Estimate,PHolm) %>%
 mutate(Estimate=signif(Estimate,4),PHolm=signif(PHolm,4))
writeLines(c('# Flagged-dyad exclusion sensitivity','',
 'Primary analysis remains all 35 dyads. Dyads 15 and 5 were flagged post hoc by large model residuals, not established data errors. These exclusions are exploratory checks only; no data were deleted and no pipeline defaults changed.','',
 'Same saved observations and Visual x Music random-intercept models. Holm correction across the two outcomes separately within each effect, scale and scenario; no correction across the exploratory scenarios. Estimates are marginal Visual (Yes minus No), marginal Music (Same minus Diff), and difference-in-differences.','',
 md(table),'','All35 reproduces previous adjusted p-values within 1e-10. Full tests and residual diagnostics are saved beside this report. Exclusion-dependent p-values must not be used to choose which dyads to retain.'),file.path(out,'Report.md'))
print(as.data.frame(table),row.names=FALSE)
cat('DIAGNOSTICS\n');print(bind_rows(diagnostics),row.names=FALSE)
