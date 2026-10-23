-- ============================================================================
-- FEATURE DISCOVERY for Modelo C (fetal death): which extra predictors exist in
-- MIMIC-IV, how often they are available, and whether they differ between
-- admissions with and without the event.
-- ============================================================================
-- Reads only. Needs mimiciv.cohort_fetal_death_dataset (fetal_death_dataset_en.sql),
-- mimiciv.fetal_death_code_patterns and mimiciv.pregnancy_diagnoses_expanded.
-- Run as a whole script (DBeaver: Alt+X) in ONE connection (temporary table) and
-- share the result of each query.
--
-- TIME RULE (to avoid leakage): a feature is only eligible if it is known at or
-- shortly after arrival -- history from EARLIER admissions of the same patient,
-- admission attributes, and tests/records in the first 24 h from arrival.
-- Diagnoses, procedures, DRG codes and treatments of the SAME admission are not
-- candidates (the event itself generates them: induction, D&E, misoprostol...).
-- Dates are shifted per patient in MIMIC-IV, but order and intervals inside one
-- patient are preserved, so comparisons within a patient are valid.
-- ============================================================================

DROP TABLE IF EXISTS fx_cohort;
CREATE TEMP TABLE fx_cohort AS
SELECT c.subject_id, c.hadm_id, c.outcome_fetal_death AS y, c.fd_strict,
       a.admittime, a.edregtime, a.marital_status,
       LEAST(a.admittime, COALESCE(a.edregtime, a.admittime)) AS t0   -- arrival (ED or ward)
FROM   mimiciv.cohort_fetal_death_dataset c
JOIN   mimiciv.admissions a ON a.hadm_id = c.hadm_id;

-- ----------------------------------------------------------------------------
-- Query 1: marital status and arrival through the ED
-- ----------------------------------------------------------------------------
SELECT 'marital_status' AS feature, COALESCE(marital_status, '(missing)') AS level,
       COUNT(*) AS admissions, SUM(y) AS events, ROUND(100.0*AVG(y), 2) AS event_rate_pct
FROM   fx_cohort GROUP BY 1, 2
UNION ALL
SELECT 'ed_arrival', CASE WHEN edregtime IS NOT NULL THEN 'yes' ELSE 'no' END,
       COUNT(*), SUM(y), ROUND(100.0*AVG(y), 2)
FROM   fx_cohort GROUP BY 1, 2
ORDER  BY 1, 3 DESC;

-- ----------------------------------------------------------------------------
-- Query 2: first hospital service of the admission (OBS = obstetrics, GYN, MED...)
-- ----------------------------------------------------------------------------
WITH first_srv AS (
    SELECT DISTINCT ON (s.hadm_id) s.hadm_id, s.curr_service
    FROM   mimiciv.services s
    JOIN   fx_cohort f ON f.hadm_id = s.hadm_id
    ORDER  BY s.hadm_id, s.transfertime
)
SELECT COALESCE(fs.curr_service, '(no service record)') AS first_service,
       COUNT(*) AS admissions, SUM(f.y) AS events, ROUND(100.0*AVG(f.y), 2) AS event_rate_pct
FROM   fx_cohort f
LEFT JOIN first_srv fs ON fs.hadm_id = f.hadm_id
GROUP  BY 1
ORDER  BY 2 DESC;

-- ----------------------------------------------------------------------------
-- Query 3: first care unit recorded in transfers (first record with a unit)
-- ----------------------------------------------------------------------------
WITH first_unit AS (
    SELECT DISTINCT ON (t.hadm_id) t.hadm_id, t.careunit
    FROM   mimiciv.transfers t
    JOIN   fx_cohort f ON f.hadm_id = t.hadm_id
    WHERE  t.careunit IS NOT NULL
    ORDER  BY t.hadm_id, t.intime
)
SELECT COALESCE(fu.careunit, '(no unit record)') AS first_care_unit,
       COUNT(*) AS admissions, SUM(f.y) AS events, ROUND(100.0*AVG(f.y), 2) AS event_rate_pct
FROM   fx_cohort f
LEFT JOIN first_unit fu ON fu.hadm_id = f.hadm_id
GROUP  BY 1
ORDER  BY 2 DESC;

-- ----------------------------------------------------------------------------
-- Query 4: number of EARLIER admissions of the same patient
-- (how much of the cohort has any history at all)
-- ----------------------------------------------------------------------------
WITH prior AS (
    SELECT f.hadm_id, f.y, COUNT(a2.hadm_id) AS n_prior_adm
    FROM   fx_cohort f
    LEFT JOIN mimiciv.admissions a2
           ON a2.subject_id = f.subject_id AND a2.admittime < f.admittime
    GROUP  BY f.hadm_id, f.y
)
SELECT CASE WHEN n_prior_adm = 0 THEN '0' WHEN n_prior_adm = 1 THEN '1'
            WHEN n_prior_adm <= 3 THEN '2-3' ELSE '4+' END AS prior_admissions,
       COUNT(*) AS admissions, SUM(y) AS events, ROUND(100.0*AVG(y), 2) AS event_rate_pct
