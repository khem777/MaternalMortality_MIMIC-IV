-- ============================================================================
-- ESTADO (2026-10-25): este script define las etiquetas del manuscrito ENVIADO
-- ============================================================================
-- Se ejecutó en la base local y produjo las 475 admisiones con SMM de la versión
-- enviada. Esa versión tiene dos limitaciones conocidas, corregidas en la
-- revisión; no uses este script para el análisis revisado:
--   (1) Códigos de SMM: solo ICD-10-CM/PCS. MIMIC-IV tiene diagnósticos y
--       procedimientos ICD-9-CM hasta 2015, así que las admisiones ICD-9 se
--       contaron como SMM negativas.
--   (2) Bandera de parto: solo ICD-10 Z37/O80/O82; 8,857 partos, frente a 19,425
--       con la bandera revisada (diagnósticos, procedimientos y DRG, ICD-9 e ICD-10).
-- Definiciones revisadas (lista oficial del CDC en ambas versiones ICD, bandera
-- de parto, etiquetas en la misma admisión): ver sql/06_revision_labels/. Conteos
-- que comparan las dos versiones: sql/05_revision_audit/ y revision_audit_counts.md.
-- Solo se editaron comentarios en este archivo; no se cambió ninguna sentencia SQL.
-- ============================================================================

