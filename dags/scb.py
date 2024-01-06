import os
from datetime import datetime, timedelta
from tempfile import TemporaryDirectory
from urllib.request import urlretrieve

from airflow import DAG, Dataset
import geopandas as gpd

from osm_bjk.fetch_dataframe_operator import FetchDataframeOperator
from osm_bjk.licenses import CC0_1_0

with DAG(
    "scb-forskolor",
    description="Hämtar förskolor från SCB",
    schedule_interval=timedelta(days=28),
    start_date=datetime(2023, 9, 16, 21, 30),
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
    tags=["provider:SCB"],
):

    def fetch_forskolor(*_args, **_kwargs):
        with TemporaryDirectory() as directory:
            zipname = os.path.join(directory, "data.zip")
            url = (
                "https://www.scb.se/contentassets/51c8cfbe88a94a36927ad34618e636b9/forskolor_vt23_sweref_rev230525.zip"
            )
            print(f"Downloading {url}...")
            urlretrieve(url, zipname)
            print(f"Reading...")
            return gpd.read_file(f"{zipname}")

    FetchDataframeOperator(
        task_id=f"fetch",
        fetch=fetch_forskolor,
        provider="SCB",
        dataset=f"Förskolor",
        dataset_url="https://www.scb.se/vara-tjanster/oppna-data/oppna-geodata/forskolor/",
        license=CC0_1_0,
        outlets=[Dataset(f"psql://upstream/scb/forskolor")],
    )


with DAG(
    "scb-myndighetskontor",
    description=f"Hämtar Myndighets- och kommunkontor från SCB",
    schedule_interval=timedelta(days=28),
    start_date=datetime(2023, 9, 16, 21, 30),
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
    tags=["provider:SCB"],
):

    def fetch_kontor(*_args):
        with TemporaryDirectory() as directory:
            zipname = os.path.join(directory, "data.zip")
            url = "https://www.scb.se/contentassets/ee8137db0282427f92213f12236f0dc2/myndighetsochkommunkontor_vt23_sweref.zip"
            print(f"Downloading {url}...")
            urlretrieve(url, zipname)
            print(f"Reading...")
            return gpd.read_file(f"{zipname}")

    FetchDataframeOperator(
        task_id="fetch",
        fetch=fetch_kontor,
        provider="SCB",
        dataset=f"Myndighets- och kommunkontor",
        dataset_url="https://www.scb.se/vara-tjanster/oppna-data/oppna-geodata/myndighets--och-kommunkontor/",
        license=CC0_1_0,
        outlets=[Dataset(f"psql://upstream/scb/myndighetskontor")],
    )
