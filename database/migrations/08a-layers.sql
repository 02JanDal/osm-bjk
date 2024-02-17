INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (1, 'Vägar', true, 'Alla vägar ur NVDB finns, med minst geometri, typ, hastighetsgräns och enkelriktighet') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (2, 'Trafikregler', false, 'Alla trafikregler ur NVDB finns (t.ex. svängrestriktioner)') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (3, 'Byggnader', true, 'Alla byggnader finns, med minst grov typindelning (bostad, industri, kommersiellt)') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (4, 'Adresser', true, 'Alla adresser finns') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (5, 'Skolor', false, 'Alla skolor finns, med minst område och byggnader') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (6, 'Sjukhus', false, 'Alla sjukhus finns, med minst område och byggnader') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (7, 'Mark', true, 'Kommunen har heltäckande markanvändning/marktäcke i rimlig detaljeringsgrad') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (8, 'Spår och leder', true, 'Alla kända utmarkerade spår och leder finns (minst de som listas på kommunens hemsida), inkl. koppling till överrodnade leder om relevant') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (9, 'Idrottsplatser', false, 'Alla kända idrottsplatser/anläggningar finns') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (10, 'Vattendragsytor', false, 'Alla vattendrag >10m bredd har inritade vattendragsytor') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (11, 'Badplatser', false, 'Alla kända badplatser finns (minst de som listas på kommunens hemsida)') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (12, 'Flygplatser', false, 'Alla flygplatser finns, med minst område, landningsbanor och byggnader') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (13, 'Återvinningscentraler', false, 'Alla återvinningscentraler finns') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (14, 'Handelsområden', false, 'Alla butiker i alla större handelsområden (>3 butiker, ej centrumhandel) finns med') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (15, 'Förskolor', false, 'Alla förskolor finns med, med minst område och byggnader') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (16, 'Micromapping', false, 'Micromapping, t.ex. träd, buskar, soptunnor, etc.') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (17, 'Lokaltrafik', false, 'Busshållplatser och linjer') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (19, 'Industri', false, 'Industrier, fabriker, m.m.') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (20, 'Ledningar', false, 'Alla större kraftledningar, transformatorområden, m.m. finns') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (18, 'Fritid', false, 'Saker som rör fritid, som småbåtshamnar, campingplatser, besöksparker, m.m. (dock ej sport och leder)') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (21, 'Butiker & tjänster', false, 'Alla butiker och tjänster (inkl. offentliga) finns') ON CONFLICT DO NOTHING;
INSERT INTO api.layer OVERRIDING SYSTEM VALUE VALUES (22, 'Vindkraftverk', false, 'Alla vindkraftverk finns') ON CONFLICT DO NOTHING;

SELECT pg_catalog.setval('api.layer_id_seq', 21, true);
