# Plan del análisis desde cero, según los notebooks de revisión

> **Solo conteos y métricas agregadas.** Este documento no contiene datos a nivel de paciente ni identificadores. Todo proviene de MIMIC-IV v3.1 (PhysioNet, sujeto al acuerdo de uso de datos) y de los notebooks de `notebooks/revision/` y sus informes `outputs_*.txt`.

Cómo se armaría el análisis del artículo sobre morbilidad materna grave (SMM) a 24 horas desde cero, ordenado por fase analítica y explicado solo con lo que hacen los notebooks 01 a 07: definir la cohorte, limpiar y tratar los faltantes, validar, medir, sacar resultados y comprobar su solidez. No incluye el trabajo en SQL ni el del manuscrito. No es parte del manuscrito: sirve para tener claro en qué momento se hizo cada técnica y cuál es su función.

## Cómo leer este documento

El plan tiene 10 fases, 53 pasos y 135 análisis o resultados con detalle. Cada paso indica:

- **Notebook:** de qué notebook sale (por ejemplo, NB 02).
- **Técnicas:** las etiquetas del índice de técnicas (al final).
- **Dónde:** notebook y sección (§) o función donde está el código.
- **Salida:** archivo `outputs_*.txt` con las cifras; los números entre corchetes son las secciones del informe.
- **Referencias:** tarea del plan (T), decisión (D) o comentario de revisor (R1 a R3), solo cuando el notebook las cita.