-- ============================================================================
-- COHORTE "NEAR-MISS" / MORBILIDAD MATERNA SEVERA (SMM) — Modelo B
-- ============================================================================
-- Fuente de los 21 indicadores y códigos ICD-10-CM/PCS: CDC (2023), vía
-- HRSA Federally Available Data (FAD) Resource Document 2023, reproducidos
-- en el Apéndice 1 del reporte "Severe Maternal Morbidity Report 2017-2021"
-- de Nebraska DHHS (jul-2024). Se excluye el indicador de transfusión
-- sanguínea (#18) porque HRSA lo retiró oficialmente en 2023 ("no longer
-- used") -- así que este script usa los 20 indicadores vigentes, igual que
-- hace ese reporte estatal.
--
-- IMPORTANTE: la definición oficial de SMM del CDC se mide sobre
-- "hospitalizaciones de parto" (delivery hospitalizations), no sobre
-- cualquier admisión con diagnóstico obstétrico. Por eso este script
-- calcula el indicador SMM sobre DOS denominadores, para que puedas
-- comparar:
--   (a) Solo hospitalizaciones de parto (con código de resultado de parto
--       Z37.x u O80-O82.x) -- comparable con las tasas publicadas por CDC/
--       estados (58-88 SMM por cada 10.000 partos).
--   (b) Toda la cohorte obstétrica ampliada (maternal_cohort_expanded_es.sql)
--       -- denominador más amplio, más casos absolutos, pero ya no
--       comparable 1:1 con las tasas publicadas.
--
-- (Nota original, reemplazada por el bloque ESTADO de arriba: este script ya se
-- ejecutó en la base local, localhost:5433.)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Paso 1: catálogo de patrones ICD-10 de los 20 indicadores SMM vigentes
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mimiciv.smm_code_patterns;

CREATE TABLE mimiciv.smm_code_patterns (
    indicator_group  VARCHAR(60),
    indicator_name   VARCHAR(60),
    code_type        VARCHAR(2),   -- 'DX' (diagnoses_icd) o 'PR' (procedures_icd)
    code_pattern     VARCHAR(10)   -- prefijo; se compara con icd_code LIKE pattern || '%'
);

INSERT INTO mimiciv.smm_code_patterns (indicator_group, indicator_name, code_type, code_pattern) VALUES
-- 1. Acute myocardial infarction
('Cardiac',  'Acute myocardial infarction', 'DX', 'I21'),
('Cardiac',  'Acute myocardial infarction', 'DX', 'I22'),
-- 2. Aneurysm
('Cardiac',  'Aneurysm', 'DX', 'I71'),
('Cardiac',  'Aneurysm', 'DX', 'I790'),
-- 3. Acute renal failure
('Renal',    'Acute renal failure', 'DX', 'N17'),
('Renal',    'Acute renal failure', 'DX', 'O904'),
-- 4. Adult respiratory distress syndrome
('Respiratory', 'ARDS', 'DX', 'J80'),
('Respiratory', 'ARDS', 'DX', 'J951'),
('Respiratory', 'ARDS', 'DX', 'J952'),
('Respiratory', 'ARDS', 'DX', 'J953'),
('Respiratory', 'ARDS', 'DX', 'J9582'),
('Respiratory', 'ARDS', 'DX', 'J960'),
('Respiratory', 'ARDS', 'DX', 'J962'),
('Respiratory', 'ARDS', 'DX', 'R092'),
-- 5. Amniotic fluid embolism
('Other_Obstetric', 'Amniotic fluid embolism', 'DX', 'O881'),
-- 6. Cardiac arrest / ventricular fibrillation
('Cardiac',  'Cardiac arrest/ventricular fibrillation', 'DX', 'I46'),
('Cardiac',  'Cardiac arrest/ventricular fibrillation', 'DX', 'I490'),
-- 7. Conversion of cardiac rhythm (procedimiento, ICD-10-PCS)
('Cardiac',  'Conversion of cardiac rhythm', 'PR', '5A2204Z'),
('Cardiac',  'Conversion of cardiac rhythm', 'PR', '5A12012'),
-- 8. Disseminated intravascular coagulation
('Hemorrhage', 'DIC', 'DX', 'D65'),
('Hemorrhage', 'DIC', 'DX', 'D688'),
('Hemorrhage', 'DIC', 'DX', 'D689'),
('Hemorrhage', 'DIC', 'DX', 'O723'),
-- 9. Eclampsia
('Other_Obstetric', 'Eclampsia', 'DX', 'O15'),
-- 10. Heart failure/arrest during surgery or procedure
('Cardiac',  'Heart failure/arrest during surgery or procedure', 'DX', 'I9712'),
('Cardiac',  'Heart failure/arrest during surgery or procedure', 'DX', 'I9713'),
('Cardiac',  'Heart failure/arrest during surgery or procedure', 'DX', 'I97710'),
('Cardiac',  'Heart failure/arrest during surgery or procedure', 'DX', 'I97711'),
-- 11. Puerperal cerebrovascular disorders
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I60'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I61'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I62'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I63'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I64'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I65'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I66'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I67'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I68'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'O2251'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'O2252'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'O2253'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I9781'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'I9782'),
('Other_Medical', 'Puerperal cerebrovascular disorders', 'DX', 'O873'),
-- 12. Pulmonary edema / Acute heart failure
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'J810'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I501'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5020'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5021'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5023'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5030'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5031'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5033'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5040'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5041'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I5043'),
('Cardiac',  'Pulmonary edema/acute heart failure', 'DX', 'I509'),
-- 13. Severe anesthesia complications
('Other_Obstetric', 'Severe anesthesia complications', 'DX', 'O740'),
('Other_Obstetric', 'Severe anesthesia complications', 'DX', 'O741'),
('Other_Obstetric', 'Severe anesthesia complications', 'DX', 'O742'),
('Other_Obstetric', 'Severe anesthesia complications', 'DX', 'O743'),
('Other_Obstetric', 'Severe anesthesia complications', 'DX', 'O890'),
('Other_Obstetric', 'Severe anesthesia complications', 'DX', 'O891'),
('Other_Obstetric', 'Severe anesthesia complications', 'DX', 'O892'),
-- 14. Sepsis
('Sepsis',   'Sepsis', 'DX', 'O85'),
('Sepsis',   'Sepsis', 'DX', 'O8604'),
('Sepsis',   'Sepsis', 'DX', 'T80211A'),
('Sepsis',   'Sepsis', 'DX', 'T814XXA'),
('Sepsis',   'Sepsis', 'DX', 'T8144'),
('Sepsis',   'Sepsis', 'DX', 'R6520'),
('Sepsis',   'Sepsis', 'DX', 'A40'),
('Sepsis',   'Sepsis', 'DX', 'A41'),
('Sepsis',   'Sepsis', 'DX', 'A327'),
-- 15. Shock
('Hemorrhage', 'Shock', 'DX', 'O751'),
('Hemorrhage', 'Shock', 'DX', 'R57'),
('Hemorrhage', 'Shock', 'DX', 'R6521'),
('Hemorrhage', 'Shock', 'DX', 'T782XXA'),
('Hemorrhage', 'Shock', 'DX', 'T882XXA'),
('Hemorrhage', 'Shock', 'DX', 'T886XXA'),
('Hemorrhage', 'Shock', 'DX', 'T8110XA'),
('Hemorrhage', 'Shock', 'DX', 'T8111XA'),
('Hemorrhage', 'Shock', 'DX', 'T8119XA'),
-- 16. Sickle cell disease with crisis
('Other_Medical', 'Sickle cell disease with crisis', 'DX', 'D570'),
('Other_Medical', 'Sickle cell disease with crisis', 'DX', 'D5721'),
('Other_Medical', 'Sickle cell disease with crisis', 'DX', 'D5741'),
('Other_Medical', 'Sickle cell disease with crisis', 'DX', 'D5781'),
-- 17. Air and thrombotic embolism
('Other_Obstetric', 'Air and thrombotic embolism', 'DX', 'I26'),
('Other_Obstetric', 'Air and thrombotic embolism', 'DX', 'O880'),
('Other_Obstetric', 'Air and thrombotic embolism', 'DX', 'O882'),
('Other_Obstetric', 'Air and thrombotic embolism', 'DX', 'O883'),
('Other_Obstetric', 'Air and thrombotic embolism', 'DX', 'O888'),
-- 18. Blood products transfusion: EXCLUIDO (retirado por HRSA 2023)
-- 19. Hysterectomy (procedimiento, ICD-10-PCS)
('Hemorrhage', 'Hysterectomy', 'PR', '0UT90ZZ'),
('Hemorrhage', 'Hysterectomy', 'PR', '0UT94ZZ'),
('Hemorrhage', 'Hysterectomy', 'PR', '0UT97ZZ'),
('Hemorrhage', 'Hysterectomy', 'PR', '0UT98ZZ'),
('Hemorrhage', 'Hysterectomy', 'PR', '0UT9FZZ'),
-- 20. Temporary tracheostomy (procedimiento)
('Respiratory', 'Temporary tracheostomy', 'PR', '0B110Z'),
('Respiratory', 'Temporary tracheostomy', 'PR', '0B110F'),
('Respiratory', 'Temporary tracheostomy', 'PR', '0B113'),
('Respiratory', 'Temporary tracheostomy', 'PR', '0B114'),
-- 21. Ventilation (procedimiento)
('Respiratory', 'Ventilation', 'PR', '5A1935Z'),
('Respiratory', 'Ventilation', 'PR', '5A1945Z'),
('Respiratory', 'Ventilation', 'PR', '5A1955Z');

