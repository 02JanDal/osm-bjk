INSERT INTO osm.node (id, tags, meta, geom) VALUES (42, '{"amenity":"toilets"}'::JSONB, row(now(), 1, 1), ST_SetSRID(ST_MakePoint(1, 2), 3006));
INSERT INTO osm.way (id, tags, meta, geom) VALUES (
    43,
    '{"highway":"secondary"}'::JSONB,
    row(now(), 1, 1),
    ST_SetSRID(ST_MakeLine(ST_MakePoint(1, 2), ST_MakePoint(2, 1)), 3006)
);
INSERT INTO osm.way (id, tags, meta, geom) VALUES (
    44,
    '{"building":"yes"}'::JSONB,
    row(now(), 1, 1),
    ST_SetSRID(ST_MakeLine(ARRAY[ST_MakePoint(1, 2), ST_MakePoint(2, 1), ST_MakePoint(2, 2), ST_MakePoint(1, 2)]), 3006)
);
INSERT INTO osm.way (id, tags, meta, geom) VALUES (
    45,
    '{}'::JSONB,
    row(now(), 1, 1),
    ST_SetSRID(ST_MakeLine(ARRAY[ST_MakePoint(1, 2), ST_MakePoint(2, 1), ST_MakePoint(2, 2)]), 3006)
);
INSERT INTO osm.way (id, tags, meta, geom) VALUES (46, '{}'::JSONB, row(now(), 1, 1), ST_SetSRID(ST_MakeLine(ARRAY[ST_MakePoint(2, 2), ST_MakePoint(1, 2)]), 3006));
INSERT INTO osm.relation (id, tags, meta) VALUES (47, '{"type":"multipolygon","landuse":"residential"}'::JSONB, row(now(), 1, 1));
INSERT INTO osm.relation_member_way (relation_id, member_id, role, sequence_order)
VALUES (47, 45, 'outer', 1),
       (47, 46, 'outer', 2);

INSERT INTO osm.area (id, geom, way_id, relation_id, timestamp)
VALUES (44, ST_MakeEnvelope(1, 1, 2, 2, 3006), 44, NULL, now()),
       (47, ST_MakeEnvelope(3, 3, 4, 4, 3006), NULL, 47, now());

SELECT test(1::BIGINT, (SELECT count(*) FROM osm.element WHERE id = 42 AND type = 'n'));
SELECT test(42::BIGINT, (SELECT node_id FROM osm.element WHERE id = 42 AND type = 'n'));
SELECT test('{"amenity":"toilets"}'::JSONB, (SELECT tags FROM osm.element WHERE id = 42 AND type = 'n'));
SELECT test_geom(
    ST_SetSRID(ST_MakePoint(1, 2), 3006),
    (SELECT geom FROM osm.element WHERE id = 42 AND type = 'n')
);

SELECT test(1::BIGINT, (SELECT count(*) FROM osm.element WHERE id = 43 AND type = 'w'));
SELECT test(43::BIGINT, (SELECT way_id FROM osm.element WHERE id = 43 AND type = 'w'));
SELECT test('{"highway":"secondary"}'::JSONB, (SELECT tags FROM osm.element WHERE id = 43 AND type = 'w'));
SELECT test_geom(
    ST_SetSRID(ST_MakeLine(ST_MakePoint(1, 2), ST_MakePoint(2, 1)), 3006),
    (SELECT geom FROM osm.element WHERE id = 43 AND type = 'w')
);

SELECT test(1::BIGINT, (SELECT count(*) FROM osm.element WHERE id = 44 AND type = 'a'));
SELECT test(44::BIGINT, (SELECT way_id FROM osm.element WHERE id = 44 AND type = 'a'));
SELECT test('{"building":"yes"}'::JSONB, (SELECT tags FROM osm.element WHERE id = 44 AND type = 'a'));
SELECT test_geom(
    ST_MakeEnvelope(1, 1, 2, 2, 3006),
    (SELECT geom FROM osm.element WHERE id = 44 AND type = 'a')
);

SELECT test(1::BIGINT, (SELECT count(*) FROM osm.element WHERE id = 47 AND type = 'a'));
SELECT test(47::BIGINT, (SELECT relation_id FROM osm.element WHERE id = 47 AND type = 'a'));
SELECT test(
    '{"landuse":"residential","type":"multipolygon"}'::JSONB,
    (SELECT tags FROM osm.element WHERE id = 47 AND type = 'a')
);
SELECT test_geom(
    ST_MakeEnvelope(3, 3, 4, 4, 3006),
    (SELECT geom FROM osm.element WHERE id = 47 AND type = 'a')
);

UPDATE osm.way SET tags = '{"building":"residential"}'::JSONB WHERE id = 44;
UPDATE osm.relation SET tags = '{"landuse":"industrial","type":"multipolygon"}'::JSONB WHERE id = 47;

SELECT test('{"building":"residential"}'::JSONB, (SELECT tags FROM osm.element WHERE id = 44 AND type = 'a'));
SELECT test('{"landuse":"industrial","type":"multipolygon"}'::JSONB, (SELECT tags FROM osm.element WHERE id = 47 AND type = 'a'));
