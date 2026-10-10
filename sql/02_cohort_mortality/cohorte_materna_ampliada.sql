-- ============================================================================
-- COHORTE MATERNA AMPLIADA — candidatas para aumentar el N de fallecidas
-- ============================================================================
-- Objetivo: ampliar la cohorte original (23.474 / 23.471 / 36 fallecidas,
-- definida en "Cohort de embarazadas.txt") aplicando 3 de las 4 palancas
-- discutidas en el chat. La 4ta (outcome compuesto "near-miss") se deja
-- para una fase posterior porque cambia la pregunta de investigación y
-- requiere acordar contigo el listado de códigos de morbilidad severa.
--
-- Palancas aplicadas aquí:
--   (1) Se quita el JOIN obligatorio con icustays -> se usa TODA admisión
--       hospitalaria (módulo hosp), no solo las que pasaron por UCI.
--       Se conserva un flag "tuvo_uci" para poder filtrar/comparar después.
--   (2) Se quita la restricción de fecha 2021-10 a 2022-10 (heredada del
--       modelo neonatal, sin razón conocida para el materno). Se deja
--       como filtro opcional comentado por si tu entorno de MIMIC-IV
--       demo/acceso solo tiene datos en cierto rango.
--   (3) Se amplía la detección de diagnóstico obstétrico: al ILIKE por
--       texto (PREGNANCY/OBSTETRIC/FETAL/DELIVERY) se le suma un match
--       por rango/capítulo de código ICD (ICD-9: 630-679, V22-V24,V27,V28;
--       ICD-10: capítulo O00-O9A, Z33/Z34/Z37/Z39), que puede capturar
--       códigos obstétricos cuyo título largo no contiene esas palabras.
--
-- NOTA IMPORTANTE: este script NO se ha ejecutado contra tu base real
-- (localhost:5433, solo accesible desde tu máquina, no desde este entorno).
-- Debes correrlo tú en pgAdmin/psql y compartirme los conteos resultantes
-- antes de decidir el siguiente paso.
--
-- POSIBLE BUG a revisar en el script original: la condición
-- "TO_CHAR(a.admittime,'YYYYMM') <= '221410'" tiene mes '14', que no
-- existe. Probablemente debía ser '221031' (31-oct-2022). Aquí ya no
-- aplica porque se quitó el filtro de fecha, pero si decides reactivarlo
-- revisa ese valor.
--
-- CORRECCIÓN (v2, a partir de tu observación): la tabla PATIENTS de este
-- esquema define DOB explícitamente como "This is a NaN column" (ver
-- mimic_create_database.sql, línea 36) -- solo quedó poblada para los
-- casos que el propio pipeline de neonatos actualizó como fecha sintética
-- de nacimiento del bebé, no como dato demográfico real de cada paciente
-- adulto. Usarla para calcular la edad de la madre filtra mal la cohorte
-- (por eso al comentar el BETWEEN saltó de 36 a 45: dejó de excluir por
-- error a madres cuyo dob nunca se pobló).
--
-- La forma correcta de estimar edad en MIMIC-IV es con ANCHOR_AGE /
-- ANCHOR_YEAR (sí poblados para todo paciente, es el mecanismo oficial
-- de des-identificación de MIMIC-IV): ANCHOR_AGE es la edad del paciente
-- durante ANCHOR_YEAR, y todas sus fechas están desplazadas de forma
-- consistente relativas a ese año. Entonces:
--   edad_en_la_admision = anchor_age + (año(admittime) - anchor_year)
-- (Limitación conocida: pacientes que en algún momento superaron 89 años
-- quedan fijados en anchor_age = 91 por des-identificación; no afecta
-- de forma relevante al rango 12-55 que nos interesa aquí.)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Paso 1: universo ampliado de diagnósticos obstétricos (texto + rango ICD)
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mimiciv.diagnosticos_embarazos_ampliado;

