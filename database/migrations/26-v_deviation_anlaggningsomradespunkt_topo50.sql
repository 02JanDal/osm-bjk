CREATE VIEW upstream.v_deviation_anlaggningsomradespunkt_topo50 AS
WITH gavle AS (
         SELECT municipality.geom
           FROM api.municipality
          WHERE municipality.code = '2180'
        ),
		missing AS (
	SELECT item.*, jsonb_build_object('leisure', 'sports_centre') as tags FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' IN ('stadium', 'pitch', 'sports_centre', 'sports_hall')
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Idrottsanläggning' AND element.id IS NULL AND NOT ST_Within(element.geom, (SELECT gavle.geom FROM gavle))
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'pitch', 'sport', 'shooting') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' = 'pitch' AND element.tags->>'sport' = 'shooting'
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' IN ('Skjutbana, mindre', 'Skjutbana') AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'bathing_place') as tags FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' IN ('bathing_place', 'swimming_area')
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Badplats' AND element.id IS NULL AND NOT ST_Within(element.geom, (SELECT gavle.geom FROM gavle))
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'track', 'sport', 'horse_racing') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' IN ('track', 'sports_centre', 'pitch') AND element.tags->>'sport' IN ('horse_racing', 'equestrian')
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' IN ('Travbana', 'Galoppbana') AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('emergency', 'water_rescue') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'emergency' AND element.tags->>'emergency' IN ('water_rescue', 'rescue_station')
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Sjöräddningsstation' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'marina') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' = 'marina'
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Småbåtshamn' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'marina', 'mooring', 'guest') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND (element.tags ? 'leisure' OR element.tags ? 'man_made') AND (element.tags->>'man_made' IN ('pier', 'quay') OR element.tags->>'leisure' = 'marina') AND element.tags->>'mooring' LIKE '%guest%'
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Gästhamn' AND element.id IS NULL AND NOT ST_Within(element.geom, (SELECT gavle.geom FROM gavle))
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'pitch') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' = 'pitch'
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Bollplan' AND element.id IS NULL AND NOT ST_Within(element.geom, (SELECT gavle.geom FROM gavle))
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'pitch', 'sport', 'soccer') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' = 'pitch' AND element.tags->>'sport' = 'soccer'
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Fotbollsplan' AND element.id IS NULL AND NOT ST_Within(element.geom, (SELECT gavle.geom FROM gavle))
	UNION ALL
	SELECT item.*, jsonb_build_object('industrial', 'port') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'industrial' AND element.tags->>'industrial' = 'port' OR element.tags ? 'harbour'
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Hamn' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('tourism', 'camp_site') FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'tourism' AND element.tags->>'tourism' IN ('camp_site', 'caravan_site')
	WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Campingplats' AND element.id IS NULL
)
SELECT 139 AS dataset_id,
	CASE WHEN missing.original_attributes->>'andamal' IN ('Campingplats', 'Gästhamn', 'Småbåtshamn', 'Sjöräddningsstation') THEN 18
		 WHEN missing.original_attributes->>'andamal' IN ('Hamn') THEN 19
		 WHEN missing.original_attributes->>'andamal' IN ('Fotbollsplan', 'Bollplan', 'Travbana', 'Galoppbana', 'Skjutbana, mindre', 'Skjutbana', 'Idrottsanläggning') THEN 9
		 WHEN missing.original_attributes->>'andamal' IN ('Badplats') THEN 11
	END AS layer_id,
    ARRAY[missing.id] AS upstream_item_ids,
    missing.geometry AS suggested_geom,
    missing.tags AS suggested_tags,
    NULL::bigint AS osm_element_id,
    NULL::osm.element_type AS osm_element_type,
    SUBSTRING(missing.original_attributes->>'andamal' FROM '^[^, ]+') || ' saknas' AS title,
	'Enligt Lantmäteriets 1:50 000 karta ska det finnas en ' || LOWER(SUBSTRING(missing.original_attributes->>'andamal' FROM '^[^, ]+')) || ' här' AS description,
	'' AS note
FROM missing;

GRANT SELECT ON TABLE upstream.v_deviation_anlaggningsomradespunkt_topo50 TO app;
