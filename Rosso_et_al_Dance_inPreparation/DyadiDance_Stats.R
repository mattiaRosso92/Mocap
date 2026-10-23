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
# Must match CFG.common.filter_output_tag and CFG.block6.output_tag in MATLAB.
study_results_folder <- "legacy_logarithmic_recovered_dyads"
phase_output_tag <- "PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0"
overwrite_flag <- FALSE

# Resolve paths relative to this script so it can run from any directory.
command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)

if (length(file_argument) == 1) {
  script_file <- normalizePath(sub("^--file=", "", file_argument))
} else {
  script_candidates <- c(
    file.path(getwd(), "DyadiDance_Stats.R"),
    file.path(
      getwd(), "Rosso_et_al_Dance_inPreparation", "DyadiDance_Stats.R"
    )
  )
  script_file <- script_candidates[file.exists(script_candidates)][1]
  if (is.na(script_file)) {
    stop("Could not locate DyadiDance_Stats.R.")
  }
  script_file <- normalizePath(script_file)
}

repository_path <- dirname(dirname(script_file))
results_root <- file.path(
  repository_path,
  "Dance_Data",
  "FREQNESS_Results_Rosso_et_al_inPreparation"
)
# Final publication analyses: all 35 dyads, both components.
analysis_methods <- list(
  SpatialRaw = list(
    input_path = file.path(results_root, study_results_folder,
      "06_Statistics_R", "SpatialCoordination"),
    output_subfolder = file.path(study_results_folder, "SpatialCoordination", "Raw")
  ),
  SpatialFisher = list(
    input_path = file.path(results_root, study_results_folder,
      "06_Statistics_R", "SpatialCoordination"),
    output_subfolder = file.path(study_results_folder, "SpatialCoordination", "Fisher")
  ),
  PhaseSpaceRQACorrected = list(
    input_path = file.path(results_root, study_results_folder, "06_Statistics_R", phase_output_tag),
    output_subfolder = file.path(study_results_folder, phase_output_tag)
  )
)

# Fit spatial/temporal primary methods and Fisher sensitivity by default.
# Set a comma-separated list to fit other methods, or an empty string for all.
requested_methods <- Sys.getenv(
  "FREQNESS_STATS_METHODS", unset = "SpatialRaw,SpatialFisher,PhaseSpaceRQACorrected"
)
if (nzchar(requested_methods)) {
  requested_methods <- trimws(strsplit(requested_methods, ",")[[1]])
  unknown_methods <- setdiff(requested_methods, names(analysis_methods))
  if (length(unknown_methods) > 0) {
    stop("Unknown requested methods: ", paste(unknown_methods, collapse = ", "))
  }
  analysis_methods <- analysis_methods[requested_methods]
}

