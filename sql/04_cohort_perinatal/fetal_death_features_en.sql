-- ============================================================================
-- Modelo C (fetal death): extended feature table
--   mimiciv.cohort_fetal_death_dataset_ext = cohort_fetal_death_dataset + new features
-- ============================================================================
-- Added after the feature-discovery queries (perinatal_feature_discovery_en.sql).
-- PREREQUISITES: fetal_death_dataset_en.sql (cohort_fetal_death_dataset,
-- fetal_death_code_patterns) and pregnancy-independent MIMIC-IV tables only.
--
-- TIME RULE (leakage control): every feature is known at or before arrival, or
-- measured in the first 24 h from arrival (ED registration or admission time,
-- whichever is earlier). Diagnoses, procedures, DRG, treatments and
-- microbiology of the SAME admission are NOT used (they are produced by the event:
-- e.g. CMV / toxoplasma serology and tissue specimens follow a fetal death).
-- Coagulation (PT, INR, PTT, fibrinogen) and LDH are NOT used either: they were
-- 5-10x more frequent among events (post-diagnosis work-up).
--
-- Blocks:
--   history  hx_hypertension, hx_diabetes, hx_obesity, hx_renal_disease
--            (from diagnoses of EARLIER admissions of the same patient)
--            hx_prior_fetal_death_1y: prior fetal-death code at least 365 days earlier
--            (a closer one is usually the SAME pregnancy: 5 of 6 such events were within 90 days)
--   cbc      first hemoglobin, hematocrit, platelets, WBC, MCV, RDW (tier 1)
--   panel    first creatinine, ALT, AST, uric acid, urea nitrogen, urine protein/creatinine
--            (tier 2: pre-eclampsia work-up; ordered selectively)
--   omr      outpatient measurements in the 365 days BEFORE the admission date (OMR table):
--            last and maximum blood pressure, last weight (kg) and BMI, number of outpatient
--            dates with vitals, days since the last one. Coverage: BP 61% of admissions,
--            weight 57%, BMI 41%; not enriched among events (no ordering signature).
--            Values outside plausible ranges are set to NULL. These records precede the
--            admission, so the event cannot have produced them; they are outpatient
--            measurements in general, not necessarily prenatal visits.
--   days_since_prior_fd  days since the closest earlier admission with a fetal-death
--            code (ANY gap). NOT a predictor: used by the notebook to drop admissions
--            that belong to the same pregnancy as an earlier event (<= 180 days).
--
-- Run as a whole script (DBeaver: Alt+X). Can take several minutes (labevents).
-- ============================================================================

