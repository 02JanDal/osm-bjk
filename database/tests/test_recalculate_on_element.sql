DO $$
DECLARE
    layer_id BIGINT;
    dataset_id BIGINT;
    provider_id BIGINT;
BEGIN
    INSERT INTO api.layer (name, is_major, description) VALUES ('Test layer', FALSE, 'Test layer') RETURNING id INTO layer_id;
    INSERT INTO api.municipality (code, name, geom) VALUES ('0000', 'Test municipality', ST_MakeEnvelope(0, 0, 10000, 10000, 3006));
    INSERT INTO upstream.provider (name, url) VALUES ('Test provider', '') RETURNING id INTO provider_id;
    INSERT INTO upstream.dataset (name, provider_id, url, license) VALUES ('Test dataset', provider_id, '', '') RETURNING id INTO dataset_id;
    INSERT INTO upstream.item (dataset_id, geometry, original_attributes)
    VALUES
        -- in OSM but missing name
        (dataset_id, ST_SetSRID(ST_MakePoint(1000, 1000), 3006), '{"name":"Point toilet A"}'::jsonb),
        -- in OSM complete
        (dataset_id, ST_SetSRID(ST_MakePoint(2000, 1000), 3006), '{"name":"Point toilet B"}'::jsonb),
        -- missing from OSM
        (dataset_id, ST_SetSRID(ST_MakePoint(3000, 1000), 3006), '{"name":"Point toilet C"}'::jsonb),
        -- in OSM but missing name (will be deleted instead)
        (dataset_id, ST_SetSRID(ST_MakePoint(4000, 1000), 3006), '{"name":"Point toilet D"}'::jsonb),
        -- in OSM but missing name and wrong geometry
        (dataset_id, ST_MakeEnvelope(1000, 2000, 1025, 2025, 3006), '{"name":"Polygon toilet A"}'::jsonb),
        -- in OSM complete
        (dataset_id, ST_MakeEnvelope(2000, 2000, 2025, 2025, 3006), '{"name":"Polygon toilet B"}'::jsonb),
        -- missing from OSM
        (dataset_id, ST_MakeEnvelope(3000, 2000, 3025, 2025, 3006), '{"name":"Polygon toilet C"}'::jsonb);

    -- corresponding to Point toilet A
    INSERT INTO osm.node (id, tags, meta, geom) VALUES (42, '{"amenity":"toilets"}'::JSONB, row(now(), 1, 1), ST_SetSRID(ST_MakePoint(1000, 1000), 3006));
    -- corresponding to Point toilet B
    INSERT INTO osm.node (id, tags, meta, geom) VALUES (43, '{"amenity":"toilets","name":"Point toilet B"}'::JSONB, row(now(), 1, 1), ST_SetSRID(ST_MakePoint(2050, 1050), 3006));
    -- corresponding to Point toilet D, but will be deleted instead
    INSERT INTO osm.node (id, tags, meta, geom) VALUES (44, '{"amenity":"toilets"}'::JSONB, row(now(), 1, 1), ST_SetSRID(ST_MakePoint(4050, 1050), 3006));
    -- missing in upstream
    INSERT INTO osm.node (id, tags, meta, geom) VALUES (45, '{"amenity":"toilets","name":"Point toilet E"}'::JSONB, row(now(), 1, 1), ST_SetSRID(ST_MakePoint(5050, 1050), 3006));
    -- nodes for ways
    INSERT INTO osm.node (id, tags, meta, geom)
    VALUES (101, '{}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(1025, 2025), 3006)),
           (102, '{}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(1025, 2025), 3006)),
           (103, '{}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(1050, 2050), 3006)),
           (104, '{}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(1025, 2050), 3006)),
           (111, '{}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(2005, 2005), 3006)),
           (112, '{}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(2025, 2005), 3006)),
           (113, '{}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(2025, 2025), 3006)),
           (114, '{}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(2005, 2025), 3006));
    INSERT INTO osm.way (id, tags, meta, geom) VALUES (51, '{"amenity":"toilets"}'::jsonb, ROW(NOW(), 1, 1), ST_Boundary(ST_MakeEnvelope(1025, 2025, 1050, 2050, 3006)));
    INSERT INTO osm.way (id, tags, meta, geom) VALUES (52, '{"amenity":"toilets","name":"Polygon toilet B"}'::jsonb, ROW(NOW(), 1, 1), ST_Boundary(ST_MakeEnvelope(2005, 2005, 2025, 2025, 3006)));
    INSERT INTO osm.way_node (node_id, way_id, sequence_order)
    VALUES (101, 51, 1), (102, 51, 2), (103, 51, 3), (104, 51, 4), (101, 51, 5),
           (111, 52, 1), (112, 52, 2), (113, 52, 3), (114, 52, 4), (111, 52, 5);
    INSERT INTO osm.area (id, geom, way_id, relation_id, timestamp)
    VALUES (51, ST_MakeEnvelope(1025, 2025, 1050, 2050, 3006), 51, NULL, NOW()),
           (52, ST_MakeEnvelope(2005, 2005, 2025, 2025, 3006), 52, NULL, NOW());
    ASSERT 16 = (SELECT COUNT(*) FROM osm.element);

    CREATE VIEW upstream.v_deviation_test_dataset AS
        SELECT i.dataset_id AS dataset_id,
               (SELECT id FROM api.layer) AS layer_id,
               ARRAY[i.id] AS upstream_item_ids,
               CASE WHEN o.id IS NULL THEN i.geometry
                   ELSE NULL::geometry
                   END AS suggested_geom,
               o.id AS osm_element_id,
               o.type AS osm_element_type,
               tag_diff(COALESCE(o.tags, '{}'::jsonb), jsonb_build_object('amenity', 'toilets', 'name', i.original_attributes->>'name')) AS suggested_tags,
               CASE WHEN o.id IS NULL THEN 'Missing'::text
                   ELSE 'Incomplete'::text
                   END AS title,
                ''::text AS description,
                ''::text AS note
        FROM (SELECT * FROM upstream.item) i
        LEFT JOIN (SELECT * FROM osm.element WHERE element.tags->>'amenity' = 'toilets' AND element.type IN ('n', 'a')) o ON ST_DWithin(o.geom, i.geometry, 100)
        WHERE o.id IS NULL OR o.tags->>'name' IS DISTINCT FROM i.original_attributes->>'name'
    UNION ALL
        SELECT (SELECT id FROM api.dataset) AS dataset_id,
               (SELECT id FROM api.layer) AS layer_id,
               ARRAY[]::bigint[] AS upstream_item_ids,
               NULL::geometry AS suggested_geom,
               element.id AS osm_element_id,
               element.type AS osm_element_type,
               NULL::jsonb AS suggested_tags,
               'Removed'::text AS title,
               ''::text AS description,
               ''::text AS note
           FROM osm.element
               WHERE element.tags->>'amenity' = 'toilets' AND element.type IN ('n', 'a') AND NOT (EXISTS (SELECT 1 FROM upstream.item WHERE ST_DWithin(element.geom, item.geometry, 500)));
    CREATE OR REPLACE VIEW upstream.v_deviations AS SELECT * FROM upstream.v_deviation_test_dataset;

    ASSERT 6 = (SELECT COUNT(*) FROM upstream.v_deviation_test_dataset);
    SELECT upstream.sync_deviations('test_dataset'::text);
    ASSERT 6 = (SELECT COUNT(*) FROM api.deviation);

    DELETE FROM osm.node WHERE id = 45;
    PERFORM test('Suggested delete is performed', 'fixed', (SELECT action FROM api.deviation WHERE osm_element_id = 45));

    DELETE FROM osm.node WHERE id = 44;
    PERFORM test('Suggested change is deleted instead', 'Missing'::text, (SELECT title FROM api.deviation WHERE suggested_tags->>'name' = 'Point toilet D'));

    PERFORM test('Suggested addition is performed but incomplete', 'Missing', (SELECT title FROM api.deviation WHERE suggested_tags->>'name' = 'Point toilet C'));
    INSERT INTO osm.node (id, tags, meta, geom) VALUES (1000, '{"amenity":"toilets"}'::jsonb, ROW(NOW(), 1, 1), ST_SetSRID(ST_MakePoint(3010, 1010), 3006));
    PERFORM test('Suggested addition is performed but incomplete', 'Incomplete', (SELECT title FROM api.deviation WHERE suggested_tags->>'name' = 'Point toilet C'));
    PERFORM test('Suggested addition is performed but incomplete', NULL, (SELECT action FROM api.deviation WHERE suggested_tags->>'name' = 'Point toilet C'));
    UPDATE osm.node SET tags = '{"amenity":"toilets","name":"Point toilet C"}'::jsonb WHERE id = 1000;
    PERFORM test('Suggested addition is performed and finalized', 'Incomplete', (SELECT title FROM api.deviation WHERE suggested_tags->>'name' = 'Point toilet C'));
    PERFORM test('Suggested addition is performed and finalized', 'fixed', (SELECT action FROM api.deviation WHERE suggested_tags->>'name' = 'Point toilet C'));


END; $$;
