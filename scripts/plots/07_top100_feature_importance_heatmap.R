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

objects <- readRDS(
  file.path(RESULTS_FOLDER, "Analysis_Objects.rds")
)

importance <- read.csv(
  file.path(
    RESULTS_FOLDER,
    "Top100_Important_Features_Final_Model.csv"
  ),
  check.names = FALSE
)

X <- objects$X
y <- objects$y

heatmap_features <- importance |>
  filter(!is.na(Importance)) |>
  slice_head(n = objects$top_n_features) |>
  pull(Feature)

heatmap_features <- intersect(
  heatmap_features,
  colnames(X)
)

if (length(heatmap_features) < 2) {
  stop("At least two important features are required for the heatmap.")
}

heatmap_matrix <- t(
  as.matrix(X[, heatmap_features, drop = FALSE])
)

heatmap_scaled <- t(scale(t(heatmap_matrix)))
heatmap_scaled[!is.finite(heatmap_scaled)] <- 0

annotation_col <- data.frame(Class = y)
rownames(annotation_col) <- rownames(X)

png(
  filename = file.path(
    FIGURES_FOLDER,
    "Top100_Features_Heatmap.png"
  ),
  width = 3200,
  height = 3600,
  res = 300
)

pheatmap::pheatmap(
  heatmap_scaled,
  annotation_col = annotation_col,
  show_rownames = TRUE,
  show_colnames = TRUE,
  fontsize_row = 5,
  fontsize_col = 7,
  main = paste(
    "Top",
    length(heatmap_features),
    "Important Features"
  )
)

dev.off()