DROP TABLE IF EXISTS mimiciv.cohort_fetal_death_features;
CREATE TABLE mimiciv.cohort_fetal_death_features AS
WITH base AS (
    SELECT c.subject_id, c.hadm_id, a.admittime,
           LEAST(a.admittime, COALESCE(a.edregtime, a.admittime)) AS t0
    FROM   mimiciv.cohort_fetal_death_dataset c
    JOIN   mimiciv.admissions a ON a.hadm_id = c.hadm_id
),
-- first value of each lab item inside [t0, t0 + 24 h]
first_lab AS (
    SELECT DISTINCT ON (b.hadm_id, l.itemid)
           b.hadm_id, l.itemid, l.valuenum
    FROM   base b
    JOIN   mimiciv.labevents l
           ON l.hadm_id = b.hadm_id
          AND l.valuenum IS NOT NULL
          AND l.charttime BETWEEN b.t0 AND b.t0 + INTERVAL '24 hours'
          AND l.itemid IN (51222, 51221, 51265, 51301, 51250, 51277,        -- CBC
                           50912, 50861, 50878, 51007, 51006, 51099)        -- panel
    ORDER  BY b.hadm_id, l.itemid, l.charttime
),
labs AS (
    SELECT hadm_id,
           MAX(valuenum) FILTER (WHERE itemid = 51222) AS lab_hemoglobin,
           MAX(valuenum) FILTER (WHERE itemid = 51221) AS lab_hematocrit,
           MAX(valuenum) FILTER (WHERE itemid = 51265) AS lab_platelets,
           MAX(valuenum) FILTER (WHERE itemid = 51301) AS lab_wbc,
           MAX(valuenum) FILTER (WHERE itemid = 51250) AS lab_mcv,
           MAX(valuenum) FILTER (WHERE itemid = 51277) AS lab_rdw,
           MAX(valuenum) FILTER (WHERE itemid = 50912) AS lab_creatinine,
           MAX(valuenum) FILTER (WHERE itemid = 50861) AS lab_alt,
           MAX(valuenum) FILTER (WHERE itemid = 50878) AS lab_ast,
           MAX(valuenum) FILTER (WHERE itemid = 51007) AS lab_uric_acid,
           MAX(valuenum) FILTER (WHERE itemid = 51006) AS lab_urea_nitrogen,
           MAX(valuenum) FILTER (WHERE itemid = 51099) AS lab_urine_prot_creat
    FROM   first_lab
    GROUP  BY hadm_id
),
-- diagnoses of EARLIER admissions of the same patient
prior_dx AS (
    SELECT b.hadm_id,
           (b.admittime::date - a2.admittime::date) AS gap_days,
           d.icd_version, d.icd_code,
           EXISTS (SELECT 1 FROM mimiciv.fetal_death_code_patterns fp
                   WHERE fp.icd_version = d.icd_version
                     AND d.icd_code LIKE fp.code_prefix || '%') AS is_fd
    FROM   base b
    JOIN   mimiciv.admissions a2
           ON a2.subject_id = b.subject_id AND a2.admittime < b.admittime
    JOIN   mimiciv.diagnoses_icd d ON d.hadm_id = a2.hadm_id
),
hist AS (
    SELECT hadm_id,
           MAX(CASE WHEN (icd_version = 10 AND icd_code ~ '^(I1[0-6]|O1[0-6])')
                      OR (icd_version = 9  AND icd_code ~ '^(40[1-5]|642)') THEN 1 ELSE 0 END) AS hx_hypertension,
           MAX(CASE WHEN (icd_version = 10 AND icd_code ~ '^(E08|E09|E10|E11|E13|O24)')
                      OR (icd_version = 9  AND icd_code ~ '^(250|6480|6488)') THEN 1 ELSE 0 END) AS hx_diabetes,
           MAX(CASE WHEN (icd_version = 10 AND icd_code ~ '^(E66|O9921)')
                      OR (icd_version = 9  AND icd_code ~ '^(2780|6491)') THEN 1 ELSE 0 END)     AS hx_obesity,
           MAX(CASE WHEN (icd_version = 10 AND icd_code ~ '^N1[7-9]')
                      OR (icd_version = 9  AND icd_code ~ '^58[4-6]') THEN 1 ELSE 0 END)         AS hx_renal_disease,
           MAX(CASE WHEN is_fd AND gap_days >= 365 THEN 1 ELSE 0 END)                            AS hx_prior_fetal_death_1y,
           MIN(CASE WHEN is_fd THEN gap_days END)                                                AS days_since_prior_fd
    FROM   prior_dx
    GROUP  BY hadm_id
),
-- OMR: outpatient measurements in the 365 days before the admission date
omr_raw AS (
    SELECT b.hadm_id, o.chartdate, o.seq_num, o.result_name, o.result_value,
           (b.admittime::date - o.chartdate) AS days_before
    FROM   base b
    JOIN   mimiciv.omr o
           ON o.subject_id = b.subject_id
          AND o.chartdate <  b.admittime::date
          AND o.chartdate >= b.admittime::date - 365
    WHERE  o.result_name IN ('Blood Pressure', 'Weight (Lbs)', 'BMI (kg/m2)')
),
omr_bp_ok AS (
    SELECT hadm_id, chartdate, seq_num, sbp, dbp
    FROM (
        SELECT hadm_id, chartdate, seq_num,
               CASE WHEN result_value ~ '^\s*[0-9]{2,3}\s*/\s*[0-9]{2,3}\s*$'
                    THEN split_part(result_value, '/', 1)::numeric END AS sbp,
               CASE WHEN result_value ~ '^\s*[0-9]{2,3}\s*/\s*[0-9]{2,3}\s*$'
                    THEN split_part(result_value, '/', 2)::numeric END AS dbp
        FROM   omr_raw
        WHERE  result_name = 'Blood Pressure'
    ) t
    WHERE sbp BETWEEN 60 AND 260 AND dbp BETWEEN 30 AND 160 AND sbp > dbp
),
omr_bp_last AS (
    SELECT DISTINCT ON (hadm_id) hadm_id, sbp, dbp
    FROM   omr_bp_ok
    ORDER  BY hadm_id, chartdate DESC, seq_num DESC
),
omr_bp_max AS (
    SELECT hadm_id, MAX(sbp) AS sbp_max, MAX(dbp) AS dbp_max
    FROM   omr_bp_ok
    GROUP  BY hadm_id
),
omr_wt AS (
    SELECT DISTINCT ON (hadm_id) hadm_id, ROUND(w * 0.45359237, 1) AS weight_kg
    FROM (
        SELECT hadm_id, chartdate, seq_num,
               CASE WHEN result_value ~ '^\s*[0-9]+(\.[0-9]+)?\s*$' THEN result_value::numeric END AS w
        FROM   omr_raw
        WHERE  result_name = 'Weight (Lbs)'
    ) t
    WHERE w BETWEEN 70 AND 600
    ORDER  BY hadm_id, chartdate DESC, seq_num DESC
),
omr_bmi AS (
    SELECT DISTINCT ON (hadm_id) hadm_id, v AS bmi
    FROM (
        SELECT hadm_id, chartdate, seq_num,
               CASE WHEN result_value ~ '^\s*[0-9]+(\.[0-9]+)?\s*$' THEN result_value::numeric END AS v
        FROM   omr_raw
        WHERE  result_name = 'BMI (kg/m2)'
    ) t
    WHERE v BETWEEN 12 AND 80
    ORDER  BY hadm_id, chartdate DESC, seq_num DESC
),
omr_n AS (
    SELECT hadm_id, COUNT(DISTINCT chartdate) AS n_visits, MIN(days_before) AS days_since_last
    FROM   omr_raw
    GROUP  BY hadm_id
)
SELECT b.hadm_id,
       COALESCE(h.hx_hypertension, 0)          AS hx_hypertension,
       COALESCE(h.hx_diabetes, 0)              AS hx_diabetes,
       COALESCE(h.hx_obesity, 0)               AS hx_obesity,
       COALESCE(h.hx_renal_disease, 0)         AS hx_renal_disease,
       COALESCE(h.hx_prior_fetal_death_1y, 0)  AS hx_prior_fetal_death_1y,
       h.days_since_prior_fd,
       l.lab_hemoglobin, l.lab_hematocrit, l.lab_platelets, l.lab_wbc, l.lab_mcv, l.lab_rdw,
       l.lab_creatinine, l.lab_alt, l.lab_ast, l.lab_uric_acid, l.lab_urea_nitrogen, l.lab_urine_prot_creat,
       bl.sbp AS omr_sbp_last, bl.dbp AS omr_dbp_last, bm.sbp_max AS omr_sbp_max, bm.dbp_max AS omr_dbp_max,
       wt.weight_kg AS omr_weight_kg_last, bmi.bmi AS omr_bmi_last,
       COALESCE(n.n_visits, 0) AS omr_n_visits_365, n.days_since_last AS omr_days_since_last
