CREATE OR REPLACE FUNCTION public.filtered_deviations(
	dataset_ids integer[] DEFAULT NULL::integer[],
	municipalities character[] DEFAULT NULL::bpchar[],
	layer_ids integer[] DEFAULT NULL::integer[],
	titles text[] DEFAULT NULL::text[])
    RETURNS TABLE(id integer, layer_id integer, dataset_id integer, osm_element_id bigint, suggested_geom geometry, suggested_tags jsonb, title text, description text, osm_element_type osm.element_type, center geometry, municipality_code character, action api.action_type, action_at timestamp with time zone, note text, view_name text, upstream_item_ids bigint[], index integer)
    LANGUAGE 'sql'
    COST 100
    STABLE PARALLEL SAFE
    ROWS 1000

AS $BODY$
SELECT *, ROW_NUMBER() OVER () AS index
FROM api.deviation
WHERE (dataset_ids IS NULL OR dataset_id = ANY (dataset_ids))
AND (municipalities IS NULL OR municipality_code = ANY (municipalities))
AND (layer_ids IS NULL OR layer_id = ANY (layer_ids))
AND (titles IS NULL OR deviation.title = ANY (titles))
LIMIT 1000
$BODY$;

CREATE OR REPLACE FUNCTION api.osmchange(
	dataset_ids integer[] DEFAULT NULL::integer[],
	municipalities character[] DEFAULT NULL::bpchar[],
	layer_ids integer[] DEFAULT NULL::integer[],
	titles text[] DEFAULT NULL::text[])
    RETURNS "text/xml"
    LANGUAGE 'plpgsql'
    COST 100
    STABLE SECURITY DEFINER PARALLEL SAFE
