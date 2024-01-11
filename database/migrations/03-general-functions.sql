create domain "text/xml" as pg_catalog.xml;

CREATE OR REPLACE FUNCTION public.fix_name(original text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$
	SELECT REGEXP_REPLACE(REGEXP_REPLACE(INITCAP(original), '\yKommun\y', 'kommun'), '\yAb\y', 'AB');
$$;
COMMENT ON FUNCTION public.fix_name(original text) IS 'Fix the casing of text';

CREATE OR REPLACE FUNCTION public.tag_diff(in_old jsonb, in_new jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE LEAKPROOF PARALLEL SAFE
    AS $$
SELECT
    COALESCE(JSONB_OBJECT_AGG(new.key, new.value), '{}'::jsonb)
  FROM JSONB_EACH_TEXT(COALESCE(in_new, '{}'::jsonb)) new
  FULL OUTER JOIN JSONB_EACH_TEXT(COALESCE(in_old, '{}'::jsonb)) old ON new.key = old.key
WHERE
  new.value IS DISTINCT FROM old.value AND new.key IS NOT NULL
$$;
COMMENT ON FUNCTION public.tag_diff(in_old jsonb, in_new jsonb) IS 'Result only includes tags that are different or do not exist in in_old';

CREATE OR REPLACE FUNCTION public.match_condition(tags_a jsonb, tags_b jsonb, name_key text, ref_key text,
												  other_distance real, name_distance real, ref_distance real, geom_a geometry, geom_b geometry)
    RETURNS bool
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT (tags_a ? ref_key AND tags_a->>ref_key = tags_b->>ref_key AND ST_DWithin(geom_a, geom_b, ref_distance)) OR (tags_a ? name_key AND LOWER(tags_a->>name_key) = LOWER(tags_b->>name_key) AND ST_DWithin(geom_a, geom_b, name_distance)) OR ST_DWithin(geom_a, geom_b, other_distance);
$BODY$;
CREATE OR REPLACE FUNCTION public.match_condition(tags_a jsonb, tags_b jsonb, name_key text, ref_key1 text, ref_key2 text,
												  other_distance real, name_distance real, ref_distance real, geom_a geometry, geom_b geometry)
    RETURNS bool
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT (tags_a ? ref_key1 AND tags_a ? ref_key2 AND tags_a->>ref_key1 = tags_b->>ref_key1 AND tags_a->>ref_key2 = tags_b->>ref_key2 AND ST_DWithin(geom_a, geom_b, ref_distance)) OR (tags_a ? name_key AND LOWER(tags_a->>name_key) = LOWER(tags_b->>name_key) AND ST_DWithin(geom_a, geom_b, name_distance)) OR ST_DWithin(geom_a, geom_b, other_distance);
$BODY$;
CREATE OR REPLACE FUNCTION public.match_condition(tags_a jsonb, tags_b jsonb, name_key text,
												  other_distance real, name_distance real, geom_a geometry, geom_b geometry)
    RETURNS bool
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT (tags_a ? name_key AND LOWER(tags_a->>name_key) = LOWER(tags_b->>name_key) AND ST_DWithin(geom_a, geom_b, name_distance)) OR ST_DWithin(geom_a, geom_b, other_distance);
$BODY$;

CREATE OR REPLACE FUNCTION public.match_score(tags_a jsonb, tags_b jsonb, name_key text, ref_key text,
											  other_distance real, name_distance real, ref_distance real, geom_a geometry, geom_b geometry)
    RETURNS real
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT CASE
		WHEN tags_a->>ref_key = tags_b->>ref_key THEN ref_distance + ST_Distance(geom_a, geom_b)
		WHEN tags_a->>name_key = tags_b->>name_key THEN name_distance + ST_Distance(geom_a, geom_b)
		ELSE other_distance + ST_Distance(geom_a, geom_b) END;
$BODY$;
CREATE OR REPLACE FUNCTION public.match_score(tags_a jsonb, tags_b jsonb, name_key text, ref_key1 text, ref_key2 text,
											  other_distance real, name_distance real, ref_distance real, geom_a geometry, geom_b geometry)
    RETURNS real
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT CASE
		WHEN tags_a->>ref_key1 = tags_b->>ref_key1 AND tags_a->>ref_key2 = tags_b->>ref_key2 THEN ref_distance + ST_Distance(geom_a, geom_b)
		WHEN tags_a->>name_key = tags_b->>name_key THEN name_distance + ST_Distance(geom_a, geom_b)
		ELSE other_distance + ST_Distance(geom_a, geom_b) END;
$BODY$;
CREATE OR REPLACE FUNCTION public.match_score(tags_a jsonb, tags_b jsonb, name_key text,
											  other_distance real, name_distance real, geom_a geometry, geom_b geometry)
    RETURNS real
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT CASE
		WHEN tags_a->>name_key = tags_b->>name_key THEN name_distance + ST_Distance(geom_a, geom_b)
		ELSE other_distance + ST_Distance(geom_a, geom_b) END;
$BODY$;
