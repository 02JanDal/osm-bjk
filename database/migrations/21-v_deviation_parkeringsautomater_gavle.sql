CREATE OR REPLACE VIEW upstream.v_deviation_parkeringsautomater_gavle
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
          WHERE element.tags->>'amenity' = 'vending_machine' AND element.tags->>'vending' = 'parking_tickets' AND st_within(element.geom, ( SELECT gavle.geom
                   FROM gavle))
        ), gavle_objs AS (
         SELECT item.id,
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
 SELECT 33 AS dataset_id,
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
        WHEN osm_objs.id IS NULL THEN 'Parkeringsautomat saknas'::text
        ELSE 'Parkeringsautomat saknar taggar'::text
    END AS title,
    CASE
        WHEN osm_objs.id IS NULL THEN 'Enligt Gävle kommun ska det finnas en parkeringsautomat här'::text
        ELSE 'Följande taggar, härledda ur Gävle kommuns data, saknas på parkeringsautomaten här'::text
    END AS description,
     '' AS note
   FROM gavle_objs
     LEFT JOIN osm_objs ON st_dwithin(gavle_objs.geometry, osm_objs.geom, 50::double precision)
  WHERE osm_objs.tags IS NULL OR NOT osm_objs.tags @> gavle_objs.tags;

GRANT SELECT ON TABLE upstream.v_deviation_parkeringsautomater_gavle TO app;
