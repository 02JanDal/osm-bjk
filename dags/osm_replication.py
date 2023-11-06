import os
import sys
from datetime import timedelta, datetime
from logging import StreamHandler
from tempfile import TemporaryDirectory
from typing import TypedDict, cast
from urllib.request import urlretrieve

import ujson
from airflow.decorators import task
from airflow.models import TaskInstance
from osmapi import OsmApi
from osmium.replication.server import ReplicationServer, LOG as REPLICATION_LOG
from osmium.replication.utils import get_replication_header
from psycopg import Cursor, Copy

from airflow import DAG, Dataset
from osm_bjk import make_prefix
from osm_bjk.pg_cursor import pg_cursor
from osm_bjk.replication.build_geometries import build_geometries
from osm_bjk.replication.copy_handlers import (
    CopyRelationHandler,
    CopyNodeHandler,
    CopyWayHandler,
    CopyChangesetHandler,
)
from osm_bjk.replication.replication_handler import ReplicationHandler
from osm_bjk.replication.schema import OSM_SCHEMA

REPLICATION_LOG.addHandler(StreamHandler(sys.stderr))

latest_url = "https://download.openstreetmap.fr/extracts/europe/sweden-latest.osm.pbf"


class LoadReturn(TypedDict):
    url: str
    sequence: int
    timestamp: datetime


with DAG(
    "osm-init",
    description="Fetches initial replication state",
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
    tags=["osm"],
):

    @task(task_id="load-nodes", multiple_outputs=True)
    def load_nodes(ti: TaskInstance | None = None) -> LoadReturn:
        with pg_cursor(cast(TaskInstance, ti)) as cur:
            with TemporaryDirectory() as directory:
                print("Downloading...")
                filename = os.path.join(directory, "data.osm.pbf")
                urlretrieve(latest_url, filename)
                url, sequence, timestamp = get_replication_header(filename)
                print("Pre-loading...")
                handler = CopyNodeHandler(cur, make_prefix(cast(TaskInstance, ti).run_id))
                handler.apply_file(filename, locations=False)
                handler.write_buffer()
        return dict(url=url, sequence=sequence, timestamp=timestamp)

    @task(task_id="load-ways", multiple_outputs=True)
    def load_ways(ti: TaskInstance | None = None) -> LoadReturn:
        with pg_cursor(cast(TaskInstance, ti)) as cur:
            with TemporaryDirectory() as directory:
                print("Downloading...")
                filename = os.path.join(directory, "data.osm.pbf")
                urlretrieve(latest_url, filename)
                print("Pre-loading...")
                url, sequence, timestamp = get_replication_header(filename)
                handler = CopyWayHandler(cur, make_prefix(cast(TaskInstance, ti).run_id))
                handler.apply_file(filename, locations=False)
                handler.write_buffer()
        return dict(url=url, sequence=sequence, timestamp=timestamp)

    @task(task_id="load-relations", multiple_outputs=True)
    def load_relations(ti: TaskInstance | None = None) -> LoadReturn:
        with pg_cursor(cast(TaskInstance, ti)) as cur:
            with TemporaryDirectory() as directory:
                print("Downloading...")
                filename = os.path.join(directory, "data.osm.pbf")
                urlretrieve(latest_url, filename)
                print("Pre-loading...")
                url, sequence, timestamp = get_replication_header(filename)
                handler = CopyRelationHandler(cur, make_prefix(cast(TaskInstance, ti).run_id))
                handler.apply_file(filename, locations=False)
                handler.write_buffer()
        return dict(url=url, sequence=sequence, timestamp=timestamp)

    @task(task_id="load-changesets", multiple_outputs=True)
    def load_changesets(ti: TaskInstance | None = None) -> LoadReturn:
        with pg_cursor(cast(TaskInstance, ti)) as cur:
            with TemporaryDirectory() as directory:
                print("Downloading...")
                filename = os.path.join(directory, "data.osm.pbf")
                urlretrieve(latest_url, filename)
                print("Pre-loading...")
                url, sequence, timestamp = get_replication_header(filename)
                handler = CopyChangesetHandler(cur, make_prefix(cast(TaskInstance, ti).run_id))
                handler.apply_file(filename, locations=False)
                handler.write_buffer()
        return dict(url=url, sequence=sequence, timestamp=timestamp)

    @task(task_id="load-missing-nodes")
    def load_missing_nodes(ti: TaskInstance | None = None):
        prefix = make_prefix(cast(TaskInstance, ti).run_id)
        osm = OsmApi()

        cur: Cursor
        with pg_cursor(ti) as cur:
            cur.execute(
                f"""
            SELECT DISTINCT unioned.id FROM (
                SELECT node_id AS id FROM osm.{prefix}_way_node
                UNION ALL
                SELECT member_id AS id FROM osm.{prefix}_relation_node
            ) AS unioned
            LEFT OUTER JOIN osm.{prefix}_node n ON n.id = unioned.id
            WHERE n.id IS NULL
            """
            )
            missing_nodes = [row[0] for row in cur.fetchall()]
            print("Missing", len(missing_nodes), "nodes")

            if missing_nodes:
                lists = [missing_nodes[i : i + 10] for i in range(0, len(missing_nodes), 10)]
                print("Fetching...")
                fetched_lists = [osm.NodesGet(lst) for lst in lists]
                print("Loading...")
                fetched_nodes = [n for lst in fetched_lists for n in lst.values()]
                copy: Copy
                with cur.copy(f"COPY osm.{prefix}_node FROM STDIN") as copy:
                    for n in fetched_nodes:
                        if "lon" in n:
                            copy.write_row(
                                (
                                    n["id"],
                                    ujson.dumps(n["tag"]),
                                    f"SRID=4326;POINT({n['lon']} {n['lat']})",
                                    (
                                        n["timestamp"]
                                        if isinstance(n["timestamp"], datetime)
                                        else datetime.fromisoformat(n["timestamp"])
                                    ).isoformat(),
                                    n["uid"],
                                    n["version"],
                                )
                            )

    @task(task_id="process", outlets=[Dataset("psql://osm")])
    def process(
        sequence_n: int,
        sequence_w: int,
        sequence_r: int,
        sequence_c: int,
        url: str,
        ti: TaskInstance | None = None,
    ):
        sequence = min(sequence_n, sequence_w, sequence_r, sequence_c)
        prefix = make_prefix(cast(TaskInstance, ti).run_id)

        with pg_cursor(ti) as cur:
            print("Creating final schema...")
            cur.execute(OSM_SCHEMA)
            cur.execute(
                "INSERT INTO osm.meta (key, value) VALUES ('url', %s), ('sequence', %s) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value",
                (url, sequence),
            )
            print("Copying data into correct tables...")
            cur.execute(
                f"INSERT INTO osm.node (id, geom, tags, meta) (SELECT id, ST_Transform(geom, 3006), tags, ROW(timestamp, uid, version)::osm.osm_meta FROM osm.{prefix}_node)"
            )
            cur.execute(
                f"INSERT INTO osm.way (id, tags, meta) (SELECT id, tags, ROW(timestamp, uid, version)::osm.osm_meta FROM osm.{prefix}_way)"
            )
            cur.execute(
                f"INSERT INTO osm.way_node (node_id, way_id, sequence_order) (SELECT node_id, way_id, sequence FROM osm.{prefix}_way_node)"
            )
            cur.execute(
                f"INSERT INTO osm.relation (id, tags, meta) (SELECT id, tags, ROW(timestamp, uid, version)::osm.osm_meta FROM osm.{prefix}_relation)"
            )
            cur.execute(
                f"INSERT INTO osm.relation_member_node (relation_id, member_id, role, sequence_order) (SELECT relation_id, member_id, role, sequence FROM osm.{prefix}_relation_node INNER JOIN osm.{prefix}_node ON id = member_id)"
            )
            cur.execute(
                f"INSERT INTO osm.relation_member_way (relation_id, member_id, role, sequence_order) (SELECT relation_id, member_id, role, sequence FROM osm.{prefix}_relation_way INNER JOIN osm.{prefix}_way ON id = member_id)"
            )
            cur.execute(
                f"INSERT INTO osm.relation_member_relation (relation_id, member_id, role, sequence_order) (SELECT relation_id, member_id, role, sequence FROM osm.{prefix}_relation_relation INNER JOIN osm.{prefix}_relation ON id = member_id)"
            )
            cur.execute(
                f"INSERT INTO osm.changeset (id, tags, created_at, open, uid) (SELECT id, tags, created_at, open, uid FROM osm.{prefix}_changeset)"
            )
            print("Building geometries...")
            build_geometries(cur)

    @task(task_id="cleanup")
    def cleanup(ti: TaskInstance | None = None):
        prefix = make_prefix(cast(TaskInstance, ti).run_id)

        with pg_cursor(ti) as cur:
            for table in (
                "relation_node",
                "relation_way",
                "relation_relation",
                "relation",
                "way_node",
                "way",
                "node",
                "changeset",
            ):
                cur.execute(f"DROP TABLE osm.{prefix}_{table} CASCADE")

    load_nodes_t = load_nodes()
    load_ways_t = load_ways()
    load_relations_t = load_relations()
    load_missing_nodes_t = load_missing_nodes()
    load_changesets_t = load_changesets()
    process_t = process(
        load_nodes_t["sequence"],
        load_ways_t["sequence"],
        load_relations_t["sequence"],
        load_changesets_t["sequence"],
        load_nodes_t["url"],
    )
    cleanup_t = cleanup()

    [load_ways_t, load_nodes_t] >> load_missing_nodes_t
    ([load_relations_t, load_ways_t, load_missing_nodes_t, load_changesets_t] >> process_t >> cleanup_t)


