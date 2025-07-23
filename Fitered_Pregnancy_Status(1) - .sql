---Preganancy _cases (1).sql
---Extract identified pregnant women from MIMIC usisng ICD-10 codes
---Author: Tolu | date: 07-21-2025

---Having a glimse of the data 
SELECT *
FROM d_icd_diagnoses
LIMIT 10;

SELECT *
FROM patients
LIMIT 10;

SELECT *
FROM admissions
LIMIT 10;



---Since ICD-10 codes for pregnancy start with Z34-37, Z39, Z3A
---and HCG lab test is either postive, negative or uncertain
---I create CTEs to account for the ICD code and lab result
---and ensure blank or null lab values for each patients are validated by the ICD code on the diagnoses table
---as some of the lab test are omitted
---patients are limited to 18-52 years (child bearing age)
---and to avoid double counting, only the first pregnancy status is recorded 

WITH picd AS ( 
  SELECT icd_code, icd_version, long_title 
  FROM physionet-data.mimiciv_hosp.d_icd_diagnoses
  WHERE icd_code LIKE 'Z34%' 
        OR icd_code LIKE 'Z35%' 
        OR icd_code LIKE 'Z36%'
        OR icd_code LIKE 'Z37%' 
        OR icd_code LIKE 'Z39%' 
        OR icd_code LIKE 'Z3A%'
),

hcg_lab_results AS (
  SELECT subject_id, hadm_id, charttime AS sampling_time, value, flag, comments, 
         CASE 
           WHEN comments LIKE 'POS%' THEN 'POS' 
           WHEN comments LIKE 'NEG%' THEN 'NEG' 
           ELSE 'UNCERTAIN' 
         END AS result
  FROM `physionet-data.mimiciv_hosp.labevents` labevents 
  JOIN `physionet-data.mimiciv_hosp.d_labitems` labitems 
    ON labevents.itemid = labitems.itemid 
  WHERE labitems.label LIKE '%HCG%'
),

picd2 AS (
  SELECT subject_id, hadm_id, sampling_time, 
         CASE 
           WHEN value IS NULL THEN result 
           WHEN value = '___' THEN 'UNCERTAIN' 
           ELSE value 
         END AS hcg_result 
  FROM hcg_lab_results
),

pregnancy_status AS (
  SELECT di.subject_id,  
         p.gender,  
         p.anchor_age,  
         picd.icd_code,
         adm.admittime, 
         adm.dischtime, 
         picd2.sampling_time, 
         COALESCE(picd2.sampling_time, adm.admittime) AS event_time,
         picd2.hcg_result,
         CASE 
           WHEN picd.icd_code IS NULL AND picd2.hcg_result = 'POS' THEN 'PREGNANT'
           WHEN picd.icd_code IS NULL AND picd2.hcg_result = 'NEG' THEN 'NOT PREGNANT'
           WHEN picd.icd_code IS NOT NULL THEN 'PREGNANT'
           ELSE 'NOT PREGNANT'
         END AS Status  
  FROM physionet-data.mimiciv_hosp.diagnoses_icd di
  LEFT JOIN physionet-data.mimiciv_hosp.patients p 
    ON p.subject_id = di.subject_id
  LEFT JOIN picd 
    ON picd.icd_code = di.icd_code
  LEFT JOIN picd2 
    ON picd2.subject_id = di.subject_id AND picd2.hadm_id = di.hadm_id
  LEFT JOIN `physionet-data.mimiciv_hosp.admissions` adm 
    ON adm.subject_id = di.subject_id
  WHERE p.gender = 'F' 
    AND p.anchor_age BETWEEN 18 AND 52
),

ranked_status AS (
  SELECT subject_id,
         gender,
         anchor_age,
         pregnancy_status,
         event_time,
         ROW_NUMBER() OVER (
           PARTITION BY subject_id 
           ORDER BY 
             CASE 
               WHEN Status = 'PREGNANT' THEN 1 
               ELSE 2 
             END,
             event_time
         ) AS rank
  FROM pregnancy_status
)

SELECT subject_id, 
       gender, 
       anchor_age, 
       pregnancy_status.Status, 
       event_time
FROM ranked_status
WHERE rank = 1;
