CREATE OR REPLACE VIEW upstream.v_deviation_schools_skolverket AS
 WITH with_ref AS (
         SELECT element.type,
            element.id,
            element.tags,
            element.geom,
            element.node_id,
            element.way_id,
            element.relation_id
           FROM osm.element
          WHERE (((element.tags->>'amenity') = 'school') AND (element.tags ? 'ref:se:skolverket') AND ((element.tags->>'ref:se:skolverket') IS NOT NULL) AND (element.type = ANY (ARRAY['n'::osm.element_type, 'a'::osm.element_type])))
        ), schools AS NOT MATERIALIZED (
         SELECT element.type,
            element.id,
            element.tags,
            element.geom,
            element.node_id,
            element.way_id,
            element.relation_id
           FROM osm.element
          WHERE (((element.tags->>'amenity') = 'school') AND (EXISTS ( SELECT 1
                   FROM api.municipality
                  WHERE ST_Within(ST_MakeValid(element.geom), municipality.geom))) AND (element.type = ANY (ARRAY['n'::osm.element_type, 'a'::osm.element_type])))
        ), ups AS NOT MATERIALIZED (
         SELECT item.geometry,
            item.id,
            (jsonb_build_object('amenity', 'school', 'name', (item.original_attributes->'SkolaNamn'), 'operator', public.fix_name((item.original_attributes->'Huvudman'->>'Namn')), 'operator:type',
                CASE
                    WHEN ((item.original_attributes->'Huvudman'->>'Typ') = ANY (ARRAY['Kommun'::text, 'Region'::text, 'Stat'::text])) THEN 'government'::text
                    WHEN (((item.original_attributes->'Huvudman'->>'Namn') ~~* '%förening%') OR ((item.original_attributes->'Huvudman'->>'Namn') ~~* '%ek för%')) THEN 'cooperative'
                    WHEN ((item.original_attributes->'Huvudman'->>'Namn') ~~* '%stiftelse%') THEN 'ngo'
                    ELSE 'private'
                END,
                'ref:se:skolverket', item.original_attributes->>'Skolenhetskod',
                'addr:housenumber', SUBSTRING((item.original_attributes->'Besoksadress'->>'Adress'), '[0-9]+.*$'),
                'addr:street', SUBSTRING((item.original_attributes->'Besoksadress'->>'Adress'), '^[^0-9]+'),
                'addr:city', item.original_attributes->'Besoksadress'->>'Ort',
                'addr:postcode', item.original_attributes->'Besoksadress'->>'Postnr',
                'contact:website', item.original_attributes->'Webbadress',
                'contact:phone', item.original_attributes->'Telefon',
                'contact:email', item.original_attributes->'Epost') ||
                CASE
                    WHEN item.original_attributes->>'Inriktningstyp' = 'Waldorf' THEN jsonb_build_object('pedagogy', 'waldorf')
                    ELSE '{}'::jsonb
                END) AS tags,
            item.original_attributes
           FROM upstream.item
          WHERE item.dataset_id = 109 AND item.original_attributes->>'Status' = 'Aktiv'
        ), matched AS NOT MATERIALIZED (
         SELECT DISTINCT ON (ups.id) ups.id,
            ups.tags AS ups_tags,
            COALESCE(with_ref.tags, schools.tags) AS osm_tags,
            ups.geometry,
            COALESCE(with_ref.id, schools.id) AS osm_id,
            COALESCE(with_ref.type, schools.type) AS osm_type
           FROM ups
             LEFT JOIN with_ref ON with_ref.tags->>'ref:se:skolverket' = ups.tags->>'ref:se:skolverket'
             LEFT JOIN schools ON ST_DWithin(ups.geometry, schools.geom, 250)
          WHERE with_ref.tags IS NOT NULL OR schools.tags IS NOT NULL
          ORDER BY ups.id, with_ref.id, (ST_Distance(ups.geometry, schools.geom)), COALESCE(with_ref.id, schools.id), COALESCE(with_ref.type, schools.type)
        )
 SELECT 109 AS dataset_id,
    5 AS layer_id,
    q.upstream_item_id,
    q.suggested_geom,
    q.osm_element_id,
    q.osm_element_type,
    q.suggested_tags,
    q.title,
    q.description
   FROM ( SELECT matched.id AS upstream_item_id,
                CASE
                    WHEN matched.osm_id IS NULL THEN matched.geometry
                    ELSE NULL::GEOMETRY
                END AS suggested_geom,
            matched.osm_id AS osm_element_id,
            matched.osm_type AS osm_element_type,
            public.tag_diff(matched.osm_tags, matched.ups_tags) AS suggested_tags,
                CASE
                    WHEN matched.osm_id IS NULL THEN 'Skola saknas'
                    ELSE 'Skola saknar taggar'
                END AS title,
                CASE
                    WHEN matched.osm_id IS NULL THEN 'Enligt skolverkets register ska det finnas en skola här'
                    ELSE 'Följande taggar som går att härleda ur skolverkets register saknas eller är avvikande på OSM-objektet'
                END AS description
           FROM matched
          WHERE ((public.tag_diff(matched.osm_tags, matched.ups_tags - 'operator' - 'name') <> '{}'::jsonb) OR (lower(matched.osm_tags->>'name') <> lower(matched.ups_tags->>'name')) OR (lower(matched.osm_tags->>'operator') <> lower(matched.ups_tags->>'operator')))
        UNION ALL
         SELECT NULL::BIGINT AS upstream_item_id,
            NULL::GEOMETRY AS suggested_geom,
            schools.id AS osm_element_id,
            schools.type AS osm_element_type,
            NULL::JSONB AS suggested_tags,
            'Möjligen stängd skola' AS title,
            'Enligt Skolverkets register ska det inte finnas någon skola här. Den kan ha blivit nedlagd.' AS description
           FROM schools
             LEFT JOIN matched ON matched.osm_id = schools.id AND matched.osm_type = schools.type
          WHERE (matched.osm_id IS NULL)) q;

GRANT SELECT ON TABLE upstream.v_deviation_schools_skolverket TO app;
