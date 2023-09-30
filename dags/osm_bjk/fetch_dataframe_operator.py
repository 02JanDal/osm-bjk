from datetime import datetime
from typing import Callable, Iterable, cast

import geopandas
import numpy as np
import psycopg2
import ujson
from airflow.models import BaseOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.utils.context import Context
from geopandas import GeoDataFrame
from pandas import RangeIndex


def get_or_create_dataset(cur: psycopg2._psycopg.cursor, provider: str, dataset: str, dataset_url: str, license: str) -> int:
    cur.execute(
        "SELECT id FROM upstream.provider WHERE name = %s", (provider,)
    )
    provider_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO upstream.dataset (name, provider_id, url, license) VALUES (%s, %s, %s, %s) ON CONFLICT (provider_id, name) DO UPDATE SET url = EXCLUDED.url, license = EXCLUDED.license RETURNING id",
        (dataset, provider_id, dataset_url, license))
    return cur.fetchone()[0]


def upsert(cur: psycopg2._psycopg.cursor, items: Iterable[tuple[int, str, bytes, int, dict, datetime]]):
    cur.executemany(
        """
WITH v (dataset_id, original_id, geometry, original_attributes, fetched_at) AS (
    VALUES (%s, %s, ST_Transform(ST_Force2D(ST_GeomFromWKB(%s, %s)), 3006), %s::json, %s)
),
updated AS (
    UPDATE upstream.item i SET original_attributes = v.original_attributes, geometry = v.geometry, fetched_at = v.fetched_at
    FROM v WHERE i.dataset_id = v.dataset_id AND i.original_id = v.original_id
    RETURNING id
),
inserted AS (
    INSERT INTO upstream.item (dataset_id, original_id, geometry, original_attributes, fetched_at)
    (SELECT v.* FROM v
    LEFT OUTER JOIN upstream.item i2 ON v.dataset_id = i2.dataset_id AND v.original_id = i2.original_id
    WHERE i2.id IS NULL)
    RETURNING id
)
SELECT * FROM updated UNION ALL SELECT * FROM inserted
        """,
        ((i[0], i[1], i[2], i[3], ujson.dumps(i[4]), i[5]) for i in items)
    )


class FetchDataframeOperator(BaseOperator):
    def __init__(self, *, fetch: Callable[[], GeoDataFrame] | str, provider: str, dataset: str, dataset_url: str,
                 license: str, **kwargs):
        super().__init__(**kwargs)
        self.fetch = fetch
        self.provider = provider
        self.dataset = dataset
        self.dataset_url = dataset_url
        self.license = license

    def execute(self, context: Context):
        print("Fetching...")
        fetched_at = datetime.utcnow()
        if isinstance(self.fetch, str):
            df = geopandas.read_file(self.fetch)
            print(f"Got {len(df)} items from {self.fetch}")
        else:
            df = self.fetch()
            print(f"Got {len(df)} items")
        df = df.replace(np.nan, None)
        print("Preparing database...")
        hook = PostgresHook(postgres_conn_id="PG_OSM")
        with hook.get_conn() as conn:
            hook.set_autocommit(conn, False)
            try:
                with conn.cursor() as cur:
                    dataset_id = get_or_create_dataset(cur, self.provider, self.dataset, self.dataset_url, self.license)

                    if isinstance(df.index, RangeIndex):
                        cur.execute(
                            "DELETE FROM upstream.item WHERE dataset_id = %s",
                            (dataset_id,))
                        print("Loading data into database...")
                        items = [(dataset_id, row[1].geometry.wkb, df.crs.to_epsg(),
                                  ujson.dumps({k: v for k, v in row[1].items() if k != 'geometry'}),
                                  fetched_at)
                                 for row in df.iterrows() if row[1].geometry is not None]
                        ignored_items = len([1 for row in df.iterrows() if row[1].geometry is None])
                        cur.executemany(
                            "INSERT INTO upstream.item (dataset_id, geometry, original_attributes, fetched_at) VALUES (%s, ST_Transform(ST_Force2D(ST_GeomFromWKB(%s, %s)), 3006), %s::json, %s) RETURNING 1",
                            items
                        )
                        print(f"Inserted {len(items)} items")
                        if ignored_items:
                            print(f"Ignored {ignored_items} items without geometry")
                    else:
                        cur.execute(
                            "DELETE FROM upstream.item WHERE dataset_id = %s AND original_id <> ANY(%s)",
                            (dataset_id, list(df.index)))
                        print("Loading data into database...")
                        items = [(dataset_id, cast(str, row[0]), cast(bytes, row[1].geometry.wkb), cast(int, df.crs.to_epsg()),
                                  {k: v for k, v in row[1].items() if k != 'geometry'},
                                  fetched_at)
                                 for row in df.iterrows()]
                        upsert(cur, items)
                        print(f"Inserted or updated of {len(items)} items")

                    conn.commit()
            finally:
                conn.rollback()