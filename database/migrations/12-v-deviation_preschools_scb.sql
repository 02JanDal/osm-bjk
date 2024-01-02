CREATE OR REPLACE VIEW upstream.v_deviation_preschools_scb AS
 SELECT 110 AS dataset_id,
    15 AS layer_id,
    ARRAY[i.id] AS upstream_item_ids,
    CASE
        WHEN (p.id IS NULL) THEN i.geometry
        ELSE NULL::GEOMETRY
    END AS suggested_geom,
    public.tag_diff(COALESCE(p.tags, '{}'::jsonb), jsonb_build_object('amenity', 'kindergarten', 'name', public.fix_name((i.original_attributes->>'Firmabenämning')), 'operator', public.fix_name((i.original_attributes->>'Företagsnamn')))) AS suggested_tags,
    p.id AS osm_element_id,
    p.type AS osm_element_type,
    CASE
        WHEN (p.id IS NULL) THEN 'Förskola saknas'
        ELSE 'Förskola saknar tagg'
    END AS title,
    CASE
        WHEN (p.id IS NULL) THEN 'Enligt SCBs register över förskolor ska det finnas en förskola här'
        ELSE 'Förskola i OSM saknar vissa taggar vars värde kan fås ur SCBs register över förskolor'
    END AS description,
    '' AS note
   FROM (( SELECT id,
            dataset_id,
            url,
            original_id,
            geometry,
            original_attributes,
            updated_at AS fetched_at
           FROM upstream.item
          WHERE (dataset_id = 110)) i
     LEFT JOIN ( SELECT type,
            id,
            tags,
            geom
           FROM osm.element
          WHERE (((tags->>'amenity') = ANY (ARRAY['kindergarten', 'childcare'])) AND (type = ANY (ARRAY['n'::osm.element_type, 'a'::osm.element_type])))) p ON (ST_DWithin(p.geom, i.geometry, 100)))
  WHERE ((p.id IS NULL) OR (LOWER((p.tags->>'name')) <> LOWER((i.original_attributes->>'Firmabenämning'))) OR (LOWER((p.tags->>'operator')) <> LOWER((i.original_attributes->>'Företagsnamn'))))
UNION ALL
 SELECT 110 AS dataset_id,
    15 AS layer_id,
    ARRAY[]::BIGINT[] AS upstream_item_ids,
    NULL::GEOMETRY AS suggested_geom,
    NULL::JSONB AS suggested_tags,
    element.id AS osm_element_id,
    element.type AS osm_element_type,
    'Möjligen stängd förskola' AS title,
    'Enligt SCBs register över förskolor finns det ingen förskola här' AS description,
    '' AS note
   FROM osm.element
  WHERE (((element.tags->>'amenity') = ANY (ARRAY['kindergarten', 'childcare'])) AND (NOT (EXISTS ( SELECT 1
           FROM upstream.item
          WHERE ((item.dataset_id = 110) AND ST_DWithin(element.geom, item.geometry, 500))))) AND (EXISTS ( SELECT 1
           FROM api.municipality
          WHERE ST_Within(element.geom, municipality.geom))));

GRANT SELECT ON TABLE upstream.v_deviation_preschools_scb TO app;
