SELECT test(
    'no change',
    jsonb_build_object(),
    tag_diff(
        jsonb_build_object('amenity', 'school', 'name', 'Lugnadalskolan'),
        jsonb_build_object('amenity', 'school', 'name', 'Lugnadalskolan')
    )
);
SELECT test(
    'adds a tag',
    jsonb_build_object('name', 'Lugnadalskolan'),
    tag_diff(
        jsonb_build_object('amenity', 'school'),
        jsonb_build_object('amenity', 'school', 'name', 'Lugnadalskolan')
    )
);
SELECT test(
    'keeps existing tags',
    jsonb_build_object(),
    tag_diff(
        jsonb_build_object('amenity', 'school', 'name', 'Lugnadalskolan'),
        jsonb_build_object('amenity', 'school')
    )
);
SELECT test(
    'removes a tag',
    jsonb_build_object('name', NULL),
    tag_diff(
        jsonb_build_object('amenity', 'school', 'name', 'Lugnadalskolan'),
        jsonb_build_object('amenity', 'school', 'name', NULL)
    )
);
SELECT test(
    'removes a tag',
    jsonb_build_object('name', NULL),
    tag_diff(
        jsonb_build_object('amenity', 'school', 'name', 'Lugnadalskolan'),
        jsonb_build_object('amenity', 'school', 'name', NULL)
    )
);
SELECT test(
    'prefers contact:email over email',
    jsonb_build_object('contact:email', 'hej@example.com'),
    tag_diff(
        jsonb_build_object(),
        jsonb_build_object('contact:email', 'hej@example.com')
    )
);
SELECT test(
    'does not add contact:email when email is already present',
    jsonb_build_object(),
    tag_diff(
        jsonb_build_object('email', 'hej@example.com'),
        jsonb_build_object('contact:email', 'hej@example.com')
    )
);
SELECT test(
    'suggests adding email (not contact:email) when phone is already present',
    jsonb_build_object('email', 'hej@example.com'),
    tag_diff(
        jsonb_build_object('phone', '+46123456'),
        jsonb_build_object('phone', '+46123456', 'contact:email', 'hej@example.com')
    )
);
SELECT test(
    'default to contact:email when tags are inconsistent',
    jsonb_build_object('contact:email', 'hej@example.com'),
    tag_diff(
        jsonb_build_object('phone', '+46123456', 'contact:website', 'http://example.com'),
        jsonb_build_object('phone', '+46123456', 'contact:email', 'hej@example.com')
    )
);
SELECT test(
    'default to contact:email when tags are inconsistent, but don''t add it if email exists',
    jsonb_build_object(),
    tag_diff(
        jsonb_build_object('phone', '+46123456', 'email', 'hej@example.com', 'contact:website', 'http://example.com'),
        jsonb_build_object('phone', '+46123456', 'contact:email', 'hej@example.com')
    )
);
