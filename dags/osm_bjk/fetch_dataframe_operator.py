from collections import namedtuple
from datetime import datetime
from typing import Callable, Iterable, cast, NamedTuple

import geopandas
import numpy as np
import ujson
from airflow.models import BaseOperator, TaskInstance
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.utils.context import Context
from geopandas import GeoDataFrame
from pandas import RangeIndex, Timestamp
from psycopg import Cursor, Copy

from osm_bjk import make_prefix
from osm_bjk.pg_cursor import pg_cursor


def get_or_create_dataset(cur: Cursor, provider: str, dataset: str, dataset_url: str, license: str) -> int:
    cur.execute(
        "SELECT id FROM upstream.provider WHERE name = %s", (provider,)
    )
    provider_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO upstream.dataset (name, provider_id, url, license) VALUES (%s, %s, %s, %s) ON CONFLICT (provider_id, name) DO UPDATE SET url = EXCLUDED.url, license = EXCLUDED.license RETURNING id",
        (dataset, provider_id, dataset_url, license))
    return cur.fetchone()[0]


def upsert(cur: Cursor, items: Iterable[tuple[int, str, bytes, int, dict, datetime]], prefix: str):
    cur.execute(f"""
CREATE TEMPORARY TABLE {prefix}_temp (
    dataset_id INTEGER,
    original_id TEXT,
    geometry BYTEA,
    srid INTEGER,
    original_attributes TEXT,
    fetched_at TIMESTAMPTZ
)
    """)
    with cur.copy(f"COPY {prefix}_temp FROM STDIN") as copy:
        copy: Copy
        for i in items:
            copy.write_row((i[0], i[1], i[2], i[3], ujson.dumps(i[4]), i[5]))
    cur.execute(
        f"""
WITH v (dataset_id, original_id, geometry, original_attributes, fetched_at) AS (
    SELECT dataset_id, original_id, ST_Transform(ST_Force2D(ST_GeomFromWKB(geometry, srid)), 3006), original_attributes::json, fetched_at
    FROM {prefix}_temp
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
        """
    )
    cur.execute(f"DROP TABLE {prefix}_temp")


def process_row(row: NamedTuple) -> dict:
    return {k: v.isoformat() if isinstance(v, Timestamp) else v
            for k, v in row._asdict().items()
            if k not in ('geometry', 'Index')}


class FetchDataframeOperator(BaseOperator):
    def __init__(self, *, fetch: Callable[[TaskInstance], GeoDataFrame] | str, provider: str, dataset: str, dataset_url: str,
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
            df = self.fetch(context["task_instance"])
            print(f"Got {len(df)} items")
        df = df.replace(np.nan, None)
        print("Preparing database...")
        with pg_cursor() as cur:
            dataset_id = get_or_create_dataset(cur, self.provider, self.dataset, self.dataset_url, self.license)

            if isinstance(df.index, RangeIndex):
                cur.execute(
                    "DELETE FROM upstream.item WHERE dataset_id = %s",
                    (dataset_id,))
                print("Loading data into database...")
                items = [(dataset_id, row.geometry.wkb, df.crs.to_epsg(), ujson.dumps(process_row(row)), fetched_at)
                         for row in df.itertuples(index=False) if row.geometry is not None]
                ignored_items = len([1 for row in df.itertuples(index=False) if row.geometry is None])
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
                items = [(dataset_id, cast(str, row.Index), cast(bytes, row.geometry.wkb), cast(int, df.crs.to_epsg()),
                          process_row(row),
                          fetched_at)
                         for row in df.itertuples()]
                upsert(cur, items, make_prefix(context["run_id"]))
                print(f"Inserted or updated of {len(items)} items")
