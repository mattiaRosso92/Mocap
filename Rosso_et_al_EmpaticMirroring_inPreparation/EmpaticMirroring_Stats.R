# ============================================================================
# FREQ-NESS MOCAP: EMPATIC MIRRORING STATISTICAL ANALYSES
# ============================================================================
#
# Mirrors the Dyadic Dance statistical workflow while respecting this study's
# repeated-measures design. Each component is analysed separately with
# participant-level mixed models spanning instruction, complexity, stimulus
# version, movement, and metric level. Teacher-only network summaries remain
# diagnostic: the same teacher recording was reused, so its condition-labelled
# copies are not independent observations and are not tested inferentially.
#
# Usage:
#   Rscript EmpaticMirroring_Stats.R
#   Rscript EmpaticMirroring_Stats.R --smoke-test --no-plots --output=/tmp/test
#   Rscript EmpaticMirroring_Stats.R --overwrite
#
# AUTHORS:
# Mattia Rosso, Felix Bigand, Leonardo Bonetti
# ============================================================================


# Command-line options --------------------------------------------------------

arguments <- commandArgs(trailingOnly = TRUE)

has_flag <- function(flag) {
  flag %in% arguments
}

argument_value <- function(prefix, default = NULL) {
  match <- grep(paste0("^", prefix), arguments, value = TRUE)
  if (length(match) > 1) {
    stop("Option supplied more than once: ", prefix)
  }
  if (length(match) == 0) {
    return(default)
  }
  sub(paste0("^", prefix), "", match)
}

smoke_test <- has_flag("--smoke-test")
make_plots <- !has_flag("--no-plots")
overwrite <- has_flag("--overwrite")


# Required libraries ----------------------------------------------------------

required_packages <- c("readr", "dplyr", "ggplot2", "lme4", "lmerTest", "emmeans")
missing_packages <- required_packages[!vapply(
  required_packages, requireNamespace, logical(1), quietly = TRUE
)]
if (length(missing_packages) > 0) {
  stop(
    "Missing required R packages: ",
    paste(missing_packages, collapse = ", "),
    ". Install them before running the statistical workflow."
  )
}

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(lme4)
  library(lmerTest)
  library(emmeans)
})

# Type-III tests require contrasts whose columns sum to zero.
options(contrasts = c("contr.sum", "contr.poly"))
# Use explicit asymptotic inference for emmeans on this large dataset. The
# mixed-model Type-III ANOVAs retain lmerTest's Satterthwaite degrees of freedom.
emm_options(lmer.df = "asymptotic")


# Paths and analysis contract -------------------------------------------------

command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)
if (length(file_argument) == 1) {
  script_file <- normalizePath(sub("^--file=", "", file_argument))
} else {
  candidates <- c(
    file.path(getwd(), "EmpaticMirroring_Stats.R"),
    file.path(
      getwd(), "Rosso_et_al_EmpaticMirroring_inPreparation",
      "EmpaticMirroring_Stats.R"
    )
  )
  script_file <- candidates[file.exists(candidates)][1]
  if (is.na(script_file)) {
    stop("Could not locate EmpaticMirroring_Stats.R.")
  }
  script_file <- normalizePath(script_file)
}

study_root <- dirname(script_file)
default_input <- file.path(
  study_root, "outputs", "05_Statistics_R", "OUT2R_AllComponents.csv"
)
default_similarity_input <- file.path(
  study_root, "outputs", "05_Statistics_R", "OUT2R_LandscapeSimilarity.csv"
)
default_prominence_input <- file.path(
  study_root, "outputs", "05_Statistics_R", "OUT2R_NetworkProminence.csv"
)
default_global_prominence_input <- file.path(
  study_root, "outputs", "05_Statistics_R",
  "OUT2R_GlobalMetricProminence.csv"
)
default_output <- file.path(study_root, "outputs", "06_Statistics_Results")
input_file <- argument_value("--input=", default_input)
similarity_input_file <- argument_value(
  "--similarity-input=", default_similarity_input
)
prominence_input_file <- argument_value(
  "--prominence-input=", default_prominence_input
)
global_prominence_input_file <- argument_value(
  "--global-prominence-input=", default_global_prominence_input
)
output_root <- argument_value("--output=", default_output)

input_file <- normalizePath(input_file, mustWork = TRUE)
similarity_input_file <- normalizePath(
  similarity_input_file, mustWork = TRUE
)
prominence_input_file <- normalizePath(
  prominence_input_file, mustWork = TRUE
)
global_prominence_input_file <- normalizePath(
  global_prominence_input_file, mustWork = TRUE
)
if (
  dir.exists(output_root) &&
  length(list.files(output_root, all.files = TRUE, no.. = TRUE)) > 0
) {
  if (!overwrite) {
    stop(
      "Statistics output already exists: ", output_root,
      ". Use --overwrite or choose --output=<folder>."
    )
  }
  unlink(output_root, recursive = TRUE, force = TRUE)
}
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

expected_levels <- list(
  Instruction = c("obs", "mir"),
  Complexity = c("low", "medium", "high"),
  Version = c("1", "2"),
  Movement = c("1", "2"),
  Meter = c("M1", "M2", "M3", "M4")
)
configured_metric_levels <- c(M1 = 0.25, M2 = 0.5, M3 = 1, M4 = 2)
outcomes <- c(
  "Mirror", "RR_Phase", "L_Phase", "DET_Phase", "ENTR_Phase",
  "TT_Phase", "LAM_Phase", "Vmax_Phase", "DIV_Phase"
)
coverage_columns <- c(
  "ValidSamples_Phase", "ExcludedSamples_Phase", "EligiblePairs_Phase",
  "EligiblePairFraction_Phase"
)
factor_columns <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement",
  "Meter", "Component"
)
required_columns <- c(
  factor_columns, "Condition", "MeterLevel", "NRepetitions", outcomes,
  coverage_columns
)


# Input validation and QC -----------------------------------------------------