FROM   prior
GROUP  BY 1
ORDER  BY 1;

-- ----------------------------------------------------------------------------
-- Query 5: history flags built ONLY from diagnoses of earlier admissions
-- columns: admissions with the flag, events among them, event rate with / without
-- ----------------------------------------------------------------------------
WITH prior_dx AS (
    SELECT f.hadm_id, d.icd_version, d.icd_code
    FROM   fx_cohort f
    JOIN   mimiciv.admissions a2
           ON a2.subject_id = f.subject_id AND a2.admittime < f.admittime
    JOIN   mimiciv.diagnoses_icd d ON d.hadm_id = a2.hadm_id
),
flags AS (
    SELECT p.hadm_id,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^(I1[0-6]|O1[0-6])') OR (icd_version=9 AND icd_code ~ '^(40[1-5]|642)') THEN 1 ELSE 0 END) AS hx_hypertension,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^(E08|E09|E10|E11|E13|O24)') OR (icd_version=9 AND icd_code ~ '^(250|6480|6488)') THEN 1 ELSE 0 END) AS hx_diabetes,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^(E66|O9921)') OR (icd_version=9 AND icd_code ~ '^(2780|6491)') THEN 1 ELSE 0 END) AS hx_obesity,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^(F1[0-9]|O99[3]2)') OR (icd_version=9 AND icd_code ~ '^(30[3-5]|6483)') THEN 1 ELSE 0 END) AS hx_substance_use,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^(F3[2-3]|F41|F43)') OR (icd_version=9 AND icd_code ~ '^(296|300|3090|3091)') THEN 1 ELSE 0 END) AS hx_mental_health,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^J45') OR (icd_version=9 AND icd_code ~ '^493') THEN 1 ELSE 0 END) AS hx_asthma,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^N1[7-9]') OR (icd_version=9 AND icd_code ~ '^58[4-6]') THEN 1 ELSE 0 END) AS hx_renal_disease,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^E0[0-7]') OR (icd_version=9 AND icd_code ~ '^24[0-6]') THEN 1 ELSE 0 END) AS hx_thyroid,
       MAX(CASE WHEN (icd_version=10 AND icd_code ~ '^(M32|D68[5-6]|D686)') OR (icd_version=9 AND icd_code ~ '^(710[0]|2894)') THEN 1 ELSE 0 END) AS hx_lupus_thrombophilia,
       MAX(CASE WHEN EXISTS (SELECT 1 FROM mimiciv.pregnancy_diagnoses_expanded pe
                             WHERE pe.icd_code = p.icd_code AND pe.icd_version = p.icd_version)
                THEN 1 ELSE 0 END) AS hx_prior_obstetric,
       MAX(CASE WHEN EXISTS (SELECT 1 FROM mimiciv.fetal_death_code_patterns fp
                             WHERE fp.icd_version = p.icd_version
                               AND p.icd_code LIKE fp.code_prefix || '%')
                THEN 1 ELSE 0 END) AS hx_prior_fetal_death
    FROM   prior_dx p
    GROUP  BY p.hadm_id
),
x AS (
    SELECT f.y,
           COALESCE(g.hx_hypertension, 0) AS hx_hypertension, COALESCE(g.hx_diabetes, 0) AS hx_diabetes,
           COALESCE(g.hx_obesity, 0) AS hx_obesity, COALESCE(g.hx_substance_use, 0) AS hx_substance_use,
           COALESCE(g.hx_mental_health, 0) AS hx_mental_health, COALESCE(g.hx_asthma, 0) AS hx_asthma,
           COALESCE(g.hx_renal_disease, 0) AS hx_renal_disease, COALESCE(g.hx_thyroid, 0) AS hx_thyroid,
           COALESCE(g.hx_lupus_thrombophilia, 0) AS hx_lupus_thrombophilia,
           COALESCE(g.hx_prior_obstetric, 0) AS hx_prior_obstetric,
           COALESCE(g.hx_prior_fetal_death, 0) AS hx_prior_fetal_death
    FROM   fx_cohort f
    LEFT JOIN flags g ON g.hadm_id = f.hadm_id
)
SELECT 'hx_hypertension' AS history_flag, SUM(hx_hypertension) AS admissions_with_flag, SUM(hx_hypertension*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_hypertension*y)/NULLIF(SUM(hx_hypertension),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_hypertension)*y)/NULLIF(SUM(1-hx_hypertension),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_diabetes' AS history_flag, SUM(hx_diabetes) AS admissions_with_flag, SUM(hx_diabetes*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_diabetes*y)/NULLIF(SUM(hx_diabetes),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_diabetes)*y)/NULLIF(SUM(1-hx_diabetes),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_obesity' AS history_flag, SUM(hx_obesity) AS admissions_with_flag, SUM(hx_obesity*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_obesity*y)/NULLIF(SUM(hx_obesity),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_obesity)*y)/NULLIF(SUM(1-hx_obesity),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_substance_use' AS history_flag, SUM(hx_substance_use) AS admissions_with_flag, SUM(hx_substance_use*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_substance_use*y)/NULLIF(SUM(hx_substance_use),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_substance_use)*y)/NULLIF(SUM(1-hx_substance_use),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_mental_health' AS history_flag, SUM(hx_mental_health) AS admissions_with_flag, SUM(hx_mental_health*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_mental_health*y)/NULLIF(SUM(hx_mental_health),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_mental_health)*y)/NULLIF(SUM(1-hx_mental_health),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_asthma' AS history_flag, SUM(hx_asthma) AS admissions_with_flag, SUM(hx_asthma*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_asthma*y)/NULLIF(SUM(hx_asthma),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_asthma)*y)/NULLIF(SUM(1-hx_asthma),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_renal_disease' AS history_flag, SUM(hx_renal_disease) AS admissions_with_flag, SUM(hx_renal_disease*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_renal_disease*y)/NULLIF(SUM(hx_renal_disease),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_renal_disease)*y)/NULLIF(SUM(1-hx_renal_disease),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_thyroid' AS history_flag, SUM(hx_thyroid) AS admissions_with_flag, SUM(hx_thyroid*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_thyroid*y)/NULLIF(SUM(hx_thyroid),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_thyroid)*y)/NULLIF(SUM(1-hx_thyroid),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_lupus_thrombophilia' AS history_flag, SUM(hx_lupus_thrombophilia) AS admissions_with_flag, SUM(hx_lupus_thrombophilia*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_lupus_thrombophilia*y)/NULLIF(SUM(hx_lupus_thrombophilia),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_lupus_thrombophilia)*y)/NULLIF(SUM(1-hx_lupus_thrombophilia),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_prior_obstetric' AS history_flag, SUM(hx_prior_obstetric) AS admissions_with_flag, SUM(hx_prior_obstetric*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_prior_obstetric*y)/NULLIF(SUM(hx_prior_obstetric),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_prior_obstetric)*y)/NULLIF(SUM(1-hx_prior_obstetric),0),2) AS rate_without_flag_pct
FROM x
UNION ALL
SELECT 'hx_prior_fetal_death' AS history_flag, SUM(hx_prior_fetal_death) AS admissions_with_flag, SUM(hx_prior_fetal_death*y) AS events_with_flag,
       ROUND(100.0*SUM(hx_prior_fetal_death*y)/NULLIF(SUM(hx_prior_fetal_death),0),2) AS rate_with_flag_pct,
       ROUND(100.0*SUM((1-hx_prior_fetal_death)*y)/NULLIF(SUM(1-hx_prior_fetal_death),0),2) AS rate_without_flag_pct
FROM x;

-- ----------------------------------------------------------------------------
-- Query 6: HOSPITAL-WIDE labs (not only ICU) in the first 24 h from arrival:
-- which lab items exist for most admissions? (top 60 by coverage)
-- ----------------------------------------------------------------------------
WITH lab24 AS (
    SELECT f.hadm_id, l.itemid, MAX(f.y) AS y
    FROM   fx_cohort f
    JOIN   mimiciv.labevents l
           ON l.hadm_id = f.hadm_id AND l.valuenum IS NOT NULL
          AND l.charttime BETWEEN f.t0 AND f.t0 + INTERVAL '24 hours'
    GROUP  BY f.hadm_id, l.itemid
)
SELECT d.itemid, d.label, d.fluid, d.category,
       COUNT(*) AS admissions_with_value,
       ROUND(100.0*COUNT(*) / (SELECT COUNT(*) FROM fx_cohort), 1) AS pct_of_cohort,
       SUM(x.y) AS events_with_value,
       ROUND(100.0*SUM(x.y) / (SELECT SUM(y) FROM fx_cohort), 1)   AS pct_of_events
FROM   lab24 x
JOIN   mimiciv.d_labitems d ON d.itemid = x.itemid
GROUP  BY d.itemid, d.label, d.fluid, d.category
ORDER  BY admissions_with_value DESC
LIMIT  60;

-- ----------------------------------------------------------------------------
-- Query 7: microbiology specimens in the first 24 h from arrival (top 15)
-- ----------------------------------------------------------------------------
SELECT m.spec_type_desc,
       COUNT(DISTINCT f.hadm_id) AS admissions,
       COUNT(DISTINCT f.hadm_id) FILTER (WHERE f.y = 1) AS events
FROM   fx_cohort f
JOIN   mimiciv.microbiologyevents m
       ON m.hadm_id = f.hadm_id
      AND COALESCE(m.charttime, m.chartdate::timestamp) BETWEEN f.t0 AND f.t0 + INTERVAL '24 hours'
GROUP  BY 1
ORDER  BY 2 DESC
LIMIT  15;

-- ----------------------------------------------------------------------------
-- Query 8: is the OMR table (outpatient BMI, blood pressure, weight) loaded?
-- The load script of this repository has no COPY for it, so it is probably empty
-- or missing. If this returns TRUE, run the commented coverage query below.
-- ----------------------------------------------------------------------------
SELECT to_regclass('mimiciv.omr') IS NOT NULL AS omr_table_exists;

-- Only if omr_table_exists = TRUE (it fails otherwise, so it is commented out):
-- SELECT o.result_name, COUNT(DISTINCT f.hadm_id) AS admissions,
--        COUNT(DISTINCT f.hadm_id) FILTER (WHERE f.y = 1) AS events
-- FROM   fx_cohort f
-- JOIN   mimiciv.omr o ON o.subject_id = f.subject_id
--                     AND o.chartdate <= f.admittime::date
--                     AND o.chartdate >= f.admittime::date - 365
-- WHERE  o.result_name IN ('BMI (kg/m2)', 'Blood Pressure', 'Weight (Lbs)', 'Height (Inches)')
-- GROUP  BY 1 ORDER BY 2 DESC;

-- ----------------------------------------------------------------------------
-- Query 9: prior fetal-death history -- how long before the index admission?
-- A prior admission only a few months earlier may belong to the SAME pregnancy
-- (diagnosis in one admission, delivery in the next), which would turn the
-- "history" flag into the event itself. Expected for a true previous pregnancy:
-- a gap of about 9 months or more.
-- ----------------------------------------------------------------------------
WITH prior_fd AS (
    SELECT f.hadm_id, f.y,
           MIN(f.admittime::date - a2.admittime::date) AS days_since_prior_fd
    FROM   fx_cohort f
    JOIN   mimiciv.admissions a2
           ON a2.subject_id = f.subject_id AND a2.admittime < f.admittime
    JOIN   mimiciv.hadm_with_fetal_death fd ON fd.hadm_id = a2.hadm_id
    GROUP  BY f.hadm_id, f.y
)
SELECT CASE WHEN days_since_prior_fd < 90  THEN '1) < 90 days'
            WHEN days_since_prior_fd < 180 THEN '2) 90-179 days'
            WHEN days_since_prior_fd < 365 THEN '3) 180-364 days'
            ELSE '4) >= 365 days' END AS gap_to_prior_fetal_death,
       COUNT(*) AS admissions, SUM(y) AS events, ROUND(100.0*AVG(y), 2) AS event_rate_pct
FROM   prior_fd
GROUP  BY 1
ORDER  BY 1;

-- ----------------------------------------------------------------------------
-- Query 10: is OMR (outpatient measurements) actually populated?
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS rows_in_omr, COUNT(DISTINCT subject_id) AS patients,
       MIN(chartdate) AS first_date, MAX(chartdate) AS last_date
FROM   mimiciv.omr;

-- ----------------------------------------------------------------------------
-- Query 11: OMR measurements in the 365 days BEFORE the admission date
-- (outpatient / prenatal-visit vitals: blood pressure, weight, BMI...).
-- They precede the admission, so they cannot be produced by the event itself.
-- ----------------------------------------------------------------------------
SELECT o.result_name,
       COUNT(DISTINCT f.hadm_id) AS admissions,
       ROUND(100.0*COUNT(DISTINCT f.hadm_id) / (SELECT COUNT(*) FROM fx_cohort), 1) AS pct_of_cohort,
       COUNT(DISTINCT f.hadm_id) FILTER (WHERE f.y = 1) AS events,
       ROUND(100.0*COUNT(DISTINCT f.hadm_id) FILTER (WHERE f.y = 1) / (SELECT SUM(y) FROM fx_cohort), 1) AS pct_of_events
FROM   fx_cohort f
JOIN   mimiciv.omr o
       ON o.subject_id = f.subject_id
      AND o.chartdate <  f.admittime::date
      AND o.chartdate >= f.admittime::date - 365
GROUP  BY o.result_name
ORDER  BY admissions DESC
LIMIT  20;
