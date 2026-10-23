# Count audit for the maternal article (healthcare-4661619)

> **Aggregate counts only.** This document contains no patient-level data or identifiers. All figures come from MIMIC-IV v3.1 (PhysioNet, use subject to the data use agreement) and were obtained with the SQL scripts and the notebook named in each section.

Only 10 of the 41 positive admissions for Model A are a death in the same admission, and 14,064 of the 25,736 admissions cannot have SMM under the current labeling.

| Admissions | Patients | Deaths in the same admission | SMM admissions |
|---:|---:|---:|---:|
| 25,736 | 15,084 | 10 | 475 |

## How to read this document

- This is a copy of the count dashboard used during the manuscript revision, generated from the same data (published dashboard, version 13, 2026-10-23).
- Sections **Q1 to Q21**, **Q24** and **Q25** describe the labels and splits of the submitted manuscript. From **Revision v2** onward the counts come from the new scripts in `sql/06_revision_labels` and `sql/07_revision_predictors`; the original scripts were not modified.
- Each section names its source. The queries return no individual rows.
- SMM = severe maternal morbidity; ICU = intensive care unit; DRG = diagnosis-related group; DIC = disseminated intravascular coagulation.
- The methodological decisions (D1 to D10) are at the end.

## Contents

- [Dataset size and labels by scope](#dataset-size-and-labels-by-scope)
- [Q1. Cohort and repeat patients](#q1-cohort-and-repeat-patients)
- [Q2. Model A positives under the submitted label](#q2-model-a-positives-under-the-submitted-label)
- [Q3. Relationship of each positive to the admission of death](#q3-relationship-of-each-positive-to-the-admission-of-death)
- [Q4. Positives contributed by each deceased patient](#q4-positives-contributed-by-each-deceased-patient)
- [Q5. Redefinition: death in the same admission](#q5-redefinition-death-in-the-same-admission)
- [Q6. ICD version of the admissions](#q6-icd-version-of-the-admissions)
- [Q7. SMM rate by era (per 10,000 deliveries)](#q7-smm-rate-by-era-per-10000-deliveries)
- [Q8. Deliveries in ICD-9 admissions (proxy)](#q8-deliveries-in-icd-9-admissions-proxy)
- [Q9. Patients with SMM](#q9-patients-with-smm)
- [Q10. SMM versus death in the same admission](#q10-smm-versus-death-in-the-same-admission)
- [Q11. SMM versus the submitted mortality label](#q11-smm-versus-the-submitted-mortality-label)
- [Q12. Inclusion rule: obstetric diagnosis in position 4 or less](#q12-inclusion-rule-obstetric-diagnosis-in-position-4-or-less)
- [Q13. Variable availability by ICU and SMM (% with a value)](#q13-variable-availability-by-icu-and-smm--with-a-value)
- [Q14. When the first creatinine appears](#q14-when-the-first-creatinine-appears)
- [Q15. SMM cases by indicator](#q15-smm-cases-by-indicator)
- [Q16. Profile of deaths in the same admission](#q16-profile-of-deaths-in-the-same-admission)
- [Q17. Approximate admission year and ICD version](#q17-approximate-admission-year-and-icd-version)
- [Q18. SMM indicators by anchor-year group](#q18-smm-indicators-by-anchor-year-group)
- [Q19. Distinct indicators per SMM admission (submitted label)](#q19-distinct-indicators-per-smm-admission-submitted-label)
- [Q20. Alternative SMM definitions (submitted label)](#q20-alternative-smm-definitions-submitted-label)
- [Q21. SMM outside delivery: obstetric chapters (submitted label)](#q21-smm-outside-delivery-obstetric-chapters-submitted-label)
- [Revision v2: Labels revised with the official CDC list](#revision-v2-labels-revised-with-the-official-cdc-list)
- [Q-C1. Cohort and new labels](#q-c1-cohort-and-new-labels)
- [Q22. Original delivery flag versus the new one](#q22-original-delivery-flag-versus-the-new-one)
- [Q-C2. SMM in deliveries by coding version](#q-c2-smm-in-deliveries-by-coding-version)
- [Q-C3. SMM in deliveries by indicator and version](#q-c3-smm-in-deliveries-by-indicator-and-version)
- [Q-C4. Official list versus the original label](#q-c4-official-list-versus-the-original-label)
- [Q-C5. Alternative SMM definitions in deliveries](#q-c5-alternative-smm-definitions-in-deliveries)
- [Q-C6. Patients with more than one admission](#q-c6-patients-with-more-than-one-admission)
- [Q-C7. Codes the original list had and the official one does not](#q-c7-codes-the-original-list-had-and-the-official-one-does-not)
- [Q23. Manuscript dataset versus the new label](#q23-manuscript-dataset-versus-the-new-label)
- [Q24. Patient overlap in the submitted hold-out](#q24-patient-overlap-in-the-submitted-hold-out)
- [Q25. Overlap in cross-validation and with other seeds](#q25-overlap-in-cross-validation-and-with-other-seeds)
- [Q-D1. Lowest position of the obstetric diagnosis](#q-d1-lowest-position-of-the-obstetric-diagnosis)
- [Q-D3. Type of the first obstetric code and position rule](#q-d3-type-of-the-first-obstetric-code-and-position-rule)
- [Q-D4. Admissions with obstetric evidence only from the title text](#q-d4-admissions-with-obstetric-evidence-only-from-the-title-text)
- [Q-D5. Effect of each cohort rule on the revised labels](#q-d5-effect-of-each-cohort-rule-on-the-revised-labels)
- [Q-E1. Deaths within a horizon from admission (any cause)](#q-e1-deaths-within-a-horizon-from-admission-any-cause)
- [Q-E4. Days from admission to the first later death](#q-e4-days-from-admission-to-the-first-later-death)
- [Q-F1. Eligibility for a 24-h model and events lost](#q-f1-eligibility-for-a-24-h-model-and-events-lost)
- [Q-F2. Hours from admission to death](#q-f2-hours-from-admission-to-death)
- [Q-F3. Timing of the first ICU admission and outcomes](#q-f3-timing-of-the-first-icu-admission-and-outcomes)
- [Q-F4. Availability of each variable in the predictor window (eligible deliveries, D10 window)](#q-f4-availability-of-each-variable-in-the-predictor-window-eligible-deliveries-d10-window)
- [Q-F5. Delivery labs: effect of the window from 24 h before admission to 24 h after](#q-f5-delivery-labs-effect-of-the-window-from-24-h-before-admission-to-24-h-after)
- [Decisions made on 2026-10-23](#decisions-made-on-2026-10-23)

### Dataset size and labels by scope

| Scope | Records (admissions) | Patients | Deaths: mortality label | SMM cases |
|:---|---:|---:|---:|---:|
| Submitted label (manuscript) | 25,736 | 15,084 | 41 | 475 |
| Any obstetric admission (current universe, new labels) | 25,736 | 15,084 | 10 | 848 |
| With structured obstetric code (D6 sensitivity) | 25,644 | 15,022 | 10 | 837 |
| Delivery hospitalizations only (main scope D5) | 19,425 | 13,729 | 4 | 447 |

**Interpretation.** With the submitted label there were 41 mortality positives, but only 10 were a death in that admission: the others were earlier admissions of patients who died later. The 10 deaths belong to 10 different patients and none were lost by the cohort rule. In delivery hospitalizations 4 remain, that is, 4 deaths in 19,425 deliveries. With so few deaths, Model A is a descriptive, feasibility analysis, and SMM is the main outcome.

### Q1. Cohort and repeat patients

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

**Interpretation.** The cohort has 25,736 admissions from 15,084 patients, and 6,793 of those patients have more than one admission. The figures match the manuscript. With an admission-level split, the same patient can end up in both training and test.

### Q2. Model A positives under the submitted label

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

**Interpretation.** The current label flags 41 admissions as positive, which correspond to 26 distinct patients. The mortality model therefore has fewer independent events than the manuscript suggests.

### Q3. Relationship of each positive to the admission of death

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Relationship | Admissions | Patients | Death in a cohort admission | Admission of death with ICU | This admission with ICU | Median days to death | Minimum (days) | Maximum (days) |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
| Same admission | 10 | 10 | 10 | 7 | 7 | 1.0 | 0.2 | 21.4 |
| Later admission | 31 | 18 | 6 | 18 | 4 | 1,354.6 | 11.3 | 4,840.0 |

**Interpretation.** Only 10 positives are the admission in which the patient died. The other 31 are earlier admissions of 18 patients who died later (two patients appear in both rows: 2). Of those earlier positives, 25 have the death in an admission outside the obstetric cohort. The median time to death is 3.7 years and the maximum is 13.3 years. The outcome is mostly late in-hospital all-cause mortality.

### Q4. Positives contributed by each deceased patient

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Positives per patient | Patients |
|:---|---:|
| 1 | 18 |
| 2 | 4 |
| 3 | 3 |
| 6 | 1 |

**Interpretation.** Patients who contribute more than one positive are copies of a single outcome, and they end up split between training and test if the split is by admission. The first row is those contributing one; the rest contribute two, three or six.

### Q5. Redefinition: death in the same admission

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Deaths in the same admission | With ICU | No ICU | Within the first 24 h |
|---:|---:|---:|---:|
| 10 | 7 | 3 | 5 |

**Interpretation.** With the correct definition, 10 deaths from 10 patients remain, and all 10 were already among the current positives. Because 5 occurred in the first 24 h, a 24-h prediction point leaves half of them out. With so few events, a machine-learning model is not supported: descriptive analysis is recommended.

### Q6. ICD version of the admissions

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Version in the admission | Admissions | SMM cases | Mortality positives (Model A) | Deliveries detected |
|:---|---:|---:|---:|---:|
| ICD-10 only | 11,671 | 475 | 2 | 8,857 |
| ICD-9 only | 14,064 | 0 | 39 | 0 |
| Both | 1 | 0 | 0 | 0 |

**Interpretation.** All SMM cases and all detected deliveries are in ICD-10 admissions. The 14,064 ICD-9 admissions enter as certain negatives, because the labeling only recognizes ICD-10 codes. For mortality the opposite happens: 39 of the 41 positives are in ICD-9 admissions. The "Both" row assumes the reading 1, 0, 0, 0 of the recorded result.

### Q7. SMM rate by era (per 10,000 deliveries)

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Era | Per 10,000 deliveries |
|:---|---:|
| 2008 - 2010 | 216.5 |
| 2011 - 2013 | 185.6 |
| 2014 - 2016 | 251.5 |
| 2017 - 2019 | 324.0 |
| 2020 - 2022 | 546.6 |

| Anchor-year group | Admissions | With ICD-9 | With ICD-10 | SMM cases | Deliveries (ICD-10) | SMM in delivery | SMM per 10,000 deliveries |
|:---|---:|---:|---:|---:|---:|---:|---:|
| 2008 - 2010 | 10,733 | 8,796 | 1,937 | 52 | 1,524 | 33 | 216.5 |
| 2011 - 2013 | 5,633 | 3,807 | 1,826 | 40 | 1,509 | 28 | 185.6 |
| 2014 - 2016 | 4,724 | 1,461 | 3,264 | 123 | 2,545 | 64 | 251.5 |
| 2017 - 2019 | 3,208 | 1 | 3,207 | 143 | 2,346 | 76 | 324.0 |
| 2020 - 2022 | 1,438 | 0 | 1,438 | 117 | 933 | 51 | 546.6 |

**Interpretation.** The rate rises from 216.5 to 546.6 per 10,000 deliveries, with a minimum of 185.6 in 2011–2013. All these figures come from ICD-10 admissions, so the version change does not explain the rise. The anchor-year group is the window of the patient's anchor year, not the date of each admission: that is why there are ICD-10 admissions in 2008–2010 (they are later admissions of those patients).

### Q8. Deliveries in ICD-9 admissions (proxy)

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Deliveries detected, ICD-10 | ICD-9 admissions with 650 or V27 | Estimated deliveries in total |
|---:|---:|---:|
| 8,857 | 10,540 | 19,397 |

**Interpretation.** The current denominator of deliveries (8,857) leaves out 10,540 ICD-9 admissions with a delivery code. The sum is about 19,397, more than double. Codes 650 and V27 are an ad hoc proxy and not a validated list, so the figure is indicative and does not discount possible overlaps.

### Q9. Patients with SMM

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

**Interpretation.** The 475 SMM admissions correspond to 426 patients, that is, 49 admissions repeat a patient. Patient-level splitting matters, but with less leakage than in mortality.

### Q10. SMM versus death in the same admission

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Combination | Admissions |
|:---|---:|
| No SMM, no in-hospital death | 25,252 |
| No SMM, in-hospital death | 9 |
| SMM, no in-hospital death | 474 |
| SMM, in-hospital death | 1 |

**Interpretation.** Only 1 SMM case died in that admission, and 9 deaths have no SMM indicator. Many are probably in ICD-9 admissions, where SMM is zero by construction; Q16 in part 2 checks this.

### Q11. SMM versus the submitted mortality label

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Combination | Admissions |
|:---|---:|
| No SMM, no mortality label | 25,221 |
| No SMM, mortality label | 40 |
| SMM, no mortality label | 474 |
| SMM, mortality label | 1 |

**Interpretation.** The two outcomes barely overlap: only 1 admission is positive for both. Model A and Model B predict almost disjoint events, and this must be acknowledged in the predictor comparison that Reviewer 1 requests.

### Q12. Inclusion rule: obstetric diagnosis in position 4 or less

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Measure | SQL rule (no position) | With position 4 or less | Difference |
|:---|---:|---:|---:|
| Admissions | 25,736 | 25,574 | 162 |
| SMM cases | 475 | 457 | 18 |
| Deaths in the same admission | 10 | 7 | 3 |

**Interpretation.** The position rule barely changes the cohort (162 admissions), but removes 18 SMM cases and 3 of the 10 deaths. A single rule should be chosen so that the text and the SQL say the same thing.

### Q13. Variable availability by ICU and SMM (% with a value)

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Group | Admissions | Heart rate | Creatinine | Glucose | Lactate | Hemoglobin |
|:---|---:|---:|---:|---:|---:|---:|
| No ICU, no SMM | 24,965 | 0.0% | 19.5% | 9.7% | 1.2% | 49.4% |
| No ICU, with SMM | 292 | 0.0% | 67.5% | 51.7% | 17.5% | 76.0% |
| With ICU, no SMM | 296 | 100.0% | 96.3% | 96.6% | 57.1% | 96.3% |
| With ICU, with SMM | 183 | 100.0% | 99.5% | 99.5% | 75.4% | 98.9% |

**Interpretation.** Only 479 admissions have an ICU stay. SMM reaches 38.2% among them and 1.2% without ICU. Without ICU there is no heart rate, and labs are measured far more often when there is SMM (for example, lactate and creatinine): missingness is informative, not random. Imputing heart rate with the median of ICU patients does not represent the others.

### Q14. When the first creatinine appears

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Variable | Admissions with a value | Median (hours) | 90th percentile (hours) | First value after 24 h | % after 24 h |
|:---|---:|---:|---:|---:|---:|
| Creatinine | 5,544 | 8.4 | 48.0 | 1,164 | 21.0% |

**Interpretation.** Only 5,544 admissions have a creatinine. The median time to the first value is 8.4 hours and the 90th percentile is 48.0 hours. In 1,164 admissions (21.0%) the first value arrives after 24 h. A 24-h window is feasible, but those admissions would have the value missing. Today the "earliest value" has no window and can come from any time in the hospitalization.

### Q15. SMM cases by indicator

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Indicator group | Admissions with the indicator | In delivery hospitalization | Outside delivery |
|:---|---:|---:|---:|
| Renal | 180 | 139 | 41 |
| Hemorrhage | 131 | 72 | 59 |
| Respiratory | 89 | 38 | 51 |
| Other_Medical | 77 | 22 | 55 |
| Sepsis | 62 | 21 | 41 |
| Cardiac | 61 | 24 | 37 |
| Other_Obstetric | 56 | 22 | 34 |

| Indicator | Group | Admissions |
|:---|:---|---:|
| Acute renal failure | Renal | 180 |
| Shock | Hemorrhage | 72 |
| ARDS | Respiratory | 66 |
| Sepsis | Sepsis | 62 |
| DIC | Hemorrhage | 61 |
| Puerperal cerebrovascular disorders | Other_Medical | 55 |
| Ventilation | Respiratory | 51 |
| Pulmonary edema/acute heart failure | Cardiac | 45 |
| Hysterectomy | Hemorrhage | 41 |
| Air and thrombotic embolism | Other_Obstetric | 33 |
| Sickle cell disease with crisis | Other_Medical | 23 |
| Eclampsia | Other_Obstetric | 16 |
| Conversion of cardiac rhythm | Cardiac | 8 |
| Acute myocardial infarction | Cardiac | 7 |
| Cardiac arrest/ventricular fibrillation | Cardiac | 7 |
| Aneurysm | Cardiac | 5 |
| Severe anesthesia complications | Other_Obstetric | 4 |
| Amniotic fluid embolism | Other_Obstetric | 4 |
| Heart failure/arrest during surgery or procedure | Cardiac | 1 |
| Temporary tracheostomy | Respiratory | 1 |

**Interpretation.** 223 of the 475 SMM cases (46.9%) are in non-delivery admissions, while the rate per 10,000 uses only deliveries as the denominator. Acute renal failure appears in 180 cases: 37.9% of the total and 55.2% of delivery admissions with SMM. Shock, sepsis, ARDS and ventilation are generic critical-illness codes. A case can have several indicators, so the sum of the groups exceeds the total. Queries Q19 to Q21 in part 3 measure how much SMM changes if acute renal failure is excluded as the only indicator or if it is restricted to deliveries.

### Q16. Profile of deaths in the same admission

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Profile | ICD version | Delivery flag | SMM | ICU | Deaths |
|:---|:---|:---|:---|:---|---:|
| ICD-9, with ICU, principal obstetric diagnosis | ICD-9 only | No | No | Yes | 4 |
| ICD-9, no ICU, principal obstetric diagnosis | ICD-9 only | No | No | No | 2 |
| ICD-9, with ICU, non-principal obstetric diagnosis | ICD-9 only | No | No | Yes | 2 |
| ICD-10, with ICU, principal obstetric diagnosis | ICD-10 only | Yes | Yes | Yes | 1 |
| ICD-9, no ICU, non-principal obstetric diagnosis | ICD-9 only | No | No | No | 1 |

**Interpretation.** 9 of the 10 deaths are in ICD-9-only admissions, and 1 in ICD-10, which is the only one with SMM. That is why the SMM label hardly sees deaths (Q10): it is a coding-version effect. In 3 deaths the obstetric diagnosis is not the principal one, probably deaths from a non-obstetric cause.

### Q17. Approximate admission year and ICD version

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Approximate year | Admissions | ICD-9 only | ICD-10 only | % ICD-10 | SMM cases | Deliveries (ICD-10) | SMM per 100 ICD-10 admissions |
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

**Interpretation.** The change from ICD-9 to ICD-10 occurs between approximately 2013 and 2016: in 2013, 7.6% of admissions are ICD-10, and from 2017 on all are. The approximate year is the lower bound of the anchor-year window plus the offset of each admission, with a margin of up to two years. Among ICD-10 admissions, SMM goes from 2.3% in 2016 to 6.4% in 2020, without a continuous trend. The rise by era in Q7 depends in part on grouping by anchor-year window and not by admission date.

### Q18. SMM indicators by anchor-year group

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Indicator group | 2008 - 2010 | 2011 - 2013 | 2014 - 2016 | 2017 - 2019 | 2020 - 2022 |
|:---|---:|---:|---:|---:|---:|
| Cardiac | 11 | 1 | 8 | 22 | 19 |
| Hemorrhage | 12 | 9 | 30 | 35 | 45 |
| Other_Medical | 6 | 3 | 39 | 16 | 13 |
| Other_Obstetric | 7 | 2 | 19 | 19 | 9 |
| Renal | 18 | 19 | 32 | 66 | 45 |
| Respiratory | 8 | 4 | 11 | 27 | 39 |
| Sepsis | 8 | 8 | 13 | 15 | 18 |

**Interpretation.** Renal failure goes from 18 to 66 cases between the first and fourth group, and respiratory indicators jump to 39 in the last. Each cell counts admissions with that indicator. Because the first two groups have few ICD-10 admissions, the counts should be divided by the ICD-10 denominator in Q7 before concluding that coding practice or severity changed.

### Q19. Distinct indicators per SMM admission (submitted label)

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Distinct indicators | Admissions | In delivery | Outside delivery |
|:---|---:|---:|---:|
| 1 | 346 | 186 | 160 |
| 2 | 68 | 32 | 36 |
| 3 | 24 | 14 | 10 |
| 4 | 13 | 8 | 5 |
| 5 | 12 | 6 | 6 |
| 6 | 8 | 3 | 5 |
| 7 | 4 | 3 | 1 |

**Interpretation.** 72.8% of SMM admissions have a single indicator (346), and only 4 reach seven. The outcome depends mostly on a single code per admission, which reinforces the question of which indicators truly reflect severity.

### Q20. Alternative SMM definitions (submitted label)

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Definition | Admissions | Patients | With ICU |
|:---|---:|---:|---:|
| A. Submitted label (any indicator, any admission) | 475 | 426 | 183 |
| B. Delivery hospitalizations only (ICD-10 flag) | 252 | 249 | 80 |
| C. Any admission without renal as the only indicator | 345 | 303 | 172 |
| D. Delivery without renal as the only indicator | 142 | 141 | 75 |
| E. Two or more indicators | 129 | 126 | 113 |
| Renal failure only (any admission) | 130 | 127 | 11 |

**Interpretation.** If admissions whose only indicator is acute renal failure are excluded, SMM falls from 475 to 345. Those 130 admissions almost never have ICU (8.5%), versus 49.9% in the rest. With two or more indicators, 129 remain.

### Q21. SMM outside delivery: obstetric chapters (submitted label)

_Source: `sql/05_revision_audit/` (`audit_counts_en.sql`, `audit_counts_part2_en.sql`, `audit_counts_part3_en.sql`)_

| Chapter of codes present | Admissions |
|:---|---:|
| Other (O94–O9A and O98–O99) | 153 |
| Antepartum (O09–O48) | 120 |
| Puerperium (O85–O92) | 103 |
| Labor and delivery (O60–O77) | 42 |
| Abortive outcome (O00–O08) | 17 |
| Pregnancy or postpartum care (Z33, Z34, Z39) | 9 |

**Interpretation.** Of the 223 SMM admissions that the original flag did not mark as delivery, 103 have puerperium codes and 42 have labor and delivery codes. The flags overlap, so they do not add up to the total. Several are likely deliveries that the original flag missed (Q22).

### Revision v2: Labels revised with the official CDC list

**Interpretation.** From here on the counts come from the new scripts (folder sql/06_revision_labels): the official CDC list in ICD-9-CM and ICD-10-CM/PCS, a delivery flag using diagnoses, procedures and DRG, and death in the same admission. The original scripts were not touched. The results of Q1 to Q18 above describe the labels of the submitted manuscript.

### Q-C1. Cohort and new labels

_Source: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Deliveries (new flag) | SMM admissions in delivery | SMM admissions, any admission | Deaths in the same admission | Of them, in delivery |
|---:|---:|---:|---:|---:|
| 19,425 | 447 | 848 | 10 | 4 |

**Interpretation.** The cohort remains at 25,736 admissions from 15,084 patients. With the official list there are 848 SMM admissions, and 447 are in deliveries (2.3% of 19,425 deliveries). The other 401 (47.3%) are non-delivery admissions, so choosing the delivery hospitalization as the main scope (D5) leaves almost half of the cases as a sensitivity analysis. Death in the same admission totals 10 events, 4 in deliveries, and matches deathtime in all admissions (0 discordant). With 10 events, Model A does not allow a machine-learning model to be estimated.

### Q22. Original delivery flag versus the new one

_Source: `sql/06_revision_labels/02_delivery_flag.sql`_

| Measure | Admissions |
|:---|---:|
| Deliveries with the original flag | 8,857 |
| Deliveries with the new flag | 19,425 |
| Added by the new flag | 10,584 |
| Lost by the new flag | 16 |
| By diagnosis only | 18 |
| Delivery procedure without diagnosis | 17 |
| By DRG only | 33 |
| Excluded by abortion, ectopic or molar code | 27 |
| With stillbirth code | 109 |

**Interpretation.** The original flag marked 8,857 deliveries and the new one marks 19,425, that is, 2.2 times more, because it includes deliveries coded in ICD-9 and delivery procedures and DRGs. It adds 10,584 and loses 16: the lost ones also have an abortion, ectopic or molar pregnancy code. Only 18 deliveries depend on the diagnosis and 33 on the DRG alone, so the three sources corroborate each other. The 109 deliveries with a stillbirth code remain as deliveries. The delivery-restricted analysis in the manuscript used the original denominator.

### Q-C2. SMM in deliveries by coding version

_Source: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Admission coding | Deliveries | With SMM | % with SMM | Deaths in the same admission |
|:---|---:|---:|---:|---:|
| ICD-10 only | 8,883 | 272 | 3.06% | 1 |
| ICD-9 only | 10,542 | 175 | 1.66% | 3 |

**Interpretation.** With the official list, SMM in deliveries is 3.06% in ICD-10-only admissions and 1.66% in ICD-9-only. No admission mixes the two versions. Applying the ICD-9-CM algorithm adds 175 cases that the previous label did not see, but the rate remains lower in ICD-9. These data do not distinguish whether this is under-detection due to coding or a real difference between eras. Restricting to ICD-10 (option b of D4) would leave 272 events in 8,883 deliveries, versus 447 with both versions (1.6 times more). Option (a) keeps more events and the rate does not worsen, so it is retained, with the coding version as a sensitivity variable.

### Q-C3. SMM in deliveries by indicator and version

_Source: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Indicator | ICD-10 | ICD-9 | Total | % of deliveries with SMM |
|:---|---:|---:|---:|---:|
| Acute renal failure | 140 | 55 | 195 | 43.6% |
| DIC | 44 | 46 | 90 | 20.1% |
| Hysterectomy | 44 | 35 | 79 | 17.7% |
| ARDS | 32 | 32 | 64 | 14.3% |
| Ventilation | 27 | 32 | 59 | 13.2% |
| Shock | 35 | 17 | 52 | 11.6% |
| Sepsis | 21 | 22 | 43 | 9.6% |
| Puerperal cerebrovascular disorders | 22 | 11 | 33 | 7.4% |
| Pulmonary edema/acute heart failure | 16 | 15 | 31 | 6.9% |
| Air and thrombotic embolism | 10 | 11 | 21 | 4.7% |
| Eclampsia | 8 | 4 | 12 | 2.7% |
| Severe anesthesia complications | 3 | 7 | 10 | 2.2% |
| Cardiac arrest/ventricular fibrillation | 5 | 3 | 8 | 1.8% |
| Conversion of cardiac rhythm | 5 | 2 | 7 | 1.6% |
| Sickle cell disease with crisis | 2 | 5 | 7 | 1.6% |
| Amniotic fluid embolism | 3 | 3 | 6 | 1.3% |
| Acute myocardial infarction | 1 | 2 | 3 | 0.7% |
| Aneurysm | 2 | 0 | 2 | 0.4% |

**Interpretation.** Acute renal failure is in 195 of the 447 deliveries with SMM (43.6%), followed by DIC (90) and hysterectomy (79). Because no admission mixes versions, each total counts distinct admissions per indicator, and one admission can appear in several. Heart failure during surgery and temporary tracheostomy have no cases. Rare indicators have very few events, so they should be grouped when modeling.

### Q-C4. Official list versus the original label

_Source: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Combination | Admissions |
|:---|---:|
| In the official list and the original | 459 |
| Only in the official list | 389 |
| Only in the original | 16 |

**Interpretation.** Of the 848 SMM admissions under the official list, 459 were already in the original label and 389 are new: cases the submitted label did not see, mostly because of ICD-9 deliveries and codes missing from the original list. Another 16 admissions drop out because they depended on codes or prefixes that the official list does not have. The original label totals 475 admissions, the same as in the manuscript dataset (Q23).

### Q-C5. Alternative SMM definitions in deliveries

_Source: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Definition | Admissions |
|:---|---:|
| Any indicator | 447 |
| Not counting renal failure as the only indicator | 297 |
| Two or more indicators | 130 |

**Interpretation.** If isolated acute renal failure does not count as SMM, events fall from 447 to 297: 150 deliveries (33.6%) have only that indicator. With two or more indicators, 130 remain. The sensitivity analysis of task T50 is necessary, because a third of the outcome depends on a single code.

### Q-C6. Patients with more than one admission

_Source: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Patients with more than one admission | Patients | % with several admissions | Maximum admissions per patient |
|---:|---:|---:|---:|
| 6,793 | 15,084 | 45.0% | 27 |

**Interpretation.** 45.0% of patients have more than one admission, up to 27 in a single patient. The training/test split has to be by patient, not by admission.

### Q-C7. Codes the original list had and the official one does not

_Source: `sql/06_revision_labels/03_labels_same_admission.sql`_

| Code | Version | Admissions | Status in the official list |
|:---|:---|---:|:---|
| T814XXA | ICD-10 | 5 | Unofficial (excluded) |
| 9980 | ICD-9 | 2 | Official, pre-2012 use (included) |
| O2251 | ICD-10 | 2 | Unofficial (excluded) |
| T80211A | ICD-10 | 1 | Unofficial (excluded) |

**Interpretation.** The unofficial codes appear in very few admissions, and code 9980 (998.0, valid in the official list only for its use before 2012) is in 2. Neither I64 nor the extra hysterectomy and tracheostomy variants appear in the query. These codes explain at most 8 of the 16 admissions that only the original label had; the rest probably come from prefixes broader than the official ones and would need to be broken down with a query. T81.4XXA is a post-procedural infection code that the current official list replaces with T81.44XA (sepsis).

### Q23. Manuscript dataset versus the new label

_Source: `sql/06_revision_labels/03b_reconcile_old_labels.sql`_

| Measure | Admissions |
|:---|---:|
| Dataset rows | 25,736 |
| Dataset rows outside the new table | 0 |
| SMM positives in the dataset | 475 |
| Positives in the original view and in the new label | 459 |
| Positives in the original view but not in the new one | 16 |
| Positives not in the original view | 0 |
| Positives with renal failure only (new label) | 129 |
| Positives that are not delivery under the new flag | 218 |

**Interpretation.** The manuscript dataset has the same 25,736 admissions as the new table (0 outside it). Its 475 SMM positives are all from the original view: 459 are also in the new label and 16 only in the original. There is no difference between the dataset and the view to explain. With the new delivery flag, 218 of those positives fall outside delivery, and 129 have only renal failure.

### Q24. Patient overlap in the submitted hold-out

_Source: `notebooks/revision/01_audit_patient_overlap.ipynb`_

| Measure | Model A (mortality) | Model B (SMM) |
|:---|---:|---:|
| Test patients | 4,527 | 4,523 |
| Test patients also in training | 2,686 | 2,635 |
| Test admissions | 5,148 | 5,148 |
| Test admissions with patient in training | 3,086 | 3,065 |
| Test events | 8 | 95 |
| Test events with patient in training | 6 | 48 |
| Test events with a positive from the same patient in training | 6 | 13 |
| Patients with an event in training | 24 | 346 |
| Patients with an event in test | 7 | 91 |
| Patients with an event on both sides | 5 | 11 |

**Interpretation.** With the submitted split (80/20, seed 42, reproduced exactly), 59.3% of the Model A test patients and 58.3% of the Model B test patients also have admissions in training, and 59.9% and 59.5% of test admissions belong to those patients. In mortality, 6 of the 8 test events belong to a patient who already has a positive admission in training. In SMM the label is specific to each admission, and 13 of the 95 events share a patient with a training positive. This result measures how much overlap there was, not how much it inflated performance.

### Q25. Overlap in cross-validation and with other seeds

_Source: `notebooks/revision/01_audit_patient_overlap.ipynb`_

| Measure | Model A (mortality) | Model B (SMM) |
|:---|:---|:---|
| Submitted 5-fold cross-validation: events whose patient is in the other folds | 23 of 41 | 244 of 475 |
| Same figure in 200 repetitions of the cross-validation (median and 2.5th to 97.5th percentile) | 21 (18–23) of 41 | 240 (230–249) of 475 |
| 1,000 hold-out splits: % of test admissions with patient in training | 60.1 (58.9–61.3) | 60.1 (58.8–61.4) |
| 1,000 hold-out splits: test events with patient in training | 4 (2–7) | 48 (39–57) |
| 1,000 hold-out splits: events with a positive from the same patient in training | 4 (2–7) | 14 (8–20) |

**Interpretation.** The overlap does not depend on the seed: across 1,000 hold-out splits the median share of test admissions with a patient in training is 60.1%, with a very narrow range. In the submitted cross-validation, 23 of the 41 mortality events have their patient in the other folds, and a single patient contributes up to 6 positives. Patient-level splitting removes this overlap.

### Q-D1. Lowest position of the obstetric diagnosis

_Source: `sql/06_revision_labels/04_cohort_obstetric_flags.sql`_

| Lowest position | Admissions | Deliveries | With SMM | SMM in delivery | Deaths in the same admission | With ICU |
|:---|---:|---:|---:|---:|---:|---:|
| 1 | 25,254 | 19,413 | 793 | 445 | 7 | 435 |
| 2 | 154 | 3 | 6 | 0 | 0 | 10 |
| 3 | 103 | 3 | 9 | 0 | 0 | 6 |
| 4 | 63 | 0 | 2 | 0 | 0 | 1 |
| 5–6 | 73 | 4 | 14 | 2 | 0 | 7 |
| 7–10 | 55 | 1 | 10 | 0 | 2 | 9 |
| 11 or more | 34 | 1 | 14 | 0 | 1 | 11 |

**Interpretation.** 98.1% of admissions have the obstetric diagnosis in position 1. The 162 admissions with position greater than 4 are almost all non-delivery (156) and are the most severe: 23.5% have SMM versus 3.2% in the rest, 3 died in the admission and 16.7% had an ICU stay. A very ill patient accumulates diagnoses and the obstetric one is pushed down, so the rule of position 4 or less excludes precisely the patients with the outcome.

### Q-D3. Type of the first obstetric code and position rule

_Source: `sql/06_revision_labels/04_cohort_obstetric_flags.sql`_

| Group of the first code | Position 4 or less | Admissions | Deliveries | With SMM | Deaths in the same admission |
|:---|:---|---:|---:|---:|---:|
| Chapter O (ICD-10) | Yes | 11,503 | 8,875 | 460 | 1 |
| Chapter O (ICD-10) | No | 18 | 2 | 8 | 0 |
| Z33, Z34, Z37, Z39 (ICD-10) | Yes | 76 | 4 | 3 | 0 |
| Z33, Z34, Z37, Z39 (ICD-10) | No | 28 | 0 | 5 | 0 |
| 630–679 (ICD-9) | Yes | 13,860 | 10,538 | 346 | 6 |
| 630–679 (ICD-9) | No | 26 | 0 | 11 | 2 |
| V22–V28 (ICD-9) | Yes | 87 | 0 | 0 | 0 |
| V22–V28 (ICD-9) | No | 38 | 2 | 3 | 1 |
| Title text only | Yes | 48 | 2 | 1 | 0 |
| Title text only | No | 52 | 2 | 11 | 0 |

**Interpretation.** Admissions with position greater than 4 ("No" row) are spread across all code groups, and in each one they have much more SMM than those with position 4 or less. It is not a problem of a single code type, but of admission severity.

### Q-D4. Admissions with obstetric evidence only from the title text

_Source: `sql/06_revision_labels/04_cohort_obstetric_flags.sql`_

| Code | Admissions |
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

**Interpretation.** There are 88 admissions that are not deliveries and have no structured obstetric code. Their codes are history codes (V13.29, Z86.32, Z87.59), pregnancy tests (V72.4x, Z32.01) and others that match by title words, such as Q86.0 (fetal alcohol syndrome) and the Y76 codes (obstetric devices). They have 11 SMM cases and no deaths. The F53 codes (puerperal mental disorders) are obstetric and would be left out by that rule: it is a small loss that is declared.

### Q-D5. Effect of each cohort rule on the revised labels

_Source: `sql/06_revision_labels/04_cohort_obstetric_flags.sql`_

| Rule | Admissions | Patients | Deliveries | SMM, any admission | SMM in delivery | Deaths in the same admission | Deaths in delivery |
|:---|---:|---:|---:|---:|---:|---:|---:|
| R0 Any position (current SQL) | 25,736 | 15,084 | 19,425 | 848 | 447 | 10 | 4 |
| R1 Position 4 or less (submitted text) | 25,574 | 15,001 | 19,419 | 810 | 445 | 7 | 4 |
| R2 Structured code, any position | 25,644 | 15,022 | 19,421 | 837 | 447 | 10 | 4 |
| R3 Delivery only (new flag) | 19,425 | 13,729 | 19,425 | 447 | 447 | 4 | 4 |

**Interpretation.** The position-4-or-less rule leaves 810 of the 848 SMM cases and 7 of the 10 deaths, and barely changes deliveries. Requiring a structured code (R2) leaves 25,644 of the 25,736 admissions without losing any death. With the delivery flag (R3), 447 SMM events and 4 deaths remain among 13,729 patients. Decision D6: delivery as the main scope, sensitivity with a structured code in any position.

### Q-E1. Deaths within a horizon from admission (any cause)

_Source: `sql/06_revision_labels/05_death_horizon_counts.sql`_

| Window from admission | Deceased patients | Admissions | Patients, delivery admission | Hospital record only | Aggregates by state death date (dod) |
|:---|---:|---:|---:|---:|---:|
| Same admission (corrected label) | 10 | 10 | 4 | 10 | 0 |
| Up to 42 days from admission | 13 | 16 | 5 | 10 | 3 |
| Up to 90 days from admission | 16 | 20 | 6 | 10 | 6 |
| Up to 365 days from admission | 26 | 47 | 12 | 11 | 15 |

**Interpretation.** The dod column exists in this copy (Q-E0), so deaths outside the hospital are visible: 13 patients at 42 days, 16 at 90 and 26 at 365, versus 10 with the same-admission label. In delivery admissions they are 5, 6 and 12. The state registry explains almost all of the increase. MIMIC-IV does not store the cause of death, so these are all-cause deaths, and they are not enough to train a model. They are reported only as a descriptive sensitivity analysis (decision D7).

### Q-E4. Days from admission to the first later death

_Source: `sql/06_revision_labels/05_death_horizon_counts.sql`_

| Days from admission | Admissions | Patients |
|:---|---:|---:|
| Same day as admission | 3 | 3 |
| 1 to 42 days | 13 | 11 |
| 43 to 90 days | 4 | 4 |
| 91 to 365 days | 27 | 13 |
| More than 365 days | 89 | 49 |

**Interpretation.** Of the obstetric admissions with any death after admission, 89 have the death more than one year later and fall outside any reasonable horizon. Between 1 and 365 days there are 13, 4 and 27 admissions in each bracket. MIMIC-IV dates are shifted per patient, but the intervals within a patient are preserved.

### Q-F1. Eligibility for a 24-h model and events lost

_Source: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Scope | Admissions | Eligible at 24 h | Live discharge before 24 h | SMM | Eligible SMM | Deaths | Eligible deaths | Deaths before 24 h |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
| Any obstetric admission | 25,736 | 23,625 | 2,106 | 848 | 814 | 10 | 5 | 5 |
| Delivery hospitalization (main) | 19,425 | 19,383 | 41 | 447 | 445 | 4 | 3 | 1 |
| Structured obstetric code (sensitivity) | 25,644 | 23,560 | 2,079 | 837 | 803 | 10 | 5 | 5 |

**Interpretation.** In delivery hospitalizations almost nothing is lost: 19,383 of 19,425 admissions remain, 445 of 447 SMM cases and 3 of 4 deaths. With any obstetric admission, 2,106 short live-discharge stays are lost (almost all non-delivery), 848 minus 814 SMM cases and half of the deaths (5 of 10). The 24-h model is feasible for SMM; for mortality it is left with 3 to 5 events.

### Q-F2. Hours from admission to death

_Source: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Hours from admission | Deaths in the same admission | Of them, in delivery | With ICU in the first 24 h |
|:---|---:|---:|---:|
| 0 to 6 h | 1 | 0 | 1 |
| 6 to 12 h | 0 | 0 | 0 |
| 12 to 24 h | 4 | 1 | 2 |
| 24 to 48 h | 1 | 1 | 1 |
| More than 48 h | 4 | 2 | 2 |

**Interpretation.** Five of the ten deaths occur before 24 h and five after. In deliveries, one occurs before 24 h and three after.

### Q-F3. Timing of the first ICU admission and outcomes

_Source: `sql/07_revision_predictors/01_predictors_24h.sql`_

| First ICU admission | Admissions | Deliveries | SMM | SMM in delivery | Deaths |
|:---|---:|---:|---:|---:|---:|
| No ICU stay | 25,257 | 19,220 | 505 | 279 | 3 |
| ICU at admission or earlier | 1 | 0 | 1 | 0 | 0 |
| First ICU admission within 24 h | 366 | 115 | 250 | 90 | 6 |
| First ICU admission between 24 and 72 h | 53 | 40 | 44 | 36 | 0 |
| First ICU admission after 72 h | 59 | 50 | 48 | 42 | 1 |

**Interpretation.** Of the 447 SMM cases in deliveries, 279 never enter the ICU, 90 enter in the first 24 h and 36 plus 42 enter later. ICU admission in the first 24 h is not a clean predictor: 90 of the 115 deliveries that enter have SMM, and several SMM indicators (ventilation, shock) are probably managed in the ICU.

### Q-F4. Availability of each variable in the predictor window (eligible deliveries, D10 window)

_Source: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Variable | Role | Admissions with a value | Total | With ICU in 24 h | Without ICU in 24 h | With SMM |
|:---|:---|---:|---:|---:|---:|---:|
| hematocrit | Main model | 15,846 | 81.8% | 96.5% | 81.7% | 84.9% |
| hemoglobin | Main model | 15,822 | 81.6% | 96.5% | 81.5% | 84.9% |
| creatinine | Main model | 3,971 | 20.5% | 96.5% | 20.0% | 62.9% |
| glucose | Main model | 760 | 3.9% | 95.7% | 3.4% | 39.3% |
| chloride | Main model | 673 | 3.5% | 95.7% | 2.9% | 38.2% |
| potassium | Main model | 683 | 3.5% | 95.7% | 3.0% | 38.4% |
| sodium | Main model | 678 | 3.5% | 95.7% | 2.9% | 38.4% |
| anion_gap | Main model | 660 | 3.4% | 95.7% | 2.9% | 38.0% |
| bicarbonate | Main model | 660 | 3.4% | 95.7% | 2.9% | 38.0% |
| magnesium | Main model | 620 | 3.2% | 93.9% | 2.7% | 39.1% |
| calcium_noionized | Main model | 527 | 2.7% | 94.8% | 2.2% | 35.7% |
| phosphorus | Main model | 513 | 2.6% | 94.8% | 2.1% | 35.3% |
| lactate | Main model | 162 | 0.8% | 73.0% | 0.4% | 21.6% |
| gcs_eye_opening | ICU sensitivity only | 113 | 0.6% | 98.3% | 0.0% | 19.8% |
| gcs_motor_response | ICU sensitivity only | 113 | 0.6% | 98.3% | 0.0% | 19.8% |
| gcs_verbal_response | ICU sensitivity only | 113 | 0.6% | 98.3% | 0.0% | 19.8% |
| heart_rate | ICU sensitivity only | 114 | 0.6% | 99.1% | 0.0% | 20.0% |
| o2_saturation | ICU sensitivity only | 114 | 0.6% | 99.1% | 0.0% | 20.0% |
| respiratory_rate | ICU sensitivity only | 114 | 0.6% | 99.1% | 0.0% | 20.0% |
| temperature_fahrenheit | ICU sensitivity only | 113 | 0.6% | 98.3% | 0.0% | 19.8% |
| weight_admission | ICU sensitivity only | 115 | 0.6% | 100.0% | 0.0% | 20.2% |
| pressure_blood_diastolic | ICU sensitivity only | 92 | 0.5% | 80.0% | 0.0% | 15.5% |
| pressure_blood_mean | ICU sensitivity only | 92 | 0.5% | 80.0% | 0.0% | 15.5% |
| pressure_blood_systolic | ICU sensitivity only | 92 | 0.5% | 80.0% | 0.0% | 15.5% |
| richmond_ras_scale | ICU sensitivity only | 95 | 0.5% | 82.6% | 0.0% | 17.3% |
| peep_set | ICU sensitivity only | 59 | 0.3% | 51.3% | 0.0% | 11.9% |
| height | ICU sensitivity only | 44 | 0.2% | 38.3% | 0.0% | 9.2% |

**Interpretation.** With the window from 24 h before admission to 24 h after, hemoglobin is present in 81.6% of eligible deliveries and hematocrit in 81.8%; creatinine, in 20.5%. The other labs remain below 4%. The 14 ICU variables do not exist outside the ICU. Missingness remains tied to the outcome for creatinine (62.9% in SMM cases) and for infrequent labs, but hemoglobin now barely discriminates (84.9% in SMM versus 81.6% overall).

### Q-F5. Delivery labs: effect of the window from 24 h before admission to 24 h after

_Source: `sql/07_revision_predictors/01_predictors_24h.sql`_

| Lab | First value in the window | Of them, before admission | Only after 24 h | No value | % in the new window | % with the previous window (from admission) |
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

**Interpretation.** Accepting values from the 24 h before admission raises hemoglobin coverage from 53.0% to 81.6%, hematocrit from 56.5% to 81.7% and creatinine from 13.1% to 20.4% (all deliveries). 43.7% of the first hemoglobin values and 53.8% of the first creatinine values were taken before the admission time (triage or emergency department), so the timing of the datum relative to the prediction point varies between 48 and 0 hours.

## Decisions made on 2026-10-23

- **D1, scope of Model A.** Decided: exploratory feasibility analysis, using the label of death in the same admission. With 10 events, the sample-size calculation will show that it is not enough for a model, and SMM is the main outcome.
- **D2, title.** Decided: reframe with SMM as the main outcome; the final title is set at the end.
- **D3, prediction point.** Decided: 24-h window for the predictors of both models, with SMM defined per admission (codes carry no timestamp) and the limitation declared.
- **D4, ICD-9.** Decided: official CDC algorithm for ICD-9-CM, with the ICD-10-only version as a sensitivity analysis. Q-C2 does not show a worsening: option (a) keeps 1.6 times the events of option (b).
- **D5, SMM scope.** Decided: delivery hospitalization as the main scope, with 447 events in 19,425 deliveries, and any obstetric admission as a sensitivity analysis (401 cases outside delivery).
- **D6, cohort rule.** Decided: no position rule, because position 4 or less would exclude 38 SMM cases and 3 deaths from severe admissions. The sensitivity analysis with any obstetric admission requires at least one structured obstetric code in any position.
- **D7, death definition for Model A.** Decided: the main label is death in the same admission. The 42- and 365-day horizons (13 and 26 patients) are reported only as a descriptive sensitivity analysis, named all-cause mortality.
- **D8, admissions with death or discharge before 24 h.** Decided: they are left out of the 24-h model and their events are reported separately. Five of the 10 deaths occur within the first 24 h.
- **D9, prediction point.** Decided: admission + 24 h; the 28 diagnosis-group indicators (which come from discharge diagnoses) are removed from the main model; ICU admission is measured within the first 24 h instead of the number of stays.
- **D10, window and ICU variables.** Decided: the predictor window runs from 24 h before admission to 24 h after, because triage values are already available at the prediction point (hemoglobin coverage rises from 53.0% to 81.6%). The 14 variables that exist only in the ICU and ICU admission are left out of the main model and moved to a separate sensitivity analysis.

## Sources

| Origin | Content |
|:---|:---|
| `sql/05_revision_audit/` | Audit Q1 to Q21 on the submitted labels |
| `sql/06_revision_labels/` | Official code lists, delivery flag, same-admission labels, cohort rule and death horizons (Q22, Q23, Q-C1 to Q-C7, Q-D1 to Q-D5, Q-E1 to Q-E4) |
| `sql/07_revision_predictors/` | Predictors with a 24-h window and their availability (Q-F1 to Q-F5) |
| `notebooks/revision/01_audit_patient_overlap.ipynb` | Patient overlap between training and test (Q24, Q25) |

Queries Q-D0, Q-D2, Q-E0, Q-E2, Q-E3 and Q-F0 are used in the text of the sections and in the revision plan, but have no table of their own here.