data <- read_csv(
  input_file,
  col_types = cols(Participant = col_character()),
  show_col_types = FALSE,
  progress = FALSE
)
similarity_data <- read_csv(
  similarity_input_file,
  col_types = cols(Participant = col_character()),
  show_col_types = FALSE,
  progress = FALSE
)
prominence_data <- read_csv(
  prominence_input_file,
  col_types = cols(Participant = col_character()),
  show_col_types = FALSE,
  progress = FALSE
)
global_prominence_data <- read_csv(
  global_prominence_input_file,
  col_types = cols(Participant = col_character()),
  show_col_types = FALSE,
  progress = FALSE
)

missing_columns <- setdiff(required_columns, names(data))
if (length(missing_columns) > 0) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}
if (nrow(data) == 0) {
  stop("The statistical export contains no rows.")
}

similarity_outcomes <- c(
  "LandscapeSimilarityComponent", "LandscapeSimilarityEntropy"
)
similarity_required <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement",
  "Condition", "Component", "NRepetitions", similarity_outcomes
)
similarity_missing <- setdiff(similarity_required, names(similarity_data))
if (length(similarity_missing) > 0 || nrow(similarity_data) == 0) {
  stop(
    "Landscape-similarity export is empty or missing columns: ",
    paste(similarity_missing, collapse = ", ")
  )
}

for (column in names(expected_levels)) {
  actual <- sort(unique(as.character(data[[column]])))
  expected <- sort(expected_levels[[column]])
  if (!identical(actual, expected)) {
    stop(
      column, " levels differ from the analysis contract. Expected: ",
      paste(expected, collapse = ", "), "; found: ",
      paste(actual, collapse = ", ")
    )
  }
}

numeric_columns <- c(
  "Condition", "MeterLevel", "Component", "NRepetitions", outcomes,
  coverage_columns
)
non_numeric <- numeric_columns[!vapply(data[numeric_columns], is.numeric, logical(1))]
if (length(non_numeric) > 0) {
  stop("Expected numeric columns: ", paste(non_numeric, collapse = ", "))
}
if (any(!is.finite(as.matrix(data[numeric_columns])))) {
  stop("Numeric analysis columns contain missing or non-finite values.")
}
if (any(data$NRepetitions < 1 | data$NRepetitions != round(data$NRepetitions))) {
  stop("NRepetitions must contain positive integers.")
}
if (any(data$EligiblePairFraction_Phase < 0 | data$EligiblePairFraction_Phase > 1)) {
  stop("EligiblePairFraction_Phase must lie in [0, 1].")
}
if (any(data$Mirror <= -1 | data$Mirror >= 1)) {
  stop("Mirror must lie strictly inside (-1, 1) for Fisher transformation.")
}
if (any(data$RR_Phase <= 0 | data$DET_Phase <= 0)) {
  stop("RR_Phase and DET_Phase must be positive for log transformation.")
}

meter_map <- distinct(data, Meter, MeterLevel) %>% arrange(Meter)
if (
  nrow(meter_map) != length(configured_metric_levels) ||
  !identical(as.character(meter_map$Meter), names(configured_metric_levels)) ||
  !isTRUE(all.equal(meter_map$MeterLevel, unname(configured_metric_levels)))
) {
  stop("Meter labels do not map uniquely to beat/4, beat/2, beat, and 2x beat.")
}

key_columns <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement",
  "Meter", "Component"
)
duplicate_keys <- data %>% count(across(all_of(key_columns))) %>% filter(n != 1)
if (nrow(duplicate_keys) > 0) {
  stop("The export contains duplicate participant-factor-meter-component rows.")
}

data <- data %>%
  mutate(
    Participant = factor(Participant),
    Instruction = factor(Instruction, levels = expected_levels$Instruction),
    Complexity = factor(Complexity, levels = expected_levels$Complexity),
    Version = factor(as.character(Version), levels = expected_levels$Version),
    Movement = factor(as.character(Movement), levels = expected_levels$Movement),
    Meter = factor(Meter, levels = expected_levels$Meter),
    Component = factor(Component, levels = sort(unique(Component)))
  )

similarity_numeric <- c(
  "Condition", "Component", "NRepetitions", similarity_outcomes
)
if (any(!vapply(
  similarity_data[similarity_numeric], is.numeric, logical(1)
))) {
  stop("Landscape-similarity analysis columns must be numeric.")
}
if (any(!is.finite(as.matrix(similarity_data[similarity_numeric])))) {
  stop("Landscape-similarity analysis columns contain non-finite values.")
}
if (any(abs(as.matrix(similarity_data[similarity_outcomes])) >= 1)) {
  stop("Landscape similarities must lie strictly inside (-1, 1).")
}
similarity_expected_levels <- expected_levels[setdiff(
  names(expected_levels), "Meter"
)]
for (column in names(similarity_expected_levels)) {
  actual <- sort(unique(as.character(similarity_data[[column]])))
  expected <- sort(similarity_expected_levels[[column]])
  if (!identical(actual, expected)) {
    stop(column, " levels differ in the landscape-similarity export.")
  }
}
similarity_key <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement",
  "Component"
)
if (anyDuplicated(similarity_data[similarity_key])) {
  stop("The landscape-similarity export contains duplicate factorial keys.")
}
similarity_data <- similarity_data %>%
  mutate(
    Participant = factor(Participant),
    Instruction = factor(Instruction, levels = expected_levels$Instruction),
    Complexity = factor(Complexity, levels = expected_levels$Complexity),
    Version = factor(as.character(Version), levels = expected_levels$Version),
    Movement = factor(as.character(Movement), levels = expected_levels$Movement),
    Component = factor(Component, levels = sort(unique(Component)))
  )

