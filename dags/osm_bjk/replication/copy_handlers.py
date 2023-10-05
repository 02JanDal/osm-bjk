from datetime import datetime

import ujson
from osmium import SimpleHandler, Relation, Node, Way, Changeset
from osmium.geom import WKTFactory
from psycopg import Cursor, Copy

from osm_bjk.replication.process_tags import process_tags


class CopyNodeHandler(SimpleHandler):
    def __init__(self, cursor: Cursor, prefix: str):
        super().__init__()
        self._cursor = cursor
        self._geom_factory = WKTFactory()
        self._prefix = prefix
        self._cursor.execute(f"""
CREATE TABLE IF NOT EXISTS osm.{self._prefix}_node (
    id BIGINT NOT NULL PRIMARY KEY,
    tags JSONB,
    geom GEOMETRY(Point, 4326),
    timestamp TIMESTAMPTZ,
    uid BIGINT,
    version INT
);
TRUNCATE osm.{self._prefix}_node;
        """)
        self._buffer: list[tuple[int, dict, str, datetime, int, int]] = []
        self._count = 0

    def write_buffer(self):
        with self._cursor.copy(f"COPY osm.{self._prefix}_node FROM STDIN") as copy:
            copy: Copy
            for id, tags, geom, timestamp, uid, version in self._buffer:
                copy.write_row((id, ujson.dumps(tags), geom, timestamp.isoformat(), uid, version))
        self._buffer.clear()

    def node(self, n: Node):
        self._buffer.append(
            (n.id, process_tags(n.tags), self._geom_factory.create_point(n), n.timestamp, n.uid, n.version)
        )
        self._count += 1
        if len(self._buffer) > 100000:
            self.write_buffer()
            print("Loaded", self._count, "nodes")


class CopyWayHandler(SimpleHandler):
    def __init__(self, cursor: Cursor, prefix: str):
        super().__init__()
        self._cursor = cursor
        self._prefix = prefix
        self._cursor.execute(f"""
CREATE TABLE IF NOT EXISTS osm.{self._prefix}_way (
    id BIGINT NOT NULL PRIMARY KEY,
    tags JSONB NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    uid BIGINT NOT NULL,
    version INT NOT NULL
);
CREATE TABLE IF NOT EXISTS osm.{self._prefix}_way_node (
    node_id BIGINT NOT NULL,
    way_id BIGINT NOT NULL,
    sequence INT NOT NULL
);
TRUNCATE osm.{self._prefix}_way;
TRUNCATE osm.{self._prefix}_way_node;
        """)
        self._buffer: list[tuple[int, dict, datetime, int, int]] = []
        self._node_buffer: list[tuple[int, int, int]] = []
        self._count = 0

    def write_buffer(self):
        with self._cursor.copy(f"COPY osm.{self._prefix}_way FROM STDIN") as copy:
            copy: Copy
            for id, tags, timestamp, uid, version in self._buffer:
                copy.write_row((id, ujson.dumps(tags), timestamp.isoformat(), uid, version))
        self._buffer.clear()

        with self._cursor.copy(f"COPY osm.{self._prefix}_way_node FROM STDIN") as copy:
            copy: Copy
            for row in self._node_buffer:
                copy.write_row(row)
        self._node_buffer.clear()

    def way(self, w: Way):
        self._buffer.append(
            (w.id, process_tags(w.tags), w.timestamp, w.uid, w.version)
        )
        self._node_buffer.extend(((n.ref, w.id, idx) for idx, n in enumerate(w.nodes)))
        self._count += 1
        if len(self._buffer) > 100000:
            self.write_buffer()
            print("Loaded", self._count, "ways")


