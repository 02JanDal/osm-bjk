UPDATE api.municipality SET geom = (
SELECT ST_SimplifyPreserveTopology(ST_BuildArea(ST_Collect(geom)), 10) FROM osm.relation
INNER JOIN osm.relation_member_way rmw ON rmw.relation_id = relation.id
INNER JOIN osm.way_geom wg ON rmw.member_id = wg.id
WHERE tags->>'type' = 'boundary' AND tags->>'admin_level' = '7' AND tags->>'KNKOD' = code)
