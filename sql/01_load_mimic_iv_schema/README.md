# Step 1 — Load the raw MIMIC-IV schema into a local Postgres instance

These scripts are copied from the companion neonatal-mortality project
(`Stacked-Model-Neonatal-MimicIV`), because this project's cohort is built
against the **same underlying MIMIC-IV schema**, already loaded in the same
local Postgres data directory (see `docker-compose.yml` at the project
root). You normally do **not** need to run these again if that instance is
already loaded — they are included here so this repository is
self-contained and reproducible on its own, e.g. for a reviewer setting up
a fresh instance from scratch.

They contain **no patient data** — only table definitions, indexes, and the
public MIMIC-IV lab-item dictionary (`d_labitems`: standard test names such
as "Hemoglobin" or "Creatinine", with no patient information attached).

Run them in this order, against your own credentialed, locally-loaded copy
of MIMIC-IV:

1. `mimic_create_database.sql` — creates the `mimiciv` schema and all base
   tables (admissions, patients, icustays, chartevents, labevents,
   diagnoses_icd, etc.).
2. Download the official MIMIC-IV CSV export from PhysioNet (requires your
   own credentialed access, see the main README) and place the files per
   the volume mount in `docker-compose.yml`. The `powershell_csv_prep/`
   scripts in this folder are optional Windows helpers used to merge/order
   multi-part CSV exports for a couple of large tables before loading —
   adjust the paths inside them to your own environment, or skip them if
   your CSV export is already a single file per table.
3. `mimic_load_data_upgrade.sql` — loads the CSVs into the tables created
   in step 1 (server-side `COPY`, so paths are relative to the Postgres
   *container's* filesystem, per the `docker-compose.yml` volume mount).
4. `mimic_add_indexes.sql` — adds the indexes used by the cohort-extraction
   queries in `sql/02_cohort_mortality/` and `sql/03_cohort_smm/`.

`mimic_generals_query.sql` holds a handful of ad-hoc exploratory queries
used while validating the schema load; not part of the build sequence.

An alternative, official tool for this same step is
[MIT-LCP/mimic-code](https://github.com/MIT-LCP/mimic-code), if you prefer
its build scripts to the ones here.
