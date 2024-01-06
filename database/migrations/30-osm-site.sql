CREATE OR REPLACE VIEW osm.site AS
    SELECT relation.id, relation.tags, area.geom
    FROM osm.relation
    LEFT OUTER JOIN osm.relation_member_way rmw ON rmw.relation_id = relation.id AND rmw.role IN ('perimeter', 'boundary', 'outer')
    LEFT OUTER JOIN osm.relation_member_relation rmr ON rmr.relation_id = relation.id AND rmw.role IN ('perimeter', 'boundary', 'outer')
    INNER JOIN osm.area ON area.way_id = rmw.member_id OR area.relation_id = rmr.member_id
    WHERE tags ? 'site';

GRANT SELECT ON osm.site TO app;
