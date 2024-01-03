CREATE OR REPLACE VIEW upstream.v_deviation_parkmobler_gavle
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
          WHERE element.tags->>'amenity' IN ('bench', 'table') AND st_within(element.geom, ( SELECT gavle.geom
                   FROM gavle))
        ), gavle_objs AS (
         SELECT item.id,
            item.geometry,
			jsonb_build_object(
				'amenity', CASE WHEN item.original_attributes->>'PRODTYP' = 'Bänk' THEN 'bench'
				WHEN item.original_attributes->>'PRODTYP' = 'Bord' THEN 'table' END
			) as tags
           FROM upstream.item
          WHERE item.dataset_id = 7 AND item.original_attributes->>'PRODTYP' IN ('Bänk', 'Bord')
			-- TODO: there's also "Soffa" and "Möbelgrupp", what do they translate to in OSM?
        )
 SELECT 7 AS dataset_id,
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
        WHEN osm_objs.id IS NULL THEN 'Parkmöbel saknas'::text
        ELSE 'Parkmöbel saknar taggar'::text
    END AS title,
    CASE
        WHEN osm_objs.id IS NULL THEN 'Enligt Gävle kommun ska det finnas en parkmöbel här'::text
        ELSE 'Följande taggar, härledda ur Gävle kommuns data, saknas på parkmöbeln här'::text
    END AS description,
     '' AS note
   FROM gavle_objs
     LEFT JOIN osm_objs ON st_dwithin(gavle_objs.geometry, osm_objs.geom, 5::double precision)
  WHERE osm_objs.tags IS NULL OR NOT osm_objs.tags @> gavle_objs.tags;

GRANT SELECT ON TABLE upstream.v_deviation_parkmobler_gavle TO app;
