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
