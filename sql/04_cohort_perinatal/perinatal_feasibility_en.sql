-- ============================================================================
-- FEASIBILITY CHECK: perinatal death (fetal-death component) -- Modelo C
-- ============================================================================
-- Goal: count how many admissions of the existing maternal cohort carry an
-- ICD code for fetal death (stillbirth), to decide whether a third model is
-- feasible BEFORE building any dataset.
--
-- Definition under test (WHO / ICD-10 perinatal period): fetal death from 22
-- completed weeks of gestation. Only the fetal component is identifiable from
-- the mother's record; early neonatal deaths live in the newborn's record and
-- are not used here.
--
-- Cohort: mimiciv.cohort_smm_dataset (the 25,736 admissions of Models A and B).
-- This script has NOT been run against the database. It only reads data
-- (temporary table + SELECTs). Run it as a whole script (DBeaver: Alt+X) in ONE
-- connection, because the temporary table must survive between statements,
-- and share the result of each query.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Step 0: code patterns for fetal death
--   strict  = the code says the fetus died (stillbirth / intrauterine death)
--   partial = multiple pregnancy where only some fetuses died; kept apart so
--             you can decide whether to include them
-- Pre-viable losses (abortion, ectopic, missed abortion O02.1, 630-639) are
-- NOT included: they fall below 22 weeks.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fd_patterns;
CREATE TEMP TABLE fd_patterns (
    icd_version INT,
    code_prefix VARCHAR(10),
    tier        VARCHAR(10),
    label       VARCHAR(80)
);

INSERT INTO fd_patterns VALUES
 (10, 'O364', 'strict',  'Maternal care for intrauterine death'),
 (10, 'Z371', 'strict',  'Outcome of delivery: single stillborn'),
 (10, 'Z374', 'strict',  'Outcome of delivery: twins, both stillborn'),
 (10, 'Z377', 'strict',  'Outcome of delivery: other multiple, all stillborn'),
 (10, 'Z373', 'partial', 'Outcome of delivery: twins, one liveborn one stillborn'),
 (10, 'Z376', 'partial', 'Outcome of delivery: other multiple, some liveborn'),
 (10, 'O312', 'partial', 'Continuing pregnancy after intrauterine death of one fetus'),
 (9,  '6564', 'strict',  'Intrauterine death (656.4x)'),
 (9,  'V271', 'strict',  'Outcome of delivery: single stillborn'),
 (9,  'V274', 'strict',  'Outcome of delivery: twins, both stillborn'),
 (9,  'V277', 'strict',  'Outcome of delivery: other multiple, all stillborn'),
 (9,  'V273', 'partial', 'Outcome of delivery: twins, one liveborn one stillborn'),
 (9,  'V276', 'partial', 'Outcome of delivery: other multiple, some liveborn');

-- Admissions of the cohort that carry at least one of those codes
DROP TABLE IF EXISTS fd_hits;
CREATE TEMP TABLE fd_hits AS
SELECT c.subject_id, c.hadm_id, d.icd_version, d.icd_code, d.seq_num,
       p.tier, p.label
FROM   mimiciv.cohort_smm_dataset c
JOIN   mimiciv.diagnoses_icd d
       ON d.subject_id = c.subject_id AND d.hadm_id = c.hadm_id
JOIN   fd_patterns p
       ON p.icd_version = d.icd_version
      AND d.icd_code LIKE p.code_prefix || '%';

-- ----------------------------------------------------------------------------
-- Query 1: cohort size (should be 25,736 admissions, 15,084 patients)
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS admissions, COUNT(DISTINCT subject_id) AS patients
FROM   mimiciv.cohort_smm_dataset;

-- ----------------------------------------------------------------------------
-- Query 2: inventory of the fetal-death codes actually present in the cohort
-- ----------------------------------------------------------------------------
SELECT h.icd_version, h.icd_code, h.tier, dd.long_title,
       COUNT(DISTINCT h.hadm_id) AS admissions
FROM   fd_hits h
LEFT JOIN mimiciv.d_icd_diagnoses dd
       ON dd.icd_code = h.icd_code AND dd.icd_version = h.icd_version
GROUP  BY h.icd_version, h.icd_code, h.tier, dd.long_title
ORDER  BY admissions DESC;

-- ----------------------------------------------------------------------------
-- Query 3: number of events (distinct admissions) under each definition,
-- by ICD version. This is the key number for feasibility.
-- ----------------------------------------------------------------------------
SELECT icd_version,
       COUNT(DISTINCT hadm_id) FILTER (WHERE tier = 'strict')            AS strict_only_admissions,
       COUNT(DISTINCT hadm_id)                                           AS strict_or_partial_admissions,
       COUNT(DISTINCT subject_id) FILTER (WHERE tier = 'strict')         AS strict_patients
FROM   fd_hits
GROUP  BY icd_version
UNION ALL
SELECT NULL,
       COUNT(DISTINCT hadm_id) FILTER (WHERE tier = 'strict'),
       COUNT(DISTINCT hadm_id),
       COUNT(DISTINCT subject_id) FILTER (WHERE tier = 'strict')
FROM   fd_hits;

