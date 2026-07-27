# ============================================================
# MODEL-PERFORMANCE BAR GRAPH
# Input:  results/Nested_CV_Model_Comparison.csv
# Output: results/figures/Model_Performance_Mean_SD.png
# ============================================================

required_packages <- c(
  "ggplot2",
  "dplyr",
  "tidyr"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    quietly = TRUE,
    FUN.VALUE = logical(1)
  )
]

if (length(missing_packages) > 0) {
  install.packages(
    missing_packages,
    dependencies = TRUE
  )
}

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

# ------------------------------------------------------------
# 1. FOLDER SETTINGS
# ------------------------------------------------------------

RESULTS_FOLDER <- "results"

FIGURES_FOLDER <- file.path(
  RESULTS_FOLDER,
  "figures"
)

dir.create(
  FIGURES_FOLDER,
  recursive = TRUE,
  showWarnings = FALSE
)

input_file <- file.path(
  RESULTS_FOLDER,
  "Nested_CV_Model_Comparison.csv"
)

output_file <- file.path(
  FIGURES_FOLDER,
  "Model_Performance_Mean_SD.png"
)

# ------------------------------------------------------------
# 2. CHECK INPUT FILE
# ------------------------------------------------------------

if (!file.exists(input_file)) {
  stop(
    paste0(
      "Required file was not found:\n",
      input_file,
      "\n\nRun 01_main_binary_classification.R first."
    )
  )
}

# ------------------------------------------------------------
# 3. READ MODEL RESULTS
# ------------------------------------------------------------

model_summary <- read.csv(
  input_file,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

required_columns <- c(
  "Model",
  "Accuracy_Mean",
  "Accuracy_SD",
  "BalancedAcc_Mean",
  "BalancedAcc_SD",
  "F1_Mean",
  "F1_SD",
  "ROC_AUC_Mean",
  "ROC_AUC_SD"
)

missing_columns <- setdiff(
  required_columns,
  colnames(model_summary)
)

if (length(missing_columns) > 0) {
  stop(
    paste0(
      "The following required columns are missing:\n",
      paste(missing_columns, collapse = ", ")
    )
  )
}

# ------------------------------------------------------------
# 4. CONVERT DATA INTO LONG FORMAT
# ------------------------------------------------------------

bar_data <- model_summary %>%
  select(
    Model,
    Accuracy_Mean,
    Accuracy_SD,
    BalancedAcc_Mean,
    BalancedAcc_SD,
    F1_Mean,
    F1_SD,
    ROC_AUC_Mean,
    ROC_AUC_SD
  ) %>%
  pivot_longer(
    cols = -Model,
    names_to = c("Metric", ".value"),
    names_pattern = "(.*)_(Mean|SD)"
  ) %>%
  mutate(
    Metric = recode(
      Metric,
      Accuracy = "Accuracy",
      BalancedAcc = "Balanced accuracy",
      F1 = "F1-score",
      ROC_AUC = "ROC AUC"
    )
  )

# Order models according to mean accuracy.
model_order <- model_summary %>%
  arrange(Accuracy_Mean) %>%
  pull(Model)

bar_data$Model <- factor(
  bar_data$Model,
  levels = model_order
)

bar_data$Metric <- factor(
  bar_data$Metric,
  levels = c(
    "Accuracy",
    "Balanced accuracy",
    "F1-score",
    "ROC AUC"
  )
)

# ------------------------------------------------------------
# 5. CREATE BAR GRAPH
# ------------------------------------------------------------

model_performance_plot <- ggplot(
  bar_data,
  aes(
    x = Model,
    y = Mean,
    fill = Metric
  )
) +
  geom_col(
    position = position_dodge(width = 0.80),
    width = 0.70
  ) +
  geom_errorbar(
    aes(
      ymin = pmax(0, Mean - SD),
      ymax = pmin(1, Mean + SD)
    ),
    position = position_dodge(width = 0.80),
    width = 0.20,
    linewidth = 0.5,
    na.rm = TRUE
  ) +
  coord_flip() +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.1),
    expand = c(0, 0)
  ) +
  theme_bw(base_size = 13) +
  theme(
    plot.title = element_text(
      face = "bold",
      hjust = 0.5,
      size = 16
    ),
    plot.subtitle = element_text(
      hjust = 0.5,
      size = 11
    ),
    axis.title = element_text(
      face = "bold"
    ),
    axis.text.y = element_text(
      size = 10
    ),
    legend.position = "bottom",
    legend.title = element_text(
      face = "bold"
    ),
    panel.grid.minor = element_blank()
  ) +
  labs(
    title = "Model Performance Under Nested Cross-Validation",
    subtitle = paste(
      "Bars represent mean performance;",
      "error bars represent standard deviation"
    ),
    x = "Machine-learning model",
    y = "Performance score",
    fill = "Metric"
  )

# ------------------------------------------------------------
# 6. SAVE FIGURE
# ------------------------------------------------------------

ggsave(
  filename = output_file,
  plot = model_performance_plot,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

cat("\nModel-performance bar graph created successfully.\n")
cat("Saved as:\n")
cat(normalizePath(output_file), "\n")
