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
