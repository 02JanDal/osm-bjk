CREATE TABLE IF NOT EXISTS osm.dirty (
    node_id BIGINT,
    way_id BIGINT,
    relation_id BIGINT,
    CONSTRAINT id_uniq UNIQUE NULLS NOT DISTINCT (node_id, way_id, relation_id)
);

GRANT SELECT, INSERT, DELETE, TRUNCATE, UPDATE ON TABLE osm.dirty TO app;

CREATE OR REPLACE FUNCTION osm.t_node_dirty() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
	INSERT INTO osm.dirty (node_id) VALUES (COALESCE(OLD.id, NEW.id)) ON CONFLICT ON CONSTRAINT id_uniq DO NOTHING;
	RETURN NULL;
END; $$;
CREATE OR REPLACE TRIGGER t_node_dirty
    AFTER INSERT OR DELETE OR UPDATE
    ON osm.node
    FOR EACH ROW
    EXECUTE FUNCTION osm.t_node_dirty();

CREATE OR REPLACE FUNCTION osm.t_relation_dirty() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
	INSERT INTO osm.dirty (relation_id) VALUES (COALESCE(OLD.id, NEW.id)) ON CONFLICT ON CONSTRAINT id_uniq DO NOTHING;
	RETURN NULL;
END; $$;
CREATE OR REPLACE TRIGGER t_relation_dirty
    AFTER INSERT OR DELETE OR UPDATE
    ON osm.relation
    FOR EACH ROW
    EXECUTE FUNCTION osm.t_relation_dirty();

CREATE OR REPLACE FUNCTION osm.t_way_dirty() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
	INSERT INTO osm.dirty (way_id) VALUES (COALESCE(OLD.id, NEW.id)) ON CONFLICT ON CONSTRAINT id_uniq DO NOTHING;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_way_dirty
    AFTER INSERT OR DELETE OR UPDATE
    ON osm.way
    FOR EACH ROW
    EXECUTE FUNCTION osm.t_way_dirty();