prominence_required <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement",
  "Condition", "Meter", "MeterLevel", "Component", "NRepetitions",
  "FrequencyHz", "RawProminencePercent", "NonMetricBaselinePercent",
  "MetricProminenceRatio", "LogMetricProminence"
)
prominence_missing <- setdiff(prominence_required, names(prominence_data))
if (length(prominence_missing) > 0 || nrow(prominence_data) == 0) {
  stop(
    "Network-prominence export is empty or missing columns: ",
    paste(prominence_missing, collapse = ", ")
  )
}
prominence_numeric <- c(
  "Condition", "MeterLevel", "Component", "NRepetitions", "FrequencyHz",
  "RawProminencePercent", "NonMetricBaselinePercent",
  "MetricProminenceRatio", "LogMetricProminence"
)
if (any(!vapply(
  prominence_data[prominence_numeric], is.numeric, logical(1)
))) {
  stop("Network-prominence analysis columns must be numeric.")
}
if (any(!is.finite(as.matrix(prominence_data[prominence_numeric])))) {
  stop("Network-prominence analysis columns contain non-finite values.")
}
if (any(
  prominence_data$RawProminencePercent < 0 |
  prominence_data$RawProminencePercent > 100
)) {
  stop("RawProminencePercent must lie in [0, 100].")
}
if (any(
  prominence_data$NonMetricBaselinePercent <= 0 |
  prominence_data$MetricProminenceRatio <= 0
)) {
  stop("Normalized network-prominence values must be positive.")
}
if (!isTRUE(all.equal(
  prominence_data$LogMetricProminence,
  log(prominence_data$MetricProminenceRatio), tolerance = 1e-12
))) {
  stop("LogMetricProminence must be the natural log of the ratio.")
}
if (!identical(unique(prominence_data$Component), 1)) {
  stop("Network prominence must use participant Network 1.")
}
for (column in names(expected_levels)) {
  actual <- sort(unique(as.character(prominence_data[[column]])))
  expected <- sort(expected_levels[[column]])
  if (!identical(actual, expected)) {
    stop(column, " levels differ in the network-prominence export.")
  }
}
prominence_meter_map <- distinct(prominence_data, Meter, MeterLevel) %>%
  arrange(Meter)
if (
  !identical(as.character(prominence_meter_map$Meter),
             names(configured_metric_levels)) ||
  !isTRUE(all.equal(
    prominence_meter_map$MeterLevel, unname(configured_metric_levels)
  ))
) {
  stop("Network-prominence Meter labels do not match the analysis contract.")
}
if (!isTRUE(all.equal(
  prominence_data$FrequencyHz,
  1.67 * prominence_data$MeterLevel,
  tolerance = 1e-12
))) {
  stop("Network-prominence frequencies do not match the 1.67 Hz beat.")
}
prominence_key <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement", "Meter"
)
if (anyDuplicated(prominence_data[prominence_key])) {
  stop("The network-prominence export contains duplicate factorial keys.")
}
prominence_data <- prominence_data %>%
  mutate(
    Participant = factor(Participant),
    Instruction = factor(Instruction, levels = expected_levels$Instruction),
    Complexity = factor(Complexity, levels = expected_levels$Complexity),
    Version = factor(as.character(Version), levels = expected_levels$Version),
    Movement = factor(as.character(Movement), levels = expected_levels$Movement),
    Meter = factor(Meter, levels = expected_levels$Meter)
  )

global_prominence_required <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement",
  "Condition", "Component", "NRepetitions", "GlobalMetricMeanPercent",
  "NonMetricBaselinePercent", "GlobalMetricProminenceRatio",
  "LogGlobalMetricProminence"
)
global_prominence_missing <- setdiff(
  global_prominence_required, names(global_prominence_data)
)
if (length(global_prominence_missing) > 0 || nrow(global_prominence_data) == 0) {
  stop(
    "Global metric-prominence export is empty or missing columns: ",
    paste(global_prominence_missing, collapse = ", ")
  )
}
global_prominence_numeric <- c(
  "Condition", "Component", "NRepetitions", "GlobalMetricMeanPercent",
  "NonMetricBaselinePercent", "GlobalMetricProminenceRatio",
  "LogGlobalMetricProminence"
)
if (any(!vapply(
  global_prominence_data[global_prominence_numeric], is.numeric, logical(1)
))) {
  stop("Global metric-prominence analysis columns must be numeric.")
}
if (any(!is.finite(as.matrix(
  global_prominence_data[global_prominence_numeric]
)))) {
  stop("Global metric-prominence analysis columns contain non-finite values.")
}
if (any(
  global_prominence_data$GlobalMetricMeanPercent < 0 |
  global_prominence_data$GlobalMetricMeanPercent > 100 |
  global_prominence_data$NonMetricBaselinePercent <= 0 |
  global_prominence_data$GlobalMetricProminenceRatio <= 0
)) {
  stop("Global metric-prominence values violate their valid ranges.")
}
if (!isTRUE(all.equal(
  global_prominence_data$LogGlobalMetricProminence,
  log(global_prominence_data$GlobalMetricProminenceRatio), tolerance = 1e-12
))) {
  stop("LogGlobalMetricProminence must be the natural log of the ratio.")
}
if (!identical(unique(global_prominence_data$Component), 1)) {
  stop("Global metric prominence must use participant Network 1.")
}
for (column in c("Instruction", "Complexity", "Version", "Movement")) {
  actual <- sort(unique(as.character(global_prominence_data[[column]])))
  expected <- sort(expected_levels[[column]])
  if (!identical(actual, expected)) {
    stop(column, " levels differ in the global metric-prominence export.")
  }
}
global_prominence_key <- c(
  "Participant", "Instruction", "Complexity", "Version", "Movement"
)
if (anyDuplicated(global_prominence_data[global_prominence_key])) {
  stop("The global metric-prominence export contains duplicate factorial keys.")
}
global_prominence_data <- global_prominence_data %>%
  mutate(
    Participant = factor(Participant),
    Instruction = factor(Instruction, levels = expected_levels$Instruction),
    Complexity = factor(Complexity, levels = expected_levels$Complexity),
    Version = factor(as.character(Version), levels = expected_levels$Version),
    Movement = factor(as.character(Movement), levels = expected_levels$Movement)
  )

components <- levels(data$Component)
analysis_outcomes <- outcomes
if (smoke_test) {
  components <- components[1]
  analysis_outcomes <- "Mirror"
}

cell_coverage <- data %>%
  count(
    Instruction, Complexity, Version, Movement, Meter, Component,
    name = "NParticipants"
  ) %>%
  arrange(Component, Meter, Instruction, Complexity, Version, Movement)
write_csv(cell_coverage, file.path(output_root, "Factorial_Cell_Coverage.csv"))

