SELECT test(
    '',
    jsonb_build_array(jsonb_build_object('leisure', 'bathing_place', 'name', 'Hello'), jsonb_build_object('leisure', 'swimming_area', 'name', 'Hello')),
    tag_alternatives(
        ARRAY[jsonb_build_object('leisure', 'bathing_place'), jsonb_build_object('leisure', 'swimming_area')],
        jsonb_build_object('name', 'Hello')
    )
);