with DAG(
    "osm-replication",
    description="Fetches latest changes from upstream OSM servers",
    schedule_interval=timedelta(minutes=10),
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
    tags=["osm"],
):

    @task(task_id="sync", outlets=[Dataset("psql://osm")])
    def sync_task(ti: TaskInstance | None = None):
        with pg_cursor(ti) as cur:
            cur.execute("SELECT key, value FROM osm.meta")
            meta = cur.fetchall()
            url = next(m[1] for m in meta if m[0] == "url")
            sequence = int(next(m[1] for m in meta if m[0] == "sequence"))
            print("Starting replication from", url)
            print("Will start att sequence", sequence)

            with ReplicationServer(url) as rep:
                handler = ReplicationHandler(cur)
                while True:
                    res = rep.collect_diffs(sequence)
                    if res is None:
                        return None

                    res.reader.apply(handler)
                    print("Finalizing batch...")
                    handler.finalize()

                    cur.execute(
                        "UPDATE osm.meta SET value = %s WHERE key = 'sequence'",
                        (res.id,),
                    )
                    sequence = res.id
                    print(
                        "Replicated, now at sequence ",
                        res.id,
                        ", newest is",
                        res.newest,
                    )
                    print("Committing...")
                    cur.connection.commit()

                    if res.newest <= res.id:
                        print("No more sequences to fetch, replication finished")
                        return res.id

    sync_t = sync_task()
