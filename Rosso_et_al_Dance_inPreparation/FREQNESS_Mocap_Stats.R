# ============================================================================
# FREQ-NESS MOCAP: DANCE STATISTICAL ANALYSES
# ============================================================================
#
# Automatically analyses every component exported by the MATLAB pipeline,
# all dyadic dependent variables, and all four metric levels using the models
# described in the Dance manuscript.
#
# AUTHORS:
# Mattia Rosso, Felix Bigand, Leonardo Bonetti
# ============================================================================


# Required libraries ----------------------------------------------------------

library(readxl)
library(dplyr)
library(ggplot2)
library(lme4)
library(lmerTest)  # Satterthwaite denominator degrees of freedom and p-values


# Paths and manuscript settings ----------------------------------------------

bonferroni_tests <- 4
bonferroni_alpha <- 0.05 / bonferroni_tests
configured_metric_levels <- c(M1 = 0.25, M2 = 0.5, M3 = 1, M4 = 2)

# Resolve paths relative to this script so it can run from any directory.
command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)

if (length(file_argument) == 1) {
  script_file <- normalizePath(sub("^--file=", "", file_argument))
} else {
  script_candidates <- c(
    file.path(getwd(), "FREQNESS_Mocap_Stats.R"),
    file.path(
      getwd(), "Rosso_et_al_Dance_inPreparation", "FREQNESS_Mocap_Stats.R"
    )
  )
  script_file <- script_candidates[file.exists(script_candidates)][1]
  if (is.na(script_file)) {
    stop("Could not locate FREQNESS_Mocap_Stats.R.")
  }
  script_file <- normalizePath(script_file)
}

repository_path <- dirname(dirname(script_file))
results_root <- file.path(
  repository_path,
  "Dance_Data",
  "FREQNESS_Results_Rosso_et_al_inPreparation"
)
statistics_input_path <- file.path(results_root, "06_Statistics_R")

# The latest non-standardized phase-space analysis is the default target. Historical
# JRQA and phase-space outputs remain untouched unless this flag is changed
# explicitly for a deliberate reanalysis.
run_established_methods <- FALSE
analysis_methods <- list(
  PhaseSpaceRQANonStandardized = list(
    input_path = file.path(
      statistics_input_path, "PhaseSpaceRQA_NonStandardized"
    ),
    output_subfolder = file.path(
      "PhaseSpaceRQA_NonStandardized", "SelectedTransformations"
    )
  ),
  FixedDyadRadiusJRQA = list(
    input_path = file.path(
      statistics_input_path, "JRQA_Validated", "FixedDyadRadius"
    ),
    output_subfolder = file.path("JRQA_Validated", "FixedDyadRadius")
  ),
  CorrectedManuscriptJRQA = list(
    input_path = file.path(
      statistics_input_path, "JRQA_Validated", "CorrectedManuscript"
    ),
    output_subfolder = file.path("JRQA_Validated", "CorrectedManuscript")
  ),
  RobustnessJRQA = list(
    input_path = file.path(
      statistics_input_path, "JRQA_Validated", "Robustness"
    ),
    output_subfolder = file.path("JRQA_Validated", "Robustness")
  ),
  FaithfulAdaptiveMaxJRQA = list(
    input_path = file.path(
      statistics_input_path, "JRQA_Validated", "FaithfulAdaptiveMax"
    ),
    output_subfolder = file.path("JRQA_Validated", "FaithfulAdaptiveMax")
  )
)
if (run_established_methods) {
  analysis_methods$JRQA <- list(
    input_path = statistics_input_path,
    output_subfolder = NULL
  )
  analysis_methods$PhaseSpaceRQA <- list(
    input_path = file.path(statistics_input_path, "PhaseSpaceRQA"),
    output_subfolder = "PhaseSpaceRQA"
  )
}

