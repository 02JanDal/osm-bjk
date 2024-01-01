from datetime import datetime

import ujson
from osmapi import OsmApi
from osmium import SimpleHandler, Node, Way, Relation
from osmium.geom import WKTFactory
from psycopg import Cursor

from osm_bjk.replication.build_geometries import build_geometries_from_dirty
from osm_bjk.replication.process_tags import process_tags


class ReplicationHandler(SimpleHandler):
    def __init__(self, cursor: Cursor):
        super().__init__()
        self._cursor = cursor
        self._geom_factory = WKTFactory()
        self._osm = OsmApi()

        self._node_buffer: list[tuple[int, str, dict, datetime, int, int]] = []
        self._node_delete_buffer: list[int] = []
        self._nodes_now: int = 0

        self._way_buffer: list[tuple[int, dict, datetime, int, int, list[int]]] = []
        self._way_delete_buffer: list[int] = []
        self._ways_now: int = 0

        self._relation_buffer: list[
            tuple[
                int,
                dict,
                datetime,
                int,
                int,
                list[tuple[int, str | None]],
                list[tuple[int, str | None]],
                list[tuple[int, str | None]],
            ]
        ] = []
        self._relation_delete_buffer: list[int] = []
        self._relations_now: int = 0

    def _write_buffers(self, force: bool = False):
        self._write_buffer_nodes(force)
        self._write_buffer_ways(force)
        self._write_buffer_relations(force)

    def _write_buffer_relations(self, force):
        if len(self._relation_delete_buffer) > 500 or (self._relation_delete_buffer and force):
            print("  Deleting", len(self._relation_delete_buffer), "relations")
            self._cursor.execute(
                "DELETE FROM osm.relation WHERE id = ANY(%s)",
                (self._relation_delete_buffer,),
            )
            self._relation_delete_buffer = []
        if len(self._relation_buffer) > 500 or (self._relation_buffer and force):
            print("  Saving", len(self._relation_buffer), "relations")
            self._cursor.executemany(
                "INSERT INTO osm.relation (id, tags, meta) VALUES (%s, %s::json, ROW(%s, %s, %s)) ON CONFLICT (id) DO UPDATE SET tags = EXCLUDED.tags, meta = EXCLUDED.meta",
                ((row[0], ujson.dumps(row[1]), row[2], row[3], row[4]) for row in self._relation_buffer),
            )
            self._cursor.execute(
                "DELETE FROM osm.relation_member_node WHERE relation_id = ANY(%s)",
                ([row[0] for row in self._relation_buffer],),
            )
            self._cursor.execute(
                "DELETE FROM osm.relation_member_way WHERE relation_id = ANY(%s)",
                ([row[0] for row in self._relation_buffer],),
            )
            self._cursor.execute(
                "DELETE FROM osm.relation_member_relation WHERE relation_id = ANY(%s)",
                ([row[0] for row in self._relation_buffer],),
            )
            self._cursor.executemany(
                "INSERT INTO osm.relation_member_node (relation_id, member_id, role, sequence_order) SELECT val.* FROM (VALUES (%s, %s, %s, %s)) val (relation_id, member_id, role, sequence_order) INNER JOIN osm.node n ON member_id = n.id",
                ((row[0], m[0], m[1], idx) for row in self._relation_buffer for idx, m in enumerate(row[5])),
            )
            self._cursor.executemany(
                "INSERT INTO osm.relation_member_way (relation_id, member_id, role, sequence_order) SELECT val.* FROM (VALUES (%s, %s, %s, %s)) val (relation_id, member_id, role, sequence_order) INNER JOIN osm.way w ON member_id = w.id",
                ((row[0], m[0], m[1], idx) for row in self._relation_buffer for idx, m in enumerate(row[6])),
            )
            self._cursor.executemany(
                "INSERT INTO osm.relation_member_relation (relation_id, member_id, role, sequence_order) SELECT val.* FROM (VALUES (%s, %s, %s, %s)) val (relation_id, member_id, role, sequence_order) INNER JOIN osm.relation r ON member_id = r.id",
                ((row[0], m[0], m[1], idx) for row in self._relation_buffer for idx, m in enumerate(row[7])),
            )
            self._relation_buffer = []

    def _write_buffer_ways(self, force):
        if len(self._way_delete_buffer) > 500 or (self._way_delete_buffer and force):
            print("  Deleting", len(self._way_delete_buffer), "ways")
            self._cursor.execute("DELETE FROM osm.way WHERE id = ANY(%s)", (self._way_delete_buffer,))
            self._way_delete_buffer = []
        if len(self._way_buffer) > 500 or (self._way_buffer and force):
            print("  Saving", len(self._way_buffer), "ways")
            self._write_buffer_nodes(True)
            self._cursor.executemany(
                "INSERT INTO osm.way (id, tags, meta) VALUES (%s, %s::jsonb, ROW(%s, %s, %s)) ON CONFLICT (id) DO UPDATE SET tags = EXCLUDED.tags, meta = EXCLUDED.meta",
                ((row[0], ujson.dumps(row[1]), row[2], row[3], row[4]) for row in self._way_buffer),
            )
            self._cursor.execute(
                "DELETE FROM osm.way_node WHERE way_id = ANY(%s)",
                ([row[0] for row in self._way_buffer],),
            )
            self._cursor.executemany(
                "INSERT INTO osm.way_node (node_id, way_id, sequence_order) VALUES (%s, %s, %s)",
                ((n, row[0], idx) for row in self._way_buffer for idx, n in enumerate(row[5])),
            )
            self._way_buffer = []

    def _write_buffer_nodes(self, force):
        if len(self._node_delete_buffer) > 500 or (self._node_delete_buffer and force):
            print("  Deleting", len(self._node_delete_buffer), "nodes")
            self._cursor.execute("DELETE FROM osm.node WHERE id = ANY (%s)", (self._node_delete_buffer,))
            self._node_delete_buffer = []
        if len(self._node_buffer) > 500 or (self._node_buffer and force):
            print("  Saving", len(self._node_buffer), "nodes")
            self._cursor.executemany(
                "INSERT INTO osm.node (id, geom, tags, meta) VALUES (%s, ST_Transform(ST_SetSRID(ST_GeomFromText(%s), 4326), 3006), %s::jsonb, ROW(%s, %s, %s)) ON CONFLICT (id) DO UPDATE SET geom = EXCLUDED.geom, tags = EXCLUDED.tags, meta = EXCLUDED.meta",
                ((row[0], row[1], ujson.dumps(row[2]), row[3], row[4], row[5]) for row in self._node_buffer),
            )
            self._node_buffer = []

    def node(self, n: Node):
        self._write_buffers()
        if n.deleted:
            self._node_delete_buffer.append(n.id)
        else:
            self._node_buffer.append(
                (
                    n.id,
                    self._geom_factory.create_point(n),
                    process_tags(n.tags),
                    n.timestamp,
                    n.uid,
                    n.version,
                )
            )
        self._nodes_now += 1
        if self._nodes_now % 100000 == 0:
            print(f"Processed {self._nodes_now} nodes")

    def way(self, w: Way):
        self._write_buffers(self._ways_now == 0)
        if w.deleted:
            self._way_delete_buffer.append(w.id)
        else:
            self._cursor.execute(
                "SELECT id FROM osm.node WHERE id = ANY (%s)",
                ([n.ref for n in w.nodes],),
            )
            existing_nodes = [n[0] for n in self._cursor.fetchall()]
            missing_nodes = [n.ref for n in w.nodes if n.ref not in existing_nodes]
            deleted_nodes = []
            if missing_nodes:
                print(f"Fetching {len(missing_nodes)} missing nodes: {missing_nodes}")
                try:
                    lists = [missing_nodes[i : i + 10] for i in range(0, len(missing_nodes), 10)]
                    fetched_lists = [self._osm.NodesGet(lst) for lst in lists]
                    fetched_nodes = [n for lst in fetched_lists for n in lst.values()]
                    deleted_nodes = [n["id"] for n in fetched_nodes if not n["visible"]]
                    fetched_nodes = [n for n in fetched_nodes if n["visible"]]
                    for n in fetched_nodes:
                        self._node_buffer.append(
                            (
                                n["id"],
                                f"SRID=4326;POINT({n['lon']} {n['lat']})",
                                process_tags(n["tag"]),
                                n["timestamp"]
                                if isinstance(n["timestamp"], datetime)
                                else datetime.fromisoformat(n["timestamp"]),
                                n["uid"],
                                n["version"],
                            )
                        )
                except Exception as e:
                    raise RuntimeError(
                        "Could not load missing nodes: " + ", ".join([str(n) for n in missing_nodes])
                    ) from e

            self._way_buffer.append(
                (
                    w.id,
                    process_tags(w.tags),
                    w.timestamp,
                    w.uid,
                    w.version,
                    [n.ref for n in w.nodes if n.ref not in deleted_nodes],
                )
            )
        self._ways_now += 1
        if self._ways_now % 100000 == 0:
            print(f"Processed {self._ways_now} ways")

    def relation(self, r: Relation):
        self._write_buffers(self._relations_now == 0)
        if r.deleted:
            self._relation_delete_buffer.append(r.id)
        else:
            self._relation_buffer.append(
                (
                    r.id,
                    process_tags(r.tags),
                    r.timestamp,
                    r.uid,
                    r.version,
                    [(member.ref, member.role) for member in r.members if member.type == "n"],
                    [(member.ref, member.role) for member in r.members if member.type == "w"],
                    [(member.ref, member.role) for member in r.members if member.type == "r"],
                )
            )
        self._relations_now += 1
        if self._relations_now % 100000 == 0:
            print(f"Processed {self._relations_now} relations")

    def write_buffers(self):
        self._write_buffers(True)

    def finalize(self):
        self._write_buffers(True)
        build_geometries_from_dirty(self._cursor)
