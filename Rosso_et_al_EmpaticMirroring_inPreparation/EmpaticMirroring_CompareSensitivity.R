# ============================================================================
# EMPATIC MIRRORING: PRIMARY VS RECOVERY-SENSITIVITY COMPARISON
# ============================================================================
# Compares the immutable retained-sample analysis with the combined cohort.
# The sensitivity input must be a strict superset: primary participant rows
# are verified unchanged, and only newly recovered participants may be added.

arguments <- commandArgs(trailingOnly = TRUE)

has_flag <- function(flag) flag %in% arguments
argument_value <- function(prefix, default = NULL) {
  match <- grep(paste0("^", prefix), arguments, value = TRUE)
  if (length(match) > 1) stop("Option supplied more than once: ", prefix)
  if (length(match) == 0) return(default)
  sub(paste0("^", prefix), "", match)
}

required_packages <- c("readr", "dplyr")
missing_packages <- required_packages[!vapply(
  required_packages, requireNamespace, logical(1), quietly = TRUE
)]
if (length(missing_packages) > 0) {
  stop("Missing required R packages: ", paste(missing_packages, collapse = ", "))
}
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

primary_input <- argument_value("--primary-input=")
sensitivity_input <- argument_value("--sensitivity-input=")
primary_results <- argument_value("--primary-results=")
sensitivity_results <- argument_value("--sensitivity-results=")
output_root <- argument_value("--output=")
if (any(vapply(
  list(primary_input, sensitivity_input, primary_results,
       sensitivity_results, output_root), is.null, logical(1)
))) {
  stop(
    "Required options: --primary-input, --sensitivity-input, ",
    "--primary-results, --sensitivity-results, and --output."
  )
}

primary_input <- normalizePath(primary_input, mustWork = TRUE)
sensitivity_input <- normalizePath(sensitivity_input, mustWork = TRUE)
primary_results <- normalizePath(primary_results, mustWork = TRUE)
sensitivity_results <- normalizePath(sensitivity_results, mustWork = TRUE)
overwrite <- has_flag("--overwrite")
if (
  dir.exists(output_root) &&
  length(list.files(output_root, all.files = TRUE, no.. = TRUE)) > 0
) {
  if (!overwrite) {
    stop("Comparison output already exists: ", output_root, ". Use --overwrite.")
  }
  unlink(output_root, recursive = TRUE, force = TRUE)
}
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

read_analysis <- function(path) {
  read_csv(
    path, col_types = cols(Participant = col_character()),
    show_col_types = FALSE, progress = FALSE
  )
}
primary <- read_analysis(primary_input)
sensitivity <- read_analysis(sensitivity_input)

key <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement",
  "Meter", "Component"
)
if (!all(key %in% names(primary)) || !all(key %in% names(sensitivity))) {
  stop("An analysis input is missing factorial key columns.")
}
if (anyDuplicated(primary[key]) || anyDuplicated(sensitivity[key])) {
  stop("Primary or sensitivity input contains duplicate analysis keys.")
}

primary_participants <- sort(unique(primary$Participant))
sensitivity_participants <- sort(unique(sensitivity$Participant))
added_participants <- setdiff(sensitivity_participants, primary_participants)
removed_participants <- setdiff(primary_participants, sensitivity_participants)
if (length(removed_participants) > 0) {
  stop(
    "Sensitivity cohort removed primary participants: ",
    paste(removed_participants, collapse = ", ")
  )
}

shared <- inner_join(
  primary, sensitivity, by = key, suffix = c("_Primary", "_Sensitivity")
)
if (nrow(shared) != nrow(primary)) {
  stop("Sensitivity input is not a complete superset of primary analysis rows.")
}
numeric_shared <- intersect(
  names(primary)[vapply(primary, is.numeric, logical(1))],
  names(sensitivity)[vapply(sensitivity, is.numeric, logical(1))]
)
numeric_shared <- setdiff(numeric_shared, c("Version", "Movement", "Component"))
maximum_difference <- 0
for (column in numeric_shared) {
  difference <- abs(
    shared[[paste0(column, "_Primary")]] -
      shared[[paste0(column, "_Sensitivity")]]
  )
  maximum_difference <- max(maximum_difference, difference, na.rm = TRUE)
}
if (!is.finite(maximum_difference)) maximum_difference <- NA_real_
primary_rows_unchanged <- isTRUE(maximum_difference <= 1e-10)
if (!primary_rows_unchanged) {
  stop(
    "Primary rows changed while building the sensitivity input; maximum ",
    "absolute difference = ", maximum_difference
  )
}

