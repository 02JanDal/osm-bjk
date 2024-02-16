CREATE OR REPLACE VIEW upstream.v_match_schools_skolverket AS
	SELECT i.*
	FROM api.municipality
	CROSS JOIN LATERAL (
		WITH osm_objs AS NOT MATERIALIZED (
			SELECT id, type, tags, element.geom FROM osm.element
			WHERE (tags->>'amenity' = 'school' OR tags->>'disused:amenity' = 'school' OR tags->>'planned:amenity' = 'school') AND ST_Within(element.geom, municipality.geom) AND type IN ('n', 'a')
		), ups_objs AS NOT MATERIALIZED (
			SELECT ARRAY[item.id] AS id,
				item.geometry,
                CASE WHEN item.original_attributes->>'Status' = 'Aktiv' THEN jsonb_build_object('amenity', 'school', 'disused:amenity', null, 'planned:amenity', null)
                    WHEN item.original_attributes->>'Status' = 'Vilande' THEN jsonb_build_object('disused:amenity', 'school', 'end_date', item.original_attributes->>'Nedlaggningsdatum', 'amenity', null, 'planned:amenity', null)
                    WHEN item.original_attributes->>'Status' = 'Planerad' THEN jsonb_build_object('planned:amenity', 'school', 'opening_date', item.original_attributes->>'Startdatum', 'amenity', null, 'disused:amenity', null)
                    END ||
				jsonb_strip_nulls(
                           jsonb_build_object(
                                   'name', TRIM(item.original_attributes->>'SkolaNamn'),
                                   'operator', public.fix_name((item.original_attributes->'Huvudman'->>'Namn')),
                                   'operator:type', CASE
                                       WHEN ((item.original_attributes->'Huvudman'->>'Typ') = ANY (ARRAY['Kommun'::text, 'Region'::text, 'Stat'::text])) THEN 'government'::text
                                       WHEN (((item.original_attributes->'Huvudman'->>'Namn') ~~* '%förening%') OR ((item.original_attributes->'Huvudman'->>'Namn') ~~* '%ek för%')) THEN 'cooperative'
                                       WHEN ((item.original_attributes->'Huvudman'->>'Namn') ~~* '%stiftelse%') THEN 'ngo'
                                       ELSE 'private'
                                   END,
                                   'ref:se:skolverket', item.original_attributes->>'Skolenhetskod',
                                   'addr:housenumber', TRIM(SUBSTRING((item.original_attributes->'Besoksadress'->>'Adress'), '[0-9]+.*$')),
                                   'addr:street', TRIM(SUBSTRING((item.original_attributes->'Besoksadress'->>'Adress'), '^[^0-9]+')),
                                   'addr:city', TRIM(item.original_attributes->'Besoksadress'->>'Ort'),
                                   'addr:postcode', TRIM(item.original_attributes->'Besoksadress'->>'Postnr'),
                                   'contact:website', TRIM(item.original_attributes->>'Webbadress'),
                                   'contact:phone', fix_phone(item.original_attributes->>'Telefon'),
                                   'contact:email', TRIM(item.original_attributes->>'Epost')
                           ) || CASE
                               WHEN item.original_attributes->>'Inriktningstyp' = 'Waldorf' THEN jsonb_build_object('pedagogy', 'waldorf')
                               ELSE '{}'::jsonb
                               END
				) as tags
			FROM upstream.item
			WHERE item.dataset_id = 109 AND item.original_attributes->'Kommun'->>'Kommunkod' = municipality.code
		)
		SELECT * FROM (
			SELECT DISTINCT ON (ups_objs.id)
				ups_objs.id AS upstream_item_ids, ups_objs.tags AS upstream_tags, ups_objs.geometry AS upstream_geom,
				osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags
			FROM ups_objs
			LEFT OUTER JOIN osm_objs ON match_condition(osm_objs.tags, ups_objs.tags, 'name', 'ref:se:skolverket', 50, 500, 1000, osm_objs.geom, ups_objs.geometry)
			ORDER BY ups_objs.id, match_score(osm_objs.tags, ups_objs.tags, 'name', 'ref:se:skolverket', 50, 500, 1000, osm_objs.geom, ups_objs.geometry)
		) as q
		UNION ALL
		SELECT
			ARRAY[]::bigint[] AS upstream_item_ids, NULL AS upstream_tags, NULL AS upstream_geom,
			osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags
		FROM osm_objs
		LEFT OUTER JOIN ups_objs ON match_condition(osm_objs.tags, ups_objs.tags, 'name', 'ref:se:skolverket', 50, 500, 1000, osm_objs.geom, ups_objs.geometry)
		WHERE ups_objs.id IS NULL
	) i;

DROP MATERIALIZED VIEW IF EXISTS upstream.mv_match_schools_skolverket CASCADE;
CREATE MATERIALIZED VIEW upstream.mv_match_schools_skolverket AS SELECT * FROM upstream.v_match_schools_skolverket;
ALTER TABLE upstream.mv_match_schools_skolverket OWNER TO app;

CREATE OR REPLACE VIEW upstream.v_deviation_schools_skolverket AS
	SELECT
		109::bigint AS dataset_id,
		5::bigint AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, upstream_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE
			WHEN osm_element_id IS NULL THEN 'Skola saknas'::text
			WHEN ARRAY_LENGTH(upstream_item_ids, 1) IS NULL THEN 'Skola möjligen stängd'::text
			ELSE 'Skola saknar taggar'::text
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt Skolverkets register ska det finnas en skola här'::text
			WHEN ARRAY_LENGTH(upstream_item_ids, 1) IS NULL THEN 'Enligt Skolverkets register finns det ingen skola här, den kan vara stängd'::text
			ELSE 'Följande taggar, härledda ur från Skolverkets register, saknas på skolan här'::text
		END AS description,
		 '' AS note
	FROM upstream.mv_match_schools_skolverket
	WHERE (osm_tags IS NULL OR upstream_tags IS NULL OR tag_diff(osm_tags, upstream_tags) <> '{}'::jsonb)
	  -- don't suggest adding a disused school
	  AND NOT (upstream_tags ? 'disused:amenity' AND osm_element_id IS NULL);

GRANT SELECT ON TABLE upstream.v_match_schools_skolverket TO app;
GRANT SELECT ON TABLE upstream.v_deviation_schools_skolverket TO app;

CREATE OR REPLACE FUNCTION api.tile_match_schools_skolverket(z integer, x integer, y integer)
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
			FROM upstream.mv_match_schools_skolverket items
			LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
			INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
		)
		SELECT ST_AsMVT(mvtgeom, 'default')
		FROM mvtgeom;
$$;
