# Analysis plan from scratch, according to the revision notebooks

> **Aggregate counts and metrics only.** This document contains no patient-level data or identifiers. Everything comes from MIMIC-IV v3.1 (PhysioNet, use subject to the data use agreement) and from the notebooks in `notebooks/` and their `data/outputs_*.txt` reports.

How the analysis of the article on severe maternal morbidity (SMM) at 24 hours would be built from scratch, organized by analytical phase and explained only with what notebooks 01 to 07 do: define the cohort, clean the data and handle missing values, validate, measure, obtain results and check their robustness. It does not include the SQL work or the manuscript work. It is not part of the manuscript: its purpose is to make clear when each technique was applied and what its function is.

The Spanish version is [`analysis_plan_notebooks_es.md`](analysis_plan_notebooks_es.md).

## How to read this document

The plan has 10 phases, 53 steps and 135 analyses or results with detail. Each step states:

- **Notebook:** which notebook it comes from (for example, NB 02).
- **Techniques:** the labels of the technique index (at the end).
- **Where:** notebook and section (§) or function where the code is.
- **Output:** the `data/outputs_*.txt` file with the figures; numbers in brackets are sections of the report.
- **References:** plan task (T), decision (D) or reviewer comment (R1 to R3), only when the notebook cites them.

| Phase | Name | Notebooks | Steps |
|---|---|---|---:|
| [P0](#p0-common-rules-and-configuration) | Common rules and configuration | Notebooks 02 to 06, section 1 | 2 |
| [P1](#p1-cohort-definition-and-count-audit) | Cohort definition and count audit | Notebooks 01, 02, 05, 06 and 07 | 6 |
| [P2](#p2-data-cleaning-missing-data-and-winsorization) | Data cleaning, missing data and winsorization | Notebooks 02 to 06, sections 2 and 4 | 7 |
| [P3](#p3-partition-models-and-tuning) | Partition, models and tuning | Notebook 02, sections 3 to 5 (repeated in 03 to 06) | 7 |
| [P4](#p4-metrics-uncertainty-and-sample-size) | Metrics, uncertainty and sample size | Notebook 02, sections 5 and 6 and Riley cells | 7 |
| [P5](#p5-results-of-the-main-analysis) | Results of the main analysis | `outputs_main.txt` and `outputs_modelA.txt` | 7 |
| [P6](#p6-sensitivity-analyses) | Sensitivity analyses | Notebooks 02 (section 10), 04 and 06 | 5 |
| [P7](#p7-class-imbalance-no-correction-weights-and-smote-nc) | Class imbalance: no correction, weights and SMOTE-NC | Notebook 03 | 4 |
| [P8](#p8-era-coding-version-and-temporal-validation) | Era, coding version and temporal validation | Notebook 05 | 5 |
| [P9](#p9-timing-of-events-relative-to-the-prediction-point) | Timing of events relative to the prediction point | Notebook 07 | 3 |

## P0. Common rules and configuration

**Where:** Notebooks 02 to 06, section 1.

**Goal.** Fix, before running anything, what makes all analyses comparable: seed, folds, repeats, bootstrap and data-use rules.

### 0.1 Fixed parameters of the experiment

*A single configuration that the six modeling notebooks repeat identically.*

**Notebook:** NB 02 to 06  
**Techniques:** Models, tuning and stacking, Metrics and uncertainty  
**Where:** §1 of each notebook

**What was done.** Every notebook opens with the same block of settings. They are the contract of the analysis: changing them changes all results, so they are not touched between notebooks.

**What it is for.** So that differences between analyses are due only to what was deliberately changed (population, outcome, predictors) and never to the seed, the number of repeats or the size of the forests.

Detail:

- **SEED.** 20260101. The outer partitions (seed + repeat number) and the remaining random seeds derive from it. *What for:* Exact reproducibility of every partition.
- **Folds.** 5 outer folds × 3 repeats (15 outer fits per model) and 3 inner folds to choose hyperparameters. *What for:* Also measure how much development varies across repeats, not only across folds.
- **Bootstrap.** B = 1000 in the main analysis and in the paired comparisons of notebooks 04 and 05 (with and without indicator, era refits); B = 300 in the other sensitivity analyses, in the strategy comparison of notebook 03 and in the by-group and temporal analyses of notebook 05. *What for:* 95% intervals from the 2.5th and 97.5th percentiles.
- **Trees.** 300 trees in RF and ET; 200 in XGBoost. *What for:* Fixed size so that no result depends on a different number of trees.
- **Limits.** APPLY_LIMITS = True: values outside the dictionary's plausibility limits become missing. *What for:* See phase P2.
- **Categorical.** Five: ethnicity, insurance, language, admission type and admission location (ethnicity, insurance, language, `admission_type`, `admission_location`). *What for:* Administrative predictors available at admission.
- **Thresholds.** Eight thresholds for the decision curve: 0.5%, 1%, 2%, 3%, 5%, 10%, 15% and 20%. *What for:* Cover everything from very sensitive screening to selective alerting.
- **EXPECTED.** Certified counts that every notebook compares on loading: 19,383 eligible deliveries, 445 SMM and 3 deaths. *What for:* Stop if the population is not the audited one. See 1.2.

### 0.2 Data-use rules and test mode (QUICK)

*Only aggregates are printed; the only file written is a text report with counts and metrics.*

**Notebook:** NB 01 to 07  
**Techniques:** Count audit  
**Where:** First cell of each notebook  
**Output:** `data/outputs_*.txt`  
**References:** DUA, T43

**What was done.** Each notebook declares its rules in the first cell. No notebook shows, exports or saves rows, identifiers or dates. The notebooks are in `notebooks/` (01 to 07). Notebook 01 writes nothing to disk and 07 only runs read queries. The `data/outputs_*.txt` reports contain aggregate counts and metrics only and are tracked in the repository; the notebooks never write identifiers or rows.

**What it is for.** Comply with the MIMIC-IV data use agreement and be able to publish the code without risk.

Detail:

- **QUICK.** With QUICK = True the notebook runs a smoke test: 3 folds × 1 repeat, B = 50 (30 in sensitivity analyses) and forests of 60 and 50 trees. A figure from that mode is never reported. *What for:* Catch errors in minutes before the long run.
- **One file.** Each analysis writes a single file named `outputs_<analysis>.txt`. *What for:* One deliverable per analysis that can be pasted or cited without exposing data.

## P1. Cohort definition and count audit

**Where:** Notebooks 01, 02, 05, 06 and 07.

**Goal.** Make clear who enters each analysis and check with counts that each population, event and partition is what the text says.

### 1.1 Rebuild the submitted analysis and measure patient overlap

*How many patients were in both training and test in the submitted version.*

**Notebook:** NB 01  
**Techniques:** Count audit, Patient-level partition  
**Where:** 01 · §2 to §7  
**Output:** Screen only (last cell)  
**References:** T43, R1-4, R2-2

**What was done.** The notebook reads only `subject_id`, `hadm_id` and the submitted label of the two original tables (Model A, mortality, and Model B, SMM). It reproduces the partitions as they were made and counts the overlap. It does not change any model, label or database.

**What it is for.** It is the evidence for the patient-level leakage comments. Quantifying it justifies moving to the grouped validation of phase P3.

Detail:

- **§2 Load.** Three columns are read. The expected positives are verified: 41 in Model A and 475 in Model B. *What for:* Confirm that the work starts from the submitted labels.
- **§3 Replication.** The ordering by `subject_id`, the stratified 80/20 hold-out with seed 42 and the 5-fold cross-validation with seed 42 are repeated. Sizes and events are compared with what was submitted (Model B: 20,588 in training with 380 events and 5,148 in test with 95). *What for:* Prove that the replication matches in sizes and events before interpreting anything.
- **§4 Patients.** Admissions per patient: percentage with more than one, median, maximum, positives per patient with an event. *What for:* Show that patients repeat admissions and why grouping matters.
- **§5 and §6.1.** Overlap in the hold-out: test patients who are also in training, test admissions whose patient is in training, positives whose patient has an admission (or a positive one) in training. Result: 59.3% of Model A test patients and 58.3% of Model B test patients. *What for:* Figure that goes into the response letter.
- **§6.2.** The same in each fold of the submitted cross-validation. For mortality, 23 of 41 events had their patient in other folds, and one patient contributed up to 6 positives. *What for:* Show that the problem was not limited to the hold-out.
- **§6.3.** Order-independent simulation: 1,000 hold-out partitions (seeds 0 to 999) and 200 repeats of 5 folds, with median and 2.5th to 97.5th percentiles. Median of test admissions whose patient is in training: 60.1%. *What for:* So that the result does not depend on the physical row order or on a seed.
- **§7 Summary.** A short block with the figures for the letter, with no identifiers. *What for:* Paste only that output.

### 1.2 Load the predictor table and verify the expected counts

*Every notebook checks on loading that the population is the audited one.*

**Notebook:** NB 02 to 06  
**Techniques:** Count audit, Cohort definition  
**Where:** 02 · §2; 03 to 06 · §2

**What was done.** `predictors_24h_v2` is read (one row per obstetric hospitalization, with the predictors observed in the window from 24 hours before to 24 hours after admission) together with `predictor_dictionary_final_v2` (role of each variable and plausibility limits). Null logical indicators are treated as false. An assertion prints OK or CHECK against the expected counts.

**What it is for.** A wrong population would give results that look valid. With this check all analyses start from the same cohort certified by the count audit.

Detail:

- **Eligible deliveries.** 19,383 delivery hospitalizations eligible at 24 hours, from 13,710 patients. *What for:* Denominator of the main analysis.
- **SMM.** 445 with severe maternal morbidity (2.30%). *What for:* Events of the main analysis.
- **Deaths.** 3 deaths in the same admission among eligible deliveries. *What for:* Too few to model: see 5.7.
- **Any obstetric.** 23,625 eligible admissions from 14,602 patients, with 814 SMM and 5 deaths. *What for:* Population of the `any_obstetric` sensitivity analysis.

### 1.3 Define the population of each analysis

*One function, `make_spec`, decides who enters each variant and which predictors it uses.*

**Notebook:** NB 02 to 06  
**Techniques:** Cohort definition, Sensitivity  
**Where:** 02 · §3 `make_spec`; 04 to 06 · §3  
**References:** D4, T50

**What was done.** Each analysis is a specification (population, predictors, outcome). It always starts from the admissions eligible at 24 hours. Constant columns are dropped, because an indicator that never varies carries no information. Columns missing from the table are also dropped.

**What it is for.** So that each variant changes one thing only and it is written down which. The results of each are in phase P6.

Detail:

- **main.** Eligible deliveries. 19,383 admissions, 13,710 patients, 445 events (2.30%). *What for:* Main analysis.
- **first_admission.** Only the first delivery hospitalization of each patient, if eligible. 13,701 admissions, 13,701 patients, 356 events (2.60%). *What for:* Remove the effect of repeated admissions.
- **any_obstetric.** Eligible obstetric admissions, with or without delivery. 23,625 admissions, 14,602 patients, 814 events (3.45%). *What for:* See whether the conclusion depends on restricting to deliveries.
- **no_icu_24h.** Eligible deliveries without ICU admission in the first 24 hours. 19,268 admissions, 13,632 patients, 355 events (1.84%). *What for:* Remove patients who are already critical at the prediction point.
- **icd10_only.** Deliveries whose diagnoses are all ICD-10-CM, with no ICD-9-CM at all (decision D4). 8,864 admissions, 7,070 patients, 271 events (3.06%). *What for:* Remove the change in coding version.
- **label_ge2.** Same population and predictors; the outcome becomes two or more SMM indicators. 129 events (0.67%). *What for:* A stricter outcome.
- **excl_renal_only.** Eligible deliveries minus those whose only indicator is acute renal failure. 19,233 admissions, 13,610 patients, 295 events (1.53%). They are removed from the population; they are not relabeled as non-events. *What for:* Do not treat real morbidity as health.
- **labs_extended and icu_vars.** Same population as main with more predictors (laboratory and ICU, each with its missingness indicator). *What for:* See whether more variables improve prediction.

### 1.4 Ineligible deliveries and deaths before the prediction point

*Two consistency checks against counts that were already certified.*

**Notebook:** NB 07  
**Techniques:** Count audit, Timing, Cohort definition  
**Where:** 07 · §3  
**Output:** `outputs_smm_timing.txt`  
**References:** T52, R3-2, R3-3

**What was done.** Read-only queries on `predictors_24h_v2` and admissions. The first counts deliveries that ended before 24 hours and are therefore not eligible. The second classifies the in-hospital deaths of the obstetric universe according to whether they occurred before T (admission + 24 hours) or from T onward.

**What it is for.** Explain why 19,425 deliveries become 19,383 eligible ones and why some deaths fall outside the analysis. Both figures go into the manuscript.

Detail:

- **Ineligible.** 42 deliveries ended before 24 hours: 2 with SMM and 1 with death. *What for:* It adds up: 19,425 − 42 = 19,383, 447 − 2 = 445 and 4 − 1 = 3.
- **Deaths.** 10 in-hospital deaths in the obstetric universe: 5 before T (1 in a delivery and 4 in another obstetric admission) and 5 from T onward (3 in a delivery and 2 in another). *What for:* Show that half of the deaths occurred before the model could predict them.

### 1.5 SMM by number of indicators and by ICD version

*How many of the 445 SMM admissions rest only on acute renal failure.*

**Notebook:** NB 06  
**Techniques:** Count audit, Cohort definition, Sensitivity  
**Where:** 06 · §3b  
**Output:** `outputs_excl_renal_only.txt`  
**References:** T50, R2-14, R2-15, R1-9

**What was done.** Eligible admissions are joined with `cohort_obstetric_v2` (`smm_only_renal`, `smm_n_indicators`, `has_icd9_dx`, `has_icd10_dx`). A table is printed for each population (all, ICD-9 only, ICD-10 only) with admissions, SMM, SMM with renal failure as the only indicator, SMM left after excluding them and the percentage, plus the distribution of the number of indicators (1, 2, 3, 4 or more). Two assertions check that the population and the events of the analysis subtract exactly those admissions.

**What it is for.** Acute renal failure is the most frequent indicator and the only one in about a third of SMM cases (150 of 445, 33.7%), and creatinine is a main predictor. It had to be quantified before the sensitivity analysis of P6.

### 1.6 Prevalence by period and ICD version

*How the frequency of SMM changes with time and with coding version.*

**Notebook:** NB 05  
**Techniques:** Count audit, Era and temporal validation, Cohort definition  
**Where:** 05 · §2; 05 · cell 7.4  
**Output:** `outputs_era_temporal.txt`  
**References:** T47, R1-3, R2-6, R2-17

**What was done.** `anchor_year_group` (patients table) and the ICD version of each admission (ICD-9 only, ICD-10 only, mixed) are joined. Admissions, patients, events and prevalence are printed by group, together with the cross-table of admissions by group and version. It checks that no group is missing or outside the expected order.

**What it is for.** Before asking whether the model learns the period, it must be clear that prevalence rises with it. It is the reason for phase P8.

Detail:

- **2008–2010.** 8,212 admissions, 5,536 patients, 121 events (1.47%).
- **2011–2013.** 4,328 admissions, 2,977 patients, 86 events (1.99%).
- **2014–2016.** 3,569 admissions, 2,507 patients, 104 events (2.91%).
- **2017–2019.** 2,343 admissions, 1,813 patients, 81 events (3.46%).
- **2020–2022.** 931 admissions, 877 patients, 53 events (5.69%).
- **ICD-9 / ICD-10.** ICD-9 only: 10,519 admissions, 174 events (1.65%). ICD-10 only: 8,864 admissions, 271 events (3.06%). The October 2015 change falls within 2014–2016, which has 2,552 ICD-10 admissions and 1,017 ICD-9 admissions. *What for:* Period and coding version are partly confounded.

## P2. Data cleaning, missing data and winsorization

**Where:** Notebooks 02 to 06, sections 2 and 4.

**Goal.** Turn the variables into a matrix without impossible values and with missing data handled, so that nothing learned from a test patient touches the training data.

### 2.1 Roles of the variables in the dictionary

*The dictionary says which variable goes into the main model and which only into a sensitivity analysis.*

**Notebook:** NB 02 to 06  
**Techniques:** Missing data and indicators, Cohort definition  
**Where:** 02 · §2

**What was done.** `predictor_dictionary_final_v2` assigns each variable a role: main model, ICU-only sensitivity or laboratory sensitivity. It also flags for which variables the main model carries a missingness indicator and gives their plausibility limits.

**What it is for.** So that the predictors of the main model are fixed before seeing results and the sensitivity analyses only add declared variables.

Detail:

- **Main model.** Three numeric variables (age at admission, hemoglobin and creatinine), one creatinine missingness indicator and five administrative categorical variables. *What for:* It is the model that is reported.
- **ICU only.** ICU variables, only in the `icu_vars` sensitivity analysis, plus the `icu_in_24h` flag.
- **Laboratory.** Hematocrit and other laboratory variables, only in `labs_extended`.

### 2.2 Plausibility limits: the impossible becomes missing

*A value outside the physiological range is treated as not measured, not as a real extreme value.*

**Notebook:** NB 02 to 06  
**Techniques:** Cleaning and winsorization, Missing data and indicators  
**Where:** 02 · §2; 05 · §2  
**References:** D16

**What was done.** For each variable with lower and upper limits in the dictionary, values outside that interval are replaced by missing. The number of values changed per variable is printed. The APPLY_LIMITS switch allows the step to be turned off. In the code, the limits appear as proposals pending clinical confirmation.

**What it is for.** Prevent a data-entry error from dragging into winsorization and imputation. It is done before the missingness indicators are computed.

### 2.3 Missingness indicators, row by row

*A 0/1 column per variable saying whether the value is absent.*

**Notebook:** NB 02 to 06  
**Techniques:** Missing data and indicators  
**Where:** 02 · §2; 06 · §2  
**References:** R2-7, R2-20

**What was done.** For the main-model variables (creatinine only), and in the sensitivity analyses also for the laboratory and ICU variables, the column `<variable>_missing` is created as 1 if the value is absent. It is computed after the plausibility limits, so an out-of-range value is also flagged. It is computed row by row from the value of that same row, so it does not carry information across patients. `icu_in_24h_bin` is also created. In `make_spec`, indicators that do not vary are dropped.

**What it is for.** In MIMIC-IV creatinine is measured in those suspected of being ill; its absence is information. The indicator captures it explicitly and allows measuring how much it weighs (see 6.4).

### 2.4 Winsorization within the training data

*Clip each numeric variable to the 0.5th and 99.5th percentiles computed with the training data only.*

**Notebook:** NB 02 to 06  
**Techniques:** Cleaning and winsorization  
**Where:** 02 · §4 Winsor class

**What was done.** The Winsor class is the first step of the numeric block of the pipeline. At fit time it computes the 0.5th and 99.5th percentiles of each column (ignoring missing values) and at transform time it clips the values outside them. The percentiles are learned from the training data of each fit and applied identically to the test data. It acts only on numeric variables: indicators and categorical variables pass through unchanged.

**What it is for.** Limit the influence of real extreme values without looking at the test data. If the percentiles were computed with all data, test information would leak into training.

### 2.5 Imputation, scaling and encoding inside the pipeline

*Everything that learns from the data is refit on every training set.*

**Notebook:** NB 02 to 06  
**Techniques:** Missing data and indicators, Models, tuning and stacking  
**Where:** 02 · §4 `make_prep`

**What was done.** A ColumnTransformer with three branches. Numeric: Winsor, median imputation (keeps entirely empty columns) and standardization. Indicators: pass through unchanged. Categorical: missing values are filled with the «missing» category and encoded as 0/1 columns, grouping categories with less than 1% into an «infrequent» category; a new category in the test data falls into that same one.

**What it is for.** Imputing with the training median (never the test one) avoids leakage. The «missing» category preserves the fact that it was not recorded.

Detail:

- **Parameters.** The main model ends up with 32 candidate parameters: 3 numeric, 1 indicator and 28 0/1 columns from the five categorical variables. *What for:* It is the P used by the sample-size criterion (see 4.7).

### 2.6 What information the creatinine indicator encodes

*The availability of creatinine closely follows severity and ICU admission.*

**Notebook:** NB 04  
**Techniques:** Missing data and indicators, Count audit  
**Where:** 04 · §8 [4]  
**Output:** `outputs_no_indicator.txt`  
**References:** R2-7, R2-20

**What was done.** The proportion with creatinine present among eligible deliveries is printed, by outcome and by ICU admission in the first 24 hours.

**What it is for.** Show that the indicator says who was tested, not only which value they had. It is the basis of the sensitivity analysis with and without the indicator.

Detail:

- **By outcome.** Creatinine present in 20.5% overall, 19.5% of those without SMM and 62.9% of those with SMM. *What for:* Quantifies how much information is carried by the fact of measuring it.
- **By ICU.** Present in 96.5% with ICU admission within 24 hours and in 20.0% without. *What for:* Measurement is tied to the level of care.

### 2.7 Predictor set of each variant

*How many numeric, binary and categorical variables each analysis uses.*

**Notebook:** NB 02 to 05  
**Techniques:** Missing data and indicators, Sensitivity  
**Where:** 02 · §3; 04 · §3; 05 · §3

**What was done.** The header of each report prints the count of numeric, binary and categorical variables of its analysis.

**What it is for.** Verify at a glance that each variant changed what was planned and nothing else.

Detail:

- **main.** 3 numeric, 1 binary and 5 categorical.
- **labs_extended.** 14 numeric, 12 binary and 5 categorical. *What for:* More laboratory tests, each with its indicator.
- **icu_vars.** 17 numeric, 16 binary and 5 categorical. *What for:* More ICU variables, with their indicators and the ICU flag.
- **main_noind.** 3 numeric, 0 binary and 5 categorical. *What for:* Without the creatinine indicator.
- **main_noadmin.** 3 numeric, 1 binary and no categorical. *What for:* Without the five administrative variables.
- **main_plus_era.** 3 numeric, 1 binary and 6 categorical. *What for:* Adds the year group as a diagnostic.

## P3. Partition, models and tuning

**Where:** Notebook 02, sections 3 to 5 (repeated in 03 to 06).

**Goal.** Design the validation so that no patient ends up on both sides and everything that is learned, including calibration, is learned with the training data only.

### 3.1 Outer partition grouped by patient, 5 × 3

*Each patient appears in a single fold per repeat.*

**Notebook:** NB 02  
**Techniques:** Patient-level partition, Count audit  
**Where:** 02 · `run_cv`  
**Output:** `outputs_main.txt` [0]  
**References:** T43, R1-4, R2-2

**What was done.** StratifiedGroupKFold with `subject_id` as the group, 5 folds, seed = SEED + repeat, 3 repeats. An assertion checks that no patient is in training and test at the same time. The log of each partition is printed: admissions, patients and events in training and test, and shared patients. The projected time after the first fold is also printed.

**What it is for.** It fixes the leakage measured in 1.1. Stratifying by event keeps the prevalence in each fold.

Detail:

- **Fold 1.** Training: 15,538 admissions, 10,978 patients, 364 events. Test: 3,845 admissions, 2,732 patients, 81 events. Shared patients: 0. *What for:* Example from repeat 1.
- **15 partitions.** Test patients per fold between 2,732 and 2,748; event-bearing patients per test fold between 70 and 109; patients on both sides: 0. *What for:* Result of the assertion.

### 3.2 Leak-free pipeline

*What learns from the data is learned inside the training data of each fit.*

**Notebook:** NB 02 to 06  
**Techniques:** Patient-level partition, Models, tuning and stacking  
**Where:** 02 · §4  
**References:** R1-4, R2-2

**What was done.** Winsorization, imputation, scaling and encoding are fit in a Pipeline once per fit. Hyperparameters are chosen with grouped inner validation. The meta-learner of the ensemble is trained with out-of-fold predictions of the base models. The calibrator is trained with out-of-fold predictions of the training patients. Test patients are only scored.

**What it is for.** It is what makes the outer estimate honest. Each of those pieces learns from data that do not include the patients being evaluated.

### 3.3 Base models and hyperparameter grids

*Logistic regression, random forest, extra trees and XGBoost with small grids declared in advance.*

**Notebook:** NB 02  
**Techniques:** Models, tuning and stacking  
**Where:** 02 · GRID  
**Output:** `outputs_main.txt` [7]

**What was done.** Each model has a short grid. The grids were widened once after the first run, because the edge of the grid had been chosen; the change was documented in the code.

**What it is for.** Compare a linear model with three tree-based ones under the same procedure, with grids wide enough not to favor any of them.

Detail:

- **LR.** C in 0.01, 0.1 and 1; class weights none or balanced. *What for:* Interpretable baseline.
- **RF.** Depth 2, 4 or 8; class weights none or `balanced_subsample`; minimum 20 per leaf.
- **ET.** Depth 4, 8 or 12.
- **XGB.** Depth 1, 2 or 4; `scale_pos_weight` 1 or the square root of negatives over positives; learning rate 0.05, subsample 0.8, column sampling 0.8, minimum child weight 5.

### 3.4 Nested hyperparameter tuning

*Hyperparameters are chosen inside the training data, also grouped by patient.*

**Notebook:** NB 02  
**Techniques:** Models, tuning and stacking, Patient-level partition  
**Where:** 02 · `tune_stack_calibrate`  
**Output:** `outputs_main.txt` [7]

**What was done.** Within each outer training set, a 3-fold inner StratifiedGroupKFold scores each combination of the grid. The criterion is the average precision (AUPRC) of the pooled out-of-fold predictions. The chosen combination is refit with the whole training set.

**What it is for.** Choosing with AUPRC is consistent with a rare outcome. Doing it inside each training set prevents the test set from influencing the choice.

Detail:

- **Chosen.** Across 15 outer fits, ET chose depth 12 in 12; RF depth 4 in 11; LR C = 1.0 in 7 and C = 0.1 in 6; XGBoost depth 2 with the square root weight in 8. *What for:* Shows how much the choice varies and that it did not stick to the edge.

### 3.5 Explicit stacking

*The ensemble combines the four models with a meta-learner trained only with out-of-fold predictions.*

**Notebook:** NB 02  
**Techniques:** Models, tuning and stacking  
**Where:** 02 · `tune_stack_calibrate`

**What was done.** The out-of-fold predictions of the four models, on the logit scale, feed a logistic regression (C = 0.1) that learns how to combine them. To train the calibrator, predictions of the meta-learner that are also out-of-fold are used (cross-validation inside the training data). The base models are refit with the whole training set to score the test data.

**What it is for.** It is the «ensemble» model of the manuscript. Training the meta-learner with in-sample predictions would make it trust the most overfit models too much.

### 3.6 Platt recalibration

*A one-predictor logistic regression corrects the scale of the probability.*

**Notebook:** NB 02  
**Techniques:** Calibration, Models, tuning and stacking  
**Where:** 02 · platt; `tune_stack_calibrate`  
**Output:** `outputs_main.txt` [2]

**What was done.** The calibrator (Platt) is fit with the out-of-fold predictions of the training patients and applied to the test patients. The uncalibrated ensemble (Stack_raw) is also computed to measure what the step contributes.

**What it is for.** So that probabilities can be read as risks. Stack_raw allows checking that recalibration does not change discrimination.

Detail:

- **Stack_raw.** AUROC 0.789 and AUPRC 0.167, equal to those of the recalibrated ensemble; slope 1.01 and O/E 1.00 in both. *What for:* The Platt step does not alter the ranking.

### 3.7 Hyperparameters chosen in the inner loops

*Each report lists which configuration each model chose in the 15 outer fits.*

**Notebook:** NB 02 to 06  
**Techniques:** Models, tuning and stacking, Count audit  
**Where:** 02 · report [7]  
**Output:** `data/outputs_*.txt` [7]

**What was done.** The table counts, by model and configuration, in how many of the 15 outer fits it was chosen.

**What it is for.** Check that the choice is stable and that it does not stick to an edge of the grid.

## P4. Metrics, uncertainty and sample size

**Where:** Notebook 02, sections 5 and 6 and Riley cells.

**Goal.** Define in advance how each result is measured and how certain it is, including whether there are enough events for the model.

### 4.1 Discrimination and overall error

*AUROC, AUPRC and Brier score on the out-of-fold predictions.*

**Notebook:** NB 02  
**Techniques:** Metrics and uncertainty  
**Where:** 02 · `metrics_one`  
**Output:** `outputs_main.txt` [1]

**What was done.** Metrics are computed with the pooled out-of-fold predictions of each repeat and then averaged over the three repeats. The standard deviation across repeats is also reported.

**What it is for.** With a prevalence of 2.30%, AUROC alone is not enough. The AUPRC of a model with no information equals the prevalence and is the reference against which it is read. The deviation across repeats measures how much the result depends on the partition.

Detail:

- **AUROC.** Probability that a case with SMM receives a higher risk than one without SMM. *What for:* Overall discrimination.
- **AUPRC.** Average precision; non-informative reference = prevalence. *What for:* More sensitive than AUROC to what happens among the highest-risk cases.
- **Brier.** Mean squared error of the probability. *What for:* Mixes discrimination and calibration.
- **SD across repeats.** Standard deviation of AUROC and AUPRC across the three repeats. *What for:* Instability of development.

### 4.2 Calibration: slope, CITL, O/E, ECE and deciles

*Five looks at whether the predicted probability matches the observed frequency.*

**Notebook:** NB 02  
**Techniques:** Calibration, Metrics and uncertainty  
**Where:** 02 · `calib_slope`, citl, `metrics_one`, `decile_table`  
**Output:** `outputs_main.txt` [2], [8]

**What was done.** The slope and the CITL are estimated by weighted Newton iterations. The ECE uses 10 quantile bins. There is also a table by risk decile and a calibration plot that is only shown on screen.

**What it is for.** A model with good discrimination can give useless probabilities. The recalibration of 3.6 is evaluated with these measures.

Detail:

- **Slope.** Logistic regression of the outcome on the predicted logit. Ideal 1. *What for:* Measures whether the model exaggerates or attenuates risk.
- **CITL.** Intercept with the slope fixed at 1. Ideal 0. *What for:* Measures overall bias.
- **O/E.** Observed over expected events. Ideal 1. *What for:* The same bias expressed as a ratio.
- **ECE.** Expected calibration error with 10 quantile bins. *What for:* Summary of the distance between the curve and the diagonal.
- **Deciles.** Mean predicted and observed risk per decile (mean across repeats). *What for:* What is drawn in the calibration figure.

### 4.3 Patient-level cluster bootstrap

*Intervals resample patients, not rows.*

**Notebook:** NB 02  
**Techniques:** Metrics and uncertainty, Patient-level partition  
**Where:** 02 · bootstrap  
**References:** R1-4, R2-2

**What was done.** In each replicate, patients are resampled with replacement and all admissions of a patient enter together, with weights equal to the number of times each patient is drawn. Each metric is recomputed with those weights. The 95% interval comes from the 2.5th and 97.5th percentiles.

**What it is for.** A patient with several admissions is not independent of herself. Resampling rows would give intervals that are too narrow.

Detail:

- **B.** 1,000 replicates in the main analysis; 300 in the sensitivity analyses. *What for:* See 0.1.

### 4.4 Paired differences between models

*Differences are computed on the same bootstrap samples.*

**Notebook:** NB 02  
**Techniques:** Metrics and uncertainty, Models, tuning and stacking  
**Where:** 02 · bootstrap, PAIRS  
**Output:** `outputs_main.txt` [3]

**What was done.** Five pairs are compared: RF − LR, ET − LR, XGB − LR, ensemble − LR and ensemble − XGB. In each replicate one metric is subtracted from the other with the same resampled patients, and the interval comes from the distribution of those differences. It is done for AUROC, AUPRC, Brier score and net benefit.

**What it is for.** Two intervals that overlap do not say whether the difference is real. The paired difference does, because it shares the noise of the sample.

### 4.5 Events captured in the top 5% and 10% of risk, and decision curve

*Two ways of reading utility: who is flagged and what is gained by flagging them.*

**Notebook:** NB 02  
**Techniques:** Clinical utility, Metrics and uncertainty  
**Where:** 02 · `top_threshold`, `metrics_one`  
**Output:** `outputs_main.txt` [4], [5]

**What was done.** The threshold that leaves 5% (and 10%) of admissions with the highest risk is fixed, and sensitivity and positive predictive value are computed. For the decision curve, net benefit is computed at eight thresholds (from 0.5% to 20%) and compared with treating everyone and treating no one.

**What it is for.** AUROC does not say how many events are recovered by monitoring a small fraction. The decision curve shows at which thresholds the model beats simple alternatives.

### 4.6 Performance by ICU admission in the first 24 hours

*The same predictions, evaluated separately in those already in the ICU and those not.*

**Notebook:** NB 02  
**Techniques:** Clinical utility, Metrics and uncertainty  
**Where:** 02 · `all_metrics` strata  
**Output:** `outputs_main.txt` [6]

**What was done.** With the predictions of the main partitions, AUROC and AUPRC are computed within each stratum (ICU within 24 hours and no ICU).

**What it is for.** Patients in the ICU at the prediction point are already seriously ill; mixing them in can inflate overall performance. The no-ICU stratum is the one that corresponds to early prediction.

### 4.7 Sample size: Riley criteria

*How many patients and events the SMM model and the mortality model would require.*

**Notebook:** NB 02  
**Techniques:** Sample size  
**Where:** 02 · functions riley, `p_max`, `riley_block`, `count_parameters`, `r2cs_from_oof`  
**Output:** `outputs_main.txt` (Riley); `outputs_modelA.txt`

**What was done.** The number of candidate parameters (32) is counted and the Riley criteria are computed: shrinkage, optimism and precision of the overall risk (with margins of ±0.05 and ±0.01). In Model B (SMM) the Cox–Snell R² is estimated from the cross-validated result of the logistic regression. In Model A (mortality) nothing is trained: R² values of 15%, 30% and 50% of the maximum possible are assumed.

**What it is for.** Leave in writing that SMM has enough events and mortality does not, and why the latter is not modeled.

## P5. Results of the main analysis

**Where:** `outputs_main.txt` and `outputs_modelA.txt`.

**Goal.** What came out of applying phases P1 to P4 to the main analysis: 19,383 eligible deliveries and 445 events.

### 5.1 Discrimination and overall error

*The ensemble and XGBoost reach an AUROC near 0.79; logistic regression, 0.78.*

**Notebook:** NB 02  
**Techniques:** Metrics and uncertainty  
**Where:** `outputs_main.txt` [1]  
**Output:** `outputs_main.txt`

**What was done.** Means across repeats with 95% intervals from the patient bootstrap. Prevalence 0.0230, which is also the AUPRC of a model with no information.

**What it is for.** It is the performance table of the manuscript.

Detail:

- **LR.** AUROC 0.780 (0.757–0.803), AUPRC 0.154 (0.125–0.192), Brier 0.02087.
- **RF.** AUROC 0.777 (0.750–0.801), AUPRC 0.158 (0.130–0.195), Brier 0.02075.
- **ET.** AUROC 0.770 (0.745–0.795), AUPRC 0.151 (0.124–0.185), Brier 0.02090.
- **XGB.** AUROC 0.791 (0.767–0.816), AUPRC 0.163 (0.135–0.202), Brier 0.02073.
- **Ensemble.** AUROC 0.789 (0.765–0.813), AUPRC 0.167 (0.138–0.206), Brier 0.02066. *What for:* AUPRC about 7 times the prevalence.

### 5.2 Calibration

*All five models are well calibrated after the Platt step.*

**Notebook:** NB 02  
**Techniques:** Calibration  
**Where:** `outputs_main.txt` [2], [8]  
**Output:** `outputs_main.txt`

**What was done.** Slopes between 0.99 and 1.02, CITL close to 0 and O/E equal to 1.00 or 1.01. By deciles, the predicted risk follows the observed one, with the last decile at 0.107 predicted and 0.106 observed for logistic regression, and 0.111 and 0.119 for the ensemble.

**What it is for.** So that probabilities can be read as risks.

Detail:

- **Slope.** LR 0.99 (0.92–1.07), XGB 1.02 (0.95–1.10), ensemble 1.01 (0.93–1.08).
- **O/E.** 1.00 in LR, XGB and ensemble; 1.01 in RF.
- **Decile 1.** Ensemble: predicted 0.0054 and observed 0.0041. *What for:* The low end, with few events.
- **Decile 10.** Ensemble: predicted 0.1107 and observed 0.1186. *What for:* The high end, where risk concentrates.

### 5.3 Paired differences

*The ensemble beats logistic regression by a small difference and is not distinguishable from XGBoost.*

**Notebook:** NB 02  
**Techniques:** Metrics and uncertainty, Models, tuning and stacking  
**Where:** `outputs_main.txt` [3]  
**Output:** `outputs_main.txt`

**What was done.** Differences in AUROC and AUPRC with a paired 95% interval.

**What it is for.** It is the honest answer to whether the complex model adds anything.

Detail:

- **Ensemble − LR.** AUROC +0.009 (0.002 to 0.016); AUPRC +0.013 (0.003 to 0.023); Brier −0.00021 (−0.00037 to −0.00006).
- **XGB − LR.** AUROC +0.011 (0.004 to 0.020); AUPRC +0.009 (−0.002 to 0.021).
- **RF − LR.** AUROC −0.003 (−0.013 to 0.006); AUPRC +0.004 (−0.014 to 0.022).
- **ET − LR.** AUROC −0.009 (−0.019 to 0.000); AUPRC −0.004 (−0.022 to 0.014).
- **Ensemble − XGB.** AUROC −0.002 (−0.006 to 0.001); AUPRC +0.003 (−0.001 to 0.008).

### 5.4 Events captured in the top 5% and 10% of risk

*Monitoring the top 10% of risk captures about half of the events.*

**Notebook:** NB 02  
**Techniques:** Clinical utility  
**Where:** `outputs_main.txt` [4]  
**Output:** `outputs_main.txt`

**What was done.** Sensitivity (and positive predictive value) when flagging the 5% and 10% with the highest predicted risk.

**What it is for.** It translates discrimination into an operational figure.

Detail:

- **Ensemble, 5%.** Sensitivity 0.354 (0.316–0.399), positive predictive value 0.163.
- **Ensemble, 10%.** Sensitivity 0.517 (0.476–0.559), positive predictive value 0.119.
- **LR, 5% and 10%.** Sensitivity 0.333 (0.292–0.374) and 0.461 (0.417–0.506). *What for:* Baseline.

### 5.5 Decision curve

*From the 2% threshold onward the ensemble clearly beats treating everyone.*

**Notebook:** NB 02  
**Techniques:** Clinical utility  
**Where:** `outputs_main.txt` [5]  
**Output:** `outputs_main.txt`

**What was done.** Net benefit by decision threshold, compared with treating everyone and treating no one, and paired differences.

**What it is for.** Show the range of thresholds in which using the model makes sense.

Detail:

- **Threshold 0.5%.** Ensemble 0.01814, treat everyone 0.01805: practically equal. *What for:* With such a low threshold, treating everyone is almost optimal.
- **Threshold 5%.** Ensemble 0.00717; treat everyone −0.02846.
- **Ensemble − LR.** Threshold 2%: +0.00047 (0.00013 to 0.00081). Threshold 5%: +0.00129 (0.00076 to 0.00188). *What for:* Paired differences.

### 5.6 ICU strata

*Performance drops in the population without ICU, which is the early-prediction one.*

**Notebook:** NB 02  
**Techniques:** Clinical utility  
**Where:** `outputs_main.txt` [6]  
**Output:** `outputs_main.txt`

**What was done.** The same predictions, evaluated by stratum.

**What it is for.** Show that part of the overall performance comes from patients who are already critical.

Detail:

- **ICU within 24 h.** 115 admissions and 90 events. AUROC LR 0.544 (0.416–0.664) and ensemble 0.610 (0.479–0.725). *What for:* Small stratum: the intervals are wide.
- **No ICU within 24 h.** 19,268 admissions and 355 events. AUROC LR 0.743 (0.716–0.771) and ensemble 0.749 (0.722–0.777); AUPRC 0.101 and 0.109. *What for:* It is the population of interest for early prediction.

### 5.7 Sample size and feasibility of mortality

*SMM has more than enough events for 32 parameters; mortality does not.*

**Notebook:** NB 02  
**Techniques:** Sample size  
**Where:** `outputs_main.txt` (Riley); `outputs_modelA.txt`  
**Output:** `outputs_main.txt`; `outputs_modelA.txt`

**What was done.** Riley criteria applied to the SMM model with observed R² and to the mortality model with assumed R².

**What it is for.** Justify why SMM is modeled and mortality is only reported as a feasibility analysis.

Detail:

- **Model B (SMM).** 445 events and 32 parameters: 13.91 events per parameter. Observed Cox–Snell R² 0.0311 (maximum 0.1964). Required size 9,112 admissions and 209 events; available 19,383 and 445. Maximum number of parameters the data support: 68.1. *What for:* Met.
- **Model A (mortality).** 3 events and 32 parameters: 0.09 events per parameter. Required size: 635,433 admissions with 15% of the maximum R², 317,637 with 30% and 211,688 with 50%; available 19,383. Maximum number of parameters: 1.0, 2.0 and 3.3. *What for:* Not met in any scenario.
- **Rule of thumb.** Ten events per parameter would require 320 deaths; there are 3. *What for:* That is why mortality is not modeled.

## P6. Sensitivity analyses

**Where:** Notebooks 02 (section 10), 04 and 06.

**Goal.** Repeat the main analysis changing one thing only, to see whether the conclusion (the ensemble beats logistic regression by a small margin) holds.

### 6.1 The population changes

*Four variants that change who enters and leave the model and predictors unchanged.*

**Notebook:** NB 02  
**Techniques:** Sensitivity, Cohort definition  
**Where:** 02 · §10  
**Output:** `outputs_first_admission.txt`; `outputs_any_obstetric.txt`; `outputs_no_icu_24h.txt`; `outputs_icd10_only.txt`  
**References:** D4

**What was done.** The same procedure (grouped 5 × 3 partition, nested tuning, stacking, Platt, bootstrap with B = 300) is applied to each population. Results are the AUROC of the ensemble with its interval and the paired ensemble − LR difference.

**What it is for.** See whether the conclusion depends on repeated admissions, on restricting to deliveries, on patients already in the ICU or on the change of coding.

Detail:

- **first_admission.** One admission per patient. Ensemble AUROC 0.786 (0.761–0.812), AUPRC 0.159. Ensemble − LR in AUROC +0.008 (0.002 to 0.014). *What for:* Without repeated admissions.
- **any_obstetric.** Any obstetric admission. Ensemble AUROC 0.830 (0.814–0.847), AUPRC 0.267. Ensemble − LR +0.011 (0.005 to 0.016). *What for:* Broader population with higher prevalence (3.45%).
- **no_icu_24h.** No ICU admission within 24 h. Ensemble AUROC 0.754 (0.727–0.782), AUPRC 0.112. Ensemble − LR +0.016 (0.008 to 0.025). *What for:* The early-prediction population.
- **icd10_only.** ICD-10-CM only. Ensemble AUROC 0.779 (0.747–0.813), AUPRC 0.208. Ensemble − LR +0.009 (−0.000 to 0.022). *What for:* Without the change of version.

### 6.2 The definition of the outcome changes

*Two ways of making the outcome stricter.*

**Notebook:** NB 02 and 06  
**Techniques:** Sensitivity  
**Where:** 02 · §10; 06 · §4  
**Output:** `outputs_label_ge2.txt`; `outputs_excl_renal_only.txt`  
**References:** T50, R2-14, R2-15, R1-9

**What was done.** `label_ge2` requires two or more SMM indicators. `excl_renal_only` removes from the population the admissions whose only indicator is acute renal failure; those with renal failure plus another indicator remain as events.

**What it is for.** Acute renal failure is the most frequent indicator and creatinine is a main predictor; it had to be seen whether the model survives without that possible circularity.

Detail:

- **label_ge2.** 129 events (0.67%). Ensemble AUROC 0.848 (0.814–0.884), AUPRC 0.081. Ensemble − LR in AUROC +0.008 (−0.002 to 0.020) and in AUPRC +0.013 (0.002 to 0.024). *What for:* Few events: the intervals are wide.
- **excl_renal_only.** 295 events in 19,233 admissions (1.53%). Ensemble AUROC 0.795 (0.765–0.822), AUPRC 0.110. Ensemble − LR +0.004 (−0.002 to 0.010). *What for:* Without the admissions that only have renal failure, AUROC does not drop.

### 6.3 The predictors change

*Two variants that add variables to the same population.*

**Notebook:** NB 02  
**Techniques:** Sensitivity, Missing data and indicators  
**Where:** 02 · §10  
**Output:** `outputs_labs_extended.txt`; `outputs_icu_vars.txt`

**What was done.** `labs_extended` adds hematocrit and other laboratory variables, each with its missingness indicator. `icu_vars` adds the ICU variables, with their indicators, and the ICU flag.

**What it is for.** See how much prediction improves with more information and whether the conclusion about the model changes.

Detail:

- **labs_extended.** 14 numeric and 12 binary. Ensemble AUROC 0.823 (0.799–0.846), AUPRC 0.332. Ensemble − LR +0.006 (−0.001 to 0.012). *What for:* More laboratory information raises the performance of both models.
- **icu_vars.** 17 numeric and 16 binary. Ensemble AUROC 0.797 (0.770–0.821), AUPRC 0.322. Ensemble − LR +0.011 (0.003 to 0.018). *What for:* With ICU variables.

### 6.4 With and without the creatinine missingness indicator

*How much of the performance depends on knowing whether creatinine was measured.*

**Notebook:** NB 04  
**Techniques:** Sensitivity, Missing data and indicators  
**Where:** 04 · §7 and §8  
**Output:** `outputs_no_indicator.txt`  
**References:** R2-7, R2-20

**What was done.** The main model is repeated on the same partitions and with the same patient samples, without the indicator (absent creatinine is imputed with the median without flagging it). Differences are paired, with B = 1000, and the notebook also reports calibration and ICU strata.

**What it is for.** The indicator carries information about who was tested (see 2.6). The reviewer's question is how much it weighs.

Detail:

- **LR.** AUROC 0.780 with the indicator and 0.695 without it; difference −0.085 (−0.109 to −0.059). *What for:* The linear model depends heavily on the indicator.
- **Ensemble.** AUROC 0.789 with the indicator and 0.776 without it; difference −0.013 (−0.024 to −0.002). AUPRC 0.167 and 0.164; difference −0.003 (−0.010 to 0.003). *What for:* The tree-based models lose much less than logistic regression (RF −0.023, ET −0.012, XGB −0.013).
- **Calibration.** Slope and O/E unchanged with and without the indicator (ensemble: 1.01 and 1.00). *What for:* The indicator affects discrimination, not calibration.

### 6.5 Joint reading of the nine sensitivity analyses

*The ensemble − LR difference is positive in all of them, between +0.004 and +0.016 of AUROC.*

**Notebook:** NB 02, 04, 06  
**Techniques:** Sensitivity  
**Where:** All `data/outputs_*.txt` outputs

**What was done.** In all variants the AUROC of the ensemble and its paired difference with logistic regression are compared. In the main analysis it is +0.009 (0.002 to 0.016). The interval excludes zero in `first_admission`, `any_obstetric`, `icu_vars` and `no_icu_24h`; it includes it in `labs_extended`, `label_ge2`, `excl_renal_only` and `icd10_only` (in the latter, the lower limit is −0.000).

**What it is for.** Answer in one sentence whether the conclusion depends on a design decision: in these analyses the advantage of the ensemble is small and does not depend on a particular population, outcome or set of predictors.

## P7. Class imbalance: no correction, weights and SMOTE-NC

**Where:** Notebook 03.

**Goal.** Test, with the same nested and grouped procedure, whether correcting the imbalance (2.30% of events) improves the model, and what each correction does to the probability scale.

### 7.1 Three strategies, each tuned separately

*Same partition, same inner tuning and same criterion; only the handling of imbalance changes.*

**Notebook:** NB 03  
**Techniques:** Class imbalance, Models, tuning and stacking  
**Where:** 03 · §3 and §8 `make_grid`, `set_strategy`  
**Output:** `outputs_resampling.txt`  
**References:** R1-9

**What was done.** The main analysis is run three times: with no weights or resampling, with class weights (balanced; square root of negatives over positives in XGBoost) and with SMOTE-NC. The outer partitions, the grouped inner tuning and the criterion (AUPRC) are those of notebook 02. The grids are the same except for the weights or resampling option. In no strategy are weights and oversampling combined.

**What it is for.** Answer with evidence whether resampling was tried and what it did. The result holds for these configurations, as the reviewer notes.

Detail:

- **unweighted.** No weights (`class_weight` = None, `scale_pos_weight` = 1) and no resampling. *What for:* Reference.
- **weighted.** Class weights only. *What for:* Corrects the imbalance by changing the loss.
- **smote.** SMOTE-NC only, on the training part of each fit, with the minority/majority ratio chosen between 0.1 and 1.0. *What for:* Corrects the imbalance by creating synthetic cases.

### 7.2 SMOTE-NC inside the pipeline

*Synthetic cases are born only from training rows of the fit in progress.*

**Notebook:** NB 03  
**Techniques:** Class imbalance, Patient-level partition  
**Where:** 03 · §8 SmoteNCAuto class  
**References:** R1-9

**What was done.** Oversampling happens inside the pipeline, after the preprocessing of the training data. The columns after the numeric block (indicators and 0/1 columns) are treated as categorical, so that the vote of the nearest neighbors (k = 5) sets them instead of averaging them into fractions. Validation or test rows are never used.

**What it is for.** The classic error is resampling before splitting and leaking synthetic cases into the test data. Doing it inside the fit avoids that leakage.

### 7.3 Comparison after recalibration

*Weights barely change the result and SMOTE-NC makes it worse.*

**Notebook:** NB 03  
**Techniques:** Class imbalance, Calibration, Metrics and uncertainty  
**Where:** 03 · §10 `strategy_compare`  
**Output:** `outputs_resampling.txt` [S1], [S3]  
**References:** R1-9

**What was done.** Calibrated results use the Platt step of each strategy. Differences between strategies are paired, with the same patient samples (B = 300). The ensemble without correction gives AUROC 0.786, slightly less than the 0.789 of the main analysis, whose grid includes weights as an option.

**What it is for.** It is the table that supports the manuscript sentence about resampling.

Detail:

- **Ensemble.** AUROC 0.786 with no correction, 0.790 with weights and 0.774 with SMOTE-NC. AUPRC 0.167, 0.162 and 0.156.
- **SMOTE − no correction.** Ensemble: AUROC −0.012 (−0.023 to −0.002) and AUPRC −0.010 (−0.020 to −0.001). Logistic regression: AUROC −0.023 (−0.034 to −0.012). XGBoost: AUROC −0.013 (−0.023 to −0.005). *What for:* SMOTE-NC lowers AUROC in four of the five models (all but RF).
- **Weights − no correction.** Ensemble: AUROC +0.004 (0.000 to 0.007) and AUPRC −0.004 (−0.013 to 0.002). RF and ET lose AUPRC (−0.022, with intervals that exclude zero). *What for:* Weights barely change discrimination and can lower precision.

### 7.4 What each correction does to the probability, before recalibration

*Weights and oversampling inflate the predicted probability by a factor of 3 to 17.*

**Notebook:** NB 03  
**Techniques:** Class imbalance, Calibration  
**Where:** 03 · §10  
**Output:** `outputs_resampling.txt` [S2]  
**References:** R1-9

**What was done.** The probabilities of each base model are reported as the algorithm produced them: mean predicted risk, O/E, slope and AUROC. The observed prevalence is 0.0230.

**What it is for.** Show that the correction moves the probability scale, and that recalibration is therefore indispensable if it is used.

Detail:

- **No correction.** Mean predicted risk 0.0229 in LR, RF and ET, and 0.0228 in XGBoost; O/E 1.00 in the first three and 1.01 in XGBoost. *What for:* The scale is already correct.
- **Class weights.** Mean risk 0.382 in LR, 0.384 in RF, 0.397 in ET and 0.107 in XGBoost; O/E 0.06 (0.21 in XGBoost). *What for:* They overestimate risk by a factor of 5 to 17.
- **SMOTE-NC.** Mean risk between 0.080 and 0.086; O/E between 0.27 and 0.29. *What for:* They overestimate by a factor of 3 to 4.

## P8. Era, coding version and temporal validation

**Where:** Notebook 05.

**Goal.** Check whether the model learns when the admission occurred instead of the severity of the patient, and how it behaves when applied to a period later than the one that developed it.

### 8.1 Performance by year group and by ICD version (A)

*The out-of-fold predictions of the main model, evaluated separately in each group.*

**Notebook:** NB 05  
**Techniques:** Era and temporal validation, Metrics and uncertainty  
**Where:** 05 · §6 `group_performance`; 05 · cell 7.4  
**Output:** `outputs_era_temporal.txt` [1]  
**References:** T47, R1-3, R2-6, R2-17, R2-25

**What was done.** The out-of-fold predictions of the main analysis (replicated in this notebook) are used to compute AUROC, AUPRC, O/E and slope in each year group (`anchor_year_group`) and in each ICD version (ICD-9 only, mixed, ICD-10 only), with patient-bootstrap intervals (B = 300). The slope is shown only in groups with at least 20 events. O/E and slope are computed with probabilities calibrated on the whole development sample, so an O/E far from 1 in a group indicates a calibration shift between groups.

**What it is for.** If the model discriminated well in only one period or version, it would be learning the period. Calibration by group shows the shift in risk.

Detail:

- **Ensemble AUROC.** 2008–2010: 0.778 (0.735–0.824). 2011–2013: 0.762 (0.701–0.824). 2014–2016: 0.800 (0.745–0.847). 2017–2019: 0.803 (0.747–0.858). 2020–2022: 0.750 (0.673–0.813). *What for:* Stable discrimination across periods, with wide intervals.
- **Ensemble O/E.** 0.69 (0.56–0.84), 0.90 (0.74–1.11), 1.18 (0.97–1.40), 1.33 (1.06–1.61) and 1.95 (1.50–2.40) in the same five groups. *What for:* The model overestimates in the first years and underestimates in the last ones, because of the rise in prevalence.
- **ICD version.** ICD-9 only: AUROC 0.780 (0.739–0.821), O/E 0.80. ICD-10 only: AUROC 0.784 (0.751–0.812), O/E 1.18. *What for:* The same discrimination with both versions.

### 8.2 Rolling-origin temporal validation (B)

*Train with the earlier years and score a later group.*

**Notebook:** NB 05  
**Techniques:** Era and temporal validation, Patient-level partition  
**Where:** 05 · §6 `temporal_plan`, `temporal_fit`, `run_temporal`  
**Output:** `outputs_era_temporal.txt` [2]  
**References:** T47, R3-7

**What was done.** For each group after the first, each model is fit, stacked and recalibrated only with the earlier groups and scored in that group. Patients with admissions in the test group are removed from training, and an assertion checks that nobody is in both. A fit is skipped, and printed as skipped, if training has fewer than 40 events or the test set fewer than 15.

**What it is for.** It is the closest to prospective use that a single institution allows. It is exploratory and is not an external validation.

Detail:

- **2008–2010 → 2011–2013.** Training 8,212 admissions and 121 events; test 4,328 and 86. Ensemble AUROC 0.762 (0.705–0.813); O/E 1.34. Ensemble − LR in AUROC +0.003 (−0.017 to 0.023).
- **2008–2013 → 2014–2016.** Training 12,540 and 207; test 3,569 and 104. AUROC 0.807 (0.754–0.848); O/E 1.51. Ensemble − LR +0.024 (0.009 to 0.036).
- **2008–2016 → 2017–2019.** Training 16,109 and 311; test 2,343 and 81. AUROC 0.801 (0.745–0.858); O/E 1.47. Ensemble − LR in AUROC −0.002 (−0.020 to 0.016).
- **2008–2019 → 2020–2022.** Training 18,452 and 392; test 931 and 53. AUROC 0.760 (0.694–0.829); O/E 2.12 (1.57–2.69). Ensemble − LR +0.021 (0.003 to 0.040).
- **Reading.** Forward discrimination resembles that of the cross-validation in the same block (for example 0.762, 0.800, 0.803 and 0.750), but O/E rises from 1.34 to 2.12. *What for:* The model ranks well in later periods and underestimates absolute risk, because prevalence increases.

### 8.3 ICD-9 → ICD-10 transition (C)

*Train only with ICD-9 admissions and score the ICD-10 ones.*

**Notebook:** NB 05  
**Techniques:** Era and temporal validation, Patient-level partition  
**Where:** 05 · §6 `temporal_plan`  
**Output:** `outputs_era_temporal.txt` [2]  
**References:** T47, R2-17

**What was done.** Same procedure as 8.2: training with ICD-9-only admissions (8,507 admissions, 6,640 patients and 154 events), removing the patients who appear in the test set, and testing with ICD-10-only admissions (8,864, 7,070 and 271).

**What it is for.** Isolate the change of coding from the definition of SMM, which uses different lists per version.

Detail:

- **Ensemble.** AUROC 0.775 (0.745–0.805), AUPRC 0.150, O/E 1.22 (1.05–1.36), slope 0.84 (0.73–0.95). Cross-validation AUROC in the same block: 0.784. *What for:* Small loss of discrimination; some underestimation.
- **Ensemble − LR.** AUROC +0.010 (0.005 to 0.015); AUPRC +0.012 (0.002 to 0.024).

### 8.4 Refits without administrative variables and with the era (D)

*Two paired refits against the main model: without proxies of the period and with the period added.*

**Notebook:** NB 05  
**Techniques:** Era and temporal validation, Sensitivity  
**Where:** 05 · §3 and §6 `paired_alt`  
**Output:** `outputs_era_temporal.txt` [3]  
**References:** T47, R1-3, R2-6

**What was done.** `main_noadmin` removes the five administrative variables (ethnicity, insurance, language, admission type and location), whose categories and use change over time. `main_plus_era` adds the year group and is a diagnostic only: it is not a deployable predictor. Same partitions and same patient samples (B = 1000).

**What it is for.** If removing the administrative variables lowered performance a lot, the model would rely on variables that may reflect the period. If adding the period raised it a lot, there would be temporal signal that the model does not capture.

Detail:

- **Without administrative.** Ensemble: AUROC 0.773 versus 0.789; difference −0.016 (−0.026 to −0.004). AUPRC 0.145 versus 0.167; difference −0.022 (−0.040 to −0.006). Logistic regression: −0.018 (−0.030 to −0.007). *What for:* The administrative variables contribute some signal.
- **With the era.** Ensemble: AUROC 0.801; difference +0.012 (0.004 to 0.022). AUPRC 0.183; difference +0.016 (0.008 to 0.024). *What for:* The period adds signal.
- **Calibration.** Slope and O/E of the ensemble unchanged in the three models (1.01 or 1.00).

### 8.5 What these analyses can and cannot show

*Four limits that the notebook leaves in writing.*

**Notebook:** NB 05  
**Techniques:** Era and temporal validation  
**Where:** 05 · first cell  
**References:** T47

**What was done.** `anchor_year_group` is a three-year group that MIMIC-IV assigns to each patient, not an exact admission date: a repeat admission years later keeps the patient's group. Because it is fixed per patient, each patient falls entirely in one block. The ICD-9 to ICD-10 change (October 2015) falls within the 2014–2016 group, so period and coding version are partly confounded. The temporal validation is exploratory: one institution, few events in the first groups.

**What it is for.** So that the reading of phase P8 does not go beyond what the data allow. It is not an external validation.

## P9. Timing of events relative to the prediction point

**Where:** Notebook 07.

**Goal.** Know how many of the 445 SMM cases could have occurred before 24 hours, when the model predicts. It only counts; it trains nothing.

### 9.1 Rule for placing each procedure before or after T

*Diagnosis codes have no time; procedure codes have a date.*

**Notebook:** NB 07  
**Techniques:** Timing, Count audit  
**Where:** 07 · §2 SQL_CATEGORY, SQL_INDICATOR  
**Output:** `outputs_smm_timing.txt`  
**References:** T52, R3-2, R3-3, R1-2, R2-5

**What was done.** For each eligible delivery with SMM, each procedure-based indicator (ventilation, hysterectomy, conversion of cardiac rhythm) is joined with `procedures_icd` using the same code patterns as the label (`smm_code_patterns_v2`, by prefix or exact match). With the procedure date D (no time) and T = admission + 24 hours, it is classified into three timings.

**What it is for.** SMM is defined for the whole admission and diagnoses carry no time. The procedure date is the only thing that allows part of the events to be placed in time.

Detail:

- **before.** D + 1 day ≤ T: the whole day ended before T. *What for:* The procedure certainly preceded the prediction.
- **after.** D ≥ T: the day started at T or later. *What for:* The procedure certainly followed it.
- **ambiguous.** Any other case: the day contains T. *What for:* The order cannot be determined.

### 9.2 Categories A to D of each admission with SMM

*Each of the 445 admissions is assigned a single category.*

**Notebook:** NB 07  
**Techniques:** Timing, Count audit  
**Where:** 07 · §2 `report_category`  
**Output:** `outputs_smm_timing.txt` [1]  
**References:** T52, R3-2, R3-3

**What was done.** Categories are assigned in order: A if some procedure indicator is certainly before T; otherwise B if any is ambiguous; C if all are certainly after T; D if there is no procedure indicator at all. It is also split by the presence of a diagnosis-based indicator, whose time is unknown. The sum of categories is compared with 445 (OK).

**What it is for.** It is the figure that bounds which part of SMM could have started before the prediction point.

Detail:

- **A.** 59 admissions (13.3%): 23 without a diagnosis-based indicator and 36 with one. *What for:* At least these had a procedure certainly before T.
- **B.** 25 (5.6%): 6 without a diagnosis-based indicator and 19 with one. *What for:* The order cannot be determined.
- **C.** 42 (9.4%): 14 without a diagnosis-based indicator and 28 with one. *What for:* The procedures follow T.
- **D.** 319 (71.7%): all with a diagnosis-based indicator and none based on a procedure. *What for:* The label rests only on diagnosis codes: there is no time.

### 9.3 Procedure indicators by timing

*How many admissions have each indicator before, around or after T.*

**Notebook:** NB 07  
**Techniques:** Timing, Count audit  
**Where:** 07 · §2 pivot  
**Output:** `outputs_smm_timing.txt` [2]  
**References:** T52

**What was done.** For each procedure indicator, admissions are counted by timing. An admission with the same indicator on different days can appear in several columns, so they need not add up to the number of distinct admissions with the indicator.

**What it is for.** See which indicators contribute the events that had already occurred at the prediction point.

Detail:

- **Hysterectomy.** 79 admissions: 38 before, 13 ambiguous and 28 after.
- **Ventilation.** 60 admissions: 27 before, 12 ambiguous and 21 after.
- **Conversion of cardiac rhythm.** 6 admissions: 0 before, 3 ambiguous and 3 after.

## Technique index

| Technique | What it groups | Steps |
|---|---|---|
| Count audit | Checks that print only aggregate counts and compare them with what is expected (OK or CHECK): cohort, events, patients per partition, overlap, timing. | 0.2, 1.1, 1.2, 1.4, 1.5, 1.6, 2.6, 3.1, 3.7, 9.1, 9.2, 9.3 |
| Cohort definition | Who enters each analysis: population, eligibility filters and the rule of each variant. | 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 6.1 |
| Cleaning and winsorization | Plausibility limits and clipping of extreme values (0.5th and 99.5th percentiles of the training data). | 2.2, 2.4 |
| Missing data and indicators | How absent values are handled: missingness indicators, median imputation, the «missing» category. | 2.1, 2.2, 2.3, 2.5, 2.6, 2.7, 6.3, 6.4 |
| Patient-level partition | Cross-validation grouped by patient and everything that guarantees nobody ends up on both sides. | 1.1, 3.1, 3.2, 3.4, 4.3, 7.2, 8.2, 8.3 |
| Models, tuning and stacking | The four base models, their grids, nested tuning and the stacked ensemble. | 0.1, 2.5, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.4, 5.3, 7.1 |
| Calibration | Platt recalibration and the calibration measures: slope, CITL, O/E, ECE and deciles. | 3.6, 4.2, 5.2, 7.3, 7.4 |
| Metrics and uncertainty | AUROC, AUPRC, Brier score, patient-level bootstrap and paired differences. | 0.1, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.3, 7.3, 8.1 |
| Clinical utility | Events captured in the top 5% and 10% of predicted risk, decision curve and ICU strata. | 4.5, 4.6, 5.4, 5.5, 5.6 |
| Sample size | Riley criteria and feasibility of the mortality model. | 4.7, 5.7 |
| Sensitivity | Repeating the main analysis changing one thing only: population, outcome or predictors. | 1.3, 1.5, 2.7, 6.1, 6.2, 6.3, 6.4, 6.5, 8.4 |
| Class imbalance | No correction, class weights and SMOTE-NC, each tuned separately. | 7.1, 7.2, 7.3, 7.4 |
| Era and temporal validation | Performance by period and ICD version, forward-in-time validation and refits without era proxies. | 1.6, 8.1, 8.2, 8.3, 8.4, 8.5 |
| Timing | Which SMM events could have occurred before the prediction point (admission + 24 h). | 1.4, 9.1, 9.2, 9.3 |
