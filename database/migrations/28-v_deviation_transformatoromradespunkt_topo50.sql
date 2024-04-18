CREATE OR REPLACE VIEW upstream.v_match_transformatoromradespunkt_topo50 AS
	SELECT DISTINCT ON (item.id)
		ARRAY[item.id] AS upstream_item_ids, jsonb_build_object('power', 'substation') AS upstream_tags, item.geometry AS upstream_geom,
		element.id AS osm_element_id, element.type AS osm_element_type, element.tags AS osm_tags
	FROM upstream.item LEFT OUTER JOIN osm.element
	ON ST_DWithin(item.geometry, element.geom, 250) AND element.tags ? 'power' AND element.tags->>'power' = 'substation'
	WHERE item.dataset_id = 149
	ORDER BY item.id, ST_Distance(item.geometry, element.geom);
DROP MATERIALIZED VIEW IF EXISTS upstream.mv_match_transformatoromradespunkt_topo50 CASCADE;
CREATE MATERIALIZED VIEW upstream.mv_match_transformatoromradespunkt_topo50 AS SELECT * FROM upstream.v_match_transformatoromradespunkt_topo50;
ALTER TABLE upstream.mv_match_transformatoromradespunkt_topo50 OWNER TO app;

DROP VIEW IF EXISTS upstream.v_deviation_transformatoromradespunkt_topo50;
CREATE OR REPLACE VIEW upstream.v_deviation_transformatoromradespunkt_topo50 AS
	SELECT
		149::bigint AS dataset_id,
		20::bigint AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, upstream_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE
			WHEN osm_element_id IS NULL THEN 'Transformatområde saknas'
			ELSE 'Transformatområde saknar taggar'
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt Lantmäteriets 1:50 000 karta ska det finnas ett transformatorområde här'
			ELSE 'Följande taggar, härledda ur Lantmäteriets 1:50 000 karta, saknas här'
		END AS description,
		 '' AS note
	FROM upstream.mv_match_transformatoromradespunkt_topo50
	WHERE osm_tags IS NULL OR upstream_tags IS NULL OR tag_diff(osm_tags, upstream_tags) <> '{}'::jsonb;

CREATE OR REPLACE FUNCTION api.tile_match_transformatoromradespunkt_topo50(z integer, x integer, y integer)
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
			FROM upstream.mv_match_transformatoromradespunkt_topo50 items
			LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
			INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
		)
		SELECT ST_AsMVT(mvtgeom, 'default')
		FROM mvtgeom;
$$;
