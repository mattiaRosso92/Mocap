# Historical Dance analysis: DyadicDance_PhaseAntialiasDownsample_Stats.R
# Not the default manuscript workflow. See Historical/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/Historical/DyadicDance_StatisticalModels_Historical.R')))
setwd(repo)

suppressPackageStartupMessages({library(readxl);library(dplyr);library(ggplot2);library(lmerTest)})
base <- file.path(repo,'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/legacy_logarithmic_recovered_dyads')
input <- file.path(base,'PhaseSpaceRQA_AA10Hz_Downsample_20261017')
out <- file.path(input,'R_Statistics')
if (dir.exists(out) && length(list.files(out)) > 0) stop('Output exists: ', out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
methods <- c('Legacy filter / 25 Hz','10 Hz filter / 25 Hz','10 Hz filter / 50 Hz','10 Hz filter / 50 Hz; matched span')
all_data <- list(); tests <- list(); posthoc <- list(); diagnostics <- list(); fitted_models <- list()
for(co in 1:2) {
  files <- c(file.path(base,'06_Statistics_R/PhaseSpaceRQA_NonStandardized',paste0('OUT2R_Comp#',co,'.xlsx')),
             file.path(input,paste0('Factor10_Component',co,'.xlsx')),
             file.path(input,paste0('Factor5_Component',co,'.xlsx')),
             file.path(input,paste0('Factor5_Component',co,'_SpanMatched.xlsx')))
  reference_keys <- NULL
  for(mi in seq_along(methods)) {
    d <- as.data.frame(read_excel(files[mi])); keys <- c('Dyad','Visual','Music','Meter')
    stopifnot(nrow(d)==560,length(unique(d$Dyad))==35,all(is.finite(d$RR)),all(is.finite(d$DET)))
    if(is.null(reference_keys)) reference_keys<-d[keys] else stopifnot(identical(reference_keys,d[keys]))
    d$Method <- methods[mi]; d$Component <- co; all_data[[paste(co,mi)]] <- d
    for(n in keys) d[[n]] <- factor(d[[n]])
    for(dv in c('RR','DET')) {
      if(mi==4 && dv=='RR') next
      for(scale in c('raw','log')) {
        stopifnot(all(d[[dv]]>0)); d$Y <- if(scale=='log') log(d[[dv]]) else d[[dv]]
        model <- lmer(Y~Visual*Music*Meter+(1|Dyad),data=d)
        e<-residuals(model); z<-(e-mean(e))/sd(e); sh<-shapiro.test(e)
        diagnostics[[length(diagnostics)+1]] <- data.frame(Component=co,Method=methods[mi],Outcome=dv,Scale=scale,W=unname(sh$statistic),P=sh$p.value,Skewness=mean(z^3),ExcessKurtosis=mean(z^4)-3,Singular=isSingular(model),Convergence=paste(model@optinfo$conv$lme4$messages,collapse='; '))
        a<-as.data.frame(anova(model,type=3));a$Term<-rownames(a)
        a$Component<-co;a$Method<-methods[mi];a$Outcome<-dv;a$Scale<-scale
        tests[[length(tests)+1]]<-a
        p<-list()
        for(meter in levels(d$Meter)) {
          m<-lmer(Y~Visual*Music+(1|Dyad),data=d[d$Meter==meter,])
          a<-as.data.frame(anova(m,type=3));a$Term<-rownames(a);a$Meter<-meter;p[[meter]]<-a
        }
        a<-bind_rows(p);a$PValueRaw<-a[['Pr(>F)']]
        a$PValueBonferroni<-ave(a$PValueRaw,a$Term,FUN=function(x)p.adjust(x,'bonferroni'))
        a$Component<-co;a$Method<-methods[mi];a$Outcome<-dv;a$Scale<-scale;posthoc[[length(posthoc)+1]]<-a
        fitted_models[[paste(co,mi,dv,scale)]]<-model
      }
    }
  }
}
data<-bind_rows(all_data); f<-tibble::as_tibble(bind_rows(tests)); p<-tibble::as_tibble(bind_rows(posthoc)); diag<-tibble::as_tibble(bind_rows(diagnostics))
# Retain the established primary scales across methods; report both scales as diagnostics/sensitivity.
primary<-function(d) d %>% filter((Outcome=='RR' & Scale=='log') | (Outcome=='DET' & Scale=='raw'))
fp<-primary(f); pp<-primary(p)
write.csv(f,file.path(out,'All_Factorial_Tests_BothScales.csv'),row.names=FALSE)
write.csv(p,file.path(out,'All_PostHoc_Tests_BothScales.csv'),row.names=FALSE)
write.csv(fp,file.path(out,'Primary_Factorial_Tests.csv'),row.names=FALSE)
write.csv(pp,file.path(out,'Primary_PostHoc_Tests.csv'),row.names=FALSE)
write.csv(diag,file.path(out,'Residual_Diagnostics.csv'),row.names=FALSE)
write.csv(data,file.path(out,'All_Model_Data.csv'),row.names=FALSE)
# Verify that unchanged legacy data reproduce the saved full-factorial model.
for(co in 1:2) for(dv in c('RR','DET')) {
  old <- read.csv(file.path(repo,'Dance_Data/FREQNESS_Mocap_Stats_Results/Recovered35_Faithful_vs_Phase10/PhaseSpaceRQANonStandardized',paste0('Component_',co),dv,'All_Meters/Factorial_Type_III_ANOVA.csv'),check.names=FALSE)
  new <- fp %>% filter(Component==co,Outcome==dv,Method==methods[1])
  stopifnot(identical(old$Term,new$Term),max(abs(old[['Pr(>F)']]-new[['Pr(>F)']]))<1e-8)
}
labels <- c(M1='Beat / 4',M2='Beat / 2',M3='Beat',M4='2 × beat')
for(co in 1:2) for(dv in c('RR','DET')) {
  avg <- data %>% filter(Component==co,Method!=methods[4]) %>% group_by(Method,Meter,Visual,Music) %>%
    summarise(Mean=mean(.data[[dv]]),SEM=sd(.data[[dv]])/sqrt(n()),.groups='drop') %>%
    mutate(Method=factor(Method,levels=methods),Meter=factor(Meter,levels=names(labels),labels=labels),Music=factor(Music,levels=c('Diff','Same')))
  g<-ggplot(avg,aes(Music,Mean,color=Visual,group=Visual))+geom_line(linewidth=.8)+geom_point(size=2)+geom_errorbar(aes(ymin=Mean-SEM,ymax=Mean+SEM),width=.12)+
    facet_grid(Method~Meter)+scale_color_manual(values=c(No='#AA0000',Yes='#003399'))+
    labs(title=paste('Phase-space RQA — Component',co,'—',dv),subtitle='35 dyads; non-standardized signals; 10% radius; lmin = 2. Raw mean ± SEM; shared vertical scale.',x='Music',y=dv)+theme_minimal(base_size=13)+theme(legend.position='bottom')
  ggsave(file.path(out,paste0('Comparison_C',co,'_',dv,'.png')),g,width=14,height=9,dpi=150,bg='white')
  png(file.path(out,paste0('Residuals_C',co,'_',dv,'.png')),width=1800,height=1700,res=160)
  par(mfrow=c(3,2),mar=c(4,4,3,1))
  for(mi in 1:3) for(scale in c('raw','log')) {m<-fitted_models[[paste(co,mi,dv,scale)]];qqnorm(residuals(m),main=paste(methods[mi],scale));qqline(residuals(m),col='red')}
  dev.off()
}
means<-data %>% group_by(Component,Method) %>% summarise(RR=mean(RR),DET=mean(DET),.groups='drop')
write.csv(means,file.path(out,'Outcome_Means.csv'),row.names=FALSE)
fmt<-function(x)ifelse(x<.001,formatC(x,format='e',digits=3),formatC(x,format='f',digits=5))
md<-function(x)c(paste0('| ',paste(names(x),collapse=' | '),' |'),paste0('| ',paste(rep('---',ncol(x)),collapse=' | '),' |'),apply(x,1,function(r)paste0('| ',paste(r,collapse=' | '),' |')))
tab<-fp[,c('Component','Outcome','Method','Term','NumDF','DenDF','F value','Pr(>F)')];tab[['Pr(>F)']]<-fmt(tab[['Pr(>F)']]);tab[['F value']]<-round(tab[['F value']],4);tab$DenDF<-round(tab$DenDF,2)
sig<-pp %>% filter(PValueBonferroni<.05) %>% select(Component,Outcome,Method,Term,Meter,PValueBonferroni)
sig$PValueBonferroni<-fmt(sig$PValueBonferroni)
beat<-pp %>% filter(Outcome=='RR',Term=='Visual',Meter=='M3') %>% select(Component,Method,PValueRaw,PValueBonferroni)
lines<-c('# Phase-space RQA: fixed 10 Hz filtering and sampling-rate sensitivity','',
'## Findings in brief','',
'All 1,119 trials completed in 1,706.6 seconds (28.4 minutes, excluding MATLAB startup). The worktree remains unchanged; analysis drivers and outputs are ignored. No core estimation or earlier analysis was overwritten.','',
'Filtering correction leaves the broad phase-space condition patterns similar. Component 1 beat Visual RR has Bonferroni-adjusted p = .05496 (legacy 25 Hz), .04216 (corrected 25 Hz), and .03822 (corrected 50 Hz). This small threshold crossing does not establish beat specificity: Visual-by-Meter remains nonsignificant (.605 and .561 in the corrected runs). Both corrected rates retain Music effects on RR at beat/4 and beat for Component 1, and beat/4 for Component 2.','',
'DET is much more sampling-sensitive: mean Component 1 DET rises from .816 at corrected 25 Hz to .961 at 50 Hz with lmin=2; Component 2 rises from .863 to .977. With lmin=3 at 50 Hz, means become .854 and .898. Music effects at beat/4 and beat survive in both components and both rates. Component 1 Music-by-Meter changes from p=.000564 at 25 Hz to p=.1245 at 50 Hz with lmin=2, but p=.00130 with matched-span lmin=3. The doubled sampling density and shortened minimum temporal span should not be interpreted as stronger interpersonal coordination.','',
'Log RR and raw DET remain preferable to their alternatives by residual Shapiro W across all variants. No fitted omnibus model is singular or reports a convergence warning. Nevertheless, DET residuals remain non-normal and become markedly worse at 50 Hz with lmin=2. Component 2 log-RR residuals also reject normality. The preserved manuscript-model p-values therefore require qualification; these checks do not establish all modelling assumptions.','',
'Earlier original-legacy-JRQA versus phase-space comparisons shared the legacy filter. Corrected-JRQA versus legacy-preprocessed phase-space comparisons had unequal filtering, in addition to other methodological differences. The new results address the phase-space filtering sensitivity; they do not retroactively make those comparisons algorithm-only tests.','',
'## Methods and validation','',
'35 dyads; 1,119 retained trials; two components; four partner-specific beat-relative metric levels. Core estimation was reused unchanged. New analyses use the same fourth-order Butterworth filter, designed at 250 Hz with a 10 Hz cutoff and applied with filtfilt before decimation by 10 or 5. Non-standardized signals, radius 10% of maximum Euclidean distance, Theiler window zero. The legacy 25 Hz comparator retains its original 100 Hz filter. Outputs are separate from all earlier analyses.','',
'Primary minimum diagonal length is two samples at both rates. The supplementary 50 Hz analysis uses three samples, matching the 40 ms first-to-last-point span of two samples at 25 Hz. Duration selection follows the original round(15%):round(85%) convention at each rate; endpoint rounding differs by one 50 Hz sample. No signal stretching or tempo equalization.','',
'RR/DET-only calculations were checked against the full public function on both components, four metric levels and both sampling rates of the first trial (tolerance 1e-12). Saved configurations, trial identifiers, sample counts, frequencies and thresholds accompany each trial.','',
'Primary models retain the established log RR and raw DET transformations for a controlled comparison. Raw/log residual diagnostics and both-scale tests are provided separately; significance was not used to choose transformations. Model: outcome ~ Visual * Music * Meter + (1 | Dyad); Type III tests with Satterthwaite degrees of freedom. Within-meter models: outcome ~ Visual * Music + (1 | Dyad), Bonferroni correction across four meters per effect. Dyad-condition-meter inputs average available trials, with no dyad exclusions. Alpha .05. These are paired sensitivity analyses, not independent replications; no additional correction across analysis variants.','',
'Unchanged legacy omnibus p-values reproduce the saved results within 1e-8.','',
'## Outcome means','',md(as.data.frame(means)),'','## Beat Visual effect on RR','',md(as.data.frame(beat)),
'','## All omnibus tests','',md(tab),'','## Significant corrected within-meter effects','',md(as.data.frame(sig)),
'','## Residual diagnostics (both scales)','',md(as.data.frame(diag)),'',
'The 10,000-sample limit is an implementation guard against dense quadratic matrix allocation, not a statistical limit or a property of RQA. At 10,000 samples one double matrix uses 800 MB (decimal), before intermediate arrays and masks. The current implementation computes dense distances even when store_matrices=false; that flag controls retained outputs, not peak working memory.','')
for(co in 1:2) for(dv in c('RR','DET')) lines<-c(lines,paste0('![C',co,' ',dv,'](',file.path(out,paste0('Comparison_C',co,'_',dv,'.png')),')'),'')
writeLines(lines,file.path(out,'Report.md'))
cat('LEGACY REGRESSION PASSED\nSIGNIFICANT PRIMARY OMNIBUS\n');print(fp %>% filter(`Pr(>F)`<.05) %>% select(Component,Outcome,Method,Term,`Pr(>F)`),n=100)
cat('BEAT RR VISUAL\n');print(beat,n=100);cat('MEANS\n');print(means,n=100);cat('SIGNIFICANT PRIMARY POSTHOC\n');print(sig,n=100)
cat('COMPLETE\n')