# Fit the primary method by default, retaining completed sensitivity outputs.
# Set a comma-separated list to fit other methods, or an empty string for all.
requested_methods <- Sys.getenv(
  "FREQNESS_STATS_METHODS", unset = "PhaseSpaceRQANonStandardized"
)
if (nzchar(requested_methods)) {
  requested_methods <- trimws(strsplit(requested_methods, ",")[[1]])
  unknown_methods <- setdiff(requested_methods, names(analysis_methods))
  if (length(unknown_methods) > 0) {
    stop("Unknown requested methods: ", paste(unknown_methods, collapse = ", "))
  }
  analysis_methods <- analysis_methods[requested_methods]
}

# One main statistics folder beside FREQNESS_Results_.... Existing JRQA
# component folders remain at this level; phase-space results use a separate
# method subfolder.
output_root <- file.path(
  repository_path,
  "Dance_Data",
  "FREQNESS_Mocap_Stats_Results"
)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)


# Output helpers ---------------------------------------------------------------

write_text <- function(..., output_file) {
  writeLines(capture.output(...), output_file)
}

anova_to_data_frame <- function(anova_result) {
  output <- as.data.frame(anova_result)
  output$Term <- rownames(output)
  rownames(output) <- NULL
  output[, c("Term", setdiff(names(output), "Term"))]
}

write_anova <- function(anova_result, output_file) {
  write.csv(anova_to_data_frame(anova_result), output_file, row.names = FALSE)
}

write_shapiro <- function(model_residuals, output_file) {
  test <- shapiro.test(model_residuals)
  write.csv(
    data.frame(W = unname(test$statistic), PValue = test$p.value),
    output_file,
    row.names = FALSE
  )
}

save_residual_diagnostics <- function(model, title_text, output_file) {
  model_residuals <- residuals(model)
  model_fitted <- fitted(model)

  png(output_file, width = 1800, height = 600, res = 150)
  par(mfrow = c(1, 3))
  hist(
    model_residuals,
    main = paste(title_text, "Residuals"),
    xlab = "Residuals"
  )
  qqnorm(model_residuals, main = paste(title_text, "QQ plot"))
  qqline(model_residuals, col = "red")
  plot(
    model_fitted,
    model_residuals,
    xlab = "Fitted values",
    ylab = "Residuals",
    main = paste(title_text, "Residuals vs fitted")
  )
  abline(h = 0, col = "red")
  par(mfrow = c(1, 1))
  dev.off()
}

save_polynomial_diagnostics <- function(models, output_file) {
  png(output_file, width = 1800, height = 1200, res = 150)
  par(mfrow = c(2, 3))
  model_names <- c("Linear", "Quadratic", "Cubic")

  for (model_index in seq_along(models)) {
    model_residuals <- residuals(models[[model_index]])
    hist(
      model_residuals,
      main = paste(model_names[model_index], "residuals"),
      xlab = "Residuals"
    )
  }
  for (model_index in seq_along(models)) {
    model_residuals <- residuals(models[[model_index]])
    qqnorm(model_residuals, main = paste("QQ:", model_names[model_index]))
    qqline(model_residuals, col = "red")
  }
  par(mfrow = c(1, 1))
  dev.off()
}


# Component analysis ----------------------------------------------------------