participant_coverage <- data %>%
  group_by(Participant, Component) %>%
  summarise(
    NRows = n(),
    NConditions = n_distinct(Condition),
    MinimumEligiblePairFraction = min(EligiblePairFraction_Phase),
    MedianEligiblePairFraction = median(EligiblePairFraction_Phase),
    .groups = "drop"
  )
write_csv(participant_coverage, file.path(output_root, "Participant_Coverage.csv"))

rqa_coverage <- data %>%
  group_by(Component, Meter) %>%
  summarise(
    N = n(),
    MeanValidSamples = mean(ValidSamples_Phase),
    MeanExcludedSamples = mean(ExcludedSamples_Phase),
    MinimumEligiblePairFraction = min(EligiblePairFraction_Phase),
    MedianEligiblePairFraction = median(EligiblePairFraction_Phase),
    MaximumEligiblePairFraction = max(EligiblePairFraction_Phase),
    .groups = "drop"
  )
write_csv(rqa_coverage, file.path(output_root, "PhaseRQA_Coverage_QC.csv"))


# Output and model helpers ----------------------------------------------------

write_text <- function(..., output_file) {
  writeLines(capture.output(...), output_file)
}

anova_to_data_frame <- function(anova_result) {
  output <- as.data.frame(anova_result)
  output$Term <- rownames(output)
  rownames(output) <- NULL
  output[, c("Term", setdiff(names(output), "Term")), drop = FALSE]
}

p_value_column <- function(table) {
  columns <- grep("^Pr\\(", names(table), value = TRUE)
  if (length(columns) != 1) {
    stop("Could not identify exactly one p-value column in an ANOVA table.")
  }
  columns
}

safe_shapiro <- function(residual_values) {
  residual_values <- residual_values[is.finite(residual_values)]
  if (length(residual_values) > 5000) {
    indices <- unique(round(seq(1, length(residual_values), length.out = 5000)))
    residual_values <- residual_values[indices]
  }
  if (length(residual_values) < 3) {
    return(data.frame(W = NA_real_, PValue = NA_real_, N = length(residual_values)))
  }
  test <- shapiro.test(residual_values)
  data.frame(
    W = unname(test$statistic), PValue = test$p.value,
    N = length(residual_values)
  )
}

save_residual_diagnostics <- function(model, title_text, output_file) {
  residual_values <- residuals(model)
  fitted_values <- fitted(model)
  png(output_file, width = 1800, height = 600, res = 150)
  par(mfrow = c(1, 3))
  hist(residual_values, main = paste(title_text, "Residuals"), xlab = "Residuals")
  qqnorm(residual_values, main = paste(title_text, "QQ plot"))
  qqline(residual_values, col = "red")
  plot(
    fitted_values, residual_values,
    xlab = "Fitted values", ylab = "Residuals",
    main = paste(title_text, "Residuals vs fitted")
  )
  abline(h = 0, col = "red")
  par(mfrow = c(1, 1))
  dev.off()
}

model_diagnostics <- function(model, model_data) {
  convergence_messages <- model@optinfo$conv$lme4$messages
  if (is.null(convergence_messages)) {
    convergence_messages <- ""
  }
  data.frame(
    NRows = nrow(model_data),
    NParticipants = n_distinct(model_data$Participant),
    SingularFit = isSingular(model, tol = 1e-4),
    ConvergenceMessage = paste(convergence_messages, collapse = " | "),
    AIC = AIC(model),
    BIC = BIC(model),
    LogLikelihood = as.numeric(logLik(model))
  )
}

fit_model <- function(model_data, include_meter) {
  fixed_factors <- c("Instruction", "Complexity", "Version", "Movement")
  if (include_meter) {
    fixed_factors <- c(fixed_factors, "Meter")
  }
  formula <- as.formula(paste0(
    "ModelOutcome ~ ", paste(fixed_factors, collapse = " * "),
    " + (1 | Participant)"
  ))
  model <- lmer(
    formula,
    data = model_data,
    REML = TRUE,
    control = lmerControl(
      optimizer = "bobyqa", optCtrl = list(maxfun = 200000)
    )
  )
  list(model = model, formula = formula, fixed_factors = fixed_factors)
}

transform_outcome <- function(data, outcome) {
  transformed <- data
  if (outcome %in% c(
    "Mirror", "LandscapeSimilarityComponent", "LandscapeSimilarityEntropy"
  )) {
    transformed$ModelOutcome <- atanh(transformed[[outcome]])
    transformation <- "Fisher z (atanh)"
  } else if (outcome %in% c("RR_Phase", "DET_Phase")) {
    transformed$ModelOutcome <- log(transformed[[outcome]])
    transformation <- "natural log"
  } else {
    transformed$ModelOutcome <- transformed[[outcome]]
    transformation <- "none"
  }
  list(data = transformed, transformation = transformation)
}

save_similarity_plot <- function(raw_data, outcome, component, output_file) {
  summary_stats <- raw_data %>%
    group_by(Instruction, Complexity, Version, Movement) %>%
    summarise(
      Mean = mean(.data[[outcome]]),
      SEM = sd(.data[[outcome]]) / sqrt(n()),
      N = n(),
      .groups = "drop"
    )
  plot <- ggplot(
    summary_stats,
    aes(
      x = Complexity, y = Mean, color = Instruction,
      group = Instruction
    )
  ) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2.4) +
    geom_errorbar(aes(ymin = Mean - SEM, ymax = Mean + SEM), width = 0.12) +
    facet_grid(Movement ~ Version, labeller = label_both) +
    labs(
      title = paste("Mean +/- SEM:", outcome),
      subtitle = component,
      x = "Complexity", y = "Pearson correlation",
      color = "Instruction"
    ) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold", hjust = 0.5))
  ggsave(output_file, plot, width = 10, height = 7, dpi = 240, bg = "white")
}

write_simple_effect_contrasts <- function(model, factors, output_file) {
  contrast_tables <- lapply(factors, function(factor_name) {
    by_factors <- setdiff(factors, factor_name)
    marginal_means <- emmeans(
      model, specs = factor_name, by = by_factors
    )
    output <- as.data.frame(
      summary(pairs(marginal_means, adjust = "holm"), infer = TRUE)
    )
    output$Factor <- factor_name
    output
  })
  contrasts <- bind_rows(contrast_tables)
  write_csv(contrasts, output_file)
}

