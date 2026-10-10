-- ============================================================================
-- DIAGNOSTIC: why does mimiciv.cohort_maternal only have 384 rows?
-- ============================================================================
-- English version. Spanish original: maternal_cohort_diagnostic_funnel_es.sql
-- (kept in this same folder).
--
-- Rather than keep guessing which filter is the culprit, this script breaks
-- the funnel down filter by filter into a single result row, so we can see
-- exactly where cases are being lost.
--
-- We already know "no date filter, no ICU requirement, expanded diagnosis
-- list" gave 41 deaths (maternal_cohort_expanded_en.sql) -- but the total
-- ADMISSION count from that run was never shared, only the death count, so
-- it can't be compared directly against this table's 384 rows yet. Run
-- this and share the full result row.
--
-- Also re-checking something left unverified: the date filter
-- TO_CHAR(admittime,'YYYYMM') BETWEEN '211001' AND '221410' reads as "year
-- 2110 to year 2214", but it was never confirmed against the real database
-- whether the shifted dates actually fall in that range. If they do NOT,
-- the date filter could be silently discarding 100% of rows -- the same
-- class of bug already found with `dob`. That's why Step 0 checks the real
-- range of admittime first.
--
-- PREREQUISITE: run maternal_pregnancy_diagnoses_narrow_en.sql and
-- maternal_cohort_expanded_en.sql first (they create the
-- pregnancy_diagnoses_narrow / pregnancy_diagnoses_expanded views this
-- script depends on).
-- ============================================================================

-- Step 0: what (shifted) year range do the admissions actually fall in?
SELECT
    MIN(admittime)                         AS min_admittime,
    MAX(admittime)                         AS max_admittime,
    MIN(EXTRACT(YEAR FROM admittime))      AS min_year,
    MAX(EXTRACT(YEAR FROM admittime))      AS max_year,
    COUNT(*) FILTER (
        WHERE TO_CHAR(admittime, 'YYYYMM') BETWEEN '211001' AND '221410'
    )                                       AS admissions_within_current_filter,
    COUNT(*)                               AS total_admissions
FROM mimiciv.admissions;

-- Step 1: full funnel (requires having already run both
-- maternal_cohort_expanded_en.sql -- which creates pregnancy_diagnoses_expanded
-- -- and maternal_pregnancy_diagnoses_narrow_en.sql -- pregnancy_diagnoses_narrow)
WITH women_by_age AS (
    SELECT a.subject_id, a.hadm_id, a.admittime
    FROM   mimiciv.admissions a
    JOIN   mimiciv.patients p ON p.subject_id = a.subject_id
    WHERE  p.gender = 'F'
      AND  p.anchor_age + (DATE_PART('year', a.admittime) - p.anchor_year) BETWEEN 12 AND 55
),
dx_narrow AS (
    SELECT DISTINCT d.subject_id, d.hadm_id
    FROM   mimiciv.diagnoses_icd d
    JOIN   mimiciv.pregnancy_diagnoses_narrow de
      ON   d.icd_code = de.icd_code AND d.icd_version = de.icd_version
),
dx_expanded AS (
    SELECT DISTINCT d.subject_id, d.hadm_id
    FROM   mimiciv.diagnoses_icd d
    JOIN   mimiciv.pregnancy_diagnoses_expanded de
      ON   d.icd_code = de.icd_code AND d.icd_version = de.icd_version
),
icu AS (
    SELECT DISTINCT subject_id, hadm_id FROM mimiciv.icustays
)
SELECT
    (SELECT COUNT(*) FROM women_by_age)                                          AS a_women_12_55,

    (SELECT COUNT(*) FROM women_by_age wa JOIN dx_narrow dn
        ON wa.subject_id = dn.subject_id AND wa.hadm_id = dn.hadm_id)            AS b_dx_narrow_no_date_no_icu,

    (SELECT COUNT(*) FROM women_by_age wa JOIN dx_expanded de
        ON wa.subject_id = de.subject_id AND wa.hadm_id = de.hadm_id)            AS c_dx_expanded_no_date_no_icu,

    (SELECT COUNT(*) FROM women_by_age wa JOIN dx_narrow dn
        ON wa.subject_id = dn.subject_id AND wa.hadm_id = dn.hadm_id
     WHERE TO_CHAR(wa.admittime,'YYYYMM') BETWEEN '211001' AND '221410')         AS d_dx_narrow_WITH_date_no_icu,

    (SELECT COUNT(*) FROM women_by_age wa JOIN dx_expanded de
        ON wa.subject_id = de.subject_id AND wa.hadm_id = de.hadm_id
     WHERE TO_CHAR(wa.admittime,'YYYYMM') BETWEEN '211001' AND '221410')         AS e_dx_expanded_WITH_date_no_icu,

    (SELECT COUNT(*) FROM women_by_age wa JOIN dx_narrow dn
        ON wa.subject_id = dn.subject_id AND wa.hadm_id = dn.hadm_id
     JOIN icu i ON wa.subject_id = i.subject_id AND wa.hadm_id = i.hadm_id
     WHERE TO_CHAR(wa.admittime,'YYYYMM') BETWEEN '211001' AND '221410')         AS f_dx_narrow_WITH_date_WITH_icu_THIS_IS_384,

    (SELECT COUNT(*) FROM women_by_age wa JOIN dx_narrow dn
        ON wa.subject_id = dn.subject_id AND wa.hadm_id = dn.hadm_id
     JOIN icu i ON wa.subject_id = i.subject_id AND wa.hadm_id = i.hadm_id)      AS g_dx_narrow_no_date_WITH_icu,

    (SELECT COUNT(*) FROM women_by_age wa JOIN dx_expanded de
        ON wa.subject_id = de.subject_id AND wa.hadm_id = de.hadm_id
     JOIN icu i ON wa.subject_id = i.subject_id AND wa.hadm_id = i.hadm_id)      AS h_dx_expanded_no_date_WITH_icu;

-- Read the result left to right: a -> (b or c) -> (d or e) -> (f, g or h).
-- Column "f_..._THIS_IS_384" should reproduce exactly the 384 you got -- if
-- it doesn't match, something else changed between this run and yours and
-- needs to be checked. Comparing b vs. c shows how much the expanded
-- diagnosis list adds; comparing b vs. d shows how much the date filter
-- removes; comparing d vs. f shows how much requiring an ICU stay removes
-- (likely the biggest cut of all, since most obstetric admissions do NOT
-- require intensive care).
