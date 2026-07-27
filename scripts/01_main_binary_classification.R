# ============================================================
# SUPERVISED BINARY CLASSIFICATION WORKFLOW
# Main analysis script
#
# This script performs:
#   1. Package checking and setup
#   2. Data import and validation
#   3. Sample matching and preprocessing
#   4. Repeated nested stratified cross-validation
#   5. Model training, tuning, testing and evaluation
#   6. Held-out prediction generation
#   7. Feature-selection stability analysis
#   8. Final-model training and feature importance
#   9. CSV and RDS output generation
#
# Figures are generated separately by scripts/plots/*.R
# ============================================================

# ============================================================
# 1. USER SETTINGS
# ============================================================

# Input files
EXPRESSION_FILE <- "path/to/expression_matrix.csv"
TRAIT_FILE <- "path/to/traits.xlsx"

# Output directory
OUTPUT_FOLDER <- "results"

# Required columns
EXPRESSION_SAMPLE_COLUMN <- "sample"
TRAIT_SAMPLE_COLUMN <- "sample"
TRAIT_CONDITION_COLUMN <- "condition"

# Expression matrix orientation:
# "samples_rows" = samples are rows, features/genes are columns
# "genes_rows"   = features/genes are rows, samples are columns
EXPRESSION_ORIENTATION <- "samples_rows"

# Required only when EXPRESSION_ORIENTATION = "genes_rows"
GENE_ID_COLUMN <- "gene_id"

# Map the original labels in the metadata to two ML classes.
# Edit these values for your own study.
NEGATIVE_CLASS_LABELS <- c("control")
POSITIVE_CLASS_LABELS <- c("drought")

NEGATIVE_CLASS <- "Control"
POSITIVE_CLASS <- "Drought"

# Validation settings
# Repeated nested stratified cross-validation:
# Outer loop = unbiased testing
# Inner loop = feature selection and hyperparameter tuning
OUTER_FOLDS <- 5
OUTER_REPEATS <- 10
INNER_MAX_FOLDS <- 5
INNER_REPEATS <- 3

TOP_N_FEATURES <- 100
SEED <- 42
USE_GBM <- TRUE

# Apply log2(x + 1) when all values are non-negative.
# Set FALSE when the input is already transformed.
APPLY_LOG2_TRANSFORM <- TRUE

# ============================================================
# 2. REQUIRED PACKAGES
# ============================================================

required_packages <- c(
  "caret", "pROC", "ggplot2", "dplyr", "tidyr", "readxl",
  "randomForest", "ranger", "e1071", "kernlab", "gbm",
  "glmnet", "naivebayes", "rpart", "nnet", "foreach"
)

install_missing_packages <- function(packages) {
  missing <- packages[
    !vapply(packages, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))
  ]

  if (length(missing) == 0) {
    return(invisible(TRUE))
  }

  message("Installing missing packages: ", paste(missing, collapse = ", "))
  install.packages(missing, dependencies = TRUE)

  still_missing <- missing[
    !vapply(missing, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))
  ]

  if (length(still_missing) > 0) {
    stop(
      "The following packages could not be installed: ",
      paste(still_missing, collapse = ", ")
    )
  }

  invisible(TRUE)
}

install_missing_packages(required_packages)

suppressPackageStartupMessages({
  library(caret)
  library(pROC)
  library(dplyr)
  library(tidyr)
  library(readxl)
})

set.seed(SEED)
foreach::registerDoSEQ()

dir.create(OUTPUT_FOLDER, recursive = TRUE, showWarnings = FALSE)

# ============================================================
# 3. OUTPUT PATHS
# ============================================================

