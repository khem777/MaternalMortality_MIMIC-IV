# Spanish → English naming map

This project's working SQL was originally written in Spanish while
debugging locally with Emmanuel. Since the manuscript, the code repository,
and peer review are all in English, every SQL script now has an English
copy (`*_en.sql`) alongside a Spanish original renamed with an `*_es.sql`
suffix (so the pairing is obvious from the filename alone), and **the
English copy is the one that should be run against the database going
forward** — so every table/view this project creates from now on has an
English name.

The Spanish originals (`*_es.sql`) are kept only as a paper trail of the
debugging history (matched 1:1 against `docs/Cohort de embarazadas.txt` and
the chat history where the cohort issues were found) — they are not meant
to be run again. Their content is left in Spanish on purpose (it's a
historical record of the actual debugging session); only the filename was
changed, from the original ad hoc Spanish name to the `_es` suffix, for
consistency with the `_en` pair and so an English-speaking reviewer can
tell the two apart at a glance.

## File pairs

| Spanish (reference only) | English (run this one) |
|---|---|
| `sql/02_cohort_mortality/maternal_cohort_expanded_es.sql` (was `cohorte_materna_ampliada.sql`) | `sql/02_cohort_mortality/maternal_cohort_expanded_en.sql` |
| *(inline in `docs/Cohort de embarazadas.txt`)* | `sql/02_cohort_mortality/maternal_pregnancy_diagnoses_narrow_en.sql` |
| `sql/02_cohort_mortality/maternal_cohort_diagnostic_funnel_es.sql` (was `diagnostico_funnel_cohorte_materna.sql`) | `sql/02_cohort_mortality/maternal_cohort_diagnostic_funnel_en.sql` |
| `sql/03_cohort_smm/smm_cohort_es.sql` (was `cohorte_near_miss_smm.sql`) | `sql/03_cohort_smm/smm_cohort_en.sql` |
| `sql/03_cohort_smm/lookup_itemids_labevents_es.sql` (was `lookup_itemids_labevents.sql`) | `sql/03_cohort_smm/lookup_itemids_labevents_en.sql` |

## Database object names

| Spanish (do not (re)create) | English (create this instead) |
|---|---|
| `mimiciv.diagnosticos_embarazos` | `mimiciv.pregnancy_diagnoses_narrow` |
| `mimiciv.diagnosticos_embarazos_ampliado` | `mimiciv.pregnancy_diagnoses_expanded` |
| `admisiones_maternas` (CTE) | `maternal_admissions` |
| `cohorte_final` (CTE) | `final_cohort` |
| `mimiciv.hadm_con_smm` | `mimiciv.hadm_with_smm` |
| `mimiciv.hadm_hospitalizacion_parto` | `mimiciv.hadm_delivery_hospitalization` |
| `edad_aprox` (column) | `approx_age` |
| `tuvo_uci` (column) | `had_icu_stay` |
| `deathtime_resuelto` (column) | `resolved_deathtime` |
| `n_registros_labevents` (column) | `n_labevents_records` |
| `es_hospitalizacion_parto` (column) | `is_delivery_hospitalization` |
| `smm_categoria_principal` (column) | `primary_smm_category` |
| `categoria_principal` (subquery alias) | `primary_category` |

Already-English and unchanged: `mimiciv.cohort_maternal_dataset`,
`mimiciv.cohort_maternal_diagnoses`, `mimiciv.cohort_smm_dataset`,
`mimiciv.smm_code_patterns`, `gdg_m01`–`gdg_m28` (corrected from the earlier
`gdg_m01`–`gdg_m30` placeholder once the expert classification was
consolidated to 26 real groups + 2 residual k-means clusters = 28 total;
see the new file pair below).

## Diagnostic-group pipeline (added 2026-09-17)

The physician-reviewed maternal diagnostic-group classification (26 groups
+ `diagnoses_excluded`) is implemented as a "modifiable" data/generator/logic
split, not hand-written SQL, so future panel feedback only ever requires
editing the two CSVs below and re-running the generator:

| File | Role |
|---|---|
| `sql/02_cohort_mortality/maternal_diagnoses_group_catalog.csv` | source-of-truth data: one row per `GDG_Mxx` diagnostic group (26 expert groups + 2 residual-cluster placeholders) |
| `sql/02_cohort_mortality/maternal_diagnoses_group_map.csv` | source-of-truth data: one row per ICD code (4,116) → `group_code`, or the `diagnoses_excluded` sentinel |
| `scripts/generate_maternal_diagnoses_group_sql.py` | generator: reads the two CSVs above, writes `maternal_diagnoses_group_load_en.sql` -- never hand-edit the generated file |
| `sql/02_cohort_mortality/maternal_diagnoses_group_load_en.sql` | **generated file, do not hand-edit** -- creates + populates `mimiciv.maternal_diagnoses_group_catalog` and `mimiciv.maternal_diagnoses_group_map` |
| `sql/02_cohort_mortality/maternal_diagnoses_group_assign_en.sql` | run after the load script -- stamps `cohort_maternal_diagnoses.diagnoses_group` and (re)creates the generic `mimiciv.update_feature_diagnoses_cohort_maternal_dataset()` propagation function |

Run order: `maternal_diagnoses_group_load_en.sql`, then
`maternal_diagnoses_group_assign_en.sql`. To change the classification later:
edit the CSV(s) → re-run the generator script → re-run the load script → 
re-run the assign script. No other file needs to change.

`libraries/database.py` has already been updated to query the English
object names (`get_smm_denominator_comparison_query()`,
`get_smm_category_summary_query()`, `get_smm_indicator_summary_query()`).
