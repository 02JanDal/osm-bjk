from contextlib import contextmanager
from typing import Generator, Optional

import psycopg
from airflow.hooks.base import BaseHook
from airflow.models import Connection
from psycopg import Cursor


@contextmanager
def pg_cursor(name: Optional[str] = None) -> Generator[Cursor, None, None]:
    conn_data: Connection = BaseHook.get_connection("PG_OSM")
    with psycopg.connect(
            host=conn_data.host,
            user=conn_data.login,
            password=conn_data.password,
            dbname=conn_data.schema,
            port=conn_data.port,
            application_name=name
    ) as conn:
        conn.autocommit = False
        with conn.cursor() as cur:
            try:
                yield cur
                conn.commit()
            except BaseException:
                conn.rollback()
                raise
