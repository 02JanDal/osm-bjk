SELECT test(
    'fallback behavior should be to replace if distinct',
    (true, 'a')::new_tag_value_type,
    new_tag_value(
        'arandomtag',
        'a',
        'b'
    )
);

SELECT test(
    'fallback behavior should be to replace if distinct, even if new is null',
    (true, null)::new_tag_value_type,
    new_tag_value(
        'arandomtag',
        null,
        'b'
    )
);

-- contact:phone comparisons
SELECT test(
    'contact:phone with a distinct phone number should be replaced',
    (true, '+46 12345678')::new_tag_value_type,
    new_tag_value(
        'contact:website',
        '+46 12345678',
        '+46 00000000'
    )
);

-- NOTE: Here it might be useful to do some form of normalization at
-- least by adding the country prefix, if desirable.
SELECT test(
    'contact:phone with an equivalent number should not be replaced',
    (false, null)::new_tag_value_type,
    new_tag_value(
        'contact:phone',
        '+46 12345678',
        '012-34 56 78'
    )
);

-- contact:website comparisons
SELECT test(
    'contact:website with a distinct url should be replaced',
    (true, 'http://a.example.com')::new_tag_value_type,
    new_tag_value(
        'contact:website',
        'http://a.example.com',
        'https://b.example.com'
    )
);

SELECT test(
    'contact:website with the same url should not be replaced',
    (false, null)::new_tag_value_type,
    new_tag_value(
        'contact:website',
        'https://a.example.com',
        'https://a.example.com'
    )
);


SELECT test(
    'contact:website with the same url but without https should be ignored',
    (false, null)::new_tag_value_type,
    new_tag_value(
        'contact:website',
        'http://example.com',
        'https://example.com'
    )
);

SELECT test(
    'website with the same url but without https should be ignored',
    (false, null)::new_tag_value_type,
    new_tag_value(
        'website',
        'http://example.com',
        'https://example.com'
    )
);

SELECT test(
    'contact:website with the same url with https should be used',
    (true, 'https://example.com')::new_tag_value_type,
    new_tag_value(
        'contact:website',
        'https://example.com',
        'http://example.com'
    )
);

SELECT test(
    'website with the same url with https should be used',
    (true, 'https://example.com')::new_tag_value_type,
    new_tag_value(
        'website',
        'https://example.com',
        'http://example.com'
    )
);

SELECT test(
    'completely different operator',
    (true, 'Hagfors kommun')::new_tag_value_type,
    new_tag_value(
        'operator',
        'Hagfors kommun',
        'Karlskoga kommun'
    )
);
SELECT test(
    'operator only changes case',
    (false, null)::new_tag_value_type,
    new_tag_value(
        'operator',
        'Hagfors kommun',
        'Hagfors Kommun'
    )
);
SELECT test(
    'operator same when translated',
    (false, null)::new_tag_value_type,
    new_tag_value(
        'operator',
        'Göteborg kommun',
        'Göteborgs kommun'
    )
);
SELECT test(
    'operator same when translated, currently using translated',
    (false, null)::new_tag_value_type,
    new_tag_value(
        'operator',
        'Göteborg kommun',
        'Göteborgs Stad'
    )
);
SELECT test(
    'operator same as translated',
    (false, null)::new_tag_value_type,
    new_tag_value(
        'operator',
        'Göteborgs Stad',
        'Göteborg kommun'
    )
);
SELECT test(
    'suggests translated operator',
    (true, 'Göteborgs Stad')::new_tag_value_type,
    new_tag_value(
        'operator',
        'Göteborg kommun',
        'Privata Skolan AB'
    )
);


SELECT test(
    'suggests non-float value',
    (true, 'yes')::new_tag_value_type,
    new_tag_value(
        'generator:output:electricity',
        'yes',
        null
    )
);
SELECT test(
    'suggests changed non-float value',
    (true, 'yes')::new_tag_value_type,
    new_tag_value(
        'generator:output:electricity',
        'yes',
        '2.0 MW'
    )
);
SELECT test(
    'suggests float value',
    (true, '2.0 MW')::new_tag_value_type,
    new_tag_value(
        'generator:output:electricity',
        '2.0 MW',
        null
    )
);
SELECT test(
    'suggests changed float value',
    (true, '2.5 MW')::new_tag_value_type,
    new_tag_value(
        'generator:output:electricity',
        '2.5 MW',
        '2.0 MW'
    )
);
SELECT test(
    'does not suggests equivalent float value',
    (false, NULL)::new_tag_value_type,
    new_tag_value(
        'generator:output:electricity',
        '2.0 MW',
        '2 MW'
    )
);
SELECT test(
    'does not suggests equivalent float value, reversed',
    (false, NULL)::new_tag_value_type,
    new_tag_value(
        'generator:output:electricity',
        '2 MW',
        '2.0 MW'
    )
);
