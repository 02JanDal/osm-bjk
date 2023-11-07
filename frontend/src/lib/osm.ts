const BASE = "https://api.openstreetmap.org";

type OSMElementType = "node" | "way" | "relation";

interface OSMElementBase {
  type: OSMElementType;
  id: number;
  timestamp: string;
  version: number;
  changeset: number;
  user: string;
  uid: number;
  tags: Record<string, string>;
}
interface OSMElementNode extends OSMElementBase {
  type: "node";
  lat: number;
  lon: number;
}
interface OSMElementWay extends OSMElementBase {
  type: "way";
  nodes: number[];
}
interface OSMElementRelation extends OSMElementBase {
  type: "relation";
}
type OSMElement = OSMElementRelation | OSMElementWay | OSMElementNode;

interface OSMUser {
  id: number;
  display_name: string;
}

export function actualElementType(type: OSMElementType | "area" | "a" | "n" | "w" | "r", id: number): OSMElementType {
  if (type === "a" || type === "area") {
    return id > 3600000000 ? "relation" : "way";
  } else if (type === "n" || type === "w" || type === "r") {
    return { n: "node" as const, w: "way" as const, r: "relation" as const }[type];
  } else {
    return type;
  }
}
export function actualElementId(type: OSMElementType | "area" | "a" | "n" | "w" | "r", id: number) {
  return type[0] === "area" && id > 3600000000 ? id - 3600000000 : id;
}

export async function getElement(type: OSMElementType | "area" | "a" | "n" | "w" | "r", id: number) {
  const resp = await fetch(`${BASE}/api/0.6/${actualElementType(type, id)}/${actualElementId(type, id)}`, {
    headers: { Accept: "application/json" },
  });
  if (!resp.ok) {
    throw new Error(await resp.text());
  }
  return (await resp.json()).elements[0] as OSMElement;
}

export async function getUser(id: number) {
  const resp = await fetch(`${BASE}/api/0.6/user/${id}`, { headers: { Accept: "application/json" } });
  if (!resp.ok) {
    throw new Error(await resp.text());
  }
  return (await resp.json()).user as OSMUser;
}
