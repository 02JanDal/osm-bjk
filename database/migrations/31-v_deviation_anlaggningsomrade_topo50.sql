CREATE OR REPLACE VIEW upstream.v_deviation_anlaggningsomrade_topo50 AS
WITH gavle AS (
         SELECT municipality.geom
           FROM api.municipality
          WHERE municipality.code = '2180'
        ),
		missing AS (
	SELECT item.*, jsonb_build_object('site', 'winter_sports') as tags, item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 1000) AND (element.tags ? 'landuse' OR element.tags ? 'leisure') AND (element.tags->>'landuse' = 'winter_sports' OR ((element.tags->>'landuse' = 'recreation_ground' AND element.tags->>'sport' = 'skiing') OR (element.tags->>'leisure' = 'sports_centre' AND element.tags->>'sport' = 'skiing')))
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Vintersportanläggning' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'pitch', 'sport', 'shooting'), 'Skjutbana' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' = 'pitch' AND element.tags->>'sport' = 'shooting'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'objekttyp' = 'Civilt skjutfält' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'sports_centre', 'sport', 'motor') as tags, item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' IN ('stadium', 'sports_centre') AND element.tags->>'sport' IN ('motor', 'karting', 'motocross')
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Motorsportanläggning' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('amenity', 'prison'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'amenity' AND element.tags->>'amenity' = 'prison'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Kriminalvårdsanstalt' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('landuse', 'quarry'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'emergency' AND element.tags->>'landuse' = 'quarry'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Täkt' AND element.id IS NULL
	UNION ALL
-- TODO: how should these be tagged?
--	SELECT item.*, jsonb_build_object('leisure', 'marina'), item.original_attributes->>'andamal' as title FROM upstream.item
--	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' = 'marina'
--	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Testbana' AND element.id IS NULL
--	UNION ALL
	SELECT item.*, jsonb_build_object('site', 'theme_park'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.site ON ST_DWithin(item.geometry, site.geom, 500) AND site.tags->>'site' = 'theme_park'
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'tourism' AND element.tags->>'tourism' IN ('theme_park', 'zoo')
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Besökspark' AND element.id IS NULL AND site.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('landuse', 'cemetery'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND (element.tags ? 'landuse' OR element.tags ? 'amenity') AND (element.tags->>'landuse' = 'cemetery' OR element.tags->>'amenity' = 'grave_yard')
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Begravningsplats' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('power', 'plant'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'power' AND element.tags->>'power' = 'plant'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Energiproduktion' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('amenity', 'hospital'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'amenity' AND element.tags->>'amenity' = 'hospital'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Sjukhusområde' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('amenity', 'recycling'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'amenity' AND element.tags->>'amenity' = 'recycling'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Avfallsanläggning' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('landuse', 'industrial', 'industrial', 'mine'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'landuse' AND element.tags ? 'industrial' AND element.tags->>'landuse' = 'industrial' AND element.tags->>'industrial' = 'mine'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Gruvområde' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('leisure', 'golf_course'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'leisure' AND element.tags->>'leisure' = 'golf_course'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Golfbana' AND element.id IS NULL
	UNION ALL
-- TODO: how should these be tagged?
--	SELECT item.*, jsonb_build_object('tourism', 'camp_site'), item.original_attributes->>'andamal' as title FROM upstream.item
--	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'tourism' AND element.tags->>'tourism' IN ('camp_site', 'caravan_site')
--	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Rengärde' AND element.id IS NULL
--	UNION ALL
-- TODO: how should these be tagged?
--	SELECT item.*, jsonb_build_object('tourism', 'camp_site'), item.original_attributes->>'andamal' as title FROM upstream.item
--	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'tourism' AND element.tags->>'tourism' IN ('camp_site', 'caravan_site')
--	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Trafikövningsplats' AND element.id IS NULL
--	UNION ALL
	SELECT item.*, jsonb_build_object('landuse', 'allotments'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'landuse' AND element.tags->>'landuse' = 'allotments'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Koloniområde' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('landuse', 'education'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'landuse' AND element.tags->>'landuse' = 'education'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Skolområde' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('site', 'theme_park'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.site ON ST_DWithin(item.geometry, site.geom, 500) AND site.tags->>'site' = 'theme_park'
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'tourism' AND element.tags->>'tourism' = 'theme_park'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Aktivitetspark' AND element.id IS NULL AND site.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('tourism', 'camp_site'), item.original_attributes->>'andamal' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'tourism' AND element.tags->>'tourism' IN ('camp_site', 'caravan_site')
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Kulturanläggning' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('landuse', 'commercial'), 'Samhällsfunktionsområde' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'landuse' AND element.tags->>'landuse' IN ('commercial', 'institutional')
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Ospecificerad' AND item.original_attributes->>'objekttyp' = 'Samhällsfunktion' AND element.id IS NULL
	UNION ALL
	SELECT item.*, jsonb_build_object('landuse', 'industrial'), 'Industriområde' as title FROM upstream.item
	LEFT OUTER JOIN osm.element ON ST_DWithin(item.geometry, element.geom, 500) AND element.tags ? 'landuse' AND element.tags->>'landuse' = 'industrial'
	WHERE item.dataset_id = 140 AND item.original_attributes->>'andamal' = 'Ospecificerad' AND item.original_attributes->>'objekttyp' = 'Industriområde' AND element.id IS NULL
)
SELECT 140 AS dataset_id,
	CASE WHEN missing.original_attributes->>'andamal' IN ('Vintersportanläggning', 'Civilt övningsfält', 'Motorsportanläggning', 'Besökspark', 'Golfbana', 'Kulturanläggning', 'Aktivitetspark') THEN 18 -- Fritid
		 WHEN missing.original_attributes->>'objekttyp' = 'Civilt skjutfält' THEN 7 -- Mark
		 WHEN missing.original_attributes->>'andamal' IN ('Skolområde', 'Koloniområde', 'Sjukhusområde', 'Rengärde', 'Begravningsplats') THEN 7 -- Mark
		 WHEN missing.original_attributes->>'andamal' = 'Ospecificerad' THEN 7 -- Mark
		 WHEN missing.original_attributes->>'andamal' IN ('Kriminalvårdsanstalt', 'Testbana', 'Trafikövningsplats') THEN 21 -- Butiker och tjänster
		 WHEN missing.original_attributes->>'andamal' IN ('Avfallsanläggning', 'Energiproduktion', 'Täkt', 'Gruvområde') THEN 19 -- Industri
	END AS layer_id,
    ARRAY[missing.id] AS upstream_item_ids,
    missing.geometry AS suggested_geom,
    missing.tags AS suggested_tags,
    NULL::bigint AS osm_element_id,
    NULL::osm.element_type AS osm_element_type,
    missing.title || ' saknas' AS title,
	'Enligt Lantmäteriets 1:50 000 karta ska det finnas en ' || LOWER(missing.title) || ' här' AS description,
	'' AS note
FROM missing;

GRANT SELECT ON TABLE upstream.v_deviation_anlaggningsomrade_topo50 TO app;