analyse_component <- function(
  input_file,
  component,
  component_output,
  method
) {
  message(
    "Analysing ", method, " Component ", component, ": ",
    basename(input_file)
  )

  data <- read_excel(input_file)

  # Current MATLAB exports use Dyad. Accept the earlier Subject-labelled file
  # so an already completed analysis remains readable.
  if ("Subject" %in% names(data) && !"Dyad" %in% names(data)) {
    data <- data %>% rename(Dyad = Subject)
  }

  required_columns <- c("Dyad", "Visual", "Music", "Meter")
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0) {
    stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
  }

  dependent_variables <- setdiff(names(data), required_columns)
  dependent_variables <- dependent_variables[
    vapply(data[dependent_variables], is.numeric, logical(1))
  ]
  if (length(dependent_variables) == 0) {
    stop("No numeric dependent variables were found in ", input_file)
  }

  meter_levels <- unique(as.character(data$Meter))
  meter_index <- suppressWarnings(as.numeric(gsub("[^0-9]", "", meter_levels)))
  meter_levels <- meter_levels[order(meter_index)]
  meter_display <- ifelse(
    meter_levels %in% names(configured_metric_levels),
    paste0("Meter_", configured_metric_levels[meter_levels], "x"),
    paste0("Meter_", meter_levels)
  )
  names(meter_display) <- meter_levels

  data <- data %>%
    mutate(
      Dyad = factor(Dyad),
      Visual = factor(Visual),
      Music = factor(Music),
      Meter = factor(Meter, levels = meter_levels),
      MeterIndex = as.numeric(gsub("[^0-9]", "", as.character(Meter)))
    )

  analysis_manifest <- data.frame()

  for (dv in dependent_variables) {
    message("  Dependent variable: ", dv)

    dv_output <- file.path(component_output, dv)
    full_model_output <- file.path(dv_output, "All_Meters")
    dir.create(full_model_output, recursive = TRUE, showWarnings = FALSE)

    # Preserve manuscript transformations for established methods. For the
    # latest non-standardized phase-space analysis, residual diagnostics favour
    # log RR and untransformed DET. This post hoc choice is recorded separately.
    # Figures and descriptive statistics always remain on the original scale.
    model_data <- data
    transformation <- "none"
    log_transform <- dv %in% c("RR", "DET") &&
      !(method == "PhaseSpaceRQANonStandardized" && dv == "DET")
    if (log_transform) {
      if (any(model_data[[dv]] <= 0, na.rm = TRUE)) {
        stop("Cannot log-transform non-positive values in ", dv, ".")
      }
      model_data[[dv]] <- log(model_data[[dv]])
      transformation <- "natural log"
    }

    posthoc_anova <- list()

    # Metric-specific post-hoc models ---------------------------------------
    for (meter_level in meter_levels) {
      meter_name <- unname(meter_display[meter_level])
      message("    ", meter_name)

      meter_output <- file.path(dv_output, meter_name)
      dir.create(meter_output, recursive = TRUE, showWarnings = FALSE)

      raw_meter_data <- data %>% filter(Meter == meter_level)
      meter_model_data <- model_data %>% filter(Meter == meter_level)

      summary_stats <- raw_meter_data %>%
        group_by(Visual, Music) %>%
        summarise(
          mean = mean(.data[[dv]], na.rm = TRUE),
          sem = sd(.data[[dv]], na.rm = TRUE) /
            sqrt(sum(!is.na(.data[[dv]]))),
          n = sum(!is.na(.data[[dv]])),
          .groups = "drop"
        )
      write.csv(
        summary_stats,
        file.path(meter_output, "Descriptive_Statistics_Raw_Scale.csv"),
        row.names = FALSE
      )

      bar_plot <- ggplot(
        summary_stats,
        aes(x = Music, y = mean, fill = Visual)
      ) +
        geom_col(position = position_dodge(width = 0.8), width = 0.7) +
        geom_errorbar(
          aes(ymin = mean - sem, ymax = mean + sem),
          position = position_dodge(width = 0.8),
          width = 0.2
        ) +
        labs(
          title = paste("Mean ± SEM for", meter_name, "-", dv),
          subtitle = paste(method, "| Component", component, "| Raw scale"),
          y = dv,
          x = "Music",
          fill = "Visual"
        ) +
        theme_minimal(base_size = 14) +
        theme(plot.title = element_text(hjust = 0.5, face = "bold")) +
        scale_fill_manual(values = c("No" = "#990000", "Yes" = "#003399"))

      line_plot <- ggplot(
        summary_stats,
        aes(x = Music, y = mean, group = Visual, color = Visual)
      ) +
        geom_line(linewidth = 1.2) +
        geom_point(size = 4) +
        geom_errorbar(
          aes(ymin = mean - sem, ymax = mean + sem),
          width = 0.15,
          linewidth = 0.7
        ) +
        labs(
          title = paste("Mean ± SEM for", meter_name, "-", dv),
          subtitle = paste(method, "| Component", component, "| Raw scale"),
          x = "Music",
          y = dv,
          color = "Visual"
        ) +
        theme_minimal(base_size = 14) +
        theme(
          plot.title = element_text(hjust = 0.5, face = "bold"),
          legend.position = "right"
        ) +
        scale_color_manual(values = c("No" = "#990000", "Yes" = "#003399"))

      ggsave(
        file.path(meter_output, "Bar_SEM_Raw_Scale.png"),
        bar_plot,
        width = 8,
        height = 6,
        dpi = 300,
        bg = "white"
      )
      ggsave(
        file.path(meter_output, "Line_SEM_Raw_Scale.png"),
        line_plot,
        width = 8,
        height = 6,
        dpi = 300,
        bg = "white"
      )

      meter_model <- lmer(
        as.formula(paste(dv, "~ Visual * Music + (1 | Dyad)")),
        data = meter_model_data
      )
      meter_anova <- anova_to_data_frame(anova(meter_model, type = 3))
      meter_anova$Meter <- meter_level
      posthoc_anova[[meter_level]] <- meter_anova

      write_text(
        summary(meter_model),
        output_file = file.path(meter_output, "Mixed_Model_Summary.txt")
      )
      write.csv(
        meter_anova,
        file.path(meter_output, "Type_III_ANOVA_Uncorrected.csv"),
        row.names = FALSE
      )
      write_shapiro(
        residuals(meter_model),
        file.path(meter_output, "Residual_Shapiro_Wilk.csv")
      )
      save_residual_diagnostics(
        meter_model,
        paste("Component", component, dv, meter_name),
        file.path(meter_output, "Residual_Diagnostics.png")
      )

      analysis_manifest <- bind_rows(
        analysis_manifest,
        data.frame(
          Method = method,
          Component = component,
          DependentVariable = dv,
          Meter = meter_level,
          MeterLabel = meter_name,
          TransformationForModels = transformation,
          PlotScale = "raw",
          N = nrow(meter_model_data),
          OutputFolder = meter_output
        )
      )
    }

    # Manuscript correction across the four metric-specific post-hoc models.
    posthoc_table <- bind_rows(posthoc_anova)
    p_column <- grep("^Pr\\(", names(posthoc_table), value = TRUE)
    posthoc_table$PValueRaw <- posthoc_table[[p_column]]
    posthoc_table$PValueBonferroni <- ave(
      posthoc_table$PValueRaw,
      posthoc_table$Term,
      FUN = function(p) p.adjust(p, method = "bonferroni")
    )
    posthoc_table$SignificantBonferroni <-
      posthoc_table$PValueRaw < bonferroni_alpha
    write.csv(
      posthoc_table,
      file.path(dv_output, "PostHoc_Type_III_ANOVA_Bonferroni.csv"),
      row.names = FALSE
    )

    # Full factorial model: Metric as a categorical factor ------------------
    factorial_model <- lmer(
      as.formula(paste(dv, "~ Visual * Music * Meter + (1 | Dyad)")),
      data = model_data
    )
    write_text(
      summary(factorial_model),
      output_file = file.path(full_model_output, "Factorial_Model_Summary.txt")
    )
    write_anova(
      anova(factorial_model, type = 3),
      file.path(full_model_output, "Factorial_Type_III_ANOVA.csv")
    )
    write_shapiro(
      residuals(factorial_model),
      file.path(full_model_output, "Factorial_Residual_Shapiro_Wilk.csv")
    )
    save_residual_diagnostics(
      factorial_model,
      paste("Component", component, dv, "all meters"),
      file.path(full_model_output, "Factorial_Residual_Diagnostics.png")
    )

    # Supplementary linear/quadratic/cubic model comparison -----------------
    linear_model <- lmer(
      as.formula(paste(dv, "~ Visual * Music * MeterIndex + (1 | Dyad)")),
      data = model_data
    )
    quadratic_model <- lmer(
      as.formula(
        paste(dv, "~ Visual * Music * poly(MeterIndex, 2) + (1 | Dyad)")
      ),
      data = model_data
    )
    cubic_model <- lmer(
      as.formula(
        paste(dv, "~ Visual * Music * poly(MeterIndex, 3) + (1 | Dyad)")
      ),
      data = model_data
    )
    polynomial_models <- list(linear_model, quadratic_model, cubic_model)

    write_text(
      anova(linear_model, quadratic_model, cubic_model),
      output_file = file.path(full_model_output, "Polynomial_Model_Comparison.txt")
    )
    write_anova(
      anova(cubic_model, type = 3),
      file.path(full_model_output, "Cubic_Type_III_ANOVA.csv")
    )

    polynomial_shapiro <- bind_rows(lapply(
      seq_along(polynomial_models),
      function(model_index) {
        test <- shapiro.test(residuals(polynomial_models[[model_index]]))
        data.frame(
          Model = c("Linear", "Quadratic", "Cubic")[model_index],
          W = unname(test$statistic),
          PValue = test$p.value
        )
      }
    ))
    write.csv(
      polynomial_shapiro,
      file.path(full_model_output, "Polynomial_Residual_Shapiro_Wilk.csv"),
      row.names = FALSE
    )
    save_polynomial_diagnostics(
      polynomial_models,
      file.path(full_model_output, "Polynomial_Residual_Diagnostics.png")
    )
  }

  write.csv(
    analysis_manifest,
    file.path(component_output, "Analysis_Manifest.csv"),
    row.names = FALSE
  )
  writeLines(
    c(
      paste("Method:", method),
      paste("Component:", component),
      paste("Input:", input_file),
      paste("Dependent variables:", paste(dependent_variables, collapse = ", ")),
      paste("Metric levels:", paste(meter_display, collapse = ", ")),
      if (method == "PhaseSpaceRQANonStandardized") {
        "Inferential models: natural-log RR; untransformed DET (diagnostic selection)"
      } else {
        "RR and DET: natural-log transformed for inferential models"
      },
      if ("Mirror" %in% dependent_variables) {
        "Mirroring: analyzed on its original scale"
      },
      "Descriptive statistics and plots: original scale for all measures",
      paste(
        "Metric-specific post-hoc correction: Bonferroni across",
        bonferroni_tests,
        "metric levels; alpha =",
        bonferroni_alpha
      ),
      paste("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
    ),
    file.path(component_output, "Run_Summary.txt")
  )
}


