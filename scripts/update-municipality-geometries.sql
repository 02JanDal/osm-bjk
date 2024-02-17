WITH computed AS (
  SELECT rel.tags->>'KNKOD' AS code,
         ST_SimplifyPreserveTopology(ST_BuildArea(ST_Collect(wg.geom)), 10) AS geom
  FROM osm.relation AS rel
  INNER JOIN osm.relation_member_way rmw ON rmw.relation_id = rel.id
  INNER JOIN osm.way wg ON rmw.member_id = wg.id
  WHERE rel.tags->>'type' = 'boundary' AND
        rel.tags->>'admin_level' = '7' AND
        rel.tags->>'KNKOD'::text IS NOT NULL
  GROUP BY code
)
UPDATE api.municipality
SET geom = COALESCE(computed.geom, api.municipality.geom)
FROM computed
WHERE api.municipality.code = computed.code;
