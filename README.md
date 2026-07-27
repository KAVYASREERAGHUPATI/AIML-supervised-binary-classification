# Supervised Binary Classification Using Machine Learning

## Overview

This repository contains an R-based supervised machine learning workflow for binary classification.
Examples of binary classification tasks include:
        Control vs Treatment
        Healthy vs Diseased
        Responder vs Non-responder
        Stress vs Non-stress
        Positive vs Negative
        Class A vs Class B

The code is designed to compare multiple classification algorithms, optimise their hyperparameters, evaluate their performance using nested cross-validation and identify the variables or features that contribute most strongly to class separation.

The repository contains reusable analysis scripts only. No original dataset or study-specific files are included.

Users can apply this workflow to their own dataset after formatting the input data and modifying the file paths, class labels and selected parameters.

## Objectives

The workflow is designed to:

* Prepare a numerical dataset for binary classification.(Ex: DESeq2 normalised counts file)
* Match predictor data with sample metadata or class labels.(sample class labels file)
* Perform exploratory analysis using principal component analysis.
* Compare multiple supervised machine learning models.
* Optimise model hyperparameters.
* Evaluate models using repeated nested cross-validation.
* Generate held-out predictions for unbiased performance estimation.
* Compare models using several classification metrics.
* Generate receiver operating characteristic curves.
* Generate confusion matrices.
* Identify important predictive features.
* Evaluate the stability of selected features.
* Train a final model using the complete dataset.


## Machine Learning Models

The workflow can evaluate the following supervised machine learning algorithms:

* Logistic Regression
* Elastic Net
* Linear Support Vector Machine
* Radial Support Vector Machine
* Random Forest
* Ranger
* Naive Bayes
* K-Nearest Neighbours
* Decision Tree
* Neural Network
* Gradient Boosting Machine

The exact models included in the analysis can be modified according to the dataset and computational requirements.

## Validation Strategy
there are several validation stratagies are there depending on the sample size, class distribution, computational resources and purpose of the analysis.
Here, The workflow uses  nested stratified cross-validation.

Nested cross-validation contains two separate validation loops:
      Outer Cross-Validation: The outer loop is used to evaluate model performance on held-out samples that are not used during feature selection, model training or hyperparameter optimisation.
      Inner Cross-Validation:The inner loop is used to:
                                                       * Select features.
                                                       * Tune model hyperparameters.
                                                       * Identify the best parameter combination within the training data.

This separation helps reduce overfitting and prevents information leakage between model training and final performance evaluation.

A typical configuration may include:
.......
Outer validation: Stratified 10-fold cross-validation
Repeats: 5
Inner validation: Stratified cross-validation
.......
These settings can be modified depending on sample size, class distribution and computational resources.

## NOTE:  
For most binary classification datasets, "stratified K-fold cross-validation" is preferred because it maintains the class distribution within each fold. When feature selection, preprocessing and hyperparameter tuning are performed, nested "stratified cross-validation" is more appropriate because it separates model optimization from final performance evaluation. For very small datasets, "LOOCV" may be considered, although repeated stratified K-fold cross-validation often provides a more stable estimate.

## Workflow

The main analysis steps are:

1. Import the predictor matrix.
2. Import sample labels or metadata.
3. Validate and match sample names.
4. Remove missing or invalid observations.
5. Filter low-information or near-zero-variance features.
6. perform exploratory analysis using PCA.
7. Divide the data into outer training and test folds.
8. Perform feature selection within the training data.
9. Tune each model using inner cross-validation.
10. Generate predictions for the outer held-out test samples.
11. Repeat the procedure across all folds and repetitions.
12. Calculate model-performance metrics.
13. Compare the evaluated models.
14. Generate ROC curves and confusion matrices.
15. Rank predictive features.
16. Calculate feature-selection stability.
17. Train the final selected model using the complete dataset.

## Repository Structure

```text
supervised-binary-classification/
├── README.md
├── LICENSE
├── .gitignore
└── scripts/
    ├── 01_data_preparation.R
    ├── 02_exploratory_analysis_pca.R
    ├── 03_feature_selection.R
    ├── 04_nested_cross_validation.R
    ├── 05_model_performance_comparison.R
    ├── 06_roc_curve_analysis.R
    ├── 07_confusion_matrix_analysis.R
    ├── 08_feature_importance.R
    ├── 09_feature_selection_stability.R
    ├── 10_expression_heatmap.R
    └── 11_final_model_training.R
```