save_descriptive_plot <- function(raw_data, outcome, component, output_file) {
  summary_stats <- raw_data %>%
    group_by(Instruction, Complexity, Version, Movement, Meter) %>%
    summarise(
      Mean = mean(.data[[outcome]]),
      SEM = sd(.data[[outcome]]) / sqrt(n()),
      N = n(),
      .groups = "drop"
    )
  plot <- ggplot(
    summary_stats,
    aes(
      x = Complexity, y = Mean, color = Instruction,
      linetype = Version, group = interaction(Instruction, Version)
    )
  ) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2.4) +
    geom_errorbar(aes(ymin = Mean - SEM, ymax = Mean + SEM), width = 0.12) +
    facet_grid(Movement ~ Meter, labeller = label_both) +
    labs(
      title = paste("Mean +/- SEM:", outcome),
      subtitle = paste("Component", component, "| raw scale"),
      x = "Complexity", y = outcome,
      color = "Instruction", linetype = "Version"
    ) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold", hjust = 0.5))
  ggsave(
    output_file, plot, width = 13, height = 7.5, dpi = 240,
    bg = "white"
  )
}


# Component and outcome analyses ---------------------------------------------

full_anova_tables <- list()
analysis_manifest <- data.frame()

for (component in components) {
  message("Analysing Component ", component)
  component_data <- data %>% filter(Component == component)
  component_output <- file.path(output_root, paste0("Component_", component))
  dir.create(component_output, recursive = TRUE, showWarnings = FALSE)

  for (outcome in analysis_outcomes) {
    message("  Outcome: ", outcome)
    outcome_output <- file.path(component_output, outcome)
    full_output <- file.path(outcome_output, "All_Meters")
    dir.create(full_output, recursive = TRUE, showWarnings = FALSE)

    transformed <- transform_outcome(component_data, outcome)
    model_data <- transformed$data
    full_fit <- fit_model(model_data, include_meter = TRUE)
    full_model <- full_fit$model
    full_anova <- anova_to_data_frame(anova(full_model, type = 3))
    p_column <- p_value_column(full_anova)
    full_anova$PValueRaw <- full_anova[[p_column]]
    full_anova$Component <- component
    full_anova$Outcome <- outcome
    full_anova$Transformation <- transformed$transformation
    full_anova_tables[[paste(component, outcome, sep = "_")]] <- full_anova

    write_text(
      summary(full_model),
      output_file = file.path(full_output, "Factorial_Model_Summary.txt")
    )
    writeLines(
      deparse(full_fit$formula),
      file.path(full_output, "Factorial_Model_Formula.txt")
    )
    write_csv(full_anova, file.path(full_output, "Factorial_Type_III_ANOVA.csv"))
    write_csv(
      model_diagnostics(full_model, model_data),
      file.path(full_output, "Model_Fit_Diagnostics.csv")
    )
    write_csv(
      safe_shapiro(residuals(full_model)),
      file.path(full_output, "Residual_Shapiro_Wilk.csv")
    )
    write_simple_effect_contrasts(
      full_model, full_fit$fixed_factors,
      file.path(full_output, "Simple_Effect_Contrasts_Holm.csv")
    )
    if (make_plots) {
      save_residual_diagnostics(
        full_model, paste("Component", component, outcome),
        file.path(full_output, "Residual_Diagnostics.png")
      )
      save_descriptive_plot(
        component_data, outcome, component,
        file.path(outcome_output, "Factorial_Descriptive_Raw_Scale.png")
      )
    }

    meter_anova_tables <- list()
    for (meter in levels(data$Meter)) {
      meter_name <- paste0(
        "Meter_", configured_metric_levels[[meter]], "x"
      )
      meter_output <- file.path(outcome_output, meter_name)
      dir.create(meter_output, recursive = TRUE, showWarnings = FALSE)
      meter_data <- model_data %>% filter(Meter == meter)
      meter_fit <- fit_model(meter_data, include_meter = FALSE)
      meter_model <- meter_fit$model
      meter_anova <- anova_to_data_frame(anova(meter_model, type = 3))
      meter_p_column <- p_value_column(meter_anova)
      meter_anova$PValueRaw <- meter_anova[[meter_p_column]]
      meter_anova$Meter <- meter
      meter_anova$MeterLevel <- configured_metric_levels[[meter]]
      meter_anova_tables[[meter]] <- meter_anova

      write_text(
        summary(meter_model),
        output_file = file.path(meter_output, "Mixed_Model_Summary.txt")
      )
      write_csv(
        meter_anova,
        file.path(meter_output, "Type_III_ANOVA_Uncorrected.csv")
      )
      write_csv(
        model_diagnostics(meter_model, meter_data),
        file.path(meter_output, "Model_Fit_Diagnostics.csv")
      )
      write_csv(
        safe_shapiro(residuals(meter_model)),
        file.path(meter_output, "Residual_Shapiro_Wilk.csv")
      )
      write_simple_effect_contrasts(
        meter_model, meter_fit$fixed_factors,
        file.path(meter_output, "Simple_Effect_Contrasts_Holm.csv")
      )
      if (make_plots) {
        save_residual_diagnostics(
          meter_model, paste("Component", component, outcome, meter_name),
          file.path(meter_output, "Residual_Diagnostics.png")
        )
      }
    }

    meter_anova <- bind_rows(meter_anova_tables)
    meter_anova$PValueBonferroniAcrossMeters <- ave(
      meter_anova$PValueRaw,
      meter_anova$Term,
      FUN = function(values) p.adjust(values, method = "bonferroni")
    )
    meter_anova$SignificantBonferroniAcrossMeters <-
      meter_anova$PValueBonferroniAcrossMeters < 0.05
    write_csv(
      meter_anova,
      file.path(outcome_output, "MeterSpecific_Type_III_ANOVA_Bonferroni.csv")
    )

    analysis_manifest <- bind_rows(
      analysis_manifest,
      data.frame(
        Component = component,
        Outcome = outcome,
        TransformationForModels = transformed$transformation,
        PlotScale = "raw",
        NRows = nrow(model_data),
        NParticipants = n_distinct(model_data$Participant),
        FullModelSingular = isSingular(full_model, tol = 1e-4),
        OutputFolder = outcome_output
      )
    )
  }
}


