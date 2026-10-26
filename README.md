# Stacked Machine Learning for Severe Maternal Morbidity at 24 Hours (MIMIC-IV)

Code, SQL and aggregate outputs for the manuscript **"Predicting Severe Maternal Morbidity at 24 Hours in Delivery Hospitalizations of MIMIC-IV: A Stacked Ensemble versus Logistic Regression, with a Feasibility Analysis of Maternal Death"**, under revision for *Healthcare* (MDPI).

Authors: Emmanuel Gutiérrez Jiménez and José Duván Márquez Díaz — Systems Engineering Department, Universidad del Norte, Barranquilla, Colombia.

> **No patient-level data are included in this repository.** MIMIC-IV requires credentialed access (see [Data access](#data-access)). The SQL files contain only schema definitions, cohort logic and code lists; the notebooks' outputs in `notebooks/revision/` are aggregate counts and metrics. No `subject_id`, `hadm_id` or `stay_id` values are published.

## Summary of the revised analysis

The revised analysis predicts **severe maternal morbidity (SMM)** in **delivery hospitalizations** of MIMIC-IV v3.1 (2008–2022; all dates are deidentified by patient-specific shifting), using only information available up to **24 hours after admission**. Maternal death is analysed only as a feasibility question, because there are too few events.

| | Revised analysis |
|---|---|
| Population | Delivery hospitalizations still in hospital 24 h after admission: 19,383 admissions (13,710 patients) |
| Outcome | SMM: at least one of the 20 active CDC indicators, ICD-9-CM or ICD-10-CM/PCS (445 events, 2.30%) |
| Predictors | Age, five administrative variables, hemoglobin and creatinine up to 24 h, creatinine missingness indicator |
| Models | Logistic regression, Random Forest, Extra Trees, XGBoost and a stacked ensemble with a logistic meta-learner |
| Validation | Patient-grouped nested cross-validation (5 outer × 3 inner folds, 3 repeats); recalibration inside the training patients; patient-level bootstrap |
| Main result | Ensemble AUROC 0.789 (95% CI 0.765–0.813), AUPRC 0.167 (prevalence 0.023); logistic regression 0.780 / 0.154; XGBoost 0.791 / 0.163 |
| Ensemble minus logistic regression | AUROC +0.009 (0.002–0.016); no difference from XGBoost |
| Maternal death | 3 deaths in the same admission among the eligible deliveries: not feasible to model |

Main findings:

- At 24 hours SMM can be ranked moderately well; the gain of stacking over a regularized logistic regression is small.
- The advantage of the ensemble depends on a creatinine missingness indicator: without it the AUROC falls by 0.085 for logistic regression and by 0.013 for the ensemble. Creatinine is present in 19.5% of admissions without SMM and in 62.9% of those with SMM, so missingness reflects who was tested.
- Calibration is reported for the whole procedure, recalibration included. In a temporal validation (earlier years to later years of the same hospital) discrimination holds (AUROC 0.76–0.81) but risks are underestimated as the SMM rate rises (observed/expected up to 2.12).
- Class weights and SMOTE-NC did not improve discrimination and required recalibration.
- The models are exploratory research prototypes. They are single-center, have no external validation and must not guide individual clinical decisions.

### What changed from the submitted version (v1)

The submitted version (Model A, 41 positives; Model B, 475 SMM admissions, AUC 0.904) is **superseded**. The revision follows reviewers' comments and an audit of the submitted data (counts in [`revision_audit_counts.md`](revision_audit_counts.md)):

- **Labels.** The SMM catalogue used ICD-10 codes only, so ICD-9-CM admissions (2008 to about 2015) were counted as negative. The revision uses the official CDC list in both ICD versions (848 SMM admissions in the obstetric universe, 447 in delivery hospitalizations). The mortality label is death in the same admission (10 deaths), not any later recorded death.
- **Delivery flag.** The ICD-10-only flag found 8,857 deliveries; the revised flag (diagnoses, procedures and DRG, both ICD versions) finds 19,425.
- **Prediction time.** Predictors are restricted to the window from 24 h before admission to 24 h after. Discharge-diagnosis indicators and ICU variables that exist only in the ICU are out of the main model.
- **Patient overlap.** The submitted split was by admission, and about 59% of test patients also appeared in training. The revision groups every split by patient.
- **Calibration and imbalance.** Recalibration is fitted inside the training patients; resampling is compared against no correction.

The executed notebooks of v1 (`notebooks/maternal_mortality_models.ipynb` and `notebooks/maternal_smm_models.ipynb`) and the original SQL under `sql/02_cohort_mortality/` and `sql/03_cohort_smm/` are kept unchanged (only header comments were updated) for traceability. Do not use their results or labels for new work.

## Repository structure

```
sql/
  01_load_mimic_iv_schema/   Rebuild the raw MIMIC-IV schema locally (see its README)
  02_cohort_mortality/       Obstetric universe of the submitted version, diagnosis-group mapping (v1)
  03_cohort_smm/             SMM catalogue and datasets of the submitted version (v1), lab item lookup
  04_cohort_perinatal/       Perinatal (fetal death) feasibility scripts; not part of the manuscript
  05_revision_audit/         Audit counts on the submitted labels (Q1-Q21)
  06_revision_labels/        Revised labels: official CDC code lists, delivery flag, same-admission labels,
                             cohort rule, death horizons, SMM-death overlap
  07_revision_predictors/    Predictors in the 24-hour window, final dictionary and missingness
notebooks/
  maternal_mortality_models.ipynb, maternal_smm_models.ipynb   Executed notebooks of the submitted version (v1)
  maternal_fetal_death_models.ipynb   Perinatal (fetal death) feasibility model; not a manuscript model
  revision/
    01_audit_patient_overlap.ipynb               Patient overlap in the submitted splits
    02_grouped_validation_smm.ipynb              Main analysis: grouped nested validation of the SMM models
    03_resampling_comparison_smm.ipynb           No correction vs class weights vs SMOTE-NC
    04_creatinine_indicator_sensitivity_smm.ipynb  With and without the creatinine missingness indicator
    05_era_temporal_validation_smm.ipynb         Calendar era, ICD version and temporal validation
    06_smm_renal_only_sensitivity.ipynb          Sensitivity without admissions whose only SMM indicator is acute renal failure
    07_smm_timing_vs_prediction_time.ipynb       Counts: timing of procedure-based SMM indicators relative to the 24-h prediction point
    outputs_*.txt                                Aggregate outputs of these notebooks (no patient-level data)
libraries/
  database.py                Connection (environment variables) and query functions
  functions.py               Small statistics helper
data/
  ethnicity_groups.xlsx, language_groups.xlsx, admission_location_groups.xlsx
                             Code -> group lookup tables (no patient-level data)
  Table_*.csv                Aggregate result tables of the submitted version
scripts/
  generate_maternal_diagnoses_group_sql.py   Generates the diagnosis-group SQL from the mapping
revision_audit_counts.md     Aggregate counts supporting the revision (Q1-Q25, Q-C to Q-I, decisions D1-D16)
docker-compose.yml           Local PostgreSQL + Jupyter environment
requirements.txt  .env.example  LICENSE
```

Files with an `_es.sql` suffix (and the Spanish-named scripts) are the original Spanish scripts kept as a paper trail; run the `_en.sql` versions.

The aggregate outputs `notebooks/revision/outputs_*.txt` (counts and metrics only; no identifiers or patient-level rows) are published with the code. Some of the earlier notebooks state in their header that these files are git-ignored; that note predates the decision to publish them. They are, one per analysis: `main` (main analysis), `no_indicator`, `resampling`, `era_temporal`, and the sensitivity analyses `first_admission`, `any_obstetric`, `icd10_only`, `label_ge2`, `no_icu_24h`, `labs_extended`, `icu_vars`, plus `modelA` (death feasibility).

## Installation and execution

1. **Get credentialed access to MIMIC-IV** (see [Data access](#data-access)) and download the CSV export. The manuscript uses **MIMIC-IV v3.1** (downloaded on 18 April 2025).
2. **Load the schema locally** following `sql/01_load_mimic_iv_schema/README.md`. `docker-compose.yml` starts PostgreSQL 13 and Jupyter; edit the `volumes:` path of `db_mimiciv` to your own data directory and run only one container per data directory.
3. **Build the tables** by running the SQL scripts in this order (the header of each script lists its prerequisites; the revision scripts create new `*_v2` objects and do not modify the originals):
   1. `sql/02_cohort_mortality/` and `sql/03_cohort_smm/` — obstetric universe and the objects the revision builds on.
   2. `sql/06_revision_labels/` in numeric order (`01` to `06`, including `03b`).
   3. `sql/07_revision_predictors/` in numeric order (`01`, `02`).
   4. `sql/05_revision_audit/` is optional: it reproduces the audit on the submitted labels.
4. **Set your credentials:** copy `.env.example` to `.env` in the project root and fill in your local database password. Check that the file is named `.env` (not `.env.txt`). `.env` is git-ignored and must never be committed.
5. **Create an environment and install dependencies:**
   ```powershell
   cd MaternalMortality_MIMIC-IV
   python -m venv .venv
   .venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
   pip install -r requirements.txt
   ```
   Select this interpreter as the Jupyter kernel.
6. **Run the revision notebooks** in `notebooks/revision/` top to bottom (Restart & Run All), starting with `02_grouped_validation_smm.ipynb` (main analysis); `03` to `06` use the same partitions and settings (`07` only counts events and trains no model). The nested validation with bootstrap is computationally heavy.

Notebooks print aggregate results only. Files written into `data/` (for example `df_*_dataset.xlsx`) are derived, patient-level-adjacent artifacts and are excluded by `.gitignore`. Do not commit them.

## Methodological notes

- Prediction time is 24 hours after admission, and only admissions still in hospital at that time enter the main analysis (events before 24 h are reported separately). The SMM label, however, is an admission-level classification from ICD codes, which carry no date for diagnoses and only a calendar date for procedures: the model classifies SMM at 24 h; it does not predict its onset. Notebook 07 quantifies the timing of the procedure-based indicators (59 of the 445 eligible SMM admissions, 13.3%, have one certainly before the prediction time; 319, 71.7%, rest on diagnosis codes alone).
- All splits are grouped by patient, so no patient appears on both sides. Imputation, scaling, hyperparameter tuning, stacking and recalibration are fitted inside the training part of each fold.
- The SMM label is an administrative proxy and has not been validated against chart review in MIMIC-IV. The rate rises with calendar period and is aligned with the change from ICD-9-CM to ICD-10-CM/PCS, so the effect of coding and period cannot be separated.
- Single-center data and no external validation. The temporal validation uses later patients of the same hospital.
- Reporting follows TRIPOD+AI. The completed checklist is provided with the article, not in this repository; the code lists (Appendix D, Tables A4–A6) and the predictor availability tables (Appendix E, Tables A7–A8) are appendices of the article.

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