The scripts should be executed in numerical order.

## Script Description

### 01_data_preparation.R

This script is used to:

* Import the predictor matrix.
* Import the sample labels.
* Match sample names between files.
* Check class labels.
* Remove missing values.
* Convert the data into the required format.
* Remove low-information features.
* Save the processed dataset for subsequent analysis.

### 02_exploratory_analysis_pca.R

This script performs exploratory analysis using principal component analysis.

It can be used to:

* Examine overall variation in the dataset.
* Visualise separation between the two classes.
* Identify possible outlying samples.
* Assess whether major sources of variation are associated with class labels.

### 03_feature_selection.R

This script performs feature selection within the training data.

Feature selection must be conducted independently inside each training fold to prevent data leakage.

Depending on the analysis, this script may include:

* Variance-based filtering
* Univariate feature ranking
* Correlation filtering
* Recursive feature elimination
* Model-based feature selection

### 04_nested_cross_validation.R

This is the main model-training and validation script.

It performs:

* Creation of stratified outer folds.
* Creation of inner cross-validation folds.
* Feature selection within each training fold.
* Hyperparameter optimisation.
* Model training.
* Held-out test prediction.
* Repetition of the process across folds and repeats.
* Storage of prediction probabilities and class predictions.

### 05_model_performance_comparison.R

This script calculates and compares model-performance metrics.

The supported metrics may include:

* Accuracy
* Balanced Accuracy
* Cohen’s Kappa
* Precision
* Recall
* F1-score
* Sensitivity
* Specificity
* Receiver operating characteristic area under the curve

The script can also generate:

* Mean performance values.
* Standard deviations across outer folds.
* Model-comparison tables.
* Performance bar plots.
* Outer-fold performance boxplots.

### 06_roc_curve_analysis.R

This script generates receiver operating characteristic curves using held-out predictions.

It can be used to:

* Calculate ROC AUC values.
* Compare the best-performing models.
* Display only the top models.
* Generate publication-quality ROC figures.
* Save model-specific ROC results.

ROC curves should be generated from outer held-out predictions rather than training predictions.

### 07_confusion_matrix_analysis.R

This script generates confusion matrices for the evaluated models.

It can calculate:

* True positives
* True negatives
* False positives
* False negatives
* Sensitivity
* Specificity
* Precision
* Recall
* Accuracy

The script may generate:

* A confusion matrix for the best-performing model.
* Separate confusion matrices for all models.
* Tables summarising classification results.

### 08_feature_importance.R

This script identifies the features that contribute most strongly to classification.

Feature-importance values may be obtained directly from models that support native importance measures or calculated using a model-independent approach.

The script can generate:

* Ranked feature-importance tables.
* Top-feature bar plots.
* Model-specific feature rankings.
* Combined feature rankings across models.

### 09_feature_selection_stability.R

This script measures how consistently each feature is selected across outer cross-validation folds.

Feature stability is calculated using the number or proportion of outer-fold training sets in which a feature was selected.

Frequently selected features may be more reproducible and less dependent on a particular data split.

The script can generate:

* Feature-selection frequency tables.
* Selection proportions.
* Top stable-feature plots.
* Ranked lists of consistently selected features.

### 10_expression_heatmap.R

This script generates a heatmap for the most important or most stable features.

Although the script name refers to expression data, it can be adapted for any numerical predictor matrix.

The heatmap can display:

* Samples as columns.
* Selected features as rows.
* Standardised feature values.
* Class annotations.
* Hierarchical clustering of samples and features.

The script name may alternatively be changed to:

```text
10_top_features_heatmap.R
```

This is more appropriate for a general-purpose repository.

### 11_final_model_training.R

This script trains the final selected classifier using the complete available dataset.

It may include:

* Final feature selection.
* Final hyperparameter optimisation.
* Training the selected model.
* Saving the trained model object.
* Saving the final selected features.
* Saving tuning results.
* Generating final predicted probabilities.

The final trained model should be used only after model selection and validation have been completed.

## Required Input Format

The code requires two primary inputs:

1. A numerical predictor matrix.
2. A file containing sample identifiers and binary class labels.

### Predictor Matrix

The predictor matrix should contain samples and numerical features.

A recommended format is:

