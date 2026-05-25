# MIMIC-IV Readmission Analysis: Heart Failure vs. Pneumonia

## Project Overview

This project analyzes **30-day hospital readmission rates** in patients admitted for **heart failure (HF)** and **pneumonia** using the MIMIC-IV clinical database. The goal is to identify clinical predictors of readmission, compare outcomes across the two conditions, and surface patterns that could inform discharge planning and post-acute care interventions.

---

## Research Questions

1. What is the 30-day readmission rate for heart failure vs. pneumonia patients in MIMIC-IV?
2. Which clinical features (labs, vitals, comorbidities, demographics) are most predictive of readmission?
3. Do the risk factors for readmission differ between HF and pneumonia cohorts?
4. Are there differences in length of stay, ICU utilization, or in-hospital mortality between the two groups?

---

## Cohort Definitions

### Heart Failure Cohort
- **ICD-10 codes:** `I50.x` (I50.0, I50.1, I50.2, I50.3, I50.4, I50.9, and sub-codes)
- **ICD-9 codes:** `428.x` (428, 428.0, 428.1, 428.2, 428.3, 428.4, 428.9)
- Principal or secondary diagnosis on any admission

### Pneumonia Cohort
- **ICD-10 codes:** `J12.x`, `J13`, `J14`, `J15.x`, `J16.x`, `J17`, `J18.x`
- **ICD-9 codes:** `480.x`–`486.x`
- Principal or secondary diagnosis on any admission

### Inclusion Criteria (Both Cohorts)
- Age ≥ 18 years at time of admission
- Admitted to hospital (not just ED visit)
- At least one prior admission in MIMIC-IV (to establish readmission baseline)

### Exclusion Criteria
- Died during index admission (no opportunity for readmission)
- Transferred to another acute care facility at discharge
- Administrative/elective admissions flagged as same-day

### 30-Day Readmission Definition
- Any unplanned inpatient readmission within 30 days of the **discharge date** of the index admission
- Index admission = first qualifying admission per patient per cohort

---

## Methodology

```
1. Cohort Extraction
   ├── Identify HF and pneumonia admissions via ICD-9/10 codes
   ├── Apply inclusion/exclusion criteria
   └── Flag index admissions and 30-day readmissions

2. Feature Engineering
   ├── Demographics: age, gender, race, insurance type
   ├── Comorbidities: Charlson Comorbidity Index from ICD codes
   ├── Lab values: BMP, CBC, BNP (HF), procalcitonin (pneumonia) — first 24h
   ├── Vitals: HR, BP, SpO2, temperature, RR — first 24h
   ├── Admission details: LOS, ICU admission, ED source, time of year
   └── Medications: diuretics (HF), antibiotics (pneumonia)

3. Analysis
   ├── Descriptive statistics by cohort and readmission status
   ├── Unadjusted readmission rates with 95% CIs
   ├── Logistic regression for 30-day readmission predictors
   └── Comparison of risk factors: HF vs. pneumonia
```

---

## Project Structure

```
MIMIC-bq-project/
├── README.md                        # This file
├── agents/
│   ├── pipeline.py                  # Multi-agent SQL pipeline (Analyst → Senior → PI)
│   └── output/                      # Approved SQL queries saved here
├── sql/
│   ├── cohorts/
│   │   ├── heart_failure_cohort.sql # HF cohort extraction
│   │   └── pneumonia_cohort.sql     # Pneumonia cohort extraction
│   ├── features/                    # Feature engineering queries
│   └── analysis/                    # Final analysis queries
├── notebooks/                       # Jupyter notebooks for analysis and visualization
├── outputs/
│   ├── figures/                     # Plots and charts
│   └── tables/                      # Summary statistics, model outputs
└── data/
    └── README.md                    # Data access instructions
```

---

## Data Access: MIMIC-IV via BigQuery

### Prerequisites

1. **PhysioNet account** — Register at [physionet.org](https://physionet.org)
2. **MIMIC-IV credentialing** — Complete CITI training and sign the DUA at [physionet.org/content/mimiciv](https://physionet.org/content/mimiciv/)
3. **Google Cloud account** — Required for BigQuery access
4. **PhysioNet–BigQuery access** — Request via your PhysioNet profile after credentialing

### BigQuery Connection Details

| Setting | Value |
|---|---|
| GCP Project ID | `third-pad-435601-a2` |
| MIMIC-IV Dataset | `physionet-data.mimiciv_hosp` |
| MIMIC-IV Version | 3.1 |

### Key Tables

| Table | Description |
|---|---|
| `admissions` | Hospital admissions (hadm_id, admittime, dischtime, deathtime, discharge_location) |
| `patients` | Patient demographics (subject_id, gender, anchor_age, dod) |
| `diagnoses_icd` | ICD-9 and ICD-10 diagnosis codes per admission |
| `d_icd_diagnoses` | ICD code reference (icd_code, icd_version, long_title) |
| `labevents` | Lab results (itemid, charttime, value, valuenum, flag) |
| `d_labitems` | Lab item reference (itemid, label, category, fluid) |
| `pharmacy` | Medication orders (medication, route, starttime, stoptime) |
| `omr` | Outpatient measurements (result_name, result_value) |

### Python Connection

```python
from google.cloud import bigquery

client = bigquery.Client(project="third-pad-435601-a2")

query = """
    SELECT COUNT(*) as total_admissions
    FROM `physionet-data.mimiciv_hosp.admissions`
"""
result = client.query(query).to_dataframe()
```

### Authentication

```bash
# Authenticate with your Google account
gcloud auth application-default login

# Or set a service account key
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

---

## Multi-Agent Analysis Pipeline

[agents/pipeline.py](agents/pipeline.py) provides an AI-powered SQL generation and review workflow:

| Agent | Role |
|---|---|
| **Data Analyst** | Writes BigQuery SQL based on the research question |
| **Senior Analyst** | Reviews SQL for correctness, clinical validity, and MIMIC-IV conventions |
| **PI** | Makes the final GO/NO-GO decision aligned with research goals |

### Usage

```bash
# Interactive mode
python agents/pipeline.py

# Direct question
python agents/pipeline.py "What is the 30-day readmission rate for heart failure patients?"
```

Approved queries are saved to `agents/output/latest_approved_query.sql`.

---

## Dependencies

```bash
pip install anthropic google-cloud-bigquery pandas db-dtypes jupyter
```

---

## Ethics & Data Use

- MIMIC-IV is de-identified and approved for research use under a PhysioNet DUA
- All analyses must comply with the data use agreement
- Do not attempt to re-identify patients
- Never commit raw MIMIC data to version control (CSV files are gitignored)
