INSERT INTO osm.node(id,geom,tags,meta) VALUES (42, ST_SetSRID(ST_MakePoint(1, 2), 3006), '{}'::JSONB, row(now(), 1, 1));
INSERT INTO osm.way(id,tags,meta) VALUES (43, '{}'::JSONB, row(now(), 1, 1));
INSERT INTO osm.relation(id,tags,meta) VALUES (44, '{}'::JSONB, row(now(), 1, 1));

SELECT test(1, (SELECT count(*) FROM osm.dirty WHERE node_id = 42));
SELECT test(1, (SELECT count(*) FROM osm.dirty WHERE way_id = 43));
SELECT test(1, (SELECT count(*) FROM osm.dirty WHERE relation_id = 44));
SELECT test(3, (SELECT count(*) FROM osm.dirty));
