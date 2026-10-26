# Historical Dance analysis: DyadicDance_Recovered35_Radius05_Stats.R
# Not the default manuscript workflow. See Historical/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/Historical/DyadicDance_StatisticalModels_Historical.R')))
setwd(repo)

suppressPackageStartupMessages({library(readxl);library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})
bonferroni_tests <- 4; bonferroni_alpha <- .05/4
configured_metric_levels <- c(M1=.25,M2=.5,M3=1,M4=2)
expressions <- parse(file.path(repo,'Rosso_et_al_Dance_inPreparation/Historical/DyadicDance_StatisticalModels_Historical.R'))
for(e in expressions) if(is.call(e) && identical(e[[1]],as.name('<-')) && is.call(e[[3]]) && identical(e[[3]][[1]],as.name('function'))) eval(e)
base <- file.path(repo,'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation')
input <- file.path(base,'legacy_logarithmic_recovered_dyads/06_Statistics_R')
stats <- file.path(repo,'Dance_Data/FREQNESS_Mocap_Stats_Results')
out <- file.path(stats,'Recovered35_Phase05_vs_Phase10')
stopifnot(!dir.exists(out));dir.create(out,recursive=TRUE)
factorial<-list();posthoc<-list();diagnostics<-list();means<-list()
for(co in 1:2) {
  name<-paste0('OUT2R_Comp#',co,'.xlsx')
  file<-file.path(input,'PhaseSpaceRQA_NonStandardized_Radius05',name)
  a<-read_excel(file); b<-read_excel(file.path(input,'PhaseSpaceRQA_NonStandardized',name))
  old<-read_excel(file.path(base,'06_Statistics_R/PhaseSpaceRQA_NonStandardized_Radius05',name))
  keys<-c('Dyad','Visual','Music','Meter')
  stopifnot(nrow(a)==560,length(unique(a$Dyad))==35,identical(a[keys],b[keys]))
  unchanged<-a[!a$Dyad %in% c(13,32),]
  stopifnot(identical(unchanged[keys],old[keys]),max(abs(unchanged$RR-old$RR))<1e-14,max(abs(unchanged$DET-old$DET))<1e-14,all(a$RR<=b$RR+1e-12))
  dest<-file.path(out,'Radius05',paste0('Component_',co));dir.create(dest,recursive=TRUE)
  analyse_component(file,co,dest,'PhaseSpaceRQANonStandardized')
  data<-bind_rows(mutate(a,Radius='5%'),mutate(b,Radius='10%'))
  for(dv in c('RR','DET')) {
    for(radius in c('5%','10%')) {
      folder<-if(radius=='5%') dest else file.path(stats,'Recovered35_Faithful_vs_Phase10/PhaseSpaceRQANonStandardized',paste0('Component_',co))
      f<-read.csv(file.path(folder,dv,'All_Meters/Factorial_Type_III_ANOVA.csv'),check.names=FALSE)
      p<-read.csv(file.path(folder,dv,'PostHoc_Type_III_ANOVA_Bonferroni.csv'),check.names=FALSE)
      d<-read.csv(file.path(folder,dv,'All_Meters/Factorial_Residual_Shapiro_Wilk.csv'))
      factorial[[paste(co,dv,radius)]]<-mutate(f,Component=co,Outcome=dv,Radius=radius)
      posthoc[[paste(co,dv,radius)]]<-mutate(p,Component=co,Outcome=dv,Radius=radius)
      diagnostics[[paste(co,dv,radius)]]<-mutate(d,Component=co,Outcome=dv,Radius=radius)
    }
    labels<-c(M1='Beat / 4',M2='Beat / 2',M3='Beat',M4='2 × beat')
    avg<-data %>% group_by(Radius,Meter,Visual,Music) %>% summarise(Mean=mean(.data[[dv]]),SEM=sd(.data[[dv]])/sqrt(n()),.groups='drop') %>%
      mutate(Meter=factor(Meter,levels=names(labels),labels=labels),Music=factor(Music,levels=c('Diff','Same')),Radius=factor(Radius,levels=c('10%','5%')))
    g<-ggplot(avg,aes(Music,Mean,color=Visual,group=Visual))+geom_line(linewidth=.85)+geom_point(size=2.4)+geom_errorbar(aes(ymin=Mean-SEM,ymax=Mean+SEM),width=.12)+
      facet_grid(Radius~Meter,scales='free_y')+scale_color_manual(values=c(No='#AA0000',Yes='#003399'))+
      labs(title=paste('35 dyads — Phase-space RQA — Component',co,'—',dv),subtitle='Non-standardised trajectories. Radius as fraction of maximum distance; separate row scales. Mean ± SEM.',x='Music',y=dv)+
      theme_minimal(base_size=14)+theme(legend.position='bottom')
    ggsave(file.path(out,paste0('Radius35_C',co,'_',dv,'.png')),g,width=14,height=7,dpi=160,bg='white')
    means[[paste(co,dv)]]<-data %>% group_by(Radius) %>% summarise(Mean=mean(.data[[dv]]),.groups='drop') %>% mutate(Component=co,Outcome=dv)
  }
}
f<-bind_rows(factorial);p<-bind_rows(posthoc);d<-bind_rows(diagnostics);m<-bind_rows(means)
write.csv(f,file.path(out,'All_Factorial_Tests.csv'),row.names=FALSE)
write.csv(p,file.path(out,'All_PostHoc_Tests.csv'),row.names=FALSE)
write.csv(d,file.path(out,'Residual_Normality.csv'),row.names=FALSE)
write.csv(m,file.path(out,'Outcome_Means.csv'),row.names=FALSE)
cat('SIGNIFICANT 5% OMNIBUS\n');print(f %>% filter(Radius=='5%',`Pr(>F)`<.05) %>% select(Component,Outcome,Term,`F value`,`Pr(>F)`),row.names=FALSE)
cat('SIGNIFICANT 5% POSTHOC\n');print(p %>% filter(Radius=='5%',SignificantBonferroni) %>% select(Component,Outcome,Term,Meter,PValueBonferroni),row.names=FALSE)
cat('BEAT VISUAL RR\n');print(p %>% filter(Outcome=='RR',Term=='Visual',Meter=='M3') %>% select(Component,Radius,PValueRaw,PValueBonferroni),row.names=FALSE)
cat('MEANS\n');print(m);cat('DIAGNOSTICS\n');print(d)
fmt<-function(x) ifelse(x<.001,formatC(x,format='e',digits=3),formatC(x,format='f',digits=5))
md<-function(x)c(paste0('| ',paste(names(x),collapse=' | '),' |'),paste0('| ',paste(rep('---',ncol(x)),collapse=' | '),' |'),apply(x,1,function(r)paste0('| ',paste(r,collapse=' | '),' |')))
lines<-c('# 35-dyad phase-space RQA: 5% versus 10% radius','',
'The 5% analysis reuses the completed 33-dyad 5% values exactly and computes only the recovered 63 trials × two components. No core estimation, preprocessing or 10% analysis was repeated. Saved non-standardised trajectories determine the Euclidean distances, and radius is 5% of maximum eligible distance, not a fixed 5% recurrence rate. Only RR and DET were recalculated/saved for the new 5% trials.','',
'The new trials reproduce their saved 10% RR values within 1e-12 before threshold reduction; 10% DET is additionally checked on the first retained trial of each condition/dyad/component. All 5% RR values are no greater than their 10% counterparts. The 33-dyad RR/DET arrays and exported means are unchanged. Each component has 4,476 trial-level metric observations and 560 dyad-condition-meter statistical rows. Dyad 13 retains 7/8/9/8 trials; dyad 32 retains 8/8/8/7.','',
'Models and transformations are unchanged: log RR, raw DET; outcome ~ Visual * Music * Meter + (1 | Dyad). Within-meter models use Visual * Music + (1 | Dyad), with Bonferroni correction across four metric levels per effect. Results use all 35 dyads. No transformation or radius was selected based on significance.','',
'## Means across dyad-condition-meter observations','',md(as.data.frame(m)),'','## Beat Visual effect on RR','')
beat<-p[p$Outcome=='RR' & p$Term=='Visual' & p$Meter=='M3',c('Component','Radius','PValueRaw','PValueBonferroni')]
beat$PValueRaw<-fmt(beat$PValueRaw);beat$PValueBonferroni<-fmt(beat$PValueBonferroni)
lines<-c(lines,md(beat),'','## All significant 5% meter-specific effects','')
sig<-p[p$Radius=='5%' & p$SignificantBonferroni,c('Component','Outcome','Term','Meter','PValueBonferroni')];sig$PValueBonferroni<-fmt(sig$PValueBonferroni)
lines<-c(lines,md(sig),'','Meter mapping: M1 = beat/4; M2 = beat/2; M3 = beat; M4 = 2beat.','',
'## All omnibus tests','')
tab<-f[,c('Component','Outcome','Radius','Term','NumDF','DenDF','F value','Pr(>F)')];tab$DenDF<-round(tab$DenDF,2);tab[['F value']]<-round(tab[['F value']],4);tab[['Pr(>F)']]<-fmt(tab[['Pr(>F)']])
lines<-c(lines,md(tab),'','## Residual normality','')
d$PValue<-fmt(d$PValue);lines<-c(lines,md(d),'',
'Residual diagnostics accompany the preserved models; significant Shapiro tests flag departures from normality, not a complete assessment of mixed-model validity. Threshold sensitivity is not independent replication, and a significant beat-level test alone does not establish beat specificity.','')
for(co in 1:2) for(dv in c('RR','DET')) lines<-c(lines,paste0('## Component ',co,' ',dv),'',paste0('![Comparison](',file.path(out,paste0('Radius35_C',co,'_',dv,'.png')),')'),'')
lines<-c(lines,'All post-hoc tests, including nonsignificant ones, are in All_PostHoc_Tests.csv. Individual model outputs, polynomial comparisons and residual plots are in Radius05/Component_1 and Component_2. No tracked code or earlier output was changed.')
writeLines(lines,file.path(out,'Radius05_35Dyads_Report.md'))
cat('RADIUS05_35 STATS COMPLETE\n')