-- ----------------------------------------------------------------------------
-- Query 4: position of the fetal-death code in the diagnosis list
-- (seq_num 1-4 means it is among the main diagnoses)
-- ----------------------------------------------------------------------------
SELECT CASE WHEN seq_num <= 4 THEN '1-4' WHEN seq_num <= 10 THEN '5-10' ELSE '>10' END AS position,
       COUNT(DISTINCT hadm_id) AS admissions
FROM   fd_hits
WHERE  tier = 'strict'
GROUP  BY 1
ORDER  BY 1;

-- ----------------------------------------------------------------------------
-- Query 5: gestational age (ICD-10 only, codes Z3A.xx = weeks of gestation)
-- among admissions with a strict fetal-death code
-- ----------------------------------------------------------------------------
WITH fd_adm AS (
    SELECT DISTINCT subject_id, hadm_id FROM fd_hits
    WHERE tier = 'strict' AND icd_version = 10
),
weeks AS (
    SELECT f.hadm_id,
           MAX(substring(d.icd_code FROM 4 FOR 2)::INT) AS gest_weeks
    FROM   fd_adm f
    JOIN   mimiciv.diagnoses_icd d
           ON d.subject_id = f.subject_id AND d.hadm_id = f.hadm_id
    WHERE  d.icd_version = 10
      AND  d.icd_code ~ '^Z3A[0-9]{2}'
      AND  substring(d.icd_code FROM 4 FOR 2)::INT >= 8   -- Z3A.00 / Z3A.01 = unspecified / <8 weeks
    GROUP  BY f.hadm_id
)
SELECT CASE WHEN w.gest_weeks IS NULL THEN 'no Z3A code'
            WHEN w.gest_weeks <  22 THEN '< 22 weeks'
            WHEN w.gest_weeks <  28 THEN '22-27 weeks'
            ELSE '>= 28 weeks' END AS gestational_age,
       COUNT(*) AS admissions
FROM   fd_adm f
LEFT JOIN weeks w ON w.hadm_id = f.hadm_id
GROUP  BY 1
ORDER  BY 1;

-- ----------------------------------------------------------------------------
-- Query 6: event rate over the possible denominators
--   (a) the whole cohort, (b) delivery hospitalizations of the cohort
-- ----------------------------------------------------------------------------
SELECT 'whole cohort' AS denominator,
       COUNT(*) AS admissions,
       COUNT(*) FILTER (WHERE c.hadm_id IN (SELECT hadm_id FROM fd_hits WHERE tier = 'strict')) AS strict_events
FROM   mimiciv.cohort_smm_dataset c
UNION ALL
SELECT 'delivery hospitalizations',
       COUNT(*),
       COUNT(*) FILTER (WHERE c.hadm_id IN (SELECT hadm_id FROM fd_hits WHERE tier = 'strict'))
FROM   mimiciv.cohort_smm_dataset c
WHERE  c.is_delivery_hospitalization = 1;

-- ----------------------------------------------------------------------------
-- Query 7: overlap with the existing outcomes (SMM and maternal death)
-- ----------------------------------------------------------------------------
SELECT COUNT(DISTINCT c.hadm_id)                                        AS fetal_death_admissions,
       COUNT(DISTINCT c.hadm_id) FILTER (WHERE c.outcome_smm = 1)       AS also_smm,
       COUNT(DISTINCT c.hadm_id) FILTER (WHERE a.hospital_expire_flag = 1) AS maternal_died_same_admission
FROM   mimiciv.cohort_smm_dataset c
JOIN   mimiciv.admissions a ON a.hadm_id = c.hadm_id
WHERE  c.hadm_id IN (SELECT hadm_id FROM fd_hits WHERE tier = 'strict');

-- ----------------------------------------------------------------------------
-- Query 8: are there fetal-death codes among women's admissions that the
-- current cohort leaves out? (cohort requires an obstetric diagnosis in
-- position <= 4; fetal death may be coded further down.)
-- ----------------------------------------------------------------------------
SELECT COUNT(DISTINCT d.hadm_id) AS strict_admissions_outside_cohort
FROM   mimiciv.diagnoses_icd d
JOIN   fd_patterns p
       ON p.icd_version = d.icd_version
      AND d.icd_code LIKE p.code_prefix || '%'
      AND p.tier = 'strict'
JOIN   mimiciv.patients pt ON pt.subject_id = d.subject_id AND pt.gender = 'F'
WHERE  d.hadm_id NOT IN (SELECT hadm_id FROM mimiciv.cohort_smm_dataset);

-- ----------------------------------------------------------------------------
-- Query 9: strict fetal-death events by ICD version and delivery flag.
-- The flag (view hadm_delivery_hospitalization) only looks for ICD-10 codes
-- (Z37, O80, O82), so ICD-9 admissions can never be flagged as deliveries.
-- Expected if that is the explanation: ICD-9 events all with flag = 0.
-- Run in the same connection as the script (it uses the temp table fd_hits).
-- ----------------------------------------------------------------------------
SELECT h.icd_version,
       c.is_delivery_hospitalization AS delivery_flag,
       COUNT(DISTINCT c.hadm_id)     AS strict_events
FROM   fd_hits h
JOIN   mimiciv.cohort_smm_dataset c ON c.hadm_id = h.hadm_id
WHERE  h.tier = 'strict'
GROUP  BY 1, 2
ORDER  BY 1, 2;
