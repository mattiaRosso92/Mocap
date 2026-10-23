# Historical Dance analysis: DyadiDance_PhaseRadius05_Diagnostics.R
# Not the default manuscript workflow. See Historical/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/Historical/DyadiDance_StatisticalModels_Historical.R')))
setwd(repo)

suppressPackageStartupMessages({library(readxl);library(lmerTest)})
input <- 'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/06_Statistics_R/PhaseSpaceRQA_NonStandardized_Radius05'
out <- 'Dance_Data/FREQNESS_Mocap_Stats_Results/PhaseSpaceRQA_NonStandardized_Radius05/Transformation_Sensitivity'
if (dir.exists(out) && length(list.files(out)) > 0) stop('Output exists: ', out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
diagnostics<-list();factorial<-list();posthoc<-list()
for(dv in c('RR','DET')) {
  png(file.path(out,paste0(dv,'_Residual_QQ.png')),width=1800,height=1400,res=150)
  par(mfrow=c(2,2),mar=c(4,4,3,1))
  for(co in 1:2) {
    d<-as.data.frame(read_excel(file.path(input,paste0('OUT2R_Comp#',co,'.xlsx'))))
    stopifnot(nrow(d)==528,all(d[[dv]]>0))
    for(f in c('Dyad','Visual','Music','Meter'))d[[f]]<-factor(d[[f]])
    for(scale in c('raw','log')) {
      d$Y<-if(scale=='raw')d[[dv]] else log(d[[dv]])
      m<-lmer(Y~Visual*Music*Meter+(1|Dyad),data=d)
      e<-residuals(m);z<-(e-mean(e))/sd(e);sh<-shapiro.test(e)
      diagnostics[[length(diagnostics)+1]]<-data.frame(Component=co,Outcome=dv,Scale=scale,W=unname(sh$statistic),P=sh$p.value,Skewness=mean(z^3),ExcessKurtosis=mean(z^4)-3,SpreadFittedSpearman=cor(abs(e),fitted(m),method='spearman'))
      a<-as.data.frame(anova(m,type=3));a$Term<-rownames(a);a$Component<-co;a$Outcome<-dv;a$Scale<-scale
      factorial[[length(factorial)+1]]<-a
      qqnorm(e,main=paste('Component',co,dv,scale));qqline(e,col='#007C83',lwd=2)
      ph<-list()
      for(meter in levels(d$Meter)) {
        mm<-lmer(Y~Visual*Music+(1|Dyad),data=d[d$Meter==meter,])
        a<-as.data.frame(anova(mm,type=3));a$Term<-rownames(a);a$Meter<-meter;ph[[meter]]<-a
      }
      a<-do.call(rbind,ph);a$AdjustedP<-ave(a[['Pr(>F)']],a$Term,FUN=function(p)p.adjust(p,'bonferroni'))
      a$Component<-co;a$Outcome<-dv;a$Scale<-scale;posthoc[[length(posthoc)+1]]<-a
    }
  }
  dev.off()
}
write.csv(do.call(rbind,diagnostics),file.path(out,'Residual_Diagnostics.csv'),row.names=FALSE)
write.csv(do.call(rbind,factorial),file.path(out,'Factorial_Comparison.csv'),row.names=FALSE)
write.csv(do.call(rbind,posthoc),file.path(out,'PostHoc_Comparison.csv'),row.names=FALSE)
print(do.call(rbind,diagnostics),row.names=FALSE)
