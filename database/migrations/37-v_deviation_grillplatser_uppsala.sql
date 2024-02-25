CREATE OR REPLACE VIEW upstream.v_match_grillplatser_uppsala AS
    WITH uppsala AS (
        SELECT municipality.geom FROM api.municipality WHERE municipality.code = '0380'
    ), osm_objs AS (
        SELECT id, type, tags, geom FROM osm.element
        WHERE (element.tags->>'amenity' = 'bbq' OR element.tags->>'leisure' = 'firepit')
                  AND ST_Within(geom, (SELECT uppsala.geom FROM uppsala)) AND type = 'n'
    ), ups_objs AS (
     SELECT ARRAY[item.id] AS id,
        item.geometry,
        tag_alternatives(
                        ARRAY[jsonb_build_object('amenity', 'bbq'), jsonb_build_object('leisure', 'firepit')],
                        jsonb_strip_nulls(jsonb_build_object(
                                'wood_provided', CASE WHEN item.original_attributes->>'Kommentar'::text ~ 'Ved finns\.' THEN 'yes'
                                                      WHEN item.original_attributes->>'Kommentar'::text ~ 'Ved finns inte\.' THEN 'no'
                                                      ELSE NULL
                                                 END
                        ))
                ) as tags,
                item.original_attributes->>'Kommentar'::text as comment
       FROM upstream.item
      WHERE item.dataset_id = 466
    )
    SELECT DISTINCT ON (ups_objs.id)
        ups_objs.id AS upstream_item_ids, ups_objs.tags AS upstream_tags, ups_objs.geometry AS upstream_geom,
        osm_objs.id AS osm_element_id, osm_objs.type AS osm_element_type, osm_objs.tags AS osm_tags,
                ups_objs.comment AS upstream_comment
    FROM ups_objs
    LEFT OUTER JOIN osm_objs ON match_condition(25, osm_objs.geom, ups_objs.geometry)
    ORDER BY ups_objs.id, match_score(25, osm_objs.geom, ups_objs.geometry);

DROP MATERIALIZED VIEW IF EXISTS upstream.mv_match_grillplatser_uppsala CASCADE;
CREATE MATERIALIZED VIEW upstream.mv_match_grillplatser_uppsala AS SELECT * FROM upstream.v_match_grillplatser_uppsala;
ALTER TABLE upstream.mv_match_grillplatser_uppsala OWNER TO app;

CREATE OR REPLACE VIEW upstream.v_deviation_grillplatser_uppsala AS
    SELECT *
    FROM (SELECT DISTINCT ON (match_id)
     466::bigint AS dataset_id,
     18::bigint AS layer_id,
     upstream_item_ids,
     CASE
         WHEN osm_element_id IS NULL THEN upstream_geom
         ELSE NULL::geometry
     END AS suggested_geom,
     tag_diff(osm_tags, ups_tags) AS suggested_tags,
     osm_element_id,
     osm_element_type,
     CASE
         WHEN osm_element_id IS NULL THEN 'Grillplats saknas'::text
         ELSE 'Grillplats saknar taggar'::text
     END AS title,
     CASE
         WHEN osm_element_id IS NULL THEN 'Enligt Uppsala kommun ska det finnas en grillplats här'::text
         ELSE 'Följande taggar, härledda ur från Uppsala kommuns data, saknas på grillplatsen här'::text
     END AS description,
     CASE WHEN upstream_comment IS NOT NULL THEN 'Kommentar från Uppsala kommun: ' || upstream_comment
                  ELSE ''
             END AS note
           FROM (SELECT ROW_NUMBER() OVER () AS match_id, * FROM upstream.mv_match_grillplatser_uppsala) sub
           LEFT JOIN LATERAL jsonb_array_elements(upstream_tags) ups_tags ON true
           ORDER BY match_id, count_jsonb_keys(tag_diff(osm_tags, ups_tags)) ASC
    ) sub
    WHERE osm_element_id IS NULL OR suggested_tags <> '{}'::jsonb;

CREATE OR REPLACE FUNCTION api.tile_match_grillplatser_uppsala(z integer, x integer, y integer)
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
            FROM upstream.mv_match_grillplatser_uppsala items
            LEFT OUTER JOIN osm.element ON items.osm_element_id = element.id AND items.osm_element_type = element.type
            INNER JOIN bounds ON ST_Intersects(items.upstream_geom, ST_Transform(bounds.geom, 3006)) OR (element.id IS NOT NULL AND ST_Intersects(element.geom, ST_Transform(bounds.geom, 3006)))
        )
        SELECT ST_AsMVT(mvtgeom, 'default')
        FROM mvtgeom;
$$;