paths <- list(
  matched_samples = file.path(OUTPUT_FOLDER, "Matched_Samples_Used_For_ML.csv"),
  unmatched_expression = file.path(OUTPUT_FOLDER, "Samples_Only_In_Expression_File.csv"),
  unmatched_traits = file.path(OUTPUT_FOLDER, "Samples_Only_In_Trait_File.csv"),
  outer_fold_metrics = file.path(OUTPUT_FOLDER, "Outer_Fold_Metrics.csv"),
  model_comparison = file.path(OUTPUT_FOLDER, "Nested_CV_Model_Comparison.csv"),
  all_predictions = file.path(OUTPUT_FOLDER, "All_Outer_Heldout_Predictions.csv"),
  per_sample_predictions = file.path(OUTPUT_FOLDER, "Per_Sample_Averaged_Heldout_Predictions.csv"),
  stable_top_features = file.path(OUTPUT_FOLDER, "Top100_Stable_Selected_Features.csv"),
  final_top_features = file.path(OUTPUT_FOLDER, "Top100_Important_Features_Final_Model.csv"),
  final_tuning = file.path(OUTPUT_FOLDER, "Final_Model_Tuning_Results.csv"),
  top_features_all_models = file.path(OUTPUT_FOLDER, "Top100_Important_Features_All_Models.csv"),
  top6_roc_table = file.path(OUTPUT_FOLDER, "Top6_Models_ROC_AUC.csv"),
  analysis_objects = file.path(OUTPUT_FOLDER, "Analysis_Objects.rds"),
  session_info = file.path(OUTPUT_FOLDER, "Session_Info.txt")
)

# ============================================================
# 4. HELPER FUNCTIONS
# ============================================================

clean_id <- function(x) {
  trimws(as.character(x))
}

clean_column_names <- function(x) {
  trimws(gsub("^\ufeff", "", x))
}

make_unique_feature_names <- function(x) {
  make.unique(clean_id(x), sep = "_duplicate_")
}

to_numeric_dataframe <- function(data) {
  output <- as.data.frame(
    lapply(data, function(x) suppressWarnings(as.numeric(as.character(x)))),
    check.names = FALSE
  )

  all_na <- vapply(output, function(x) all(is.na(x)), logical(1))

  if (any(all_na)) {
    warning(
      sum(all_na),
      " completely non-numeric predictor columns were removed."
    )
    output <- output[, !all_na, drop = FALSE]
  }

  output[is.na(output)] <- 0
  output
}

standardize_binary_class <- function(x) {
  cleaned <- tolower(trimws(as.character(x)))
  output <- rep(NA_character_, length(cleaned))

  output[cleaned %in% tolower(NEGATIVE_CLASS_LABELS)] <- NEGATIVE_CLASS
  output[cleaned %in% tolower(POSITIVE_CLASS_LABELS)] <- POSITIVE_CLASS

  factor(output, levels = c(NEGATIVE_CLASS, POSITIVE_CLASS))
}

calculate_binary_metrics <- function(observed, predicted, probability) {
  observed <- factor(observed, levels = c(NEGATIVE_CLASS, POSITIVE_CLASS))
  predicted <- factor(predicted, levels = c(NEGATIVE_CLASS, POSITIVE_CLASS))

  cm <- caret::confusionMatrix(
    data = predicted,
    reference = observed,
    positive = POSITIVE_CLASS
  )

  roc_auc <- tryCatch(
    as.numeric(
      pROC::auc(
        pROC::roc(
          response = observed,
          predictor = probability,
          levels = c(NEGATIVE_CLASS, POSITIVE_CLASS),
          direction = "<",
          quiet = TRUE
        )
      )
    ),
    error = function(e) NA_real_
  )

  c(
    Accuracy = unname(cm$overall["Accuracy"]),
    Kappa = unname(cm$overall["Kappa"]),
    BalancedAcc = unname(cm$byClass["Balanced Accuracy"]),
    Sensitivity = unname(cm$byClass["Sensitivity"]),
    Specificity = unname(cm$byClass["Specificity"]),
    Precision = unname(cm$byClass["Precision"]),
    Recall = unname(cm$byClass["Recall"]),
    F1 = unname(cm$byClass["F1"]),
    ROC_AUC = roc_auc
  )
}

