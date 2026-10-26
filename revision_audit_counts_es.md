# Auditoría de conteos del artículo materno (healthcare-4661619)

> Versión en español de [`revision_audit_counts.md`](revision_audit_counts.md). Si hay diferencias, prevalece la versión en inglés.

> **Solo conteos agregados.** Este documento no contiene datos a nivel de paciente ni identificadores. Todas las cifras provienen de MIMIC-IV v3.1 (PhysioNet, uso sujeto al acuerdo de uso de datos) y se obtuvieron con los scripts SQL y el notebook que se nombran en cada sección.

Solo 10 de las 41 admisiones positivas del Modelo A son una muerte en la misma admisión, y 14,064 de las 25,736 admisiones no pueden tener SMM con el etiquetado actual.

| Admisiones | Pacientes | Muertes en la misma admisión | Admisiones con SMM |
|---:|---:|---:|---:|
| 25,736 | 15,084 | 10 | 475 |

## Cómo leer este documento

- Esta es una copia del tablero de conteos usado durante la revisión del manuscrito, generada con los mismos datos (tablero publicado, versión 24, 2026-10-25).
- Las secciones **Q1 a Q21**, **Q24** y **Q25** describen las etiquetas y las particiones del manuscrito enviado. Desde **Revisión v2** en adelante, los conteos provienen de los nuevos scripts de `sql/06_revision_labels` y `sql/07_revision_predictors`; los scripts originales conservan su SQL sin cambios (el 2026-10-25 solo se actualizaron sus comentarios de encabezado para indicar que definen la versión enviada). **Cifras clave del manuscrito revisado** resume los resultados de los notebooks de `notebooks/revision/`, que son solo salidas agregadas.
- Cada sección nombra su fuente. Las consultas no devuelven filas individuales.
- SMM = morbilidad materna grave; UCI = unidad de cuidados intensivos; DRG = grupo relacionado por el diagnóstico; CID = coagulación intravascular diseminada.
- Las decisiones metodológicas (D1 a D16) están al final.

## Contenido

