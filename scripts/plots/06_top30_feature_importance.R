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

importance <- read.csv(
  file.path(
    RESULTS_FOLDER,
    "Top100_Important_Features_Final_Model.csv"
  ),
  check.names = FALSE
)

objects <- readRDS(
  file.path(RESULTS_FOLDER, "Analysis_Objects.rds")
)

top30 <- importance |>
  filter(!is.na(Importance)) |>
  slice_head(n = 30)

if (nrow(top30) == 0) {
  stop("No variable-importance values are available for the final model.")
}

plot_object <- ggplot(
  top30,
  aes(
    x = reorder(Feature, Importance),
    y = Importance
  )
) +
  geom_col() +
  coord_flip() +
  theme_bw() +
  labs(
    title = paste(
      "Top 30 Important Features:",
      objects$best_model_name
    ),
    subtitle = "Final model fitted after nested validation",
    x = "Feature",
    y = "Scaled importance"
  )

ggsave(
  file.path(FIGURES_FOLDER, "Top30_Important_Features.png"),
  plot_object,
  width = 9,
  height = 10,
  dpi = 300
)
