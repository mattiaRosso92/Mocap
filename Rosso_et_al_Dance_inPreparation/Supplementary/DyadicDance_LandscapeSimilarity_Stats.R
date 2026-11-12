# Dance BLOCK 5: beat-relative component and H2 landscape similarity.
# Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
suppressPackageStartupMessages({library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})

# Run with Rscript; optional arguments: exported CSV, new output directory.
args <- commandArgs(trailingOnly=TRUE)
script_file <- sub("^--file=","",grep("^--file=",commandArgs(),value=TRUE))
repo <- dirname(dirname(dirname(normalizePath(script_file))))
input_file <- if(length(args)>=1) args[1] else file.path(repo,"Dance_Data",
  "FREQNESS_Results_Rosso_et_al_inPreparation","legacy_logarithmic",
  "05_LandscapeSimilarity","Component_1","OUT2R_LandscapeSimilarity.csv")
output_path <- if(length(args)>=2) args[2] else file.path(dirname(input_file),"R_Statistics")
if(dir.exists(output_path)) stop("Output folder exists; choose a new folder to preserve completed results.")
data <- read.csv(input_file)
labels <- c(Component="Component landscape",Entropy="H2 entropy landscape")
stopifnot(all(c("Dyad","Visual","Music","Outcome","FisherZ") %in% names(data)),
  setequal(data$Dyad,1:35),nrow(data)==35*4*2,
  setequal(unique(data$Outcome),names(labels)),all(is.finite(data$FisherZ)),
  all(data$Visual %in% c("No","Yes")),all(data$Music %in% c("Diff","Same")),
  !anyDuplicated(data[c("Dyad","Visual","Music","Outcome")]))
data <- data %>% mutate(Dyad=factor(Dyad),Visual=factor(Visual,levels=c("No","Yes")),
  Music=factor(Music,levels=c("Diff","Same")))
stopifnot(all(table(data$Dyad,data$Outcome)==4))
dir.create(output_path,recursive=TRUE)
tests <- list();diagnostics <- list()
for(outcome in names(labels)) {
  this_data <- filter(data,Outcome==outcome)
  model <- lmer(FisherZ ~ Visual * Music + (1 | Dyad),data=this_data)
  result <- as.data.frame(anova(model,type=3))
  result$Term <- rownames(result);result$Outcome <- outcome;rownames(result) <- NULL
  tests[[outcome]] <- result
  writeLines(capture.output(summary(model)),file.path(output_path,paste0(outcome,"_Model.txt")))
  shapiro <- shapiro.test(residuals(model))
  diagnostics[[outcome]] <- data.frame(Outcome=outcome,W=unname(shapiro$statistic),
    PValue=shapiro$p.value,Singular=isSingular(model),
    Convergence=paste(model@optinfo$conv$lme4$messages,collapse="; "))
  write.csv(data.frame(Fitted=fitted(model),Residual=residuals(model)),
    file.path(output_path,paste0(outcome,"_Residuals.csv")),row.names=FALSE)
  # Average and calculate SEM on z, then back-transform centre and both bounds.
  summary_data <- this_data %>% group_by(Visual,Music) %>%
    summarise(MeanZ=mean(FisherZ),SEMZ=sd(FisherZ)/sqrt(n()),.groups="drop") %>%
    mutate(Correlation=tanh(MeanZ),Lower=tanh(MeanZ-SEMZ),Upper=tanh(MeanZ+SEMZ))
  write.csv(summary_data,file.path(output_path,paste0(outcome,"_Descriptives.csv")),row.names=FALSE)
  plot <- ggplot(summary_data,aes(Music,Correlation,color=Visual,group=Visual))+
    geom_line(linewidth=1)+geom_point(size=3)+
    geom_errorbar(aes(ymin=Lower,ymax=Upper),width=.12)+
    scale_color_manual(values=c(No="#990000",Yes="#003399"))+
    labs(title=paste("Similarity:",labels[outcome]),
      subtitle=paste(nlevels(data$Dyad),"dyads | Fisher-z mean +/- SEM, back-transformed"),
      x="Music",y="Pearson correlation (beat-relative landscapes)")+theme_minimal(base_size=14)
  ggsave(file.path(output_path,paste0(outcome,"_Conditions.png")),plot,width=8,height=6,dpi=160,bg="white")
}
tests <- bind_rows(tests) %>% group_by(Term) %>%
  mutate(PValueHolm=p.adjust(`Pr(>F)`,method="holm"),Significant=PValueHolm<.05) %>% ungroup()
write.csv(tests,file.path(output_path,"Tests_Holm_TwoOutcomes.csv"),row.names=FALSE)
write.csv(bind_rows(diagnostics),file.path(output_path,"Residual_Diagnostics.csv"),row.names=FALSE)
writeLines(c("FisherZ ~ Visual * Music + (1 | Dyad); Type III tests.",
  "Holm correction across two outcomes, separately for each effect; alpha .05.",
  "Trial correlations Fisher-transformed, then averaged within dyad/condition.",
  "Shared beat-relative grid: 1/8 to 4x beat; no interpolation. Entropy is H2, not ED.",
  "Plots back-transform the across-dyad z mean and mean +/- SEM bounds.",
  paste("Input:",normalizePath(input_file))),file.path(output_path,"Analysis_Notes.txt"))
writeLines(capture.output(sessionInfo()),file.path(output_path,"R_Session.txt"))
print(as.data.frame(tests[,c("Outcome","Term","F value","Pr(>F)","PValueHolm")]),row.names=FALSE)
