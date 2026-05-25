-- Heart Failure Cohort Extraction
-- MIMIC-IV | physionet-data.mimiciv_hosp
-- Goal: Identify index admissions for heart failure (ICD-9: 428.x | ICD-10: I50.x)
--       and flag 30-day readmissions

WITH hf_admissions AS (
    SELECT DISTINCT
        d.subject_id,
        d.hadm_id
    FROM `physionet-data.mimiciv_hosp.diagnoses_icd` d
    WHERE
        (d.icd_version = 10 AND d.icd_code LIKE 'I50%')
        OR (d.icd_version = 9  AND d.icd_code LIKE '428%')
),

-- Join demographics and admission details
cohort AS (
    SELECT
        p.subject_id,
        p.gender,
        p.anchor_age,
        a.hadm_id,
        a.admittime,
        a.dischtime,
        a.deathtime,
        a.discharge_location,
        a.admission_type,
        a.race,
        a.insurance,
        -- Died during index admission
        CASE WHEN a.deathtime IS NOT NULL AND a.deathtime <= a.dischtime THEN 1 ELSE 0 END AS died_in_hospital
    FROM hf_admissions hf
    JOIN `physionet-data.mimiciv_hosp.admissions` a USING (hadm_id)
    JOIN `physionet-data.mimiciv_hosp.patients` p USING (subject_id)
    WHERE p.anchor_age >= 18
),

-- Select index admission (earliest qualifying admission per patient)
index_admissions AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY admittime) AS admission_rank
    FROM cohort
    WHERE died_in_hospital = 0  -- must survive index admission
),

-- Find 30-day readmissions (any subsequent inpatient admission)
readmissions AS (
    SELECT
        idx.subject_id,
        idx.hadm_id AS index_hadm_id,
        MIN(a.admittime) AS readmit_time
    FROM index_admissions idx
    JOIN `physionet-data.mimiciv_hosp.admissions` a
        ON idx.subject_id = a.subject_id
        AND a.hadm_id <> idx.hadm_id
        AND a.admittime > idx.dischtime
        AND DATE_DIFF(DATE(a.admittime), DATE(idx.dischtime), DAY) <= 30
    WHERE idx.admission_rank = 1
    GROUP BY idx.subject_id, idx.hadm_id
)

SELECT
    idx.subject_id,
    idx.gender,
    idx.anchor_age,
    idx.hadm_id AS index_hadm_id,
    idx.admittime AS index_admittime,
    idx.dischtime AS index_dischtime,
    idx.discharge_location,
    idx.admission_type,
    idx.race,
    idx.insurance,
    CASE WHEN r.subject_id IS NOT NULL THEN 1 ELSE 0 END AS readmitted_30d,
    r.readmit_time,
    'Heart Failure' AS cohort
FROM index_admissions idx
LEFT JOIN readmissions r
    ON idx.subject_id = r.subject_id
    AND idx.hadm_id = r.index_hadm_id
WHERE idx.admission_rank = 1
ORDER BY idx.subject_id
