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

ranking <- read.csv(
  file.path(RESULTS_FOLDER, "Top6_Models_ROC_AUC.csv"),
  check.names = FALSE
)

objects <- readRDS(
  file.path(RESULTS_FOLDER, "Analysis_Objects.rds")
)

negative_class <- objects$negative_class
positive_class <- objects$positive_class

ranking$Legend_Label <- paste0(
  ranking$Model,
  " (AUC = ",
  sprintf("%.3f", ranking$ROC_AUC),
  ")"
)

roc_data <- list()

for (model_name in ranking$Model) {
  current <- predictions |>
    filter(Model == model_name)

  roc_object <- pROC::roc(
    response = factor(
      current$Observed,
      levels = c(negative_class, positive_class)
    ),
    predictor = current$Mean_Positive_Class_Probability,
    levels = c(negative_class, positive_class),
    direction = "<",
    quiet = TRUE
  )

  label <- ranking$Legend_Label[
    match(model_name, ranking$Model)
  ]

  roc_data[[model_name]] <- data.frame(
    Legend_Label = label,
    FPR = 1 - roc_object$specificities,
    TPR = roc_object$sensitivities
  )
}

roc_plot_df <- bind_rows(roc_data)
roc_plot_df$Legend_Label <- factor(
  roc_plot_df$Legend_Label,
  levels = ranking$Legend_Label
)

roc_colors <- c(
  "#0072B2", "#D55E00", "#009E73",
  "#CC79A7", "#E69F00", "#56B4E9"
)
names(roc_colors) <- levels(roc_plot_df$Legend_Label)

plot_object <- ggplot(
  roc_plot_df,
  aes(
    x = FPR,
    y = TPR,
    color = Legend_Label,
    group = Legend_Label
  )
) +
  geom_step(linewidth = 1.35, direction = "vh") +
  geom_abline(
    slope = 1,
    intercept = 0,
    color = "grey45",
    linewidth = 0.7,
    linetype = "dashed"
  ) +
  scale_color_manual(values = roc_colors) +
  scale_x_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    expand = c(0, 0)
  ) +
  coord_equal() +
  theme_classic(base_size = 14) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", hjust = 0.5),
    legend.position = "right",
    legend.title = element_blank()
  ) +
  labs(
    title = "ROC Curves of the Top Six Models",
    subtitle = "Based on averaged outer held-out probabilities",
    x = "False Positive Rate (1 - Specificity)",
    y = "True Positive Rate (Sensitivity)"
  )

ggsave(
  file.path(FIGURES_FOLDER, "ROC_Curves_Top6_Models_Color.png"),
  plot_object,
  width = 11,
  height = 8,
  dpi = 600,
  bg = "white"
)

ggsave(
  file.path(FIGURES_FOLDER, "ROC_Curves_Top6_Models_Color.pdf"),
  plot_object,
  width = 11,
  height = 8,
  bg = "white"
)
