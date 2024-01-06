CREATE OR REPLACE FUNCTION api.t_deviation_municipality()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
 BEGIN
 	NEW.municipality_code := (SELECT code FROM api.municipality WHERE ST_Within(NEW.center, municipality.geom));
	IF NEW.municipality_code IS NULL THEN
		NEW.municipality_code = (SELECT code FROM api.municipality ORDER BY ST_Distance(NEW.center, municipality.geom) LIMIT 1);
	END IF;
	RETURN NEW;
END;
$BODY$;
