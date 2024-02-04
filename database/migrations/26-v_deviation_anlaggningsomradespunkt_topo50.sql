CREATE OR REPLACE VIEW upstream.v_match_anlaggningsomradespunkt_topo50 AS
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, tag_alternatives(ARRAY[jsonb_build_object('leisure', 'sports_centre'), jsonb_build_object('leisure', 'stadium'), jsonb_build_object('leisure', 'pitch'), jsonb_build_object('leisure', 'sports_hall')], jsonb_build_object()) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'Kan även vara en `leisure=stadium`, `leisure=pitch` eller `leisure=sports_hall`, jämför med flygbild eller andra källor' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' IN ('stadium', 'pitch', 'sports_centre', 'sports_hall')
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Idrottsanläggning'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q1
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_array(jsonb_build_object('leisure', 'pitch', 'sport', 'shooting')) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' = 'pitch' AND element.tags->>'sport' = 'shooting'
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' IN ('Skjutbana, mindre', 'Skjutbana')
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q2
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, tag_alternatives(ARRAY[jsonb_build_object('leisure', 'bathing_place'), jsonb_build_object('leisure', 'swimming_area')], jsonb_build_object()) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' IN ('bathing_place', 'swimming_area')
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Badplats'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q3
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, tag_alternatives(ARRAY[jsonb_build_object('leisure', 'track'), jsonb_build_object('leisure', 'sports_centre'), jsonb_build_object('leisure', 'pitch')], jsonb_build_object('sport', 'horse_racing')) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' IN ('track', 'sports_centre', 'pitch') AND element.tags->>'sport' IN ('horse_racing', 'equestrian')
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' IN ('Travbana', 'Galoppbana')
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q4
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, tag_alternatives(ARRAY[jsonb_build_object('emergency', 'water_rescue'), jsonb_build_object('emergency', 'rescue_station')], jsonb_build_object()) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'emergency' IN ('water_rescue', 'rescue_station')
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Sjöräddningsstation'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q5
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_array(jsonb_build_object('leisure', 'marina')) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' = 'marina'
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Småbåtshamn'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q6
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, tag_alternatives(ARRAY[jsonb_build_object('leisure', 'marina'), jsonb_build_object('man_made', 'pier'), jsonb_build_object('man_made', 'quay')], jsonb_build_object('mooring', 'guest')) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND (element.tags->>'man_made' IN ('pier', 'quay') OR element.tags->>'leisure' = 'marina') AND element.tags->>'mooring' LIKE '%guest%'
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Gästhamn'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q7
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_array(jsonb_build_object('leisure', 'pitch')) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' = 'pitch'
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Bollplan'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q8
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_array(jsonb_build_object('leisure', 'pitch', 'sport', 'soccer')) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' = 'pitch' AND element.tags->>'sport' = 'soccer'
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Fotbollsplan'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q9
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_array(jsonb_build_object('industrial', 'port')) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'Se även taggen `harbour=*`' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND ((element.tags ? 'industrial' AND element.tags->>'industrial' = 'port') OR element.tags ? 'harbour')
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Hamn'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q10
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (item.id)
			ARRAY[item.id] AS upstream_item_ids, tag_alternatives(ARRAY[jsonb_build_object('tourism', 'camp_site'), jsonb_build_object('tourism', 'caravan_site')], jsonb_build_object()) AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'tourism' IN ('camp_site', 'caravan_site')
		WHERE item.dataset_id = 139 AND item.original_attributes->>'andamal' = 'Campingplats'
		ORDER BY item.id, ST_Distance(item.geometry, element.geom)
	) AS q11;

DROP MATERIALIZED VIEW IF EXISTS upstream.mv_match_anlaggningsomradespunkt_topo50 CASCADE;
CREATE MATERIALIZED VIEW upstream.mv_match_anlaggningsomradespunkt_topo50 AS SELECT * FROM upstream.v_match_anlaggningsomradespunkt_topo50;
ALTER TABLE upstream.mv_match_anlaggningsomradespunkt_topo50 OWNER TO app;

DROP VIEW IF EXISTS upstream.v_deviation_anlaggningsomradespunkt_topo50;
CREATE OR REPLACE VIEW upstream.v_deviation_anlaggningsomradespunkt_topo50 AS
	SELECT *
    FROM (SELECT DISTINCT ON (match_id)
		139 AS dataset_id,
		CASE WHEN andamal IN ('Campingplats', 'Gästhamn', 'Småbåtshamn', 'Sjöräddningsstation') THEN 18
			 WHEN andamal IN ('Hamn') THEN 19
			 WHEN andamal IN ('Fotbollsplan', 'Bollplan', 'Travbana', 'Galoppbana', 'Skjutbana, mindre', 'Skjutbana', 'Idrottsanläggning') THEN 9
			 WHEN andamal IN ('Badplats') THEN 11
		END AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, ups_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE
			WHEN osm_element_id IS NULL THEN SUBSTRING(andamal FROM '^[^, ]+') || ' saknas'
			ELSE SUBSTRING(andamal FROM '^[^, ]+') || ' saknar taggar'
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt Lantmäteriets 1:50 000 karta ska det finnas en ' || LOWER(SUBSTRING(andamal FROM '^[^, ]+')) || ' här'
			ELSE 'Följande taggar, härledda ur Lantmäteriets 1:50 000 karta, saknas här'
		END AS description,
		 '' AS note
	FROM (SELECT ROW_NUMBER() OVER () AS match_id, * FROM upstream.mv_match_anlaggningsomradespunkt_topo50) sub
	LEFT JOIN LATERAL jsonb_array_elements(upstream_tags) ups_tags ON true
    ORDER BY match_id, count_jsonb_keys(tag_diff(osm_tags, ups_tags)) ASC) sub
    WHERE osm_element_id IS NULL OR suggested_tags <> '{}'::jsonb;

CREATE OR REPLACE FUNCTION api.tile_match_anlaggningsomradespunkt_topo50(z integer, x integer, y integer)
    RETURNS bytea
    LANGUAGE 'sql'
    STABLE PARALLEL SAFE
    SECURITY DEFINER
AS $$
	WITH
		bounds AS (SELECT ST_TileEnvelope(z, x, y) AS geom),
		mvtgeom AS (
			SELECT ST_AsMVTGeom(ST_Transform(CASE
											 WHEN items.upstream_geom IS NOT NULL AND element.geom IS NOT NULL THEN ST_MakeLine(ST_Centroid(items.upstream_geom), ST_Centroid(element.geom))
											 WHEN items.upstream_geom IS NOT NULL THEN ST_Centroid(items.upstream_geom)
											 WHEN element.geom IS NOT NULL THEN ST_Centroid(element.geom)
											 END, 3857), bounds.geom) AS geom,
				items.upstream_tags::text AS upstream_tags,
				CASE WHEN element.id IS NULL THEN 'not-in-osm'
					 WHEN array_length(items.upstream_item_ids, 1) IS NULL THEN 'not-in-upstream'
					 ELSE 'in-both' END AS state
			FROM upstream.mv_match_anlaggningsomradespunkt_topo50 items
			LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
			INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
		)
		SELECT ST_AsMVT(mvtgeom, 'default')
		FROM mvtgeom;
$$;
