CREATE OR REPLACE VIEW upstream.v_deviation_atervinning_gavle
 AS
 WITH gavle AS (
         SELECT municipality.geom
           FROM api.municipality
          WHERE municipality.code = '2180'
        ), osm_objs_centre AS (
         SELECT element.id,
            element.type,
            element.tags,
            element.geom
           FROM osm.element
          WHERE element.tags->>'recycling_type' IN ('centre') AND st_within(element.geom, ( SELECT gavle.geom
                   FROM gavle))
        ), osm_objs_container AS (
         SELECT element.id,
            element.type,
            element.tags,
            element.geom
           FROM osm.element
          WHERE element.tags->>'recycling_type' IN ('container') AND st_within(element.geom, ( SELECT gavle.geom
                   FROM gavle))
        ), gavle_objs_centre AS (
         SELECT item.id,
            item.geometry,
			jsonb_strip_nulls(jsonb_build_object(
				'amenity', 'recycling',
				'recycling_type', 'centre',
				'name', item.original_attributes->>'NAMN',
				'addr:street', TRIM(REGEXP_SUBSTR(item.original_attributes->>'GATUADRESS', '[^,0-9]+')),
				'addr:housenumber', TRIM(REGEXP_SUBSTR(item.original_attributes->>'GATUADRESS', '[0-9]+[^,]*')),
				'addr:city', TRIM((REGEXP_MATCH(item.original_attributes->>'GATUADRESS', ', (.*)'))[1])
			)) as tags
           FROM upstream.item
          WHERE item.dataset_id = 17 AND item.original_attributes->>'KATEGORI' = 'ÅTERVINNINGSCENTRAL'
        ), gavle_objs_container AS (
         SELECT             item.geometry,
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
 SELECT 17 AS dataset_id,
    13 AS layer_id,
    gavle_objs_centre.id AS upstream_item_id,
        CASE
            WHEN osm_objs_centre.id IS NULL THEN gavle_objs_centre.geometry
            ELSE NULL::geometry
        END AS suggested_geom,
    osm_objs_centre.id AS osm_element_id,
    osm_objs_centre.type AS osm_element_type,
    tag_diff(osm_objs_centre.tags, gavle_objs_centre.tags) AS suggested_tags,
        CASE
            WHEN osm_objs_centre.id IS NULL THEN 'Återvinningsstation saknas'::text
            ELSE 'Återvinningsstation saknar taggar'::text
        END AS title,
        CASE
            WHEN osm_objs_centre.id IS NULL THEN 'Enligt Gävle kommun ska det finnas en återvinningsstation här'::text
            ELSE 'Följande taggar, härledda ur från Gävle kommuns data, saknas på återvinningsstationen här'::text
        END AS description,
		'' AS note
   FROM gavle_objs_centre
     LEFT JOIN osm_objs_centre ON st_dwithin(gavle_objs_centre.geometry, osm_objs_centre.geom, 500::double precision)
  WHERE osm_objs_centre.tags IS NULL OR NOT osm_objs_centre.tags @> gavle_objs_centre.tags
  UNION ALL
   SELECT 17 AS dataset_id,
    13 AS layer_id,
    null AS upstream_item_id,
    CASE
        WHEN osm_objs_container.id IS NULL THEN gavle_objs_container.geometry
        ELSE NULL::geometry
    END AS suggested_geom,
    tag_diff(osm_objs_container.tags, gavle_objs_container.tags) AS suggested_tags,
    osm_objs_container.id AS osm_element_id,
    osm_objs_container.type AS osm_element_type,
    CASE
        WHEN osm_objs_container.id IS NULL THEN 'Återvinningscentral saknas'::text
        ELSE 'Återvinningscentral saknar taggar'::text
    END AS title,
    CASE
        WHEN osm_objs_container.id IS NULL THEN 'Enligt Gävle kommun ska det finnas en återvinningscentral här'::text
        ELSE 'Följande taggar, härledda ur från Gävle kommuns data, saknas på återvinningscentralen här'::text
    END AS description,
    gavle_objs_container.note AS note
   FROM gavle_objs_container
     LEFT JOIN osm_objs_container ON st_dwithin(gavle_objs_container.geometry, osm_objs_container.geom, 500::double precision)
  WHERE osm_objs_container.tags IS NULL OR NOT osm_objs_container.tags @> gavle_objs_container.tags
  ;

GRANT SELECT ON TABLE upstream.v_deviation_atervinning_gavle TO app;
