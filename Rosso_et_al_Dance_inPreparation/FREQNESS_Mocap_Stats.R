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

# MATLAB exports one workbook for every component selected for coordination
# in BLOCK 3. Discover those workbooks here so this script remains in sync
# without maintaining a second component count in R.
component_workbooks <- list.files(
  statistics_input_path,
  pattern = "^OUT2R_Comp#[0-9]+\\.xlsx$",
  full.names = FALSE
)
if (length(component_workbooks) == 0) {
  stop(
    "No component workbooks were found in ",
    statistics_input_path,
    ". Run BLOCK 6 in FREQNESS_DyadicDance_Mocap.m first."
  )
}
components <- sort(unique(as.integer(sub(
  "^OUT2R_Comp#([0-9]+)\\.xlsx$", "\\1", component_workbooks
))))

# One main statistics folder beside FREQNESS_Results_..., containing one
# subfolder for each exported body-network component.
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

analyse_component <- function(input_file, component, component_output) {
  message("Analysing Component ", component, ": ", basename(input_file))

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

    # Manuscript specification: RR and DET are natural-log transformed before
    # model fitting; Mirroring remains on its original scale. Figures and
    # descriptive statistics remain on the original, interpretable scale.
    model_data <- data
    transformation <- "none"
    if (dv %in% c("RR", "DET")) {
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
          subtitle = paste("Component", component, "| Raw scale"),
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
          subtitle = paste("Component", component, "| Raw scale"),
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
        dpi = 300
      )
      ggsave(
        file.path(meter_output, "Line_SEM_Raw_Scale.png"),
        line_plot,
        width = 8,
        height = 6,
        dpi = 300
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
      paste("Component:", component),
      paste("Input:", input_file),
      paste("Dependent variables:", paste(dependent_variables, collapse = ", ")),
      paste("Metric levels:", paste(meter_display, collapse = ", ")),
      "RR and DET: natural-log transformed for inferential models",
      "Mirroring: analyzed on its original scale",
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


# Run every exported component ------------------------------------------------

component_status <- data.frame()

for (component in components) {
  component_output <- file.path(output_root, paste0("Component_", component))
  dir.create(component_output, recursive = TRUE, showWarnings = FALSE)

  input_file <- file.path(
    statistics_input_path,
    paste0("OUT2R_Comp#", component, ".xlsx")
  )

  if (!file.exists(input_file)) {
    notice <- c(
      paste("Component", component, "was not analysed."),
      paste("Missing input:", input_file),
      "Generate the component-specific MATLAB export and rerun this script."
    )
    writeLines(notice, file.path(component_output, "INPUT_MISSING.txt"))
    warning(notice[1], immediate. = TRUE)
    status <- "missing input"
  } else {
    missing_notice <- file.path(component_output, "INPUT_MISSING.txt")
    if (file.exists(missing_notice)) {
      unlink(missing_notice)
    }
    analyse_component(input_file, component, component_output)
    status <- "completed"
  }

  component_status <- bind_rows(
    component_status,
    data.frame(
      Component = component,
      InputFile = input_file,
      Status = status,
      OutputFolder = component_output
    )
  )
}

write.csv(
  component_status,
  file.path(output_root, "Component_Status.csv"),
  row.names = FALSE
)

message("Statistical workflow completed. Outputs: ", output_root)