# Network-landscape similarity analyses --------------------------------------

similarity_anova_tables <- list()
similarity_manifest <- data.frame()
similarity_output_root <- file.path(output_root, "LandscapeSimilarity")
dir.create(similarity_output_root, recursive = TRUE, showWarnings = FALSE)

similarity_jobs <- list()
for (component in components) {
  similarity_jobs[[paste0("Component_", component)]] <- list(
    data = similarity_data %>% filter(Component == component),
    outcome = "LandscapeSimilarityComponent",
    component = component,
    label = paste("Component", component)
  )
}
similarity_jobs[["Entropy"]] <- list(
  data = similarity_data %>%
    filter(Component == levels(similarity_data$Component)[1]),
  outcome = "LandscapeSimilarityEntropy",
  component = NA,
  label = "H2 entropy landscape"
)
if (smoke_test) {
  similarity_jobs <- similarity_jobs[1]
}

for (job_name in names(similarity_jobs)) {
  job <- similarity_jobs[[job_name]]
  outcome_output <- file.path(similarity_output_root, job_name)
  dir.create(outcome_output, recursive = TRUE, showWarnings = FALSE)
  transformed <- transform_outcome(job$data, job$outcome)
  fit <- fit_model(transformed$data, include_meter = FALSE)
  model <- fit$model
  anova_table <- anova_to_data_frame(anova(model, type = 3))
  p_column <- p_value_column(anova_table)
  anova_table$PValueRaw <- anova_table[[p_column]]
  anova_table$Component <- job$component
  anova_table$Outcome <- job$outcome
  anova_table$Transformation <- transformed$transformation
  similarity_anova_tables[[job_name]] <- anova_table

  write_text(
    summary(model),
    output_file = file.path(outcome_output, "Factorial_Model_Summary.txt")
  )
  writeLines(
    deparse(fit$formula),
    file.path(outcome_output, "Factorial_Model_Formula.txt")
  )
  write_csv(
    anova_table,
    file.path(outcome_output, "Factorial_Type_III_ANOVA.csv")
  )
  write_csv(
    model_diagnostics(model, transformed$data),
    file.path(outcome_output, "Model_Fit_Diagnostics.csv")
  )
  write_csv(
    safe_shapiro(residuals(model)),
    file.path(outcome_output, "Residual_Shapiro_Wilk.csv")
  )
  write_simple_effect_contrasts(
    model, fit$fixed_factors,
    file.path(outcome_output, "Simple_Effect_Contrasts_Holm.csv")
  )
  if (make_plots) {
    save_residual_diagnostics(
      model, paste("Landscape similarity", job$label),
      file.path(outcome_output, "Residual_Diagnostics.png")
    )
    save_similarity_plot(
      job$data, job$outcome, job$label,
      file.path(outcome_output, "Factorial_Descriptive_Raw_Scale.png")
    )
  }

  similarity_manifest <- bind_rows(
    similarity_manifest,
    data.frame(
      Component = job$component,
      Outcome = job$outcome,
      TransformationForModels = transformed$transformation,
      PlotScale = "raw",
      NRows = nrow(transformed$data),
      NParticipants = n_distinct(transformed$data$Participant),
      FullModelSingular = isSingular(model, tol = 1e-4),
      OutputFolder = outcome_output
    )
  )
}

similarity_anova_all <- bind_rows(similarity_anova_tables)
similarity_anova_all$PValueBHAcrossSimilarityModels <- p.adjust(
  similarity_anova_all$PValueRaw, method = "BH"
)
similarity_anova_all$SignificantBHAcrossSimilarityModels <-
  similarity_anova_all$PValueBHAcrossSimilarityModels < 0.05
write_csv(
  similarity_anova_all,
  file.path(output_root, "All_LandscapeSimilarity_ANOVAs_BH.csv")
)
write_csv(
  similarity_manifest,
  file.path(output_root, "LandscapeSimilarity_Analysis_Manifest.csv")
)


# Participant metric-prominence analysis -------------------------------------

prominence_output <- file.path(output_root, "NetworkProminence")
prominence_full_output <- file.path(prominence_output, "All_Meters")
dir.create(prominence_full_output, recursive = TRUE, showWarnings = FALSE)
prominence_model_data <- prominence_data %>%
  mutate(ModelOutcome = LogMetricProminence)
prominence_fit <- fit_model(prominence_model_data, include_meter = TRUE)
prominence_model <- prominence_fit$model
prominence_anova <- anova_to_data_frame(anova(prominence_model, type = 3))
prominence_p_column <- p_value_column(prominence_anova)
prominence_anova$PValueRaw <- prominence_anova[[prominence_p_column]]
write_text(
  summary(prominence_model),
  output_file = file.path(prominence_full_output, "Factorial_Model_Summary.txt")
)
writeLines(
  deparse(prominence_fit$formula),
  file.path(prominence_full_output, "Factorial_Model_Formula.txt")
)
write_csv(
  prominence_anova,
  file.path(prominence_full_output, "Factorial_Type_III_ANOVA.csv")
)
write_csv(
  model_diagnostics(prominence_model, prominence_model_data),
  file.path(prominence_full_output, "Model_Fit_Diagnostics.csv")
)
write_csv(
  safe_shapiro(residuals(prominence_model)),
  file.path(prominence_full_output, "Residual_Shapiro_Wilk.csv")
)
write_simple_effect_contrasts(
  prominence_model, prominence_fit$fixed_factors,
  file.path(prominence_full_output, "Simple_Effect_Contrasts_Holm.csv")
)

