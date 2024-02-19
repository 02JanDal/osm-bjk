TRUNCATE TABLE public.operator_translation;

-- https://sv.wikipedia.org/wiki/Lista_%C3%B6ver_kommuner_i_Sverige_som_kallar_sig_stad
INSERT INTO public.operator_translation (source, target)
VALUES
    ('Borås kommun', 'Borås Stad'),
    ('Göteborg kommun', 'Göteborgs Stad'),
    ('Göteborgs kommun', 'Göteborgs Stad'),
    ('Haparanda kommun', 'Haparanda stad'),
    ('Haparandas kommun', 'Haparanda stad'),
    ('Helsingborg kommun', 'Helsningborgs stad'),
    ('Helsingborgs kommun', 'Helsningborgs stad'),
    ('Landskrona kommun', 'Landskrona stad'),
    ('Landskronas kommun', 'Landskrona stad'),
    ('Lidingö kommun', 'Lidingö stad'),
    ('Lidingös kommun', 'Lidingö stad'),
    ('Malmö kommun', 'Malmö stad'),
    ('Malmös kommun', 'Malmö stad'),
    ('Mölndal kommun', 'Mölndals stad'),
    ('Mölndals kommun', 'Mölndals stad'),
    ('Solna kommun', 'Solna stad'),
    ('Solnas kommun', 'Solna stad'),
    ('Stockholm kommun', 'Stockholms stad'),
    ('Stockholms kommun', 'Stockholms stad'),
    ('Sundbyberg kommun', 'Sundbybergs stad'),
    ('Sundbybergs kommun', 'Sundbybergs stad'),
    ('Trollhättan kommun', 'Trollhättans Stad'),
    ('Trollhättans kommun', 'Trollhättans Stad'),
    ('Vaxholm kommun', 'Vaxholms stad'),
    ('Vaxholms kommun', 'Vaxholms stad'),
    ('Västerås kommun', 'Västerås stad');
