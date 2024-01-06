CREATE OR REPLACE VIEW upstream.v_deviation_transformatoromradespunkt_topo50 AS
WITH missing AS (
	SELECT item.*, jsonb_build_object('power', 'substation') as tags FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'power' AND element.tags->>'power' = 'substation'
	WHERE item.dataset_id = 149 AND element.id IS NULL
)
SELECT 149 AS dataset_id,
	20 AS layer_id,
    ARRAY[missing.id] AS upstream_item_ids,
    missing.geometry AS suggested_geom,
    missing.tags AS suggested_tags,
    NULL::bigint AS osm_element_id,
    NULL::osm.element_type AS osm_element_type,
    'Transformatorområde saknas' AS title,
	'Enligt Lantmäteriets 1:50 000 karta ska det finnas ett transformatorområde här' AS description,
	'' AS note
FROM missing;

GRANT SELECT ON TABLE upstream.v_deviation_transformatoromradespunkt_topo50 TO app;
