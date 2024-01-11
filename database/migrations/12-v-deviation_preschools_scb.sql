CREATE OR REPLACE VIEW upstream.v_match_preschools_scb AS
	WITH osm_objs AS NOT MATERIALIZED (
		SELECT id, type, tags, element.geom, municipality.code FROM osm.element
		LEFT OUTER JOIN api.municipality ON ST_Within(element.geom, municipality.geom)
		WHERE tags->>'amenity' = ANY(ARRAY['kindergarten', 'childcare'])
	), ups_objs AS NOT MATERIALIZED (
		SELECT ARRAY[item.id] AS id,
			item.geometry,
			jsonb_build_object(
				'amenity', 'kindergarten',
				'name', fix_name((item.original_attributes->>'Firmabenämning')),
				'operator', fix_name((item.original_attributes->>'Företagsnamn'))
			) as tags,
			municipality.code
		FROM upstream.item
		LEFT OUTER JOIN api.municipality ON ST_Within(item.geometry, municipality.geom)
		WHERE item.dataset_id = 110
	)
	SELECT * FROM (
		SELECT DISTINCT ON (ups_objs.id)
			ups_objs.id AS upstream_item_ids, ups_objs.tags AS upstream_tags, ups_objs.geometry AS upstream_geom,
			osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags
		FROM ups_objs
		LEFT OUTER JOIN osm_objs ON match_condition(osm_objs.tags, ups_objs.tags, 'name', 100, 500, osm_objs.geom, ups_objs.geometry)
		WHERE osm_objs.code = ups_objs.code
		ORDER BY ups_objs.id, match_score(osm_objs.tags, ups_objs.tags, 'name', 100, 500, osm_objs.geom, ups_objs.geometry)
	) as q
 	UNION ALL
 	SELECT
 		ARRAY[]::bigint[] AS upstream_item_ids, NULL AS upstream_tags, NULL AS upstream_geom,
 		osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags
 	FROM osm_objs
 	LEFT OUTER JOIN ups_objs ON match_condition(osm_objs.tags, ups_objs.tags, 'name', 100, 500, osm_objs.geom, ups_objs.geometry)
 	WHERE ups_objs.id IS NULL;
CREATE MATERIALIZED VIEW upstream.mv_match_preschools_scb AS SELECT * FROM upstream.v_match_preschools_scb;
ALTER TABLE upstream.mv_match_preschools_scb OWNER TO app;

CREATE OR REPLACE VIEW upstream.v_deviation_preschools_scb AS
	SELECT
		110 AS dataset_id,
		15 AS layer_id,
		upstream_item_ids,
		CASE
			WHEN osm_element_id IS NULL THEN upstream_geom
			ELSE NULL::geometry
		END AS suggested_geom,
		tag_diff(osm_tags, upstream_tags) AS suggested_tags,
		osm_element_id,
		osm_element_type,
		CASE
			WHEN osm_element_id IS NULL THEN 'Förskola saknas'::text
			WHEN ARRAY_LENGTH(upstream_item_ids, 1) IS NULL THEN 'Förskola möjligen stängd'::text
			ELSE 'Förskola saknar taggar'::text
		END AS title,
		CASE
			WHEN osm_element_id IS NULL THEN 'Enligt SCBs register ska det finnas en förskola här'::text
			WHEN ARRAY_LENGTH(upstream_item_ids, 1) IS NULL THEN 'Enligt SCBs register finns det ingen förskola här, den kan vara stängd'::text
			ELSE 'Följande taggar, härledda ur från SCBs register, saknas på förskolan här'::text
		END AS description,
		 '' AS note
	FROM upstream.v_match_preschools_scb
	WHERE osm_tags IS NULL OR upstream_tags IS NULL OR tag_diff(osm_tags, upstream_tags) <> '{}'::jsonb;

GRANT SELECT ON TABLE upstream.v_match_preschools_scb TO app;
GRANT SELECT ON TABLE upstream.v_deviation_preschools_scb TO app;
