interface iDParameters {
  background?: string; // ID from https://github.com/openstreetmap/iD/blob/develop/data/imagery.json
  comment?: string;
  disable_features?: (
    | "points"
    | "traffic_roads"
    | "service_roads"
    | "paths"
    | "buildings"
    | "building_parts"
    | "indoor"
    | "landuse"
    | "boundaries"
    | "water"
    | "rail"
    | "pistes"
    | "aerialways"
    | "power"
    | "past_future"
    | "others"
  )[];
  gpx?: string;
  hashtags?: string[];
  id?: ["node" | "way" | "relation", number];
  locale?: string;
  map?: [number, number, number];
  maprules?: string;
  offset?: [number, number];
  photo_overlay?: ("streetside" | "mapillary" | "mapillary-signs" | "mapillary-map-features" | "kartaview")[];
  photo_dates?: [string, string];
  photo_username?: string[];
  photo?: ["streetside" | "mapillary" | "kartaview", string];
  presets?: string[];
  source?: string;
}

export default function makeLink(params: iDParameters, url?: string): string {
  const search = new URLSearchParams();
  const hash = new URLSearchParams();

  if (params.background) {
    (url ? search : hash).set("background", params.background);
  }
  if (params.comment) {
    (url ? search : hash).set("comment", params.comment);
  }
  if (params.disable_features) {
    (url ? search : hash).set("disable_features", params.disable_features.join(","));
  }
  if (params.gpx) {
    (url ? search : hash).set("gpx", params.gpx);
  }
  if (params.hashtags) {
    (url ? search : hash).set("hashtags", params.hashtags.join(","));
  }
  if (params.id) {
    if (url) {
      search.set("id", `${params.id[0][0]}${params.id[1]}`);
    } else {
      search.set(params.id[0], `${params.id[1]}`);
    }
  }
  if (params.locale) {
    search.set("locale", params.locale);
  }
  if (params.map) {
    if (url) {
      search.set("map", params.map.join("/"));
    } else {
      search.set("zoom", `${params.map[0]}`);
      search.set("lat", `${params.map[1]}`);
      search.set("lon", `${params.map[2]}`);
    }
  }
  if (params.maprules) {
    (url ? search : hash).set("maprules", params.maprules);
  }
  if (params.offset) {
    (url ? search : hash).set("offset", `${params.offset[0]},${params.offset[1]}`);
  }
  if (params.photo_overlay) {
    (url ? search : hash).set("photo_overlay", params.photo_overlay.join(","));
  }
  if (params.photo_dates) {
    (url ? search : hash).set("photo_dates", params.photo_dates.join("_"));
  }
  if (params.photo_username) {
    (url ? search : hash).set("photo_username", params.photo_username.join(","));
  }
  if (params.photo) {
    (url ? search : hash).set("photo", params.photo.join("/"));
  }
  if (params.presets) {
    (url ? search : hash).set("presets", params.presets.join(","));
  }
  if (params.source) {
    (url ? search : hash).set("source", params.source);
  }

  if (url) {
    return `${url}?${search.toString()}`;
  } else {
    return `https://openstreetmap.org/edit${search.size > 0 ? "?" + search.toString() : ""}${
      hash.size > 0 ? "#" + hash.toString().replaceAll("+", "%20") : ""
    }`;
  }
}
