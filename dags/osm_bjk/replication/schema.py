OSM_SCHEMA = """
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS osm;

CREATE TABLE IF NOT EXISTS osm.meta (
    key TEXT PRIMARY KEY,
    value TEXT
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'osm_meta') THEN
        CREATE TYPE osm.osm_meta AS (
            timestamp TIMESTAMPTZ,
            user_id BIGINT,
            version INT
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS osm.node (
    id BIGINT PRIMARY KEY NOT NULL,
    geom GEOMETRY(Point, 3006) NOT NULL,
    tags JSONB NOT NULL,
    meta osm.osm_meta NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_node_geom ON osm.node USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_node_tags ON osm.node USING GIN (tags);

CREATE TABLE IF NOT EXISTS osm.way (
    id BIGINT PRIMARY KEY NOT NULL,
    tags JSONB NOT NULL,
    meta osm.osm_meta NOT NULL
);
CREATE TABLE IF NOT EXISTS osm.way_geom (
    id BIGINT PRIMARY KEY NOT NULL REFERENCES osm.way(id) ON DELETE CASCADE,
    geom GEOMETRY(LineString, 3006) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS osm.way_node (
    node_id BIGINT NOT NULL REFERENCES osm.node(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    way_id BIGINT NOT NULL REFERENCES osm.way(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    sequence_order INT NOT NULL,
    UNIQUE (way_id, sequence_order) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX IF NOT EXISTS idx_way_geom ON osm.way_geom USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_way_tags ON osm.way USING GIN (tags);

CREATE TABLE IF NOT EXISTS osm.relation (
    id BIGINT PRIMARY KEY NOT NULL,
    tags JSONB NOT NULL,
    meta osm.osm_meta NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_relation_tags ON osm.relation USING GIN (tags);
CREATE TABLE IF NOT EXISTS osm.relation_member_node (
    relation_id BIGINT NOT NULL REFERENCES osm.relation(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    member_id BIGINT NOT NULL REFERENCES osm.node(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    role TEXT,
    sequence_order INT NOT NULL,
    UNIQUE (relation_id, sequence_order) DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE IF NOT EXISTS osm.relation_member_way (
    relation_id BIGINT NOT NULL REFERENCES osm.relation(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    member_id BIGINT NOT NULL REFERENCES osm.way(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    role TEXT,
    sequence_order INT NOT NULL,
    UNIQUE (relation_id, sequence_order) DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE IF NOT EXISTS osm.relation_member_relation (
    relation_id BIGINT NOT NULL REFERENCES osm.relation(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    member_id BIGINT NOT NULL REFERENCES osm.relation(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    role TEXT,
    sequence_order INT NOT NULL,
    UNIQUE (relation_id, sequence_order) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE IF NOT EXISTS osm.area (
    id BIGINT PRIMARY KEY NOT NULL,
    geom GEOMETRY(MultiPolygon, 3006) NOT NULL,
    way_id BIGINT REFERENCES osm.way(id) ON DELETE CASCADE,
    relation_id BIGINT REFERENCES osm.relation(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    CHECK (way_id IS NOT NULL OR relation_id IS NOT NULL),
    CHECK (way_id IS NULL OR relation_id IS NULL),
    UNIQUE (way_id),
    UNIQUE (relation_id)
);
CREATE INDEX IF NOT EXISTS idx_area_geom ON osm.area USING GIST (geom);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'object_type') THEN
        CREATE TYPE osm.object_type AS ENUM ('node', 'way', 'relation');
    END IF;
END $$;
CREATE TABLE IF NOT EXISTS osm.import_error (
    type osm.object_type NOT NULL,
    id BIGINT NOT NULL,
    in_type osm.object_type NOT NULL,
    in_id BIGINT NOT NULL,
    message TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS osm.changeset (
    id BIGINT PRIMARY KEY NOT NULL,
    tags JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    open BOOLEAN NOT NULL,
    uid BIGINT NOT NULL
);

TRUNCATE TABLE osm.node RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.way RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.way_geom RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.way_node RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.area RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.relation RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.relation_member_node RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.relation_member_way RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.relation_member_relation RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.import_error RESTART IDENTITY CASCADE;
TRUNCATE TABLE osm.changeset RESTART IDENTITY CASCADE;
        """