prominence_emmeans <- emmeans(
  prominence_model, ~ Complexity | Instruction * Movement * Meter
)
prominence_emmeans_table <- as.data.frame(summary(
  prominence_emmeans, infer = c(TRUE, TRUE)
))
prominence_lower_column <- grep(
  "LCL$", names(prominence_emmeans_table), value = TRUE
)[1]
prominence_upper_column <- grep(
  "UCL$", names(prominence_emmeans_table), value = TRUE
)[1]
prominence_emmeans_table$ProminenceRatio <- exp(prominence_emmeans_table$emmean)
prominence_emmeans_table$RatioLowerCL <- exp(
  prominence_emmeans_table[[prominence_lower_column]]
)
prominence_emmeans_table$RatioUpperCL <- exp(
  prominence_emmeans_table[[prominence_upper_column]]
)
prominence_complexity_pairs <- as.data.frame(summary(
  pairs(prominence_emmeans, adjust = "holm"), infer = c(TRUE, TRUE)
))
prominence_complexity_trends <- as.data.frame(summary(
  contrast(prominence_emmeans, method = "poly", adjust = "holm"),
  infer = c(TRUE, TRUE)
))
write_csv(
  prominence_emmeans_table,
  file.path(prominence_output, "Complexity_EstimatedMarginalMeans.csv")
)
write_csv(
  prominence_complexity_pairs,
  file.path(prominence_output, "Complexity_Contrasts_Holm.csv")
)
write_csv(
  prominence_complexity_trends,
  file.path(prominence_output, "Complexity_Trends_Holm.csv")
)

prominence_meter_anova_tables <- list()
for (meter_name in levels(prominence_data$Meter)) {
  meter_level <- configured_metric_levels[[meter_name]]
  meter_output <- file.path(
    prominence_output, paste0("Meter_", meter_level, "x")
  )
  dir.create(meter_output, recursive = TRUE, showWarnings = FALSE)
  meter_data <- prominence_model_data %>% filter(Meter == meter_name)
  meter_fit <- fit_model(meter_data, include_meter = FALSE)
  meter_model <- meter_fit$model
  meter_anova <- anova_to_data_frame(anova(meter_model, type = 3))
  meter_p_column <- p_value_column(meter_anova)
  meter_anova$PValueRaw <- meter_anova[[meter_p_column]]
  meter_anova$Meter <- meter_name
  meter_anova$MeterLevel <- meter_level
  prominence_meter_anova_tables[[meter_name]] <- meter_anova
  write_text(
    summary(meter_model),
    output_file = file.path(meter_output, "Mixed_Model_Summary.txt")
  )
  write_csv(
    meter_anova,
    file.path(meter_output, "Type_III_ANOVA_Uncorrected.csv")
  )
  write_csv(
    model_diagnostics(meter_model, meter_data),
    file.path(meter_output, "Model_Fit_Diagnostics.csv")
  )
  write_csv(
    safe_shapiro(residuals(meter_model)),
    file.path(meter_output, "Residual_Shapiro_Wilk.csv")
  )
  write_simple_effect_contrasts(
    meter_model, meter_fit$fixed_factors,
    file.path(meter_output, "Simple_Effect_Contrasts_Holm.csv")
  )
}
prominence_meter_anova <- bind_rows(prominence_meter_anova_tables)
prominence_meter_anova$PValueBonferroniAcrossMeters <- ave(
  prominence_meter_anova$PValueRaw,
  prominence_meter_anova$Term,
  FUN = function(values) p.adjust(values, method = "bonferroni")
)
prominence_meter_anova$SignificantBonferroniAcrossMeters <-
  prominence_meter_anova$PValueBonferroniAcrossMeters < 0.05
write_csv(
  prominence_meter_anova,
  file.path(prominence_output, "MeterSpecific_Type_III_ANOVA_Bonferroni.csv")
)

if (make_plots) {
  save_residual_diagnostics(
    prominence_model, "Participant Network 1 normalized metric prominence",
    file.path(prominence_full_output, "Residual_Diagnostics.png")
  )
  prominence_plot <- ggplot(
    prominence_emmeans_table %>% mutate(
      MeterLabel = factor(
        Meter, levels = names(configured_metric_levels),
        labels = c("Beat/4", "Beat/2", "Beat", "Beat x 2")
      )
    ),
    aes(
      x = Complexity, y = ProminenceRatio, color = Instruction,
      group = Instruction
    )
  ) +
    geom_hline(yintercept = 1, linetype = "dotted", color = "grey45") +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2.5) +
    geom_errorbar(
      aes(
        ymin = RatioLowerCL,
        ymax = RatioUpperCL
      ),
      width = 0.12
    ) +
    facet_grid(
      Movement ~ MeterLabel,
      labeller = labeller(Movement = label_both, MeterLabel = label_value)
    ) +
    labs(
      title = "Participant Network 1 normalized prominence at metric levels",
      subtitle = paste(
        "Ratio to the mean of nonmetric frequencies;",
        "Version averaged by the model"
      ),
      x = "Stimulus complexity",
      y = "Metric / nonmetric prominence ratio",
      color = "Instruction"
    ) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold", hjust = 0.5))
  ggsave(
    file.path(prominence_output, "NetworkProminence_Complexity_EMMeans.png"),
    prominence_plot, width = 14, height = 7.5, dpi = 240, bg = "white"
  )
}


# Global metric-prominence analysis -----------------------------------------

global_prominence_output <- file.path(prominence_output, "Global")
dir.create(global_prominence_output, recursive = TRUE, showWarnings = FALSE)
global_prominence_model_data <- global_prominence_data %>%
  mutate(ModelOutcome = LogGlobalMetricProminence)
global_prominence_fit <- fit_model(
  global_prominence_model_data, include_meter = FALSE
)
global_prominence_model <- global_prominence_fit$model
global_prominence_anova <- anova_to_data_frame(
  anova(global_prominence_model, type = 3)
)
global_prominence_p_column <- p_value_column(global_prominence_anova)
global_prominence_anova$PValueRaw <-
  global_prominence_anova[[global_prominence_p_column]]
write_text(
  summary(global_prominence_model),
  output_file = file.path(global_prominence_output, "Factorial_Model_Summary.txt")
)
writeLines(
  deparse(global_prominence_fit$formula),
  file.path(global_prominence_output, "Factorial_Model_Formula.txt")
)
write_csv(
  global_prominence_anova,
  file.path(global_prominence_output, "Factorial_Type_III_ANOVA.csv")
)
write_csv(
  model_diagnostics(global_prominence_model, global_prominence_model_data),
  file.path(global_prominence_output, "Model_Fit_Diagnostics.csv")
)
write_csv(
  safe_shapiro(residuals(global_prominence_model)),
  file.path(global_prominence_output, "Residual_Shapiro_Wilk.csv")
)
write_simple_effect_contrasts(
  global_prominence_model, global_prominence_fit$fixed_factors,
  file.path(global_prominence_output, "Simple_Effect_Contrasts_Holm.csv")
)

