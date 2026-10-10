# Stacked Machine Learning for In-Hospital Maternal Mortality and Severe Maternal Morbidity (MIMIC-IV)

Code, SQL and figures for the manuscript **"Predicting In-Hospital Maternal Mortality and Severe Maternal Morbidity in MIMIC-IV with a Stacked Machine Learning Ensemble under Extreme Class Imbalance"**, prepared for submission to *Healthcare* (MDPI).

Authors: Emmanuel Gutiérrez Jiménez and José Duván Márquez Díaz — Systems Engineering Department, Universidad del Norte, Barranquilla, Colombia.

> **No patient-level data are included in this repository.** MIMIC-IV requires credentialed access (see [Data access](#data-access)). The SQL files contain only schema definitions, cohort logic and an ICD-code-to-group mapping; no `subject_id`, `hadm_id` or `stay_id` values are published.

## Summary

Two prediction tasks are built on the same cohort of **25,736 obstetric hospital admissions** (women aged 12–55; observed range 18–55) from MIMIC-IV v3.1 (patients admitted between 2008 and 2022; all dates are deidentified by patient-specific shifting):

| | Model A — maternal mortality | Model B — severe maternal morbidity (SMM) |
|---|---|---|
| Outcome | In-hospital death recorded in the index or a later admission | At least one of the 20 active CDC/HRSA FAD-2023 SMM indicators |
| Events | 41 (0.159%) | 475 (1.846%) |
| Predictors | 89 (including 26 expert-grouped diagnosis indicators, `gdg_m01`–`gdg_m26`) | 65 (diagnosis-group indicators excluded to avoid outcome leakage) |
| Stacked ensemble, 5-fold CV | AUC 0.857 ± 0.069; AP 0.156 ± 0.096 | AUC 0.904 ± 0.020; AP 0.419 ± 0.050 |
| Stacked ensemble, hold-out (20%) | 8 deaths in the test set; AUC 0.844, AP 0.148 (not reliable) | AUC 0.913; AP 0.384 |

Main findings:

- With 41 events, mortality is too rare to model reliably in single-center data; results for Model A are exploratory.
- SMM gives a much more stable task. Flagging the top 5% of admissions by predicted probability captured 68% of SMM cases (positive predictive value 0.25).
- Raw predicted probabilities are **not calibrated** (class weighting and tree ensembles). Post hoc Platt scaling corrects them for Model B (Brier skill score from −4.10 to 0.26) but gives little gain for Model A (skill 0.06); use the raw scores to rank admissions, and absolute risks only after recalibration and external validation.
- SMOTE did not improve precision-based metrics; IQR×3 winsorization (instead of row deletion) preserved all positive cases.
- The models are research prototypes and must not guide individual clinical decisions.

### Pipeline

1. Cohort and feature extraction in PostgreSQL (MIMIC-IV loaded locally).
2. Cleaning of sentinel values and implausible zeros; IQR×3 winsorization; skewness-driven imputation; differential scaling (RobustScaler / MinMaxScaler).
3. Random Forest, XGBoost, Extra Trees and Logistic Regression tuned by grid search on average precision, combined by a class-weighted L2 logistic-regression meta-learner (stacking).
4. Stratified 80/20 split (seed 42) and stratified 5-fold cross-validation; SMOTE sensitivity analysis inside the folds.
5. Additional analyses: calibration and risk bands, SHAP, subgroup audit, Model A without diagnosis groups, and recalibration (Platt / isotonic).

## Repository structure

```
sql/
  01_load_mimic_iv_schema/   Rebuild the raw MIMIC-IV schema locally (see its README)
  02_cohort_mortality/       Model A cohort, diagnosis-group mapping and catalogue
  03_cohort_smm/             Model B cohort, SMM indicators, feature dataset, lab item lookup
libraries/
  database.py                Connection (environment variables) and query functions
  functions.py               Small statistics helper
notebooks/
  maternal_mortality_models.ipynb   Model A — full pipeline
  maternal_smm_models.ipynb         Model B — full pipeline
  Recalibration_cell.py             Platt / isotonic recalibration cell (run after the calibration section)
  Fig_*.png / Fig_*.pdf, Table_*.csv  Figures and aggregate tables produced by the notebooks
data/
  ethnicity_groups.xlsx, language_groups.xlsx, admission_location_groups.xlsx
                             Code -> group lookup tables (no patient-level data)
scripts/
  generate_maternal_diagnoses_group_sql.py   Generates the diagnosis-group SQL from the mapping
docs/                        Working notes and methodological documents
article/                     Manuscript sources (LaTeX) and TRIPOD+AI checklist
docker-compose.yml           Local PostgreSQL + Jupyter environment
requirements.txt  .env.example  LICENSE
```

Files with an `_es.sql` suffix are the original Spanish scripts kept as a paper trail; run the `_en.sql` versions (see `docs/NAMING.md`).

## Installation and execution

1. **Get credentialed access to MIMIC-IV** (see [Data access](#data-access)) and download the CSV export. The manuscript uses **MIMIC-IV v3.1** (downloaded on 18 April 2025).
2. **Load the schema locally** following `sql/01_load_mimic_iv_schema/README.md`. `docker-compose.yml` starts PostgreSQL 13 and Jupyter; edit the `volumes:` path of `db_mimiciv` to your own data directory and run only one container per data directory.
3. **Build the cohorts and feature tables** by running the SQL scripts in `sql/02_cohort_mortality/` (Model A) and `sql/03_cohort_smm/` (Model B), as indicated at the start of each notebook.
4. **Set your credentials:** copy `.env.example` to `.env` in the project root and fill in your local database password. Check that the file is named `.env` (not `.env.txt`). `.env` is git-ignored and must never be committed.
5. **Create an environment and install dependencies:**
   ```powershell
   cd maternal-smm-mimicIV
   python -m venv .venv
   .venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
   pip install -r requirements.txt
   ```
   Select this interpreter as the Jupyter kernel.
6. **Run the notebooks** top to bottom (Restart & Run All), one model at a time: `maternal_mortality_models.ipynb` (Model A) and `maternal_smm_models.ipynb` (Model B). The SHAP cells are CPU- and memory-intensive; run them only when needed.
7. **Recalibration:** paste `notebooks/Recalibration_cell.py` into a new cell after the calibration section (it needs `y`, `y_oof` and `LABEL`). It saves `Table_Recalibration_<label>.csv` and `Fig_Recalibration_<label>.pdf/png`.

Files written by the notebooks into `data/` (for example `df_*_dataset.xlsx`) are derived, patient-level-adjacent artifacts and are excluded by `.gitignore`. Do not commit them.

## Methodological notes

- Train/test split and cross-validation are made **by admission**; they are not grouped by patient.
- Imputation values and scalers were fitted before the train/test split, and cross-validation re-fits hyperparameters tuned on the training split, so estimates may be slightly optimistic.
- The SMM label is ICD-based and an administrative proxy; the timing of predictors relative to the event was not enforced.
- Single-center data and no external validation.
- Reporting follows TRIPOD+AI; the completed checklist is in `article/TRIPOD_AI_checklist.docx`.

## Data access

This repository does **not** include any patient-level data. All analyses use the **MIMIC-IV** database, available through [PhysioNet](https://physionet.org/content/mimiciv/) under credentialed access. To reproduce this work you must:

1. Complete the CITI "Data or Specimens Only Research" training course.
2. Sign the PhysioNet Credentialed Health Data Use Agreement.
3. Request and be granted access to MIMIC-IV, and download your own copy.

Reference: Johnson, A.E.W. et al. *MIMIC-IV, a freely accessible electronic health record dataset.* Scientific Data **2023**, 10, 1. https://doi.org/10.1038/s41597-022-01899-x

## Citation

If you use this code, please cite the manuscript. The full reference (journal, volume, DOI) will be added after publication.

## License

The code is released under the MIT License (see `LICENSE`).

## Contact

Emmanuel Gutiérrez Jiménez — emmanuelg@uninorte.edu.co
