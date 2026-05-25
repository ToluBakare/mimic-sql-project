-- =============================================================================
-- Task: Table overview for readmission analysis project
-- Dataset: physionet-data.mimiciv_3_1_hosp
-- Covers: admissions, d_icd_diagnoses, labevents, diagnoses_icd, patients
-- PI-approved decision: use physionet-data.mimiciv_3_1_hosp as the base dataset
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ROW COUNTS — one query per table for clarity
-- ─────────────────────────────────────────────────────────────────────────────

-- Total rows in admissions
SELECT 'admissions'      AS table_name, COUNT(*) AS row_count FROM `physionet-data.mimiciv_3_1_hosp.admissions`;
SELECT 'd_icd_diagnoses' AS table_name, COUNT(*) AS row_count FROM `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses`;
SELECT 'labevents'       AS table_name, COUNT(*) AS row_count FROM `physionet-data.mimiciv_3_1_hosp.labevents`;
SELECT 'diagnoses_icd'   AS table_name, COUNT(*) AS row_count FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`;
SELECT 'patients'        AS table_name, COUNT(*) AS row_count FROM `physionet-data.mimiciv_3_1_hosp.patients`;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. FIRST 2 ROWS of each table (for schema/value orientation)
-- ─────────────────────────────────────────────────────────────────────────────

SELECT * FROM `physionet-data.mimiciv_3_1_hosp.admissions`      LIMIT 2;
SELECT * FROM `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses` LIMIT 2;
SELECT * FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`   LIMIT 2;
SELECT * FROM `physionet-data.mimiciv_3_1_hosp.patients`        LIMIT 2;
-- labevents: row count only per PI guidance (table is too large for NULL scan)
SELECT * FROM `physionet-data.mimiciv_3_1_hosp.labevents`       LIMIT 2;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. NULL COUNTS PER COLUMN
-- Skipping labevents — table is too large; PI-approved: row count only
-- ─────────────────────────────────────────────────────────────────────────────

-- admissions: NULLs per column
SELECT
  COUNTIF(subject_id        IS NULL) AS subject_id_nulls,
  COUNTIF(hadm_id           IS NULL) AS hadm_id_nulls,
  COUNTIF(admittime         IS NULL) AS admittime_nulls,
  COUNTIF(dischtime         IS NULL) AS dischtime_nulls,
  COUNTIF(deathtime         IS NULL) AS deathtime_nulls,
  COUNTIF(admission_type    IS NULL) AS admission_type_nulls,
  COUNTIF(admit_provider_id IS NULL) AS admit_provider_id_nulls,
  COUNTIF(admission_location IS NULL) AS admission_location_nulls,
  COUNTIF(discharge_location IS NULL) AS discharge_location_nulls,
  COUNTIF(insurance         IS NULL) AS insurance_nulls,
  COUNTIF(language          IS NULL) AS language_nulls,
  COUNTIF(marital_status    IS NULL) AS marital_status_nulls,
  COUNTIF(race              IS NULL) AS race_nulls,
  COUNTIF(edregtime         IS NULL) AS edregtime_nulls,
  COUNTIF(edouttime         IS NULL) AS edouttime_nulls,
  COUNTIF(hospital_expire_flag IS NULL) AS hospital_expire_flag_nulls
FROM `physionet-data.mimiciv_3_1_hosp.admissions`;

-- d_icd_diagnoses: NULLs per column
SELECT
  COUNTIF(icd_code    IS NULL) AS icd_code_nulls,
  COUNTIF(icd_version IS NULL) AS icd_version_nulls,
  COUNTIF(long_title  IS NULL) AS long_title_nulls
FROM `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses`;

-- diagnoses_icd: NULLs per column
SELECT
  COUNTIF(subject_id  IS NULL) AS subject_id_nulls,
  COUNTIF(hadm_id     IS NULL) AS hadm_id_nulls,
  COUNTIF(seq_num     IS NULL) AS seq_num_nulls,
  COUNTIF(icd_code    IS NULL) AS icd_code_nulls,
  COUNTIF(icd_version IS NULL) AS icd_version_nulls
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`;

-- patients: NULLs per column
SELECT
  COUNTIF(subject_id   IS NULL) AS subject_id_nulls,
  COUNTIF(gender       IS NULL) AS gender_nulls,
  COUNTIF(anchor_age   IS NULL) AS anchor_age_nulls,
  COUNTIF(anchor_year  IS NULL) AS anchor_year_nulls,
  COUNTIF(anchor_year_group IS NULL) AS anchor_year_group_nulls,
  COUNTIF(dod          IS NULL) AS dod_nulls
FROM `physionet-data.mimiciv_3_1_hosp.patients`;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. UNIQUE ICD-9 AND ICD-10 CODES
-- Checked in both d_icd_diagnoses (reference) and diagnoses_icd (claims)
-- ─────────────────────────────────────────────────────────────────────────────

-- d_icd_diagnoses: distinct codes by version
SELECT
  icd_version,
  COUNT(DISTINCT icd_code) AS unique_codes
FROM `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses`
GROUP BY icd_version
ORDER BY icd_version;

-- diagnoses_icd: distinct codes by version (actual usage in admissions)
SELECT
  icd_version,
  COUNT(DISTINCT icd_code) AS unique_codes
FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
GROUP BY icd_version
ORDER BY icd_version;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. DATE RANGE OF admittime IN admissions
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  MIN(admittime) AS earliest_admission,
  MAX(admittime) AS latest_admission,
  DATE_DIFF(DATE(MAX(admittime)), DATE(MIN(admittime)), YEAR) AS span_years
FROM `physionet-data.mimiciv_3_1_hosp.admissions`;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. UNIQUE VALUES IN admission_type AND discharge_location
-- ─────────────────────────────────────────────────────────────────────────────

-- Admission types with counts
SELECT
  admission_type,
  COUNT(*) AS admission_count
FROM `physionet-data.mimiciv_3_1_hosp.admissions`
GROUP BY admission_type
ORDER BY admission_count DESC;

-- Discharge locations with counts
SELECT
  discharge_location,
  COUNT(*) AS discharge_count
FROM `physionet-data.mimiciv_3_1_hosp.admissions`
GROUP BY discharge_location
ORDER BY discharge_count DESC;
