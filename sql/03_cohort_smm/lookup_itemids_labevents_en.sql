-- ============================================================================
-- LOOKUP: LABEVENTS itemids for Modelo A's "laboratory" variables, which are
-- currently only extracted from CHARTEVENTS (ICU-only)
-- ============================================================================
-- English version. Spanish original: lookup_itemids_labevents_es.sql (kept in
-- this same folder).
--
-- Goal: identify, for each lab test, the real itemid(s) in YOUR instance of
-- d_labitems, together with how many records each one has in labevents (to
-- pick the right itemid when there are several variants, e.g. arterial vs.
-- venous blood, or serum vs. plasma).
--
-- Share the full result (all 13 rows) so the extraction for
-- cohort_maternal_dataset can be rewritten to pull these variables from
-- labevents (hospital-wide) instead of only chartevents (ICU-only), leaving
-- the genuinely ICU-only variables (heart_rate, respiratory_rate,
-- o2_saturation, blood pressure, temperature, weight, height, GCS, RASS,
-- PEEP) as they are -- MIMIC-IV has no ward-level vitals table to fall back
-- to for those, only labevents (labs) is hospital-wide.
--
-- 2026-09-17: added anion_gap -- it's a lab value (derived from
-- sodium/chloride/bicarbonate) present in d_labitems/labevents just like the
-- other 12, it had simply been left off the original ILIKE list below.
-- ============================================================================

SELECT dli.itemid, dli.label, dli.fluid, dli.category,
       (SELECT COUNT(*) FROM mimiciv.labevents le WHERE le.itemid = dli.itemid) AS n_labevents_records
FROM   mimiciv.d_labitems dli
WHERE  dli.label ILIKE '%glucose%'
   OR  dli.label ILIKE '%hemoglobin%'
   OR  dli.label ILIKE '%sodium%'
   OR  dli.label ILIKE '%potassium%'
   OR  dli.label ILIKE '%calcium%'
   OR  dli.label ILIKE '%magnesium%'
   OR  dli.label ILIKE '%chloride%'
   OR  dli.label ILIKE '%bicarbonate%'
   OR  dli.label ILIKE '%phosphate%'
   OR  dli.label ILIKE '%creatinine%'
   OR  dli.label ILIKE '%hematocrit%'
   OR  dli.label ILIKE '%lactate%'
   OR  dli.label ILIKE '%anion gap%'
ORDER BY dli.label, n_labevents_records DESC;
