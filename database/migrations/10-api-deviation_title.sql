CREATE OR REPLACE VIEW api.deviation_title AS
    SELECT title,
           municipality_code,
           layer_id,
           dataset_id,
           COUNT(*) AS count
    FROM api.deviation
    GROUP BY title, municipality_code, layer_id, dataset_id;
GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE api.deviation_title TO app;
GRANT SELECT ON TABLE api.deviation_title TO web_auth;
GRANT SELECT ON TABLE api.deviation_title TO web_anon;
