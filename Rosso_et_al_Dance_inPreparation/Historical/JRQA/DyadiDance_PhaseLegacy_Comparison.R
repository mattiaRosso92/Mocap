# Historical Dance analysis: DyadiDance_PhaseLegacy_Comparison.R
# Not the default manuscript workflow. See Historical/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/Historical/DyadiDance_StatisticalModels_Historical.R')))
setwd(repo)

suppressPackageStartupMessages({library(readxl);library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})
bonferroni_tests <- 4
bonferroni_alpha <- .05/4
configured_metric_levels <- c(M1=.25,M2=.5,M3=1,M4=2)
repo <- getwd()
expressions <- parse('Rosso_et_al_Dance_inPreparation/Historical/DyadiDance_StatisticalModels_Historical.R')
for(e in expressions) if(is.call(e) && identical(e[[1]],as.name('<-')) &&
  is.call(e[[3]]) && identical(e[[3]][[1]],as.name('function'))) eval(e)
input <- file.path(repo,'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/06_Statistics_R')
out <- file.path(repo,'Dance_Data/FREQNESS_Mocap_Stats_Results/PhaseSpaceRQA_NonStandardized/SelectedTransformations')
if (dir.exists(out) && length(list.files(out)) > 0) stop('Output exists: ', out)
labels <- c(M1='Beat / 4',M2='Beat / 2',M3='Beat',M4='2 x beat')
for(co in 1:2) {
  dest<-file.path(out,paste0('Component_',co));dir.create(dest,recursive=TRUE,showWarnings=FALSE)
  f<-file.path(input,'PhaseSpaceRQA_NonStandardized',paste0('OUT2R_Comp#',co,'.xlsx'))
  analyse_component(f,co,dest,'PhaseSpaceRQANonStandardized')
  old<-read_excel(file.path(input,paste0('OUT2R_Comp#',co,'.xlsx')))
  if('Subject' %in% names(old)) names(old)[names(old)=='Subject']<-'Dyad'
  new<-read_excel(f)
  keys<-c('Dyad','Visual','Music','Meter')
  stopifnot(identical(as.data.frame(old[keys]),as.data.frame(new[keys])))
  data<-bind_rows(mutate(old,Method='Legacy JRQA'),mutate(new,Method='Latest phase-space RQA'))
  for(dv in c('RR','DET')) {
    # Match the independently fitted raw/log sensitivity models numerically.
    check<-read.csv(file.path(dest,dv,'All_Meters/Factorial_Type_III_ANOVA.csv'),check.names=FALSE)
    reference<-read.csv(file.path(dirname(out),'Transformation_Sensitivity/Factorial_Comparison.csv'),check.names=FALSE)
    reference<-reference[reference$Component==co & reference$Outcome==dv & reference$Scale==if(dv=='RR')'log' else 'raw',]
    stopifnot(max(abs(check[['F value']]-reference[['F value']]))<1e-6)
    a<-data %>% group_by(Method,Meter,Visual,Music) %>%
      summarise(Mean=mean(.data[[dv]]),SEM=sd(.data[[dv]])/sqrt(n()),.groups='drop') %>%
      mutate(Method=factor(Method,levels=c('Legacy JRQA','Latest phase-space RQA')),
        Meter=factor(Meter,levels=names(labels),labels=labels),Music=factor(Music,levels=c('Diff','Same')))
    p<-ggplot(a,aes(Music,Mean,color=Visual,group=Visual))+
      geom_line(linewidth=.85)+geom_point(size=2.4)+geom_errorbar(aes(ymin=Mean-SEM,ymax=Mean+SEM),width=.12)+
      facet_grid(Method~Meter)+scale_color_manual(values=c(No='#AA0000',Yes='#003399'))+
      labs(title=paste('Component',co,'—',dv),subtitle=paste('Original-scale means ± SEM; 33 dyads; shared axes. Models: legacy log;',if(dv=='RR') 'phase-space log.' else 'phase-space untransformed.'),x='Music',y=dv)+
      theme_minimal(base_size=15)+theme(legend.position='bottom')
    ggsave(file.path(out,paste0('Legacy_vs_PhaseSpace_C',co,'_',dv,'.png')),p,width=15,height=7,dpi=160,bg='white')
  }
  manifest<-read.csv(file.path(dest,'Analysis_Manifest.csv'))
  stopifnot(all(manifest$TransformationForModels[manifest$DependentVariable=='RR']=='natural log'),all(manifest$TransformationForModels[manifest$DependentVariable=='DET']=='none'))
}
cat('Selected models, regression checks and comparison plots complete.\n')
