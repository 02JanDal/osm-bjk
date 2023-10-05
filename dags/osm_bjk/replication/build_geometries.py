from psycopg import Cursor


def build_geometries(cursor: Cursor):
    print("  Building ways...")
    cursor.execute("""
    WITH timestamps AS (SELECT way.id, GREATEST((way.meta).timestamp, MAX((node.meta).timestamp)) as timestamp
                        FROM osm.way
                                 INNER JOIN osm.way_node ON way.id = way_node.way_id
                                 INNER JOIN osm.node ON way_node.node_id = node.id
                        GROUP BY way.id),
         dirty AS (SELECT timestamps.id, timestamps.timestamp
                   FROM timestamps
                            LEFT OUTER JOIN osm.way_geom ON way_geom.id = timestamps.id
                   WHERE way_geom.timestamp IS NULL
                      or way_geom.timestamp < timestamps.timestamp),
         geometry AS (SELECT dirty.id, ST_MakeLine(node.geom ORDER BY way_node.sequence_order) as geometry, dirty.timestamp
                      FROM dirty
                               INNER JOIN osm.way_node ON way_node.way_id = dirty.id
                               INNER JOIN osm.node ON way_node.node_id = node.id
                      GROUP BY dirty.id, dirty.timestamp)
    INSERT
    INTO osm.way_geom (id, geom, timestamp) (SELECT * FROM geometry)
    ON CONFLICT (id) DO UPDATE SET geom      = EXCLUDED.geom,
                                   timestamp = EXCLUDED.timestamp
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