# One statistics folder beside the unchanged FREQNESS_Results_... data folder.
# Main and Fisher-sensitivity results use their established method subfolders.
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

  required_columns <- c("Dyad", "Visual", "Music", "Meter")
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0) {
    stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
  }
  spatial_method <- method %in% c("SpatialRaw", "SpatialFisher")
  stopifnot(method %in% c("PhaseSpaceRQACorrected", "SpatialRaw", "SpatialFisher"))
  if (method == "PhaseSpaceRQACorrected" || spatial_method) {
    # One complete observation per dyad x condition x meter; no silent row
    # exclusion or smaller-cohort fallback.
    stopifnot(
      nrow(data) == 35 * 4 * 4,
      setequal(data$Dyad, 1:35),
      setequal(data$Visual, c("No", "Yes")),
      setequal(data$Music, c("Diff", "Same")),
      setequal(data$Meter, names(configured_metric_levels)),
      !anyNA(data[required_columns]),
      !anyDuplicated(data[required_columns])
    )
    if (spatial_method) {
      stopifnot(all(c("Mirror", "FisherZ") %in% names(data)),
        all(is.finite(data$Mirror) & abs(data$Mirror) < 1),
        all(is.finite(data$FisherZ)))
    } else {
      stopifnot(all(c("RR", "DET") %in% names(data)),
        all(is.finite(data$RR) & data$RR > 0 & data$RR <= 1),
        all(is.finite(data$DET) & data$DET >= 0 & data$DET <= 1))
    }
  }

  dependent_variables <- setdiff(names(data), required_columns)
  dependent_variables <- dependent_variables[
    vapply(data[dependent_variables], is.numeric, logical(1))
  ]
  if (spatial_method) dependent_variables <- "Mirror"
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
    if (method == "SpatialFisher") {
      # MATLAB transforms each trial before averaging; do not transform twice.
      model_data$Mirror <- data$FisherZ
      transformation <- "Fisher atanh at trial level, then averaged"
    }
    log_transform <- dv %in% c("RR", "DET") &&
      !(method %in% c("PhaseSpaceRQACorrected") &&
        dv == "DET")
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
    if (spatial_method) {
      model_residuals <- residuals(factorial_model)
      standardized <- (model_residuals - mean(model_residuals)) / sd(model_residuals)
      cell_sd <- tapply(model_residuals,
        interaction(model_data$Visual, model_data$Music, model_data$Meter), sd)
      write.csv(data.frame(Dyad = model_data$Dyad, Visual = model_data$Visual,
        Music = model_data$Music, Meter = model_data$Meter,
        Fitted = fitted(factorial_model), Residual = model_residuals),
        file.path(full_model_output, "Factorial_Residuals.csv"), row.names = FALSE)
      write.csv(data.frame(Skew = mean(standardized^3),
        ExcessKurtosis = mean(standardized^4)-3,
        CellResidualSDRatio = max(cell_sd)/min(cell_sd),
        Singular = isSingular(factorial_model)),
        file.path(full_model_output, "Factorial_Residual_Shape.csv"), row.names = FALSE)
    }

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
      if (spatial_method) {
        "35 dyads; retained trial counts may differ; equal-weight dyad/condition/meter averages"
      } else if (method %in% c("PhaseSpaceRQACorrected")) {
        "Inferential models: natural-log RR; untransformed DET (diagnostic selection)"
      } else {
        "RR and DET: natural-log transformed for inferential models"
      },
      if ("Mirror" %in% dependent_variables) {
        if (method == "SpatialFisher") {
          "Mirroring sensitivity: trial-level Fisher atanh, then averaged within dyad/condition/meter"
        } else "Mirroring: analyzed on its original scale"
      },
      "Descriptive statistics and plots: original scale for all measures",
      if (method == "PhaseSpaceRQACorrected") {
        paste(
          "35 dyads; 250 Hz input; fourth-order 10 Hz Butterworth filtfilt;",
          "decimation by 10, then 15--85% crop; no z-standardization;",
          "Euclidean max_fraction radius 0.1; Theiler 0; lmin 2; vmin 2"
        )
      },
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
  if (method %in% c("PhaseSpaceRQACorrected", "SpatialRaw", "SpatialFisher") && !overwrite_flag &&
      dir.exists(method_output_root) &&
      length(list.files(method_output_root, all.files = TRUE, no.. = TRUE)) > 0) {
    stop(
      "Statistics already exist: ", method_output_root,
      ". Use a new output_subfolder or explicitly set overwrite_flag = TRUE."
    )
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
      "(BLOCK 8 in DyadiDance_MainPipeline.m)."
    )
  }
  components <- sort(unique(as.integer(sub(
    "^OUT2R_Comp#([0-9]+)\\.xlsx$", "\\1", component_workbooks
  ))))
  if (method %in% c("PhaseSpaceRQACorrected", "SpatialRaw", "SpatialFisher")) {
    stopifnot(identical(components, 1:2))
  }

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
  writeLines(
    capture.output(sessionInfo()),
    file.path(method_output_root, "R_Session_Info.txt")
  )
}


message("Statistical workflow completed. Outputs: ", output_root)
