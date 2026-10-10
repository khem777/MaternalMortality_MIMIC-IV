-- ============================================================================
-- PREGNANCY/OBSTETRIC DIAGNOSES -- NARROW (TEXT-ONLY) MATCH
-- ============================================================================
-- English version. Spanish original: inline in docs/Cohort de embarazadas.txt
-- (the earliest exploratory version of this view, kept only as a working
-- note there -- this is its first standalone, documented copy).
--
-- This is the ORIGINAL, narrower diagnosis-matching view: it flags an ICD
-- code as "obstetric" only when its long_title text contains one of a
-- handful of keywords. sql/02_cohort_mortality/maternal_cohort_expanded_en.sql
-- builds a wider view (pregnancy_diagnoses_expanded) on top of this one by
-- also matching ICD chapter/range, which catches codes whose title doesn't
-- happen to contain these words.
--
-- Kept as a separate, named object (rather than being inlined again) so
-- sql/02_cohort_mortality/maternal_cohort_diagnostic_funnel_en.sql can
-- compare "narrow" vs. "expanded" cohort counts directly, and so
-- notebooks/maternal_mortality_models.ipynb (Section 2.1) can build
-- mimiciv.cohort_maternal from it directly instead of redefining an
-- equivalent view under its old Spanish name (mimiciv.diagnosticos_embarazos).
--
-- Includes icd_version (not just icd_code) so that joins against
-- mimiciv.diagnoses_icd match on the same (icd_code, icd_version) pair used
-- everywhere else in this project (an icd_code string can mean different
-- things under ICD-9 vs. ICD-10).
-- ============================================================================

DROP VIEW IF EXISTS mimiciv.pregnancy_diagnoses_narrow;

CREATE VIEW mimiciv.pregnancy_diagnoses_narrow AS
SELECT DISTINCT icd_code, icd_version, long_title
FROM (
    SELECT icd_code, icd_version, long_title
    FROM   mimiciv.d_icd_diagnoses
    WHERE  long_title ILIKE '%PREGNANCY%'
    UNION
    SELECT icd_code, icd_version, long_title
    FROM   mimiciv.d_icd_diagnoses
    WHERE  long_title ILIKE '%OBSTETRIC%'
    UNION
    SELECT icd_code, icd_version, long_title
    FROM   mimiciv.d_icd_diagnoses
    WHERE  long_title ILIKE '%FETAL%'
    UNION
    SELECT icd_code, icd_version, long_title
    FROM   mimiciv.d_icd_diagnoses
    WHERE  long_title ILIKE '%DELIVERY%'
) x;
