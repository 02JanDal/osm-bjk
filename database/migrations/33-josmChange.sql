CREATE OR REPLACE FUNCTION api.josmchange(
	dataset_ids integer[] DEFAULT NULL::integer[],
	municipalities character[] DEFAULT NULL::bpchar[],
	layer_ids integer[] DEFAULT NULL::integer[],
	titles text[] DEFAULT NULL::text[])
    RETURNS "text/xml"
    LANGUAGE 'plpgsql'
    COST 100
    STABLE SECURITY DEFINER PARALLEL SAFE
AS $BODY$
DECLARE
	extent box2d;
BEGIN
    --PERFORM SET_CONFIG('response.headers', '[{"Content-Type": "text/xml"}, {"Content-Disposition": "attachment;filename=\"deviations.osm\""}]', TRUE);
	SELECT ST_Extent(ST_Transform(center, 4326)) INTO extent FROM public.filtered_deviations(dataset_ids, municipalities, layer_ids, titles);
    RETURN XMLELEMENT(
            NAME "osm",
            XMLATTRIBUTES(
				'0.6' AS "version",
				'BästaJävlaKartan' AS "generator",
				'false' AS "upload"
			),
			XMLELEMENT(
				NAME "bounds",
				XMLATTRIBUTES(
					ST_XMin(extent) AS "minlon",
					ST_XMax(extent) AS "maxlon",
					ST_YMin(extent) AS "minlat",
					ST_YMin(extent) AS "maxlat",
					'BästaJävlaKartan' AS "origin"
				)
			),
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
                ,
                    (SELECT XMLAGG(CASE
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'node'
                                           THEN XMLELEMENT(
                                               NAME "node",
                                               XMLATTRIBUTES(
												   osm.real_element_id(osm_element_type, osm_element_id) AS "id",
												   (SELECT (meta).version FROM osm.node WHERE node.id = osm_element_id) AS "version",
												   'modify' AS "action"
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
												   (SELECT (meta).version FROM osm.way WHERE way.id = osm.real_element_id(osm_element_type, osm_element_id)) AS "version",
												   'modify' AS "action"
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
												   (SELECT (meta).version FROM osm.relation WHERE relation.id = osm.real_element_id(osm_element_type, osm_element_id)) AS "version",
												   'modify' AS "action"
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
                ,
                    (SELECT XMLAGG(CASE
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'node'
                                           THEN XMLELEMENT(
                                               NAME "node",
                                               XMLATTRIBUTES(osm.real_element_id(osm_element_type, osm_element_id) AS
                                               "id", 'delete' AS "action")
                                           )
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'way'
                                           THEN XMLELEMENT(
                                               NAME "way",
                                               XMLATTRIBUTES(osm.real_element_id(osm_element_type, osm_element_id) AS
                                               "id", 'delete' AS "action")
                                           )
                                       WHEN osm.real_element_type(osm_element_type, osm_element_id) = 'relation'
                                           THEN XMLELEMENT(
                                               NAME "relation",
                                               XMLATTRIBUTES(osm.real_element_id(osm_element_type, osm_element_id) AS
                                               "id", 'delete' AS "action")
                                           ) END)
                     FROM public.filtered_deviations(dataset_ids, municipalities, layer_ids, titles)
                     WHERE osm_element_id IS NOT NULL
                       AND (suggested_geom IS NOT NULL AND suggested_tags IS NOT NULL))

        );
END;
$BODY$;

REVOKE ALL ON FUNCTION api.josmchange(dataset_ids INTEGER[], municipalities CHAR(4)[0], layer_ids INTEGER[], titles TEXT[]) FROM PUBLIC;
GRANT ALL ON FUNCTION api.josmchange(dataset_ids INTEGER[], municipalities CHAR(4)[0], layer_ids INTEGER[], titles TEXT[]) TO web_anon;
GRANT ALL ON FUNCTION api.josmchange(dataset_ids INTEGER[], municipalities CHAR(4)[0], layer_ids INTEGER[], titles TEXT[]) TO web_auth;
