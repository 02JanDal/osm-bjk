from datetime import timedelta, datetime

from airflow import DAG, Dataset
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

for dataset_id, view_name, dataset_name in [(5, "trees_gavle", "tradskotsel")]:
    with DAG(
        f"deviations-{view_name}",
        description=f"Updates deviations based on v_deviations_{view_name}",
        schedule=[Dataset(f"psql://upstream/gavlekommun/{dataset_name}")],
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
        tags=["provider:Gävle kommun", "type:Deviations"],
    ):
        SQLExecuteQueryOperator(
            task_id="deviations", conn_id="PG_OSM", sql=f"SELECT upstream.sync_deviations('{view_name}', {dataset_id})"
        )
