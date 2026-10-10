-- ============================================================================
-- LOOKUP: itemids de LABEVENTS para las variables "de laboratorio" del
-- Modelo A, que actualmente solo se extraen de CHARTEVENTS (exclusivo UCI)
-- ============================================================================
-- Objetivo: identificar, para cada examen, el/los itemid(s) reales en TU
-- instancia de d_labitems, junto con cuántos registros tiene cada uno en
-- labevents (para elegir el itemid correcto si hay varias variantes, p.ej.
-- sangre arterial vs venosa, o suero vs plasma).
--
-- Pásame el resultado completo (las 12 filas de b_conteo_por_examen) y con
-- eso reescribo la extracción de cohort_maternal_dataset para que estas
-- variables salgan de labevents (todo el hospital) en vez de solo
-- chartevents (solo UCI), dejando las genuinamente exclusivas de UCI
-- (heart_rate, respiratory_rate, o2_saturation, presión arterial, GCS,
-- RASS, PEEP) como están.
-- ============================================================================

SELECT dli.itemid, dli.label, dli.fluid, dli.category,
       (SELECT COUNT(*) FROM mimiciv.labevents le WHERE le.itemid = dli.itemid) AS n_registros_labevents
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
ORDER BY dli.label, n_registros_labevents DESC;
