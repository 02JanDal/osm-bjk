CREATE OR REPLACE FUNCTION api.gpx(deviation_id BIGINT) RETURNS XML
    LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER PARALLEL SAFE
    AS $_$
DECLARE
   geom GEOMETRY;
   title TEXT;
   description TEXT;
   suggested_tags TEXT;
   upstream_item_ids BIGINT[];
   original_attributes TEXT;
   fetched_at TIMESTAMPTZ;
BEGIN
	PERFORM set_config('response.headers', '[{"Content-Type": "application/gpx+xml"}]', true);
	SELECT ST_Transform(suggested_geom, 4326) INTO geom FROM api.deviation WHERE id = $1;
	SELECT deviation.title INTO title FROM api.deviation WHERE id = $1;
	SELECT deviation.description INTO description FROM api.deviation WHERE id = $1;
	SELECT STRING_AGG(a.key || '=' || a.value, '  -  ') INTO suggested_tags FROM api.deviation, jsonb_each_text(deviation.suggested_tags) as a WHERE id = $1;
	SELECT deviation.upstream_item_ids INTO upstream_item_ids FROM api.deviation WHERE id = $1;
	SELECT MIN(item.fetched_at) INTO fetched_at FROM upstream.item WHERE id = ANY(upstream_item_ids);
	SELECT STRING_AGG(a.key || '=' || a.value, '  -  ') INTO original_attributes FROM upstream.item, jsonb_each_text(item.original_attributes) as a WHERE id = ANY(upstream_item_ids);

	RETURN XMLELEMENT(
    	NAME "gpx",
		XMLATTRIBUTES('http://www.topografix.com/GPX/1/1' AS "xmlns",
					  'http://www.w3.org/2001/XMLSchema-instance' AS "xmlns:xsi",
					  'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd' AS "xsi:schemaLocation",
					  '1.1' AS "version",
					  'osm.jandal.se' AS "creator"),
  		CASE
		WHEN ST_GeometryType(geom) = 'ST_Point' THEN XMLELEMENT(
			NAME "wpt",
			XMLATTRIBUTES(ST_Y(geom) AS "lat", ST_X(geom) AS "lon"),
			XMLELEMENT(NAME "desc", title),
			XMLELEMENT(NAME "name", description),
			XMLELEMENT(NAME "time", fetched_at),
			XMLELEMENT(NAME "keywords", suggested_tags),
			XMLELEMENT(NAME "cmt", original_attributes)
			)
	  	WHEN ST_GeometryType(geom) IN ('ST_LineString', 'ST_Polygon', 'ST_MultiPolygon') THEN XMLELEMENT(
			NAME "trk",
			XMLELEMENT(NAME "desc", title),
			XMLELEMENT(NAME "name", description),
			XMLELEMENT(NAME "time", fetched_at),
			XMLELEMENT(NAME "keywords", suggested_tags),
			XMLELEMENT(NAME "cmt", original_attributes),
			XMLELEMENT(NAME "trkseg", (SELECT XMLAGG(
				XMLELEMENT(NAME "trkpt", XMLATTRIBUTES(ST_Y(a.geom) AS "lat", ST_X(a.geom) AS "lon"))
			) FROM ST_DumpPoints(geom) AS a))
			)
		ELSE null
	  END
 );
END;
$_$;

REVOKE ALL ON FUNCTION api.gpx(deviation_id BIGINT) FROM PUBLIC;
GRANT ALL ON FUNCTION api.gpx(deviation_id BIGINT) TO web_anon;
GRANT ALL ON FUNCTION api.gpx(deviation_id BIGINT) TO web_auth;
