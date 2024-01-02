CREATE OR REPLACE VIEW upstream.v_deviation_badplatser_gavle
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
          WHERE element.tags->>'leisure' IN ('swimming_area', 'bathing_place') AND st_within(element.geom, ( SELECT gavle.geom
                   FROM gavle))
        ), gavle_objs AS (
         SELECT item.id,
            item.geometry,
			jsonb_strip_nulls(jsonb_build_object(
				'leisure', 'bathing_place',
				'name', item.original_attributes->>'NAMN',
				'website', item.original_attributes->>'URL',
				'description:sv', TRIM(REGEXP_REPLACE(item.original_attributes->>'BESKR_KORT', 'Välkommen [^!]+!', '')),
				'addr:street', TRIM(REGEXP_SUBSTR(item.original_attributes->>'GATUADRESS', '[^,0-9]+')),
				'addr:housenumber', TRIM(REGEXP_SUBSTR(item.original_attributes->>'GATUADRESS', '[0-9]+[^,]*')),
				'addr:city', TRIM((REGEXP_MATCH(item.original_attributes->>'GATUADRESS', ', (.*)'))[1])
			)) as tags
           FROM upstream.item
          WHERE item.dataset_id = 4
        )
 SELECT 4 AS dataset_id,
    11 AS layer_id,
    ARRAY[gavle_objs.id] AS upstream_item_ids,
    CASE
        WHEN osm_objs.id IS NULL THEN gavle_objs.geometry
        ELSE NULL::geometry
    END AS suggested_geom,
    tag_diff(osm_objs.tags, gavle_objs.tags) AS suggested_tags,
    osm_objs.id AS osm_element_id,
    osm_objs.type AS osm_element_type,
    CASE
        WHEN osm_objs.id IS NULL THEN 'Badplats saknas'::text
        ELSE 'Badplats saknar taggar'::text
    END AS title,
    CASE
        WHEN osm_objs.id IS NULL THEN 'Enligt Gävle kommun ska det finnas en badplats här'::text
        ELSE 'Följande taggar, härledda ur från Gävle kommuns data, saknas på badplatsen här'::text
    END AS description,
     '' AS note
   FROM gavle_objs
     LEFT JOIN osm_objs ON st_dwithin(gavle_objs.geometry, osm_objs.geom, 500::double precision)
  WHERE osm_objs.tags IS NULL OR NOT osm_objs.tags @> gavle_objs.tags;

GRANT SELECT ON TABLE upstream.v_deviation_badplatser_gavle TO app;
