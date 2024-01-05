from datetime import timedelta, datetime

from airflow import DAG, Dataset
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

with DAG(
    "deviations-schools-skolverket",
    description="Updates deviations based on v_deviations_schools_skolverket",
    schedule=[Dataset(f"psql://upstream/skolverket/skolenhetsregistret")],
    start_date=datetime(2024, 1, 1, 0, 0),
    catchup=False,
    max_active_runs=1,
    default_args=dict(
        depends_on_past=False,
        email=["jan@dalheimer.de"],
        email_on_failure=True,
        email_on_retry=False,
        retries=1,
        retry_delay=timedelta(minutes=5),
    ),
    tags=["provider:Skolverket", "type:Deviations"],
):
    SQLExecuteQueryOperator(
        task_id="deviations",
        conn_id="PG_OSM",
        sql="SELECT upstream.sync_deviations('schools_skolverket')",
        outlets=[Dataset("psql://api/deviations")],
    )
