from typing import Callable

import geopandas
import numpy as np
import ujson
from airflow.models import BaseOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.utils.context import Context
from geopandas import GeoDataFrame
from pandas import RangeIndex


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
                    cur.execute(
                        "SELECT id FROM upstream.provider WHERE name = %s", (self.provider,)
                    )
                    provider_id = cur.fetchone()[0]
                    cur.execute(
                        "INSERT INTO upstream.dataset (name, provider_id, url, license) VALUES (%s, %s, %s, %s) ON CONFLICT (provider_id, name) DO UPDATE SET url = EXCLUDED.url, license = EXCLUDED.license RETURNING id",
                        (self.dataset, provider_id, self.dataset_url, self.license))
                    dataset_id = cur.fetchone()[0]

                    if isinstance(df.index, RangeIndex):
                        cur.execute(
                            "DELETE FROM upstream.item WHERE dataset_id = %s",
                            (dataset_id,))
                        print("Loading data into database...")
                        items = [(dataset_id, row[1].geometry.wkb, df.crs.to_epsg(),
                                  ujson.dumps({k: v for k, v in row[1].items() if k != 'geometry'}))
                                 for row in df.iterrows() if row[1].geometry is not None]
                        ignored_items = len([1 for row in df.iterrows() if row[1].geometry is None])
                        cur.executemany(
                            "INSERT INTO upstream.item (dataset_id, geometry, original_attributes) VALUES (%s, ST_Transform(ST_Force2D(ST_GeomFromWKB(%s, %s)), 3006), %s::json) RETURNING 1",
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
                        items = [(dataset_id, row[0], row[1].geometry.wkb, df.crs.to_epsg(),
                                  ujson.dumps({k: v for k, v in row[1].items() if k != 'geometry'}))
                                 for row in df.iterrows()]
                        cur.executemany(
                            """
WITH v (dataset_id, original_id, geometry, original_attributes) AS (
        VALUES (%s, %s, ST_Transform(ST_Force2D(ST_GeomFromWKB(%s, %s)), 3006), %s::json)
        ),
    updated AS (
        UPDATE upstream.item i SET original_attributes = v.original_attributes, geometry = v.geometry
        FROM v WHERE i.dataset_id = v.dataset_id AND i.original_id = v.original_id
        RETURNING id
        ),
    inserted AS (
        INSERT INTO upstream.item (dataset_id, original_id, geometry, original_attributes)
        (SELECT v.* FROM v
         LEFT OUTER JOIN upstream.item i2 ON v.dataset_id = i2.dataset_id AND v.original_id = i2.original_id
         WHERE i2.id IS NULL)
         RETURNING id
        )
SELECT * FROM updated UNION ALL SELECT * FROM inserted
                            """,
                            items
                        )
                        print(f"Inserted or updated of {len(items)} items")

                    conn.commit()
            finally:
                conn.rollback()
