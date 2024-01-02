CREATE OR REPLACE VIEW upstream.v_deviations AS
 SELECT q.dataset_id::bigint,
    q.layer_id::bigint,
    q.upstream_item_ids::bigint[],
    q.suggested_geom,
    q.osm_element_id::bigint,
    q.osm_element_type,
    q.suggested_tags,
    q.title,
    q.description
   FROM ( SELECT v_deviation_preschools_scb.dataset_id,
            v_deviation_preschools_scb.layer_id,
            v_deviation_preschools_scb.upstream_item_ids,
            v_deviation_preschools_scb.suggested_geom,
            v_deviation_preschools_scb.osm_element_id,
            v_deviation_preschools_scb.osm_element_type,
            v_deviation_preschools_scb.suggested_tags,
            v_deviation_preschools_scb.title,
            v_deviation_preschools_scb.description
           FROM upstream.v_deviation_preschools_scb
        UNION ALL
         SELECT v_deviation_trees_gavle.dataset_id,
            v_deviation_trees_gavle.layer_id,
            v_deviation_trees_gavle.upstream_item_ids,
            v_deviation_trees_gavle.suggested_geom,
            v_deviation_trees_gavle.osm_element_id,
            v_deviation_trees_gavle.osm_element_type,
            v_deviation_trees_gavle.suggested_tags,
            v_deviation_trees_gavle.title,
            v_deviation_trees_gavle.description
           FROM upstream.v_deviation_trees_gavle
        UNION ALL
         SELECT v_deviation_schools_skolverket.dataset_id,
            v_deviation_schools_skolverket.layer_id,
            v_deviation_schools_skolverket.upstream_item_ids,
            v_deviation_schools_skolverket.suggested_geom,
            v_deviation_schools_skolverket.osm_element_id,
            v_deviation_schools_skolverket.osm_element_type,
            v_deviation_schools_skolverket.suggested_tags,
            v_deviation_schools_skolverket.title,
            v_deviation_schools_skolverket.description
           FROM upstream.v_deviation_schools_skolverket) q;

GRANT SELECT ON TABLE upstream.v_deviations TO app;

CREATE OR REPLACE FUNCTION upstream._dynamic_deviations_by_view_name(view_name text) RETURNS SETOF upstream.calculated_deviation
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY EXECUTE format('SELECT * FROM upstream.%I', 'v_deviation_' || view_name);
END;
$$;

CREATE OR REPLACE FUNCTION upstream.recalculate_deviation(api.deviation) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ups upstream.v_deviations;
	fixed_by osm.element;
BEGIN
	SELECT * INTO ups FROM upstream.v_deviations
	                  WHERE dataset_id = $1.dataset_id AND layer_id = $1.layer_id
	                    AND (upstream_item_ids = $1.upstream_item_ids OR
	                         (osm_element_id = $1.osm_element_id AND osm_element_type = $1.osm_element_type));
	IF ups.dataset_id IS NULL THEN
		IF EXISTS(SELECT 1 FROM upstream.item WHERE dataset_id = $1.dataset_id AND id = ANY($1.upstream_item_ids)) THEN
			IF $1.osm_element_id IS NULL THEN
				UPDATE api.deviation SET action = 'fixed' WHERE id = $1.id;
			ELSE
			    SELECT * INTO fixed_by FROM osm.element WHERE id = $1.osm_element_id AND type = $1.osm_element_type;
				CALL api.mark_deviation_fixed_by($1, fixed_by);
			END IF;
		ELSE
			DELETE FROM api.deviation WHERE id = $1.id AND (action IS NULL OR action = 'deferred');
		END IF;
	ELSE
		UPDATE api.deviation
		SET suggested_tags = ups.suggested_tags, suggested_geom = ups.suggested_geom, title = ups.title, description = ups.description, osm_element_id = ups.osm_element_id, osm_element_type = ups.osm_element_type
		WHERE id = $1.id;
	END IF;
END;
$_$;

