# Historical Dance analysis: landscape_raw_sensitivity.R
# Not the default manuscript workflow. See statistics_history/README.md.
# Run from the repository root (or set FREQNESS_REPO); equations are preserved.
repo <- normalizePath(Sys.getenv('FREQNESS_REPO', unset = getwd()), mustWork = TRUE)
stopifnot(file.exists(file.path(repo, 'Rosso_et_al_Dance_inPreparation/FREQNESS_Mocap_Stats.R')))
setwd(repo)

suppressPackageStartupMessages({library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})
root <- file.path(repo,'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/legacy_logarithmic_recovered_dyads/05_LandscapeSimilarity/Component_1')
out <- file.path(root,'Sensitivity_RawVsFisher')
if (length(setdiff(list.files(out), 'ModelData.csv')) > 0) stop('Output exists: ', out)
d <- read.csv(file.path(out,'ModelData.csv'))
d <- mutate(d,Dyad=factor(Dyad),Visual=factor(Visual,levels=c('No','Yes')),Music=factor(Music,levels=c('Diff','Same')))
set.seed(17102026);B <- 20000;n <- 35
# Resample entire dyads: the same row indices preserve dependence among
# conditions, outcomes and transformations. No trials treated as independent.
indices <- matrix(sample.int(n,n*B,replace=TRUE),nrow=n)
tests <- list();diagnostics <- list();bootstrap <- list();influence <- list();plots <- list()
for(outcome in c('Component','Entropy')) {
 png(file.path(out,paste0(outcome,'_Diagnostics.png')),width=1800,height=1100,res=150)
 par(mfrow=c(2,3))
 for(scale in c('FisherZ','RawR')) {
  x <- filter(d,Outcome==outcome);x$Y <- x[[scale]]
  fit <- lmer(Y~Visual*Music+(1|Dyad),data=x)
  a <- as.data.frame(anova(fit,type=3));a$Term <- rownames(a)
  tests[[paste(outcome,scale)]] <- mutate(a,Outcome=outcome,Scale=scale)
  sh <- shapiro.test(residuals(fit))
  diagnostics[[paste(outcome,scale)]] <- data.frame(Outcome=outcome,Scale=scale,W=unname(sh$statistic),P=sh$p.value,Singular=isSingular(fit))
  qqnorm(residuals(fit),main=paste(outcome,scale,'Q-Q'));qqline(residuals(fit),col='red')
  plot(fitted(fit),residuals(fit),main=paste(scale,'residuals'),xlab='Fitted',ylab='Residual');abline(h=0,col='red')
  hist(residuals(fit),main=paste(scale,'residual histogram'),xlab='Residual')
  for(id in levels(x$Dyad)) {
   f <- lmer(Y~Visual*Music+(1|Dyad),data=filter(x,Dyad!=id))
   a <- as.data.frame(anova(f,type=3));a$Term <- rownames(a)
   influence[[paste(outcome,scale,id)]] <- mutate(a,Outcome=outcome,Scale=scale,OmittedDyad=as.integer(id))
  }
  cells <- with(x,tapply(Y,list(Dyad,Visual,Music),mean))
  contrasts <- cbind(Visual=(cells[,'Yes','Diff']+cells[,'Yes','Same']-cells[,'No','Diff']-cells[,'No','Same'])/2,
    Music=(cells[,'No','Same']+cells[,'Yes','Same']-cells[,'No','Diff']-cells[,'Yes','Diff'])/2,
    Interaction=cells[,'Yes','Same']-cells[,'Yes','Diff']-cells[,'No','Same']+cells[,'No','Diff'])
  for(term in colnames(contrasts)) {
   v <- contrasts[,term];effect <- mean(v);se <- sd(v)/sqrt(n)
   draws <- matrix(v[indices],nrow=n);means <- colMeans(draws)
   ses <- sqrt((colSums(draws^2)-n*means^2)/(n-1)/n)
   stopifnot(all(ses>0))
   # Studentized centred nonparametric bootstrap: approximate two-sided null test.
   null_t <- (means-effect)/ses
   p <- (1+sum(abs(null_t)>=abs(effect/se)))/(B+1)
   ci <- effect-quantile(null_t,c(.975,.025))*se
   bootstrap[[paste(outcome,scale,term)]] <- data.frame(Outcome=outcome,Scale=scale,Term=if(term=='Interaction')'Visual:Music' else term,
      Estimate=effect,Lower=ci[1],Upper=ci[2],P=p)
  }
  z <- x %>% group_by(Visual,Music) %>% summarise(Mean=mean(Y),SEM=sd(Y)/sqrt(n()),.groups='drop')
  z <- mutate(z,Lower=Mean-SEM,Upper=Mean+SEM,Outcome=outcome,Scale=scale)
  if(scale=='FisherZ') z <- mutate(z,Mean=tanh(Mean),Lower=tanh(Lower),Upper=tanh(Upper))
  plots[[paste(outcome,scale)]] <- z
 }
 dev.off()
}
tests <- bind_rows(tests) %>% group_by(Scale,Term) %>% mutate(PHolm=p.adjust(`Pr(>F)`,'holm')) %>% ungroup()
bootstrap <- bind_rows(bootstrap) %>% group_by(Scale,Term) %>% mutate(PHolm=p.adjust(P,'holm')) %>% ungroup()
influence <- bind_rows(influence) %>% group_by(Scale,Term,OmittedDyad) %>% mutate(PHolm=p.adjust(`Pr(>F)`,'holm')) %>% ungroup()
write.csv(tests,file.path(out,'MixedModels.csv'),row.names=FALSE)
write.csv(bootstrap,file.path(out,'DyadBootstrap.csv'),row.names=FALSE)
write.csv(influence,file.path(out,'LeaveOneDyadOut.csv'),row.names=FALSE)
write.csv(bind_rows(diagnostics),file.path(out,'ResidualNormality.csv'),row.names=FALSE)
for(outcome in c('Component','Entropy')) {
 p <- ggplot(filter(bind_rows(plots),Outcome==outcome),aes(Music,Mean,color=Visual,group=Visual))+
  geom_line()+geom_point(size=2.5)+geom_errorbar(aes(ymin=Lower,ymax=Upper),width=.1)+facet_wrap(~Scale)+
  scale_color_manual(values=c(No='#990000',Yes='#003399'))+theme_minimal(base_size=14)+
  labs(title=paste(outcome,'landscape similarity'),subtitle='35 dyads | Mean +/- SEM; Fisher summaries back-transformed',y='Correlation')
 ggsave(file.path(out,paste0(outcome,'_Comparison.png')),p,width=11,height=5,dpi=150,bg='white')
}
writeLines(c('Exploratory sensitivity analysis; original pipeline unchanged.',
 'RawR: arithmetic trial-r averages. FisherZ: arithmetic trial-atanh(r) averages. Same saved trial correlations.',
 'Bootstrap: 20,000 whole-dyad resamples; seed 17102026; studentized centred two-sided tests of mean within-dyad factorial contrasts.',
 'Bootstrap does not assume normal residuals but assumes independent representative dyads and is approximate, not an exact randomization test.',
 'Holm across two outcomes separately for each effect and scale; transformations are alternative analyses, not independent confirmations.',
 'Bootstrap CIs are unadjusted 95% studentized intervals, in the corresponding analysis units.'),file.path(out,'Methods.txt'))
print(tests[,c('Outcome','Scale','Term','PHolm')]);print(bind_rows(diagnostics))
print(bootstrap)
print(influence %>% group_by(Outcome,Scale,Term) %>% summarise(MinP=min(PHolm),MaxP=max(PHolm),.groups='drop'))
