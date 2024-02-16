CREATE OR REPLACE VIEW upstream.v_match_atervinning_gavle AS
	WITH gavle AS (
		SELECT municipality.geom FROM api.municipality WHERE municipality.code = '2180'
	), osm_objs AS (
		SELECT id, type, tags, geom FROM osm.element
		WHERE element.tags->>'recycling_type' IN ('centre', 'container') AND ST_Within(geom, (SELECT gavle.geom FROM gavle)) AND type IN ('n', 'a')
	), ups_objs AS (
         SELECT ARRAY[item.id] AS id,
            item.geometry,
			jsonb_strip_nulls(jsonb_build_object(
				'amenity', 'recycling',
				'recycling_type', 'centre',
				'name', item.original_attributes->>'NAMN',
				'addr:street', TRIM(REGEXP_SUBSTR(item.original_attributes->>'GATUADRESS', '[^,0-9]+')),
				'addr:housenumber', TRIM(REGEXP_SUBSTR(item.original_attributes->>'GATUADRESS', '[0-9]+[^,]*')),
				'addr:city', TRIM((REGEXP_MATCH(item.original_attributes->>'GATUADRESS', ', (.*)'))[1])
			)) as tags,
			'' AS note
           FROM upstream.item
          WHERE item.dataset_id = 17 AND item.original_attributes->>'KATEGORI' = 'ÅTERVINNINGSCENTRAL'
		UNION ALL
         SELECT ARRAY_AGG(item.id) AS id,
			item.geometry,
			jsonb_strip_nulls(jsonb_build_object(
				'amenity', 'recycling',
				'recycling_type', 'container',
				'addr:street', TRIM(REGEXP_SUBSTR(item.original_attributes->>'GATUADRESS', '[^,0-9]+')),
				'addr:housenumber', TRIM(REGEXP_SUBSTR(item.original_attributes->>'GATUADRESS', '[0-9]+[^,]*')),
				'addr:city', TRIM((REGEXP_MATCH(item.original_attributes->>'GATUADRESS', ', (.*)'))[1])
			)) as tags,
			'Sätt `recycling:*=yes` enligt följande: ' || STRING_AGG(TRIM(REGEXP_REPLACE(REGEXP_REPLACE(item.original_attributes->>'BESKR_KORT', 'Återvinningsstation för:  ', ''),  '  Ansvarig för stationen är FTI.', '')), ', ') as note
           FROM upstream.item
          WHERE item.dataset_id = 17 AND item.original_attributes->>'KATEGORI' = 'ÅTERVINNINGSSTATION'
		  GROUP BY item.original_attributes->>'GATUADRESS', item.geometry
        )
	SELECT * FROM (
		SELECT DISTINCT ON (ups_objs.id)
			ups_objs.id AS upstream_item_ids, ups_objs.tags AS upstream_tags, ups_objs.geometry AS upstream_geom,
			osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags,
			ups_objs.note
		FROM ups_objs
		LEFT OUTER JOIN osm_objs ON osm_objs.tags->>'recycling_type' = ups_objs.tags->>'recycling_type' AND match_condition(osm_objs.tags, ups_objs.tags, 'addr:street', 'addr:street', 'addr:housenumber', 250, 500, 1000, osm_objs.geom, ups_objs.geometry)
		ORDER BY ups_objs.id, match_score(osm_objs.tags, ups_objs.tags, 'addr:street', 'addr:street', 'addr:housenumber', 250, 500, 1000, osm_objs.geom, ups_objs.geometry)
	) AS q
	UNION ALL
	SELECT
		ARRAY[]::bigint[] AS upstream_item_ids, NULL AS upstream_tags, NULL AS upstream_geom,
		osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags,
		'' AS note
	FROM osm_objs
	LEFT OUTER JOIN ups_objs ON match_condition(osm_objs.tags, ups_objs.tags, 'addr:street', 'addr:street', 'addr:housenumber', 250, 500, 1000, osm_objs.geom, ups_objs.geometry)
	WHERE ups_objs.id IS NULL;

DROP MATERIALIZED VIEW IF EXISTS upstream.mv_match_atervinning_gavle CASCADE;
CREATE MATERIALIZED VIEW upstream.mv_match_atervinning_gavle AS SELECT * FROM upstream.v_match_atervinning_gavle;
ALTER TABLE upstream.mv_match_atervinning_gavle OWNER TO app;

CREATE OR REPLACE VIEW upstream.v_deviation_atervinning_gavle AS
	SELECT
		17::bigint AS dataset_id,
		13::bigint AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, upstream_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE
			WHEN osm_element_id IS NULL THEN 'Återvinningsstation saknas'::text
			WHEN ARRAY_LENGTH(upstream_item_ids, 1) IS NULL THEN 'Återvinningsstation/-central möjligen stängd'::text
			ELSE 'Återvinningsstation/-central saknar taggar'::text
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt Gävle kommun ska det finnas en återvinningsstation/-central här'::text
			WHEN ARRAY_LENGTH(upstream_item_ids, 1) IS NULL THEN 'Enligt Gävle kommun finns det ingen återvinningsstation/-central här, den kan vara stängd'::text
			ELSE 'Följande taggar, härledda ur från Gävle kommuns data, saknas på återvinningsstationen/-centralen här'::text
		END AS description,
		 note AS note
	FROM upstream.mv_match_atervinning_gavle
	WHERE osm_tags IS NULL OR upstream_tags IS NULL OR tag_diff(osm_tags, upstream_tags) <> '{}'::jsonb;

CREATE OR REPLACE FUNCTION api.tile_match_atervinning_gavle(z integer, x integer, y integer)
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
			FROM upstream.mv_match_atervinning_gavle items
			LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
			INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
		)
		SELECT ST_AsMVT(mvtgeom, 'default')
		FROM mvtgeom;
$$;
