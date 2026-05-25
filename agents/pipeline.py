#!/usr/bin/env python3
"""
Multi-agent pipeline for MIMIC-IV readmission analysis.
Flow: Data Analyst (writes SQL) → Senior Analyst (reviews) → PI (final decision)

Research focus: 30-day readmission in heart failure vs. pneumonia cohorts
"""

import json
import os
import sys

import anthropic

client = anthropic.Anthropic()
MODEL = "claude-sonnet-4-6"

_PROJECT_CONTEXT = """
Project: MIMIC-IV 30-day readmission analysis — Heart Failure vs. Pneumonia
GCP Project: third-pad-435601-a2
Dataset: physionet-data.mimiciv_hosp (MIMIC-IV v3.1)

Research goal: Compare 30-day readmission rates and predictors between heart failure (HF)
and pneumonia patients to inform discharge planning and post-acute care.

Cohort definitions:
  Heart Failure  — ICD-10: I50.x  | ICD-9: 428.x
  Pneumonia      — ICD-10: J12.x, J13, J14, J15.x, J16.x, J17, J18.x | ICD-9: 480.x-486.x
  Inclusion: age >= 18, inpatient admission, survived index admission
  Exclusion: died during index admission, transferred out at discharge

30-day readmission: any inpatient readmission within 30 days of index discharge date.
Index admission: first qualifying admission per patient per cohort.

Available tables (always use backtick references):
  `physionet-data.mimiciv_hosp.admissions`      hadm_id, admittime, dischtime, deathtime, discharge_location, admission_type
  `physionet-data.mimiciv_hosp.patients`         subject_id, gender, anchor_age, dod
  `physionet-data.mimiciv_hosp.diagnoses_icd`    subject_id, hadm_id, seq_num, icd_code, icd_version
  `physionet-data.mimiciv_hosp.d_icd_diagnoses`  icd_code, icd_version, long_title
  `physionet-data.mimiciv_hosp.labevents`        subject_id, hadm_id, itemid, charttime, value, valuenum, flag
  `physionet-data.mimiciv_hosp.d_labitems`       itemid, label, category, fluid
  `physionet-data.mimiciv_hosp.pharmacy`         subject_id, hadm_id, medication, route, starttime, stoptime

BigQuery conventions:
  - Use Standard SQL (backtick table names, DATE_DIFF not DATEDIFF)
  - Use CTEs for readability
  - Handle NULLs explicitly
  - Deduplicate patients with ROW_NUMBER() when needed
  - Both ICD-9 and ICD-10 codes must be considered (icd_version IN (9, 10))
"""

DATA_ANALYST_SYSTEM = f"""You are a Data Analyst specializing in clinical SQL and Google BigQuery.

{_PROJECT_CONTEXT}

Your role: Given a research question, write a correct, efficient BigQuery SQL query.
- Use CTEs, not subqueries
- Handle both ICD-9 and ICD-10 versions
- Add comments only when logic is non-obvious
- Output must be valid BigQuery Standard SQL

Respond ONLY with valid JSON (no markdown fences, no prose outside JSON):
{{
  "sql": "-- BigQuery SQL here",
  "rationale": "one-sentence summary of your approach",
  "assumptions": ["assumption 1", "assumption 2"]
}}"""

SENIOR_ANALYST_SYSTEM = f"""You are a Senior Clinical Data Analyst and MIMIC-IV SQL expert.

{_PROJECT_CONTEXT}

Your role: Review the Data Analyst's SQL for correctness, efficiency, and clinical validity.
Check specifically for:
- Correct ICD code patterns and LIKE clauses (e.g., 'I50%' not 'I050%')
- Both ICD-9 and ICD-10 codes covered
- JOIN logic — no accidental cartesian products
- NULL handling (deathtime, discharge_location)
- Correct 30-day readmission window calculation using DATE_DIFF or TIMESTAMP_DIFF
- Proper deduplication for index admissions
- Exact MIMIC-IV column names (dischtime not discharge_time, admittime not admit_time)

Respond ONLY with valid JSON (no markdown fences, no prose outside JSON):
{{
  "verdict": "APPROVED" or "NEEDS_REVISION",
  "issues": ["specific issue 1", "specific issue 2"],
  "suggestions": ["suggestion 1", "suggestion 2"],
  "revised_sql": "corrected SQL string if NEEDS_REVISION, otherwise null"
}}"""

PI_SYSTEM = f"""You are the Principal Investigator (PI) leading a MIMIC-IV readmission study.

{_PROJECT_CONTEXT}

Research mission: Produce clinically valid, reproducible analyses that accurately characterize
30-day readmission in heart failure and pneumonia patients, with actionable findings for
discharge planning and post-acute care.

Your role: Make the final GO/NO-GO decision on SQL queries based on:
- Does this correctly answer the research question?
- Is the cohort definition clinically defensible?
- Does it advance the readmission analysis goals?
- Is the senior analyst's review adequate?

Respond ONLY with valid JSON (no markdown fences, no prose outside JSON):
{{
  "decision": "APPROVED" or "REJECTED" or "REVISE",
  "final_sql": "the SQL to execute if APPROVED, otherwise null",
  "reasoning": "2-3 sentence clinical and scientific rationale",
  "next_steps": ["next step 1", "next step 2"]
}}"""


