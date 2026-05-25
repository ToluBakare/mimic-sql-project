---Overview of the admissions table
-- 1. Row count
SELECT COUNT(*) AS total_rows
FROM `physionet-data.mimiciv_3_1_hosp.admissions`;

-- 2. First 2 rows
SELECT *
FROM `physionet-data.mimiciv_3_1_hosp.admissions`
LIMIT 2;

-- 3. NULL counts per column
SELECT
  COUNTIF(hadm_id IS NULL) AS hadm_id_nulls,
  COUNTIF(subject_id IS NULL) AS subject_id_nulls,
  COUNTIF(admittime IS NULL) AS admittime_nulls,
  COUNTIF(dischtime IS NULL) AS dischtime_nulls,
  COUNTIF(admission_type IS NULL) AS admission_type_nulls,
  COUNTIF(insurance IS NULL) AS insurance_nulls,
  COUNTIF(marital_status IS NULL) AS marital_status_nulls,
  COUNTIF(race IS NULL) AS race_nulls,
  COUNTIF(hospital_expire_flag IS NULL) AS hospital_expire_flag_nulls,
  COUNTIF(discharge_location IS NULL) AS discharge_location_nulls
FROM `physionet-data.mimiciv_3_1_hosp.admissions`;

-- 4. Unique admission types
SELECT DISTINCT admission_type
FROM `physionet-data.mimiciv_3_1_hosp.admissions`
ORDER BY admission_type;

-- 5. Unique discharge locations
SELECT DISTINCT discharge_location
FROM `physionet-data.mimiciv_3_1_hosp.admissions`
ORDER BY discharge_location;

-- 6. Date range
SELECT 
  MIN(admittime) AS earliest_admission,
  MAX(admittime) AS latest_admission
FROM `physionet-data.mimiciv_3_1_hosp.admissions`;



---Overview of d_icd_diagnoses table---
-- 1. Row count
SELECT  COUNT(*) 
FROM `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses`;

---2. First 2 rows
SELECT  * 
FROM `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses`
LIMIT 2;

---3. Null count per column
SELECT 
COUNTIF (icd_code IS NULL) AS icd_code_nulls,
COUNTIF(icd_version IS NULL) AS icd_version_null
FROM `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses`;


---Overview of patient table---
-- 1. Row count
SELECT  COUNT (*)
FROM `physionet-data.mimiciv_3_1_hosp.patients`
;

---2. First 2 rows
SELECT  * 
FROM `physionet-data.mimiciv_3_1_hosp.patients`
LIMIT 2;

---3. Null count per column
SELECT
COUNTIF(subject_id IS NULL) AS subject_null,
COUNTIF(gender IS NULL) AS gender_null,
COUNTIF(anchor_age IS NULL) AS anchorage_null,
COUNTIF(anchor_year IS NULL) AS anchoryear_null,
COUNTIF(dod is NULL) AS deathofdeath_null
FROM `physionet-data.mimiciv_3_1_hosp.patients`;

---Overview of labevents---
-- 1. Row count
SELECT  COUNT(*) 
FROM `physionet-data.mimiciv_3_1_hosp.labevents`;

---diagnoses_icd table---
-- 1. Row count
SELECT COUNT(*) AS total_rows
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`;

-- 2. First 2 rows
SELECT *
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
LIMIT 2;

-- 3. NULL counts
SELECT
  COUNTIF(subject_id IS NULL) AS subject_id_nulls,
  COUNTIF(hadm_id IS NULL) AS hadm_id_nulls,
  COUNTIF(icd_code IS NULL) AS icd_code_nulls,
  COUNTIF(icd_version IS NULL) AS icd_version_nulls,
  COUNTIF(seq_num IS NULL) AS seq_num_nulls
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`;

-- 4. ICD-9 vs ICD-10 distribution
SELECT icd_version, COUNT(*) AS total_codes
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
GROUP BY icd_version
ORDER BY icd_version;

-- 5. seq_num distribution
SELECT seq_num, COUNT(*) AS total
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
GROUP BY seq_num
ORDER BY seq_num;

--6. Distrubution of Heart Failure and Pnuemonia
SELECT COUNT (*) AS total, 
CASE 
  WHEN icd_code LIKE 'I50%' THEN 'Heart Failure ICD-10'
  WHEN icd_code LIKE '428%' THEN 'Heart Failure ICD-9'
  WHEN icd_code LIKE 'J18%' THEN 'Pnuemonia ICD-10'
  WHEN icd_code LIKE '486%' THEN 'Pnuemonia ICD-9'
END AS condition
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
WHERE  icd_code LIKE '428%'
      OR  icd_code LIKE '486%' 
      OR  icd_code LIKE 'I50%'
      OR  icd_code LIKE 'J18%'
GROUP BY condition;