- [Tamaño del conjunto de datos y etiquetas por alcance](#tamaño-del-conjunto-de-datos-y-etiquetas-por-alcance)
- [Q1. Cohorte y pacientes repetidos](#q1-cohorte-y-pacientes-repetidos)
- [Q2. Positivos del Modelo A con la etiqueta enviada](#q2-positivos-del-modelo-a-con-la-etiqueta-enviada)
- [Q3. Relación de cada positivo con la admisión de la muerte](#q3-relación-de-cada-positivo-con-la-admisión-de-la-muerte)
- [Q4. Positivos aportados por cada paciente fallecido](#q4-positivos-aportados-por-cada-paciente-fallecido)
- [Q5. Redefinición: muerte en la misma admisión](#q5-redefinición-muerte-en-la-misma-admisión)
- [Q6. Versión de ICD de las admisiones](#q6-versión-de-icd-de-las-admisiones)
- [Q7. Tasa de SMM por era (por 10,000 partos)](#q7-tasa-de-smm-por-era-por-10000-partos)
- [Q8. Partos en admisiones ICD-9 (aproximación)](#q8-partos-en-admisiones-icd-9-aproximación)
- [Q9. Pacientes con SMM](#q9-pacientes-con-smm)
- [Q10. SMM frente a muerte en la misma admisión](#q10-smm-frente-a-muerte-en-la-misma-admisión)
- [Q11. SMM frente a la etiqueta de mortalidad enviada](#q11-smm-frente-a-la-etiqueta-de-mortalidad-enviada)
- [Q12. Regla de inclusión: diagnóstico obstétrico en posición 4 o menor](#q12-regla-de-inclusión-diagnóstico-obstétrico-en-posición-4-o-menor)
- [Q13. Disponibilidad de variables por UCI y SMM (% con valor)](#q13-disponibilidad-de-variables-por-uci-y-smm--con-valor)
- [Q14. Cuándo aparece la primera creatinina](#q14-cuándo-aparece-la-primera-creatinina)
- [Q15. Casos de SMM por indicador](#q15-casos-de-smm-por-indicador)
- [Q16. Perfil de las muertes en la misma admisión](#q16-perfil-de-las-muertes-en-la-misma-admisión)
- [Q17. Año aproximado de ingreso y versión de ICD](#q17-año-aproximado-de-ingreso-y-versión-de-icd)
- [Q18. Indicadores de SMM por grupo de año ancla](#q18-indicadores-de-smm-por-grupo-de-año-ancla)
- [Q19. Indicadores distintos por admisión con SMM (etiqueta enviada)](#q19-indicadores-distintos-por-admisión-con-smm-etiqueta-enviada)
- [Q20. Definiciones alternativas de SMM (etiqueta enviada)](#q20-definiciones-alternativas-de-smm-etiqueta-enviada)
- [Q21. SMM fuera del parto: capítulos obstétricos (etiqueta enviada)](#q21-smm-fuera-del-parto-capítulos-obstétricos-etiqueta-enviada)
- [Revisión v2: etiquetas revisadas con la lista oficial de los CDC](#revisión-v2-etiquetas-revisadas-con-la-lista-oficial-de-los-cdc)
- [Q-C1. Cohorte y etiquetas nuevas](#q-c1-cohorte-y-etiquetas-nuevas)
- [Q22. Bandera de parto original frente a la nueva](#q22-bandera-de-parto-original-frente-a-la-nueva)
- [Q-C2. SMM en partos por versión de codificación](#q-c2-smm-en-partos-por-versión-de-codificación)
- [Q-C3. SMM en partos por indicador y versión](#q-c3-smm-en-partos-por-indicador-y-versión)
- [Q-C4. Lista oficial frente a la etiqueta original](#q-c4-lista-oficial-frente-a-la-etiqueta-original)
- [Q-C5. Definiciones alternativas de SMM en partos](#q-c5-definiciones-alternativas-de-smm-en-partos)
- [Q-C6. Pacientes con más de una admisión](#q-c6-pacientes-con-más-de-una-admisión)
- [Q-C7. Códigos que tenía la lista original y que la oficial no tiene](#q-c7-códigos-que-tenía-la-lista-original-y-que-la-oficial-no-tiene)
- [Q23. Dataset del manuscrito frente a la nueva etiqueta](#q23-dataset-del-manuscrito-frente-a-la-nueva-etiqueta)
- [Q24. Solapamiento de pacientes en el hold-out enviado](#q24-solapamiento-de-pacientes-en-el-hold-out-enviado)
- [Q25. Solapamiento en la validación cruzada y con otras semillas](#q25-solapamiento-en-la-validación-cruzada-y-con-otras-semillas)
- [Q-D1. Posición más baja del diagnóstico obstétrico](#q-d1-posición-más-baja-del-diagnóstico-obstétrico)
- [Q-D3. Tipo del primer código obstétrico y regla de posición](#q-d3-tipo-del-primer-código-obstétrico-y-regla-de-posición)
- [Q-D4. Admisiones con evidencia obstétrica solo en el texto del título](#q-d4-admisiones-con-evidencia-obstétrica-solo-en-el-texto-del-título)
- [Q-D5. Efecto de cada regla de cohorte sobre las etiquetas revisadas](#q-d5-efecto-de-cada-regla-de-cohorte-sobre-las-etiquetas-revisadas)
- [Q-E1. Muertes dentro de un horizonte desde la admisión (cualquier causa)](#q-e1-muertes-dentro-de-un-horizonte-desde-la-admisión-cualquier-causa)
- [Q-E4. Días desde la admisión hasta la primera muerte posterior](#q-e4-días-desde-la-admisión-hasta-la-primera-muerte-posterior)
- [Q-F1. Elegibilidad para un modelo de 24 h y eventos perdidos](#q-f1-elegibilidad-para-un-modelo-de-24-h-y-eventos-perdidos)
- [Q-F2. Horas desde la admisión hasta la muerte](#q-f2-horas-desde-la-admisión-hasta-la-muerte)
- [Q-F3. Momento del primer ingreso a UCI y desenlaces](#q-f3-momento-del-primer-ingreso-a-uci-y-desenlaces)
- [Q-F4. Disponibilidad de cada variable en la ventana de predictores (partos elegibles, ventana D10)](#q-f4-disponibilidad-de-cada-variable-en-la-ventana-de-predictores-partos-elegibles-ventana-d10)
- [Q-F5. Laboratorios del parto: efecto de la ventana desde 24 h antes de la admisión hasta 24 h después](#q-f5-laboratorios-del-parto-efecto-de-la-ventana-desde-24-h-antes-de-la-admisión-hasta-24-h-después)
- [Q-G0. Diccionario final de predictores y regla de cobertura (D11)](#q-g0-diccionario-final-de-predictores-y-regla-de-cobertura-d11)
- [Q-G1. Disponibilidad de las tres pruebas de laboratorio principales por estrato](#q-g1-disponibilidad-de-las-tres-pruebas-de-laboratorio-principales-por-estrato)
- [Q-G2. Patrones de ausencia de datos y redundancia entre hemoglobina y hematocrito](#q-g2-patrones-de-ausencia-de-datos-y-redundancia-entre-hemoglobina-y-hematocrito)
- [Q-G3. Disponibilidad de creatinina por tipo de SMM](#q-g3-disponibilidad-de-creatinina-por-tipo-de-smm)
- [Q-G4. Distribución de las tres pruebas de laboratorio y valores fuera de los límites propuestos](#q-g4-distribución-de-las-tres-pruebas-de-laboratorio-y-valores-fuera-de-los-límites-propuestos)
- [Q-G5. Momento del primer valor respecto a la hora de admisión](#q-g5-momento-del-primer-valor-respecto-a-la-hora-de-admisión)
- [Q-H1. SMM frente a muerte en la misma admisión con las etiquetas revisadas](#q-h1-smm-frente-a-muerte-en-la-misma-admisión-con-las-etiquetas-revisadas)
- [Q-H2. Perfil de las muertes con la etiqueta revisada](#q-h2-perfil-de-las-muertes-con-la-etiqueta-revisada)
- [Q-H3. SMM por número de indicadores y muerte en la misma admisión](#q-h3-smm-por-número-de-indicadores-y-muerte-en-la-misma-admisión)
- [Q-H4. Indicadores de SMM presentes en las admisiones con muerte](#q-h4-indicadores-de-smm-presentes-en-las-admisiones-con-muerte)
- [Cifras clave del manuscrito revisado](#cifras-clave-del-manuscrito-revisado)
- [Q-I1. SMM por grupo de año de anclaje y versión de codificación (partos elegibles)](#q-i1-smm-por-grupo-de-año-de-anclaje-y-versión-de-codificación-partos-elegibles)
- [Q-J1. Momento de los indicadores de SMM respecto al momento de predicción](#q-j1-momento-de-los-indicadores-de-smm-respecto-al-momento-de-predicción)
- [Decisiones tomadas el 2026-10-23](#decisiones-tomadas-el-2026-10-23)
- [Decisiones D13 a D16 (marco de validación y manuscrito)](#decisiones-d13-a-d16-marco-de-validación-y-manuscrito)

### Tamaño del conjunto de datos y etiquetas por alcance

| Alcance | Registros (admisiones) | Pacientes | Muertes: etiqueta de mortalidad | Casos de SMM |
|:---|---:|---:|---:|---:|
| Etiqueta enviada (manuscrito) | 25,736 | 15,084 | 41 | 475 |
| Cualquier admisión obstétrica (universo actual, etiquetas nuevas) | 25,736 | 15,084 | 10 | 848 |
| Con código obstétrico estructurado (sensibilidad D6) | 25,644 | 15,022 | 10 | 837 |
| Solo hospitalizaciones de parto (alcance principal D5) | 19,425 | 13,729 | 4 | 447 |

**Interpretación.** Con la etiqueta enviada había 41 positivos de mortalidad, pero solo 10 fueron una muerte en esa admisión: los demás eran admisiones anteriores de pacientes que murieron después. Las 10 muertes pertenecen a 10 pacientes distintos y ninguna se perdió por la regla de cohorte. En las hospitalizaciones de parto quedan 4, es decir, 4 muertes en 19,425 partos. Con tan pocas muertes, el Modelo A es un análisis descriptivo, de factibilidad, y la SMM es el desenlace principal.

### Q1. Cohorte y pacientes repetidos

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

**Interpretación.** La cohorte tiene 25,736 admisiones de 15,084 pacientes, y 6,793 de esos pacientes tienen más de una admisión. Las cifras coinciden con el manuscrito. Con una partición por admisión, el mismo paciente puede quedar tanto en entrenamiento como en prueba.

### Q2. Positivos del Modelo A con la etiqueta enviada

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

**Interpretación.** La etiqueta actual marca 41 admisiones como positivas, que corresponden a 26 pacientes distintos. Por lo tanto, el modelo de mortalidad tiene menos eventos independientes de los que sugiere el manuscrito.

### Q3. Relación de cada positivo con la admisión de la muerte

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Relación | Admisiones | Pacientes | Muerte en una admisión de la cohorte | Admisión de la muerte con UCI | Esta admisión con UCI | Mediana de días hasta la muerte | Mínimo (días) | Máximo (días) |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
| Misma admisión | 10 | 10 | 10 | 7 | 7 | 1.0 | 0.2 | 21.4 |
| Admisión posterior | 31 | 18 | 6 | 18 | 4 | 1,354.6 | 11.3 | 4,840.0 |

**Interpretación.** Solo 10 positivos son la admisión en la que el paciente murió. Los otros 31 son admisiones anteriores de 18 pacientes que murieron después (dos pacientes aparecen en ambas filas: 2). De esos positivos anteriores, 25 tienen la muerte en una admisión fuera de la cohorte obstétrica. La mediana de tiempo hasta la muerte es de 3.7 años y el máximo es de 13.3 años. El desenlace es en su mayoría mortalidad hospitalaria por cualquier causa, tardía.

### Q4. Positivos aportados por cada paciente fallecido

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Positivos por paciente | Pacientes |
|:---|---:|
| 1 | 18 |
| 2 | 4 |
| 3 | 3 |
| 6 | 1 |

**Interpretación.** Los pacientes que aportan más de un positivo son copias de un único desenlace, y terminan repartidos entre entrenamiento y prueba si la partición es por admisión. La primera fila corresponde a quienes aportan uno; el resto aporta dos, tres o seis.

### Q5. Redefinición: muerte en la misma admisión

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Muertes en la misma admisión | Con UCI | Sin UCI | En las primeras 24 h |
|---:|---:|---:|---:|
| 10 | 7 | 3 | 5 |

**Interpretación.** Con la definición correcta quedan 10 muertes de 10 pacientes, y las 10 ya estaban entre los positivos actuales. Como 5 ocurrieron en las primeras 24 h, un punto de predicción a las 24 h deja fuera a la mitad. Con tan pocos eventos no se justifica un modelo de aprendizaje automático: se recomienda un análisis descriptivo.

### Q6. Versión de ICD de las admisiones

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Versión en la admisión | Admisiones | Casos de SMM | Positivos de mortalidad (Modelo A) | Partos detectados |
|:---|---:|---:|---:|---:|
| Solo ICD-10 | 11,671 | 475 | 2 | 8,857 |
| Solo ICD-9 | 14,064 | 0 | 39 | 0 |
| Ambas | 1 | 0 | 0 | 0 |

**Interpretación.** Todos los casos de SMM y todos los partos detectados están en admisiones ICD-10. Las 14,064 admisiones ICD-9 entran como negativos seguros, porque el etiquetado solo reconoce códigos ICD-10. Para la mortalidad ocurre lo contrario: 39 de los 41 positivos están en admisiones ICD-9. La fila «Ambas» supone la lectura 1, 0, 0, 0 del resultado registrado.

### Q7. Tasa de SMM por era (por 10,000 partos)

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Era | Por 10,000 partos |
|:---|---:|
| 2008 - 2010 | 216.5 |
| 2011 - 2013 | 185.6 |
| 2014 - 2016 | 251.5 |
| 2017 - 2019 | 324.0 |
| 2020 - 2022 | 546.6 |

| Grupo de año ancla | Admisiones | Con ICD-9 | Con ICD-10 | Casos de SMM | Partos (ICD-10) | SMM en parto | SMM por 10,000 partos |
|:---|---:|---:|---:|---:|---:|---:|---:|
| 2008 - 2010 | 10,733 | 8,796 | 1,937 | 52 | 1,524 | 33 | 216.5 |
| 2011 - 2013 | 5,633 | 3,807 | 1,826 | 40 | 1,509 | 28 | 185.6 |
| 2014 - 2016 | 4,724 | 1,461 | 3,264 | 123 | 2,545 | 64 | 251.5 |
| 2017 - 2019 | 3,208 | 1 | 3,207 | 143 | 2,346 | 76 | 324.0 |
| 2020 - 2022 | 1,438 | 0 | 1,438 | 117 | 933 | 51 | 546.6 |

**Interpretación.** La tasa sube de 216.5 a 546.6 por 10,000 partos, con un mínimo de 185.6 en 2011–2013. Todas estas cifras provienen de admisiones ICD-10, por lo que el cambio de versión no explica el aumento. El grupo de año ancla es la ventana del año ancla del paciente, no la fecha de cada admisión: por eso hay admisiones ICD-10 en 2008–2010 (son admisiones posteriores de esos pacientes).

### Q8. Partos en admisiones ICD-9 (aproximación)

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Partos detectados, ICD-10 | Admisiones ICD-9 con 650 o V27 | Partos estimados en total |
|---:|---:|---:|
| 8,857 | 10,540 | 19,397 |

**Interpretación.** El denominador actual de partos (8,857) deja fuera 10,540 admisiones ICD-9 con un código de parto. La suma es cercana a 19,397, más del doble. Los códigos 650 y V27 son una aproximación ad hoc y no una lista validada, por lo que la cifra es indicativa y no descuenta posibles traslapes.

### Q9. Pacientes con SMM

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

**Interpretación.** Las 475 admisiones con SMM corresponden a 426 pacientes, es decir, 49 admisiones repiten un paciente. La partición por paciente importa, pero con menos fuga que en la mortalidad.

### Q10. SMM frente a muerte en la misma admisión

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Combinación | Admisiones |
|:---|---:|
| Sin SMM, sin muerte hospitalaria | 25,252 |
| Sin SMM, con muerte hospitalaria | 9 |
| Con SMM, sin muerte hospitalaria | 474 |
| Con SMM, con muerte hospitalaria | 1 |

**Interpretación.** Con la etiqueta de SMM enviada, solo 1 caso de SMM murió en esa admisión, y 9 muertes no tienen ningún indicador de SMM. Probablemente muchas están en admisiones ICD-9, donde la SMM es cero por construcción; Q16 de la parte 2 lo comprueba. Con la etiqueta revisada el resultado cambia: ver Q-H1.

### Q11. SMM frente a la etiqueta de mortalidad enviada

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Combinación | Admisiones |
|:---|---:|
| Sin SMM, sin etiqueta de mortalidad | 25,221 |
| Sin SMM, con etiqueta de mortalidad | 40 |
| Con SMM, sin etiqueta de mortalidad | 474 |
| Con SMM, con etiqueta de mortalidad | 1 |

**Interpretación.** Con las etiquetas enviadas, los dos desenlaces casi no se traslapan: solo 1 admisión es positiva para ambos. El Modelo A y el Modelo B predicen eventos casi disjuntos, y esto debe reconocerse en la comparación de predictores que pide el Revisor 1. Con la etiqueta de SMM revisada, las 10 muertes en la misma admisión sí tienen SMM (Q-H1).

### Q12. Regla de inclusión: diagnóstico obstétrico en posición 4 o menor

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Medida | Regla del SQL (sin posición) | Con posición 4 o menor | Diferencia |
|:---|---:|---:|---:|
| Admisiones | 25,736 | 25,574 | 162 |
| Casos de SMM | 475 | 457 | 18 |
| Muertes en la misma admisión | 10 | 7 | 3 |

**Interpretación.** La regla de posición casi no cambia la cohorte (162 admisiones), pero elimina 18 casos de SMM y 3 de las 10 muertes. Debe elegirse una única regla para que el texto y el SQL digan lo mismo.

### Q13. Disponibilidad de variables por UCI y SMM (% con valor)

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Grupo | Admisiones | Frecuencia cardíaca | Creatinina | Glucosa | Lactato | Hemoglobina |
|:---|---:|---:|---:|---:|---:|---:|
| Sin UCI, sin SMM | 24,965 | 0.0% | 19.5% | 9.7% | 1.2% | 49.4% |
| Sin UCI, con SMM | 292 | 0.0% | 67.5% | 51.7% | 17.5% | 76.0% |
| Con UCI, sin SMM | 296 | 100.0% | 96.3% | 96.6% | 57.1% | 96.3% |
| Con UCI, con SMM | 183 | 100.0% | 99.5% | 99.5% | 75.4% | 98.9% |

**Interpretación.** Solo 479 admisiones tienen una estancia en UCI. La SMM alcanza el 38.2% entre ellas y el 1.2% sin UCI. Sin UCI no hay frecuencia cardíaca, y los laboratorios se miden con mucha más frecuencia cuando hay SMM (por ejemplo, lactato y creatinina): el faltante es informativo, no aleatorio. Imputar la frecuencia cardíaca con la mediana de las pacientes de UCI no representa a las demás.

### Q14. Cuándo aparece la primera creatinina

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Variable | Admisiones con valor | Mediana (horas) | Percentil 90 (horas) | Primer valor después de 24 h | % después de 24 h |
|:---|---:|---:|---:|---:|---:|
| Creatinina | 5,544 | 8.4 | 48.0 | 1,164 | 21.0% |

**Interpretación.** Solo 5,544 admisiones tienen una creatinina. La mediana de tiempo hasta el primer valor es de 8.4 horas y el percentil 90 es de 48.0 horas. En 1,164 admisiones (21.0%) el primer valor llega después de las 24 h. Una ventana de 24 h es factible, pero esas admisiones tendrían el valor faltante. Hoy el «valor más temprano» no tiene ventana y puede venir de cualquier momento de la hospitalización.

### Q15. Casos de SMM por indicador

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Grupo de indicadores | Admisiones con el indicador | En hospitalización de parto | Fuera del parto |
|:---|---:|---:|---:|
| Renal | 180 | 139 | 41 |
| Hemorragia | 131 | 72 | 59 |
| Respiratorio | 89 | 38 | 51 |
| Otros_Médicos | 77 | 22 | 55 |
| Sepsis | 62 | 21 | 41 |
| Cardíaco | 61 | 24 | 37 |
| Otros_Obstétricos | 56 | 22 | 34 |

| Indicador | Grupo | Admisiones |
|:---|:---|---:|
| Insuficiencia renal aguda | Renal | 180 |
| Choque | Hemorragia | 72 |
| SDRA | Respiratorio | 66 |
| Sepsis | Sepsis | 62 |
| CID | Hemorragia | 61 |
| Trastornos cerebrovasculares puerperales | Otros_Médicos | 55 |
| Ventilación | Respiratorio | 51 |
| Edema pulmonar/insuficiencia cardíaca aguda | Cardíaco | 45 |
| Histerectomía | Hemorragia | 41 |
| Embolia gaseosa y trombótica | Otros_Obstétricos | 33 |
| Anemia falciforme con crisis | Otros_Médicos | 23 |
| Eclampsia | Otros_Obstétricos | 16 |
| Conversión del ritmo cardíaco | Cardíaco | 8 |
| Infarto agudo de miocardio | Cardíaco | 7 |
| Paro cardíaco/fibrilación ventricular | Cardíaco | 7 |
| Aneurisma | Cardíaco | 5 |
| Complicaciones graves de la anestesia | Otros_Obstétricos | 4 |
| Embolia de líquido amniótico | Otros_Obstétricos | 4 |
| Insuficiencia/paro cardíaco durante una cirugía o procedimiento | Cardíaco | 1 |
| Traqueostomía temporal | Respiratorio | 1 |

**Interpretación.** 223 de los 475 casos de SMM (46.9%) están en admisiones que no son de parto, mientras que la tasa por 10,000 usa solo los partos como denominador. La insuficiencia renal aguda aparece en 180 casos: el 37.9% del total y el 55.2% de las admisiones de parto con SMM. Choque, sepsis, SDRA y ventilación son códigos genéricos de enfermedad crítica. Un caso puede tener varios indicadores, por lo que la suma de los grupos supera el total. Las consultas Q19 a Q21 de la parte 3 miden cuánto cambia la SMM si se excluye la insuficiencia renal aguda como único indicador o si se restringe a los partos.

### Q16. Perfil de las muertes en la misma admisión

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Perfil | Versión de ICD | Bandera de parto | SMM | UCI | Muertes |
|:---|:---|:---|:---|:---|---:|
| ICD-9, con UCI, diagnóstico obstétrico principal | Solo ICD-9 | No | No | Sí | 4 |
| ICD-9, sin UCI, diagnóstico obstétrico principal | Solo ICD-9 | No | No | No | 2 |
| ICD-9, con UCI, diagnóstico obstétrico no principal | Solo ICD-9 | No | No | Sí | 2 |
| ICD-10, con UCI, diagnóstico obstétrico principal | Solo ICD-10 | Sí | Sí | Sí | 1 |
| ICD-9, sin UCI, diagnóstico obstétrico no principal | Solo ICD-9 | No | No | No | 1 |

**Interpretación.** 9 de las 10 muertes están en admisiones solo ICD-9, y 1 en ICD-10, que es la única con SMM. Por eso la etiqueta de SMM casi no ve muertes (Q10): es un efecto de la versión de codificación. En 3 muertes el diagnóstico obstétrico no es el principal, probablemente muertes por una causa no obstétrica.

### Q17. Año aproximado de ingreso y versión de ICD

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Año aproximado | Admisiones | Solo ICD-9 | Solo ICD-10 | % ICD-10 | Casos de SMM | Partos (ICD-10) | SMM por 100 admisiones ICD-10 |
|:---|---:|---:|---:|---:|---:|---:|---:|
| 2005 | 1 | 1 | 0 | 0.0% | 0 | 0 | — |
| 2006 | 1 | 1 | 0 | 0.0% | 0 | 0 | — |
| 2007 | 4 | 4 | 0 | 0.0% | 0 | 0 | — |
| 2008 | 4,297 | 4,297 | 0 | 0.0% | 0 | 0 | — |
| 2009 | 1,052 | 1,052 | 0 | 0.0% | 0 | 0 | — |
| 2010 | 953 | 953 | 0 | 0.0% | 0 | 0 | — |
| 2011 | 3,166 | 3,166 | 0 | 0.0% | 0 | 0 | — |
| 2012 | 1,226 | 1,226 | 0 | 0.0% | 0 | 0 | — |
| 2013 | 1,069 | 988 | 81 | 7.6% | 6 | 64 | 7.4% |
| 2014 | 3,107 | 1,885 | 1,221 | 39.3% | 56 | 889 | 4.6% |
| 2015 | 1,362 | 458 | 904 | 66.4% | 26 | 721 | 2.9% |
| 2016 | 1,071 | 33 | 1,038 | 96.9% | 24 | 867 | 2.3% |
| 2017 | 2,744 | 0 | 2,744 | 100.0% | 114 | 1,957 | 4.2% |
| 2018 | 1,384 | 0 | 1,384 | 100.0% | 45 | 1,102 | 3.3% |
| 2019 | 1,154 | 0 | 1,154 | 100.0% | 42 | 928 | 3.6% |
| 2020 | 2,019 | 0 | 2,019 | 100.0% | 129 | 1,416 | 6.4% |
| 2021 | 783 | 0 | 783 | 100.0% | 22 | 638 | 2.8% |
| 2022 | 312 | 0 | 312 | 100.0% | 10 | 250 | 3.2% |
| 2023 | 31 | 0 | 31 | 100.0% | 1 | 25 | 3.2% |

**Interpretación.** El cambio de ICD-9 a ICD-10 ocurre entre aproximadamente 2013 y 2016: en 2013, el 7.6% de las admisiones son ICD-10, y desde 2017 todas lo son. El año aproximado es el límite inferior de la ventana del año ancla más el desplazamiento de cada admisión, con un margen de hasta dos años. Entre las admisiones ICD-10, la SMM pasa de 2.3% en 2016 a 6.4% en 2020, sin una tendencia continua. El aumento por era en Q7 depende en parte de agrupar por ventana del año ancla y no por fecha de admisión.

### Q18. Indicadores de SMM por grupo de año ancla

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Grupo de indicadores | 2008 - 2010 | 2011 - 2013 | 2014 - 2016 | 2017 - 2019 | 2020 - 2022 |
|:---|---:|---:|---:|---:|---:|
| Cardíaco | 11 | 1 | 8 | 22 | 19 |
| Hemorragia | 12 | 9 | 30 | 35 | 45 |
| Otros_Médicos | 6 | 3 | 39 | 16 | 13 |
| Otros_Obstétricos | 7 | 2 | 19 | 19 | 9 |
| Renal | 18 | 19 | 32 | 66 | 45 |
| Respiratorio | 8 | 4 | 11 | 27 | 39 |
| Sepsis | 8 | 8 | 13 | 15 | 18 |

**Interpretación.** La insuficiencia renal pasa de 18 a 66 casos entre el primer y el cuarto grupo, y los indicadores respiratorios saltan a 39 en el último. Cada celda cuenta admisiones con ese indicador. Como los dos primeros grupos tienen pocas admisiones ICD-10, los conteos deben dividirse por el denominador ICD-10 de Q7 antes de concluir que cambió la práctica de codificación o la gravedad.

### Q19. Indicadores distintos por admisión con SMM (etiqueta enviada)

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Indicadores distintos | Admisiones | En parto | Fuera del parto |
|:---|---:|---:|---:|
| 1 | 346 | 186 | 160 |
| 2 | 68 | 32 | 36 |
| 3 | 24 | 14 | 10 |
| 4 | 13 | 8 | 5 |
| 5 | 12 | 6 | 6 |
| 6 | 8 | 3 | 5 |
| 7 | 4 | 3 | 1 |

**Interpretación.** El 72.8% de las admisiones con SMM tiene un solo indicador (346), y solo 4 llegan a siete. El desenlace depende sobre todo de un único código por admisión, lo que refuerza la pregunta de cuáles indicadores reflejan de verdad la gravedad.

### Q20. Definiciones alternativas de SMM (etiqueta enviada)

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Definición | Admisiones | Pacientes | Con UCI |
|:---|---:|---:|---:|
| A. Etiqueta enviada (cualquier indicador, cualquier admisión) | 475 | 426 | 183 |
| B. Solo hospitalizaciones de parto (bandera ICD-10) | 252 | 249 | 80 |
| C. Cualquier admisión sin renal como único indicador | 345 | 303 | 172 |
| D. Parto sin renal como único indicador | 142 | 141 | 75 |
| E. Dos o más indicadores | 129 | 126 | 113 |
| Solo insuficiencia renal (cualquier admisión) | 130 | 127 | 11 |

**Interpretación.** Si se excluyen las admisiones cuyo único indicador es la insuficiencia renal aguda, la SMM baja de 475 a 345. Esas 130 admisiones casi nunca tienen UCI (8.5%), frente al 49.9% en el resto. Con dos o más indicadores quedan 129.

### Q21. SMM fuera del parto: capítulos obstétricos (etiqueta enviada)

_Fuente: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Capítulo de códigos presente | Admisiones |
|:---|---:|
| Otros (O94–O9A y O98–O99) | 153 |
| Anteparto (O09–O48) | 120 |
| Puerperio (O85–O92) | 103 |
| Trabajo de parto y parto (O60–O77) | 42 |
| Desenlace abortivo (O00–O08) | 17 |
| Atención del embarazo o del posparto (Z33, Z34, Z39) | 9 |

**Interpretación.** De las 223 admisiones con SMM que la bandera original no marcó como parto, 103 tienen códigos de puerperio y 42 tienen códigos de trabajo de parto y parto. Las banderas se traslapan, por lo que no suman el total. Es probable que varias sean partos que la bandera original no detectó (Q22).

### Revisión v2: etiquetas revisadas con la lista oficial de los CDC

**Interpretación.** De aquí en adelante los conteos provienen de los nuevos scripts (carpeta sql/06_revision_labels): la lista oficial de los CDC en ICD-9-CM e ICD-10-CM/PCS, una bandera de parto que usa diagnósticos, procedimientos y DRG, y la muerte en la misma admisión. No se tocó el SQL de los scripts originales. Los resultados de Q1 a Q18 describen las etiquetas del manuscrito enviado.

### Q-C1. Cohorte y etiquetas nuevas

_Fuente: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Partos (bandera nueva) | Admisiones con SMM en parto | Admisiones con SMM, cualquier admisión | Muertes en la misma admisión | De ellas, en parto |
|---:|---:|---:|---:|---:|
| 19,425 | 447 | 848 | 10 | 4 |

**Interpretación.** La cohorte sigue en 25,736 admisiones de 15,084 pacientes. Con la lista oficial hay 848 admisiones con SMM, y 447 están en partos (2.3% de 19,425 partos). Las otras 401 (47.3%) son admisiones que no son de parto, por lo que elegir la hospitalización de parto como alcance principal (D5) deja casi la mitad de los casos como análisis de sensibilidad. La muerte en la misma admisión suma 10 eventos, 4 en partos, y coincide con deathtime en todas las admisiones (0 discordantes). Con 10 eventos, el Modelo A no permite estimar un modelo de aprendizaje automático.

### Q22. Bandera de parto original frente a la nueva

_Fuente: `sql/06_revision_labels/02_delivery_flag.sql`_

| Medida | Admisiones |
|:---|---:|
| Partos con la bandera original | 8,857 |
| Partos con la bandera nueva | 19,425 |
| Añadidos por la bandera nueva | 10,584 |
| Perdidos por la bandera nueva | 16 |
| Solo por diagnóstico | 18 |
| Procedimiento de parto sin diagnóstico | 17 |
| Solo por DRG | 33 |
| Excluidos por código de aborto, ectópico o molar | 27 |
| Con código de mortinato | 109 |

**Interpretación.** La bandera original marcó 8,857 partos y la nueva marca 19,425, es decir, 2.2 veces más, porque incluye partos codificados en ICD-9 y procedimientos y DRG de parto. Añade 10,584 y pierde 16: los perdidos también tienen un código de aborto, embarazo ectópico o molar. De los 10,584 añadidos, 10,542 están codificados en ICD-9-CM y 42 en ICD-10-CM/PCS (los partos ICD-10 pasan de 8,857 a 8,883). Solo 18 partos dependen del diagnóstico y 33 solo del DRG, por lo que las tres fuentes se corroboran entre sí. Los 109 partos con código de mortinato se mantienen como partos. El análisis restringido a parto del manuscrito usó el denominador original.

### Q-C2. SMM en partos por versión de codificación

_Fuente: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Codificación de la admisión | Partos | Con SMM | % con SMM | Muertes en la misma admisión |
|:---|---:|---:|---:|---:|
| Solo ICD-10 | 8,883 | 272 | 3.06% | 1 |
| Solo ICD-9 | 10,542 | 175 | 1.66% | 3 |

**Interpretación.** Con la lista oficial, la SMM en partos es de 3.06% en las admisiones solo ICD-10 y de 1.66% en las solo ICD-9. Ninguna admisión mezcla las dos versiones. Aplicar el algoritmo de ICD-9-CM añade 175 casos que la etiqueta anterior no veía, pero la tasa sigue siendo menor en ICD-9. Estos datos no distinguen si se trata de subdetección por la codificación o de una diferencia real entre eras. Restringir a ICD-10 (opción b de D4) dejaría 272 eventos en 8,883 partos, frente a 447 con ambas versiones (1.6 veces más). La opción (a) conserva más eventos y la tasa no empeora, por lo que se mantiene, con la versión de codificación como variable de sensibilidad.

**Nota sobre la población.** Las tasas anteriores (3.06% y 1.66%) corresponden a las 19,425 hospitalizaciones de parto. Entre los 19,383 partos elegibles a las 24 h, que son la población de los modelos y del análisis principal, la SMM es de 271 de 8,864 (3.06%) en las admisiones solo ICD-10 y de 174 de 10,519 (1.65%) en las solo ICD-9 (Q-I1). Son poblaciones distintas, y el manuscrito indica a cuál se refiere cada cifra.

### Q-C3. SMM en partos por indicador y versión

_Fuente: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Indicador | ICD-10 | ICD-9 | Total | % de partos con SMM |
|:---|---:|---:|---:|---:|
| Insuficiencia renal aguda | 140 | 55 | 195 | 43.6% |
| CID | 44 | 46 | 90 | 20.1% |
| Histerectomía | 44 | 35 | 79 | 17.7% |
| SDRA | 32 | 32 | 64 | 14.3% |
| Ventilación | 27 | 32 | 59 | 13.2% |
| Choque | 35 | 17 | 52 | 11.6% |
| Sepsis | 21 | 22 | 43 | 9.6% |
| Trastornos cerebrovasculares puerperales | 22 | 11 | 33 | 7.4% |
| Edema pulmonar/insuficiencia cardíaca aguda | 16 | 15 | 31 | 6.9% |
| Embolia gaseosa y trombótica | 10 | 11 | 21 | 4.7% |
| Eclampsia | 8 | 4 | 12 | 2.7% |
| Complicaciones graves de la anestesia | 3 | 7 | 10 | 2.2% |
| Paro cardíaco/fibrilación ventricular | 5 | 3 | 8 | 1.8% |
| Conversión del ritmo cardíaco | 5 | 2 | 7 | 1.6% |
| Anemia falciforme con crisis | 2 | 5 | 7 | 1.6% |
| Embolia de líquido amniótico | 3 | 3 | 6 | 1.3% |
| Infarto agudo de miocardio | 1 | 2 | 3 | 0.7% |
| Aneurisma | 2 | 0 | 2 | 0.4% |

**Interpretación.** La insuficiencia renal aguda está en 195 de los 447 partos con SMM (43.6%), seguida de la CID (90) y la histerectomía (79). Como ninguna admisión mezcla versiones, cada total cuenta admisiones distintas por indicador, y una admisión puede aparecer en varios. La insuficiencia cardíaca durante una cirugía y la traqueostomía temporal no tienen casos. Los indicadores raros tienen muy pocos eventos, por lo que deben agruparse al modelar.

### Q-C4. Lista oficial frente a la etiqueta original

_Fuente: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Combinación | Admisiones |
|:---|---:|
| En la lista oficial y en la original | 459 |
| Solo en la lista oficial | 389 |
| Solo en la original | 16 |

**Interpretación.** De las 848 admisiones con SMM según la lista oficial, 459 ya estaban en la etiqueta original y 389 son nuevas: casos que la etiqueta enviada no veía, sobre todo por los partos ICD-9 y por códigos que faltaban en la lista original. Otras 16 admisiones salen porque dependían de códigos o prefijos que la lista oficial no tiene. La etiqueta original suma 475 admisiones, igual que el conjunto de datos del manuscrito (Q23).

### Q-C5. Definiciones alternativas de SMM en partos

_Fuente: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Definición | Admisiones |
|:---|---:|
| Cualquier indicador | 447 |
| Sin contar la insuficiencia renal como único indicador | 297 |
| Dos o más indicadores | 130 |

**Interpretación.** Si la insuficiencia renal aguda aislada no cuenta como SMM, los eventos bajan de 447 a 297: 150 partos (33.6%) tienen solo ese indicador. Con dos o más indicadores quedan 130. El análisis de sensibilidad de la tarea T50 era necesario, porque un tercio del desenlace depende de un único código. Se ejecutó en `notebooks/revision/06_smm_renal_only_sensitivity.ipynb` (salida agregada `outputs_excl_renal_only.txt`): entre los partos elegibles, 150 de los 445 eventos de SMM tienen la insuficiencia renal aguda como único indicador, y sin ellos (19,233 admisiones, 13,610 pacientes, 295 eventos, 1.53%) el AUROC es 0.792 (0.763-0.819) para la regresión logística y 0.795 (0.765-0.822) para el conjunto apilado, la diferencia conjunto menos regresión logística es +0.004 (-0.002 a 0.010), el AUPRC es 0.103 y 0.110, y el conjunto captura el 35.5% (30.7-40.7%) de los eventos en el 5% superior. Por lo tanto, la discriminación es similar a la del análisis principal (0.780 y 0.789); el AUPRC es menor porque la prevalencia baja de 2.30% a 1.53%.

### Q-C6. Pacientes con más de una admisión

_Fuente: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Pacientes con más de una admisión | Pacientes | % con varias admisiones | Máximo de admisiones por paciente |
|---:|---:|---:|---:|
| 6,793 | 15,084 | 45.0% | 27 |

**Interpretación.** El 45.0% de los pacientes tiene más de una admisión, hasta 27 en un solo paciente. La partición entrenamiento/prueba debe ser por paciente, no por admisión.

### Q-C7. Códigos que tenía la lista original y que la oficial no tiene

_Fuente: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Código | Versión | Admisiones | Estado en la lista oficial |
|:---|:---|---:|:---|
| T814XXA | ICD-10 | 5 | No oficial (excluido) |
| 9980 | ICD-9 | 2 | Oficial, uso previo a 2012 (incluido) |
| O2251 | ICD-10 | 2 | No oficial (excluido) |
| T80211A | ICD-10 | 1 | No oficial (excluido) |

**Interpretación.** Los códigos no oficiales aparecen en muy pocas admisiones, y el código 9980 (998.0, válido en la lista oficial solo por su uso antes de 2012) está en 2. Ni I64 ni las variantes adicionales de histerectomía y traqueostomía aparecen en la consulta. Estos códigos explican como máximo 8 de las 16 admisiones que solo tenía la etiqueta original; el resto probablemente viene de prefijos más amplios que los oficiales y habría que desglosarlo con una consulta. T81.4XXA es un código de infección posprocedimiento que la lista oficial actual reemplaza por T81.44XA (sepsis).

### Q23. Dataset del manuscrito frente a la nueva etiqueta

_Fuente: `sql/06_revision_labels/03b_reconcile_old_labels.sql`_

| Medida | Admisiones |
|:---|---:|
| Filas del dataset | 25,736 |
| Filas del dataset fuera de la nueva tabla | 0 |
| Positivos de SMM en el dataset | 475 |
| Positivos en la vista original y en la nueva etiqueta | 459 |
| Positivos en la vista original pero no en la nueva | 16 |
| Positivos que no están en la vista original | 0 |
| Positivos con insuficiencia renal únicamente (nueva etiqueta) | 129 |
| Positivos que no son parto según la nueva bandera | 218 |

**Interpretación.** El dataset del manuscrito tiene las mismas 25,736 admisiones que la nueva tabla (0 fuera de ella). Sus 475 positivos de SMM provienen todos de la vista original: 459 también están en la nueva etiqueta y 16 solo en la original. No hay ninguna diferencia entre el dataset y la vista que explicar. Con la nueva bandera de parto, 218 de esos positivos quedan fuera del parto y 129 tienen únicamente insuficiencia renal.

### Q24. Solapamiento de pacientes en el hold-out enviado

_Fuente: `notebooks/revision/01_audit_patient_overlap.ipynb`_

| Medida | Modelo A (mortalidad) | Modelo B (SMM) |
|:---|---:|---:|
| Pacientes de prueba | 4,527 | 4,523 |
| Pacientes de prueba que también están en entrenamiento | 2,686 | 2,635 |
| Admisiones de prueba | 5,148 | 5,148 |
| Admisiones de prueba con paciente en entrenamiento | 3,086 | 3,065 |
| Eventos de prueba | 8 | 95 |
| Eventos de prueba con paciente en entrenamiento | 6 | 48 |
| Eventos de prueba con un positivo del mismo paciente en entrenamiento | 6 | 13 |
| Pacientes con un evento en entrenamiento | 24 | 346 |
| Pacientes con un evento en prueba | 7 | 91 |
| Pacientes con un evento en ambos lados | 5 | 11 |

**Interpretación.** Con la partición enviada (80/20, semilla 42, reproducida exactamente), el 59.3% de los pacientes de prueba del Modelo A y el 58.3% de los del Modelo B también tienen admisiones en entrenamiento, y el 59.9% y el 59.5% de las admisiones de prueba pertenecen a esos pacientes. En mortalidad, 6 de los 8 eventos de prueba pertenecen a un paciente que ya tiene una admisión positiva en entrenamiento. En SMM la etiqueta es específica de cada admisión, y 13 de los 95 eventos comparten paciente con un positivo de entrenamiento. Este resultado mide cuánto solapamiento había, no cuánto infló el desempeño.

### Q25. Solapamiento en la validación cruzada y con otras semillas

_Fuente: `notebooks/revision/01_audit_patient_overlap.ipynb`_

| Medida | Modelo A (mortalidad) | Modelo B (SMM) |
|:---|:---|:---|
| Validación cruzada de 5 particiones enviada: eventos cuyo paciente está en las otras particiones | 23 de 41 | 244 de 475 |
| La misma cifra en 200 repeticiones de la validación cruzada (mediana y percentil 2.5 a 97.5) | 21 (18–23) de 41 | 240 (230–249) de 475 |
| 1,000 particiones hold-out: % de admisiones de prueba con paciente en entrenamiento | 60.1 (58.9–61.3) | 60.1 (58.8–61.4) |
| 1,000 particiones hold-out: eventos de prueba con paciente en entrenamiento | 4 (2–7) | 48 (39–57) |
| 1,000 particiones hold-out: eventos con un positivo del mismo paciente en entrenamiento | 4 (2–7) | 14 (8–20) |

**Interpretación.** El solapamiento no depende de la semilla: en 1,000 particiones hold-out la mediana de la proporción de admisiones de prueba con paciente en entrenamiento es 60.1%, con un rango muy estrecho. En la validación cruzada enviada, 23 de los 41 eventos de mortalidad tienen su paciente en las otras particiones, y un solo paciente aporta hasta 6 positivos. La partición a nivel de paciente elimina este solapamiento.

### Q-D1. Posición más baja del diagnóstico obstétrico

_Fuente: `sql/06_revision_labels/04_cohort_obstetric_flags.sql`_

| Posición más baja | Admisiones | Partos | Con SMM | SMM en parto | Muertes en la misma admisión | Con UCI |
|:---|---:|---:|---:|---:|---:|---:|
| 1 | 25,254 | 19,413 | 793 | 445 | 7 | 435 |
| 2 | 154 | 3 | 6 | 0 | 0 | 10 |
| 3 | 103 | 3 | 9 | 0 | 0 | 6 |
| 4 | 63 | 0 | 2 | 0 | 0 | 1 |
| 5–6 | 73 | 4 | 14 | 2 | 0 | 7 |
| 7–10 | 55 | 1 | 10 | 0 | 2 | 9 |
| 11 o más | 34 | 1 | 14 | 0 | 1 | 11 |

**Interpretación.** El 98.1% de las admisiones tiene el diagnóstico obstétrico en la posición 1. Las 162 admisiones con posición mayor que 4 son casi todas de no parto (156) y son las más graves: el 23.5% tiene SMM frente al 3.2% del resto, 3 murieron en la admisión y el 16.7% tuvo una estancia en UCI. Una paciente muy enferma acumula diagnósticos y el obstétrico se desplaza hacia abajo, por lo que la regla de posición 4 o menor excluye precisamente a las pacientes con el desenlace.

### Q-D3. Tipo del primer código obstétrico y regla de posición

_Fuente: `sql/06_revision_labels/04_cohort_obstetric_flags.sql`_

| Grupo del primer código | Posición 4 o menor | Admisiones | Partos | Con SMM | Muertes en la misma admisión |
|:---|:---|---:|---:|---:|---:|
| Capítulo O (ICD-10) | Sí | 11,503 | 8,875 | 460 | 1 |
| Capítulo O (ICD-10) | No | 18 | 2 | 8 | 0 |
| Z33, Z34, Z37, Z39 (ICD-10) | Sí | 76 | 4 | 3 | 0 |
| Z33, Z34, Z37, Z39 (ICD-10) | No | 28 | 0 | 5 | 0 |
| 630–679 (ICD-9) | Sí | 13,860 | 10,538 | 346 | 6 |
| 630–679 (ICD-9) | No | 26 | 0 | 11 | 2 |
| V22–V28 (ICD-9) | Sí | 87 | 0 | 0 | 0 |
| V22–V28 (ICD-9) | No | 38 | 2 | 3 | 1 |
| Solo texto del título | Sí | 48 | 2 | 1 | 0 |
| Solo texto del título | No | 52 | 2 | 11 | 0 |

**Interpretación.** Las admisiones con posición mayor que 4 (fila «No») se reparten en todos los grupos de códigos, y en cada uno tienen mucha más SMM que las de posición 4 o menor. No es un problema de un solo tipo de código, sino de la gravedad de la admisión.

### Q-D4. Admisiones con evidencia obstétrica solo en el texto del título

_Fuente: `sql/06_revision_labels/04_cohort_obstetric_flags.sql`_

| Código | Admisiones |
|:---|---:|
| V13.29 (ICD-9) | 24 |
| 629.81 (ICD-9) | 13 |
| F53 (ICD-10) | 11 |
| V72.42 (ICD-9) | 9 |
| Q86.0 (ICD-10) | 8 |
| Y76.8 (ICD-10) | 3 |
| Z86.32 (ICD-10) | 3 |
| Z87.59 (ICD-10) | 3 |
| N96 (ICD-10) | 2 |
| V72.40 (ICD-9) | 2 |
| Y76.1 (ICD-10) | 2 |
| Z32.01 (ICD-10) | 2 |
| F53.0 (ICD-10) | 1 |
| V12.21 (ICD-9) | 1 |
| V72.41 (ICD-9) | 1 |

**Interpretación.** Hay 88 admisiones que no son partos y no tienen ningún código obstétrico estructurado. Sus códigos son códigos de antecedentes (V13.29, Z86.32, Z87.59), pruebas de embarazo (V72.4x, Z32.01) y otros que coinciden por palabras del título, como Q86.0 (síndrome de alcoholismo fetal) y los códigos Y76 (dispositivos obstétricos). Tienen 11 casos de SMM y ninguna muerte. Los códigos F53 (trastornos mentales puerperales) son obstétricos y quedarían fuera con esa regla: es una pérdida pequeña que se declara.

### Q-D5. Efecto de cada regla de cohorte sobre las etiquetas revisadas

_Fuente: `sql/06_revision_labels/04_cohort_obstetric_flags.sql`_

| Regla | Admisiones | Pacientes | Partos | SMM, cualquier admisión | SMM en parto | Muertes en la misma admisión | Muertes en parto |
|:---|---:|---:|---:|---:|---:|---:|---:|
| R0 Cualquier posición (SQL actual) | 25,736 | 15,084 | 19,425 | 848 | 447 | 10 | 4 |
| R1 Posición 4 o menor (texto enviado) | 25,574 | 15,001 | 19,419 | 810 | 445 | 7 | 4 |
| R2 Código estructurado, cualquier posición | 25,644 | 15,022 | 19,421 | 837 | 447 | 10 | 4 |
| R3 Solo parto (nueva bandera) | 19,425 | 13,729 | 19,425 | 447 | 447 | 4 | 4 |

**Interpretación.** La regla de posición 4 o menor conserva 810 de los 848 casos de SMM y 7 de las 10 muertes, y casi no cambia los partos. Exigir un código estructurado (R2) deja 25,644 de las 25,736 admisiones sin perder ninguna muerte. Con la bandera de parto (R3) quedan 447 eventos de SMM y 4 muertes entre 13,729 pacientes. Decisión D6: el parto como alcance principal, con análisis de sensibilidad usando un código estructurado en cualquier posición.

### Q-E1. Muertes dentro de un horizonte desde la admisión (cualquier causa)

_Fuente: `sql/06_revision_labels/05_death_horizon_counts.sql`_

| Ventana desde la admisión | Pacientes fallecidos | Admisiones | Pacientes, admisión de parto | Solo registro hospitalario | Agregados por fecha de muerte estatal (dod) |
|:---|---:|---:|---:|---:|---:|
| Misma admisión (etiqueta corregida) | 10 | 10 | 4 | 10 | 0 |
| Hasta 42 días desde la admisión | 13 | 16 | 5 | 10 | 3 |
| Hasta 90 días desde la admisión | 16 | 20 | 6 | 10 | 6 |
| Hasta 365 días desde la admisión | 26 | 47 | 12 | 11 | 15 |

**Interpretación.** La columna dod existe en esta copia (Q-E0), por lo que se ven las muertes fuera del hospital: 13 pacientes a 42 días, 16 a 90 y 26 a 365, frente a 10 con la etiqueta de la misma admisión. En las admisiones de parto son 5, 6 y 12. El registro estatal explica casi todo el aumento. MIMIC-IV no almacena la causa de muerte, por lo que son muertes por cualquier causa y no bastan para entrenar un modelo. Se reportan solo como un análisis de sensibilidad descriptivo (decisión D7).

### Q-E4. Días desde la admisión hasta la primera muerte posterior

_Fuente: `sql/06_revision_labels/05_death_horizon_counts.sql`_

| Días desde la admisión | Admisiones | Pacientes |
|:---|---:|---:|
| El mismo día de la admisión | 3 | 3 |
| 1 a 42 días | 13 | 11 |
| 43 a 90 días | 4 | 4 |
| 91 a 365 días | 27 | 13 |
| Más de 365 días | 89 | 49 |

**Interpretación.** De las admisiones obstétricas con alguna muerte posterior a la admisión, 89 tienen la muerte más de un año después y quedan fuera de cualquier horizonte razonable. Entre 1 y 365 días hay 13, 4 y 27 admisiones en cada tramo. Las fechas de MIMIC-IV están desplazadas por paciente, pero los intervalos dentro de un mismo paciente se conservan.

### Q-F1. Elegibilidad para un modelo de 24 h y eventos perdidos

_Fuente: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Alcance | Admisiones | Elegibles a las 24 h | Alta con vida antes de 24 h | SMM | SMM elegibles | Muertes | Muertes elegibles | Muertes antes de 24 h |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
| Cualquier admisión obstétrica | 25,736 | 23,625 | 2,106 | 848 | 814 | 10 | 5 | 5 |
| Hospitalización de parto (principal) | 19,425 | 19,383 | 41 | 447 | 445 | 4 | 3 | 1 |
| Código obstétrico estructurado (sensibilidad) | 25,644 | 23,560 | 2,079 | 837 | 803 | 10 | 5 | 5 |

**Interpretación.** En las hospitalizaciones de parto casi no se pierde nada: quedan 19,383 de las 19,425 admisiones, 445 de los 447 casos de SMM y 3 de las 4 muertes. Con cualquier admisión obstétrica se pierden 2,106 estancias cortas con alta con vida (casi todas de no parto), 848 menos 814 casos de SMM y la mitad de las muertes (5 de 10). El modelo de 24 h es factible para SMM; para mortalidad queda con 3 a 5 eventos.

### Q-F2. Horas desde la admisión hasta la muerte

_Fuente: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Horas desde la admisión | Muertes en la misma admisión | De ellas, en parto | UCI en las primeras 24 h |
|:---|---:|---:|---:|
| 0 a 6 h | 1 | 0 | 1 |
| 6 a 12 h | 0 | 0 | 0 |
| 12 a 24 h | 4 | 1 | 2 |
| 24 a 48 h | 1 | 1 | 1 |
| Más de 48 h | 4 | 2 | 2 |

**Interpretación.** Cinco de las diez muertes ocurren antes de las 24 h y cinco después. En los partos, una ocurre antes de las 24 h y tres después.

### Q-F3. Momento del primer ingreso a UCI y desenlaces

_Fuente: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Primer ingreso a UCI | Admisiones | Partos | SMM | SMM en parto | Muertes |
|:---|---:|---:|---:|---:|---:|
| Sin estancia en UCI | 25,257 | 19,220 | 505 | 279 | 3 |
| UCI al momento de la admisión o antes | 1 | 0 | 1 | 0 | 0 |
| Primer ingreso a UCI dentro de las 24 h | 366 | 115 | 250 | 90 | 6 |
| Primer ingreso a UCI entre las 24 y 72 h | 53 | 40 | 44 | 36 | 0 |
| Primer ingreso a UCI después de las 72 h | 59 | 50 | 48 | 42 | 1 |

**Interpretación.** De los 447 casos de SMM en partos, 279 nunca ingresan a UCI, 90 ingresan en las primeras 24 h y 36 más 42 ingresan después. El ingreso a UCI en las primeras 24 h no es un predictor limpio: 90 de los 115 partos que ingresan tienen SMM, y varios indicadores de SMM (ventilación, choque) probablemente se manejan en la UCI.

### Q-F4. Disponibilidad de cada variable en la ventana de predictores (partos elegibles, ventana D10)

_Fuente: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Variable | Rol | Admisiones con valor | Total | Con UCI en 24 h | Sin UCI en 24 h | Con SMM |
|:---|:---|---:|---:|---:|---:|---:|
| hematocrit | Modelo principal | 15,846 | 81.8% | 96.5% | 81.7% | 84.9% |
| hemoglobin | Modelo principal | 15,822 | 81.6% | 96.5% | 81.5% | 84.9% |
| creatinine | Modelo principal | 3,971 | 20.5% | 96.5% | 20.0% | 62.9% |
| glucose | Modelo principal | 760 | 3.9% | 95.7% | 3.4% | 39.3% |
| chloride | Modelo principal | 673 | 3.5% | 95.7% | 2.9% | 38.2% |
| potassium | Modelo principal | 683 | 3.5% | 95.7% | 3.0% | 38.4% |
| sodium | Modelo principal | 678 | 3.5% | 95.7% | 2.9% | 38.4% |
| anion_gap | Modelo principal | 660 | 3.4% | 95.7% | 2.9% | 38.0% |
| bicarbonate | Modelo principal | 660 | 3.4% | 95.7% | 2.9% | 38.0% |
| magnesium | Modelo principal | 620 | 3.2% | 93.9% | 2.7% | 39.1% |
| calcium_noionized | Modelo principal | 527 | 2.7% | 94.8% | 2.2% | 35.7% |
| phosphorus | Modelo principal | 513 | 2.6% | 94.8% | 2.1% | 35.3% |
| lactate | Modelo principal | 162 | 0.8% | 73.0% | 0.4% | 21.6% |
| gcs_eye_opening | Solo sensibilidad en UCI | 113 | 0.6% | 98.3% | 0.0% | 19.8% |
| gcs_motor_response | Solo sensibilidad en UCI | 113 | 0.6% | 98.3% | 0.0% | 19.8% |
| gcs_verbal_response | Solo sensibilidad en UCI | 113 | 0.6% | 98.3% | 0.0% | 19.8% |
| heart_rate | Solo sensibilidad en UCI | 114 | 0.6% | 99.1% | 0.0% | 20.0% |
| o2_saturation | Solo sensibilidad en UCI | 114 | 0.6% | 99.1% | 0.0% | 20.0% |
| respiratory_rate | Solo sensibilidad en UCI | 114 | 0.6% | 99.1% | 0.0% | 20.0% |
| temperature_fahrenheit | Solo sensibilidad en UCI | 113 | 0.6% | 98.3% | 0.0% | 19.8% |
| weight_admission | Solo sensibilidad en UCI | 115 | 0.6% | 100.0% | 0.0% | 20.2% |
| pressure_blood_diastolic | Solo sensibilidad en UCI | 92 | 0.5% | 80.0% | 0.0% | 15.5% |
| pressure_blood_mean | Solo sensibilidad en UCI | 92 | 0.5% | 80.0% | 0.0% | 15.5% |
| pressure_blood_systolic | Solo sensibilidad en UCI | 92 | 0.5% | 80.0% | 0.0% | 15.5% |
| richmond_ras_scale | Solo sensibilidad en UCI | 95 | 0.5% | 82.6% | 0.0% | 17.3% |
| peep_set | Solo sensibilidad en UCI | 59 | 0.3% | 51.3% | 0.0% | 11.9% |
| height | Solo sensibilidad en UCI | 44 | 0.2% | 38.3% | 0.0% | 9.2% |

**Interpretación.** Con la ventana desde 24 h antes de la admisión hasta 24 h después, la hemoglobina está presente en el 81.6% de los partos elegibles y el hematocrito en el 81.8%; la creatinina, en el 20.5%. Los demás laboratorios permanecen por debajo del 4%. Las 14 variables de UCI no existen fuera de la UCI. La ausencia de datos sigue ligada al desenlace en la creatinina (62.9% en los casos de SMM) y en los laboratorios poco frecuentes, pero la hemoglobina ahora casi no discrimina (84.9% en SMM frente a 81.6% en general).

### Q-F5. Laboratorios del parto: efecto de la ventana desde 24 h antes de la admisión hasta 24 h después

_Fuente: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Laboratorio | Primer valor en la ventana | De ellos, antes de la admisión | Solo después de 24 h | Sin valor | % en la nueva ventana | % con la ventana anterior (desde la admisión) |
|:---|---:|---:|---:|---:|---:|---:|
| hematocrit | 15,868 | 6,930 | 99 | 3,458 | 81.7% | 56.5% |
| hemoglobin | 15,843 | 6,928 | 66 | 3,516 | 81.6% | 53.0% |
| creatinine | 3,970 | 2,136 | 479 | 14,976 | 20.4% | 13.1% |
| glucose | 756 | 335 | 490 | 18,179 | 3.9% | 2.6% |
| potassium | 676 | 287 | 467 | 18,282 | 3.5% | 2.4% |
| sodium | 671 | 286 | 467 | 18,287 | 3.5% | 2.4% |
| chloride | 666 | 284 | 468 | 18,291 | 3.4% | 2.4% |
| anion_gap | 653 | 281 | 467 | 18,305 | 3.4% | 2.3% |
| bicarbonate | 653 | 281 | 467 | 18,305 | 3.4% | 2.3% |
| magnesium | 612 | 170 | 490 | 18,323 | 3.2% | 2.6% |
| calcium_noionized | 520 | 175 | 414 | 18,491 | 2.7% | 2.1% |
| phosphorus | 505 | 166 | 411 | 18,509 | 2.6% | 2.0% |
| lactate | 153 | 33 | 117 | 19,155 | 0.8% | 0.7% |

**Interpretación.** Aceptar valores de las 24 h previas a la admisión eleva la cobertura de hemoglobina del 53.0% al 81.6%, la de hematocrito del 56.5% al 81.7% y la de creatinina del 13.1% al 20.4% (todos los partos). El 43.7% de los primeros valores de hemoglobina y el 53.8% de los primeros valores de creatinina se tomaron antes de la hora de admisión (triage o servicio de urgencias), por lo que el momento del dato respecto al punto de predicción varía entre 48 y 0 horas.

### Q-G0. Diccionario final de predictores y regla de cobertura (D11)

_Fuente: `sql/07_revision_predictors/02_dictionary_missingness.sql`_

| Variable | Unidad | Cobertura en partos elegibles | Rol final | Indicador de ausencia de datos en el modelo principal | Límites de plausibilidad propuestos |
|:---|:---|---:|:---|:---|:---|
| hemoglobin | g/dL | 81.6% | Modelo principal | No | 3.0–20.0 |
| creatinine | mg/dL | 20.5% | Modelo principal | Sí | 0.1–20.0 |
| hematocrit | % | 81.8% | Sensibilidad de laboratorio (redundante con hemoglobina, D12) | No | 10.0–65.0 |
| glucose | mg/dL | 3.9% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| chloride | mEq/L | 3.5% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| potassium | mEq/L | 3.5% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| sodium | mEq/L | 3.5% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| anion_gap | mEq/L | 3.4% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| bicarbonate | mEq/L | 3.4% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| magnesium | mg/dL | 3.2% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| calcium_noionized | mg/dL | 2.7% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| phosphorus | mg/dL | 2.6% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| lactate | mmol/L | 0.8% | Sensibilidad de laboratorio (cobertura bajo el umbral) | No | — |
| gcs_eye_opening | puntaje | 0.6% | Solo sensibilidad en UCI | No | — |
| gcs_motor_response | puntaje | 0.6% | Solo sensibilidad en UCI | No | — |
| gcs_verbal_response | puntaje | 0.6% | Solo sensibilidad en UCI | No | — |
| heart_rate | latidos/min | 0.6% | Solo sensibilidad en UCI | No | — |
| o2_saturation | % | 0.6% | Solo sensibilidad en UCI | No | — |
| respiratory_rate | respiraciones/min | 0.6% | Solo sensibilidad en UCI | No | — |
| temperature_fahrenheit | °F | 0.6% | Solo sensibilidad en UCI | No | — |
| weight_admission | kg | 0.6% | Solo sensibilidad en UCI | No | — |
| pressure_blood_diastolic | mmHg | 0.5% | Solo sensibilidad en UCI | No | — |
| pressure_blood_mean | mmHg | 0.5% | Solo sensibilidad en UCI | No | — |
| pressure_blood_systolic | mmHg | 0.5% | Solo sensibilidad en UCI | No | — |
| richmond_ras_scale | puntaje | 0.5% | Solo sensibilidad en UCI | No | — |
| peep_set | cmH2O | 0.3% | Solo sensibilidad en UCI | No | — |
| height | cm | 0.2% | Solo sensibilidad en UCI | No | — |

**Interpretación.** La regla del 10% deja tres pruebas de laboratorio: hemoglobina (81.6%), hematocrito (81.8%) y creatinina (20.5%). Como la hemoglobina y el hematocrito son redundantes (D12), el modelo principal usa hemoglobina y creatinina. Las otras diez pruebas de laboratorio están entre 0.8% y 3.9%, y las 14 variables de UCI entre 0.2% y 0.6%, por lo que pasan al análisis de sensibilidad. Cada prueba de laboratorio tiene una única unidad en la ventana (Q-G6), igual que en el diccionario. Los límites de plausibilidad son una propuesta pendiente de revisión clínica.

### Q-G1. Disponibilidad de las tres pruebas de laboratorio principales por estrato

_Fuente: `sql/07_revision_predictors/02_dictionary_missingness.sql`_

| Alcance | Estrato | Admisiones elegibles | Con hemoglobina | % hemoglobina | Con hematocrito | Con creatinina | % creatinina | Con las tres | Con ninguna | % con ninguna |
|:---|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Hospitalización de parto (principal) | Todas las admisiones | 19,383 | 15,822 | 81.6% | 15,846 | 3,971 | 20.5% | 3,969 | 3,536 | 18.2% |
| Hospitalización de parto (principal) | Con un diagnóstico ICD-10 | 8,864 | 7,220 | 81.5% | 7,234 | 2,094 | 23.6% | 2,093 | 1,629 | 18.4% |
| Hospitalización de parto (principal) | Solo ICD-9 | 10,519 | 8,602 | 81.8% | 8,612 | 1,877 | 17.8% | 1,876 | 1,907 | 18.1% |
| Hospitalización de parto (principal) | Sin UCI en las primeras 24 h | 19,268 | 15,711 | 81.5% | 15,735 | 3,860 | 20.0% | 3,859 | 3,533 | 18.3% |
| Hospitalización de parto (principal) | UCI en las primeras 24 h | 115 | 111 | 96.5% | 111 | 111 | 96.5% | 110 | 3 | 2.6% |
| Hospitalización de parto (principal) | Sin SMM | 18,938 | 15,444 | 81.6% | 15,468 | 3,691 | 19.5% | 3,689 | 3,469 | 18.3% |
| Hospitalización de parto (principal) | Con SMM | 445 | 378 | 84.9% | 378 | 280 | 62.9% | 280 | 67 | 15.1% |
| Hospitalización de parto (principal) | SMM, insuficiencia renal aguda como único indicador | 150 | 125 | 83.3% | 125 | 101 | 67.3% | 101 | 25 | 16.7% |
| Hospitalización de parto (principal) | SMM, dos o más indicadores | 129 | 109 | 84.5% | 109 | 85 | 65.9% | 85 | 20 | 15.5% |
| Hospitalización de parto (principal) | Murió en la misma admisión | 3 | 3 | 100.0% | 3 | 3 | 100.0% | 3 | 0 | 0.0% |
| Cualquier admisión obstétrica | Todas las admisiones | 23,625 | 19,188 | 81.2% | 19,222 | 6,613 | 28.0% | 6,585 | 4,379 | 18.5% |
| Cualquier admisión obstétrica | Con un diagnóstico ICD-10 | 10,800 | 8,766 | 81.2% | 8,786 | 3,322 | 30.8% | 3,306 | 1,999 | 18.5% |
| Cualquier admisión obstétrica | Solo ICD-9 | 12,825 | 10,422 | 81.3% | 10,436 | 3,291 | 25.7% | 3,279 | 2,380 | 18.6% |
| Cualquier admisión obstétrica | Sin UCI en las primeras 24 h | 23,273 | 18,844 | 81.0% | 18,878 | 6,271 | 26.9% | 6,245 | 4,373 | 18.8% |
| Cualquier admisión obstétrica | UCI en las primeras 24 h | 352 | 344 | 97.7% | 344 | 342 | 97.2% | 340 | 6 | 1.7% |
| Cualquier admisión obstétrica | Sin SMM | 22,811 | 18,481 | 81.0% | 18,516 | 6,016 | 26.4% | 5,989 | 4,272 | 18.7% |
| Cualquier admisión obstétrica | Con SMM | 814 | 707 | 86.9% | 706 | 597 | 73.3% | 596 | 107 | 13.1% |
| Cualquier admisión obstétrica | SMM, insuficiencia renal aguda como único indicador | 179 | 149 | 83.2% | 149 | 125 | 69.8% | 125 | 30 | 16.8% |
| Cualquier admisión obstétrica | SMM, dos o más indicadores | 223 | 195 | 87.4% | 195 | 171 | 76.7% | 171 | 28 | 12.6% |
| Cualquier admisión obstétrica | Murió en la misma admisión | 5 | 5 | 100.0% | 5 | 5 | 100.0% | 5 | 0 | 0.0% |

**Interpretación.** En los partos elegibles, 3,536 admisiones (18.2%) no tienen ninguna de las tres pruebas de laboratorio, y entre ellas hay 67 de los 445 casos de SMM. La hemoglobina casi no cambia con el desenlace ni con la era: 81.6% sin SMM frente a 84.9% con SMM, y 81.5% en admisiones con un diagnóstico ICD-10 frente a 81.8% en las de solo ICD-9. La creatinina sí cambia: 19.5% sin SMM y 62.9% con SMM; 20.0% sin UCI en 24 h y 96.5% con UCI; 23.6% en ICD-10 y 17.8% en solo ICD-9. Por eso la creatinina lleva un indicador de ausencia de datos (D11). Las 3 muertes tienen las tres pruebas de laboratorio.

### Q-G2. Patrones de ausencia de datos y redundancia entre hemoglobina y hematocrito

_Fuente: `sql/07_revision_predictors/02_dictionary_missingness.sql`_

| Patrón | Admisiones | % de los partos elegibles | Con SMM |
|:---|---:|---:|---:|
| Las tres | 3,969 | 20.5% | 280 |
| Hemoglobina y hematocrito, sin creatinina | 11,853 | 61.2% | 98 |
| Hematocrito y creatinina, sin hemoglobina | 1 | 0.0% | 0 |
| Solo hematocrito | 23 | 0.1% | 0 |
| Solo creatinina | 1 | 0.0% | 0 |
| Ninguna de las tres | 3,536 | 18.2% | 67 |

**Interpretación.** Solo 3,969 partos elegibles (20.5%) tienen las tres pruebas de laboratorio, por lo que un análisis de casos completos descartaría el resto de las admisiones y 165 de los 445 casos de SMM elegibles. La hemoglobina y el hematocrito casi siempre vienen juntos, y su correlación es 0.924 (0.945 en SMM): son casi redundantes. Por eso solo la hemoglobina entra al modelo principal y el hematocrito pasa al análisis de sensibilidad (D12).

### Q-G3. Disponibilidad de creatinina por tipo de SMM

_Fuente: `sql/07_revision_predictors/02_dictionary_missingness.sql`_

| Tipo | Admisiones | Con creatinina | % creatinina | Con hemoglobina | % hemoglobina | Con UCI en 24 h |
|:---|---:|---:|---:|---:|---:|---:|
| Sin SMM | 18,938 | 3,691 | 19.5% | 15,444 | 81.6% | 25 |
| SMM, insuficiencia renal aguda como único indicador | 150 | 101 | 67.3% | 125 | 83.3% | 5 |
| SMM, un indicador no renal | 166 | 94 | 56.6% | 144 | 86.7% | 22 |
| SMM, dos o más indicadores | 129 | 85 | 65.9% | 109 | 84.5% | 63 |

**Interpretación.** La creatinina está presente en el 19.5% de las admisiones sin SMM, en el 56.6% con un único indicador no renal y en el 65.9% con dos o más. Entre aquellas cuyo único indicador es la insuficiencia renal aguda llega al 67.3%: una de cada tres no tiene creatinina en las primeras 24 h, probablemente porque el diagnóstico se hizo o se codificó más tarde. La disponibilidad de creatinina sigue a la gravedad, por lo que refleja a quién se le hizo la prueba y no solo su valor. La hemoglobina, en cambio, se mantiene entre 81.6% y 86.7% en los cuatro grupos.

### Q-G4. Distribución de las tres pruebas de laboratorio y valores fuera de los límites propuestos

_Fuente: `sql/07_revision_predictors/02_dictionary_missingness.sql`_

| Laboratorio | Unidad | Valores | P1 | P5 | P25 | P50 | P75 | P95 | P99 | Bajo el límite inferior | Sobre el límite superior |
|:---|:---|---:|:---|:---|:---|:---|:---|:---|:---|---:|---:|
| hemoglobin | g/dL | 15,822 | 8.8 | 9.8 | 11.2 | 12.1 | 12.9 | 14.0 | 14.8 | 0 | 0 |
| hematocrit | % | 15,846 | 27.3 | 30.0 | 33.4 | 35.6 | 37.9 | 41.0 | 43.3 | 0 | 0 |
| creatinine | mg/dL | 3,971 | 0.4 | 0.4 | 0.5 | 0.6 | 0.7 | 0.9 | 1.3 | 0 | 0 |

**Interpretación.** Ningún valor queda fuera de los límites propuestos (0 por debajo y 0 por encima en las tres pruebas de laboratorio). Entre los percentiles 1 y 99, la hemoglobina va de 8.8 a 14.8 g/dL, el hematocrito de 27.3 a 43.3 % y la creatinina de 0.4 a 1.3 mg/dL. Con estos datos los límites de plausibilidad no cambian ningún valor, y lo que queda por definir es el recorte por percentiles ajustado solo con la parte de entrenamiento de cada partición.

### Q-G5. Momento del primer valor respecto a la hora de admisión

_Fuente: `sql/07_revision_predictors/02_dictionary_missingness.sql`_

| Laboratorio | Valores | P10 (horas) | Mediana (horas) | P90 (horas) | Antes de la admisión | % antes de la admisión | Después de 12 h | % después de 12 h |
|:---|---:|:---|:---|:---|---:|---:|---:|---:|
| hemoglobin | 15,822 | -3.4 | 0.1 | 2.1 | 6,907 | 43.7% | 234 | 1.5% |
| hematocrit | 15,846 | -3.4 | 0.1 | 2.2 | 6,909 | 43.6% | 252 | 1.6% |
| creatinine | 3,971 | -6.1 | -0.2 | 10.5 | 2,128 | 53.6% | 339 | 8.5% |

**Interpretación.** La mediana del momento del primer valor es 0.1 h para la hemoglobina y -0.2 h para la creatinina, es decir, alrededor de la hora de admisión (las horas negativas son anteriores a la admisión). El 43.7% de los valores de hemoglobina y el 53.6% de los de creatinina se toman antes de la admisión. Solo el 1.5% de los valores de hemoglobina y el 8.5% de los de creatinina llegan después de 12 h, lejos del punto de predicción de 24 h.

### Q-H1. SMM frente a muerte en la misma admisión con las etiquetas revisadas

_Fuente: `sql/06_revision_labels/06_smm_death_overlap.sql`_

| Alcance | Admisiones | Ni SMM ni muerte | Solo SMM | Solo muerte | SMM y muerte | Total con SMM | Total de muertes | % de SMM sin muerte |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
| Todas las admisiones obstétricas | 25,736 | 24,888 | 838 | 0 | 10 | 848 | 10 | 98.8% |
| Hospitalizaciones de parto | 19,425 | 18,978 | 443 | 0 | 4 | 447 | 4 | 99.1% |
| Partos elegibles (modelo de 24 h) | 19,383 | 18,938 | 442 | 0 | 3 | 445 | 3 | 99.3% |

**Interpretación.** Con la etiqueta de SMM revisada, las 10 muertes en la misma admisión llevan al menos un indicador de SMM (4 de 4 en partos y 3 de 3 en partos elegibles), y 838 de las 848 admisiones con SMM (98.8%) terminaron en un alta con vida. El solapamiento va en un solo sentido: la muerte está dentro de la SMM, y la SMM casi nunca es fatal. Con la etiqueta enviada (Q10 y Q11) solo 1 de las 10 muertes era SMM, porque 9 ocurrieron en admisiones ICD-9 que esa etiqueta no podía detectar.

### Q-H2. Perfil de las muertes con la etiqueta revisada

_Fuente: `sql/06_revision_labels/06_smm_death_overlap.sql`_

| Perfil | Parto | Elegible a las 24 h | Con SMM | Muertes |
|:---|:---|:---|:---|---:|
| Parto, elegible a las 24 h | Sí | Sí | Sí | 3 |
| Parto, terminó antes de 24 h | Sí | No | Sí | 1 |
| No parto, elegible a las 24 h | No | Sí | Sí | 2 |
| No parto, terminó antes de 24 h | No | No | Sí | 4 |

**Interpretación.** Las 10 muertes llevan SMM. Tres son partos elegibles para el modelo de 24 h, 1 es un parto que terminó antes de 24 h, y el resto son admisiones de no parto (2 elegibles y 4 que terminaron antes de 24 h).

### Q-H3. SMM por número de indicadores y muerte en la misma admisión

_Fuente: `sql/06_revision_labels/06_smm_death_overlap.sql`_

| Indicadores por admisión | Admisiones con SMM | Murieron en la misma admisión | % que murió |
|:---|---:|---:|---:|
| 1 | 619 | 2 | 0.3% |
| 2 | 119 | 4 | 3.4% |
| 3 | 45 | 0 | 0.0% |
| 4 | 27 | 0 | 0.0% |
| 5 | 22 | 2 | 9.1% |
| 6 | 10 | 2 | 20.0% |
| 7 | 4 | 0 | 0.0% |
| 8 | 1 | 0 | 0.0% |
| 10 | 1 | 0 | 0.0% |
| Dos o más | 229 | 8 | 3.5% |
| Total | 848 | 10 | 1.2% |

**Interpretación.** 8 de las 229 admisiones con SMM y dos o más indicadores (3.5%) murieron, frente a 2 de 619 con un solo indicador (0.3%). La mortalidad aumenta con el número de indicadores. Las filas «Dos o más» y «Total» son sumas de las filas anteriores.

### Q-H4. Indicadores de SMM presentes en las admisiones con muerte

_Fuente: `sql/06_revision_labels/06_smm_death_overlap.sql`_

| Indicador | Admisiones con muerte |
|:---|---:|
| Ventilación | 6 |
| Paro cardíaco/fibrilación ventricular | 5 |
| SDRA | 4 |
| CID | 4 |
| Choque | 3 |
| Insuficiencia renal aguda | 2 |
| Conversión del ritmo cardíaco | 2 |
| Edema pulmonar/insuficiencia cardíaca aguda | 2 |
| Histerectomía | 1 |
| Trastornos cerebrovasculares puerperales | 1 |
| Sepsis | 1 |
| Anemia falciforme con crisis | 1 |

**Interpretación.** Las muertes llevan sobre todo indicadores de soporte de órganos o de un curso terminal: ventilación en 6 de las 10, paro cardíaco en 5, SDRA y CID en 4 cada uno, y choque en 3. Por lo tanto, parte del solapamiento refleja cómo se codifica un curso fatal, y no solo una relación clínica entre los dos desenlaces. Una admisión puede llevar varios indicadores.

### Cifras clave del manuscrito revisado

_Fuente: `notebooks/revision/` (`02_grouped_validation_smm`, `03_resampling_comparison_smm`, `04_creatinine_indicator_sensitivity_smm`, `05_era_temporal_validation_smm`, `06_smm_renal_only_sensitivity`, `07_smm_timing_vs_prediction_time`; salidas agregadas `outputs_*.txt`)_

| Cifra | Valor | Nota |
|:---|:---|:---|
| Admisiones de parto elegibles a las 24 h | 19,383 | Cohorte de validación |
| Pacientes | 13,710 | |
| Eventos de SMM | 445 | 2.30% de las admisiones |
| Muertes en la misma admisión | 3 | No bastan para modelar la mortalidad |
| AUROC, ensamble apilado | 0.789 (0.765–0.813) | Validación cruzada anidada agrupada por paciente, bootstrap a nivel de paciente |
| AUPRC, ensamble apilado | 0.167 (0.138–0.206) | Prevalencia 0.023 |
| AUROC, regresión logística | 0.780 | AUPRC 0.154 |
| AUROC, XGBoost | 0.791 | AUPRC 0.163 |
| Ensamble menos regresión logística (AUROC) | +0.009 (0.002–0.016) | Sin diferencia con XGBoost |
| Sensibilidad en el 5% superior (969 admisiones) | 0.354 | VPP 0.163, especificidad 0.957 |
| Sensibilidad en el 10% superior | 0.517 | VPP 0.119 |
| Cambio del AUROC sin el indicador de creatinina: regresión logística | −0.085 | Ensamble: −0.013 |
| Partos con un ingreso a UCI en las primeras 24 h | 115 | 90 con SMM; sin discriminación en ese estrato |
| Prevalencia de SMM por grupo de año de anclaje | 1.47% (2008–2010) a 5.69% (2020–2022) | Entre los partos elegibles, solo ICD-9 1.65% (174 de 10,519) y solo ICD-10 3.06% (271 de 8,864); entre las 19,425 hospitalizaciones de parto, 1.66% y 3.06%. La era y la versión de ICD están alineadas |
| AUROC del ensamble en la validación temporal (cuatro bloques posteriores) | 0.760–0.807 | Observado/esperado 1.34 a 2.12: la discriminación se mantiene y la calibración se desplaza |
| Entrenar con ICD-9, evaluar en ICD-10 (AUROC) | 0.775 (0.745–0.805) | Observado/esperado 1.22; pendiente de calibración 0.84 |
| Admisiones con SMM con un indicador de procedimiento con certeza antes del momento de predicción | 59 (13.3%) | Otras 25 (5.6%) no se pueden ordenar, 42 (9.4%) tienen indicadores de procedimiento solo después de este, y 319 (71.7%) se basan solo en códigos de diagnóstico (Q-J1) |
| Cambio del AUROC del ensamble sin variables administrativas / con la era añadida | −0.016 / +0.012 | Intervalos −0.026 a −0.004 y 0.004 a 0.022 |

**Interpretación.** A las 24 h la SMM se ordena de forma moderadamente buena, y la ganancia del ensamble sobre la regresión logística es pequeña. Con 3 muertes en la misma admisión, la mortalidad no se modela. En la validación temporal la discriminación se mantiene, pero la calibración se desplaza a medida que sube la prevalencia. Los resultados son exploratorios, de un solo centro y sin validación externa.

### Q-I1. SMM por grupo de año de anclaje y versión de codificación (partos elegibles)

_Fuente: `notebooks/revision/05_era_temporal_validation_smm.ipynb` (`outputs_era_temporal.txt`)_

| Grupo | Partos elegibles | Eventos de SMM | Prevalencia |
|:---|---:|---:|---:|
| 2008–2010 | 8,212 | 121 | 1.47% |
| 2011–2013 | 4,328 | 86 | 1.99% |
| 2014–2016 | 3,569 | 104 | 2.91% |
| 2017–2019 | 2,343 | 81 | 3.46% |
| 2020–2022 | 931 | 53 | 5.69% |
| Codificados solo en ICD-9 | 10,519 | 174 | 1.65% |
| Codificados solo en ICD-10 | 8,864 | 271 | 3.06% |
| Todos los partos elegibles | 19,383 | 445 | 2.30% |

**Interpretación.** La prevalencia aumenta con el grupo calendario, y las dos versiones de codificación están alineadas con los grupos: los dos primeros grupos se codificaron sobre todo en ICD-9 (81% y 65% de sus partos), 2014–2016 en ambas versiones (28% en ICD-9, 1,017 de 3,569), y los dos últimos casi por completo en ICD-10. El efecto de la versión de codificación no se puede separar del efecto del período. El 1.65% y el 3.06% se refieren a los 19,383 partos elegibles; entre las 19,425 hospitalizaciones de parto son 1.66% y 3.06% (Q-C2).

### Q-J1. Momento de los indicadores de SMM respecto al momento de predicción

_Fuente: `notebooks/revision/07_smm_timing_vs_prediction_time.ipynb` (`outputs_smm_timing.txt`)_

El momento de predicción T es la hora de admisión más 24 h. Los códigos de diagnóstico ICD no tienen fecha, por lo que no se pueden ubicar respecto a T. Los códigos de procedimiento ICD tienen solo una fecha de calendario (`chartdate`): un procedimiento es con certeza anterior a T si su fecha más un día es igual o anterior a T, con certeza posterior a T si su fecha es igual o posterior a T, y ambiguo en los demás casos. Cada una de las 445 admisiones con SMM entre los partos elegibles cae en una categoría:

| Categoría | Sin un indicador basado en diagnóstico | Con un indicador basado en diagnóstico | Admisiones | % de SMM |
|:---|---:|---:|---:|---:|
| A. Un indicador de procedimiento con certeza antes de T | 23 | 36 | 59 | 13.3 |
| B. Ninguno con certeza antes de T, al menos uno ambiguo | 6 | 19 | 25 | 5.6 |
| C. Indicadores de procedimiento, todos con certeza después de T | 14 | 28 | 42 | 9.4 |
| D. Sin indicador de procedimiento (solo códigos de diagnóstico; sin hora) | 0 | 319 | 319 | 71.7 |
| Total | 43 | 402 | 445 | 100.0 |

Indicadores basados en procedimientos (una admisión puede aparecer en varias columnas de la misma fila):

| Indicador | Antes de T | Ambiguo | Después de T | Admisiones con el indicador |
|:---|---:|---:|---:|---:|
| Histerectomía | 38 | 13 | 28 | 79 |
| Ventilación | 27 | 12 | 21 | 60 |
| Conversión del ritmo cardíaco | 0 | 3 | 3 | 6 |

Verificaciones de consistencia (todas según lo esperado): las 42 hospitalizaciones de parto no elegibles a las 24 h incluyen 2 SMM y 1 muerte; de las 10 muertes hospitalarias del universo obstétrico, 5 ocurren antes de T (1 parto y 4 otras admisiones obstétricas) y 5 en T o después (3 partos y 2 otras obstétricas).

**Interpretación.** Al menos 59 admisiones con SMM (13.3%) tenían un indicador de procedimiento ya registrado antes del momento de predicción, por lo que para ellas el modelo ve en parte el evento que clasifica; para 25 (5.6%) no se puede establecer el orden, y 42 (9.4%) tienen sus indicadores de procedimiento solo después de T. Para 319 (71.7%) la etiqueta se basa solo en códigos de diagnóstico y no se puede ubicar en el tiempo. Las 126 admisiones (28.3%) con un indicador de procedimiento fechado son las únicas que permiten una verificación del momento. La fila de ventilación muestra 60 admisiones con el indicador (27 + 12 + 21), el conteo distinto; los totales anteriores que sumaban las columnas de momento contaban dos veces una admisión cuando tenía dos procedimientos fechados. El resultado respalda la redacción del manuscrito: el modelo clasifica la SMM a las 24 h y no predice su inicio (Apéndice C, Tabla A3).

## Decisiones tomadas el 2026-10-23

- **D1, alcance del Modelo A.** Decidido: análisis exploratorio de factibilidad, usando la etiqueta de muerte en la misma admisión. Con 10 eventos, el cálculo del tamaño de muestra mostrará que no alcanza para un modelo, y la SMM es el desenlace principal.
- **D2, título.** Decidido: reformular con la SMM como desenlace principal; el título final se fija al final.
- **D3, punto de predicción.** Decidido: ventana de 24 h para los predictores de ambos modelos, con la SMM definida por admisión (los códigos de diagnóstico no tienen fecha y los de procedimiento solo una fecha de calendario, por lo que los indicadores no se pueden ubicar con exactitud respecto al punto de 24 h; Q-J1 lo cuantifica) y la limitación declarada.
- **D4, ICD-9.** Decidido: algoritmo oficial de los CDC para ICD-9-CM, con la versión solo ICD-10 como análisis de sensibilidad. Q-C2 no muestra un empeoramiento: la opción (a) conserva 1.6 veces los eventos de la opción (b).
- **D5, alcance de la SMM.** Decidido: la hospitalización de parto como alcance principal, con 447 eventos en 19,425 partos, y cualquier admisión obstétrica como análisis de sensibilidad (401 casos fuera del parto).
- **D6, regla de cohorte.** Decidido: sin regla de posición, porque la posición 4 o menor excluiría 38 casos de SMM y 3 muertes de admisiones graves. El análisis de sensibilidad con cualquier admisión obstétrica exige al menos un código obstétrico estructurado en cualquier posición.
- **D7, definición de muerte para el Modelo A.** Decidido: la etiqueta principal es la muerte en la misma admisión. Los horizontes de 42 y 365 días (13 y 26 pacientes) se reportan solo como un análisis de sensibilidad descriptivo, denominado mortalidad por cualquier causa.
- **D8, admisiones con muerte o alta antes de 24 h.** Decidido: se dejan fuera del modelo de 24 h y sus eventos se reportan por separado. Cinco de las 10 muertes ocurren en las primeras 24 h.
- **D9, punto de predicción.** Decidido: admisión + 24 h; los 28 indicadores de grupos de diagnóstico (que provienen de diagnósticos al alta) se retiran del modelo principal; el ingreso a UCI se mide dentro de las primeras 24 h en lugar del número de estancias.
- **D10, ventana y variables de UCI.** Decidido: la ventana de predictores va desde 24 h antes de la admisión hasta 24 h después, porque los valores de triage ya están disponibles en el punto de predicción (la cobertura de hemoglobina sube de 53.0% a 81.6%). Las 14 variables que existen solo en la UCI y el ingreso a UCI se dejan fuera del modelo principal y pasan a un análisis de sensibilidad aparte.
- **D11, pruebas de laboratorio en el modelo principal.** Decidido: entran las pruebas de laboratorio con un valor en al menos el 10% de los partos elegibles: hemoglobina (81.6%), hematocrito (81.8%) y creatinina (20.5%). Las otras diez pruebas de laboratorio y las 14 variables de UCI van al análisis de sensibilidad con indicadores de ausencia de datos. La regla usa solo la disponibilidad, no el desenlace, por lo que no añade fuga de información. La creatinina está presente en el 62.9% de los casos de SMM: lleva un indicador de ausencia de datos y se reporta con y sin él. El diccionario final con el rol de cada variable está en Q-G0.
- **D12, hemoglobina y hematocrito.** Decidido: solo la hemoglobina entra al modelo principal y el hematocrito pasa al análisis de sensibilidad, porque su correlación es 0.924 (0.945 en SMM) y casi siempre se miden juntos. Por lo tanto, el modelo principal usa hemoglobina y creatinina, con un indicador de ausencia de datos para la creatinina.

## Decisiones D13 a D16 (marco de validación y manuscrito)

- **D13, modelos y desbalance.** Decidido: mantener el ensamble de la tesis (random forest, XGBoost, extra trees y regresión logística con un metaaprendiz logístico) y compararlo con la regresión logística, sin remuestreo en el marco principal.
- **D14, partos con un ingreso a UCI en las primeras 24 h.** Decidido: permanecen en el modelo principal (115 admisiones), con desempeño estratificado y un análisis de sensibilidad sin ellos, para no descartar casos sin evidencia temporal.
- **D15, SMOTE.** Decidido: una comparación breve en un apéndice (Apéndice B del artículo) entre sin corrección, solo pesos de clase y SMOTE-NC, cada uno ajustado por separado, para responder a R1-9.
- **D16, límites de plausibilidad.** Decidido: hemoglobina de 3 a 20 g/dL, hematocrito de 10 a 65% y creatinina de 0.1 a 20 mg/dL, más el análisis de sensibilidad sin el indicador de creatinina.

## Fuentes

| Origen | Contenido |
|:---|:---|
| `sql/05_revision_audit/` | Auditoría Q1 a Q21 sobre las etiquetas enviadas |
| `sql/06_revision_labels/` | Listas oficiales de códigos, bandera de parto, etiquetas de la misma admisión, regla de cohorte y horizontes de muerte (Q22, Q23, Q-C1 a Q-C7, Q-D1 a Q-D5, Q-E1 a Q-E4) |
| `sql/07_revision_predictors/` | Predictores con una ventana de 24 h y su disponibilidad (Q-F1 a Q-F5); diccionario final de predictores y ausencia de datos (Q-G0 a Q-G5) |
| `sql/06_revision_labels/06_smm_death_overlap.sql` | SMM y muerte en la misma admisión con las etiquetas revisadas (Q-H1 a Q-H4) |
| `notebooks/revision/01_audit_patient_overlap.ipynb` | Solapamiento de pacientes entre entrenamiento y prueba (Q24, Q25) |
| `notebooks/revision/02_grouped_validation_smm.ipynb` a `05_era_temporal_validation_smm.ipynb` | Validación agrupada, comparación de remuestreo, indicador de creatinina y validación por era/temporal (Cifras clave, Q-I1) |
| `notebooks/revision/06_smm_renal_only_sensitivity.ipynb` | Sensibilidad sin las admisiones cuyo único indicador de SMM es la insuficiencia renal aguda (Q-C5, T50) |
| `notebooks/revision/07_smm_timing_vs_prediction_time.ipynb` | Momento de los indicadores de SMM respecto al momento de predicción (Q-J1, T52) |

Las consultas Q-D0, Q-D2, Q-E0, Q-E2, Q-E3, Q-F0 y Q-G6 (unidades registradas) se usan en el texto de las secciones y en el plan de revisión, pero aquí no tienen una tabla propia.
