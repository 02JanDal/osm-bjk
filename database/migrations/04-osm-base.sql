DO $$ BEGIN
    CREATE TYPE osm.element_type AS ENUM ('n', 'w', 'a', 'r');
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;
DO $$ BEGIN
    CREATE TYPE osm.object_type AS ENUM ('node', 'way', 'relation');
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;

CREATE OR REPLACE FUNCTION osm.real_element_type(type osm.element_type, id bigint)
    RETURNS osm.object_type
    LANGUAGE 'sql'
    IMMUTABLE STRICT PARALLEL SAFE
AS $BODY$
    SELECT CASE WHEN "type" = 'n' THEN 'node'::osm.object_type
        WHEN "type" = 'w' OR ("type" = 'a' AND "id" < 3600000000) THEN 'way'::osm.object_type
        WHEN "type" = 'r' OR ("type" = 'a' AND "id" > 3600000000) THEN 'relation'::osm.object_type END
$BODY$;
GRANT EXECUTE ON FUNCTION osm.real_element_type(osm.element_type, bigint) TO PUBLIC;
CREATE OR REPLACE FUNCTION osm.real_element_id(type osm.element_type, id bigint)
    RETURNS bigint
    LANGUAGE 'sql'
    IMMUTABLE STRICT PARALLEL SAFE
AS $BODY$
    SELECT CASE WHEN ("type" = 'a' AND "id" > 3600000000) THEN "id" - 3600000000 ELSE "id" END
$BODY$;

GRANT EXECUTE ON FUNCTION osm.real_element_id(osm.element_type, bigint) TO PUBLIC;

CREATE TABLE IF NOT EXISTS osm.meta (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT
);
COMMENT ON TABLE osm.meta IS 'Meta information about the replication process';

DO $$ BEGIN
    CREATE TYPE osm.osm_meta AS (
        timestamp TIMESTAMPTZ,
        user_id BIGINT,
        version BIGINT
    );
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;
COMMENT ON TYPE osm.osm_meta IS 'Meta information about an OSM item';

CREATE TABLE IF NOT EXISTS osm.changeset (
    id BIGINT NOT NULL PRIMARY KEY,
    tags JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    open BOOLEAN NOT NULL,
    uid BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS osm.node (
    id BIGINT NOT NULL PRIMARY KEY,
    geom GEOMETRY(Point, 3006) NOT NULL,
    tags JSONB NOT NULL,
    meta osm.osm_meta NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_node_geom ON osm.node USING gist (geom);
CREATE INDEX IF NOT EXISTS idx_node_tags ON osm.node USING gin (tags);

CREATE TABLE IF NOT EXISTS osm.way (
    id BIGINT NOT NULL PRIMARY KEY,
    tags JSONB NOT NULL,
    meta osm.osm_meta NOT NULL,
    geom GEOMETRY(LineString, 3006),
    geom_timestamp TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_way_tags ON osm.way USING gin (tags);
CREATE INDEX IF NOT EXISTS way_geom_idx ON osm.way USING gist (geom);

CREATE TABLE IF NOT EXISTS osm.way_node (
    node_id BIGINT NOT NULL REFERENCES osm.node(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    way_id BIGINT NOT NULL REFERENCES osm.way(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    sequence_order BIGINT NOT NULL,
    CONSTRAINT way_node_way_id_sequence_order_key UNIQUE (way_id, sequence_order) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX IF NOT EXISTS idx_way_node_node ON osm.way_node USING btree (node_id);
CREATE INDEX IF NOT EXISTS idx_way_node_way ON osm.way_node USING btree (way_id);

CREATE TABLE IF NOT EXISTS osm.relation (
    id BIGINT NOT NULL PRIMARY KEY,
    tags JSONB NOT NULL,
    meta osm.osm_meta NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_relation_tags ON osm.relation USING gin (tags);

CREATE TABLE IF NOT EXISTS osm.relation_member_node (
    relation_id BIGINT NOT NULL REFERENCES osm.relation(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    member_id BIGINT NOT NULL REFERENCES osm.node(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    role TEXT,
    sequence_order BIGINT NOT NULL,
    CONSTRAINT relation_member_node_relation_id_sequence_order_key UNIQUE (relation_id, sequence_order) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX IF NOT EXISTS idx_relation_member_node_member ON osm.relation_member_node USING btree (member_id);
CREATE INDEX IF NOT EXISTS idx_relation_member_node_relation ON osm.relation_member_node USING btree (relation_id);

CREATE TABLE IF NOT EXISTS osm.relation_member_relation (
    relation_id BIGINT NOT NULL REFERENCES osm.relation(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    member_id BIGINT NOT NULL REFERENCES osm.relation(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    role TEXT,
    sequence_order BIGINT NOT NULL,
    CONSTRAINT relation_member_relation_relation_id_sequence_order_key UNIQUE (relation_id, sequence_order) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX IF NOT EXISTS idx_relation_member_relation_member ON osm.relation_member_relation USING btree (member_id);
CREATE INDEX IF NOT EXISTS idx_relation_member_relation_relation ON osm.relation_member_relation USING btree (relation_id);

CREATE TABLE IF NOT EXISTS osm.relation_member_way (
    relation_id BIGINT NOT NULL REFERENCES osm.relation(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    member_id BIGINT NOT NULL REFERENCES osm.way(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    role TEXT,
    sequence_order BIGINT NOT NULL,
    CONSTRAINT relation_member_way_relation_id_sequence_order_key UNIQUE (relation_id, sequence_order) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX IF NOT EXISTS idx_relation_member_way_member ON osm.relation_member_way USING btree (member_id);
CREATE INDEX IF NOT EXISTS idx_relation_member_way_relation ON osm.relation_member_way USING btree (relation_id);

CREATE TABLE IF NOT EXISTS osm.area (
    id BIGINT NOT NULL PRIMARY KEY,
    geom GEOMETRY(MultiPolygon, 3006) NOT NULL,
    way_id BIGINT REFERENCES osm.way(id) ON DELETE CASCADE,
    relation_id BIGINT REFERENCES osm.relation(id) ON DELETE CASCADE,
    "timestamp" TIMESTAMPTZ NOT NULL,
    CHECK (((way_id IS NOT NULL) OR (relation_id IS NOT NULL))),
    CHECK (((way_id IS NULL) OR (relation_id IS NULL))),
    CONSTRAINT area_relation_id_key UNIQUE (relation_id),
    CONSTRAINT area_way_id_key UNIQUE (way_id)
);
CREATE INDEX IF NOT EXISTS idx_area_geom ON osm.area USING gist (geom);
CREATE INDEX IF NOT EXISTS idx_area_relation ON osm.area USING btree (relation_id) WHERE (relation_id IS NOT NULL);
CREATE INDEX IF NOT EXISTS idx_area_way ON osm.area USING btree (way_id) WHERE (way_id IS NOT NULL);

GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.area TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.changeset TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.meta TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.node TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.relation TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.relation_member_node TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.relation_member_relation TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.relation_member_way TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.way TO app;
GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.way_node TO app;
