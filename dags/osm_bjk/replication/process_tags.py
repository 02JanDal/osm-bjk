from osmium.osm import TagList


def process_tags(tags: dict | TagList) -> dict:
    def process_tag(key: str, value: str):
        if key in ("fixme", "description", "source") or key.startswith("source:"):
            return value
        if ";" in value:
            return [process_tag(key, v) for v in value.split(";")]
        if value == "yes":
            return True
        elif value == "no":
            return False
#        if (
#                key in ("height", "width", "lanes", "admin_level", "beds", "beacon:frequency", "building:flats",
#                        "building:levels", "building:min_level", "cables", "capacity", "circuits", "class:bicycle:mtb",
#                        "cyclability", "depth", "depth:mean", "diameter", "diameter_crown", "direction", "distance",
#                        "ele", "frequency", "garages", "gauge", "gtfs:route_id", "gtfs_id", "gtfs_parent_station", "holes", "hoops", "layer", "length", "level", "lst:area_ha", "maxheight", "maxspeed", "gtfs:shape_id", "gtfs:stop_id")
#                or key.endswith(":width")
#                or key.endswith(":height")
#                or key.startswith("lanes:")
#                or key.startswith("admin_level:")
#                or key.endswith(":direction")
#                or key.startswith("building:levels:")
#                or key.startswith("capacity:")
#        ):
#            if value.isdecimal():
#                return int(value)
#            parts = value.split(".")
#            if len(parts) == 2 and parts[0].isdecimal() and parts[1].isdecimal():
#                return float(value)
        return value

    if isinstance(tags, dict):
        return {k: process_tag(k, v) for k, v in tags.items()}
    else:
        return {t.k: process_tag(t.k, t.v) for t in tags}