def _parse_json(raw: str) -> dict:
    text = raw.strip()
    if text.startswith("```"):
        parts = text.split("```")
        text = parts[1]
        if text.startswith("json"):
            text = text[4:]
    try:
        return json.loads(text.strip())
    except json.JSONDecodeError:
        return {"raw_response": raw}


def _call_agent(name: str, system: str, user_message: str) -> dict:
    print(f"\n{'=' * 64}")
    print(f"  {name}")
    print(f"{'=' * 64}")

    response = client.messages.create(
        model=MODEL,
        max_tokens=4096,
        system=[
            {
                "type": "text",
                "text": system,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        messages=[{"role": "user", "content": user_message}],
    )
    return _parse_json(response.content[0].text)


def run_pipeline(research_question: str) -> None:
    print(f"\n{'#' * 64}")
    print(f"  MIMIC-IV Readmission Pipeline: HF vs. Pneumonia")
    print(f"{'#' * 64}")
    print(f"\nQuestion: {research_question}")

    # ── Step 1: Data Analyst writes SQL ──────────────────────────
    analyst = _call_agent(
        "DATA ANALYST — Writing SQL",
        DATA_ANALYST_SYSTEM,
        f"Write a BigQuery SQL query for this research question:\n\n{research_question}",
    )

    sql = analyst.get("sql", "")
    print(f"\nRationale  : {analyst.get('rationale', '')}")
    print(f"Assumptions: {', '.join(analyst.get('assumptions', []))}")
    print(f"\n--- Generated SQL ---\n{sql}")

    # ── Step 2: Senior Analyst reviews ───────────────────────────
    senior = _call_agent(
        "SENIOR ANALYST — Reviewing SQL",
        SENIOR_ANALYST_SYSTEM,
        f"""Research question: {research_question}

Data Analyst SQL:
{sql}

Rationale: {analyst.get('rationale', '')}
Assumptions: {analyst.get('assumptions', [])}""",
    )

    verdict = senior.get("verdict", "UNKNOWN")
    issues = senior.get("issues", [])
    suggestions = senior.get("suggestions", [])
    revised_sql = senior.get("revised_sql")

    print(f"\nVerdict: {verdict}")
    if issues:
        print("Issues:\n  - " + "\n  - ".join(issues))
    if suggestions:
        print("Suggestions:\n  - " + "\n  - ".join(suggestions))

    sql_for_pi = revised_sql or sql
    if revised_sql:
        print(f"\n--- Revised SQL ---\n{revised_sql}")

    # ── Step 3: PI makes final decision ──────────────────────────
    pi_prompt = f"""Research question: {research_question}

Original SQL (Data Analyst):
{sql}

Senior Analyst verdict: {verdict}
Issues: {issues}
Suggestions: {suggestions}
"""
    if revised_sql:
        pi_prompt += f"\nRevised SQL (Senior Analyst):\n{revised_sql}"
    pi_prompt += f"\nSQL under review:\n{sql_for_pi}"

    pi = _call_agent("PI — Final Decision", PI_SYSTEM, pi_prompt)

    decision = pi.get("decision", "UNKNOWN")
    final_sql = pi.get("final_sql")
    next_steps = pi.get("next_steps", [])

    print(f"\nDecision : {decision}")
    print(f"Reasoning: {pi.get('reasoning', '')}")
    if next_steps:
        print("Next Steps:\n  - " + "\n  - ".join(next_steps))

    print(f"\n{'#' * 64}")
    print(f"  PIPELINE COMPLETE — {decision}")
    print(f"{'#' * 64}")

    if decision == "APPROVED" and final_sql:
        print(f"\n--- FINAL APPROVED SQL ---\n{final_sql}")
        out_dir = os.path.join(os.path.dirname(__file__), "output")
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "latest_approved_query.sql")
        with open(out_path, "w") as f:
            f.write(f"-- Research Question: {research_question}\n")
            f.write(f"-- PI Decision: {decision}\n")
            f.write(f"-- Reasoning: {pi.get('reasoning', '')}\n\n")
            f.write(final_sql)
        print(f"\nSaved to: {out_path}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        question = " ".join(sys.argv[1:])
    else:
        print("MIMIC-IV Readmission Pipeline — Heart Failure vs. Pneumonia")
        print("Enter your research question (or 'quit' to exit):")
        question = input("> ").strip()
        if question.lower() in ("quit", "exit", "q"):
            sys.exit(0)

    run_pipeline(question)