CREATE OR REPLACE FUNCTION upstream.sync_deviations(view_name text) RETURNS record
    LANGUAGE sql
    AS $_$
WITH deviations AS (SELECT * FROM upstream._dynamic_deviations_by_view_name(view_name)),
	 insertions AS (
		 INSERT INTO api.deviation (dataset_id, layer_id, upstream_item_ids, suggested_geom, suggested_tags, osm_element_id, osm_element_type, title, description, note, view_name)
		 SELECT dataset_id, layer_id, upstream_item_ids, suggested_geom, suggested_tags, osm_element_id, osm_element_type, title, description, note, view_name FROM deviations
		 ON CONFLICT ON CONSTRAINT uniq DO UPDATE SET suggested_geom = EXCLUDED.suggested_geom, suggested_tags = EXCLUDED.suggested_tags, description = EXCLUDED.description, note = EXCLUDED.note
		 RETURNING *
	 ),
	 deletions AS (
		 DELETE FROM api.deviation
	 	 WHERE deviation.view_name = view_name AND (deviation.action IS NULL OR deviation.action = 'deferred')
		   AND NOT EXISTS (SELECT 1 FROM deviations WHERE deviation.dataset_id = deviations.dataset_id AND deviation.layer_id = deviations.layer_id AND deviation.upstream_item_ids = deviations.upstream_item_ids AND deviation.osm_element_id = deviations.osm_element_id AND deviation.osm_element_type = deviations.osm_element_type AND deviation.title = deviations.title)
		 RETURNING *
	 )
SELECT (SELECT COUNT(*) FROM insertions) as i, (SELECT COUNT(*) FROM deletions) as d;
$_$;

GRANT ALL ON FUNCTION upstream._dynamic_deviations_by_view_name(view_name text) TO app;

GRANT ALL ON FUNCTION upstream.recalculate_deviation(api.deviation) TO app;

GRANT ALL ON FUNCTION upstream.sync_deviations(view_name text, dataset_id bigint) TO app;

-- region Triggers

CREATE OR REPLACE FUNCTION osm.t_element_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	d api.deviation;
 BEGIN
	FOR d IN SELECT * FROM api.deviation WHERE osm_element_id IS NULL AND ST_DWithin(NEW.geom, deviation.suggested_geom, 100) LOOP
		PERFORM upstream.recalculate_deviation(d);
	END LOOP;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_element_insert AFTER INSERT ON osm.element FOR EACH ROW EXECUTE FUNCTION osm.t_element_insert();

CREATE OR REPLACE FUNCTION osm.t_element_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	d api.deviation;
 BEGIN
 	SELECT * INTO d FROM api.deviation WHERE osm_element_id = OLD.id AND osm_element_type = OLD.type;
	IF d.id IS NOT NULL THEN
		IF d.suggested_geom IS NULL AND d.suggested_tags IS NOT NULL AND tag_diff(NEW.tags, d.suggested_tags) = '{}'::jsonb THEN
			CALL api.mark_deviation_fixed_by(d, NEW);
		ELSE
			PERFORM upstream.recalculate_deviation(d);
		END IF;
	END IF;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_element_update AFTER UPDATE ON osm.element FOR EACH ROW EXECUTE FUNCTION osm.t_element_update();

CREATE OR REPLACE FUNCTION osm.t_element_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	d api.deviation;
 BEGIN
 	SELECT * INTO d FROM api.deviation WHERE osm_element_id = OLD.id AND osm_element_type = OLD.type;
	IF d.id IS NOT NULL THEN
		IF d.suggested_geom IS NULL AND d.suggested_tags IS NULL THEN
			CALL api.mark_deviation_fixed_by(d, NEW);
		ELSIF d.upstream_item_id IS NOT NULL THEN
			PERFORM upstream.recalculate_deviation(d);
		END IF;
	END IF;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_element_delete AFTER DELETE ON osm.element FOR EACH ROW EXECUTE FUNCTION osm.t_element_delete();

-- endregion