select_features_training_only <- function(X_train, y_train, top_n) {
  minimum_samples <- max(2, floor(0.20 * nrow(X_train)))

  keep <- colSums(X_train > 0) >= minimum_samples
  filtered <- X_train[, keep, drop = FALSE]

  if (ncol(filtered) == 0) {
    stop("No predictors remained after minimum-expression filtering.")
  }

  nzv <- caret::nearZeroVar(filtered)
  if (length(nzv) > 0) {
    filtered <- filtered[, -nzv, drop = FALSE]
  }

  if (ncol(filtered) == 0) {
    stop("No predictors remained after near-zero-variance filtering.")
  }

  scores <- caret::filterVarImp(x = filtered, y = y_train)
  scores$Feature <- rownames(scores)

  numeric_columns <- names(scores)[
    vapply(scores, is.numeric, logical(1))
  ]

  scores$SelectionScore <- rowMeans(
    scores[, numeric_columns, drop = FALSE],
    na.rm = TRUE
  )

  scores |>
    arrange(desc(SelectionScore), Feature) |>
    slice_head(n = min(top_n, nrow(scores))) |>
    pull(Feature)
}

make_inner_control <- function(y_train) {
  smallest_class <- min(table(y_train))
  inner_folds <- max(2, min(INNER_MAX_FOLDS, smallest_class))

  caret::trainControl(
    method = "repeatedcv",
    number = inner_folds,
    repeats = INNER_REPEATS,
    classProbs = TRUE,
    summaryFunction = caret::twoClassSummary,
    savePredictions = "final",
    allowParallel = FALSE
  )
}

get_model_specifications <- function(use_gbm = TRUE) {
  specifications <- list(
    Logistic_Regression = list(
      method = "glm",
      extra_args = list(family = binomial()),
      tuneLength = NULL,
      preProcess = c("center", "scale")
    ),
    Elastic_Net = list(
      method = "glmnet",
      extra_args = list(),
      tuneLength = 10,
      preProcess = c("center", "scale")
    ),
    SVM_Linear = list(
      method = "svmLinear",
      extra_args = list(),
      tuneLength = 5,
      preProcess = c("center", "scale")
    ),
    SVM_Radial = list(
      method = "svmRadial",
      extra_args = list(),
      tuneLength = 8,
      preProcess = c("center", "scale")
    ),
    Random_Forest = list(
      method = "rf",
      extra_args = list(),
      tuneLength = 5,
      preProcess = NULL
    ),
    Ranger = list(
      method = "ranger",
      extra_args = list(importance = "permutation"),
      tuneLength = 8,
      preProcess = NULL
    ),
    Naive_Bayes = list(
      method = "naive_bayes",
      extra_args = list(),
      tuneLength = 6,
      preProcess = c("center", "scale")
    ),
    KNN = list(
      method = "knn",
      extra_args = list(),
      tuneLength = 10,
      preProcess = c("center", "scale")
    ),
    Decision_Tree = list(
      method = "rpart",
      extra_args = list(),
      tuneLength = 10,
      preProcess = NULL
    ),
    Neural_Network = list(
      method = "nnet",
      extra_args = list(trace = FALSE, MaxNWts = 10000, maxit = 500),
      tuneLength = 6,
      preProcess = c("center", "scale")
    )
  )

  if (use_gbm) {
    specifications$Gradient_Boosting <- list(
      method = "gbm",
      optimization_metric = "Accuracy",
      extra_args = list(verbose = FALSE),
      tuneGrid = expand.grid(
        n.trees = c(25, 50, 100),
        interaction.depth = c(1, 2),
        shrinkage = c(0.05, 0.10),
        n.minobsinnode = 1
      ),
      tuneLength = NULL,
      preProcess = NULL
    )
  }

  specifications
}

