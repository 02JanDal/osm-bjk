UPDATE api.municipality SET geom = (
SELECT ST_SimplifyPreserveTopology(ST_BuildArea(ST_Collect(geom)), 10) FROM osm.relation rel
INNER JOIN osm.relation_member_way rmw ON rmw.relation_id = rel.id
INNER JOIN osm.way wg ON rmw.member_id = wg.id
WHERE rel.tags->>'type' = 'boundary' AND rel.tags->>'admin_level' = '7' AND rel.tags->>'KNKOD' = code);
