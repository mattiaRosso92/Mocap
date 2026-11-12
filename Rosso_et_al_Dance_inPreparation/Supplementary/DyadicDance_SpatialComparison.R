# Supplementary spatial coordination: raw r versus Fisher z, all 35 dyads.
# Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
suppressPackageStartupMessages({library(readxl);library(dplyr);library(ggplot2)})
args <- commandArgs(trailingOnly=TRUE)
script_file <- sub("^--file=","",grep("^--file=",commandArgs(),value=TRUE))
repo <- dirname(dirname(dirname(normalizePath(script_file))))
stats_root <- file.path(repo,"Dance_Data","FREQNESS_Mocap_Stats_Results")
spatial_root <- file.path(stats_root,"legacy_logarithmic","SpatialCoordination")
input_path <- file.path(repo,"Dance_Data","FREQNESS_Results_Rosso_et_al_inPreparation",
  "legacy_logarithmic","06_Statistics_R","SpatialCoordination")
output_path <- if(length(args)) args[1] else file.path(spatial_root,"Comparison")
if(dir.exists(output_path)) stop("Output folder exists; choose a new folder to preserve results.")
dir.create(output_path,recursive=TRUE)
omnibus <- list();posthoc <- list();diagnostics <- list();qq <- list();profiles <- list()
for(component in 1:2) {
  data <- read_excel(file.path(input_path,paste0("OUT2R_Comp#",component,".xlsx")))
  stopifnot(nrow(data)==560,setequal(data$Dyad,1:35),
    !anyDuplicated(data[c("Dyad","Visual","Music","Meter")] ))
  for(method in c("Raw","Fisher")) {
    folder <- file.path(spatial_root,method)
    folder <- file.path(folder,paste0("Component_",component),"Mirror")
    a <- read.csv(file.path(folder,"All_Meters","Factorial_Type_III_ANOVA.csv"),check.names=FALSE)
    a$Component <- component;a$Method <- method
    omnibus[[length(omnibus)+1]] <- a
    p <- read.csv(file.path(folder,"PostHoc_Type_III_ANOVA_Bonferroni.csv"),check.names=FALSE)
    p$Component <- component;p$Method <- method
    posthoc[[length(posthoc)+1]] <- p
    s <- read.csv(file.path(folder,"All_Meters","Factorial_Residual_Shapiro_Wilk.csv"))
    shape <- read.csv(file.path(folder,"All_Meters","Factorial_Residual_Shape.csv"))
    diagnostics[[length(diagnostics)+1]] <- cbind(Component=component,Method=method,s,shape)
    residuals <- read.csv(file.path(folder,"All_Meters","Factorial_Residuals.csv"))$Residual
    qq[[length(qq)+1]] <- data.frame(Component=paste("Component",component),Method=method,
      Theoretical=qnorm(ppoints(length(residuals))),
      Residual=sort((residuals-mean(residuals))/sd(residuals)))
    data$Outcome <- if(method=="Raw") data$Mirror else data$FisherZ
    profile <- data %>% group_by(Visual,Music,Meter) %>%
      summarise(Mean=mean(Outcome),SEM=sd(Outcome)/sqrt(n()),N=n(),.groups="drop") %>%
      mutate(Lower=Mean-SEM,Upper=Mean+SEM)
    if(method=="Fisher") profile <- profile %>% mutate(across(c(Mean,Lower,Upper),tanh))
    profile$Component <- component;profile$Method <- method
    profiles[[length(profiles)+1]] <- profile
  }
}
a <- bind_rows(omnibus);p <- bind_rows(posthoc);di <- bind_rows(diagnostics)
write.csv(a,file.path(output_path,"Omnibus_Comparison.csv"),row.names=FALSE)
write.csv(p,file.path(output_path,"PostHoc_Comparison.csv"),row.names=FALSE)
write.csv(di,file.path(output_path,"Residual_Comparison.csv"),row.names=FALSE)
f <- bind_rows(profiles) %>% mutate(
  Method=factor(Method,levels=c("Raw","Fisher"),labels=c("Raw r","Fisher z (back-transformed)")),
  Meter=factor(Meter,levels=paste0("M",1:4),labels=c("Beat / 4","Beat / 2","Beat","2 x beat")))
write.csv(f,file.path(output_path,"Condition_Profiles.csv"),row.names=FALSE)
for(component in 1:2) {
  plot <- ggplot(filter(f,Component==component),aes(Music,Mean,color=Visual,group=Visual))+
    geom_line(linewidth=.8)+geom_point(size=2.8)+
    geom_errorbar(aes(ymin=Lower,ymax=Upper),width=.12)+
    facet_grid(Method~Meter)+scale_color_manual(values=c(No="#990000",Yes="#003399"))+
    theme_bw(base_size=12)+theme(legend.position="bottom")+
    labs(title=paste("Spatial coordination | Component",component),
      subtitle="35 dyads | Mean +/- SEM across dyads | Same trial-level correlations in both analyses",
      x="Music",y="Spatial pattern similarity (r)")
  ggsave(file.path(output_path,paste0("Component_",component,"_Raw_vs_Fisher.png")),
    plot,width=12,height=6,dpi=170,bg="white")
}
q <- bind_rows(qq) %>% mutate(Method=factor(Method,levels=c("Raw","Fisher")))
plot <- ggplot(q,aes(Theoretical,Residual))+
  geom_abline(slope=1,intercept=0,color="grey55")+geom_point(size=.7,alpha=.65,color="#164B72")+
  facet_grid(Component~Method)+theme_bw(base_size=12)+
  labs(title="Spatial coordination: conditional residual Q-Q plots",
    subtitle="35 dyads | Visual x Music x Meter + random dyad intercept",
    x="Normal-theory quantile",y="Standardized residual")
ggsave(file.path(output_path,"Residual_QQ.png"),plot,width=9,height=6,dpi=170,bg="white")
writeLines(c("Raw primary: mean trial r; Fisher sensitivity: mean atanh(trial r).",
  "Models are fitted by DyadicDance_Stats.R; this script only compares saved results.",
  "Full factorial: Visual * Music * Meter + (1 | Dyad); Type III Satterthwaite tests.",
  "Post-hoc: Visual * Music + (1 | Dyad), Bonferroni across four meters per term/component.",
  "Raw plots: mean +/- SEM. Fisher plots: z mean +/- SEM, then back-transform each bound.",
  "Significance in one meter alone does not establish a Visual x Meter interaction."),
  file.path(output_path,"Analysis_Notes.txt"))
writeLines(capture.output(sessionInfo()),file.path(output_path,"R_Session.txt"))
print(a[,c("Component","Method","Term","F value","Pr(>F)")],row.names=FALSE)
print(p[,c("Component","Method","Meter","Term","PValueBonferroni")],row.names=FALSE)
print(di,row.names=FALSE)
