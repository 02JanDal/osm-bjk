CREATE OR REPLACE VIEW upstream.v_deviation_lifesaving_gavle
 AS
 WITH gavle AS (
         SELECT municipality.geom
           FROM api.municipality
          WHERE municipality.code = '2180'
        ), osm_objs AS (
         SELECT element.id,
            element.type,
            element.tags,
            element.geom
           FROM osm.element
          WHERE string_to_array(element.tags->>'emergency', ';') && ARRAY['life_ring', 'rescue_boat', 'rescue_ladder'] AND st_within(element.geom, ( SELECT gavle.geom
                   FROM gavle)) AND element.type = 'n'::osm.element_type
        ), gavle_objs AS (
         SELECT item.id,
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
 SELECT 8 AS dataset_id,
    16 AS layer_id,
    ARRAY[gavle_objs.id] AS upstream_item_ids,
    CASE
        WHEN osm_objs.id IS NULL THEN gavle_objs.geometry
        ELSE NULL::geometry
    END AS suggested_geom,
    tag_diff(osm_objs.tags, gavle_objs.tags) AS suggested_tags,
    osm_objs.id AS osm_element_id,
    osm_objs.type AS osm_element_type,
    CASE
        WHEN osm_objs.id IS NULL THEN 'Livräddningsutrustning saknas'::text
        ELSE 'Livräddningsutrustning saknar taggar'::text
    END AS title,
    CASE
        WHEN osm_objs.id IS NULL THEN 'Enligt Gävle kommun ska det finnas livräddningsutrustning här'::text
        ELSE 'Följande taggar, härledda ur från Gävle kommuns data, saknas på livräddningsutrustning här'::text
    END AS description,
     '' AS note
   FROM gavle_objs
     LEFT JOIN osm_objs ON st_dwithin(gavle_objs.geometry, osm_objs.geom, 5::double precision)
  WHERE osm_objs.tags IS NULL OR NOT osm_objs.tags @> gavle_objs.tags;

GRANT SELECT ON TABLE upstream.v_deviation_lifesaving_gavle TO app;
