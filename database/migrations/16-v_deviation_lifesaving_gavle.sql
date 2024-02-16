CREATE OR REPLACE VIEW upstream.v_match_lifesaving_gavle AS
	WITH gavle AS (
		SELECT municipality.geom FROM api.municipality WHERE municipality.code = '2180'
	), osm_objs AS (
		SELECT id, type, tags, geom FROM osm.element
		WHERE element.tags ? 'emergency' AND string_to_array(element.tags->>'emergency', ';') && ARRAY['life_ring', 'rescue_boat', 'rescue_ladder'] AND type = 'n' AND ST_Within(geom, (SELECT gavle.geom FROM gavle))
	), ups_objs AS (
	 SELECT ARRAY[item.id] AS id,
		item.geometry,
		CASE
				WHEN (item.original_attributes->>'TYP') = 'Livräddningsboj' THEN jsonb_build_object('emergency', 'life_ring')
				WHEN (item.original_attributes->>'TYP') = 'Livräddningsstege' THEN jsonb_build_object('emergency', 'rescue_ladder')
				WHEN (item.original_attributes->>'TYP') = 'Livräddningspost' THEN jsonb_build_object('emergency', 'life_ring;rescue_ladder')
				WHEN (item.original_attributes->>'TYP') = 'Livräddningsbåt' THEN jsonb_build_object('emergency', 'rescue_boat')
				ELSE jsonb_build_object()
			END AS tags
	   FROM upstream.item
	  WHERE item.dataset_id = 8
	)
	SELECT DISTINCT ON (ups_objs.id)
		ups_objs.id AS upstream_item_ids, ups_objs.tags AS upstream_tags, ups_objs.geometry AS upstream_geom,
		osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags
	FROM ups_objs
	LEFT OUTER JOIN osm_objs ON match_condition(5, osm_objs.geom, ups_objs.geometry)
	ORDER BY ups_objs.id, match_score(5, osm_objs.geom, ups_objs.geometry);

DROP MATERIALIZED VIEW IF EXISTS upstream.mv_match_lifesaving_gavle CASCADE;
CREATE MATERIALIZED VIEW upstream.mv_match_lifesaving_gavle AS SELECT * FROM upstream.v_match_lifesaving_gavle;
ALTER TABLE upstream.mv_match_lifesaving_gavle OWNER TO app;

CREATE OR REPLACE VIEW upstream.v_deviation_lifesaving_gavle AS
	SELECT
		8::bigint AS dataset_id,
		16::bigint AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, upstream_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE
			WHEN osm_element_id IS NULL THEN 'Livräddningsutrustning saknas'::text
			ELSE 'Livräddningsutrustning saknar taggar'::text
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt Gävle kommun ska det finnas livräddningsutrustning här'::text
			ELSE 'Följande taggar, härledda ur från Gävle kommuns data, saknas på livräddningsutrustningen här'::text
		END AS description,
		 '' AS note
	FROM upstream.mv_match_lifesaving_gavle
	WHERE osm_tags IS NULL OR upstream_tags IS NULL OR tag_diff(osm_tags, upstream_tags) <> '{}'::jsonb;

CREATE OR REPLACE FUNCTION api.tile_match_lifesaving_gavle(z integer, x integer, y integer)
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
			FROM upstream.mv_match_lifesaving_gavle items
			LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
			INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
		)
		SELECT ST_AsMVT(mvtgeom, 'default')
		FROM mvtgeom;
$$;