-- ----------------------------------------------------------------------------
-- Paso 2: hadm_id con al menos un indicador SMM (solo ICD-10, como en la versión
-- enviada). MIMIC-IV también tiene datos ICD-9-CM hasta 2015, que este paso no
-- ve; la revisión aplica la lista ICD-9-CM del CDC en sql/06_revision_labels/.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mimiciv.hadm_con_smm;

CREATE VIEW mimiciv.hadm_con_smm AS
SELECT DISTINCT d.subject_id, d.hadm_id, p.indicator_group, p.indicator_name
FROM mimiciv.diagnoses_icd d
JOIN mimiciv.smm_code_patterns p
  ON p.code_type = 'DX'
 AND d.icd_version = 10
 AND d.icd_code LIKE p.code_pattern || '%'
UNION
SELECT DISTINCT pr.subject_id, pr.hadm_id, p.indicator_group, p.indicator_name
FROM mimiciv.procedures_icd pr
JOIN mimiciv.smm_code_patterns p
  ON p.code_type = 'PR'
 AND pr.icd_version = 10
 AND pr.icd_code LIKE p.code_pattern || '%';

-- ----------------------------------------------------------------------------
-- Paso 3: identificar hospitalizaciones de parto (proxy: código de
-- resultado de parto Z37.x, o encuentro de parto O80.x/O82.x)
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mimiciv.hadm_hospitalizacion_parto;

CREATE VIEW mimiciv.hadm_hospitalizacion_parto AS
SELECT DISTINCT d.subject_id, d.hadm_id
FROM mimiciv.diagnoses_icd d
WHERE d.icd_version = 10
  AND (d.icd_code LIKE 'Z37%' OR d.icd_code LIKE 'O80%' OR d.icd_code LIKE 'O82%');

-- ----------------------------------------------------------------------------
-- Paso 4: cohorte final combinando universo obstétrico ampliado (Paso 2 del
-- script maternal_cohort_expanded_es.sql) + outcome SMM + flag de parto
-- ----------------------------------------------------------------------------
WITH admisiones_maternas AS (
    SELECT DISTINCT
        a.subject_id,
        a.hadm_id,
        p.anchor_age + (DATE_PART('year', a.admittime) - p.anchor_year) AS edad_aprox
    FROM mimiciv.admissions a
    JOIN mimiciv.patients p
      ON a.subject_id = p.subject_id
    WHERE p.gender = 'F'
      AND p.anchor_age + (DATE_PART('year', a.admittime) - p.anchor_year) BETWEEN 12 AND 55
      AND (a.subject_id, a.hadm_id) IN (
            SELECT d.subject_id, d.hadm_id
            FROM mimiciv.diagnoses_icd d
            JOIN mimiciv.diagnosticos_embarazos_ampliado de
              ON d.icd_code = de.icd_code
             AND d.icd_version = de.icd_version
      )
)
SELECT
    COUNT(*)                                                          AS total_admisiones_obstetricas,
    COUNT(*) FILTER (WHERE hp.hadm_id IS NOT NULL)                     AS total_hospitalizaciones_parto,
    COUNT(DISTINCT smm.hadm_id)                                        AS total_con_smm_cualquier_admision,
    COUNT(DISTINCT smm.hadm_id) FILTER (WHERE hp.hadm_id IS NOT NULL)  AS total_con_smm_en_parto
FROM admisiones_maternas am
LEFT JOIN mimiciv.hadm_hospitalizacion_parto hp
  ON am.subject_id = hp.subject_id AND am.hadm_id = hp.hadm_id
LEFT JOIN mimiciv.hadm_con_smm smm
  ON am.subject_id = smm.subject_id AND am.hadm_id = smm.hadm_id;

-- Detalle por grupo de complicación (equivalente a la Tabla 6 del reporte
-- de Nebraska), útil para poner en la tesis una tabla comparativa:
-- SELECT indicator_group, count(DISTINCT hadm_id) AS n
-- FROM mimiciv.hadm_con_smm
-- GROUP BY indicator_group
-- ORDER BY n DESC;
