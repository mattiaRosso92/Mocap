# Historical Dance analysis: fixed_dyad_report/plot_profiles.R
# Not the default manuscript workflow. See statistics_history/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_Stats.R')))
setwd(repo)

out <- file.path(repo, 'Dance_Data/FREQNESS_Mocap_Stats_Results/JRQA_Validated/ProfileComparison')
stopifnot(!dir.exists(out))
dir.create(out, recursive = TRUE)

library(readxl)
library(dplyr)
library(ggplot2)
input <- file.path(getwd(),'Dance_Data','FREQNESS_Results_Rosso_et_al_inPreparation','06_Statistics_R')
paths <- list(Legacy=input, Adaptive=file.path(input,'JRQA_Validated','FaithfulAdaptiveMax'),
  Fixed=file.path(input,'JRQA_Validated','FixedDyadRadius'))
labels <- c(M1='Beat / 4',M2='Beat / 2',M3='Beat',M4='2 x beat')
for(method in names(paths)) for(comp in 1:2) {
  d <- read_excel(file.path(paths[[method]],paste0('OUT2R_Comp#',comp,'.xlsx')))
  for(dv in c('RR','DET')) {
    a <- d %>% group_by(Meter,Visual,Music) %>%
      summarise(Mean=mean(.data[[dv]]),SEM=sd(.data[[dv]])/sqrt(n()),.groups='drop') %>%
      mutate(Meter=factor(Meter,levels=names(labels),labels=labels),
        Music=factor(Music,levels=c('Diff','Same')),Visual=factor(Visual,levels=c('No','Yes')))
    p <- ggplot(a,aes(Music,Mean,color=Visual,group=Visual))+
      geom_line(linewidth=1.2)+geom_point(size=3.6)+
      geom_errorbar(aes(ymin=Mean-SEM,ymax=Mean+SEM),width=.12,linewidth=.85)+
      facet_wrap(~Meter,ncol=2,scales='free_y')+
      scale_color_manual(values=c(No='#AA0000',Yes='#003399'))+
      labs(x='Music',y=dv,color='Visual information')+
      theme_minimal(base_size=21)+theme(legend.position='bottom',
        strip.text=element_text(face='bold',size=23),
        panel.spacing=grid::unit(1.3,'lines'),plot.margin=margin(12,25,10,25))
    ggsave(file.path(out,paste0(method,'_C',comp,'_',dv,'.png')),
      p,width=14.8,height=8.1,dpi=180,bg='white')
  }
}
