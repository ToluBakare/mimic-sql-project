from google.cloud import bigquery

client = bigquery.Client(project="third-pad-435601-a2")

query = """
    SELECT COUNT(*) as total_admissions
    FROM `physionet-data.mimiciv_3_1_hosp.admissions`
"""

result = client.query(query).to_dataframe()
print(result)
