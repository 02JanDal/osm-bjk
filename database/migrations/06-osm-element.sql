-- region Table

CREATE TABLE IF NOT EXISTS osm.element (
    type osm.element_type NOT NULL,
    id BIGINT NOT NULL,
    tags JSONB NOT NULL,
    geom GEOMETRY(Geometry, 3006) NOT NULL,
    node_id BIGINT REFERENCES osm.node(id) ON DELETE CASCADE,
    way_id BIGINT REFERENCES osm.way(id) ON DELETE CASCADE,
    relation_id BIGINT REFERENCES osm.relation(id) ON DELETE CASCADE,
    PRIMARY KEY (type, id)
);

-- endregion

-- region Indices

CREATE INDEX IF NOT EXISTS element_geom_idx ON osm.element USING gist (geom);
CREATE INDEX IF NOT EXISTS element_node_id_idx ON osm.element USING btree (node_id);
CREATE INDEX IF NOT EXISTS element_relation_id_idx ON osm.element USING btree (relation_id);
CREATE INDEX IF NOT EXISTS element_tag_amenity_idx ON osm.element USING btree ((tags->>'amenity')) WHERE tags->>'amenity' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_disused_amenity_idx ON osm.element USING btree ((tags->>'disused:amenity')) WHERE tags->>'disused:amenity' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_planned_amenity_idx ON osm.element USING btree ((tags->>'planned:amenity')) WHERE tags->>'planned:amenity' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_barrier_idx ON osm.element USING btree ((tags->>'barrier')) WHERE tags->>'barrier' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_building_idx ON osm.element USING btree ((tags->>'building')) WHERE tags->>'building' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_highway_idx ON osm.element USING btree ((tags->>'highway')) WHERE tags->>'highway' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_landuse_idx ON osm.element USING btree ((tags->>'landuse')) WHERE tags->>'landuse' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_natural_idx ON osm.element USING btree ((tags->>'natural')) WHERE tags->>'natural' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_power_idx ON osm.element USING btree ((tags->>'power')) WHERE tags->>'power' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_service_idx ON osm.element USING btree ((tags->>'service')) WHERE tags->>'service' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_waterway_idx ON osm.element USING btree ((tags->>'waterway')) WHERE tags->>'waterway' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_leisure_idx ON osm.element USING btree ((tags->>'leisure')) WHERE tags->>'leisure' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_emergency_idx ON osm.element USING btree ((tags->>'emergency')) WHERE tags->>'emergency' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_tourism_idx ON osm.element USING btree ((tags->>'tourism')) WHERE tags->>'tourism' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tag_man_made_idx ON osm.element USING btree ((tags->>'man_made')) WHERE tags->>'man_made' IS NOT NULL;
CREATE INDEX IF NOT EXISTS element_tags_idx ON osm.element USING gin (tags);
CREATE INDEX IF NOT EXISTS element_way_id_idx ON osm.element USING btree (way_id);

-- endregion

-- region Triggers

CREATE OR REPLACE FUNCTION osm.t_area_add_element() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
	INSERT INTO osm.element (type, id, tags, geom, way_id, relation_id) VALUES ('a', NEW.id, (
		CASE WHEN NEW.way_id IS NOT NULL THEN (SELECT tags FROM osm.way WHERE way.id = NEW.way_id)
			 ELSE (SELECT tags FROM osm.relation WHERE relation.id = NEW.relation_id)
		END
	), NEW.geom, NEW.way_id, NEW.relation_id)
	ON CONFLICT (type, id) DO UPDATE SET tags = EXCLUDED.tags, geom = EXCLUDED.geom;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_area_add_element AFTER INSERT OR UPDATE OF geom ON osm.area FOR EACH ROW EXECUTE FUNCTION osm.t_area_add_element();

CREATE OR REPLACE FUNCTION osm.t_node_add_element() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
	INSERT INTO osm.element (type, id, tags, geom, node_id) VALUES ('n', NEW.id, NEW.tags, NEW.geom, NEW.id)
	ON CONFLICT (type, id) DO UPDATE SET tags = EXCLUDED.tags, geom = EXCLUDED.geom;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_node_add_element AFTER INSERT OR UPDATE OF tags, geom ON osm.node FOR EACH ROW EXECUTE FUNCTION osm.t_node_add_element();

CREATE OR REPLACE FUNCTION osm.t_relation_update_element_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
 	UPDATE osm.element SET tags = NEW.tags WHERE relation_id = NEW.id;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_relation_update_element_tags AFTER UPDATE OF tags ON osm.relation FOR EACH ROW EXECUTE FUNCTION osm.t_relation_update_element_tags();

CREATE OR REPLACE FUNCTION osm.t_way_add_element() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
 	IF NEW.geom IS NOT NULL THEN
		INSERT INTO osm.element (type, id, tags, geom, way_id) VALUES ('w', NEW.id, NEW.tags, NEW.geom, NEW.id)
		ON CONFLICT (type, id) DO UPDATE SET tags = EXCLUDED.tags, geom = EXCLUDED.geom;
	END IF;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_way_add_element AFTER INSERT OR UPDATE OF tags, geom ON osm.way FOR EACH ROW EXECUTE FUNCTION osm.t_way_add_element();

CREATE OR REPLACE FUNCTION osm.t_way_update_element_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
 	UPDATE osm.element SET tags = NEW.tags WHERE way_id = NEW.id;
	RETURN NULL;
END;
$$;
CREATE OR REPLACE TRIGGER t_way_update_element_tags AFTER UPDATE OF tags ON osm.way FOR EACH ROW EXECUTE FUNCTION osm.t_way_update_element_tags();

-- endregion

-- region Permissions

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE osm.element TO app;

-- endregion
