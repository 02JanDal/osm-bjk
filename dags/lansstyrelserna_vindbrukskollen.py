import os
from datetime import datetime, timedelta
from tempfile import TemporaryDirectory
from urllib.request import urlretrieve

from airflow import DAG, Dataset
import geopandas as gpd

from osm_bjk.fetch_dataframe_operator import FetchDataframeOperator

with DAG(
    "lansstyrelserna-vindbrukskollen",
    description=f"Hämtar vindkraftverk från Vindbrukskollen hos Länsstyrelserna",
    schedule_interval=timedelta(days=28),
    start_date=datetime(2024, 2, 17, 15, 51),
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
    tags=["provider:Länsstyrelserna"],
):

    def fetch(*_args):
        with TemporaryDirectory() as directory:
            zipname = os.path.join(directory, "data.zip")
            url = "https://ext-dokument.lansstyrelsen.se/gemensamt/geodata/ShapeExport/lst.vbk_vindkraftverk.zip"
            print(f"Downloading {url}...")
            urlretrieve(url, zipname)
            print(f"Reading...")
            df = gpd.read_file(f"{zipname}!LST.vbk_vindkraftverk.gpkg").set_index("VERKID", drop=False)
            df["bjk__updatedAt"] = df.SenasteUppdatering.apply(
                lambda x: datetime.strptime(x, "%Y%m%d") if x is not None else None
            )
            return df[df.geometry.x > 0]  # remove null-island geometries

    FetchDataframeOperator(
        task_id="fetch",
        fetch=fetch,
        provider="Länsstyrelserna",
        dataset="Vindbrukskollen",
        outlets=[Dataset(f"psql://upstream/lansstyrelserna/vindbrukskollen")],
    )
