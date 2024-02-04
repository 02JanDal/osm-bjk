DO $$ BEGIN
  CREATE DOMAIN "text/xml" AS pg_catalog.xml;
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;

CREATE OR REPLACE FUNCTION public.count_jsonb_keys(obj jsonb) RETURNS int
    LANGUAGE sql IMMUTABLE LEAKPROOF PARALLEL SAFE
    AS $$
SELECT COUNT(*) FROM (SELECT jsonb_object_keys(obj)) keys;
$$;
COMMENT ON FUNCTION public.count_jsonb_keys(obj jsonb) IS 'Counts the number of keys in a JSONB object';

CREATE OR REPLACE FUNCTION public.fix_name(original text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$
	SELECT CASE WHEN TRIM(original) = '' THEN NULL ELSE TRIM(REGEXP_REPLACE(REGEXP_REPLACE(INITCAP(original), '\yKommun\y', 'kommun'), '\yAb\y', 'AB')) END;
$$;
COMMENT ON FUNCTION public.fix_name(original text) IS 'Fix the casing of text';

CREATE OR REPLACE FUNCTION public.fix_phone(original text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$
DECLARE
	phone text;
BEGIN
	-- See https://wiki.openstreetmap.org/wiki/Key:phone#Usage for expected format
	phone := REPLACE(REPLACE(original, ' ', ''), '-', '');
	IF STARTS_WITH(phone, '+') THEN
		phone := SUBSTRING(phone FROM 1 FOR 3) || ' ' || SUBSTRING(phone FROM 4);
	ELSEIF STARTS_WITH(phone, '00') THEN
		phone := '+' || SUBSTRING(phone FROM 3 FOR 2) || ' ' || SUBSTRING(original FROM 5);
	ELSEIF STARTS_WITH(phone, '0') THEN
		phone := '+46 ' || SUBSTRING(phone FROM 2);
	END IF;
	RETURN phone;
END;
$$;
COMMENT ON FUNCTION public.fix_phone(original text) IS 'Fix the format of phone numbers';

CREATE TABLE IF NOT EXISTS public.tag_aliases (
  preferred text NOT NULL,
  alternative text NOT NULL,
  category text NOT NULL
);
GRANT SELECT ON public.tag_aliases TO app;
TRUNCATE TABLE public.tag_aliases;
INSERT INTO public.tag_aliases (preferred, alternative, category)
VALUES
  ('contact:email', 'email', 'contact'),
  ('contact:phone', 'phone', 'contact'),
  ('contact:website', 'website', 'contact');

DO $$ BEGIN
    CREATE TYPE public.new_tag_value_type AS (
           replace boolean,
           value text
    );
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;

CREATE OR REPLACE FUNCTION public.new_website(new_value text, old_value text) RETURNS boolean
    LANGUAGE sql IMMUTABLE LEAKPROOF PARALLEL SAFE
    AS $$
SELECT
  new_value IS DISTINCT FROM old_value
  -- Do not replace https://example.com with http://example.com
  AND NOT (
    starts_with(new_value, 'http://') AND
    starts_with(old_value, 'https://') AND
    substring(new_value FROM 'http://(.*)') = substring(old_value FROM 'https://(.*)')
  )
$$;

CREATE OR REPLACE FUNCTION public.new_phone(new_value text, old_value text) RETURNS boolean
    LANGUAGE sql IMMUTABLE LEAKPROOF PARALLEL SAFE
    AS $$
SELECT
  fix_phone(new_value) IS DISTINCT FROM fix_phone(old_value)
$$;

CREATE OR REPLACE FUNCTION public.new_tag_value(key text, new_value text, old_value text) RETURNS public.new_tag_value_type
    LANGUAGE sql IMMUTABLE LEAKPROOF PARALLEL SAFE
    AS $$
SELECT
  CASE WHEN key IN ('website', 'contact:website') THEN
         CASE WHEN public.new_website(new_value, old_value) THEN (true, new_value)::public.new_tag_value_type
              ELSE (false, null)::public.new_tag_value_type
         END
       WHEN key IN ('phone', 'contact:phone') THEN
         CASE WHEN public.new_phone(new_value, old_value) THEN (true, new_value)::public.new_tag_value_type
              ELSE (false, null)::public.new_tag_value_type
         END
       -- Fallback, do a normal comparison.
       WHEN new_value IS DISTINCT FROM old_value THEN (true, new_value)::public.new_tag_value_type
       ELSE (false, null)::public.new_tag_value_type
       END
$$;

CREATE OR REPLACE FUNCTION public.tag_diff(in_old jsonb, in_new jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE LEAKPROOF PARALLEL SAFE
    AS $$
WITH new AS (
  SELECT * FROM JSONB_EACH_TEXT(COALESCE(in_new, '{}'::jsonb))
), old AS (
  SELECT * FROM JSONB_EACH_TEXT(COALESCE(in_old, '{}'::jsonb))
),
-- Identify which variation the old object has for each category.
category_picks AS (
  SELECT min(choice) AS choice, category
  FROM (SELECT 'preferred' as choice, category
           FROM old JOIN public.tag_aliases ON old.key = preferred
        UNION
        SELECT 'alternative' as choice, category
           FROM old JOIN public.tag_aliases ON old.key = alternative
        ) AS recognized
  GROUP BY category
  HAVING COUNT(choice) = 1
),
-- Create a mapping from all keys in both columns of tag_aliases to
-- the selection identified above.
aliases AS (
  SELECT
    ta.preferred AS "from",
    CASE WHEN cp IS NULL OR cp.choice = 'preferred' THEN ta.preferred
         ELSE ta.alternative
         END AS "to"
  FROM tag_aliases AS ta
  LEFT OUTER JOIN category_picks AS cp
    ON ta.category = cp.category
  UNION ALL
  SELECT
    ta.alternative AS "from",
    CASE WHEN cp IS NULL OR cp.choice = 'preferred' THEN ta.preferred
         ELSE ta.alternative
         END AS "to"
  FROM tag_aliases AS ta
  LEFT OUTER JOIN category_picks AS cp
    ON ta.category = cp.category
),
canonical_new AS (
  SELECT COALESCE("to", key) AS key, value
  FROM new
  LEFT OUTER JOIN aliases ON "from" = key
),
canonical_old AS (
  SELECT COALESCE("to", key) AS key, value
  FROM old
  LEFT OUTER JOIN aliases ON "from" = key
)
SELECT
    COALESCE(JSONB_OBJECT_AGG(new.key, new_value.replace_with), '{}'::jsonb)
  FROM canonical_new AS new
  FULL OUTER JOIN canonical_old AS old ON new.key = old.key
  CROSS JOIN LATERAL public.new_tag_value(new.key, new.value, old.value) new_value(replace, replace_with)
WHERE
  new.key IS NOT NULL AND new_value.replace
$$;
COMMENT ON FUNCTION public.tag_diff(in_old jsonb, in_new jsonb) IS 'Result only includes tags that are different or do not exist in in_old';

CREATE OR REPLACE FUNCTION public.tag_alternatives(alternatives jsonb[], constants jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE LEAKPROOF PARALLEL SAFE
    AS $$
SELECT jsonb_agg(jsonb_strip_nulls(constants || alt)) FROM unnest(alternatives) alt;
$$;
COMMENT ON FUNCTION public.tag_alternatives(alternatives jsonb[], constants jsonb) IS 'Produce a JSON array of alternative tagging schemes';

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
CREATE OR REPLACE FUNCTION public.match_score(other_distance real, geom_a geometry, geom_b geometry)
    RETURNS real
    LANGUAGE 'sql'
    COST 100
    IMMUTABLE PARALLEL SAFE
AS $BODY$
	SELECT other_distance + ST_Distance(geom_a, geom_b);
$BODY$;
