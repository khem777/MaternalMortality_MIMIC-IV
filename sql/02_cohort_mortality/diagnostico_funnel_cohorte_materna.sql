-- ============================================================================
-- ESTADO (2026-10-25): diagnóstico HISTÓRICO, no es parte del análisis enviado ni del revisado
-- ============================================================================
-- Embudo exploratorio escrito al depurar una cohorte anterior (384 filas). El
-- filtro de fechas ('211001' a '221410') y el requisito de UCI que prueba NO se
-- usan en la cohorte del manuscrito enviado ni en la revisión (ver
-- cohorte_materna_ampliada.sql y sql/04_labels/).
-- Solo se editaron comentarios en este archivo; no se cambió ninguna sentencia SQL.
-- ============================================================================

-- ============================================================================
-- DIAGNÓSTICO: por qué mimiciv.cohort_maternal solo tiene 384 filas
-- ============================================================================
-- No puedo ejecutar esto contra tu base real (solo accesible desde tu
-- máquina), así que en vez de seguir adivinando qué filtro es el culpable,
-- este script descompone el embudo (funnel) filtro por filtro en una sola
-- fila de resultado, para que veamos exactamente dónde se pierden los casos.
--
-- Ya sé que "sin fecha, sin UCI, con diagnóstico ampliado" te dio 41
-- fallecidas (cohorte_materna_ampliada.sql) -- pero nunca me pasaste el total
-- de ADMISIONES de esa corrida (solo el conteo de fallecidas), así que no
-- puedo comparar directamente contra las 384 de esta tabla. Corre esto y
-- pásame la fila completa.
--
-- También reviso algo que dejé sin verificar: el filtro de fecha
-- TO_CHAR(admittime,'YYYYMM') BETWEEN '211001' AND '221410' -- ya te dije en
-- el mensaje anterior que esto se lee como "año 2110 a año 2214", pero nunca
-- comprobé contra tu base si tus fechas desplazadas realmente caen en ese
-- rango. Si NO caen ahí, el filtro de fecha podría estar descartando
-- silenciosamente el 100% de las filas -- el mismo tipo de bug que ya
-- encontramos con dob. Por eso el Paso 0 revisa el rango real de admittime.
-- ============================================================================

-- Paso 0: ¿en qué rango de años (desplazados) están realmente tus admisiones?
SELECT
    MIN(admittime)                         AS admittime_minimo,
    MAX(admittime)                         AS admittime_maximo,
    MIN(EXTRACT(YEAR FROM admittime))      AS anio_minimo,
    MAX(EXTRACT(YEAR FROM admittime))      AS anio_maximo,
    COUNT(*) FILTER (
        WHERE TO_CHAR(admittime, 'YYYYMM') BETWEEN '211001' AND '221410'
    )                                       AS admisiones_dentro_del_filtro_actual,
    COUNT(*)                               AS admisiones_totales
FROM mimiciv.admissions;

-- Paso 1: embudo completo (requiere haber corrido antes tanto
-- cohorte_materna_ampliada.sql -- que crea diagnosticos_embarazos_ampliado --
-- como el CREATE VIEW original de diagnosticos_embarazos, ya en tu base)
WITH base_mujeres_edad AS (
    SELECT a.subject_id, a.hadm_id, a.admittime
    FROM   mimiciv.admissions a
    JOIN   mimiciv.patients p ON p.subject_id = a.subject_id
    WHERE  p.gender = 'F'
      AND  p.anchor_age + (DATE_PART('year', a.admittime) - p.anchor_year) BETWEEN 12 AND 55
),
dx_narrow AS (
    SELECT DISTINCT d.subject_id, d.hadm_id
    FROM   mimiciv.diagnoses_icd d
    JOIN   mimiciv.diagnosticos_embarazos de
      ON   d.icd_code = de.icd_code AND d.icd_version = de.icd_version
),
dx_ampliada AS (
    SELECT DISTINCT d.subject_id, d.hadm_id
    FROM   mimiciv.diagnoses_icd d
    JOIN   mimiciv.diagnosticos_embarazos_ampliado de
      ON   d.icd_code = de.icd_code AND d.icd_version = de.icd_version
),
icu AS (
    SELECT DISTINCT subject_id, hadm_id FROM mimiciv.icustays
)
SELECT
    (SELECT COUNT(*) FROM base_mujeres_edad)                                   AS a_mujeres_12_55,

    (SELECT COUNT(*) FROM base_mujeres_edad bm JOIN dx_narrow dn
        ON bm.subject_id = dn.subject_id AND bm.hadm_id = dn.hadm_id)         AS b_dx_narrow_sin_fecha_sin_uci,

    (SELECT COUNT(*) FROM base_mujeres_edad bm JOIN dx_ampliada da
        ON bm.subject_id = da.subject_id AND bm.hadm_id = da.hadm_id)         AS c_dx_ampliada_sin_fecha_sin_uci,

    (SELECT COUNT(*) FROM base_mujeres_edad bm JOIN dx_narrow dn
        ON bm.subject_id = dn.subject_id AND bm.hadm_id = dn.hadm_id
     WHERE TO_CHAR(bm.admittime,'YYYYMM') BETWEEN '211001' AND '221410')      AS d_dx_narrow_CON_fecha_sin_uci,

    (SELECT COUNT(*) FROM base_mujeres_edad bm JOIN dx_ampliada da
        ON bm.subject_id = da.subject_id AND bm.hadm_id = da.hadm_id
     WHERE TO_CHAR(bm.admittime,'YYYYMM') BETWEEN '211001' AND '221410')      AS e_dx_ampliada_CON_fecha_sin_uci,

    (SELECT COUNT(*) FROM base_mujeres_edad bm JOIN dx_narrow dn
        ON bm.subject_id = dn.subject_id AND bm.hadm_id = dn.hadm_id
     JOIN icu i ON bm.subject_id = i.subject_id AND bm.hadm_id = i.hadm_id
     WHERE TO_CHAR(bm.admittime,'YYYYMM') BETWEEN '211001' AND '221410')      AS f_dx_narrow_CON_fecha_CON_uci_ESTE_ES_384,

    (SELECT COUNT(*) FROM base_mujeres_edad bm JOIN dx_narrow dn
        ON bm.subject_id = dn.subject_id AND bm.hadm_id = dn.hadm_id
     JOIN icu i ON bm.subject_id = i.subject_id AND bm.hadm_id = i.hadm_id)   AS g_dx_narrow_sin_fecha_CON_uci,

    (SELECT COUNT(*) FROM base_mujeres_edad bm JOIN dx_ampliada da
        ON bm.subject_id = da.subject_id AND bm.hadm_id = da.hadm_id
     JOIN icu i ON bm.subject_id = i.subject_id AND bm.hadm_id = i.hadm_id)   AS h_dx_ampliada_sin_fecha_CON_uci;

-- Lee el resultado de izquierda a derecha: a -> (b o c) -> (d o e) -> (f, g o h).
-- La columna "f_..._ESTE_ES_384" debería reproducir exactamente el 384 que
-- obtuviste -- si no coincide, algo más cambió entre esta corrida y la tuya
-- y hay que revisarlo. Comparando b vs c veremos cuánto suma el diagnóstico
-- ampliado; comparando b vs d veremos cuánto resta el filtro de fecha;
-- comparando d vs f veremos cuánto resta exigir UCI (probablemente el
-- mayor recorte de todos, ya que la mayoría de las admisiones obstétricas
-- NO requieren cuidados intensivos).
