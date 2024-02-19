
CREATE OR REPLACE FUNCTION public.match_condition(tags_a jsonb, tags_b jsonb, name_key text, ref_key text,
												  other_distance real, name_distance real, ref_distance real, geom_a geometry, geom_b geometry)
    RETURNS bool
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT (tags_a ? ref_key AND STRING_TO_ARRAY(tags_a->>ref_key, ';') && STRING_TO_ARRAY(tags_b->>ref_key, ';') AND ST_DWithin(geom_a, geom_b, ref_distance)) OR (tags_a ? name_key AND LOWER(tags_a->>name_key) = LOWER(tags_b->>name_key) AND ST_DWithin(geom_a, geom_b, name_distance)) OR ST_DWithin(geom_a, geom_b, other_distance);
$BODY$;
CREATE OR REPLACE FUNCTION public.match_condition(tags_a jsonb, tags_b jsonb, name_key text, ref_key1 text, ref_key2 text,
												  other_distance real, name_distance real, ref_distance real, geom_a geometry, geom_b geometry)
    RETURNS bool
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT (tags_a ? ref_key1 AND tags_a ? ref_key2 AND STRING_TO_ARRAY(tags_a->>ref_key1, ';') && STRING_TO_ARRAY(tags_b->>ref_key1, ';') AND STRING_TO_ARRAY(tags_a->>ref_key2, ';') && STRING_TO_ARRAY(tags_b->>ref_key2, ';') AND ST_DWithin(geom_a, geom_b, ref_distance)) OR (tags_a ? name_key AND LOWER(tags_a->>name_key) = LOWER(tags_b->>name_key) AND ST_DWithin(geom_a, geom_b, name_distance)) OR ST_DWithin(geom_a, geom_b, other_distance);
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
CREATE OR REPLACE FUNCTION public.match_condition(other_distance real, geom_a geometry, geom_b geometry)
    RETURNS bool
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT ST_DWithin(geom_a, geom_b, other_distance);
$BODY$;

CREATE OR REPLACE FUNCTION public.match_score(tags_a jsonb, tags_b jsonb, name_key text, ref_key text,
											  other_distance real, name_distance real, ref_distance real, geom_a geometry, geom_b geometry)
    RETURNS real
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT CASE
		WHEN tags_a ? ref_key AND STRING_TO_ARRAY(tags_a->>ref_key, ';') && STRING_TO_ARRAY(tags_b->>ref_key, ';') THEN ref_distance + ST_Distance(geom_a, geom_b)
		WHEN tags_a ? name_key AND LOWER(tags_a->>name_key) = LOWER(tags_b->>name_key) THEN name_distance + ST_Distance(geom_a, geom_b)
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
		WHEN tags_a ? ref_key1 AND tags_a ? ref_key2 AND STRING_TO_ARRAY(tags_a->>ref_key1, ';') && STRING_TO_ARRAY(tags_b->>ref_key1, ';') AND tags_a->>ref_key2 = tags_b->>ref_key2 THEN ref_distance + ST_Distance(geom_a, geom_b)
		WHEN tags_a ? name_key AND LOWER(tags_a->>name_key) = LOWER(tags_b->>name_key) THEN name_distance + ST_Distance(geom_a, geom_b)
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
CREATE OR REPLACE FUNCTION public.match_score(other_distance real, geom_a geometry, geom_b geometry)
    RETURNS real
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT other_distance + ST_Distance(geom_a, geom_b);
$BODY$;
