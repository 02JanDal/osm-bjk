-- region Table

CREATE TABLE IF NOT EXISTS api.deviation (
    id BIGINT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    layer_id BIGINT NOT NULL REFERENCES api.layer(id) ON DELETE RESTRICT,
    dataset_id BIGINT NOT NULL REFERENCES upstream.dataset(id) ON DELETE RESTRICT,
    upstream_item_id BIGINT,
    osm_element_id BIGINT,
    osm_element_type osm.element_type,
    suggested_geom GEOMETRY(Geometry, 3006),
    suggested_tags JSONB,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    center GEOMETRY(Point, 3006) NOT NULL,
    municipality_code CHAR(4) NOT NULL REFERENCES api.municipality(code),
    action api.action_type,
    action_at TIMESTAMPTZ,
    note TEXT DEFAULT '' NOT NULL,
    CONSTRAINT uniq UNIQUE NULLS NOT DISTINCT (layer_id, dataset_id, upstream_item_id, osm_element_id, osm_element_type, title),
    CONSTRAINT deviation_upstream_item_id_fkey FOREIGN KEY (dataset_id, upstream_item_id) REFERENCES upstream.item(dataset_id, id) ON DELETE CASCADE
);

-- endregion

-- region Extra PostgREST functions

CREATE OR REPLACE FUNCTION api.osm_geom(api.deviation) RETURNS GEOMETRY
    LANGUAGE sql SECURITY DEFINER
    AS $_$
  SELECT geom FROM osm.element WHERE element.type = $1.osm_element_type AND element.id = $1.osm_element_id;
$_$;

CREATE OR REPLACE FUNCTION api.upstream_item(api.deviation) RETURNS upstream.item
    LANGUAGE sql STABLE SECURITY DEFINER PARALLEL SAFE
    AS $_$
  SELECT * FROM upstream.item WHERE id = $1.upstream_item_id;
$_$;

CREATE OR REPLACE FUNCTION api.nearby(
	api.deviation)
    RETURNS SETOF api.deviation
    LANGUAGE 'sql'
    COST 100
    STABLE SECURITY DEFINER PARALLEL SAFE
    ROWS 1000

AS $BODY$
  SELECT * FROM api.deviation WHERE ST_DWithin(deviation.center, $1.center, 250) AND deviation.id <> $1.id ORDER BY ST_Distance(deviation.center, $1.center) LIMIT 10;
$BODY$;

-- endregion

-- region PostgREST RPC endpoints

CREATE OR REPLACE PROCEDURE api.mark_deviation_fixed_by(IN d api.deviation, IN e osm.element)
    LANGUAGE sql
    AS $$
UPDATE api.deviation SET action = 'fixed', action_at =
				CASE WHEN e.node_id IS NOT NULL THEN (SELECT (meta).timestamp FROM osm.node WHERE id = e.node_id)
					 WHEN e.way_id IS NOT NULL THEN (SELECT (meta).timestamp FROM osm.way WHERE id = e.way_id)
					 WHEN e.relation_id IS NOT NULL THEN (SELECT (meta).timestamp FROM osm.relation WHERE id = e.relation_id)
					 ELSE NOW() END
			WHERE id = d.id AND action IS NULL
$$;

-- endregion

-- region Triggers

CREATE OR REPLACE FUNCTION api.t_deviation_initial_center() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
 	NEW.center := ST_Centroid(COALESCE((SELECT geom FROM osm.element WHERE element.id = NEW.osm_element_id AND element.type = NEW.osm_element_type), NEW.suggested_geom));
	RETURN NEW;
END;
$$;
CREATE OR REPLACE TRIGGER t_deviation_initial_center BEFORE INSERT ON api.deviation FOR EACH ROW EXECUTE FUNCTION api.t_deviation_initial_center();

CREATE OR REPLACE FUNCTION api.t_deviation_municipality() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
 	NEW.municipality_code := (SELECT code FROM api.municipality WHERE ST_Within(NEW.center, municipality.geom));
	RETURN NEW;
END;
$$;
CREATE OR REPLACE TRIGGER t_deviation_municipality BEFORE INSERT OR UPDATE OF center ON api.deviation FOR EACH ROW EXECUTE FUNCTION api.t_deviation_municipality();

CREATE OR REPLACE FUNCTION osm.t_deviation_action() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
 	IF NEW.action IS NOT NULL THEN
		NEW.action_at := NOW();
	END IF;
	RETURN NEW;
END;
$$;
CREATE OR REPLACE TRIGGER t_deviation_action BEFORE UPDATE OF action ON api.deviation FOR EACH ROW EXECUTE FUNCTION osm.t_deviation_action();

-- endregion

-- region Indices

CREATE INDEX IF NOT EXISTS deviation_center_idx ON api.deviation USING gist (center);
CREATE INDEX IF NOT EXISTS deviation_layer_id_idx ON api.deviation USING btree (layer_id);
CREATE INDEX IF NOT EXISTS deviation_municipality_code_idx ON api.deviation USING btree (municipality_code);
CREATE INDEX IF NOT EXISTS deviation_osm_item_type_osm_item_id_idx ON api.deviation USING btree (osm_element_type, osm_element_id);
CREATE INDEX IF NOT EXISTS deviation_suggested_geom_idx ON api.deviation USING gist (suggested_geom);
CREATE INDEX IF NOT EXISTS deviation_title_idx ON api.deviation USING btree (title);
CREATE INDEX IF NOT EXISTS deviation_upstream_item_id_idx ON api.deviation USING btree (upstream_item_id);

-- endregion

-- region Permissions

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE api.deviation TO app;
GRANT SELECT ON TABLE api.deviation TO web_anon;
GRANT SELECT ON TABLE api.deviation TO web_auth;
GRANT SELECT ON TABLE api.deviation TO web_tileserv;

GRANT UPDATE(action) ON TABLE api.deviation TO web_anon;
GRANT UPDATE(action) ON TABLE api.deviation TO web_auth;

REVOKE ALL ON FUNCTION api.osm_geom(api.deviation) FROM PUBLIC;
GRANT ALL ON FUNCTION api.osm_geom(api.deviation) TO web_anon;
GRANT ALL ON FUNCTION api.osm_geom(api.deviation) TO web_auth;

REVOKE ALL ON FUNCTION api.upstream_item(api.deviation) FROM PUBLIC;
GRANT ALL ON FUNCTION api.upstream_item(api.deviation) TO web_anon;
GRANT ALL ON FUNCTION api.upstream_item(api.deviation) TO web_auth;

REVOKE ALL ON FUNCTION api.nearby(api.deviation) FROM PUBLIC;
GRANT ALL ON FUNCTION api.nearby(api.deviation) TO web_anon;
GRANT ALL ON FUNCTION api.nearby(api.deviation) TO web_auth;

-- endregion