FROM   base b
LEFT JOIN hist h         ON h.hadm_id  = b.hadm_id
LEFT JOIN labs l         ON l.hadm_id  = b.hadm_id
LEFT JOIN omr_bp_last bl ON bl.hadm_id = b.hadm_id
LEFT JOIN omr_bp_max bm  ON bm.hadm_id = b.hadm_id
LEFT JOIN omr_wt wt      ON wt.hadm_id = b.hadm_id
LEFT JOIN omr_bmi bmi    ON bmi.hadm_id = b.hadm_id
LEFT JOIN omr_n n        ON n.hadm_id  = b.hadm_id;

-- ----------------------------------------------------------------------------
-- Final table: dataset of Modelo C + the new feature columns
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mimiciv.cohort_fetal_death_dataset_ext;
CREATE TABLE mimiciv.cohort_fetal_death_dataset_ext AS
SELECT c.*,
       f.hx_hypertension, f.hx_diabetes, f.hx_obesity, f.hx_renal_disease,
       f.hx_prior_fetal_death_1y, f.days_since_prior_fd,
       f.lab_hemoglobin, f.lab_hematocrit, f.lab_platelets, f.lab_wbc, f.lab_mcv, f.lab_rdw,
       f.lab_creatinine, f.lab_alt, f.lab_ast, f.lab_uric_acid, f.lab_urea_nitrogen, f.lab_urine_prot_creat,
       f.omr_sbp_last, f.omr_dbp_last, f.omr_sbp_max, f.omr_dbp_max,
       f.omr_weight_kg_last, f.omr_bmi_last, f.omr_n_visits_365, f.omr_days_since_last
FROM   mimiciv.cohort_fetal_death_dataset c
LEFT JOIN mimiciv.cohort_fetal_death_features f ON f.hadm_id = c.hadm_id;

-- ----------------------------------------------------------------------------
-- Checks (expected: 25,736 rows, 154 events; CBC about 45% of rows and about
-- 58% of events; OMR blood pressure about 61% of rows and 56% of events, weight 57%, BMI 41%;
-- 17 admissions with days_since_prior_fd < 90, 5 of them events)
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS admissions, COUNT(DISTINCT hadm_id) AS distinct_admissions,
       SUM(outcome_fetal_death) AS events,
       COUNT(lab_hemoglobin)  AS with_cbc,
       COUNT(lab_hemoglobin) FILTER (WHERE outcome_fetal_death = 1) AS events_with_cbc,
       COUNT(lab_creatinine)  AS with_creatinine,
       COUNT(lab_uric_acid)   AS with_uric_acid,
       SUM(hx_hypertension) AS hx_htn, SUM(hx_diabetes) AS hx_dm, SUM(hx_obesity) AS hx_obes,
       SUM(hx_renal_disease) AS hx_renal, SUM(hx_prior_fetal_death_1y) AS hx_fd_1y,
       COUNT(omr_sbp_last) AS with_omr_bp, COUNT(omr_weight_kg_last) AS with_omr_weight,
       COUNT(omr_bmi_last) AS with_omr_bmi,
       COUNT(omr_sbp_last) FILTER (WHERE outcome_fetal_death = 1) AS events_with_omr_bp,
       COUNT(*) FILTER (WHERE days_since_prior_fd <= 180) AS in_post_event_window,
       COUNT(*) FILTER (WHERE days_since_prior_fd <= 180 AND outcome_fetal_death = 1) AS events_in_window
FROM   mimiciv.cohort_fetal_death_dataset_ext;
