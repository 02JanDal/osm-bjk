from datetime import datetime, timedelta
from typing import cast

import shapely
import ujson
from airflow import DAG, Dataset
from airflow.decorators import task
from airflow.providers.postgres.hooks.postgres import PostgresHook
from requests import Session

from osm_bjk.fetch_dataframe_operator import get_or_create_dataset, upsert
from osm_bjk.licenses import CC0_1_0

with DAG(
    "skolverket-skolenheter",
    description="Fetches schools from Skolverket",
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
    @task(task_id="fetch", outlets=[Dataset(f"psql://upstream/skolverket/skolenhetsregistret")])
    def fetch():
        hook = PostgresHook(postgres_conn_id="PG_OSM")
        with hook.get_conn() as conn:
            hook.set_autocommit(conn, False)
            try:
                with conn.cursor() as cur:
                    with Session() as http:
                        fetched_at = datetime.utcnow()

                        dataset_id = get_or_create_dataset(cur, "Skolverket", "Skolenhetsregistret", "https://www.skolverket.se/skolutveckling/skolenhetsregistret", CC0_1_0)

                        cur.execute("SELECT MAX(fetched_at) FROM upstream.item WHERE dataset_id = %s", (dataset_id,))
                        row = cur.fetchone()
                        if row is None or row[0] is None:
                            units = http.get("https://api.skolverket.se/skolenhetsregistret/v1/skolenhet").json()
                            units = [http.get(f"https://api.skolverket.se/skolenhetsregistret/v1/skolenhet/{unit['Skolenhetskod']}").json()["SkolenhetInfo"] for unit in units["Skolenheter"]]
                            cur.executemany(
                                "INSERT INTO upstream.item (dataset_id, original_id, geometry, original_attributes, fetched_at) VALUES (%s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 3006), %s, %s)",
                                ((dataset_id, unit["Skolenhetskod"],
                                  unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"].replace(",", "."),
                                  unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_N"].replace(",", "."),
                                  ujson.dumps(unit), fetched_at
                                  ) for unit in units if unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"])
                            )
                        else:
                            changed = http.get(f"https://api.skolverket.se/skolenhetsregistret/v1/diff/skolenhet/{row[0].strftime('%Y%m%d')}")
                            units = [http.get(f"https://api.skolverket.se/skolenhetsregistret/v1/skolenhet/{unit}").json()["SkolenhetsInfo"] for unit in changed["Skolenheter"]]
                            upsert(cur, (
                                (dataset_id, cast(str, unit["Skolenhetskod"]), cast(bytes, shapely.geometry.Point(
                                    float(unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"].replace(",", ".")),
                                    float(unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"].replace(",", "."))
                                ).wkb), 3006, unit, fetched_at)
                                for unit in units
                            ))
            except Exception:
                conn.rollback()
                raise

    fetch_t = fetch()
