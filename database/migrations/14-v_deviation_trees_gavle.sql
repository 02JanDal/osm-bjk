CREATE OR REPLACE VIEW upstream.v_deviation_trees_gavle AS
 WITH gavle AS (
         SELECT municipality.geom
           FROM api.municipality
          WHERE municipality.code = '2180'
        ), osm_trees AS (
         SELECT element.id,
            element.type,
            element.tags,
            element.geom
           FROM osm.element
          WHERE element.tags->>'natural' = 'tree' AND ST_Within(element.geom, (SELECT gavle.geom FROM gavle))
            AND element.type = 'n'::osm.element_type
        ), gavle_trees AS (
         SELECT item.id,
            item.geometry,
            (jsonb_build_object('natural', 'tree') ||
                CASE
                    WHEN item.original_attributes->>'SLAKTE' = 'Acer' AND item.original_attributes->>'NAME' = 'Acer campestre' THEN jsonb_build_object('genus', 'Acer', 'species', 'Acer campestre', 'species:wikidata', 'Q158785')
                    WHEN item.original_attributes->>'SLAKTE' = 'Acer' AND item.original_attributes->>'NAME' ~~ 'Acer tataricum%' THEN jsonb_build_object('genus', 'Acer', 'species', 'Acer tataricum', 'species:wikidata', 'Q162728')
                    WHEN item.original_attributes->>'SLAKTE' = 'Acer' THEN jsonb_build_object('genus', 'Acer', 'genus:wikidata', 'Q42292')
                    WHEN item.original_attributes->>'SLAKTE' = 'Malus' THEN jsonb_build_object('genus', 'Malus', 'genus:wikidata', 'Q104819')
                    WHEN item.original_attributes->>'SLAKTE' = 'Pinus' THEN jsonb_build_object('genus', 'Pinus', 'genus:wikidata', 'Q12024')
                    WHEN item.original_attributes->>'SLAKTE' = 'Sorbus' THEN jsonb_build_object('genus', 'Sorbus', 'genus:wikidata', 'Q157964')
                    WHEN item.original_attributes->>'SLAKTE' = 'Tilia' AND item.original_attributes->>'NAMN' = 'Tilius cordata' THEN jsonb_build_object('genus', 'Tilia', 'species', 'Tilia cordata', 'species:wikidata', 'Q158746')
                    WHEN item.original_attributes->>'SLAKTE' = 'Tilia' AND item.original_attributes->>'NAMN' = 'Tilius platyphyllos' THEN jsonb_build_object('genus', 'Tilia', 'species', 'Tilia platyphyllos', 'species:wikidata', 'Q156831')
                    WHEN item.original_attributes->>'SLAKTE' = 'Tilia' AND item.original_attributes->>'NAMN' = 'Tilius tomentosa' THEN jsonb_build_object('genus', 'Tilia', 'species', 'Tilia tomentosa', 'species:wikidata', 'Q161382')
                    WHEN item.original_attributes->>'SLAKTE' = 'Tilia' AND item.original_attributes->>'NAMN' ~~ 'Tilius x europaea%' THEN jsonb_build_object('genus', 'Tilia', 'species', 'Tilia x europaea', 'species:wikidata', 'Q163760')
                    WHEN item.original_attributes->>'SLAKTE' = 'Tilia' THEN jsonb_build_object('genus', 'Tilia', 'genus:wikidata', 'Q127849')
                    WHEN item.original_attributes->>'SLAKTE' = 'Ulmus' THEN jsonb_build_object('genus', 'Ulmus', 'genus:wikidata', 'Q131113')
                    ELSE jsonb_build_object()
                END) AS tags
           FROM upstream.item
          WHERE (item.dataset_id = 5)
        )
 SELECT 5 AS dataset_id,
    16 AS layer_id,
    ARRAY[gavle_trees.id] AS upstream_item_ids,
    CASE
        WHEN (osm_trees.id IS NULL) THEN gavle_trees.geometry
        ELSE NULL::GEOMETRY
    END AS suggested_geom,
    public.tag_diff(osm_trees.tags, gavle_trees.tags) AS suggested_tags,
    osm_trees.id AS osm_element_id,
    osm_trees.type AS osm_element_type,
    CASE
        WHEN osm_trees.id IS NULL THEN 'Träd saknas'
        ELSE 'Träd saknar taggar'
    END AS title,
    CASE
        WHEN osm_trees.id IS NULL THEN 'Enligt Gävle kommuns lista över trädskötsel ska det finnas ett träd här'
        ELSE 'Följande taggar, härledda ur Gävle kommuns lista över trädskötsel, saknas'
    END AS description,
    '' AS note
   FROM gavle_trees
     LEFT JOIN osm_trees ON ST_DWithin(gavle_trees.geometry, osm_trees.geom, 5)
  WHERE osm_trees.tags IS NULL OR NOT (osm_trees.tags @> gavle_trees.tags);

GRANT SELECT ON TABLE upstream.v_deviation_trees_gavle TO app;