added_coverage <- sensitivity %>%
  filter(Participant %in% added_participants)
if (nrow(added_coverage) > 0) {
  added_coverage <- added_coverage %>%
    group_by(Participant, Component) %>%
    summarise(
      NRows = n(),
      NConditions = n_distinct(Condition),
      NInstructions = n_distinct(Instruction),
      NComplexities = n_distinct(Complexity),
      NVersions = n_distinct(Version),
      NMovements = n_distinct(Movement),
      MinimumEligiblePairFraction = min(EligiblePairFraction_Phase),
      MedianEligiblePairFraction = median(EligiblePairFraction_Phase),
      .groups = "drop"
    )
}
write_csv(added_coverage, file.path(output_root, "Recovered_Participant_Coverage.csv"))

coverage_factors <- c(
  "Instruction", "Complexity", "Version", "Movement", "Meter", "Component"
)
primary_coverage <- primary %>%
  count(across(all_of(coverage_factors)), name = "NPrimaryParticipants")
sensitivity_coverage <- sensitivity %>%
  count(across(all_of(coverage_factors)), name = "NSensitivityParticipants")
coverage_comparison <- full_join(
  primary_coverage, sensitivity_coverage, by = coverage_factors
) %>%
  mutate(
    NPrimaryParticipants = coalesce(NPrimaryParticipants, 0L),
    NSensitivityParticipants = coalesce(NSensitivityParticipants, 0L),
    AddedParticipants = NSensitivityParticipants - NPrimaryParticipants
  ) %>%
  arrange(Component, Meter, Instruction, Complexity, Version, Movement)
write_csv(
  coverage_comparison,
  file.path(output_root, "Factorial_Cell_Coverage_Comparison.csv")
)

outcomes <- c(
  "Mirror", "RR_Phase", "L_Phase", "DET_Phase", "ENTR_Phase",
  "TT_Phase", "LAM_Phase", "Vmax_Phase", "DIV_Phase"
)
descriptive_factors <- coverage_factors
descriptive <- lapply(outcomes, function(outcome) {
  primary_summary <- primary %>%
    group_by(across(all_of(descriptive_factors))) %>%
    summarise(
      PrimaryMean = mean(.data[[outcome]]),
      PrimarySD = sd(.data[[outcome]]),
      PrimaryN = n(), .groups = "drop"
    )
  sensitivity_summary <- sensitivity %>%
    group_by(across(all_of(descriptive_factors))) %>%
    summarise(
      SensitivityMean = mean(.data[[outcome]]),
      SensitivitySD = sd(.data[[outcome]]),
      SensitivityN = n(), .groups = "drop"
    )
  full_join(primary_summary, sensitivity_summary, by = descriptive_factors) %>%
    mutate(
      Outcome = outcome,
      MeanChange = SensitivityMean - PrimaryMean,
      RelativeMeanChangePercent = if_else(
        PrimaryMean == 0, NA_real_, 100 * MeanChange / abs(PrimaryMean)
      )
    )
}) %>% bind_rows()
write_csv(
  descriptive,
  file.path(output_root, "Descriptive_Outcome_Comparison.csv")
)

anova_file <- "All_Full_Model_ANOVAs_BH.csv"
primary_anova <- read_csv(
  file.path(primary_results, anova_file), show_col_types = FALSE
)
sensitivity_anova <- read_csv(
  file.path(sensitivity_results, anova_file), show_col_types = FALSE
)
anova_key <- c("Component", "Outcome", "Term")
anova_comparison <- inner_join(
  primary_anova, sensitivity_anova, by = anova_key,
  suffix = c("_Primary", "_Sensitivity")
) %>%
  mutate(
    SignificanceChange = case_when(
      SignificantBHAcrossFullModels_Primary &
        !SignificantBHAcrossFullModels_Sensitivity ~ "lost",
      !SignificantBHAcrossFullModels_Primary &
        SignificantBHAcrossFullModels_Sensitivity ~ "gained",
      SignificantBHAcrossFullModels_Primary &
        SignificantBHAcrossFullModels_Sensitivity ~ "retained significant",
      TRUE ~ "retained non-significant"
    ),
    RawPValueChange = PValueRaw_Sensitivity - PValueRaw_Primary,
    AdjustedPValueChange =
      PValueBHAcrossFullModels_Sensitivity -
      PValueBHAcrossFullModels_Primary
  ) %>%
  arrange(Component, Outcome, Term)
