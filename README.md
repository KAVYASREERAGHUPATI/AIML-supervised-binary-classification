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

## Validation strategy used:

        Repeated nested stratified cross-validation:
        Outer loop: Stratified K-fold cross-validation repeated several times for unbiased testing.
        Inner loop: Repeated stratified K-fold cross-validation for feature selection and hyperparameter tuning.
         Purpose: To reduce information leakage and obtain a more reliable estimate of model performance.
The default script uses 5 outer folds repeated 10 times. These values can be changed in the user-settings section.

## NOTE:  
For most binary classification datasets, "stratified K-fold cross-validation" is preferred because it maintains the class distribution within each fold. When feature selection, preprocessing and hyperparameter tuning are performed, nested "stratified cross-validation" is more appropriate because it separates model optimization from final performance evaluation. For very small datasets, "LOOCV" may be considered, although repeated stratified K-fold cross-validation often provides a more stable estimate.


## Models included:

Logistic Regression
Elastic Net
Linear Support Vector Machine
Radial Support Vector Machine
Random Forest
Ranger
Naive Bayes
K-Nearest Neighbours
Decision Tree
Neural Network
Gradient Boosting

## Repository structure

supervised-binary-classification/
├── README.md
├── .gitignore
├── scripts/
│   ├── 01_main_binary_classification.R
│   └── plots/
│       ├── 01_model_performance_barplot.R
│       ├── 02_outer_fold_boxplots.R
│       ├── 03_roc_curves_top6.R
│       ├── 04_confusion_matrix_best_model.R
│       ├── 05_confusion_matrices_all_models.R
│       ├── 06_top30_feature_importance.R
│       ├── 07_top30_selection_stability.R
│       └── 08_top100_feature_heatmap.R
└── results/

## Input files (use DESeq2 normalised counts file)

1. Predictor matrix
The input CSV may have either:
samples as rows and predictors as columns, or
predictors as rows and samples as columns.
Set EXPRESSION_ORIENTATION in the main script.

Example with samples as rows:
          sample,Feature_1,Feature_2,Feature_3
          Sample_01,8.45,7.92,9.01
           Sample_02,5.62,6.18,5.97

2. Trait or metadata file

The metadata file must contain a sample column and a condition column.
           sample,condition
           Sample_01,control
           Sample_02,drought

Although the example uses control and drought, the labels can be changed for any binary-classification problem.

## How to run

Open scripts/01_main_binary_classification.R.
Edit the file paths, column names, class labels and validation settings.
Run the complete main script.
After the CSV and RDS outputs are created, run the scripts inside scripts/plots/.
All figures will be saved inside results/figures/.
Main analysis outputs

## Output files:

Matched_Samples_Used_For_ML.csv
Samples_Only_In_Expression_File.csv
Samples_Only_In_Trait_File.csv
Outer_Fold_Metrics.csv
Nested_CV_Model_Comparison.csv
All_Outer_Heldout_Predictions.csv
Per_Sample_Averaged_Heldout_Predictions.csv
Top100_Stable_Selected_Features.csv
Top100_Important_Features_Final_Model.csv
Top100_Important_Features_All_Models.csv
model-specific top-100 feature files
Final_Model_Tuning_Results.csv
Top6_Models_ROC_AUC.csv
Analysis_Objects.rds
Session_Info.txt
Figure outputs
The plotting scripts generate:
Model_Performance_Mean_SD.png
Outer_Fold_Performance_Boxplots.png
ROC_Curves_Top6_Models_Color.png
ROC_Curves_Top6_Models_Color.pdf
Confusion_Matrix_Best_Model.png
separate confusion matrices for all models.png
Top30_Important_Features.png
Top30_Feature_Selection_Stability.png
Top100_Features_Heatmap.png


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









