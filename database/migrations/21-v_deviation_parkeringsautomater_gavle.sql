CREATE OR REPLACE VIEW upstream.v_match_parkeringsautomater_gavle AS
	WITH gavle AS (
		SELECT municipality.geom FROM api.municipality WHERE municipality.code = '2180'
	), osm_objs AS (
		SELECT id, type, tags, geom FROM osm.element
		WHERE element.tags->>'amenity' = 'vending_machine' AND element.tags->>'vending' = 'parking_tickets' AND ST_Within(geom, (SELECT gavle.geom FROM gavle)) AND type = 'n'
	), ups_objs AS (
	 SELECT ARRAY[item.id] AS id,
		item.geometry,
		jsonb_build_object(
			'amenity', 'vending_machine',
			'vending', 'parking_tickets',
			'currency:SEK', 'yes',
			'payment:debit_cards', 'yes',
			'payment:credit_cards', 'yes',
			'payment:others', 'no',
			'ref', item.original_attributes->>'name'
			-- TODO: we also get the zone code for some meters, can we somehow tag that?
		) as tags
	   FROM upstream.item
	  WHERE item.dataset_id = 33
	)
	SELECT DISTINCT ON (ups_objs.id)
		ups_objs.id AS upstream_item_ids, ups_objs.tags AS upstream_tags, ups_objs.geometry AS upstream_geom,
		osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags
	FROM ups_objs
	LEFT OUTER JOIN osm_objs ON match_condition(osm_objs.tags, ups_objs.tags, 'ref', 50, 100, osm_objs.geom, ups_objs.geometry)
	ORDER BY ups_objs.id, match_score(osm_objs.tags, ups_objs.tags, 'ref', 50, 100, osm_objs.geom, ups_objs.geometry);
CREATE MATERIALIZED VIEW upstream.mv_match_parkeringsautomater_gavle AS SELECT * FROM upstream.v_match_parkeringsautomater_gavle;
ALTER TABLE upstream.mv_match_parkeringsautomater_gavle OWNER TO app;

CREATE OR REPLACE VIEW upstream.v_deviation_parkeringsautomater_gavle AS
	SELECT
		33 AS dataset_id,
		16 AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, upstream_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE
			WHEN osm_element_id IS NULL THEN 'Parkeringsautomat saknas'::text
			ELSE 'Parkeringsautomat saknar taggar'::text
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt Gävle kommun ska det finnas en parkeringsautomat här'::text
			ELSE 'Följande taggar, härledda ur från Gävle kommuns data, saknas på parkeringsautomaten här'::text
		END AS description,
		 '' AS note
	FROM upstream.mv_match_parkeringsautomater_gavle
	WHERE osm_tags IS NULL OR upstream_tags IS NULL OR tag_diff(osm_tags, upstream_tags) <> '{}'::jsonb;

CREATE OR REPLACE FUNCTION api.tile_match_parkeringsautomater_gavle(z integer, x integer, y integer)
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
			FROM upstream.mv_match_parkeringsautomater_gavle items
			LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
			INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
		)
		SELECT ST_AsMVT(mvtgeom, 'default')
		FROM mvtgeom;
$$;
