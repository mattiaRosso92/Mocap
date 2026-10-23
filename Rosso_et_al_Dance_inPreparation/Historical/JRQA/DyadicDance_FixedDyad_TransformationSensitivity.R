# Historical Dance analysis: fixed_dyad_report/transformation_sensitivity.R
# Not the default manuscript workflow. See Historical/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/Historical/DyadicDance_StatisticalModels_Historical.R')))
setwd(repo)

suppressPackageStartupMessages({library(readxl);library(lme4);library(lmerTest)})
input <- 'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/06_Statistics_R/JRQA_Validated/FixedDyadRadius'
out <- 'Dance_Data/FREQNESS_Mocap_Stats_Results/JRQA_Validated/FixedDyadRadius/Transformation_Sensitivity'
if (dir.exists(out) && length(list.files(out)) > 0) stop('Output exists: ', out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
diagnostics <- list()
for(v in c('RR','DET')) {
  png(file.path(out,paste0(v,'_Residual_QQ.png')),width=2000,height=1400,res=150)
  par(mfrow=c(2,2),mar=c(4,4,3,1),cex=1.2)
  for(c in 1:2) {
    d<-as.data.frame(read_excel(file.path(input,paste0('OUT2R_Comp#',c,'.xlsx'))))
    for(f in c('Dyad','Visual','Music','Meter')) d[[f]]<-factor(d[[f]])
    for(scale in c('raw','log')) {
      d$Y<-if(scale=='raw') d[[v]] else log(d[[v]])
      model<-lmer(Y~Visual*Music*Meter+(1|Dyad),data=d)
      e<-residuals(model); z<-(e-mean(e))/sd(e); sh<-shapiro.test(e)
      diagnostics[[length(diagnostics)+1]]<-data.frame(Component=c,Outcome=v,Scale=scale,
        W=unname(sh$statistic),P=sh$p.value,Skewness=mean(z^3),
        ExcessKurtosis=mean(z^4)-3,SpreadFittedSpearman=cor(abs(e),fitted(model),method='spearman'))
      a<-as.data.frame(anova(model,type=3));a$Term<-rownames(a)
      write.csv(a,file.path(out,paste0('C',c,'_',v,'_',scale,'_Factorial.csv')),row.names=FALSE)
      qqnorm(e,main=paste('Component',c,v,scale));qqline(e,col='#007C83',lwd=2)
    }
  }
  dev.off()
}
write.csv(do.call(rbind,diagnostics),file.path(out,'Residual_Diagnostics.csv'),row.names=FALSE)
