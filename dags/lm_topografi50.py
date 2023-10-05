from datetime import datetime, timedelta

import geopandas
from airflow import DAG, Dataset
from airflow.decorators import task
from airflow.models import Variable, TaskInstance
from airflow.sensors.base import PokeReturnValue

from osm_bjk.fetch_dataframe_operator import FetchDataframeOperator
from osm_bjk.lantmateriet import lantmateriet, lm_order_start_delivery, lm_order_get_delivery, lm_order_get_files, \
    FileData
from osm_bjk.licenses import CC0_1_0


def fetch_base(ti: TaskInstance):
    name = ti.task.task_id.replace("fetch-", "")
    files: list[FileData] = ti.xcom_pull(task_ids="check_ready")
    file = next(f for f in files if f["title"] == f"{name}_sverige.zip")
    df = geopandas.read_file(file["href"]).set_index("objektidentitet")
    return df


with DAG(
        "lm-topografi50-init",
        description="Hämtar Topografi 50 från Lantmäteriet (BAS)",
        schedule_interval=None,
        start_date=datetime(2023, 9, 16, 21, 30),
        catchup=False,
        max_active_runs=1,
        default_args=dict(
            depends_on_past=False,
            email=["jan@dalheimer.de"],
            email_on_failure=True,
            email_on_retry=False,
            retries=1,
            retry_delay=timedelta(minutes=5)
        )
):
    @task()
    def start():
        with lantmateriet() as sess:
            lm_order_start_delivery(sess, Variable.get("LM_TOPO50_ORDER_ID"), "BAS")

    @task.sensor(poke_interval=60)
    def check_ready() -> PokeReturnValue:
        with lantmateriet() as sess:
            res = lm_order_get_delivery(sess, Variable.get("LM_TOPO50_ORDER_ID"))
            if res["status"] == "LYCKAD":
                files = lm_order_get_files(sess, Variable.get("LM_TOPO50_ORDER_ID"))
                return PokeReturnValue(is_done=True, xcom_value=files)
            return PokeReturnValue(is_done=False)

    start_t = start()
    check_ready_t = check_ready()
    start_t >> check_ready_t

    for title in ("Byggnadsverk", "Naturvård", "Militärtområde", "Kulturhistorisk lämning", "Ledningar", "Mark", "Anläggningsområde", "Hydrografi", "Kommunikation"):
        name = title.lower().replace("å", "a").replace("ä", "a").replace("ö", "o").replace(" ", "")
        op = FetchDataframeOperator(
            task_id=f"fetch-{name}",
            fetch=fetch_base,
            provider="Lantmäteriet",
            dataset=f"Topografi 50 ({title})",
            dataset_url="https://www.lantmateriet.se/sv/geodata/vara-produkter/produktlista/topografi-50-nedladdning-vektor/",
            license=CC0_1_0,
            outlets=[Dataset(f"psql://upstream/lm/topo50-{name}")]
        )
        check_ready_t >> op


with DAG(
        "lm-topografi50-update",
        description="Hämtar Topografi 50 från Lantmäteriet (FÖRÄNDRING)",
        schedule_interval=None,
        start_date=datetime(2023, 9, 16, 21, 30),
        catchup=False,
        max_active_runs=1,
        default_args=dict(
            depends_on_past=False,
            email=["jan@dalheimer.de"],
            email_on_failure=True,
            email_on_retry=False,
            retries=1,
            retry_delay=timedelta(minutes=5)
        )
):
    pass
