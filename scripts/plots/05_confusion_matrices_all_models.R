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

predictions <- read.csv(
  file.path(RESULTS_FOLDER, "Per_Sample_Averaged_Heldout_Predictions.csv"),
  check.names = FALSE
)

objects <- readRDS(
  file.path(RESULTS_FOLDER, "Analysis_Objects.rds")
)

negative_class <- objects$negative_class
positive_class <- objects$positive_class

output_folder <- file.path(
  FIGURES_FOLDER,
  "Confusion_Matrices_All_Models"
)
dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)

for (model_name in unique(predictions$Model)) {
  current <- predictions |>
    filter(Model == model_name)

  confusion_table <- table(
    Predicted = factor(
      current$Predicted,
      levels = c(negative_class, positive_class)
    ),
    Observed = factor(
      current$Observed,
      levels = c(negative_class, positive_class)
    )
  )

  confusion_data <- as.data.frame(confusion_table)

  plot_object <- ggplot(
    confusion_data,
    aes(x = Observed, y = Predicted, fill = Freq)
  ) +
    geom_tile() +
    geom_text(aes(label = Freq), size = 6) +
    theme_bw() +
    labs(
      title = paste("Confusion Matrix:", model_name),
      x = "Observed class",
      y = "Predicted class",
      fill = "Count"
    )

  ggsave(
    file.path(
      output_folder,
      paste0("Confusion_Matrix_", model_name, ".png")
    ),
    plot_object,
    width = 7,
    height = 6,
    dpi = 300
  )
}