class CopyRelationHandler(SimpleHandler):
    def __init__(self, cursor: Cursor, prefix: str):
        super().__init__()
        self._cursor = cursor
        self._prefix = prefix
        self._cursor.execute(f"""
CREATE TABLE IF NOT EXISTS osm.{self._prefix}_relation (
    id BIGINT NOT NULL PRIMARY KEY,
    tags JSONB NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    uid BIGINT NOT NULL,
    version INT NOT NULL
);
CREATE TABLE IF NOT EXISTS osm.{self._prefix}_relation_node (
    member_id BIGINT NOT NULL,
    relation_id BIGINT NOT NULL,
    sequence INT NOT NULL,
    role TEXT
);
CREATE TABLE IF NOT EXISTS osm.{self._prefix}_relation_way (
    member_id BIGINT NOT NULL,
    relation_id BIGINT NOT NULL,
    sequence INT NOT NULL,
    role TEXT
);
CREATE TABLE IF NOT EXISTS osm.{self._prefix}_relation_relation (
    member_id BIGINT NOT NULL,
    relation_id BIGINT NOT NULL,
    sequence INT NOT NULL,
    role TEXT
);
TRUNCATE osm.{self._prefix}_relation;
TRUNCATE osm.{self._prefix}_relation_node;
TRUNCATE osm.{self._prefix}_relation_way;
TRUNCATE osm.{self._prefix}_relation_relation;
        """)
        self._buffer: list[tuple[int, dict, datetime, int, int]] = []
        self._node_buffer: list[tuple[int, int, int, str]] = []
        self._way_buffer: list[tuple[int, int, int, str]] = []
        self._relation_buffer: list[tuple[int, int, int, str]] = []
        self._count = 0

    def write_buffer(self):
        with self._cursor.copy(f"COPY osm.{self._prefix}_relation FROM STDIN") as copy:
            copy: Copy
            for id, tags, timestamp, uid, version in self._buffer:
                copy.write_row((id, ujson.dumps(tags), timestamp.isoformat(), uid, version))
        self._buffer.clear()

        with self._cursor.copy(f"COPY osm.{self._prefix}_relation_node FROM STDIN") as copy:
            copy: Copy
            for row in self._node_buffer:
                copy.write_row(row)
        self._node_buffer.clear()

        with self._cursor.copy(f"COPY osm.{self._prefix}_relation_way FROM STDIN") as copy:
            copy: Copy
            for row in self._way_buffer:
                copy.write_row(row)
        self._way_buffer.clear()

        with self._cursor.copy(f"COPY osm.{self._prefix}_relation_relation FROM STDIN") as copy:
            copy: Copy
            for row in self._relation_buffer:
                copy.write_row(row)
        self._relation_buffer.clear()

    def relation(self, r: Relation):
        self._buffer.append(
            (r.id, process_tags(r.tags), r.timestamp, r.uid, r.version)
        )
        self._node_buffer.extend(((m.ref, r.id, idx, m.role) for idx, m in enumerate(r.members) if m.type == "n"))
        self._way_buffer.extend(((m.ref, r.id, idx, m.role) for idx, m in enumerate(r.members) if m.type == "w"))
        self._relation_buffer.extend(((m.ref, r.id, idx, m.role) for idx, m in enumerate(r.members) if m.type == "r"))
        self._count += 1
        if len(self._buffer) > 100000:
            self.write_buffer()
            print("Loaded", self._count, "relations")


class CopyChangesetHandler(SimpleHandler):
    def __init__(self, cursor: Cursor, prefix: str):
        super().__init__()
        self._cursor = cursor
        self._geom_factory = WKTFactory()
        self._prefix = prefix
        self._cursor.execute(f"""
CREATE TABLE IF NOT EXISTS osm.{self._prefix}_changeset (
    id BIGINT NOT NULL PRIMARY KEY,
    tags JSONB,
    created_at TIMESTAMPTZ,
    open INT,
    uid BIGINT
);
TRUNCATE osm.{self._prefix}_changeset;
        """)
        self._buffer: list[tuple[int, dict, datetime, bool, int]] = []
        self._count = 0

    def write_buffer(self):
        with self._cursor.copy(f"COPY osm.{self._prefix}_changeset FROM STDIN") as copy:
            copy: Copy
            for id, tags, created_at, open, uid in self._buffer:
                copy.write_row((id, ujson.dumps(tags), created_at.isoformat(), open, uid))
        self._buffer.clear()

    def changeset(self, c: Changeset):
        self._buffer.append(
            (c.id, process_tags(c.tags), c.created_at, c.open, c.uid)
        )
        self._count += 1
        if len(self._buffer) > 100000:
            self.write_buffer()
            print("Loaded", self._count, "changesets")
