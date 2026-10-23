# Full publication R entry points, isolated outputs, unchanged saved statistics.
# Run from the repository root; local-data tests skip when exports are absent.
repo <- normalizePath(getwd())
study <- file.path(repo,"Rosso_et_al_Dance_inPreparation")
files <- list.files(study,pattern="[.]R$",recursive=TRUE,full.names=TRUE)
for(file in files) parse(file)
stopifnot(all(startsWith(basename(files),"DyadiDance_")))
root <- file.path(repo,"Dance_Data","FREQNESS_Results_Rosso_et_al_inPreparation",
  "legacy_logarithmic_recovered_dyads")
phase_tag <- "PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0"
required <- c(file.path(root,"06_Statistics_R",phase_tag,"OUT2R_Comp#1.xlsx"),
  file.path(root,"06_Statistics_R","SpatialCoordination","OUT2R_Comp#1.xlsx"))
if(!all(file.exists(required))) {
  message("SKIP full entry-point regression: local 35-dyad exports absent")
} else {
  output <- tempfile("dyadidance-organization-",tmpdir=Sys.getenv("TMPDIR","/tmp"))
  dir.create(output)
  script <- file.path(study,"DyadiDance_Stats.R")
  env <- new.env(parent=globalenv())
  env$commandArgs <- function(...) paste0("--file=",script)
  for(expression in parse(script)) {
    if(is.call(expression) && identical(expression[[1]],as.name("<-")) &&
        identical(expression[[2]],as.name("output_root"))) {
      env$output_root <- output
    } else eval(expression,env)
  }
  reference <- file.path(repo,"Dance_Data","FREQNESS_Mocap_Stats_Results")
  for(method in names(env$analysis_methods)) {
    relative <- env$analysis_methods[[method]]$output_subfolder
    new_root <- file.path(output,relative)
    old_root <- file.path(reference,relative)
    tables <- list.files(new_root,pattern="(Factorial_Type_III_ANOVA|PostHoc_Type_III_ANOVA_Bonferroni)[.]csv$",
      recursive=TRUE)
    stopifnot(length(tables)==if(method=="PhaseSpaceRQACorrected") 8 else 4)
    for(table in tables) {
      stopifnot(file.exists(file.path(old_root,table)))
      actual <- read.csv(file.path(new_root,table),check.names=FALSE)
      expected <- read.csv(file.path(old_root,table),check.names=FALSE)
      stopifnot(isTRUE(all.equal(actual,expected,tolerance=1e-8,check.attributes=FALSE)))
    }
    message("PASS full R entry point and unchanged model tables: ",method)
  }
  for(kind in c("MetricProminence","LandscapeSimilarity")) {
    block <- if(kind=="MetricProminence") "04_MetricProminence" else "05_LandscapeSimilarity"
    input <- file.path(root,block,"Component_1",paste0("OUT2R_",kind,".csv"))
    target <- file.path(output,kind)
    script <- file.path(study,"Supplementary",paste0("DyadiDance_",kind,"_Stats.R"))
    status <- system2(file.path(R.home("bin"),"Rscript"),shQuote(c(script,input,target)))
    stopifnot(status==0)
    table <- if(kind=="MetricProminence") "Tests_Holm_FiveLevels.csv" else "Tests_Holm_TwoOutcomes.csv"
    actual <- read.csv(file.path(target,table),check.names=FALSE)
    expected <- read.csv(file.path(dirname(input),"R_Statistics",table),check.names=FALSE)
    stopifnot(isTRUE(all.equal(actual,expected,tolerance=1e-8,check.attributes=FALSE)))
    message("PASS unchanged supplementary models: ",kind)
  }
  target <- file.path(output,"SpatialComparison")
  script <- file.path(study,"Supplementary","DyadiDance_SpatialComparison.R")
  stopifnot(system2(file.path(R.home("bin"),"Rscript"),shQuote(c(script,target)))==0)
  data <- read.csv(file.path(target,"Omnibus_Comparison.csv"))
  stopifnot(setequal(data$Method,c("Raw","Fisher")),nrow(data)==28)
  message("PASS spatial comparison: final 35-dyad methods only")
  message("Validation outputs retained in: ",output)
}
