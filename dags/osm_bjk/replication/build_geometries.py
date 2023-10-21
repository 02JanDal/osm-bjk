from psycopg import Cursor


def build_geometries_from_dirty(cursor: Cursor):
    print("  Completing dirty table...")
    cursor.execute("""
INSERT INTO osm.dirty (way_id)
SELECT way_node.way_id FROM osm.way_node INNER JOIN osm.dirty ON dirty.node_id = way_node.node_id
ON CONFLICT ON CONSTRAINT id_uniq DO NOTHING
""")
    cursor.execute("""
INSERT INTO osm.dirty (relation_id)
SELECT rmw.relation_id FROM osm.relation_member_way rmw INNER JOIN osm.dirty ON dirty.way_id = rmw.member_id
ON CONFLICT ON CONSTRAINT id_uniq DO NOTHING
""")
    cursor.execute("SELECT COUNT(*) FROM osm.dirty")
    print("    Total dirty elements:", cursor.fetchone()[0])
    print("  Building ways...")
    cursor.execute("""
UPDATE osm.way SET
	geom = (
		SELECT ST_MakeLine(node.geom ORDER BY way_node.sequence_order)
		FROM osm.way_node
		INNER JOIN osm.node ON node.id = way_node.node_id
		WHERE way_node.way_id = way.id
	),
	geom_timestamp = GREATEST((way.meta).timestamp, (
	    SELECT MAX((node.meta).timestamp)
		FROM osm.way_node
		INNER JOIN osm.node ON node.id = way_node.node_id
		WHERE way_node.way_id = way.id
	))
FROM osm.dirty WHERE dirty.way_id = way.id
""")
    print("  Building areas from ways...")
    cursor.execute("""
INSERT INTO osm.area (id, geom, way_id, timestamp)
	SELECT way.id, ST_Multi(ST_MakePolygon(way.geom)), way.id, way.geom_timestamp
	FROM osm.dirty
	INNER JOIN osm.way ON dirty.way_id = way.id
	WHERE ST_IsClosed(way.geom) AND ST_NPoints(way.geom) > 3
ON CONFLICT (way_id) DO UPDATE SET geom = EXCLUDED.geom, timestamp = EXCLUDED.timestamp
""")
    print("  Building areas from multipolygons...")
    # TODO: ST_BuildArea is efficient, but ignores role information, is that an issue?
    cursor.execute("""
INSERT INTO osm.area (id, relation_id, geom, timestamp)
	SELECT relation.id + 3600000000, relation.id, ST_BuildArea(ST_Collect(way.geom)), MAX(way.geom_timestamp)
	FROM osm.dirty
	INNER JOIN osm.relation ON dirty.relation_id = relation.id
	INNER JOIN osm.relation_member_way ON relation.id = relation_member_way.relation_id
	INNER JOIN osm.way ON way.id = relation_member_way.member_id
	WHERE relation.tags->>'type' = 'multipolygon'
	GROUP BY relation.id
	HAVING ST_BuildArea(ST_Collect(way.geom)) IS NOT NULL
ON CONFLICT (relation_id) DO UPDATE SET geom = EXCLUDED.geom, timestamp = EXCLUDED.timestamp
            """)
    print("  Cleaning dirty table...")
    cursor.execute("TRUNCATE osm.dirty")


def build_geometries(cursor: Cursor):
    print("  Building ways...")
    cursor.execute("""
UPDATE osm.way SET
	geom = (
		SELECT ST_MakeLine(node.geom ORDER BY way_node.sequence_order)
		FROM osm.way_node
		INNER JOIN osm.node ON node.id = way_node.node_id
		WHERE way_node.way_id = way.id
	),
	geom_timestamp = GREATEST((way.meta).timestamp, (
	    SELECT MAX((node.meta).timestamp)
		FROM osm.way_node
		INNER JOIN osm.node ON node.id = way_node.node_id
		WHERE way_node.way_id = way.id
	))
""")
    print("  Building areas from ways...")
    cursor.execute("""
    INSERT INTO osm.area (id, geom, way_id, timestamp) (
        SELECT way_geom.id, ST_Multi(ST_MakePolygon(way_geom.geom)), way_geom.id, way_geom.timestamp
            FROM osm.way_geom
            LEFT OUTER JOIN osm.area ON area.way_id = way_geom.id
            WHERE (area.timestamp IS NULL OR area.timestamp < way_geom.timestamp) AND ST_IsClosed(way_geom.geom) AND ST_NPoints(way_geom.geom) > 3
    )
    ON CONFLICT (way_id) DO UPDATE SET geom = EXCLUDED.geom, timestamp = EXCLUDED.timestamp
            """)
    print("  Building areas from multipolygons...")
    # TODO: ST_BuildArea is efficient, but ignores role information, is that an issue?
    cursor.execute("""
    INSERT INTO osm.area (id, relation_id, geom, timestamp) (SELECT relation.id + 3600000000, relation.id,
                                                                    ST_BuildArea(ST_Collect(way_geom.geom)),
                                                                    MAX(way_geom.timestamp)
                                                             FROM osm.relation
                                                                      INNER JOIN osm.relation_member_way ON relation.id = relation_member_way.relation_id
                                                                      INNER JOIN osm.way_geom ON way_geom.id = relation_member_way.member_id
                                                             WHERE tags ->> 'type' = 'multipolygon'
                                                             GROUP BY relation.id
                                                             HAVING ST_BuildArea(ST_Collect(way_geom.geom)) IS NOT NULL)
    ON CONFLICT (relation_id) DO UPDATE SET geom = EXCLUDED.geom, timestamp = EXCLUDED.timestamp
            """)
