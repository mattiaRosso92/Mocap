# HISTORICAL ONLY: saved JRQA method comparisons and circular-shift controls.
# Original cohorts/settings are preserved; not a final publication analysis.
# Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
suppressPackageStartupMessages({library(readxl);library(dplyr);library(ggplot2);library(lme4);library(lmerTest)})
repo <- normalizePath(Sys.getenv("FREQNESS_REPO", unset = getwd()), mustWork = TRUE)
results_root <- file.path(repo,"Dance_Data","FREQNESS_Results_Rosso_et_al_inPreparation")
statistics_input_path <- file.path(results_root,"06_Statistics_R")
output_root <- file.path(repo,"Dance_Data","FREQNESS_Mocap_Stats_Results")
run_established_methods <- TRUE

# Legacy versus validated JRQA comparison -------------------------------------

# Do not regenerate or overwrite historical comparisons in a phase-space run.
if (run_established_methods) {
comparison_output_root <- file.path(
  output_root, "JRQA_Validated", "Method_Comparison_FixedDyadRadius"
)
if(dir.exists(comparison_output_root)) stop("Comparison output exists; choose a new folder.")
dir.create(comparison_output_root, recursive = TRUE, showWarnings = FALSE)

comparison_inputs <- list(
  Legacy = statistics_input_path,
  FaithfulAdaptiveMax = file.path(
    statistics_input_path, "JRQA_Validated", "FaithfulAdaptiveMax"
  ),
  FixedDyadRadius = file.path(
    statistics_input_path, "JRQA_Validated", "FixedDyadRadius"
  )
)

validated_components <- sort(unique(as.integer(sub(
  "^OUT2R_Comp#([0-9]+)\\.xlsx$", "\\1",
  list.files(comparison_inputs$FixedDyadRadius, pattern = "^OUT2R_Comp#")
))))

for (component in validated_components) {
  component_data <- bind_rows(lapply(names(comparison_inputs), function(method) {
    input_file <- file.path(
      comparison_inputs[[method]], paste0("OUT2R_Comp#", component, ".xlsx")
    )
    data <- read_excel(input_file)
    data$Method <- method
    data
  })) %>%
    mutate(
      Meter = factor(Meter, levels = paste0("M", 1:4)),
      Visual = factor(Visual),
      Music = factor(Music)
    )

  component_output <- file.path(
    comparison_output_root, paste0("Component_", component)
  )
  dir.create(component_output, recursive = TRUE, showWarnings = FALSE)

  for (dv in c("RR", "DET")) {
    summary_table <- component_data %>%
      group_by(Method, Meter, Visual, Music) %>%
      summarise(
        Mean = mean(.data[[dv]], na.rm = TRUE),
        SEM = sd(.data[[dv]], na.rm = TRUE) /
          sqrt(sum(!is.na(.data[[dv]]))),
        N = sum(!is.na(.data[[dv]])),
        .groups = "drop"
      )
    write.csv(
      summary_table,
      file.path(component_output, paste0(dv, "_Method_Condition_Means.csv")),
      row.names = FALSE
    )

    method_plot <- ggplot(
      summary_table,
      aes(x = Meter, y = Mean, color = Method, group = Method)
    ) +
      geom_line(linewidth = 1) +
      geom_point(size = 2.5) +
      geom_errorbar(
        aes(ymin = Mean - SEM, ymax = Mean + SEM),
        width = 0.08,
        linewidth = 0.5
      ) +
      facet_grid(Visual ~ Music, labeller = label_both) +
      scale_color_manual(values = c(
        Legacy = "#777777",
        CorrectedManuscript = "#006D77",
        Robustness = "#D97706",
        FaithfulAdaptiveMax = "#003399",
        FixedDyadRadius = "#007C83"
      )) +
      labs(
        title = paste("JRQA method comparison for", dv),
        subtitle = paste("Component", component, "| Mean ± SEM across dyads"),
        x = "Metric level",
        y = dv,
        color = "Method"
      ) +
      theme_minimal(base_size = 13) +
      theme(
        plot.title = element_text(face = "bold"),
        legend.position = "bottom"
      )
    ggsave(
      file.path(component_output, paste0(dv, "_Method_Comparison.png")),
      method_plot, width = 11, height = 7.5, dpi = 300, bg = "white"
    )

    legacy_data <- component_data %>%
      filter(Method == "Legacy") %>%
      select(Dyad, Visual, Music, Meter, Legacy = all_of(dv))
    validated_data <- component_data %>%
      filter(Method != "Legacy") %>%
      select(Dyad, Visual, Music, Meter, Method, Validated = all_of(dv))
    paired_data <- merge(
      validated_data, legacy_data,
      by = c("Dyad", "Visual", "Music", "Meter")
    )

    agreement_table <- paired_data %>%
      group_by(Method, Meter) %>%
      summarise(
        CorrelationWithLegacy = cor(Legacy, Validated, use = "complete.obs"),
        MeanLegacy = mean(Legacy, na.rm = TRUE),
        MeanValidated = mean(Validated, na.rm = TRUE),
        MeanDifference = mean(Validated - Legacy, na.rm = TRUE),
        MeanRatio = mean(Validated / Legacy, na.rm = TRUE),
        .groups = "drop"
      )
    write.csv(
      agreement_table,
      file.path(component_output, paste0(dv, "_Agreement_With_Legacy.csv")),
      row.names = FALSE
    )

    agreement_plot <- ggplot(
      paired_data,
      aes(x = Legacy, y = Validated, color = Method)
    ) +
      geom_abline(slope = 1, intercept = 0, color = "grey65") +
      geom_point(alpha = 0.65, size = 1.8) +
      facet_grid(Method ~ Meter, scales = "free") +
      scale_color_manual(values = c(
        CorrectedManuscript = "#006D77",
        Robustness = "#D97706",
        FaithfulAdaptiveMax = "#003399",
        FixedDyadRadius = "#007C83"
      )) +
      labs(
        title = paste("Validated versus legacy", dv),
        subtitle = paste("Component", component),
        x = paste("Legacy", dv),
        y = paste("Validated", dv)
      ) +
      theme_minimal(base_size = 12) +
      theme(
        plot.title = element_text(face = "bold"),
        legend.position = "none"
      )
    ggsave(
      file.path(component_output, paste0(dv, "_Agreement_With_Legacy.png")),
      agreement_plot, width = 12, height = 6.5, dpi = 300, bg = "white"
    )
  }
}


# Circular-shift coupling validation -----------------------------------------

surrogate_input_root <- file.path(
  results_root, "03_Coordination_JRQA_Validated", "SurrogateValidation",
  "FixedDyadRadius"
)
surrogate_output_root <- file.path(
  output_root, "JRQA_Validated", "Surrogate_Validation_FixedDyadRadius"
)
if(dir.exists(surrogate_output_root)) stop("Surrogate output exists; choose a new folder.")
dir.create(surrogate_output_root, recursive = TRUE, showWarnings = FALSE)

run_surrogate_statistics <- tolower(Sys.getenv(
  "FREQNESS_RUN_SURROGATE_STATS", unset = "true"
)) != "false"

if (run_surrogate_statistics) for (component in validated_components) {
  input_file <- file.path(
    surrogate_input_root,
    paste0("Component_", component),
    paste0("FREQNESS_JRQA_SURROGATE_SUMMARY_Comp#", component, ".csv")
  )
  if (!file.exists(input_file)) {
    stop("Surrogate validation input not found: ", input_file)
  }

  component_output <- file.path(
    surrogate_output_root, paste0("Component_", component)
  )
  dir.create(component_output, recursive = TRUE, showWarnings = FALSE)
  surrogate_data <- read.csv(input_file)

  surrogate_long <- bind_rows(
    surrogate_data %>% transmute(
      Dyad, Condition, Trial, MeterIndex, MetricLevel,
      Outcome = "RR", Observed = ObservedRR, NullMean = NullRRMean,
      PValue = PValueRR, ZScore = ZScoreRR
    ),
    surrogate_data %>% transmute(
      Dyad, Condition, Trial, MeterIndex, MetricLevel,
      Outcome = "DET", Observed = ObservedDET, NullMean = NullDETMean,
      PValue = PValueDET, ZScore = ZScoreDET
    )
  )

  surrogate_summary <- surrogate_long %>%
    group_by(Outcome, MeterIndex, MetricLevel) %>%
    summarise(
      MeanObserved = mean(Observed),
      MeanNull = mean(NullMean),
      MeanDifference = mean(Observed - NullMean),
      MeanZScore = mean(ZScore),
      ProportionPBelow05 = mean(PValue <= 0.05),
      N = n(),
      .groups = "drop"
    )
  write.csv(
    surrogate_summary,
    file.path(component_output, "Surrogate_Validation_Summary.csv"),
    row.names = FALSE
  )

  # Exploratory group test: dyad is the independent sampling unit, not each
  # condition/meter case. These p-values are unadjusted across outcomes.
  group_tests <- bind_rows(lapply(c("RR", "DET"), function(outcome) {
    this_data <- surrogate_long %>% filter(Outcome == outcome) %>%
      mutate(Delta = Observed - NullMean, Dyad = factor(Dyad))
    model <- lmer(Delta ~ 1 + (1 | Dyad), data = this_data)
    coefficient <- coef(summary(model))[1, ]
    data.frame(
      Outcome = outcome, NDyads = nlevels(this_data$Dyad),
      NCases = nrow(this_data), MeanDifference = coefficient["Estimate"],
      SE = coefficient["Std. Error"], DF = coefficient["df"],
      T = coefficient["t value"], PValue = coefficient["Pr(>|t|)"],
      PositiveCases = sum(this_data$Delta > 0),
      EmpiricalPBelow05 = sum(this_data$PValue <= 0.05)
    )
  }))
  write.csv(group_tests, file.path(component_output,
    "Surrogate_Group_Tests_Exploratory.csv"), row.names = FALSE)

  value_long <- bind_rows(
    surrogate_long %>% transmute(
      Dyad, Outcome, MeterIndex, MetricLevel,
      Reference = "Observed", Value = Observed
    ),
    surrogate_long %>% transmute(
      Dyad, Outcome, MeterIndex, MetricLevel,
      Reference = "Circular-shift null", Value = NullMean
    )
  )
  value_summary <- value_long %>%
    group_by(Dyad, Outcome, MeterIndex, MetricLevel, Reference) %>%
    summarise(Value = mean(Value), .groups = "drop") %>%
    group_by(Outcome, MeterIndex, MetricLevel, Reference) %>%
    summarise(
      Mean = mean(Value),
      SEM = sd(Value) / sqrt(n()),
      .groups = "drop"
    )

  value_plot <- ggplot(
    value_summary,
    aes(
      x = factor(MetricLevel), y = Mean,
      color = Reference, group = Reference
    )
  ) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 3) +
    geom_errorbar(
      aes(ymin = Mean - SEM, ymax = Mean + SEM),
      width = 0.08, linewidth = 0.6
    ) +
    facet_wrap(~ Outcome, scales = "free_y") +
    scale_color_manual(values = c(
      "Observed" = "#006D77", "Circular-shift null" = "#A0A0A0"
    )) +
    labs(
      title = "Observed JRQA and circular-shift controls",
      subtitle = paste(
        "Component", component,
        "| fixed dyad radius | mean ± SEM across sampled dyads"
      ),
      x = "Metric level relative to beat", y = "Value", color = NULL
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "bottom"
    )
  ggsave(
    file.path(component_output, "Observed_Versus_Surrogate.png"),
    value_plot, width = 10, height = 5.8, dpi = 300, bg = "white"
  )

  z_plot <- ggplot(
    surrogate_long,
    aes(x = factor(MetricLevel), y = ZScore, fill = Outcome)
  ) +
    geom_hline(yintercept = 0, color = "grey55", linewidth = 0.5) +
    geom_boxplot(width = 0.65, outlier.shape = NA, alpha = 0.75) +
    geom_jitter(width = 0.12, alpha = 0.5, size = 1.5) +
    facet_wrap(~ Outcome, scales = "free_y") +
    scale_fill_manual(values = c("RR" = "#006D77", "DET" = "#D97706")) +
    labs(
      title = "Observed-minus-null standardized effects",
      subtitle = paste("Component", component, "| 100 surrogates per case"),
      x = "Metric level relative to beat", y = "Surrogate z-score"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "none"
    )
  ggsave(
    file.path(component_output, "Surrogate_Z_Scores.png"),
    z_plot, width = 10, height = 5.8, dpi = 300, bg = "white"
  )
}

}