```text
Feature_ID,Sample_01,Sample_02,Sample_03
Feature_001,8.45,7.92,9.01
Feature_002,5.62,6.18,5.97
Feature_003,2.41,3.02,2.79
```

In this format:

* Features are represented as rows.
* Samples are represented as columns.
* The first column contains feature identifiers.
* All remaining values must be numerical.

The scripts can transpose the matrix so that samples become rows before machine learning analysis.

Alternatively, users may modify the code to accept a sample-by-feature matrix directly.

### Class Label File

The class-label file should contain at least two columns:

```text
sample,condition
Sample_01,Class_A
Sample_02,Class_B
Sample_03,Class_A
```

The sample names must match the sample names in the predictor matrix.

The two class labels can be renamed according to the study.

For example:

```text
Control
Treatment
```

or:

```text
Negative
Positive
```

One class must be defined as the positive class before calculating sensitivity, specificity, precision, recall and ROC AUC.

## Data Requirements

Before using the workflow, users should ensure that:

* The response variable contains exactly two classes.
* Predictor values are numerical.
* Sample identifiers are unique.
* Feature identifiers are unique.
* Sample names match across all input files.
* Missing values are handled appropriately.
* Class labels are clearly defined.
* The dataset contains enough samples for the selected cross-validation strategy.
* Class imbalance is examined before model training.

For small datasets, the number of folds and repeats should be adjusted carefully.

## Preventing Data Leakage

All preprocessing operations that learn information from the data should be performed using the training portion of each cross-validation fold.

This includes:

* Feature selection
* Scaling
* Centring
* Imputation
* Correlation filtering
* Variance filtering
* Hyperparameter optimisation

The held-out outer test data must not influence model selection, feature selection or parameter tuning.

## Output Files

Depending on the selected scripts, the workflow may generate files such as:

```text
Processed_Data.csv
Matched_Samples.csv
Outer_Fold_Metrics.csv
Model_Performance_Comparison.csv
Outer_Heldout_Predictions.csv
Per_Sample_Averaged_Predictions.csv
Final_Model_Tuning_Results.csv
Top_Important_Features.csv
Top_Stable_Features.csv
Feature_Importance_All_Models.csv
```

Possible graphical outputs include:

```text
PCA_Plot.png
Model_Performance_Mean_SD.png
Outer_Fold_Performance_Boxplots.png
ROC_Curves_Top_Models.png
Confusion_Matrix_Best_Model.png
Top_Important_Features.png
Top_Stable_Features.png
Top_Features_Heatmap.png
```

The actual output filenames may be modified in the scripts.

## Software Requirements

The workflow is implemented in R.

Major packages may include:

```r
caret
tidyverse
glmnet
e1071
randomForest
ranger
naivebayes
nnet
gbm
pROC
ComplexHeatmap
circlize
ggplot2
doParallel
openxlsx
```

The required packages depend on the models and visualisations included in the final scripts.

## Running the Workflow

Clone the repository:

```bash
git clone https://github.com/KAVYASREERAGHUPATI/supervised-binary-classification.git
```

Move into the repository:

```bash
cd supervised-binary-classification
```

Open the repository in RStudio.

Place the scripts inside the `scripts` directory and execute them in numerical order.

Before running the code, modify:

* Input file paths
* Output directory
* Sample identifier column
* Class-label column
* Positive-class label
* Number of outer folds
* Number of repeats
* Inner cross-validation settings
* Number of selected features
* Model list
* Hyperparameter grids
* Number of parallel workers

## Reproducibility

To improve reproducibility, the scripts should include:

* A fixed random seed.
* Stratified cross-validation folds.
* Clearly defined class levels.
* Training-only feature selection.
* Training-only preprocessing.
* Held-out outer-fold evaluation.
* Saved tuning parameters.
* Saved held-out predictions.
* Recorded package versions.

The R environment can be documented using:

```r
sessionInfo()
```

## Important Notes

This repository provides reusable analysis code only.

It does not include:

* Raw datasets
* Processed datasets
* Personal or confidential files
* Study-specific results
* Large trained-model objects
* Temporary analysis files

Users must provide their own appropriately formatted dataset and update the paths and parameters before running the scripts.

The workflow may require further modification depending on:

* Sample size
* Number of predictors
* Class balance
* Type of input data
* Available memory
* Available processing power
* Selected machine learning models

## Citation

When using or adapting this workflow, please cite this GitHub repository using the citation information provided in the repository.