train_one_model <- function(specification, training_data, control_object) {
  predictors <- training_data[
    , setdiff(colnames(training_data), "condition"), drop = FALSE
  ]
  response <- training_data$condition

  if (ncol(predictors) == 0) {
    stop("No predictors were supplied to the model.")
  }

  optimization_metric <- specification$optimization_metric %||% "ROC"
  model_control <- control_object

  if (identical(optimization_metric, "Accuracy")) {
    model_control$summaryFunction <- caret::defaultSummary
  }

  arguments <- list(
    x = predictors,
    y = response,
    method = specification$method,
    trControl = model_control,
    metric = optimization_metric
  )

  if (!is.null(specification$tuneGrid)) {
    arguments$tuneGrid <- specification$tuneGrid
  } else if (!is.null(specification$tuneLength)) {
    arguments$tuneLength <- specification$tuneLength
  }

  if (!is.null(specification$preProcess)) {
    arguments$preProcess <- specification$preProcess
  }

  do.call(caret::train, c(arguments, specification$extra_args))
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

extract_variable_importance <- function(fit, top_n) {
  importance <- tryCatch(
    caret::varImp(fit, scale = TRUE)$importance,
    error = function(e) NULL
  )

  if (is.null(importance)) {
    return(data.frame())
  }

  importance$Feature <- rownames(importance)
  numeric_columns <- names(importance)[
    vapply(importance, is.numeric, logical(1))
  ]

  if ("Overall" %in% colnames(importance)) {
    output <- importance |>
      transmute(Feature, Importance = Overall)
  } else {
    output <- importance |>
      mutate(
        Importance = rowMeans(
          across(all_of(numeric_columns)),
          na.rm = TRUE
        )
      ) |>
      select(Feature, Importance)
  }

  output |>
    arrange(desc(Importance), Feature) |>
    slice_head(n = min(top_n, nrow(output)))
}

# ============================================================
# 5. READ AND VALIDATE INPUT FILES
# ============================================================

if (!file.exists(EXPRESSION_FILE)) {
  stop("Expression file not found: ", EXPRESSION_FILE)
}

if (!file.exists(TRAIT_FILE)) {
  stop("Trait file not found: ", TRAIT_FILE)
}

expression_df <- read.csv(
  EXPRESSION_FILE,
  check.names = FALSE,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8-BOM"
)

trait_df <- as.data.frame(
  readxl::read_excel(TRAIT_FILE, sheet = 1),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

colnames(expression_df) <- clean_column_names(colnames(expression_df))
colnames(trait_df) <- tolower(clean_column_names(colnames(trait_df)))

trait_sample_column <- tolower(TRAIT_SAMPLE_COLUMN)
trait_condition_column <- tolower(TRAIT_CONDITION_COLUMN)

required_trait_columns <- c(trait_sample_column, trait_condition_column)
missing_trait_columns <- setdiff(required_trait_columns, colnames(trait_df))

if (length(missing_trait_columns) > 0) {
  stop(
    "Missing metadata columns: ",
    paste(missing_trait_columns, collapse = ", ")
  )
}

# ============================================================
# 6. PREPARE PREDICTOR MATRIX
# ============================================================

if (EXPRESSION_ORIENTATION == "samples_rows") {
  if (!EXPRESSION_SAMPLE_COLUMN %in% colnames(expression_df)) {
    stop("Expression sample column not found: ", EXPRESSION_SAMPLE_COLUMN)
  }

  sample_ids_expression <- clean_id(
    expression_df[[EXPRESSION_SAMPLE_COLUMN]]
  )

  if (anyDuplicated(sample_ids_expression)) {
    stop("Duplicate sample IDs were found in the expression file.")
  }

  X_expression <- expression_df[
    , setdiff(colnames(expression_df), EXPRESSION_SAMPLE_COLUMN), drop = FALSE
  ]
  X_expression <- to_numeric_dataframe(X_expression)
  rownames(X_expression) <- sample_ids_expression

} else if (EXPRESSION_ORIENTATION == "genes_rows") {
  if (!GENE_ID_COLUMN %in% colnames(expression_df)) {
    stop("Feature ID column not found: ", GENE_ID_COLUMN)
  }

  feature_ids <- make_unique_feature_names(
    expression_df[[GENE_ID_COLUMN]]
  )

  values <- expression_df[
    , setdiff(colnames(expression_df), GENE_ID_COLUMN), drop = FALSE
  ]
  values <- to_numeric_dataframe(values)
  rownames(values) <- feature_ids

  X_expression <- as.data.frame(
    t(as.matrix(values)),
    check.names = FALSE
  )

  sample_ids_expression <- clean_id(rownames(X_expression))
  rownames(X_expression) <- sample_ids_expression

} else {
  stop(
    "EXPRESSION_ORIENTATION must be 'samples_rows' or 'genes_rows'."
  )
}

# ============================================================
# 7. PREPARE METADATA
# ============================================================

trait_df <- trait_df[
  !is.na(trait_df[[trait_sample_column]]) &
    trimws(as.character(trait_df[[trait_sample_column]])) != "",
  ,
  drop = FALSE
]

trait_df[[trait_sample_column]] <- clean_id(
  trait_df[[trait_sample_column]]
)

if (anyDuplicated(trait_df[[trait_sample_column]])) {
  stop("Duplicate sample IDs were found in the metadata file.")
}

trait_df$ML_Condition <- standardize_binary_class(
  trait_df[[trait_condition_column]]
)

unknown <- trait_df[
  is.na(trait_df$ML_Condition),
  c(trait_sample_column, trait_condition_column),
  drop = FALSE
]

if (nrow(unknown) > 0) {
  print(unique(unknown))
  stop(
    "Some condition labels were not recognised. Update ",
    "NEGATIVE_CLASS_LABELS and POSITIVE_CLASS_LABELS."
  )
}

# ============================================================
# 8. MATCH SAMPLES
# ============================================================

trait_sample_ids <- trait_df[[trait_sample_column]]
matched_ids <- intersect(sample_ids_expression, trait_sample_ids)

only_expression <- setdiff(sample_ids_expression, trait_sample_ids)
only_traits <- setdiff(trait_sample_ids, sample_ids_expression)

write.csv(
  data.frame(Sample = only_expression),
  paths$unmatched_expression,
  row.names = FALSE
)

write.csv(
  data.frame(Sample = only_traits),
  paths$unmatched_traits,
  row.names = FALSE
)

if (length(matched_ids) < 4) {
  stop("Fewer than four matching samples were found.")
}

matched_ids <- sample_ids_expression[
  sample_ids_expression %in% matched_ids
]

trait_matched <- trait_df[
  match(matched_ids, trait_df[[trait_sample_column]]),
  ,
  drop = FALSE
]

X <- X_expression[matched_ids, , drop = FALSE]
y <- factor(
  trait_matched$ML_Condition,
  levels = c(NEGATIVE_CLASS, POSITIVE_CLASS)
)
sample_ids <- matched_ids

write.csv(
  data.frame(
    Sample = sample_ids,
    Original_Class = trait_matched[[trait_condition_column]],
    ML_Class = y
  ),
  paths$matched_samples,
  row.names = FALSE
)

if (any(table(y) < 2)) {
  stop("Each class must contain at least two matched samples.")
}

# ============================================================
# 9. PREPROCESSING
# ============================================================

if (APPLY_LOG2_TRANSFORM) {
  if (any(X < 0, na.rm = TRUE)) {
    warning(
      "Negative values were detected; log2(x + 1) was not applied."
    )
  } else {
    X <- log2(X + 1)
  }
}

keep_nonzero <- colSums(X != 0) > 0
X <- X[, keep_nonzero, drop = FALSE]

if (ncol(X) < 2) {
  stop("Too few usable predictors remain after preprocessing.")
}

# ============================================================
# 10. CREATE OUTER STRATIFIED FOLDS
# ============================================================

outer_folds <- min(OUTER_FOLDS, min(table(y)))

if (outer_folds < 2) {
  stop("At least two outer folds are required.")
}

outer_train_indices <- caret::createMultiFolds(
  y = y,
  k = outer_folds,
  times = OUTER_REPEATS
)

specifications <- get_model_specifications(USE_GBM)

all_predictions <- list()
all_fold_metrics <- list()
selection_records <- list()

prediction_counter <- 1
metric_counter <- 1
selection_counter <- 1

# ============================================================
# 11. REPEATED NESTED STRATIFIED CROSS-VALIDATION
# ============================================================

for (split_name in names(outer_train_indices)) {
  message("Outer split: ", split_name)

  train_index <- outer_train_indices[[split_name]]
  test_index <- setdiff(seq_len(nrow(X)), train_index)

  X_train <- X[train_index, , drop = FALSE]
  X_test <- X[test_index, , drop = FALSE]

  y_train <- droplevels(y[train_index])
  y_test <- factor(y[test_index], levels = levels(y))

  selected_features <- select_features_training_only(
    X_train,
    y_train,
    TOP_N_FEATURES
  )

  selection_records[[selection_counter]] <- data.frame(
    Split = split_name,
    Feature = selected_features,
    Rank = seq_along(selected_features)
  )
  selection_counter <- selection_counter + 1

  training_data <- data.frame(
    condition = y_train,
    X_train[, selected_features, drop = FALSE],
    check.names = FALSE
  )

  testing_data <- X_test[, selected_features, drop = FALSE]
  inner_control <- make_inner_control(y_train)

  for (model_name in names(specifications)) {
    message("  Training: ", model_name)

    fit <- tryCatch(
      train_one_model(
        specifications[[model_name]],
        training_data,
        inner_control
      ),
      error = function(e) {
        message(
          "  FAILED ", model_name, " in ", split_name, ": ", e$message
        )
        NULL
      }
    )

    if (is.null(fit)) {
      next
    }

    predicted_class <- tryCatch(
      predict(fit, newdata = testing_data, type = "raw"),
      error = function(e) NULL
    )

    predicted_probability <- tryCatch(
      predict(fit, newdata = testing_data, type = "prob")[, POSITIVE_CLASS],
      error = function(e) NULL
    )

    if (is.null(predicted_class) || is.null(predicted_probability)) {
      next
    }

    all_predictions[[prediction_counter]] <- data.frame(
      Split = split_name,
      Model = model_name,
      RowIndex = test_index,
      Sample = sample_ids[test_index],
      Observed = y_test,
      Predicted = factor(predicted_class, levels = levels(y)),
      Positive_Class_Probability = as.numeric(predicted_probability)
    )
    prediction_counter <- prediction_counter + 1

    if (length(unique(y_test)) == 2) {
      metrics <- calculate_binary_metrics(
        y_test,
        predicted_class,
        predicted_probability
      )

      all_fold_metrics[[metric_counter]] <- data.frame(
        Split = split_name,
        Model = model_name,
        t(metrics),
        row.names = NULL,
        check.names = FALSE
      )
      metric_counter <- metric_counter + 1
    }
  }
}

predictions_df <- bind_rows(all_predictions)
fold_metrics_df <- bind_rows(all_fold_metrics)
selection_df <- bind_rows(selection_records)

if (nrow(predictions_df) == 0) {
  stop("No model completed successfully.")
}

write.csv(predictions_df, paths$all_predictions, row.names = FALSE)
write.csv(fold_metrics_df, paths$outer_fold_metrics, row.names = FALSE)

# ============================================================
# 12. FEATURE-SELECTION STABILITY
# ============================================================

number_outer_splits <- length(outer_train_indices)

stable_features <- selection_df |>
  group_by(Feature) |>
  summarise(
    Selection_Count = n(),
    Selection_Frequency = Selection_Count / number_outer_splits,
    Mean_Rank_When_Selected = mean(Rank),
    Median_Rank_When_Selected = median(Rank),
    .groups = "drop"
  ) |>
  arrange(
    desc(Selection_Frequency),
    Mean_Rank_When_Selected,
    Feature
  ) |>
  slice_head(n = TOP_N_FEATURES)

write.csv(
  stable_features,
  paths$stable_top_features,
  row.names = FALSE
)

# ============================================================
# 13. MODEL PERFORMANCE SUMMARY
# ============================================================

model_summary <- fold_metrics_df |>
  group_by(Model) |>
  summarise(
    Completed_Outer_Folds = n(),
    Accuracy_Mean = mean(Accuracy, na.rm = TRUE),
    Accuracy_SD = sd(Accuracy, na.rm = TRUE),
    Kappa_Mean = mean(Kappa, na.rm = TRUE),
    Kappa_SD = sd(Kappa, na.rm = TRUE),
    BalancedAcc_Mean = mean(BalancedAcc, na.rm = TRUE),
    BalancedAcc_SD = sd(BalancedAcc, na.rm = TRUE),
    Sensitivity_Mean = mean(Sensitivity, na.rm = TRUE),
    Sensitivity_SD = sd(Sensitivity, na.rm = TRUE),
    Specificity_Mean = mean(Specificity, na.rm = TRUE),
    Specificity_SD = sd(Specificity, na.rm = TRUE),
    Precision_Mean = mean(Precision, na.rm = TRUE),
    Precision_SD = sd(Precision, na.rm = TRUE),
    Recall_Mean = mean(Recall, na.rm = TRUE),
    Recall_SD = sd(Recall, na.rm = TRUE),
    F1_Mean = mean(F1, na.rm = TRUE),
    F1_SD = sd(F1, na.rm = TRUE),
    ROC_AUC_Mean = mean(ROC_AUC, na.rm = TRUE),
    ROC_AUC_SD = sd(ROC_AUC, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(
    desc(F1_Mean),
    desc(ROC_AUC_Mean),
    desc(BalancedAcc_Mean)
  )

write.csv(model_summary, paths$model_comparison, row.names = FALSE)

best_model_name <- model_summary$Model[1]
message("Best model: ", best_model_name)

# ============================================================
# 14. AVERAGED HELD-OUT PREDICTIONS
# ============================================================

sample_predictions <- predictions_df |>
  group_by(Model, RowIndex, Sample, Observed) |>
  summarise(
    Mean_Positive_Class_Probability = mean(
      Positive_Class_Probability,
      na.rm = TRUE
    ),
    Heldout_Count = n(),
    .groups = "drop"
  ) |>
  mutate(
    Predicted = factor(
      ifelse(
        Mean_Positive_Class_Probability >= 0.5,
        POSITIVE_CLASS,
        NEGATIVE_CLASS
      ),
      levels = c(NEGATIVE_CLASS, POSITIVE_CLASS)
    ),
    Observed = factor(
      Observed,
      levels = c(NEGATIVE_CLASS, POSITIVE_CLASS)
    )
  )

write.csv(
  sample_predictions,
  paths$per_sample_predictions,
  row.names = FALSE
)

# ============================================================
# 15. TOP-SIX ROC TABLE
# ============================================================

roc_auc_ranking <- sample_predictions |>
  group_by(Model) |>
  group_modify(
    ~{
      if (length(unique(.x$Observed)) < 2) {
        return(data.frame(ROC_AUC = NA_real_))
      }

      roc_object <- tryCatch(
        pROC::roc(
          response = .x$Observed,
          predictor = .x$Mean_Positive_Class_Probability,
          levels = c(NEGATIVE_CLASS, POSITIVE_CLASS),
          direction = "<",
          quiet = TRUE
        ),
        error = function(e) NULL
      )

      data.frame(
        ROC_AUC = if (is.null(roc_object)) {
          NA_real_
        } else {
          as.numeric(pROC::auc(roc_object))
        }
      )
    }
  ) |>
  ungroup() |>
  filter(is.finite(ROC_AUC)) |>
  arrange(desc(ROC_AUC), Model) |>
  slice_head(n = 6) |>
  mutate(Rank = row_number()) |>
  select(Rank, Model, ROC_AUC)

write.csv(
  roc_auc_ranking,
  paths$top6_roc_table,
  row.names = FALSE
)

# ============================================================
# 16. TRAIN FINAL SELECTED MODEL
# ============================================================

final_selected_features <- select_features_training_only(
  X,
  y,
  TOP_N_FEATURES
)

final_training_data <- data.frame(
  condition = y,
  X[, final_selected_features, drop = FALSE],
  check.names = FALSE
)

final_control <- caret::trainControl(
  method = "repeatedcv",
  number = min(INNER_MAX_FOLDS, min(table(y))),
  repeats = 20,
  classProbs = TRUE,
  summaryFunction = caret::twoClassSummary,
  savePredictions = "final",
  allowParallel = FALSE
)

final_fit <- train_one_model(
  specifications[[best_model_name]],
  final_training_data,
  final_control
)

write.csv(
  final_fit$results,
  paths$final_tuning,
  row.names = FALSE
)

final_importance <- extract_variable_importance(
  final_fit,
  TOP_N_FEATURES
)

if (nrow(final_importance) == 0) {
  final_importance <- data.frame(
    Feature = final_selected_features,
    Importance = NA_real_
  )
}

final_importance <- final_importance |>
  left_join(stable_features, by = "Feature") |>
  arrange(desc(Importance), desc(Selection_Frequency))

write.csv(
  final_importance,
  paths$final_top_features,
  row.names = FALSE
)

# ============================================================
# 17. FEATURE IMPORTANCE FOR ALL MODELS
# ============================================================

all_model_importance <- list()
importance_counter <- 1

for (model_name in names(specifications)) {
  message("Final importance model: ", model_name)

  fit <- tryCatch(
    train_one_model(
      specifications[[model_name]],
      final_training_data,
      final_control
    ),
    error = function(e) {
      message("  FAILED: ", e$message)
      NULL
    }
  )

  if (is.null(fit)) {
    next
  }

  current_importance <- extract_variable_importance(
    fit,
    TOP_N_FEATURES
  )

  if (nrow(current_importance) == 0) {
    next
  }

  current_importance <- current_importance |>
    mutate(
      Model = model_name,
      Rank = row_number(),
      .before = 1
    )

  all_model_importance[[importance_counter]] <- current_importance
  importance_counter <- importance_counter + 1

  write.csv(
    current_importance,
    file.path(
      OUTPUT_FOLDER,
      paste0("Top100_Important_Features_", model_name, ".csv")
    ),
    row.names = FALSE
  )
}

all_model_importance_df <- bind_rows(all_model_importance)

write.csv(
  all_model_importance_df,
  paths$top_features_all_models,
  row.names = FALSE
)

# ============================================================
# 18. SAVE OBJECTS REQUIRED BY PLOTTING SCRIPTS
# ============================================================

saveRDS(
  list(
    X = X,
    y = y,
    sample_ids = sample_ids,
    negative_class = NEGATIVE_CLASS,
    positive_class = POSITIVE_CLASS,
    best_model_name = best_model_name,
    final_selected_features = final_selected_features,
    top_n_features = TOP_N_FEATURES
  ),
  paths$analysis_objects
)

capture.output(sessionInfo(), file = paths$session_info)

cat("\n============================================================\n")
cat("ANALYSIS COMPLETED\n")
cat("Matched samples:", nrow(X), "\n")
cat("Predictors after preprocessing:", ncol(X), "\n")
cat("Outer folds:", outer_folds, "\n")
cat("Outer repeats:", OUTER_REPEATS, "\n")
cat("Best model:", best_model_name, "\n")
cat("Outputs saved in:", normalizePath(OUTPUT_FOLDER), "\n")
cat("Run the scripts in scripts/plots/ to generate figures.\n")
cat("============================================================\n")
