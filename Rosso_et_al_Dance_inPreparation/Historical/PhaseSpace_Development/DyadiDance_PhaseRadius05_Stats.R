# Historical Dance analysis: DyadiDance_PhaseRadius05_Stats.R
# Not the default manuscript workflow. See Historical/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/Historical/DyadiDance_StatisticalModels_Historical.R')))
setwd(repo)

suppressPackageStartupMessages({library(readxl);library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})
bonferroni_tests<-4;bonferroni_alpha<-.05/4
configured_metric_levels<-c(M1=.25,M2=.5,M3=1,M4=2)
expressions<-parse('Rosso_et_al_Dance_inPreparation/Historical/DyadiDance_StatisticalModels_Historical.R')
for(e in expressions) if(is.call(e) && identical(e[[1]],as.name('<-')) && is.call(e[[3]]) && identical(e[[3]][[1]],as.name('function')))eval(e)
root<-'Dance_Data/FREQNESS_Mocap_Stats_Results'
input<-'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/06_Statistics_R'
out<-file.path(root,'PhaseSpaceRQA_NonStandardized_Radius05/SelectedTransformations')
if (dir.exists(out) && length(list.files(out)) > 0) stop('Output exists: ', out)
inputs<-c('Legacy JRQA'='', 'Phase-space 10%'='PhaseSpaceRQA_NonStandardized','Phase-space 5%'='PhaseSpaceRQA_NonStandardized_Radius05')
models<-c('Legacy JRQA'='', 'Phase-space 10%'='PhaseSpaceRQA_NonStandardized/SelectedTransformations','Phase-space 5%'='PhaseSpaceRQA_NonStandardized_Radius05/SelectedTransformations')
labels<-c(M1='Beat / 4',M2='Beat / 2',M3='Beat',M4='2 x beat')
means<-list();omnibus<-list();posthoc<-list()
for(co in 1:2){
  dest<-file.path(out,paste0('Component_',co));dir.create(dest,recursive=TRUE,showWarnings=FALSE)
  f<-file.path(input,inputs[['Phase-space 5%']],paste0('OUT2R_Comp#',co,'.xlsx'))
  # Diagnostics favour log RR and raw DET in both components, as at 10%.
  analyse_component(f,co,dest,'PhaseSpaceRQANonStandardized')
  writeLines(c('Radius fraction: 0.05 of maximum eligible Euclidean distance.',
    'Input normalization: false. Saved trajectories reused from 10% run.',
    'Selected models: log RR; untransformed DET. Selection based on 5% residual diagnostics.',
    'Other preprocessing/settings unchanged; sensitivity analysis, not a new production default.'),file.path(dest,'Radius_Provenance.txt'))
  data<-bind_rows(lapply(names(inputs),function(method){
    d<-read_excel(file.path(input,inputs[[method]],paste0('OUT2R_Comp#',co,'.xlsx')))
    if('Subject'%in%names(d))names(d)[names(d)=='Subject']<-'Dyad'
    mutate(d,Method=method)
  }))
  keys<-c('Dyad','Visual','Music','Meter')
  stopifnot(identical(as.data.frame(data[data$Method=='Phase-space 5%',keys]),as.data.frame(data[data$Method=='Phase-space 10%',keys])))
  stopifnot(all(data$RR[data$Method=='Phase-space 5%']<=data$RR[data$Method=='Phase-space 10%']+1e-12))
  for(dv in c('RR','DET')){
    ref<-read.csv(file.path(dirname(out),'Transformation_Sensitivity/Factorial_Comparison.csv'),check.names=FALSE)
    ref<-ref[ref$Component==co & ref$Outcome==dv & ref$Scale==if(dv=='RR')'log' else 'raw',]
    fit<-read.csv(file.path(dest,dv,'All_Meters/Factorial_Type_III_ANOVA.csv'),check.names=FALSE)
    stopifnot(max(abs(ref[['F value']]-fit[['F value']]))<1e-6)
    for(method in names(models)){
      base<-file.path(root,models[[method]],paste0('Component_',co),dv)
      a<-read.csv(file.path(base,'All_Meters/Factorial_Type_III_ANOVA.csv'),check.names=FALSE)
      a$Method<-method;a$Component<-co;a$Outcome<-dv;omnibus[[length(omnibus)+1]]<-a
      a<-read.csv(file.path(base,'PostHoc_Type_III_ANOVA_Bonferroni.csv'),check.names=FALSE)
      a$Method<-method;a$Component<-co;a$Outcome<-dv;posthoc[[length(posthoc)+1]]<-a
    }
    avg<-data %>% group_by(Method,Meter,Visual,Music) %>% summarise(Mean=mean(.data[[dv]]),SEM=sd(.data[[dv]])/sqrt(n()),.groups='drop') %>%
      mutate(Method=factor(Method,levels=names(inputs)),Meter=factor(Meter,levels=names(labels),labels=labels),Music=factor(Music,levels=c('Diff','Same')))
    p<-ggplot(avg,aes(Music,Mean,color=Visual,group=Visual))+geom_line(linewidth=.8)+geom_point(size=2.2)+
      geom_errorbar(aes(ymin=Mean-SEM,ymax=Mean+SEM),width=.12)+facet_grid(Method~Meter)+
      scale_color_manual(values=c(No='#AA0000',Yes='#003399'))+theme_minimal(base_size=14)+theme(legend.position='bottom')+
      labs(title=paste('Component',co,'—',dv),subtitle='Original-scale means ± SEM; 33 dyads; shared axes. Phase-space inputs not z-normalized.',y=dv,x='Music')
    ggsave(file.path(out,paste0('Radius_Comparison_C',co,'_',dv,'.png')),p,width=15,height=10,dpi=150,bg='white')
    means[[length(means)+1]]<-data %>% group_by(Method,Meter) %>% summarise(Mean=mean(.data[[dv]]),.groups='drop') %>% mutate(Component=co,Outcome=dv)
  }
}
write.csv(bind_rows(means),file.path(out,'Comparison_Means.csv'),row.names=FALSE)
write.csv(bind_rows(omnibus),file.path(out,'Comparison_All_Factorial_Tests.csv'),row.names=FALSE)
write.csv(bind_rows(posthoc),file.path(out,'Comparison_All_PostHoc_Tests.csv'),row.names=FALSE)
cat('RADIUS05 STATISTICS AND VALIDATION COMPLETE\n')
