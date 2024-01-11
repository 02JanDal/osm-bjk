from datetime import timedelta, datetime

from airflow import DAG, Dataset
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

for view_name, dataset_name in [
    ("badplatser_gavle", "badplatser"),
    ("trees_gavle", "tradskotsel"),
    ("lifesaving_gavle", "livraddningsutrustning"),
    ("atervinning_gavle", "atervinning"),
    ("papperskorgar_gavle", "papperskorgar"),
    ("parkeringsautomater_gavle", "parkeringsautomater"),
    ("cykelpumpar_gavle", "cykelpumpar"),
    ("parkmobler_gavle", "parkmobler"),
    ("cykelparkeringsplatser_gavle", "cykelparkeringsplatser"),
    ("historiskaskyltar_gavle", "historiskaskyltar"),
    ("busshallplatser_gavle", "busshallplatser"),
]:
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
            task_id="deviations",
            conn_id="PG_OSM",
            sql=f"SELECT upstream.sync_deviations('{view_name}')",
            outlets=[Dataset("psql://api/deviations")],
        )
