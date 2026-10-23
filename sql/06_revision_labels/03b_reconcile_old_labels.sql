-- ============================================================================
-- 06_revision_labels / 03b_reconcile_old_labels.sql
-- Reconcile the SMM label of the SUBMITTED dataset with the original view
-- ============================================================================
-- Why: Q-C4 shows that the ORIGINAL view (mimiciv.hadm_with_smm) flags 405
--   admissions in this universe (389 + 16), whereas the submitted dataset
--   (mimiciv.cohort_smm_dataset, outcome_smm = 1) has 475.  The 70-admission
--   gap must be explained before the response letter says "from 475 to 848".
--   Read-only: SELECTs only, aggregate counts only.
-- ============================================================================

-- Q23a  Is the dataset the same universe as label_admission_v2?
SELECT COUNT(*)                                                         AS n_dataset_rows,
       COUNT(*) FILTER (WHERE l.hadm_id IS NULL)                        AS dataset_rows_not_in_label_table,
       COUNT(*) FILTER (WHERE d.outcome_smm = 1)                        AS n_dataset_smm
FROM mimiciv.cohort_smm_dataset d
LEFT JOIN mimiciv.label_admission_v2 l ON l.hadm_id = d.hadm_id;

-- Q23b  Where do the dataset's SMM positives come from?
SELECT COUNT(*) FILTER (WHERE old.hadm_id IS NOT NULL AND l.smm_any)         AS in_view_and_in_new,
       COUNT(*) FILTER (WHERE old.hadm_id IS NOT NULL AND NOT l.smm_any)     AS in_view_not_new,
       COUNT(*) FILTER (WHERE old.hadm_id IS NULL     AND l.smm_any)         AS not_in_view_but_in_new,
       COUNT(*) FILTER (WHERE old.hadm_id IS NULL     AND NOT l.smm_any)     AS in_dataset_only
FROM mimiciv.cohort_smm_dataset d
JOIN mimiciv.label_admission_v2 l ON l.hadm_id = d.hadm_id
LEFT JOIN (SELECT DISTINCT hadm_id FROM mimiciv.hadm_with_smm) old ON old.hadm_id = d.hadm_id
WHERE d.outcome_smm = 1;

-- Q23c  Which indicators does the original view assign to admissions that the
--       submitted dataset flags but the view does not?  (aggregate)
-- Run this only if in_dataset_only > 0 or not_in_view_but_in_new > 0; compare the
-- definition of outcome_smm in sql/03_cohort_smm/smm_dataset_en.sql.
SELECT COUNT(*) FILTER (WHERE d.outcome_smm = 1 AND l.smm_only_renal)   AS dataset_smm_renal_only_new,
       COUNT(*) FILTER (WHERE d.outcome_smm = 1 AND NOT l.is_delivery_v2) AS dataset_smm_not_delivery_v2
FROM mimiciv.cohort_smm_dataset d
JOIN mimiciv.label_admission_v2 l ON l.hadm_id = d.hadm_id;
