# Shared settings used by the plotting scripts
RESULTS_FOLDER <- "results"
FIGURES_FOLDER <- file.path(RESULTS_FOLDER, "figures")
dir.create(FIGURES_FOLDER, recursive = TRUE, showWarnings = FALSE)

required_packages <- c("ggplot2", "dplyr", "tidyr", "pROC", "pheatmap")

missing <- required_packages[
  !vapply(required_packages, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))
]

if (length(missing) > 0) {
  install.packages(missing, dependencies = TRUE)
}

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(pROC)
  library(pheatmap)
})

fold_metrics <- read.csv(
  file.path(RESULTS_FOLDER, "Outer_Fold_Metrics.csv"),
  check.names = FALSE
)

boxplot_data <- fold_metrics |>
  select(Model, Accuracy, BalancedAcc, F1, ROC_AUC) |>
  pivot_longer(
    cols = -Model,
    names_to = "Metric",
    values_to = "Score"
  )

plot_object <- ggplot(
  boxplot_data,
  aes(x = Model, y = Score, fill = Model)
) +
  geom_boxplot(outlier.alpha = 0.5) +
  facet_wrap(~Metric, scales = "free_y") +
  coord_flip() +
  theme_bw() +
  theme(legend.position = "none") +
  labs(
    title = "Distribution of Performance Across Outer Folds",
    x = "Model",
    y = "Score"
  )

ggsave(
  file.path(FIGURES_FOLDER, "Outer_Fold_Performance_Boxplots.png"),
  plot_object,
  width = 13,
  height = 10,
  dpi = 300
)
