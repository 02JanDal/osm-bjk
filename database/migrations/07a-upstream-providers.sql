INSERT INTO upstream.provider OVERRIDING SYSTEM VALUE VALUES (1, 'Gävle kommun', 'https://www.gavle.se/kommunens-service/kommun-och-politik/statistik-fakta-och-oppna-data/oppna-data/') ON CONFLICT DO NOTHING;
INSERT INTO upstream.provider OVERRIDING SYSTEM VALUE VALUES (2, 'Skolverket', 'https://www.skolverket.se/skolutveckling/skolenhetsregistret') ON CONFLICT DO NOTHING;
INSERT INTO upstream.provider OVERRIDING SYSTEM VALUE VALUES (3, 'SCB', 'https://www.scb.se/vara-tjanster/oppna-data/oppna-geodata/') ON CONFLICT DO NOTHING;
INSERT INTO upstream.provider OVERRIDING SYSTEM VALUE VALUES (4, 'Lantmäteriet', 'https://www.lantmateriet.se/sv/geodata/vara-produkter/') ON CONFLICT DO NOTHING;
INSERT INTO upstream.provider OVERRIDING SYSTEM VALUE VALUES (5, 'Trafikverket', 'https://www.trafikverket.se/') ON CONFLICT DO NOTHING;
INSERT INTO upstream.provider OVERRIDING SYSTEM VALUE VALUES (6, 'Länsstyrelserna', 'https://gis.lansstyrelsen.se/geodata/geodatakatalogen/') ON CONFLICT DO NOTHING;
INSERT INTO upstream.provider OVERRIDING SYSTEM VALUE VALUES (7, 'Uppsala kommun', 'https://opendata.uppsala.se/') ON CONFLICT DO NOTHING;

SELECT pg_catalog.setval('upstream.provider_id_seq', 7, true);
