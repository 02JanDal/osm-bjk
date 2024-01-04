from datetime import datetime, timedelta
from typing import cast

import shapely
import ujson
from airflow import DAG, Dataset
from airflow.decorators import task
from requests import Session, Response

from osm_bjk import make_prefix
from osm_bjk.fetch_dataframe_operator import get_or_create_dataset, upsert
from osm_bjk.licenses import CC0_1_0
from osm_bjk.pg_cursor import pg_cursor


def get(session: Session, url: str) -> Response:
    resp = session.get(url)
    resp.raise_for_status()
    return resp


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
        retry_delay=timedelta(minutes=5),
    ),
    tags=["provider:Skolverket"],
):

    @task(
        task_id="fetch",
        outlets=[Dataset(f"psql://upstream/skolverket/skolenhetsregistret")],
    )
    def fetch(run_id: str | None = None):
        with pg_cursor() as cur:
            # https://api.skolverket.se/skolenhetsregistret/swagger-ui/index.html#/
            with Session() as http:
                fetched_at = datetime.utcnow()

                dataset_id = get_or_create_dataset(
                    cur,
                    "Skolverket",
                    "Skolenhetsregistret",
                    "https://www.skolverket.se/skolutveckling/skolenhetsregistret",
                    CC0_1_0,
                )

                cur.execute(
                    "SELECT fetched_at FROM upstream.dataset WHERE id = %s",
                    (dataset_id,),
                )
                row = cur.fetchone()
                if row is None or row[0] is None:
                    units = get(http, "https://api.skolverket.se/skolenhetsregistret/v1/skolenhet").json()
                    units = [
                        get(
                            http, f"https://api.skolverket.se/skolenhetsregistret/v1/skolenhet/{unit['Skolenhetskod']}"
                        ).json()["SkolenhetInfo"]
                        for unit in units["Skolenheter"]
                    ]
                    cur.executemany(
                        "INSERT INTO upstream.item (dataset_id, original_id, geometry, original_attributes, updated_at) VALUES (%s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 3006), %s, %s)",
                        (
                            (
                                dataset_id,
                                unit["Skolenhetskod"],
                                unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"].replace(",", "."),
                                unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_N"].replace(",", "."),
                                ujson.dumps(unit),
                                datetime.fromisoformat(unit["Skolenhet_ValidFrom"]),
                            )
                            for unit in units
                            if unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"]
                        ),
                    )
                else:
                    changed = get(
                        http,
                        f"https://api.skolverket.se/skolenhetsregistret/v1/diff/skolenhet/{row[0].strftime('%Y%m%d')}",
                    ).json()

                    deleted = []

                    def get_unit(code: str):
                        unit = http.get(f"https://api.skolverket.se/skolenhetsregistret/v1/skolenhet/{code}")
                        if unit.status_code == 410:
                            deleted.append(code)
                            return None
                        unit.raise_for_status()
                        return unit.json()["SkolenhetInfo"]

                    units = [get_unit(unit) for unit in changed["Skolenhetskoder"]]
                    units = [u for u in units if u is not None]

                    upsert(
                        cur,
                        (
                            (
                                dataset_id,
                                cast(str, unit["Skolenhetskod"]),
                                cast(
                                    bytes,
                                    shapely.geometry.Point(
                                        float(unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"].replace(",", ".")),
                                        float(unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"].replace(",", ".")),
                                    ).wkb,
                                ),
                                3006,
                                unit,
                                datetime.fromisoformat(unit["Skolenhet_ValidFrom"]),
                            )
                            for unit in units
                            if unit["Besoksadress"]["GeoData"]["Koordinat_SweRef_E"]
                        ),
                        make_prefix(cast(str, run_id)),
                    )

                    if deleted:
                        print(f"Deleting {len(deleted)} items that were removed upstream")
                        cur.execute(
                            "DELETE FROM upstream.item WHERE dataset_id = %s AND original_id = ANY(%s)",
                            (dataset_id, deleted),
                        )

            cur.execute(
                "UPDATE upstream.dataset SET fetched_at = %s WHERE id = %s",
                (fetched_at, dataset_id),
            )

    fetch_t = fetch()
