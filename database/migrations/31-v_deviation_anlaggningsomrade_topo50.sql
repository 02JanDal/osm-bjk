CREATE OR REPLACE VIEW upstream.v_match_anlaggningsomrade_topo50 AS
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('site', 'winter_sports') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 1000) AND (element.tags->>'landuse' = 'winter_sports' OR ((element.tags->>'landuse' = 'recreation_ground' AND element.tags->>'sport' = 'skiing') OR (element.tags->>'leisure' = 'sports_centre' AND element.tags->>'sport' = 'skiing')))
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Vintersportanläggning'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q1
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('leisure', 'pitch', 'sport', 'shooting') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'objekttyp' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' = 'pitch' AND element.tags->>'sport' = 'shooting'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'objekttyp' = 'Civilt skjutfält'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q2
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('leisure', 'sports_centre', 'sport', 'motor') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'`sport=*` kan även vara `sport=karting` eller `sport=motocross`' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' IN ('stadium', 'sports_centre') AND element.tags->>'sport' IN ('motor', 'karting', 'motocross')
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Motorsportanläggning'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q3
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('amenity', 'prison') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'amenity' = 'prison'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Kriminalvårdsanstalt'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q4
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('landuse', 'quarry') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'landuse' = 'quarry'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Täkt'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q5
	UNION ALL
-- TODO: how should these be tagged?
--	SELECT item.*, jsonb_build_object('leisure', 'marina'), item.original_attributes->>'andamal' as title FROM upstream.item
--	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' = 'marina'
--	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Testbana' AND element.id IS NULL
--	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('tourism', 'theme_park') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'Kan även vara `tourism=water_park` eller `tourism=zoo`' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'tourism' IN ('theme_park', 'water_park', 'zoo')
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Besökspark'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q6
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('landuse', 'cemetery') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND (element.tags->>'landuse' = 'cemetery' OR element.tags->>'amenity' = 'grave_yard')
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Begravningsplats'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q7
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('power', 'plant') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'power' = 'plant'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Energiproduktion'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q8
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('amenity', 'hospital') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'amenity' = 'hospital'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Sjukhusområde'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q9
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('amenity', 'recycling') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'Kan även vara `landuse=industrial`+`industrial=auto_wrecker` eller `landuse=industrial`+`industrial=scrap_yard`, kontrollera mot flygbild eller annan källa' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND (element.tags->>'amenity' = 'recycling' OR (element.tags->>'landuse' = 'industrial' AND element.tags->>'industrial' IN ('auto_wrecker', 'scrap_yard')))
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Avfallsanläggning'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q10
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('landuse', 'industrial', 'industrial', 'mine') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'landuse' = 'industrial' AND element.tags->>'industrial' = 'mine'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Gruvområde'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q11
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('leisure', 'golf_course') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' = 'golf_course'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Golfbana'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q12
	UNION ALL
-- TODO: how should these be tagged?
--	SELECT item.*, jsonb_build_object('tourism', 'camp_site'), item.original_attributes->>'andamal' as title FROM upstream.item
--	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'tourism' AND element.tags->>'tourism' IN ('camp_site', 'caravan_site')
--	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Rengärde' AND element.id IS NULL
--	UNION ALL
-- TODO: how should these be tagged?
--	SELECT item.*, jsonb_build_object('tourism', 'camp_site'), item.original_attributes->>'andamal' as title FROM upstream.item
--	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'tourism' AND element.tags->>'tourism' IN ('camp_site', 'caravan_site')
--	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Trafikövningsplats' AND element.id IS NULL
--	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('landuse', 'allotments') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'landuse' = 'allotments'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Koloniområde'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q13
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('landuse', 'education') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'landuse' = 'education'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Skolområde'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q14
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('tourism', 'theme_park') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'andamal' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'tourism' = 'theme_park'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Aktivitetspark'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q15
	UNION ALL
