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
