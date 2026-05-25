---Cohort Extraction
WITH heartfailure_Pnuemonia
AS ( SELECT subject_id,hadm_id, seq_num, icd_code,
CASE 
  WHEN icd_code LIKE 'I50%' THEN 'Heart Failure ICD-10'
  WHEN icd_code LIKE '428%' THEN 'Heart Failure ICD-9'
  WHEN icd_code LIKE 'J18%' THEN 'Pnuemonia ICD-10'
  WHEN icd_code LIKE '486%' THEN 'Pnuemonia ICD-9'
END AS condition
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
WHERE  (icd_code LIKE '428%'
      OR  icd_code LIKE '486%' 
      OR  icd_code LIKE 'I50%'
      OR  icd_code LIKE 'J18%')
      AND seq_num = 1

), 
 
admittable 
AS 
( SELECT subject_id, hadm_id, DATE(admittime) AS admit_time, DATE(dischtime) AS disch_time,
          admission_type, hospital_expire_flag, insurance, race, marital_status,
          ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY admittime) AS ad
  FROM `physionet-data.mimiciv_3_1_hosp.admissions`
  WHERE hospital_expire_flag = 0 AND 
  admission_type NOT IN ('AMBULATORY OBSERVATION', 'EU OBSERVATION', 'OBSERVATION ADMIT')
  
  ),

readmissions AS(
  SELECT a1.hadm_id, a1.subject_id, 
  CASE WHEN MIN(DATE_DIFF(DATE(a2.admittime), DATE(a1.dischtime), DAY)) <=30 THEN 1 ELSE 0
  END AS readmitted_30days
  FROM `physionet-data.mimiciv_3_1_hosp.admissions` a1 
  LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` a2 ON
  a1.subject_id = a2.subject_id
  AND a2.admittime > a1.dischtime
  GROUP BY a1.hadm_id, a1.subject_id
)


SELECT p.subject_id, att.admission_type,  att.hadm_id, hp.condition, readmitted_30days, att.admit_time,
        att.disch_time,att.hospital_expire_flag, p.gender, 
        p.anchor_age + (EXTRACT (YEAR FROM admit_time) - p.anchor_year) AS age_at_admission, 
        att.race, att.marital_status, att.insurance

        FROM heartfailure_Pnuemonia hp JOIN admittable att ON hp.hadm_id = att.hadm_id  AND
        hp.subject_id = att.subject_id
        LEFT JOIN readmissions rd ON rd.hadm_id = att.hadm_id
        JOIN `physionet-data.mimiciv_3_1_hosp.patients` p ON p.subject_id = att.subject_id
        WHERE ad =1 


















