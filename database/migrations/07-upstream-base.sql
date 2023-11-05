CREATE TABLE IF NOT EXISTS upstream.provider (
    id BIGINT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT NOT NULL,
    url TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS upstream.dataset (
    id BIGINT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT NOT NULL,
    provider_id BIGINT NOT NULL REFERENCES upstream.provider(id) ON DELETE RESTRICT,
    url TEXT NOT NULL,
    license TEXT NOT NULL,
    fetched_at TIMESTAMPTZ,
    CONSTRAINT dataset_provider_id_name_key UNIQUE (provider_id, name)
);
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE upstream.dataset TO app;

CREATE TABLE IF NOT EXISTS upstream.item (
    id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    dataset_id BIGINT NOT NULL REFERENCES upstream.dataset(id),
    url TEXT,
    original_id TEXT,
    geometry GEOMETRY(Geometry, 3006) NOT NULL,
    original_attributes JSONB NOT NULL,
    updated_at TIMESTAMPTZ,
    PRIMARY KEY (id, dataset_id)
) PARTITION BY LIST (dataset_id);
CREATE INDEX IF NOT EXISTS item_dataset_id_idx ON upstream.item USING btree (dataset_id);
CREATE INDEX IF NOT EXISTS item_dataset_id_original_id_idx ON upstream.item USING btree (dataset_id, original_id) WHERE (original_id IS NOT NULL);
CREATE INDEX IF NOT EXISTS item_geometry_idx ON upstream.item USING gist (geometry);
CREATE INDEX IF NOT EXISTS item_original_attributes_idx ON upstream.item USING gin (original_attributes);
GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE upstream.item TO app;

CREATE OR REPLACE FUNCTION upstream.t_add_item_partition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE 'CREATE TABLE upstream.item__' || NEW.id || ' PARTITION OF upstream.item FOR VALUES IN (' || NEW.id || ')';
    RETURN NEW;
END
$$;
CREATE OR REPLACE TRIGGER t_add_item_partition AFTER INSERT ON upstream.dataset FOR EACH ROW EXECUTE FUNCTION upstream.t_add_item_partition();
