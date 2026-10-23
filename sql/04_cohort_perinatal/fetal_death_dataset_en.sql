-- ============================================================================
-- Modelo C (perinatal death, fetal component): build mimiciv.cohort_fetal_death_dataset
-- ============================================================================
-- Outcome  : fetal death identified from the MOTHER's ICD codes (strict + partial,
--            154 admissions in the feasibility check; 136 strict-only).
-- Population: the same 25,736 admissions of Models A and B
--            (mimiciv.cohort_smm_dataset), so the three models share the cohort.
-- Perinatal period (WHO / ICD-10): from 22 completed weeks. MIMIC-IV has no
-- validated mother-newborn linkage, so early neonatal deaths are NOT captured.
--
-- PREREQUISITE: mimiciv.cohort_smm_dataset exists (sql/03_cohort_smm/smm_dataset_en.sql).
-- This script only ADDS outcome and sensitivity columns to a copy of it; it does
-- not modify the source table. Run as a whole script (DBeaver: Alt+X).
--
-- Columns added (NONE of them is a predictor; the notebook drops them from X):
--   outcome_fetal_death   1 = strict or partial fetal-death code (main outcome)
--   fd_strict             1 = strict code only (sensitivity analysis)
--   admission_icd_version 9 or 10 (era of coding)
--   gest_weeks            gestational weeks from Z3A.xx (ICD-10 only; NULL otherwise)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Step 1: code patterns (persistent table; same list as perinatal_feasibility_en.sql)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mimiciv.fetal_death_code_patterns CASCADE;
CREATE TABLE mimiciv.fetal_death_code_patterns (
    icd_version INT,
    code_prefix VARCHAR(10),
    tier        VARCHAR(10),
    label       VARCHAR(80)
);

INSERT INTO mimiciv.fetal_death_code_patterns VALUES
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

-- ----------------------------------------------------------------------------
-- Step 2: admissions with a fetal-death code (any position in the diagnosis list)
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mimiciv.hadm_with_fetal_death;
CREATE VIEW mimiciv.hadm_with_fetal_death AS
SELECT d.subject_id, d.hadm_id,
       MAX(CASE WHEN p.tier = 'strict' THEN 1 ELSE 0 END) AS has_strict
FROM   mimiciv.diagnoses_icd d
JOIN   mimiciv.fetal_death_code_patterns p
       ON p.icd_version = d.icd_version
      AND d.icd_code LIKE p.code_prefix || '%'
GROUP  BY d.subject_id, d.hadm_id;

-- ----------------------------------------------------------------------------
-- Step 3: final dataset = cohort_smm_dataset + outcome + sensitivity columns
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mimiciv.cohort_fetal_death_dataset;
CREATE TABLE mimiciv.cohort_fetal_death_dataset AS
SELECT c.*,
       CASE WHEN fd.hadm_id IS NOT NULL THEN 1 ELSE 0 END AS outcome_fetal_death,
       COALESCE(fd.has_strict, 0)                         AS fd_strict,
       v.icd_version                                      AS admission_icd_version,
       gw.gest_weeks
FROM   mimiciv.cohort_smm_dataset c
LEFT JOIN mimiciv.hadm_with_fetal_death fd
       ON fd.subject_id = c.subject_id AND fd.hadm_id = c.hadm_id
LEFT JOIN (SELECT hadm_id, MAX(icd_version) AS icd_version
           FROM   mimiciv.diagnoses_icd
           GROUP  BY hadm_id) v
       ON v.hadm_id = c.hadm_id
LEFT JOIN (SELECT hadm_id,
                  MAX(substring(icd_code FROM 4 FOR 2)::INT) AS gest_weeks
           FROM   mimiciv.diagnoses_icd
           WHERE  icd_version = 10
             AND  icd_code ~ '^Z3A[0-9]{2}'
             AND  substring(icd_code FROM 4 FOR 2)::INT >= 8   -- Z3A.00 / Z3A.01 = unspecified / <8 weeks
           GROUP  BY hadm_id) gw
       ON gw.hadm_id = c.hadm_id;

-- ----------------------------------------------------------------------------
-- Step 4: checks (expected: 25,736 rows; 154 events; 136 strict; 2 SMM overlap
-- among strict events; 0 maternal deaths among strict events)
-- ----------------------------------------------------------------------------
SELECT COUNT(*)                                   AS admissions,
       COUNT(DISTINCT hadm_id)                    AS distinct_admissions,
       COUNT(DISTINCT subject_id)                 AS patients,
       SUM(outcome_fetal_death)                   AS events_strict_or_partial,
       SUM(fd_strict)                             AS events_strict,
       ROUND(100.0 * AVG(outcome_fetal_death), 3) AS prevalence_pct
FROM   mimiciv.cohort_fetal_death_dataset;

SELECT admission_icd_version, outcome_fetal_death, fd_strict, COUNT(*) AS admissions
FROM   mimiciv.cohort_fetal_death_dataset
GROUP  BY 1, 2, 3
ORDER  BY 1, 2, 3;