global_prominence_emmeans <- emmeans(
  global_prominence_model, ~ Complexity | Instruction * Movement
)
global_prominence_emmeans_table <- as.data.frame(summary(
  global_prominence_emmeans, infer = c(TRUE, TRUE)
))
global_lower_column <- grep(
  "LCL$", names(global_prominence_emmeans_table), value = TRUE
)[1]
global_upper_column <- grep(
  "UCL$", names(global_prominence_emmeans_table), value = TRUE
)[1]
global_prominence_emmeans_table$ProminenceRatio <- exp(
  global_prominence_emmeans_table$emmean
)
global_prominence_emmeans_table$RatioLowerCL <- exp(
  global_prominence_emmeans_table[[global_lower_column]]
)
global_prominence_emmeans_table$RatioUpperCL <- exp(
  global_prominence_emmeans_table[[global_upper_column]]
)
global_complexity_pairs <- as.data.frame(summary(
  pairs(global_prominence_emmeans, adjust = "holm"), infer = c(TRUE, TRUE)
))
global_complexity_trends <- as.data.frame(summary(
  contrast(global_prominence_emmeans, method = "poly", adjust = "holm"),
  infer = c(TRUE, TRUE)
))
write_csv(
  global_prominence_emmeans_table,
  file.path(global_prominence_output, "Complexity_EstimatedMarginalMeans.csv")
)
write_csv(
  global_complexity_pairs,
  file.path(global_prominence_output, "Complexity_Contrasts_Holm.csv")
)
write_csv(
  global_complexity_trends,
  file.path(global_prominence_output, "Complexity_Trends_Holm.csv")
)

if (make_plots) {
  save_residual_diagnostics(
    global_prominence_model, "Participant Network 1 global metric prominence",
    file.path(global_prominence_output, "Residual_Diagnostics.png")
  )
  global_prominence_plot <- ggplot(
    global_prominence_emmeans_table,
    aes(
      x = Complexity, y = ProminenceRatio, color = Instruction,
      group = Instruction
    )
  ) +
    geom_hline(yintercept = 1, linetype = "dotted", color = "grey45") +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2.5) +
    geom_errorbar(
      aes(ymin = RatioLowerCL, ymax = RatioUpperCL), width = 0.12
    ) +
    facet_wrap(~ Movement, labeller = label_both) +
    labs(
      title = "Participant Network 1 global metric prominence",
      subtitle = paste(
        "Mean at beat/4, beat/2, beat, beat x 2, x 3, and x 4",
        "relative to all other frequencies; Version averaged"
      ),
      x = "Stimulus complexity",
      y = "Global metric / nonmetric prominence ratio",
      color = "Instruction"
    ) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold", hjust = 0.5))
  ggsave(
    file.path(global_prominence_output, "GlobalMetricProminence_Complexity_EMMeans.png"),
    global_prominence_plot, width = 10, height = 6.5, dpi = 240, bg = "white"
  )
}


# Across-outcome multiplicity and reproducibility -----------------------------

full_anova_all <- bind_rows(full_anova_tables)
full_anova_all$PValueBHAcrossFullModels <- p.adjust(
  full_anova_all$PValueRaw, method = "BH"
)
full_anova_all$SignificantBHAcrossFullModels <-
  full_anova_all$PValueBHAcrossFullModels < 0.05
write_csv(full_anova_all, file.path(output_root, "All_Full_Model_ANOVAs_BH.csv"))
write_csv(analysis_manifest, file.path(output_root, "Analysis_Manifest.csv"))

run_configuration <- c(
  paste("Input:", input_file),
  paste("Landscape similarity input:", similarity_input_file),
  paste("Network prominence input:", prominence_input_file),
  paste("Global metric prominence input:", global_prominence_input_file),
  paste("Input rows:", nrow(data)),
  paste("Participants:", nlevels(data$Participant)),
  paste("Components:", paste(components, collapse = ", ")),
  paste("Outcomes:", paste(analysis_outcomes, collapse = ", ")),
  paste("Smoke test:", smoke_test),
  paste("Plots:", make_plots),
  paste(
    "Full model:",
    "Outcome ~ Instruction * Complexity * Version * Movement * Meter +",
    "(1 | Participant)"
  ),
  paste(
    "Meter-specific model:",
    "Outcome ~ Instruction * Complexity * Version * Movement +",
    "(1 | Participant)"
  ),
  "Mirror: Fisher-z transformed for modelling",
  "Landscape similarities: Fisher-z transformed for modelling",
  "RR_Phase and DET_Phase: natural-log transformed for modelling",
  "All descriptive summaries and plots: raw scale",
  "Meter-specific Type-III tests: Bonferroni corrected across four meters",
  "Full-model Type-III tests: Benjamini-Hochberg corrected across the output family",
  "Simple-effect pairwise contrasts: Holm corrected within each conditioning cell",
  "Coverage columns: reported as QC, not modelled as scientific outcomes",
  "No additional RQA coverage threshold was imposed",
  "Teacher-only summaries: descriptive only; repeated teacher copies are not independent",
  paste(
    "Network prominence model:",
    "log(metric/nonmetric Network 1 prominence) ~ Instruction * Complexity * Version *",
    "Movement * Meter + (1 | Participant)"
  ),
  paste(
    "Global metric prominence model:",
    "log(global-metric/nonmetric Network 1 prominence) ~ Instruction *",
    "Complexity * Version * Movement + (1 | Participant)"
  ),
  "Global metric set: beat/4, beat/2, beat, beat x 2, beat x 3, beat x 4",
  "Normalization baseline: mean Network 1 prominence across all other frequencies",
  "Prominence Complexity trends: linear and quadratic within Instruction x Movement x Meter",
  paste("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
)
writeLines(run_configuration, file.path(output_root, "Run_Configuration.txt"))
write_text(sessionInfo(), output_file = file.path(output_root, "R_SessionInfo.txt"))

message("Statistical workflow completed. Outputs: ", output_root)