if (nrow(anova_comparison) != nrow(primary_anova) ||
    nrow(anova_comparison) != nrow(sensitivity_anova)) {
  stop("Primary and sensitivity ANOVA families do not match.")
}
write_csv(
  anova_comparison,
  file.path(output_root, "Full_Model_ANOVA_Comparison.csv")
)

model_manifest_file <- "Analysis_Manifest.csv"
primary_models <- read_csv(
  file.path(primary_results, model_manifest_file), show_col_types = FALSE
)
sensitivity_models <- read_csv(
  file.path(sensitivity_results, model_manifest_file), show_col_types = FALSE
)
model_comparison <- inner_join(
  primary_models, sensitivity_models, by = c("Component", "Outcome"),
  suffix = c("_Primary", "_Sensitivity")
) %>%
  mutate(
    SingularFitChange = case_when(
      !FullModelSingular_Primary & FullModelSingular_Sensitivity ~ "became singular",
      FullModelSingular_Primary & !FullModelSingular_Sensitivity ~ "resolved",
      FullModelSingular_Primary & FullModelSingular_Sensitivity ~ "remained singular",
      TRUE ~ "remained non-singular"
    )
  ) %>%
  arrange(Component, Outcome)
if (nrow(model_comparison) != nrow(primary_models) ||
    nrow(model_comparison) != nrow(sensitivity_models)) {
  stop("Primary and sensitivity model manifests do not match.")
}
write_csv(
  model_comparison,
  file.path(output_root, "Model_Fit_Comparison.csv")
)

change_counts <- count(anova_comparison, SignificanceChange)
change_value <- function(label) {
  value <- change_counts$n[change_counts$SignificanceChange == label]
  if (length(value) == 0) 0L else value
}
change_summary <- data.frame(
  PrimaryParticipants = length(primary_participants),
  SensitivityParticipants = length(sensitivity_participants),
  AddedParticipants = length(added_participants),
  PrimaryRows = nrow(primary),
  SensitivityRows = nrow(sensitivity),
  AddedRows = nrow(sensitivity) - nrow(primary),
  PrimaryRowsVerifiedUnchanged = primary_rows_unchanged,
  MaximumPrimaryRowAbsoluteDifference = maximum_difference,
  TestsGainingBHSignificance = change_value("gained"),
  TestsLosingBHSignificance = change_value("lost"),
  TestsRemainingSignificant = change_value("retained significant"),
  TestsRemainingNonSignificant = change_value("retained non-significant"),
  PrimarySingularModels = sum(primary_models$FullModelSingular),
  SensitivitySingularModels = sum(sensitivity_models$FullModelSingular),
  ModelsBecomingSingular = sum(
    model_comparison$SingularFitChange == "became singular"
  )
)
write_csv(
  change_summary,
  file.path(output_root, "Sensitivity_Change_Summary.csv")
)

writeLines(
  c(
    paste("Primary input:", primary_input),
    paste("Sensitivity input:", sensitivity_input),
    paste("Added participants:", paste(added_participants, collapse = ", ")),
    paste("Primary rows preserved exactly:", primary_rows_unchanged),
    paste("Maximum shared-row absolute difference:", maximum_difference),
    "Inference comparison: BH-adjusted full factorial Type-III tests",
    "Model-fit comparison: full-model singular-fit status",
    "Descriptive comparison: participant-level raw-scale means by factorial cell",
    paste("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
  ),
  file.path(output_root, "Comparison_Configuration.txt")
)

message("Sensitivity comparison completed. Outputs: ", output_root)
