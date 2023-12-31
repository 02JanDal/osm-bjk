CREATE SCHEMA IF NOT EXISTS api;
ALTER SCHEMA api OWNER TO postgres;
COMMENT ON SCHEMA api IS 'Parts of the database that should be exposed externally';

CREATE SCHEMA IF NOT EXISTS osm;
ALTER SCHEMA osm OWNER TO postgres;
COMMENT ON SCHEMA osm IS 'Data from OpenStreetMap';

CREATE SCHEMA IF NOT EXISTS upstream;
ALTER SCHEMA upstream OWNER TO postgres;
COMMENT ON SCHEMA upstream IS 'Data from upstream sources';

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA api GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA api GRANT SELECT ON TABLES  TO web_auth;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA api GRANT SELECT ON TABLES  TO web_anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA upstream GRANT ALL ON TYPES  TO app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA upstream GRANT ALL ON FUNCTIONS  TO app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA upstream GRANT SELECT ON TABLES  TO app;

GRANT USAGE ON SCHEMA api TO app;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA api TO web_auth;
GRANT USAGE ON SCHEMA api TO web_tileserv;

GRANT ALL ON SCHEMA osm TO app;

GRANT ALL ON SCHEMA upstream TO app;
