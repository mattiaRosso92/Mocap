# Historical Dance analysis: phase_raw_stats.R
# Not the default manuscript workflow. See statistics_history/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_Stats.R')))
setwd(repo)

# Reuse the production analysis functions without executing other analyses.
library(readxl)
library(dplyr)
library(ggplot2)
library(lme4)
library(lmerTest)
bonferroni_tests <- 4
bonferroni_alpha <- .05 / 4
configured_metric_levels <- c(M1=.25,M2=.5,M3=1,M4=2)
expressions <- parse(file.path(repo,'Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_Stats.R'))
for (expression in expressions) {
  if (is.call(expression) && identical(expression[[1]], as.name('<-')) &&
      is.call(expression[[3]]) && identical(expression[[3]][[1]], as.name('function'))) {
    eval(expression)
  }
}
for (component in 1:2) {
  input <- file.path(repo,'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/06_Statistics_R/PhaseSpaceRQA_NonStandardized',paste0('OUT2R_Comp#',component,'.xlsx'))
  output <- file.path(repo,'Dance_Data/FREQNESS_Mocap_Stats_Results/PhaseSpaceRQA_NonStandardized',paste0('Component_',component))
  if (dir.exists(output) && length(list.files(output)) > 0) stop('Output exists: ', output)
  dir.create(output,recursive=TRUE,showWarnings=FALSE)
  analyse_component(input,component,output,'PhaseSpaceRQA_NonStandardized')
}

# Comparison figures and a compact machine-readable results summary.
input_root <- file.path(repo,'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/06_Statistics_R')
output_root <- file.path(repo,'Dance_Data/FREQNESS_Mocap_Stats_Results/PhaseSpaceRQA_NonStandardized')
labels <- c(M1='Beat / 4',M2='Beat / 2',M3='Beat',M4='2 x beat')
all_means <- list()
for (component in 1:2) {
  normalized <- read_excel(file.path(input_root,'PhaseSpaceRQA',paste0('OUT2R_Comp#',component,'.xlsx')))
  raw <- read_excel(file.path(input_root,'PhaseSpaceRQA_NonStandardized',paste0('OUT2R_Comp#',component,'.xlsx')))
  stopifnot(nrow(raw)==528,all(is.finite(raw$RR)),all(is.finite(raw$DET)))
  stopifnot(identical(as.data.frame(raw[c('Dyad','Visual','Music','Meter')]),as.data.frame(normalized[c('Dyad','Visual','Music','Meter')])))
  data <- bind_rows(mutate(normalized,Scaling='Z-normalized'),mutate(raw,Scaling='Original signal scale'))
  for (dv in c('RR','DET')) {
    avg <- data %>% group_by(Scaling,Meter,Visual,Music) %>%
      summarise(Mean=mean(.data[[dv]]),SEM=sd(.data[[dv]])/sqrt(n()),.groups='drop') %>%
      mutate(Meter=factor(Meter,levels=names(labels),labels=labels),Music=factor(Music,levels=c('Diff','Same')),
        Scaling=factor(Scaling,levels=c('Z-normalized','Original signal scale')))
    plot <- ggplot(avg,aes(Music,Mean,color=Visual,group=Visual))+
      geom_line(linewidth=.8)+geom_point(size=2)+geom_errorbar(aes(ymin=Mean-SEM,ymax=Mean+SEM),width=.12)+
      facet_grid(Scaling~Meter)+scale_color_manual(values=c(No='#AA0000',Yes='#003399'))+
      labs(title=paste('Phase-space RQA:',dv,'— Component',component),subtitle='Original outcome scale; mean ± SEM across 33 dyads',y=dv,x='Music')+
      theme_minimal(base_size=14)+theme(legend.position='bottom')
    ggsave(file.path(output_root,paste0('Normalization_Comparison_C',component,'_',dv,'.png')),plot,width=14,height=7,dpi=160,bg='white')
    all_means[[paste(component,dv)]] <- data %>% group_by(Scaling,Meter) %>%
      summarise(Mean=mean(.data[[dv]]),.groups='drop') %>% mutate(Component=component,Outcome=dv)
  }
}
write.csv(bind_rows(all_means),file.path(output_root,'Normalization_Comparison_Means.csv'),row.names=FALSE)
message('RAW PHASE STATISTICS AND COMPARISON COMPLETE')
