# Historical Dance analysis: DyadicDance_Recovered35_Stats.R
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
input_root <- file.path(base,'legacy_logarithmic_recovered_dyads/06_Statistics_R')
stats_root <- file.path(repo,'Dance_Data/FREQNESS_Mocap_Stats_Results')
out <- file.path(stats_root,'Recovered35_Faithful_vs_Phase10')
stopifnot(!dir.exists(out))
dir.create(out,recursive=TRUE)
methods <- list(
  FaithfulAdaptiveMaxJRQA=list(input='JRQA_Validated/FaithfulAdaptiveMax',old='JRQA_Validated/FaithfulAdaptiveMax',label='Faithful adaptive-max JRQA'),
  PhaseSpaceRQANonStandardized=list(input='PhaseSpaceRQA_NonStandardized',old='PhaseSpaceRQA_NonStandardized/SelectedTransformations',label='Phase-space RQA, 10%'))
all_factorial <- list();all_posthoc <- list();all_shapiro <- list();all_data <- list();all_polynomial <- list()
for(method in names(methods)) {
  spec <- methods[[method]]
  for(co in 1:2) {
    name <- paste0('OUT2R_Comp#',co,'.xlsx')
    file <- file.path(input_root,spec$input,name)
    data <- read_excel(file)
    old_data <- read_excel(file.path(base,'06_Statistics_R',spec$input,name))
    stopifnot(nrow(data)==560,length(unique(data$Dyad))==35)
    keys<-c('Dyad','Visual','Music','Meter')
    subset<-data[!data$Dyad %in% c(13,32),]
    stopifnot(identical(as.data.frame(subset[keys]),as.data.frame(old_data[keys])))
    stopifnot(max(abs(subset$RR-old_data$RR))<1e-14,max(abs(subset$DET-old_data$DET))<1e-14)
    dest<-file.path(out,method,paste0('Component_',co))
    dir.create(dest,recursive=TRUE)
    analyse_component(file,co,dest,method)
    all_data[[paste(method,co)]]<-mutate(data,Method=spec$label,Component=co)
    for(dv in c('RR','DET')) {
      for(n in c(33,35)) {
        folder<-if(n==35) dest else file.path(stats_root,spec$old,paste0('Component_',co))
        f<-read.csv(file.path(folder,dv,'All_Meters/Factorial_Type_III_ANOVA.csv'),check.names=FALSE)
        p<-read.csv(file.path(folder,dv,'PostHoc_Type_III_ANOVA_Bonferroni.csv'),check.names=FALSE)
        all_factorial[[paste(method,co,dv,n)]]<-mutate(f,Method=spec$label,Component=co,Outcome=dv,Dyads=n)
        all_posthoc[[paste(method,co,dv,n)]]<-mutate(p,Method=spec$label,Component=co,Outcome=dv,Dyads=n)
      }
      shapiro_file<-list.files(file.path(dest,dv,'All_Meters'),pattern='Shapiro',full.names=TRUE)
      for(f in shapiro_file) all_shapiro[[paste(method,co,dv,basename(f))]]<-mutate(read.csv(f),Method=spec$label,Component=co,Outcome=dv,Source=basename(f))
    }
  }
}
factorial<-bind_rows(all_factorial);posthoc<-bind_rows(all_posthoc)
write.csv(factorial,file.path(out,'All_Factorial_Tests_33_vs_35.csv'),row.names=FALSE)
write.csv(posthoc,file.path(out,'All_PostHoc_Tests_33_vs_35.csv'),row.names=FALSE)
write.csv(bind_rows(all_shapiro),file.path(out,'Residual_Normality.csv'),row.names=FALSE)
data<-bind_rows(all_data)
labels<-c(M1='Beat / 4',M2='Beat / 2',M3='Beat',M4='2 × beat')
for(co in 1:2) for(dv in c('RR','DET')) {
  a<-data %>% filter(Component==co) %>% group_by(Method,Meter,Visual,Music) %>%
    summarise(Mean=mean(.data[[dv]]),SEM=sd(.data[[dv]])/sqrt(n()),.groups='drop') %>%
    mutate(Meter=factor(Meter,levels=names(labels),labels=labels),Music=factor(Music,levels=c('Diff','Same')))
  p<-ggplot(a,aes(Music,Mean,color=Visual,group=Visual))+
    geom_line(linewidth=.85)+geom_point(size=2.4)+geom_errorbar(aes(ymin=Mean-SEM,ymax=Mean+SEM),width=.12)+
    facet_grid(Method~Meter,scales='free_y')+scale_color_manual(values=c(No='#AA0000',Yes='#003399'))+
    labs(title=paste('35 dyads — Component',co,'—',dv),subtitle='Original-scale means ± SEM. Separate method scales; all retained trials averaged within dyad and condition.',x='Music',y=dv)+
    theme_minimal(base_size=14)+theme(legend.position='bottom')
  ggsave(file.path(out,paste0('Comparison35_C',co,'_',dv,'.png')),p,width=14,height=7,dpi=160,bg='white')
}
cat('\nSIGNIFICANT OMNIBUS TERMS (35 dyads)\n')
print(factorial %>% filter(Dyads==35,`Pr(>F)`<.05) %>% select(Method,Component,Outcome,Term,`F value`,`Pr(>F)`),row.names=FALSE)
cat('\nSIGNIFICANT POSTHOC TERMS (35 dyads, adjusted p)\n')
print(posthoc %>% filter(Dyads==35,SignificantBonferroni) %>% select(Method,Component,Outcome,Term,Meter,PValueBonferroni),row.names=FALSE)
cat('\nBEAT VISUAL RR\n')
print(posthoc %>% filter(Outcome=='RR',Term=='Visual',Meter=='M3') %>% select(Method,Component,Dyads,PValueRaw,PValueBonferroni),row.names=FALSE)
cat('RECOVERED35 STATISTICS COMPLETE\n')