AS $BODY$
BEGIN
    PERFORM SET_CONFIG('response.headers', '[{"Content-Type": "text/xml"}, {"Content-Disposition": "attachment;filename=\"deviations.osc\""}]', TRUE);
    RETURN XMLELEMENT(
            NAME "osmChange",
            XMLATTRIBUTES('0.6' AS "version",
            'BästaJävlaKartan' AS "generator"),
            XMLELEMENT(
                    NAME "create",
                    (SELECT XMLAGG(CASE
                                       WHEN st_geometrytype(suggested_geom) = 'ST_Point' THEN XMLELEMENT(
                                               NAME "node",
                                               XMLATTRIBUTES(
                                               -index AS "id",
                                               0 AS "version",
                                               st_x(st_transform(suggested_geom, 4326)) AS "lon",
                                               st_y(st_transform(suggested_geom, 4326)) AS "lat"
                                           ),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH(suggested_tags))
                                           )
                                       WHEN st_geometrytype(suggested_geom) = 'ST_LineString' THEN XMLELEMENT(
                                               NAME "way",
                                               XMLATTRIBUTES(
                                               -1 AS "id",
                                               0 AS "version"
                                           ),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH(suggested_tags))
                                           )
                                       WHEN st_geometrytype(suggested_geom) = 'ST_Polygon' THEN XMLELEMENT(
                                               NAME "way",
                                               XMLATTRIBUTES(
                                               -1 AS "id",
                                               0 AS "version"
                                           ),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH(suggested_tags))
                                           )
                                       WHEN st_geometrytype(suggested_geom) = 'ST_MultiPolygon' THEN XMLELEMENT(
                                               NAME "relation",
                                               XMLATTRIBUTES(
                                               -1 AS "id",
                                               0 AS "version"
                                           ),
                                               XMLELEMENT(NAME "tag", XMLATTRIBUTES('type' AS "k", 'multipolygon' AS
                                                          "v")),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH(suggested_tags))
                                           ) END)
                     FROM public.filtered_deviations(dataset_ids, municipalities, layer_ids, titles)
                     WHERE osm_element_id IS NULL
                       AND (st_geometrytype(suggested_geom) = 'ST_Point' AND suggested_tags IS NOT NULL))
                ),
            XMLELEMENT(
                    NAME "modify",
                    (SELECT XMLAGG(CASE
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'node'
                                           THEN XMLELEMENT(
                                               NAME "node",
                                               XMLATTRIBUTES(
												   osm.real_element_id(osm_element_type, osm_element_id) AS "id",
												   (SELECT (meta).version FROM osm.node WHERE node.id = osm_element_id) AS "version"
											   ),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH(suggested_tags)
                                                WHERE JSONB_TYPEOF(value) != 'null'),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH((SELECT tags
                                                                 FROM osm.element
                                                                 WHERE element.id = osm_element_id
                                                                   AND element.type = osm_element_type))
                                                WHERE NOT (suggested_tags ? key))
                                           )
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'way'
                                           THEN XMLELEMENT(
                                               NAME "way",
                                               XMLATTRIBUTES(
												   osm.real_element_id(osm_element_type, osm_element_id) AS "id",
												   (SELECT (meta).version FROM osm.way WHERE way.id = osm.real_element_id(osm_element_type, osm_element_id)) AS "version"
											   ),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH(suggested_tags)
                                                WHERE JSONB_TYPEOF(value) != 'null'),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH((SELECT tags
                                                                 FROM osm.element
                                                                 WHERE element.id = osm_element_id
                                                                   AND element.type = osm_element_type))
                                                WHERE NOT (suggested_tags ? key))
                                           )
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'relation'
                                           THEN XMLELEMENT(
                                               NAME "relation",
                                               XMLATTRIBUTES(
												   osm.real_element_id(osm_element_type, osm_element_id) AS "id",
												   (SELECT (meta).version FROM osm.relation WHERE relation.id = osm.real_element_id(osm_element_type, osm_element_id)) AS "version"
											   ),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH(suggested_tags)
                                                WHERE JSONB_TYPEOF(value) != 'null'),
                                               (SELECT XMLAGG(XMLELEMENT(NAME "tag", XMLATTRIBUTES(key AS "k", value #>> '{}' AS "v")))
                                                FROM JSONB_EACH((SELECT tags
                                                                 FROM osm.element
                                                                 WHERE element.id = osm_element_id
                                                                   AND element.type = osm_element_type))
                                                WHERE NOT (suggested_tags ? key))
                                           ) END)
                     FROM public.filtered_deviations(dataset_ids, municipalities, layer_ids, titles)
                     WHERE osm_element_id IS NOT NULL
                       AND osm_element_type = 'n'
                       AND (st_geometrytype(suggested_geom) = 'ST_Point' OR suggested_tags IS NOT NULL))
                ),
            XMLELEMENT(
                    NAME "delete",
                    XMLATTRIBUTES('true' AS "if-unused"),
                    (SELECT XMLAGG(CASE
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'node'
                                           THEN XMLELEMENT(
                                               NAME "node",
                                               XMLATTRIBUTES(osm.real_element_id(osm_element_type, osm_element_id) AS
                                               "id")
                                           )
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'way'
                                           THEN XMLELEMENT(
                                               NAME "way",
                                               XMLATTRIBUTES(osm.real_element_id(osm_element_type, osm_element_id) AS
                                               "id")
                                           )
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'relation'
                                           THEN XMLELEMENT(
                                               NAME "relation",
                                               XMLATTRIBUTES(osm.real_element_id(osm_element_type, osm_element_id) AS
                                               "id")
                                           ) END)
                     FROM public.filtered_deviations(dataset_ids, municipalities, layer_ids, titles)
                     WHERE osm_element_id IS NOT NULL
                       AND (suggested_geom IS NOT NULL AND suggested_tags IS NOT NULL))
                )
        );
END;
$BODY$;

REVOKE ALL ON FUNCTION api.osmchange(dataset_ids INTEGER[], municipalities CHAR(4)[0], layer_ids INTEGER[], titles TEXT[]) FROM PUBLIC;
GRANT ALL ON FUNCTION api.osmchange(dataset_ids INTEGER[], municipalities CHAR(4)[0], layer_ids INTEGER[], titles TEXT[]) TO web_anon;
GRANT ALL ON FUNCTION api.osmchange(dataset_ids INTEGER[], municipalities CHAR(4)[0], layer_ids INTEGER[], titles TEXT[]) TO web_auth;