# Run every exported component and method -------------------------------------

for (method in names(analysis_methods)) {
  method_settings <- analysis_methods[[method]]
  method_input_path <- method_settings$input_path
  method_output_root <- if (is.null(method_settings$output_subfolder)) {
    output_root
  } else {
    file.path(output_root, method_settings$output_subfolder)
  }
  dir.create(method_output_root, recursive = TRUE, showWarnings = FALSE)

  component_workbooks <- list.files(
    method_input_path,
    pattern = "^OUT2R_Comp#[0-9]+\\.xlsx$",
    full.names = FALSE
  )
  if (length(component_workbooks) == 0) {
    stop(
      "No ", method, " component workbooks were found in ",
      method_input_path,
      ". Run the corresponding MATLAB statistical export block first " ,
      "(BLOCK 4 for the JRQA validation pipeline)."
    )
  }
  components <- sort(unique(as.integer(sub(
    "^OUT2R_Comp#([0-9]+)\\.xlsx$", "\\1", component_workbooks
  ))))

  component_status <- data.frame()
  for (component in components) {
    component_output <- file.path(
      method_output_root,
      paste0("Component_", component)
    )
    dir.create(component_output, recursive = TRUE, showWarnings = FALSE)

    input_file <- file.path(
      method_input_path,
      paste0("OUT2R_Comp#", component, ".xlsx")
    )
    analyse_component(input_file, component, component_output, method)

    component_status <- bind_rows(
      component_status,
      data.frame(
        Method = method,
        Component = component,
        InputFile = input_file,
        Status = "completed",
        OutputFolder = component_output
      )
    )
  }

  write.csv(
    component_status,
    file.path(method_output_root, "Component_Status.csv"),
    row.names = FALSE
  )
}


# Legacy versus validated JRQA comparison -------------------------------------

comparison_output_root <- file.path(
  output_root, "JRQA_Validated", "Method_Comparison_FixedDyadRadius"
)
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

message("Statistical workflow completed. Outputs: ", output_root)