-- TODO: how should these be tagged?
-- 	SELECT * FROM (
-- 		SELECT DISTINCT ON (element.id)
-- 			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('leisure', 'golf_course') AS upstream_tags, item.geometry AS upstream_geom,
-- 			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
-- 			'' AS note, item.original_attributes->>'andamal' AS andamal
-- 		FROM upstream.item LEFT OUTER JOIN osm.element
-- 		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'leisure' = 'golf_course'
-- 		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Kulturanläggning'
-- 		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
-- 	) AS q16
-- 	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('landuse', 'commercial') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'Kan även vara `landuse=commercial`, kontrollera mot flygbild eller annan källa' AS note, item.original_attributes->>'objekttyp' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'landuse' IN ('commercial', 'institutional')
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Ospecificerad' AND item.original_attributes->>'objekttyp' = 'Samhällsfunktion'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q17
	UNION ALL
	SELECT * FROM (
		SELECT DISTINCT ON (element.id)
			ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('landuse', 'industrial') AS upstream_tags, item.geometry AS upstream_geom,
			element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags,
			'' AS note, item.original_attributes->>'objekttyp' AS andamal
		FROM upstream.item LEFT OUTER JOIN osm.element
		ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags->>'landuse' = 'industrial'
		WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Ospecificerad' AND item.original_attributes->>'objekttyp' = 'Industriområde'
		ORDER BY element.id, ST_Distance(item.geometry, element.geom)
	) AS q18;
DROP MATERIALIZED VIEW IF EXISTS upstream.mv_match_anlaggningsomrade_topo50 CASCADE;
CREATE MATERIALIZED VIEW upstream.mv_match_anlaggningsomrade_topo50 AS SELECT * FROM upstream.v_match_anlaggningsomrade_topo50;
ALTER TABLE upstream.mv_match_anlaggningsomrade_topo50 OWNER TO app;

DROP VIEW IF EXISTS upstream.v_deviation_anlaggningsomrade_topo50;
CREATE OR REPLACE VIEW upstream.v_deviation_anlaggningsomrade_topo50 AS
	SELECT
		140 AS dataset_id,
		CASE WHEN andamal IN ('Vintersportanläggning', 'Civilt övningsfält', 'Motorsportanläggning', 'Besökspark', 'Golfbana', 'Kulturanläggning', 'Aktivitetspark') THEN 18 -- Fritid
			 WHEN andamal IN ('Civilt skjutfält', 'Samhällsfunktion', 'Industriområde') THEN 7 -- Mark
			 WHEN andamal IN ('Skolområde', 'Koloniområde', 'Sjukhusområde', 'Rengärde', 'Begravningsplats') THEN 7 -- Mark
			 WHEN andamal IN ('Kriminalvårdsanstalt', 'Testbana', 'Trafikövningsplats') THEN 21 -- Butiker och tjänster
			 WHEN andamal IN ('Avfallsanläggning', 'Energiproduktion', 'Täkt', 'Gruvområde') THEN 19 -- Industri
		END AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, upstream_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE andamal
			WHEN 'Civilt skjutfält' THEN 'Skjultfält'
			WHEN 'Samhällsfunktion' THEN 'Samhällsfunktionsområde'
			ELSE andamal
		END || CASE
			WHEN osm_element_id IS NULL THEN ' saknas'
			ELSE ' saknar taggar'
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt Lantmäteriets 1:50 000 karta ska det finnas ett objekt med de föreslagna taggarna här'
			ELSE 'Följande taggar, härledda ur Lantmäteriets 1:50 000 karta, saknas här'
		END AS description,
		 '' AS note
	FROM upstream.mv_match_anlaggningsomrade_topo50
	WHERE osm_tags IS NULL OR upstream_tags IS NULL OR tag_diff(osm_tags, upstream_tags) <> '{}'::jsonb;

CREATE OR REPLACE FUNCTION api.tile_match_anlaggningsomrade_topo50(z integer, x integer, y integer)
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
			FROM upstream.mv_match_anlaggningsomrade_topo50 items
			LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
			INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
		)
		SELECT ST_AsMVT(mvtgeom, 'default')
		FROM mvtgeom;
$$;
