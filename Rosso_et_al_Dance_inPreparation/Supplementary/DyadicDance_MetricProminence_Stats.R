# Dance BLOCK 4: five independent Visual x Music models of dyad-mean prominence.
# Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
suppressPackageStartupMessages({library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})

# Run with Rscript; optional arguments: exported CSV, new output directory.
args <- commandArgs(trailingOnly = TRUE)
script_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
repo <- dirname(dirname(dirname(normalizePath(script_file))))
input_file <- if(length(args)>=1) args[1] else file.path(repo,"Dance_Data",
  "FREQNESS_Results_Rosso_et_al_inPreparation","legacy_logarithmic_recovered_dyads",
  "04_MetricProminence","Component_1","OUT2R_MetricProminence.csv")
output_path <- if(length(args)>=2) args[2] else file.path(dirname(input_file),"R_Statistics")
if(dir.exists(output_path)) stop("Output folder exists; choose a new folder to preserve completed results.")
data <- read.csv(input_file)
labels <- c(Global="Global",M1="Beat / 4",M2="Beat / 2",M3="Beat",M4="2 x beat")
stopifnot(all(c("Dyad","Visual","Music","Level","Prominence") %in% names(data)),
  setequal(data$Dyad,1:35),nrow(data)==35*4*5,
  setequal(unique(data$Level),names(labels)),all(is.finite(data$Prominence)),
  all(data$Prominence>0),all(data$Visual %in% c("No","Yes")),
  all(data$Music %in% c("Diff","Same")),
  !anyDuplicated(data[c("Dyad","Visual","Music","Level")]))
data <- data %>% mutate(Dyad=factor(Dyad),Visual=factor(Visual,levels=c("No","Yes")),
  Music=factor(Music,levels=c("Diff","Same")))
stopifnot(all(table(data$Dyad,data$Level)==4))
dir.create(output_path,recursive=TRUE)
tests <- list(); diagnostics <- list()
for(level in names(labels)) {
  this_data <- filter(data,Level==level)
  model <- lmer(log(Prominence) ~ Visual * Music + (1 | Dyad),data=this_data)
  result <- as.data.frame(anova(model,type=3))
  result$Term <- rownames(result);result$Level <- level;rownames(result) <- NULL
  tests[[level]] <- result
  writeLines(capture.output(summary(model)),file.path(output_path,paste0(level,"_Model.txt")))
  shapiro <- shapiro.test(residuals(model))
  diagnostics[[level]] <- data.frame(Level=level,W=unname(shapiro$statistic),
    PValue=shapiro$p.value,Singular=isSingular(model),
    Convergence=paste(model@optinfo$conv$lme4$messages,collapse="; "))
  write.csv(data.frame(Fitted=fitted(model),Residual=residuals(model)),
    file.path(output_path,paste0(level,"_Residuals.csv")),row.names=FALSE)
  summary_data <- this_data %>% group_by(Visual,Music) %>%
    summarise(Mean=mean(Prominence),SEM=sd(Prominence)/sqrt(n()),.groups="drop")
  write.csv(summary_data,file.path(output_path,paste0(level,"_Descriptives.csv")),row.names=FALSE)
  plot <- ggplot(summary_data,aes(Music,Mean,color=Visual,group=Visual))+
    geom_line(linewidth=1)+geom_point(size=3)+
    geom_errorbar(aes(ymin=Mean-SEM,ymax=Mean+SEM),width=.12)+
    scale_color_manual(values=c(No="#990000",Yes="#003399"))+
    labs(title=paste("Metric prominence:",labels[level]),
      subtitle=paste(nlevels(data$Dyad),"dyads | Mean +/- SEM | Individual prominence averaged within dyad"),
      x="Music",y="Prominence / nonmetric baseline")+theme_minimal(base_size=14)
  ggsave(file.path(output_path,paste0(level,"_Conditions.png")),plot,width=8,height=6,dpi=160,bg="white")
}
tests <- bind_rows(tests) %>% group_by(Term) %>%
  mutate(PValueHolm=p.adjust(`Pr(>F)`,method="holm"),Significant=PValueHolm<.05) %>% ungroup()
write.csv(tests,file.path(output_path,"Tests_Holm_FiveLevels.csv"),row.names=FALSE)
write.csv(bind_rows(diagnostics),file.path(output_path,"Residual_Diagnostics.csv"),row.names=FALSE)
writeLines(c("Log prominence ~ Visual * Music + (1 | Dyad).",
  "Holm correction across Global and four meters, separately for each effect; alpha .05.",
  "Ratios averaged across participants within trial, then across retained trials within dyad/condition.",
  "Global uses the toolbox's available metric set; plots show original-scale arithmetic means +/- SEM.",
  paste("Input:",normalizePath(input_file))),file.path(output_path,"Analysis_Notes.txt"))
writeLines(capture.output(sessionInfo()),file.path(output_path,"R_Session.txt"))
print(as.data.frame(tests[,c("Level","Term","F value","Pr(>F)","PValueHolm")]),row.names=FALSE)
