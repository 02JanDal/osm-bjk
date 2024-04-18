CREATE OR REPLACE VIEW upstream.v_match_vindbrukskollen_turbines AS
	WITH osm_objs AS NOT MATERIALIZED (
		SELECT id, type, tags, element.geom, municipality.code FROM osm.element
		LEFT OUTER JOIN api.municipality ON ST_Within(element.geom, municipality.geom)
		WHERE tags->>'power' = 'generator' AND tags->>'generator:method' = 'wind_turbine' AND type = 'n'
	), ups_objs AS NOT MATERIALIZED (
		SELECT
			ARRAY[item.id] AS id,
			item.geometry,
			jsonb_strip_nulls(jsonb_build_object(
				'power', 'generator',
				'generator:method', 'wind_turbine',
				'generator:source', 'wind',
				'generator:type', 'horizontal_axis',
				'manufacturer', TRIM(item.original_attributes->>'FABRIKAT'),
				'generator:output:electricity', REPLACE(item.original_attributes->>'MAXEFFEKT', ',', '.') || ' MW',
				'model', CASE WHEN TRIM(item.original_attributes->>'MODELL') IN ('', '-') THEN NULL ELSE REPLACE(TRIM(item.original_attributes->>'MODELL'), ',', '.') END,
				'height:hub', item.original_attributes->>'NAVHOJD',
				'operator', CASE WHEN TRIM(item.original_attributes->>'ORGNAMN') ILIKE 'Projektör ej registrerad%' THEN NULL ELSE TRIM(item.original_attributes->>'ORGNAMN') END,
				'rotor:diameter', item.original_attributes->>'ROTDIAMETE',
				'height', item.original_attributes->>'TOTALHOJD',
				'start_date', CASE WHEN item.original_attributes->>'UPPFORT' IS NOT NULL AND item.original_attributes->>'UPPFORT' <> '19000101' THEN TO_CHAR(TO_DATE(item.original_attributes->>'UPPFORT', 'YYYYMMDD'), 'YYYY-MM-DD') ELSE NULL END,
				'ref', item.original_attributes->>'VERKID'
			)) as tags,
			municipality.code
		FROM upstream.item
		LEFT OUTER JOIN api.municipality ON ST_Within(item.geometry, municipality.geom)
		WHERE item.dataset_id = 462 AND item.original_attributes->>'ARENDESTATUS' = '4' AND item.original_attributes->>'STATUS' = 'Uppfört'
	)
	SELECT * FROM (
		SELECT DISTINCT ON (ups_objs.id)
			ups_objs.id AS upstream_item_ids, ups_objs.tags AS upstream_tags, ups_objs.geometry AS upstream_geom,
			osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags
		FROM ups_objs
		LEFT OUTER JOIN osm_objs ON match_condition(osm_objs.tags, ups_objs.tags, 'ref', 25, 100, osm_objs.geom, ups_objs.geometry) AND osm_objs.code = ups_objs.code
		ORDER BY ups_objs.id, match_score(osm_objs.tags, ups_objs.tags, 'ref', 25, 100, osm_objs.geom, ups_objs.geometry)
	) as q
 	UNION ALL
 	SELECT
 		ARRAY[]::bigint[] AS upstream_item_ids, NULL AS upstream_tags, NULL AS upstream_geom,
 		osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags
 	FROM osm_objs
 	LEFT OUTER JOIN ups_objs ON match_condition(osm_objs.tags, ups_objs.tags, 'ref', 25, 100, osm_objs.geom, ups_objs.geometry)
 	WHERE ups_objs.id IS NULL;

DROP MATERIALIZED VIEW IF EXISTS upstream.mv_match_vindbrukskollen_turbines CASCADE;
CREATE MATERIALIZED VIEW upstream.mv_match_vindbrukskollen_turbines AS SELECT * FROM upstream.v_match_vindbrukskollen_turbines;
ALTER TABLE upstream.mv_match_vindbrukskollen_turbines OWNER TO app;

CREATE OR REPLACE VIEW upstream.v_deviation_vindbrukskollen_turbines AS
	SELECT
		462::bigint AS dataset_id,
		22::bigint AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, upstream_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE
			WHEN osm_element_id IS NULL THEN 'Vindkraftverk saknas'::text
			WHEN ARRAY_LENGTH(upstream_item_ids, 1) IS NULL THEN 'Vindkraftverk möjligen rivet'::text
			ELSE 'Vindkraftverk saknar taggar'::text
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt Vindbrukskollen ska det finnas ett vindkraftverk här'::text
			WHEN ARRAY_LENGTH(upstream_item_ids, 1) IS NULL THEN 'Enligt Vindbrukskollen finns det inget vindkraftverk här, det kan ha rivits'::text
			ELSE 'Följande taggar, härledda från Vindbrukskollen, saknas på vindkraftverket här'::text
		END AS description,
		 '' AS note
	FROM upstream.mv_match_vindbrukskollen_turbines
    WHERE osm_element_id IS NULL OR ARRAY_LENGTH(upstream_item_ids, 1) IS NULL OR tag_diff(osm_tags, upstream_tags) <> '{}'::jsonb;

GRANT SELECT ON TABLE upstream.v_match_vindbrukskollen_turbines TO app;
GRANT SELECT ON TABLE upstream.v_deviation_vindbrukskollen_turbines TO app;

CREATE OR REPLACE FUNCTION api.tile_match_vindbrukskollen_turbines(z integer, x integer, y integer)
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
			FROM upstream.mv_match_vindbrukskollen_turbines items
			LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
			INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
		)
		SELECT ST_AsMVT(mvtgeom, 'default')
		FROM mvtgeom;
$$;
