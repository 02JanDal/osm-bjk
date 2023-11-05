DO $$ BEGIN
    CREATE TYPE api.action_type AS ENUM ('fixed', 'already-fixed', 'not-an-issue', 'deferred');
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;
DO $$ BEGIN
    CREATE TYPE api.dataset_usage AS ENUM ('advisory', 'complete', 'automatic');
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;

CREATE OR REPLACE VIEW api.provider AS SELECT id, name, url FROM upstream.provider;
CREATE OR REPLACE VIEW api.dataset AS SELECT id, name, provider_id, url, license, fetched_at FROM upstream.dataset;
CREATE OR REPLACE VIEW api.upstream_item AS SELECT id, geometry, original_attributes, dataset_id FROM upstream.item;

CREATE OR REPLACE FUNCTION api.extent(api.dataset)
    RETURNS GEOMETRY
    LANGUAGE sql STABLE SECURITY DEFINER PARALLEL SAFE
    AS $_$
  SELECT ST_Extent(geometry) FROM upstream.item WHERE dataset_id = $1.id;
$_$;

CREATE TABLE IF NOT EXISTS api.region (
    code CHAR(2) NOT NULL PRIMARY KEY,
    name TEXT
);
CREATE TABLE IF NOT EXISTS api.municipality (
    code CHAR(4) NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    geom GEOMETRY(MultiPolygon, 3006) NOT NULL
);
CREATE INDEX IF NOT EXISTS municipality_geom_idx ON api.municipality USING gist (geom);
CREATE OR REPLACE FUNCTION api.extent(api.municipality)
    RETURNS GEOMETRY
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$
  SELECT ST_Extent($1.geom);
$_$;
CREATE OR REPLACE FUNCTION api.region_name(api.municipality) RETURNS text
    LANGUAGE sql
    AS $_$
  SELECT name FROM api.region WHERE api.region.code = LEFT($1.code, 2);
$_$;

CREATE TABLE IF NOT EXISTS api.layer (
    id BIGINT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT NOT NULL,
    is_major BOOLEAN DEFAULT FALSE,
    description TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS api.municipality_layer (
    id BIGINT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    municipality_code CHAR(4) NOT NULL REFERENCES api.municipality(code) ON DELETE RESTRICT,
    layer_id BIGINT NOT NULL REFERENCES api.layer(id) ON DELETE CASCADE,
    dataset_id BIGINT REFERENCES upstream.dataset(id),
    dataset_type api.dataset_usage,
    project_link TEXT,
    last_checked TIMESTAMPTZ,
    last_checked_by BIGINT,
    CONSTRAINT municipality_layer_check CHECK ((((dataset_id IS NULL) AND (dataset_type IS NULL)) OR ((dataset_id IS NOT NULL) AND (dataset_type IS NOT NULL)))),
    CONSTRAINT municipality_layer_municipality_code_layer_id_key UNIQUE (municipality_code, layer_id)
);

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE api.upstream_item TO app;
GRANT SELECT ON TABLE api.upstream_item TO web_auth;
GRANT SELECT ON TABLE api.upstream_item TO web_anon;
GRANT SELECT ON TABLE api.upstream_item TO web_tileserv;

GRANT SELECT ON TABLE api.layer TO web_anon;
GRANT SELECT ON TABLE api.layer TO web_auth;

GRANT SELECT ON TABLE api.municipality_layer TO web_anon;
GRANT SELECT ON TABLE api.municipality_layer TO web_auth;

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE upstream.provider TO app;

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE api.provider TO app;
GRANT SELECT ON TABLE api.provider TO web_anon;
GRANT SELECT ON TABLE api.provider TO web_auth;

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE api.region TO app;
GRANT SELECT ON TABLE api.region TO web_anon;
GRANT SELECT ON TABLE api.region TO web_auth;

REVOKE ALL ON FUNCTION api.region_name(api.municipality) FROM PUBLIC;
GRANT ALL ON FUNCTION api.region_name(api.municipality) TO web_anon;
GRANT ALL ON FUNCTION api.region_name(api.municipality) TO web_auth;

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE api.dataset TO app;
GRANT SELECT ON TABLE api.dataset TO web_anon;
GRANT SELECT ON TABLE api.dataset TO web_auth;

GRANT ALL ON FUNCTION api.extent(api.dataset) TO web_anon;
GRANT ALL ON FUNCTION api.extent(api.dataset) TO web_auth;

GRANT SELECT ON TABLE api.municipality TO web_anon;
GRANT SELECT ON TABLE api.municipality TO web_auth;
GRANT SELECT ON TABLE api.municipality TO web_tileserv;