CREATE VIEW mimiciv.diagnosticos_embarazos_ampliado AS
SELECT DISTINCT icd_code, icd_version, long_title
FROM mimiciv.d_icd_diagnoses
WHERE
    -- (a) Coincidencia original por texto del título (cualquier versión ICD)
    long_title ILIKE '%PREGNAN%'
    OR long_title ILIKE '%OBSTETRIC%'
    OR long_title ILIKE '%FETAL%'
    OR long_title ILIKE '%DELIVERY%'
    OR long_title ILIKE '%PUERPERIUM%'
    OR long_title ILIKE '%POSTPARTUM%'
    OR long_title ILIKE '%GESTATION%'

    -- (b) Rango de capítulo ICD-9: complicaciones de embarazo/parto/puerperio
    --     (630-679) y códigos V de supervisión de embarazo/parto (V22-V24,V27,V28)
    OR (
        icd_version = 9
        AND icd_code ~ '^[0-9]'
        AND LEFT(icd_code, 3)::int BETWEEN 630 AND 679
    )
    OR (
        icd_version = 9
        AND LEFT(icd_code, 3) IN ('V22', 'V23', 'V24', 'V27', 'V28')
    )

    -- (c) Capítulo ICD-10 obstétrico completo (O00-O9A) + códigos Z de
    --     estado de embarazo / resultado del parto / atención postparto
    OR (
        icd_version = 10
        AND LEFT(icd_code, 1) = 'O'
    )
    OR (
        icd_version = 10
        AND (icd_code LIKE 'Z33%' OR icd_code LIKE 'Z34%'
             OR icd_code LIKE 'Z37%' OR icd_code LIKE 'Z39%')
    );

-- Chequeo rápido: cuántos códigos añade la vista ampliada vs. la original
-- SELECT count(*) FROM mimiciv.diagnosticos_embarazos_ampliado;   -- ampliada
-- SELECT count(*) FROM mimiciv.diagnosticos_embarazos;            -- original (solo texto)

-- ----------------------------------------------------------------------------
-- Paso 2: cohorte ampliada (sin exigir estancia en UCI, sin restricción de fecha)
-- ----------------------------------------------------------------------------
WITH admisiones_maternas AS (
    SELECT DISTINCT
        a.subject_id,
        a.hadm_id,
        p.gender,
        p.anchor_age,
        p.anchor_year,
        a.admittime,
        a.dischtime,
        a.deathtime            AS deathtime_admision,
        a.hospital_expire_flag,
        -- Edad real en el momento de la admisión (no usar p.dob, ver nota arriba)
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
      -- Filtro de fecha original, comentado. Descomentar solo si tu
      -- instancia de MIMIC-IV requiere acotar el rango:
      -- AND a.admittime BETWEEN '2021-10-01' AND '2022-10-31'
),
cohorte_final AS (
    SELECT
        am.subject_id,
        am.hadm_id,
        am.gender,
        am.admittime,
        am.edad_aprox,
        EXISTS (
            SELECT 1 FROM mimiciv.icustays i
            WHERE i.subject_id = am.subject_id AND i.hadm_id = am.hadm_id
        ) AS tuvo_uci,
        -- outcome: igual lógica que el script original -> murió en esta
        -- admisión o en cualquier admisión posterior con deathtime registrado
        (
            CASE
                WHEN am.deathtime_admision IS NOT NULL THEN am.deathtime_admision
                ELSE (
                    SELECT MIN(a5.deathtime)
                    FROM mimiciv.admissions a5
                    WHERE a5.subject_id = am.subject_id
                      AND a5.deathtime IS NOT NULL
                )
            END
        ) AS deathtime_resuelto
    FROM admisiones_maternas am
)
SELECT
    COUNT(*)                                                   AS total_admisiones,
    COUNT(*) FILTER (WHERE tuvo_uci)                           AS con_uci,
    COUNT(*) FILTER (WHERE NOT tuvo_uci)                       AS sin_uci,
    COUNT(*) FILTER (WHERE deathtime_resuelto IS NOT NULL)     AS total_fallecidas,
    COUNT(*) FILTER (WHERE deathtime_resuelto IS NOT NULL
                      AND tuvo_uci)                            AS fallecidas_con_uci,
    COUNT(*) FILTER (WHERE deathtime_resuelto IS NOT NULL
                      AND NOT tuvo_uci)                        AS fallecidas_sin_uci
FROM cohorte_final;

-- Si quieres el detalle fila a fila (para inspeccionar antes de decidir),
-- corre en vez del SELECT de arriba:
-- SELECT * FROM cohorte_final ORDER BY deathtime_resuelto NULLS LAST;