| Fase | Nombre | Notebooks | Pasos |
|---|---|---|---:|
| [P0](#p0-reglas-y-configuración-común) | Reglas y configuración común | Notebooks 02 a 06, sección 1 | 2 |
| [P1](#p1-definición-de-la-cohorte-y-auditoría-de-conteos) | Definición de la cohorte y auditoría de conteos | Notebooks 01, 02, 05, 06 y 07 | 6 |
| [P2](#p2-limpieza-de-datos-faltantes-y-winsorización) | Limpieza de datos, faltantes y winsorización | Notebooks 02 a 06, secciones 2 y 4 | 7 |
| [P3](#p3-partición-modelos-y-ajuste) | Partición, modelos y ajuste | Notebook 02, secciones 3 a 5 (repetido en 03 a 06) | 7 |
| [P4](#p4-métricas-incertidumbre-y-tamaño-de-muestra) | Métricas, incertidumbre y tamaño de muestra | Notebook 02, secciones 5 y 6 y celdas de Riley | 7 |
| [P5](#p5-resultados-del-análisis-principal) | Resultados del análisis principal | `outputs_main.txt` y `outputs_modelA.txt` | 7 |
| [P6](#p6-análisis-de-sensibilidad) | Análisis de sensibilidad | Notebooks 02 (sección 10), 04 y 06 | 5 |
| [P7](#p7-desbalance-de-clases-sin-corrección-pesos-y-smote-nc) | Desbalance de clases: sin corrección, pesos y SMOTE-NC | Notebook 03 | 4 |
| [P8](#p8-era-versión-de-codificación-y-validación-temporal) | Era, versión de codificación y validación temporal | Notebook 05 | 5 |
| [P9](#p9-temporalidad-de-los-eventos-respecto-del-punto-de-predicción) | Temporalidad de los eventos respecto del punto de predicción | Notebook 07 | 3 |

## P0. Reglas y configuración común

**Dónde:** Notebooks 02 a 06, sección 1.

**Objetivo.** Fijar antes de correr nada lo que hace comparables todos los análisis: semilla, pliegues, repeticiones, bootstrap y reglas de uso de datos.

### 0.1 Parámetros fijos del experimento

*Una sola configuración que los seis notebooks de modelado repiten idéntica.*

**Notebook:** NB 02 a 06  
**Técnicas:** Modelos, ajuste y apilamiento, Métricas e incertidumbre  
**Dónde:** §1 de cada notebook

**Qué se hizo.** Cada notebook abre con el mismo bloque de ajustes. Son el contrato del análisis: cambiarlos cambia todos los resultados, por eso no se tocan entre notebooks.

**Para qué sirve.** Que las diferencias entre análisis se deban solo a lo que se cambió a propósito (población, desenlace, predictores) y nunca a la semilla, al número de repeticiones o al tamaño de los bosques.

Detalle:

- **SEED.** 20260101. De ella salen las particiones externas (semilla + número de repetición) y el resto de las semillas aleatorias. *Para qué:* Reproducibilidad exacta de cada partición.
- **Pliegues.** 5 pliegues externos × 3 repeticiones (15 ajustes externos por modelo) y 3 pliegues internos para elegir hiperparámetros. *Para qué:* Medir también cuánto varía el desarrollo entre repeticiones, no solo entre pliegues.
- **Bootstrap.** B = 1000 en el análisis principal y en las comparaciones pareadas de los notebooks 04 y 05 (con y sin indicador, refits de era); B = 300 en las demás sensibilidades, en la comparación de estrategias del notebook 03 y en los análisis por grupo y temporales del 05. *Para qué:* Intervalos del 95 % por percentiles 2.5 y 97.5.
- **Árboles.** 300 árboles en RF y ET; 200 en XGBoost. *Para qué:* Tamaño fijo para que ningún resultado dependa de un ajuste distinto del número de árboles.
- **Límites.** APPLY_LIMITS = True: los valores fuera de los límites de plausibilidad del diccionario pasan a faltante. *Para qué:* Ver la fase P2.
- **Categóricas.** Cinco: etnia, seguro, idioma, tipo de admisión y lugar de procedencia (ethnicity, insurance, language, `admission_type`, `admission_location`). *Para qué:* Predictores administrativos disponibles al ingreso.
- **Umbrales.** Ocho umbrales para la curva de decisión: 0.5 %, 1 %, 2 %, 3 %, 5 %, 10 %, 15 % y 20 %. *Para qué:* Cubrir desde el cribado muy sensible hasta el aviso selectivo.
- **EXPECTED.** Conteos certificados que cada notebook compara al cargar: 19,383 partos elegibles, 445 SMM y 3 muertes. *Para qué:* Detenerse si la población no es la auditada. Ver 1.2.

### 0.2 Reglas de uso de datos y modo de prueba (QUICK)

*Solo se imprimen agregados; el único archivo escrito es un informe de texto con conteos y métricas.*

**Notebook:** NB 01 a 07  
**Técnicas:** Auditoría de conteos  
**Dónde:** Celda inicial de cada notebook  
**Salida:** `outputs_*.txt`  
**Referencias:** DUA, T43

**Qué se hizo.** Cada notebook declara sus reglas en la primera celda. Ningún notebook muestra, exporta ni guarda filas, identificadores ni fechas. Los notebooks ya ejecutados no se modifican: los nuevos viven en notebooks/revision. El notebook 01 no escribe nada en disco y el 07 solo hace consultas de lectura. Los informes `outputs_*.txt` están cubiertos por .gitignore.

**Para qué sirve.** Cumplir el acuerdo de uso de datos de MIMIC-IV y poder publicar el código sin riesgo.

Detalle:

- **QUICK.** Con QUICK = True el notebook corre una prueba de humo: 3 pliegues × 1 repetición, B = 50 (30 en sensibilidades) y bosques de 60 y 50 árboles. Nunca se reporta una cifra de ese modo. *Para qué:* Detectar errores en minutos antes de la corrida larga.
- **Un archivo.** Cada análisis escribe un solo archivo con el nombre `outputs_<análisis>.txt`. *Para qué:* Un entregable por análisis que se pega o se cita sin exponer datos.

## P1. Definición de la cohorte y auditoría de conteos

**Dónde:** Notebooks 01, 02, 05, 06 y 07.

**Objetivo.** Dejar claro quién entra a cada análisis y comprobar con conteos que cada población, evento y partición es la que dice el texto.

### 1.1 Reconstruir el análisis enviado y medir el solapamiento de pacientes

*Cuántos pacientes estaban a la vez en entrenamiento y prueba en la versión enviada.*

**Notebook:** NB 01  
**Técnicas:** Auditoría de conteos, Partición por paciente  
**Dónde:** 01 · §2 a §7  
**Salida:** Solo pantalla (última celda)  
**Referencias:** T43, R1-4, R2-2

**Qué se hizo.** El notebook lee solo `subject_id`, `hadm_id` y la etiqueta enviada de las dos tablas originales (Modelo A de mortalidad y Modelo B de SMM). Reproduce las particiones tal como se hicieron y cuenta el solapamiento. No cambia ningún modelo, etiqueta ni base.

**Para qué sirve.** Es la evidencia para los comentarios de fuga por paciente. Cuantificarla justifica pasar a la validación agrupada de la fase P3.

Detalle:

- **§2 Carga.** Se leen tres columnas. Se verifican los positivos esperados: 41 en el Modelo A y 475 en el Modelo B. *Para qué:* Confirmar que se parte de las etiquetas enviadas.
- **§3 Réplica.** Se repite el orden por `subject_id`, el hold-out 80/20 con semilla 42 estratificado y la validación cruzada de 5 pliegues con semilla 42. Se comparan tamaños y eventos con lo enviado (Modelo B: 20,588 en entrenamiento con 380 eventos y 5,148 en prueba con 95). *Para qué:* Probar que la réplica coincide en tamaños y eventos antes de interpretar nada.
- **§4 Pacientes.** Admisiones por paciente: porcentaje con más de una, mediana, máximo, positivos por paciente con evento. *Para qué:* Mostrar que los pacientes repiten admisiones y por qué importa agrupar.
- **§5 y §6.1.** Solapamiento en el hold-out: pacientes de prueba que también están en entrenamiento, admisiones de prueba con su paciente en entrenamiento, positivos cuyo paciente tiene una admisión (o una positiva) en entrenamiento. Resultado: 59.3 % de los pacientes de prueba del Modelo A y 58.3 % del B. *Para qué:* Cifra que va a la carta.
- **§6.2.** Lo mismo en cada pliegue de la validación cruzada enviada. En la mortalidad, 23 de 41 eventos tenían su paciente en otros pliegues, y un paciente aportaba hasta 6 positivos. *Para qué:* Mostrar que el problema no era solo del hold-out.
- **§6.3.** Simulación independiente del orden: 1,000 particiones hold-out (semillas 0 a 999) y 200 repeticiones de 5 pliegues, con mediana y percentiles 2.5 a 97.5. Mediana de admisiones de prueba con su paciente en entrenamiento: 60.1 %. *Para qué:* Que el resultado no dependa del orden físico de las filas ni de una semilla.
- **§7 Resumen.** Un bloque corto con las cifras de la carta, sin identificadores. *Para qué:* Pegar solo esa salida.

### 1.2 Cargar la tabla de predictores y verificar los conteos esperados

*Cada notebook comprueba al cargar que la población es la auditada.*

**Notebook:** NB 02 a 06  
**Técnicas:** Auditoría de conteos, Definición de cohorte  
**Dónde:** 02 · §2; 03 a 06 · §2

**Qué se hizo.** Se lee `predictors_24h_v2` (una fila por hospitalización obstétrica, con los predictores observados en la ventana de 24 horas antes a 24 horas después del ingreso) y `predictor_dictionary_final_v2` (rol de cada variable y límites de plausibilidad). Los indicadores lógicos nulos se tratan como falso. Una aserción imprime OK o CHECK contra los conteos esperados.

**Para qué sirve.** Una población equivocada daría resultados que parecen válidos. Con esta comprobación todos los análisis parten de la misma cohorte certificada por la auditoría de conteos.

Detalle:

- **Partos elegibles.** 19,383 hospitalizaciones de parto elegibles a las 24 horas, de 13,710 pacientes. *Para qué:* Denominador del análisis principal.
- **SMM.** 445 con morbilidad materna grave (2.30 %). *Para qué:* Eventos del análisis principal.
- **Muertes.** 3 muertes en la misma admisión entre los partos elegibles. *Para qué:* Muy pocas para modelar: ver 5.7.
- **Cualquier obstétrica.** 23,625 admisiones elegibles de 14,602 pacientes, con 814 SMM y 5 muertes. *Para qué:* Población de la sensibilidad `any_obstetric`.

### 1.3 Definir la población de cada análisis

*Una función, `make_spec`, decide quién entra a cada variante y qué predictores usa.*

**Notebook:** NB 02 a 06  
**Técnicas:** Definición de cohorte, Sensibilidad  
**Dónde:** 02 · §3 `make_spec`; 04 a 06 · §3  
**Referencias:** D4, T50

**Qué se hizo.** Cada análisis es una especificación (población, predictores, desenlace). Parte siempre de las admisiones elegibles a las 24 horas. Las columnas constantes se descartan, porque un indicador que nunca varía no aporta información. Las columnas que faltan en la tabla también se descartan.

**Para qué sirve.** Que cada variante cambie una sola cosa y que quede escrito cuál. Los resultados de cada una están en la fase P6.

Detalle:

- **main.** Partos elegibles. 19,383 admisiones, 13,710 pacientes, 445 eventos (2.30 %). *Para qué:* Análisis principal.
- **first_admission.** Solo la primera hospitalización de parto de cada paciente, si es elegible. 13,701 admisiones, 13,701 pacientes, 356 eventos (2.60 %). *Para qué:* Quitar el efecto de admisiones repetidas.
- **any_obstetric.** Admisiones obstétricas elegibles, con o sin parto. 23,625 admisiones, 14,602 pacientes, 814 eventos (3.45 %). *Para qué:* Ver si la conclusión depende de limitar a partos.
- **no_icu_24h.** Partos elegibles sin ingreso a UCI en las primeras 24 horas. 19,268 admisiones, 13,632 pacientes, 355 eventos (1.84 %). *Para qué:* Retirar a las pacientes ya críticas al punto de predicción.
- **icd10_only.** Partos cuyos diagnósticos son todos ICD-10-CM, sin ningún ICD-9-CM (decisión D4). 8,864 admisiones, 7,070 pacientes, 271 eventos (3.06 %). *Para qué:* Quitar el cambio de versión de codificación.
- **label_ge2.** Misma población y predictores; el desenlace pasa a ser dos o más indicadores de SMM. 129 eventos (0.67 %). *Para qué:* Un desenlace más estricto.
- **excl_renal_only.** Partos elegibles menos los que tienen la insuficiencia renal aguda como único indicador. 19,233 admisiones, 13,610 pacientes, 295 eventos (1.53 %). Se retiran de la población; no se reetiquetan como no eventos. *Para qué:* No tratar morbilidad real como salud.
- **labs_extended e icu_vars.** Misma población que main con más predictores (laboratorio y UCI, cada uno con su indicador de faltante). *Para qué:* Ver si más variables mejoran la predicción.

### 1.4 Partos no elegibles y muertes antes del punto de predicción

*Dos comprobaciones de consistencia con conteos ya certificados.*

**Notebook:** NB 07  
**Técnicas:** Auditoría de conteos, Temporalidad, Definición de cohorte  
**Dónde:** 07 · §3  
**Salida:** `outputs_smm_timing.txt`  
**Referencias:** T52, R3-2, R3-3

**Qué se hizo.** Consultas de lectura sobre `predictors_24h_v2` y admissions. La primera cuenta los partos que terminaron antes de las 24 horas y por eso no son elegibles. La segunda clasifica las muertes hospitalarias del universo obstétrico según ocurrieron antes de T (admisión + 24 horas) o desde T.

**Para qué sirve.** Explicar por qué se pasa de 19,425 partos a 19,383 elegibles y por qué algunas muertes quedan fuera del análisis. Ambas cifras entran al manuscrito.

Detalle:

- **No elegibles.** 42 partos terminaron antes de las 24 horas: 2 con SMM y 1 con muerte. *Para qué:* Cuadra 19,425 − 42 = 19,383, 447 − 2 = 445 y 4 − 1 = 3.
- **Muertes.** 10 muertes hospitalarias en el universo obstétrico: 5 antes de T (1 en parto y 4 en otra admisión obstétrica) y 5 desde T (3 en parto y 2 en otra). *Para qué:* Mostrar que la mitad de las muertes ocurrieron antes de que el modelo pudiera predecirlas.

### 1.5 SMM por número de indicadores y por versión ICD

*Cuántas de las 445 admisiones con SMM se apoyan solo en la insuficiencia renal aguda.*

**Notebook:** NB 06  
**Técnicas:** Auditoría de conteos, Definición de cohorte, Sensibilidad  
**Dónde:** 06 · §3b  
**Salida:** `outputs_excl_renal_only.txt`  
**Referencias:** T50, R2-14, R2-15, R1-9

**Qué se hizo.** Se cruzan las admisiones elegibles con `cohort_obstetric_v2` (`smm_only_renal`, `smm_n_indicators`, `has_icd9_dx`, `has_icd10_dx`). Se imprime una tabla por población (todas, solo ICD-9, solo ICD-10) con admisiones, SMM, SMM solo por insuficiencia renal, SMM que quedan tras excluirlas y porcentaje, y la distribución del número de indicadores (1, 2, 3, 4 o más). Dos aserciones comprueban que la población y los eventos del análisis restan exactamente esas admisiones.

**Para qué sirve.** La insuficiencia renal aguda es el indicador más frecuente y el único en cerca de un tercio de los SMM (150 de 445, 33.7 %), y la creatinina es un predictor principal. Había que cuantificarlo antes de la sensibilidad de P6.

### 1.6 Prevalencia por grupo de años y versión ICD

*Cómo cambia la frecuencia de SMM con el tiempo y con la versión de codificación.*

**Notebook:** NB 05  
**Técnicas:** Auditoría de conteos, Era y validación temporal, Definición de cohorte  
**Dónde:** 05 · §2; 05 · celda 7.4  
**Salida:** `outputs_era_temporal.txt`  
**Referencias:** T47, R1-3, R2-6, R2-17

**Qué se hizo.** Se une `anchor_year_group` (tabla patients) y la versión ICD de cada admisión (ICD-9 solo, ICD-10 solo, mixta). Se imprimen admisiones, pacientes, eventos y prevalencia por grupo, y la tabla cruzada de admisiones por grupo y versión. Se comprueba que ningún grupo falte ni quede fuera del orden esperado.

**Para qué sirve.** Antes de preguntar si el modelo aprende la época, hay que ver que la prevalencia sube con ella. Es la razón de ser de la fase P8.

Detalle:

- **2008–2010.** 8,212 admisiones, 5,536 pacientes, 121 eventos (1.47 %).
- **2011–2013.** 4,328 admisiones, 2,977 pacientes, 86 eventos (1.99 %).
- **2014–2016.** 3,569 admisiones, 2,507 pacientes, 104 eventos (2.91 %).
- **2017–2019.** 2,343 admisiones, 1,813 pacientes, 81 eventos (3.46 %).
- **2020–2022.** 931 admisiones, 877 pacientes, 53 eventos (5.69 %).
- **ICD-9 / ICD-10.** Solo ICD-9: 10,519 admisiones, 174 eventos (1.65 %). Solo ICD-10: 8,864 admisiones, 271 eventos (3.06 %). El cambio de octubre de 2015 cae dentro de 2014–2016, que tiene 2,552 admisiones ICD-10 y 1,017 ICD-9. *Para qué:* Época y versión de codificación están en parte confundidas.

## P2. Limpieza de datos, faltantes y winsorización

**Dónde:** Notebooks 02 a 06, secciones 2 y 4.

**Objetivo.** Convertir las variables en una matriz sin valores imposibles y con los faltantes tratados, sin que nada aprendido de un paciente de prueba toque el entrenamiento.

### 2.1 Roles de las variables en el diccionario

*El diccionario dice qué variable va en el modelo principal y cuál solo en una sensibilidad.*

**Notebook:** NB 02 a 06  
**Técnicas:** Faltantes e indicadores, Definición de cohorte  
**Dónde:** 02 · §2

**Qué se hizo.** `predictor_dictionary_final_v2` asigna a cada variable un rol: modelo principal, solo sensibilidad de UCI o sensibilidad de laboratorio. También marca para cuáles lleva indicador de faltante el modelo principal y da sus límites de plausibilidad.

**Para qué sirve.** Que los predictores del modelo principal estén fijados antes de ver resultados y que las sensibilidades solo añadan variables declaradas.

Detalle:

- **Modelo principal.** Tres numéricas (edad al ingreso, hemoglobina y creatinina), un indicador de faltante de creatinina y cinco categóricas administrativas. *Para qué:* Es el modelo que se reporta.
- **Solo UCI.** Variables de UCI, solo en la sensibilidad `icu_vars`, más la bandera `icu_in_24h`.
- **Laboratorio.** Hematocrito y otras variables de laboratorio, solo en `labs_extended`.

### 2.2 Límites de plausibilidad: lo imposible pasa a faltante

*Un valor fuera del rango fisiológico se trata como no medido, no como un valor extremo real.*

**Notebook:** NB 02 a 06  
**Técnicas:** Limpieza y winsorización, Faltantes e indicadores  
**Dónde:** 02 · §2; 05 · §2  
**Referencias:** D16

**Qué se hizo.** Para cada variable con límites inferior y superior en el diccionario, los valores fuera de ese intervalo se reemplazan por faltante. Se imprime cuántos valores se cambian por variable. El interruptor APPLY_LIMITS permite apagar el paso. En el código, los límites figuran como propuestas pendientes de confirmación clínica.

**Para qué sirve.** Evitar que un error de captura arrastre a la winsorización y a la imputación. Se hace antes de calcular los indicadores de faltante.

### 2.3 Indicadores de faltante, fila por fila

*Una columna 0/1 por variable que dice si el valor está ausente.*

**Notebook:** NB 02 a 06  
**Técnicas:** Faltantes e indicadores  
**Dónde:** 02 · §2; 06 · §2  
**Referencias:** R2-7, R2-20

**Qué se hizo.** Para las variables del modelo principal (solo creatinina), y en las sensibilidades también para las de laboratorio y de UCI, se crea la columna `<variable>_missing` como 1 si el valor está ausente. Se calcula después de los límites de plausibilidad, de modo que un valor fuera de rango también queda marcado. Se calcula fila por fila desde el valor de esa misma fila, así que no cruza información entre pacientes. Además se crea `icu_in_24h_bin`. En `make_spec` se descartan los indicadores que no varían.

**Para qué sirve.** En MIMIC-IV la creatinina se mide a quien se sospecha enfermo; que falte es información. El indicador la recoge de forma explícita y permite medir cuánto pesa (ver 6.4).

### 2.4 Winsorización dentro del entrenamiento

*Recortar cada numérica a los percentiles 0.5 y 99.5 calculados solo con los datos de entrenamiento.*

**Notebook:** NB 02 a 06  
**Técnicas:** Limpieza y winsorización  
**Dónde:** 02 · §4 clase Winsor

**Qué se hizo.** La clase Winsor es el primer paso del bloque numérico del pipeline. En el ajuste calcula los percentiles 0.5 y 99.5 de cada columna (ignorando los faltantes) y en la transformación recorta los valores por fuera. Los percentiles se aprenden con el entrenamiento de cada ajuste y se aplican igual a los datos de prueba. Solo actúa sobre las numéricas: indicadores y categóricas pasan sin cambio.

**Para qué sirve.** Limitar la influencia de valores extremos reales sin mirar los datos de prueba. Si los percentiles se calcularan con todos los datos, se filtraría información de prueba al entrenamiento.

### 2.5 Imputación, escalado y codificación dentro del pipeline

*Todo lo que aprende de los datos se ajusta de nuevo en cada entrenamiento.*

**Notebook:** NB 02 a 06  
**Técnicas:** Faltantes e indicadores, Modelos, ajuste y apilamiento  
**Dónde:** 02 · §4 `make_prep`

**Qué se hizo.** Un ColumnTransformer con tres ramas. Numéricas: Winsor, imputación por mediana (conserva columnas totalmente vacías) y estandarización. Indicadores: pasan sin cambio. Categóricas: los faltantes se rellenan con la categoría «missing» y se codifican en columnas 0/1, agrupando las categorías con menos del 1 % en una categoría «infrecuente»; una categoría nueva en prueba cae en esa misma.

**Para qué sirve.** Imputar con la mediana del entrenamiento (nunca la de prueba) evita fuga. La categoría «missing» conserva el hecho de que no se registró.

Detalle:

- **Parámetros.** El modelo principal queda con 32 parámetros candidatos: 3 numéricos, 1 indicador y 28 columnas 0/1 de las cinco categóricas. *Para qué:* Es el P que usa el criterio de tamaño de muestra (ver 4.7).

### 2.6 Qué información codifica el indicador de creatinina

*La disponibilidad de creatinina sigue de cerca la gravedad y el ingreso a UCI.*

**Notebook:** NB 04  
**Técnicas:** Faltantes e indicadores, Auditoría de conteos  
**Dónde:** 04 · §8 [4]  
**Salida:** `outputs_no_indicator.txt`  
**Referencias:** R2-7, R2-20

**Qué se hizo.** Se imprime la proporción de creatinina presente en las partos elegibles, por desenlace y por ingreso a UCI en las primeras 24 horas.

**Para qué sirve.** Mostrar que el indicador dice quién fue examinado, no solo qué valor tuvo. Es la base de la sensibilidad con y sin indicador.

Detalle:

- **Por desenlace.** Creatinina presente en 20.5 % del total, 19.5 % de quienes no tuvieron SMM y 62.9 % de quienes sí. *Para qué:* Cuantifica cuánta información lleva el hecho de medirla.
- **Por UCI.** Presente en 96.5 % con ingreso a UCI en 24 horas y en 20.0 % sin ingreso. *Para qué:* La medición está atada al nivel de atención.

### 2.7 Conjunto de predictores de cada variante

*Cuántas variables numéricas, binarias y categóricas usa cada análisis.*

**Notebook:** NB 02 a 05  
**Técnicas:** Faltantes e indicadores, Sensibilidad  
**Dónde:** 02 · §3; 04 · §3; 05 · §3

**Qué se hizo.** El encabezado de cada informe imprime el conteo de variables numéricas, binarias y categóricas de su análisis.

**Para qué sirve.** Verificar de un vistazo que cada variante cambió lo previsto y nada más.

Detalle:

- **main.** 3 numéricas, 1 binaria y 5 categóricas.
- **labs_extended.** 14 numéricas, 12 binarias y 5 categóricas. *Para qué:* Más laboratorios, cada uno con su indicador.
- **icu_vars.** 17 numéricas, 16 binarias y 5 categóricas. *Para qué:* Más variables de UCI, con sus indicadores y la bandera de UCI.
- **main_noind.** 3 numéricas, 0 binarias y 5 categóricas. *Para qué:* Sin el indicador de creatinina.
- **main_noadmin.** 3 numéricas, 1 binaria y ninguna categórica. *Para qué:* Sin las cinco variables administrativas.
- **main_plus_era.** 3 numéricas, 1 binaria y 6 categóricas. *Para qué:* Añade el grupo de años como diagnóstico.

## P3. Partición, modelos y ajuste

**Dónde:** Notebook 02, secciones 3 a 5 (repetido en 03 a 06).

**Objetivo.** Diseñar la validación para que ningún paciente quede a ambos lados y para que todo lo que se aprende, incluida la calibración, se aprenda solo con el entrenamiento.

### 3.1 Partición externa agrupada por paciente, 5 × 3

*Cada paciente aparece en un solo pliegue por repetición.*

**Notebook:** NB 02  
**Técnicas:** Partición por paciente, Auditoría de conteos  
**Dónde:** 02 · `run_cv`  
**Salida:** `outputs_main.txt` [0]  
**Referencias:** T43, R1-4, R2-2

**Qué se hizo.** StratifiedGroupKFold con `subject_id` como grupo, 5 pliegues, semilla = SEED + repetición, 3 repeticiones. Una aserción comprueba que ningún paciente esté en entrenamiento y prueba a la vez. Se imprime el registro de cada partición: admisiones, pacientes y eventos de entrenamiento y prueba, y pacientes compartidos. También se imprime el tiempo proyectado después del primer pliegue.

**Para qué sirve.** Corrige la fuga medida en 1.1. Con estratos por evento se mantiene la prevalencia en cada pliegue.

Detalle:

- **Pliegue 1.** Entrenamiento: 15,538 admisiones, 10,978 pacientes, 364 eventos. Prueba: 3,845 admisiones, 2,732 pacientes, 81 eventos. Pacientes compartidos: 0. *Para qué:* Ejemplo de la repetición 1.
- **15 particiones.** Pacientes de prueba por pliegue entre 2,732 y 2,748; pacientes con evento por pliegue de prueba entre 70 y 109; pacientes en ambos lados: 0. *Para qué:* Resultado de la aserción.

### 3.2 Pipeline sin fuga

*Lo que aprende de los datos se aprende dentro del entrenamiento de cada ajuste.*

**Notebook:** NB 02 a 06  
**Técnicas:** Partición por paciente, Modelos, ajuste y apilamiento  
**Dónde:** 02 · §4  
**Referencias:** R1-4, R2-2

**Qué se hizo.** Winsorización, imputación, escalado y codificación se ajustan en un Pipeline una vez por ajuste. Los hiperparámetros se eligen con validación interna agrupada. El metaaprendiz del conjunto se entrena con predicciones fuera de muestra de los modelos base. El calibrador se entrena con predicciones fuera de muestra de los pacientes de entrenamiento. Los pacientes de prueba solo se puntúan.

**Para qué sirve.** Es lo que hace que la estimación externa sea honesta. Cada una de esas piezas aprende de datos que no incluyen a los pacientes que se evalúan.

### 3.3 Modelos base y rejillas de hiperparámetros

*Regresión logística, bosque aleatorio, árboles extra y XGBoost con rejillas pequeñas y declaradas de antemano.*

**Notebook:** NB 02  
**Técnicas:** Modelos, ajuste y apilamiento  
**Dónde:** 02 · GRID  
**Salida:** `outputs_main.txt` [7]

**Qué se hizo.** Cada modelo tiene una rejilla corta. Las rejillas se ampliaron una vez después de la primera corrida, porque se había elegido el borde de la rejilla; el cambio quedó documentado en el código.

**Para qué sirve.** Comparar un modelo lineal con tres de árboles bajo el mismo procedimiento, con rejillas lo bastante amplias para no favorecer a ninguno.

Detalle:

- **LR.** C en 0.01, 0.1 y 1; pesos de clase ninguno o balanceados. *Para qué:* Línea base interpretable.
- **RF.** Profundidad 2, 4 u 8; pesos de clase ninguno o `balanced_subsample`; mínimo 20 por hoja.
- **ET.** Profundidad 4, 8 o 12.
- **XGB.** Profundidad 1, 2 o 4; `scale_pos_weight` 1 o raíz de negativos entre positivos; tasa de aprendizaje 0.05, submuestra 0.8, columnas 0.8, peso mínimo por hoja 5.

### 3.4 Ajuste anidado de hiperparámetros

*La elección de hiperparámetros ocurre dentro del entrenamiento, también agrupada por paciente.*

**Notebook:** NB 02  
**Técnicas:** Modelos, ajuste y apilamiento, Partición por paciente  
**Dónde:** 02 · `tune_stack_calibrate`  
**Salida:** `outputs_main.txt` [7]

**Qué se hizo.** Dentro de cada entrenamiento externo, un StratifiedGroupKFold interno de 3 pliegues puntúa cada combinación de la rejilla. El criterio es la precisión promedio (AUPRC) de las predicciones fuera de muestra agrupadas. La combinación elegida se reajusta con todo el entrenamiento.

**Para qué sirve.** Elegir con AUPRC es coherente con un desenlace raro. Hacerlo dentro de cada entrenamiento evita que la prueba influya en la elección.

Detalle:

- **Elegidos.** En 15 ajustes externos, ET eligió profundidad 12 en 12; RF profundidad 4 en 11; LR C = 1.0 en 7 y C = 0.1 en 6; XGBoost profundidad 2 con raíz en 8. *Para qué:* Muestra qué tanto varía la elección y que no se pegó al borde.

### 3.5 Apilamiento explícito

*El conjunto combina a los cuatro modelos con un metaaprendiz entrenado solo con predicciones fuera de muestra.*

**Notebook:** NB 02  
**Técnicas:** Modelos, ajuste y apilamiento  
**Dónde:** 02 · `tune_stack_calibrate`

**Qué se hizo.** Las predicciones fuera de muestra de los cuatro modelos, en escala logit, alimentan una regresión logística (C = 0.1) que aprende cómo combinarlas. Para entrenar el calibrador se usan predicciones del metaaprendiz obtenidas también fuera de muestra (validación cruzada dentro del entrenamiento). Los modelos base se reajustan con todo el entrenamiento para puntuar la prueba.

**Para qué sirve.** Es el modelo «conjunto» del manuscrito. Entrenar el metaaprendiz con predicciones dentro de muestra le haría confiar demasiado en los modelos más sobreajustados.

### 3.6 Recalibración de Platt

*Una regresión logística de un predictor corrige la escala de la probabilidad.*

**Notebook:** NB 02  
**Técnicas:** Calibración, Modelos, ajuste y apilamiento  
**Dónde:** 02 · platt; `tune_stack_calibrate`  
**Salida:** `outputs_main.txt` [2]

**Qué se hizo.** El calibrador (Platt) se ajusta con las predicciones fuera de muestra de los pacientes de entrenamiento y se aplica a los de prueba. Se calcula también el conjunto sin recalibrar (Stack_raw) para medir qué aporta el paso.

**Para qué sirve.** Que las probabilidades se lean como riesgos. Stack_raw permite comprobar que la recalibración no cambia la discriminación.

Detalle:

- **Stack_raw.** AUROC 0.789 y AUPRC 0.167, iguales a los del conjunto recalibrado; pendiente 1.01 y O/E 1.00 en ambos. *Para qué:* El paso de Platt no altera la ordenación.

### 3.7 Hiperparámetros elegidos en los bucles internos

*Cada informe lista qué configuración eligió cada modelo en los 15 ajustes externos.*

**Notebook:** NB 02 a 06  
**Técnicas:** Modelos, ajuste y apilamiento, Auditoría de conteos  
**Dónde:** 02 · report [7]  
**Salida:** `outputs_*.txt` [7]

**Qué se hizo.** La tabla cuenta, por modelo y configuración, en cuántos de los 15 ajustes externos se eligió.

**Para qué sirve.** Comprobar que la elección es estable y que no se pega a un borde de la rejilla.

## P4. Métricas, incertidumbre y tamaño de muestra

**Dónde:** Notebook 02, secciones 5 y 6 y celdas de Riley.

**Objetivo.** Definir de antemano cómo se mide cada resultado y qué tan seguro es, incluido si hay eventos suficientes para el modelo.

### 4.1 Discriminación y error global

*AUROC, AUPRC y Brier sobre las predicciones fuera de muestra.*

**Notebook:** NB 02  
**Técnicas:** Métricas e incertidumbre  
**Dónde:** 02 · `metrics_one`  
**Salida:** `outputs_main.txt` [1]

**Qué se hizo.** Las métricas se calculan con las predicciones fuera de muestra agrupadas de cada repetición y luego se promedian entre las tres repeticiones. Se informa también la desviación estándar entre repeticiones.

**Para qué sirve.** Con una prevalencia de 2.30 % el AUROC solo no basta. La AUPRC de un modelo sin información es igual a la prevalencia y es la referencia contra la que se lee. La desviación entre repeticiones mide cuánto depende el resultado de la partición.

Detalle:

- **AUROC.** Probabilidad de que un caso con SMM reciba más riesgo que uno sin SMM. *Para qué:* Discriminación global.
- **AUPRC.** Precisión promedio; referencia no informativa = prevalencia. *Para qué:* Más sensible que el AUROC a lo que pasa entre los casos de mayor riesgo.
- **Brier.** Error cuadrático medio de la probabilidad. *Para qué:* Mezcla discriminación y calibración.
- **SD entre repeticiones.** Desviación estándar de AUROC y AUPRC entre las tres repeticiones. *Para qué:* Inestabilidad del desarrollo.

### 4.2 Calibración: pendiente, CITL, O/E, ECE y deciles

*Cinco miradas a si la probabilidad predicha coincide con la frecuencia observada.*

**Notebook:** NB 02  
**Técnicas:** Calibración, Métricas e incertidumbre  
**Dónde:** 02 · `calib_slope`, citl, `metrics_one`, `decile_table`  
**Salida:** `outputs_main.txt` [2], [8]

**Qué se hizo.** La pendiente y el CITL se estiman por Newton con pesos. El ECE usa 10 intervalos por cuantiles. Hay además una tabla por deciles de riesgo y un gráfico de calibración que solo se muestra en pantalla.

**Para qué sirve.** Un modelo con buena discriminación puede dar probabilidades inútiles. La recalibración de 3.6 se evalúa con estas medidas.

Detalle:

- **Pendiente.** Regresión logística del desenlace sobre el logit predicho. Ideal 1. *Para qué:* Mide si el modelo exagera o atenúa el riesgo.
- **CITL.** Intercepto con pendiente fija en 1. Ideal 0. *Para qué:* Mide el sesgo global.
- **O/E.** Eventos observados entre esperados. Ideal 1. *Para qué:* Mismo sesgo en forma de razón.
- **ECE.** Error de calibración esperado con 10 intervalos por cuantiles. *Para qué:* Resumen de la distancia entre curva y diagonal.
- **Deciles.** Riesgo medio predicho y observado por decil (media entre repeticiones). *Para qué:* Lo que se dibuja en la figura de calibración.

### 4.3 Bootstrap por conglomerados de pacientes

*Los intervalos remuestrean pacientes, no filas.*

**Notebook:** NB 02  
**Técnicas:** Métricas e incertidumbre, Partición por paciente  
**Dónde:** 02 · bootstrap  
**Referencias:** R1-4, R2-2

**Qué se hizo.** En cada réplica se remuestrean pacientes con reemplazo y todas las admisiones de un paciente entran juntas, con pesos igual al número de veces que sale cada paciente. Con esos pesos se recalcula cada métrica. El intervalo del 95 % sale de los percentiles 2.5 y 97.5.

**Para qué sirve.** Una paciente con varias admisiones no es independiente de sí misma. Remuestrear filas daría intervalos demasiado angostos.

Detalle:

- **B.** 1,000 réplicas en el análisis principal; 300 en las sensibilidades. *Para qué:* Ver 0.1.

### 4.4 Diferencias pareadas entre modelos

*Las diferencias se calculan en las mismas muestras de bootstrap.*

**Notebook:** NB 02  
**Técnicas:** Métricas e incertidumbre, Modelos, ajuste y apilamiento  
**Dónde:** 02 · bootstrap, PAIRS  
**Salida:** `outputs_main.txt` [3]

**Qué se hizo.** Se comparan cinco pares: RF − LR, ET − LR, XGB − LR, conjunto − LR y conjunto − XGB. En cada réplica se resta una métrica de la otra con los mismos pacientes remuestreados, y el intervalo sale de la distribución de esas diferencias. Se hace para AUROC, AUPRC, Brier y beneficio neto.

**Para qué sirve.** Dos intervalos que se solapan no dicen si la diferencia es real. La diferencia pareada sí lo dice, porque comparte el ruido de la muestra.

### 4.5 Eventos capturados en el 5 % y 10 % de mayor riesgo y curva de decisión

*Dos formas de leer la utilidad: a quién se señala y qué se gana al señalarlo.*

**Notebook:** NB 02  
**Técnicas:** Utilidad clínica, Métricas e incertidumbre  
**Dónde:** 02 · `top_threshold`, `metrics_one`  
**Salida:** `outputs_main.txt` [4], [5]

**Qué se hizo.** Se fija el umbral que deja al 5 % (y al 10 %) de las admisiones con mayor riesgo, y se calculan la sensibilidad y el valor predictivo positivo. Para la curva de decisión se calcula el beneficio neto en ocho umbrales (de 0.5 % a 20 %) y se compara con tratar a todas y con no tratar a ninguna.

**Para qué sirve.** El AUROC no dice cuántos eventos se recuperan al vigilar a una fracción pequeña. La curva de decisión muestra en qué umbrales el modelo supera a las alternativas simples.

### 4.6 Desempeño por ingreso a UCI en las primeras 24 horas

*Las mismas predicciones, evaluadas por separado en quienes ya están en UCI y en quienes no.*

**Notebook:** NB 02  
**Técnicas:** Utilidad clínica, Métricas e incertidumbre  
**Dónde:** 02 · `all_metrics` strata  
**Salida:** `outputs_main.txt` [6]

**Qué se hizo.** Con las predicciones de las particiones principales se calculan AUROC y AUPRC dentro de cada estrato (con UCI en 24 horas y sin UCI).

**Para qué sirve.** Las pacientes en UCI al punto de predicción ya están graves; mezclarlas puede inflar el desempeño global. El estrato sin UCI es el que corresponde a la predicción temprana.

### 4.7 Tamaño de muestra: criterios de Riley

*Cuántos pacientes y eventos exigiría el modelo de SMM y el de mortalidad.*

**Notebook:** NB 02  
**Técnicas:** Tamaño de muestra  
**Dónde:** 02 · funciones riley, `p_max`, `riley_block`, `count_parameters`, `r2cs_from_oof`  
**Salida:** `outputs_main.txt` (Riley); `outputs_modelA.txt`

**Qué se hizo.** Se cuenta el número de parámetros candidatos (32) y se calculan los criterios de Riley: retracción, optimismo y precisión del riesgo global (con márgenes de ±0.05 y ±0.01). En el Modelo B (SMM) el R² de Cox–Snell se estima del resultado observado por validación cruzada de la regresión logística. En el Modelo A (mortalidad) no se entrena nada: se suponen valores de R² del 15 %, 30 % y 50 % del máximo posible.

**Para qué sirve.** Dejar escrito que el SMM tiene eventos suficientes y que la mortalidad no, y por qué esta última no se modela.

## P5. Resultados del análisis principal

**Dónde:** `outputs_main.txt` y `outputs_modelA.txt`.

**Objetivo.** Lo que salió al aplicar las fases P1 a P4 al análisis principal: 19,383 partos elegibles y 445 eventos.

### 5.1 Discriminación y error global

*El conjunto y XGBoost quedan en AUROC cerca de 0.79; la regresión logística, en 0.78.*

**Notebook:** NB 02  
**Técnicas:** Métricas e incertidumbre  
**Dónde:** `outputs_main.txt` [1]  
**Salida:** `outputs_main.txt`

**Qué se hizo.** Medias entre repeticiones con intervalos del 95 % por bootstrap de pacientes. Prevalencia 0.0230, que es también la AUPRC de un modelo sin información.

**Para qué sirve.** Es la tabla de rendimiento del manuscrito.

Detalle:

- **LR.** AUROC 0.780 (0.757–0.803), AUPRC 0.154 (0.125–0.192), Brier 0.02087.
- **RF.** AUROC 0.777 (0.750–0.801), AUPRC 0.158 (0.130–0.195), Brier 0.02075.
- **ET.** AUROC 0.770 (0.745–0.795), AUPRC 0.151 (0.124–0.185), Brier 0.02090.
- **XGB.** AUROC 0.791 (0.767–0.816), AUPRC 0.163 (0.135–0.202), Brier 0.02073.
- **Conjunto.** AUROC 0.789 (0.765–0.813), AUPRC 0.167 (0.138–0.206), Brier 0.02066. *Para qué:* AUPRC unas 7 veces la prevalencia.

### 5.2 Calibración

*Los cinco modelos quedan bien calibrados tras el paso de Platt.*

**Notebook:** NB 02  
**Técnicas:** Calibración  
**Dónde:** `outputs_main.txt` [2], [8]  
**Salida:** `outputs_main.txt`

**Qué se hizo.** Pendientes entre 0.99 y 1.02, CITL cercano a 0 y O/E igual a 1.00 o 1.01. Por deciles, el riesgo predicho sigue al observado, con el último decil en 0.107 predicho y 0.106 observado para la regresión logística, y 0.111 y 0.119 para el conjunto.

**Para qué sirve.** Que las probabilidades puedan leerse como riesgos.

Detalle:

- **Pendiente.** LR 0.99 (0.92–1.07), XGB 1.02 (0.95–1.10), conjunto 1.01 (0.93–1.08).
- **O/E.** 1.00 en LR, XGB y conjunto; 1.01 en RF.
- **Decil 1.** Conjunto: predicho 0.0054 y observado 0.0041. *Para qué:* El extremo bajo, con pocos eventos.
- **Decil 10.** Conjunto: predicho 0.1107 y observado 0.1186. *Para qué:* El extremo alto, donde se concentra el riesgo.

### 5.3 Diferencias pareadas

*El conjunto supera a la regresión logística por una diferencia pequeña, y no se distingue de XGBoost.*

**Notebook:** NB 02  
**Técnicas:** Métricas e incertidumbre, Modelos, ajuste y apilamiento  
**Dónde:** `outputs_main.txt` [3]  
**Salida:** `outputs_main.txt`

**Qué se hizo.** Diferencias de AUROC y AUPRC con intervalo del 95 % pareado.

**Para qué sirve.** Es la respuesta honesta a si el modelo complejo aporta algo.

Detalle:

- **Conjunto − LR.** AUROC +0.009 (0.002 a 0.016); AUPRC +0.013 (0.003 a 0.023); Brier −0.00021 (−0.00037 a −0.00006).
- **XGB − LR.** AUROC +0.011 (0.004 a 0.020); AUPRC +0.009 (−0.002 a 0.021).
- **RF − LR.** AUROC −0.003 (−0.013 a 0.006); AUPRC +0.004 (−0.014 a 0.022).
- **ET − LR.** AUROC −0.009 (−0.019 a 0.000); AUPRC −0.004 (−0.022 a 0.014).
- **Conjunto − XGB.** AUROC −0.002 (−0.006 a 0.001); AUPRC +0.003 (−0.001 a 0.008).

### 5.4 Eventos capturados en el 5 % y 10 % de mayor riesgo

*Al vigilar al 10 % de mayor riesgo se captura cerca de la mitad de los eventos.*

**Notebook:** NB 02  
**Técnicas:** Utilidad clínica  
**Dónde:** `outputs_main.txt` [4]  
**Salida:** `outputs_main.txt`

**Qué se hizo.** Sensibilidad (y valor predictivo positivo) al señalar al 5 % y al 10 % con mayor riesgo predicho.

**Para qué sirve.** Traduce la discriminación a una cifra operativa.

Detalle:

- **Conjunto, 5 %.** Sensibilidad 0.354 (0.316–0.399), valor predictivo positivo 0.163.
- **Conjunto, 10 %.** Sensibilidad 0.517 (0.476–0.559), valor predictivo positivo 0.119.
- **LR, 5 % y 10 %.** Sensibilidad 0.333 (0.292–0.374) y 0.461 (0.417–0.506). *Para qué:* Línea base.

### 5.5 Curva de decisión

*Desde el umbral de 2 % el conjunto supera con claridad a tratar a todas.*

**Notebook:** NB 02  
**Técnicas:** Utilidad clínica  
**Dónde:** `outputs_main.txt` [5]  
**Salida:** `outputs_main.txt`

**Qué se hizo.** Beneficio neto por umbral de decisión, comparado con tratar a todas y con no tratar a ninguna, y diferencias pareadas.

**Para qué sirve.** Mostrar el rango de umbrales en que usar el modelo tiene sentido.

Detalle:

- **Umbral 0.5 %.** Conjunto 0.01814, tratar a todas 0.01805: prácticamente iguales. *Para qué:* Con un umbral tan bajo, tratar a todas es casi óptimo.
- **Umbral 5 %.** Conjunto 0.00717; tratar a todas −0.02846.
- **Conjunto − LR.** Umbral 2 %: +0.00047 (0.00013 a 0.00081). Umbral 5 %: +0.00129 (0.00076 a 0.00188). *Para qué:* Diferencias pareadas.

### 5.6 Estratos de UCI

*El desempeño cae en la población sin UCI, que es la de la predicción temprana.*

**Notebook:** NB 02  
**Técnicas:** Utilidad clínica  
**Dónde:** `outputs_main.txt` [6]  
**Salida:** `outputs_main.txt`

**Qué se hizo.** Mismas predicciones, evaluadas por estrato.

**Para qué sirve.** Mostrar que parte del desempeño global viene de pacientes ya críticas.

Detalle:

- **Con UCI en 24 h.** 115 admisiones y 90 eventos. AUROC LR 0.544 (0.416–0.664) y conjunto 0.610 (0.479–0.725). *Para qué:* Estrato pequeño: los intervalos son anchos.
- **Sin UCI en 24 h.** 19,268 admisiones y 355 eventos. AUROC LR 0.743 (0.716–0.771) y conjunto 0.749 (0.722–0.777); AUPRC 0.101 y 0.109. *Para qué:* Es la población de interés para la predicción temprana.

### 5.7 Tamaño de muestra y viabilidad de la mortalidad

*El SMM tiene eventos de sobra para 32 parámetros; la mortalidad, no.*

**Notebook:** NB 02  
**Técnicas:** Tamaño de muestra  
**Dónde:** `outputs_main.txt` (Riley); `outputs_modelA.txt`  
**Salida:** `outputs_main.txt`; `outputs_modelA.txt`

**Qué se hizo.** Criterios de Riley aplicados al modelo de SMM con R² observado y al de mortalidad con R² supuesto.

**Para qué sirve.** Justificar por qué se modela SMM y la mortalidad solo se reporta como factibilidad.

Detalle:

- **Modelo B (SMM).** 445 eventos y 32 parámetros: 13.91 eventos por parámetro. R² de Cox–Snell observado 0.0311 (máximo 0.1964). Tamaño exigido 9,112 admisiones y 209 eventos; disponibles 19,383 y 445. Máximo de parámetros que soportan los datos: 68.1. *Para qué:* Cumple.
- **Modelo A (mortalidad).** 3 eventos y 32 parámetros: 0.09 eventos por parámetro. Tamaño exigido: 635,433 admisiones con 15 % del R² máximo, 317,637 con 30 % y 211,688 con 50 %; disponibles 19,383. Máximo de parámetros: 1.0, 2.0 y 3.3. *Para qué:* No cumple en ningún escenario.
- **Regla práctica.** Diez eventos por parámetro exigirían 320 muertes; hay 3. *Para qué:* Por eso la mortalidad no se modela.

## P6. Análisis de sensibilidad

**Dónde:** Notebooks 02 (sección 10), 04 y 06.

**Objetivo.** Repetir el análisis principal cambiando una sola cosa, para ver si la conclusión (el conjunto supera por poco a la regresión logística) se sostiene.

### 6.1 Cambia la población

*Cuatro variantes que cambian quién entra y dejan igual el modelo y los predictores.*

**Notebook:** NB 02  
**Técnicas:** Sensibilidad, Definición de cohorte  
**Dónde:** 02 · §10  
**Salida:** `outputs_first_admission.txt`; `outputs_any_obstetric.txt`; `outputs_no_icu_24h.txt`; `outputs_icd10_only.txt`  
**Referencias:** D4

**Qué se hizo.** Se aplica el mismo procedimiento (partición agrupada 5 × 3, ajuste anidado, apilamiento, Platt, bootstrap de B = 300) a cada población. Los resultados son el AUROC del conjunto con su intervalo y la diferencia pareada conjunto − LR.

**Para qué sirve.** Ver si la conclusión depende de admisiones repetidas, de limitar a partos, de las pacientes ya en UCI o del cambio de codificación.

Detalle:

- **first_admission.** Una admisión por paciente. Conjunto AUROC 0.786 (0.761–0.812), AUPRC 0.159. Conjunto − LR en AUROC +0.008 (0.002 a 0.014). *Para qué:* Sin admisiones repetidas.
- **any_obstetric.** Cualquier admisión obstétrica. Conjunto AUROC 0.830 (0.814–0.847), AUPRC 0.267. Conjunto − LR +0.011 (0.005 a 0.016). *Para qué:* Población más amplia y de mayor prevalencia (3.45 %).
- **no_icu_24h.** Sin ingreso a UCI en 24 h. Conjunto AUROC 0.754 (0.727–0.782), AUPRC 0.112. Conjunto − LR +0.016 (0.008 a 0.025). *Para qué:* La población de la predicción temprana.
- **icd10_only.** Solo ICD-10-CM. Conjunto AUROC 0.779 (0.747–0.813), AUPRC 0.208. Conjunto − LR +0.009 (−0.000 a 0.022). *Para qué:* Sin el cambio de versión.

### 6.2 Cambia la definición del desenlace

*Dos formas de volver el desenlace más estricto.*

**Notebook:** NB 02 y 06  
**Técnicas:** Sensibilidad  
**Dónde:** 02 · §10; 06 · §4  
**Salida:** `outputs_label_ge2.txt`; `outputs_excl_renal_only.txt`  
**Referencias:** T50, R2-14, R2-15, R1-9

**Qué se hizo.** `label_ge2` exige dos o más indicadores de SMM. `excl_renal_only` retira de la población a las admisiones cuyo único indicador es la insuficiencia renal aguda; las que tienen insuficiencia renal más otro indicador siguen como eventos.

**Para qué sirve.** La insuficiencia renal es el indicador más frecuente y la creatinina es un predictor principal; había que ver si el modelo sobrevive sin esa circularidad posible.

Detalle:

- **label_ge2.** 129 eventos (0.67 %). Conjunto AUROC 0.848 (0.814–0.884), AUPRC 0.081. Conjunto − LR en AUROC +0.008 (−0.002 a 0.020) y en AUPRC +0.013 (0.002 a 0.024). *Para qué:* Pocos eventos: los intervalos son anchos.
- **excl_renal_only.** 295 eventos en 19,233 admisiones (1.53 %). Conjunto AUROC 0.795 (0.765–0.822), AUPRC 0.110. Conjunto − LR +0.004 (−0.002 a 0.010). *Para qué:* Sin las admisiones que solo tienen insuficiencia renal, el AUROC no baja.

### 6.3 Cambian los predictores

*Dos variantes que añaden variables a la misma población.*

**Notebook:** NB 02  
**Técnicas:** Sensibilidad, Faltantes e indicadores  
**Dónde:** 02 · §10  
**Salida:** `outputs_labs_extended.txt`; `outputs_icu_vars.txt`

**Qué se hizo.** `labs_extended` añade hematocrito y otras variables de laboratorio, cada una con su indicador de faltante. `icu_vars` añade las variables de UCI, con sus indicadores, y la bandera de UCI.

**Para qué sirve.** Ver cuánto mejora la predicción con más información y si la conclusión sobre el modelo cambia.

Detalle:

- **labs_extended.** 14 numéricas y 12 binarias. Conjunto AUROC 0.823 (0.799–0.846), AUPRC 0.332. Conjunto − LR +0.006 (−0.001 a 0.012). *Para qué:* Más información de laboratorio sube el desempeño de los dos modelos.
- **icu_vars.** 17 numéricas y 16 binarias. Conjunto AUROC 0.797 (0.770–0.821), AUPRC 0.322. Conjunto − LR +0.011 (0.003 a 0.018). *Para qué:* Con variables de UCI.

### 6.4 Con y sin el indicador de faltante de creatinina

*Cuánto del desempeño depende de saber si se midió la creatinina.*

**Notebook:** NB 04  
**Técnicas:** Sensibilidad, Faltantes e indicadores  
**Dónde:** 04 · §7 y §8  
**Salida:** `outputs_no_indicator.txt`  
**Referencias:** R2-7, R2-20

**Qué se hizo.** Se repite el modelo principal en las mismas particiones y con las mismas muestras de pacientes, sin el indicador (la creatinina ausente se imputa por la mediana sin marcarla). Las diferencias son pareadas, con B = 1000, y el notebook también reporta calibración y estratos de UCI.

**Para qué sirve.** El indicador lleva información sobre quién fue examinado (ver 2.6). La pregunta del revisor es cuánto pesa.

Detalle:

- **LR.** AUROC 0.780 con indicador y 0.695 sin él; diferencia −0.085 (−0.109 a −0.059). *Para qué:* El modelo lineal depende mucho del indicador.
- **Conjunto.** AUROC 0.789 con indicador y 0.776 sin él; diferencia −0.013 (−0.024 a −0.002). AUPRC 0.167 y 0.164; diferencia −0.003 (−0.010 a 0.003). *Para qué:* Los modelos de árboles pierden mucho menos que la regresión logística (RF −0.023, ET −0.012, XGB −0.013).
- **Calibración.** Pendiente y O/E sin cambio con y sin indicador (conjunto: 1.01 y 1.00). *Para qué:* El indicador afecta la discriminación, no la calibración.

### 6.5 Lectura conjunta de las nueve sensibilidades

*La diferencia conjunto − LR es positiva en todas, entre +0.004 y +0.016 de AUROC.*

**Notebook:** NB 02, 04, 06  
**Técnicas:** Sensibilidad  
**Dónde:** Todas las salidas `outputs_*.txt`

**Qué se hizo.** Se compara en todas las variantes el AUROC del conjunto y su diferencia pareada con la regresión logística. En el análisis principal es +0.009 (0.002 a 0.016). El intervalo excluye el cero en `first_admission`, `any_obstetric`, `icu_vars` y `no_icu_24h`; lo incluye en `labs_extended`, `label_ge2`, `excl_renal_only` y `icd10_only` (en este último, el límite inferior es −0.000).

**Para qué sirve.** Responder en una frase si la conclusión depende de una decisión de diseño: en estos análisis la ventaja del conjunto es pequeña y no depende de una población, un desenlace o un conjunto de predictores en particular.

## P7. Desbalance de clases: sin corrección, pesos y SMOTE-NC

**Dónde:** Notebook 03.

**Objetivo.** Probar con el mismo procedimiento anidado y agrupado si corregir el desbalance (2.30 % de eventos) mejora el modelo, y qué hace cada corrección a la escala de la probabilidad.

### 7.1 Tres estrategias, cada una ajustada por separado

*Misma partición, mismo ajuste interno y mismo criterio; solo cambia el manejo del desbalance.*

**Notebook:** NB 03  
**Técnicas:** Desbalance, Modelos, ajuste y apilamiento  
**Dónde:** 03 · §3 y §8 `make_grid`, `set_strategy`  
**Salida:** `outputs_resampling.txt`  
**Referencias:** R1-9

**Qué se hizo.** Se corre el análisis principal tres veces: sin pesos ni remuestreo, con pesos de clase (balanceados; raíz de negativos entre positivos en XGBoost) y con SMOTE-NC. Las particiones externas, el ajuste interno agrupado y el criterio (AUPRC) son los mismos del notebook 02. Las rejillas son las mismas salvo la opción de pesos o de remuestreo. En ninguna estrategia se combinan pesos y sobremuestreo.

**Para qué sirve.** Responder con evidencia si se probó el remuestreo y qué hizo. El resultado vale para estas configuraciones, como señala el revisor.

Detalle:

- **unweighted.** Sin pesos (`class_weight` = None, `scale_pos_weight` = 1) ni remuestreo. *Para qué:* Referencia.
- **weighted.** Solo pesos de clase. *Para qué:* Corrige el desbalance cambiando la pérdida.
- **smote.** Solo SMOTE-NC sobre la parte de entrenamiento de cada ajuste, con la razón minoría/mayoría elegida entre 0.1 y 1.0. *Para qué:* Corrige el desbalance creando casos sintéticos.

### 7.2 SMOTE-NC dentro del pipeline

*Los casos sintéticos nacen solo de filas de entrenamiento del ajuste en curso.*

**Notebook:** NB 03  
**Técnicas:** Desbalance, Partición por paciente  
**Dónde:** 03 · §8 clase SmoteNCAuto  
**Referencias:** R1-9

**Qué se hizo.** El sobremuestreo ocurre dentro del pipeline, después del preprocesamiento del entrenamiento. Las columnas después del bloque numérico (indicadores y columnas 0/1) se tratan como categóricas, de modo que el voto de los vecinos más cercanos (k = 5) las fija en vez de promediarlas en fracciones. Nunca se usan filas de validación ni de prueba.

**Para qué sirve.** El error clásico es remuestrear antes de partir y filtrar casos sintéticos a la prueba. Hacerlo dentro del ajuste evita esa fuga.

### 7.3 Comparación tras la recalibración

*Los pesos casi no cambian el resultado y SMOTE-NC lo empeora.*

**Notebook:** NB 03  
**Técnicas:** Desbalance, Calibración, Métricas e incertidumbre  
**Dónde:** 03 · §10 `strategy_compare`  
**Salida:** `outputs_resampling.txt` [S1], [S3]  
**Referencias:** R1-9

**Qué se hizo.** Los resultados calibrados usan el paso de Platt de cada estrategia. Las diferencias entre estrategias son pareadas, con las mismas muestras de pacientes (B = 300). El conjunto sin corrección da AUROC 0.786, un poco menos que el 0.789 del análisis principal, cuya rejilla incluye los pesos como opción.

**Para qué sirve.** Es la tabla que sostiene la frase del manuscrito sobre el remuestreo.

Detalle:

- **Conjunto.** AUROC 0.786 sin corrección, 0.790 con pesos y 0.774 con SMOTE-NC. AUPRC 0.167, 0.162 y 0.156.
- **SMOTE − sin corrección.** Conjunto: AUROC −0.012 (−0.023 a −0.002) y AUPRC −0.010 (−0.020 a −0.001). Regresión logística: AUROC −0.023 (−0.034 a −0.012). XGBoost: AUROC −0.013 (−0.023 a −0.005). *Para qué:* SMOTE-NC baja el AUROC en cuatro de los cinco modelos (todos menos RF).
- **Pesos − sin corrección.** Conjunto: AUROC +0.004 (0.000 a 0.007) y AUPRC −0.004 (−0.013 a 0.002). RF y ET pierden AUPRC (−0.022, con intervalos que excluyen el cero). *Para qué:* Los pesos casi no cambian la discriminación y pueden bajar la precisión.

### 7.4 Qué le hace cada corrección a la probabilidad, antes de recalibrar

*Los pesos y el sobremuestreo inflan la probabilidad predicha por un factor de entre 3 y 17.*

**Notebook:** NB 03  
**Técnicas:** Desbalance, Calibración  
**Dónde:** 03 · §10  
**Salida:** `outputs_resampling.txt` [S2]  
**Referencias:** R1-9

**Qué se hizo.** Se reportan las probabilidades de cada modelo base tal como las produjo el algoritmo: riesgo medio predicho, O/E, pendiente y AUROC. La prevalencia observada es 0.0230.

**Para qué sirve.** Mostrar que la corrección mueve la escala de la probabilidad, y que por eso la recalibración es indispensable si se usa.

Detalle:

- **Sin corrección.** Riesgo medio predicho 0.0229 en LR, RF y ET, y 0.0228 en XGBoost; O/E 1.00 en los tres primeros y 1.01 en XGBoost. *Para qué:* La escala ya es correcta.
- **Pesos de clase.** Riesgo medio 0.382 en LR, 0.384 en RF, 0.397 en ET y 0.107 en XGBoost; O/E 0.06 (0.21 en XGBoost). *Para qué:* Sobrestiman el riesgo por un factor de 5 a 17.
- **SMOTE-NC.** Riesgo medio entre 0.080 y 0.086; O/E entre 0.27 y 0.29. *Para qué:* Sobrestiman por un factor de 3 a 4.

## P8. Era, versión de codificación y validación temporal

**Dónde:** Notebook 05.

**Objetivo.** Comprobar si el modelo aprende en qué época ocurrió la admisión en vez de la gravedad de la paciente, y cómo se comporta aplicado a un período posterior al que lo desarrolló.

### 8.1 Desempeño por grupo de años y por versión ICD (A)

*Las predicciones fuera de muestra del modelo principal, evaluadas por separado en cada grupo.*

**Notebook:** NB 05  
**Técnicas:** Era y validación temporal, Métricas e incertidumbre  
**Dónde:** 05 · §6 `group_performance`; 05 · celda 7.4  
**Salida:** `outputs_era_temporal.txt` [1]  
**Referencias:** T47, R1-3, R2-6, R2-17, R2-25

**Qué se hizo.** Se toman las predicciones fuera de muestra del análisis principal (replicado en este notebook) y se calculan AUROC, AUPRC, O/E y pendiente en cada grupo de años (`anchor_year_group`) y en cada versión ICD (solo ICD-9, mixta, solo ICD-10), con intervalos por bootstrap de pacientes (B = 300). La pendiente solo se muestra en grupos con al menos 20 eventos. O/E y pendiente se calculan con probabilidades calibradas en toda la muestra de desarrollo, así que un O/E lejos de 1 en un grupo indica cambio de calibración entre grupos.

**Para qué sirve.** Si el modelo discriminara bien solo en una época o versión, estaría aprendiendo la época. La calibración por grupo muestra el desplazamiento del riesgo.

Detalle:

- **AUROC del conjunto.** 2008–2010: 0.778 (0.735–0.824). 2011–2013: 0.762 (0.701–0.824). 2014–2016: 0.800 (0.745–0.847). 2017–2019: 0.803 (0.747–0.858). 2020–2022: 0.750 (0.673–0.813). *Para qué:* Discriminación estable entre épocas, con intervalos anchos.
- **O/E del conjunto.** 0.69 (0.56–0.84), 0.90 (0.74–1.11), 1.18 (0.97–1.40), 1.33 (1.06–1.61) y 1.95 (1.50–2.40) en los mismos cinco grupos. *Para qué:* El modelo sobrestima en los primeros años y subestima en los últimos, por el aumento de la prevalencia.
- **Versión ICD.** Solo ICD-9: AUROC 0.780 (0.739–0.821), O/E 0.80. Solo ICD-10: AUROC 0.784 (0.751–0.812), O/E 1.18. *Para qué:* Misma discriminación con las dos versiones.

### 8.2 Validación temporal con origen móvil (B)

*Entrenar con los años anteriores y puntuar un grupo posterior.*

**Notebook:** NB 05  
**Técnicas:** Era y validación temporal, Partición por paciente  
**Dónde:** 05 · §6 `temporal_plan`, `temporal_fit`, `run_temporal`  
**Salida:** `outputs_era_temporal.txt` [2]  
**Referencias:** T47, R3-7

**Qué se hizo.** Para cada grupo posterior al primero, cada modelo se ajusta, apila y recalibra solo con los grupos anteriores y se puntúa en ese grupo. Las pacientes con admisiones en el grupo de prueba se retiran del entrenamiento, y una aserción comprueba que nadie esté en ambos. Un ajuste se omite, y se imprime como omitido, si el entrenamiento tiene menos de 40 eventos o la prueba menos de 15.

**Para qué sirve.** Es lo más cercano a un uso prospectivo que permite una sola institución. Es exploratorio y no es una validación externa.

Detalle:

- **2008–2010 → 2011–2013.** Entrenamiento 8,212 admisiones y 121 eventos; prueba 4,328 y 86. AUROC del conjunto 0.762 (0.705–0.813); O/E 1.34. Conjunto − LR en AUROC +0.003 (−0.017 a 0.023).
- **2008–2013 → 2014–2016.** Entrenamiento 12,540 y 207; prueba 3,569 y 104. AUROC 0.807 (0.754–0.848); O/E 1.51. Conjunto − LR +0.024 (0.009 a 0.036).
- **2008–2016 → 2017–2019.** Entrenamiento 16,109 y 311; prueba 2,343 y 81. AUROC 0.801 (0.745–0.858); O/E 1.47. Conjunto − LR en AUROC −0.002 (−0.020 a 0.016).
- **2008–2019 → 2020–2022.** Entrenamiento 18,452 y 392; prueba 931 y 53. AUROC 0.760 (0.694–0.829); O/E 2.12 (1.57–2.69). Conjunto − LR +0.021 (0.003 a 0.040).
- **Lectura.** La discriminación hacia adelante se parece a la de la validación cruzada del mismo bloque (por ejemplo 0.762, 0.800, 0.803 y 0.750), pero el O/E sube de 1.34 a 2.12. *Para qué:* El modelo ordena bien en períodos posteriores y subestima el riesgo absoluto, porque la prevalencia aumenta.

### 8.3 Transición ICD-9 → ICD-10 (C)

*Entrenar solo con admisiones ICD-9 y puntuar las ICD-10.*

**Notebook:** NB 05  
**Técnicas:** Era y validación temporal, Partición por paciente  
**Dónde:** 05 · §6 `temporal_plan`  
**Salida:** `outputs_era_temporal.txt` [2]  
**Referencias:** T47, R2-17

**Qué se hizo.** Mismo procedimiento que 8.2: entrenamiento con admisiones solo ICD-9 (8,507 admisiones, 6,640 pacientes y 154 eventos), retirando las pacientes que aparecen en la prueba, y prueba con admisiones solo ICD-10 (8,864, 7,070 y 271).

**Para qué sirve.** Aislar el cambio de codificación de la definición de SMM, que usa listas distintas por versión.

Detalle:

- **Conjunto.** AUROC 0.775 (0.745–0.805), AUPRC 0.150, O/E 1.22 (1.05–1.36), pendiente 0.84 (0.73–0.95). AUROC de validación cruzada en el mismo bloque: 0.784. *Para qué:* Pérdida pequeña de discriminación; algo de subestimación.
- **Conjunto − LR.** AUROC +0.010 (0.005 a 0.015); AUPRC +0.012 (0.002 a 0.024).

### 8.4 Refits sin variables administrativas y con la era (D)

*Dos reajustes pareados con el modelo principal: sin proxies de la época y con la época añadida.*

**Notebook:** NB 05  
**Técnicas:** Era y validación temporal, Sensibilidad  
**Dónde:** 05 · §3 y §6 `paired_alt`  
**Salida:** `outputs_era_temporal.txt` [3]  
**Referencias:** T47, R1-3, R2-6

**Qué se hizo.** `main_noadmin` quita las cinco variables administrativas (etnia, seguro, idioma, tipo y lugar de admisión), cuyas categorías y uso cambian con el tiempo. `main_plus_era` añade el grupo de años y es solo diagnóstico: no es un predictor desplegable. Mismas particiones y mismas muestras de pacientes (B = 1000).

**Para qué sirve.** Si quitar las variables administrativas bajara mucho el desempeño, el modelo se apoyaría en variables que pueden reflejar la época. Si añadir la época lo subiera mucho, habría señal temporal que el modelo no captura.

Detalle:

- **Sin administrativas.** Conjunto: AUROC 0.773 contra 0.789; diferencia −0.016 (−0.026 a −0.004). AUPRC 0.145 contra 0.167; diferencia −0.022 (−0.040 a −0.006). Regresión logística: −0.018 (−0.030 a −0.007). *Para qué:* Las variables administrativas aportan algo de señal.
- **Con la era.** Conjunto: AUROC 0.801; diferencia +0.012 (0.004 a 0.022). AUPRC 0.183; diferencia +0.016 (0.008 a 0.024). *Para qué:* La época añade señal.
- **Calibración.** Pendiente y O/E del conjunto sin cambio en los tres modelos (1.01 o 1.00).

### 8.5 Qué pueden y qué no pueden mostrar estos análisis

*Cuatro límites que el notebook deja escritos.*

**Notebook:** NB 05  
**Técnicas:** Era y validación temporal  
**Dónde:** 05 · celda inicial  
**Referencias:** T47

**Qué se hizo.** `anchor_year_group` es un grupo de tres años que MIMIC-IV asigna a cada paciente, no una fecha exacta de admisión: una admisión repetida años después conserva el grupo de la paciente. Como es fijo por paciente, cada paciente cae entero en un bloque. El cambio ICD-9 a ICD-10 (octubre de 2015) cae dentro del grupo 2014–2016, así que época y versión de codificación están en parte confundidas. La validación temporal es exploratoria: una institución, pocos eventos en los primeros grupos.

**Para qué sirve.** Para que la lectura de la fase P8 no pase de lo que los datos permiten. No es una validación externa.

## P9. Temporalidad de los eventos respecto del punto de predicción

**Dónde:** Notebook 07.

**Objetivo.** Saber cuántos de los 445 SMM pudieron ocurrir antes de las 24 horas, cuando el modelo predice. Solo cuenta; no entrena nada.

### 9.1 Regla para ubicar cada procedimiento antes o después de T

*Los códigos de diagnóstico no tienen hora; los de procedimiento tienen fecha.*

**Notebook:** NB 07  
**Técnicas:** Temporalidad, Auditoría de conteos  
**Dónde:** 07 · §2 SQL_CATEGORY, SQL_INDICATOR  
**Salida:** `outputs_smm_timing.txt`  
**Referencias:** T52, R3-2, R3-3, R1-2, R2-5

**Qué se hizo.** Para cada parto elegible con SMM, cada indicador basado en procedimiento (ventilación, histerectomía, conversión del ritmo cardíaco) se cruza con `procedures_icd` usando los mismos patrones de código que la etiqueta (`smm_code_patterns_v2`, por prefijo o coincidencia exacta). Con la fecha D del procedimiento (sin hora) y T = ingreso + 24 horas, se clasifica en tres tiempos.

**Para qué sirve.** El SMM se define para toda la admisión y no hay hora en los diagnósticos. La fecha del procedimiento es lo único que permite ubicar parte de los eventos en el tiempo.

Detalle:

- **before.** D + 1 día ≤ T: el día completo terminó antes de T. *Para qué:* El procedimiento seguro precedió a la predicción.
- **after.** D ≥ T: el día empezó en T o después. *Para qué:* El procedimiento seguro la siguió.
- **ambiguous.** Cualquier otro caso: el día contiene a T. *Para qué:* No se puede ordenar.

### 9.2 Categorías A a D de cada admisión con SMM

*A cada una de las 445 admisiones se le asigna una sola categoría.*

**Notebook:** NB 07  
**Técnicas:** Temporalidad, Auditoría de conteos  
**Dónde:** 07 · §2 `report_category`  
**Salida:** `outputs_smm_timing.txt` [1]  
**Referencias:** T52, R3-2, R3-3

**Qué se hizo.** Las categorías se asignan en orden: A si algún indicador de procedimiento está seguro antes de T; si no, B si alguno es ambiguo; C si todos están seguro después de T; D si no hay ningún indicador de procedimiento. Se separa además por la presencia de un indicador de diagnóstico, cuya hora se desconoce. La suma de categorías se compara con 445 (OK).

**Para qué sirve.** Es la cifra que acota qué parte del SMM pudo empezar antes del punto de predicción.

Detalle:

- **A.** 59 admisiones (13.3 %): 23 sin indicador de diagnóstico y 36 con él. *Para qué:* Al menos esas tuvieron un procedimiento seguro antes de T.
- **B.** 25 (5.6 %): 6 sin indicador de diagnóstico y 19 con él. *Para qué:* No se puede ordenar.
- **C.** 42 (9.4 %): 14 sin indicador de diagnóstico y 28 con él. *Para qué:* Los procedimientos siguen a T.
- **D.** 319 (71.7 %): todas con indicador de diagnóstico y sin ninguno de procedimiento. *Para qué:* La etiqueta se apoya solo en códigos de diagnóstico: no hay hora.

### 9.3 Indicadores de procedimiento por tiempo

*Cuántas admisiones tienen cada indicador antes, alrededor o después de T.*

**Notebook:** NB 07  
**Técnicas:** Temporalidad, Auditoría de conteos  
**Dónde:** 07 · §2 pivot  
**Salida:** `outputs_smm_timing.txt` [2]  
**Referencias:** T52

**Qué se hizo.** Para cada indicador de procedimiento se cuentan las admisiones por tiempo. Una admisión con el mismo indicador en días distintos puede aparecer en varias columnas, por lo que no tienen que sumar el total de admisiones distintas con el indicador.

**Para qué sirve.** Ver cuáles indicadores aportan los eventos que ya habían ocurrido al punto de predicción.

Detalle:

- **Histerectomía.** 79 admisiones: 38 antes, 13 ambiguas y 28 después.
- **Ventilación.** 60 admisiones: 27 antes, 12 ambiguas y 21 después.
- **Conversión del ritmo cardíaco.** 6 admisiones: 0 antes, 3 ambiguas y 3 después.

## Índice de técnicas

| Técnica | Qué agrupa | Pasos |
|---|---|---|
| Auditoría de conteos | Comprobaciones que imprimen solo conteos agregados y los comparan con lo esperado (OK o CHECK): cohorte, eventos, pacientes por partición, solapamiento, tiempos. | 0.2, 1.1, 1.2, 1.4, 1.5, 1.6, 2.6, 3.1, 3.7, 9.1, 9.2, 9.3 |
| Definición de cohorte | Quién entra a cada análisis: población, filtros de elegibilidad y la regla de cada variante. | 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 6.1 |
| Limpieza y winsorización | Límites de plausibilidad y recorte de extremos (percentiles 0.5 y 99.5 del entrenamiento). | 2.2, 2.4 |
| Faltantes e indicadores | Cómo se tratan los valores ausentes: indicadores de faltante, imputación por mediana, categoría «missing». | 2.1, 2.2, 2.3, 2.5, 2.6, 2.7, 6.3, 6.4 |
| Partición por paciente | Validación cruzada agrupada por paciente y todo lo que garantiza que nadie quede a ambos lados. | 1.1, 3.1, 3.2, 3.4, 4.3, 7.2, 8.2, 8.3 |
| Modelos, ajuste y apilamiento | Los cuatro modelos base, sus rejillas, el ajuste anidado y el conjunto apilado. | 0.1, 2.5, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.4, 5.3, 7.1 |
| Calibración | Recalibración de Platt y las medidas de calibración: pendiente, CITL, O/E, ECE y deciles. | 3.6, 4.2, 5.2, 7.3, 7.4 |
| Métricas e incertidumbre | AUROC, AUPRC, Brier, bootstrap por pacientes y diferencias pareadas. | 0.1, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.3, 7.3, 8.1 |
| Utilidad clínica | Eventos capturados en el 5 % y 10 % de mayor riesgo, curva de decisión y estratos de UCI. | 4.5, 4.6, 5.4, 5.5, 5.6 |
| Tamaño de muestra | Criterios de Riley y viabilidad del modelo de mortalidad. | 4.7, 5.7 |
| Sensibilidad | Repetir el análisis principal cambiando una sola cosa: población, desenlace o predictores. | 1.3, 1.5, 2.7, 6.1, 6.2, 6.3, 6.4, 6.5, 8.4 |
| Desbalance | Sin corrección, pesos de clase y SMOTE-NC, cada uno ajustado por separado. | 7.1, 7.2, 7.3, 7.4 |
| Era y validación temporal | Desempeño por grupo de años y versión ICD, validación hacia adelante y refits sin proxies de era. | 1.6, 8.1, 8.2, 8.3, 8.4, 8.5 |
| Temporalidad | Qué eventos de SMM pudieron ocurrir antes del punto de predicción (admisión + 24 h). | 1.4, 9.1, 9.2, 9.3 |
