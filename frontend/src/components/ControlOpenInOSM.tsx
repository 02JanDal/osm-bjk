import { FC, useCallback } from "react";
import { DeviationRow } from "../postgrest.ts";
import { RControl, useOL } from "rlayers";
import { actualElementId, actualElementType } from "../lib/osm.ts";
import { toLonLat } from "ol/proj";
import osmLogo from "../assets/osm_logo.svg";

export const ControlOpenInOSM: FC<{ deviation?: Pick<DeviationRow, "osm_element_id" | "osm_element_type"> }> = ({
  deviation,
}) => {
  const { map } = useOL();
  const open = useCallback(() => {
    const urlBase =
      deviation && deviation.osm_element_type && deviation.osm_element_id
        ? `https://openstreetmap.org/${actualElementType(
            deviation.osm_element_type,
            deviation.osm_element_id,
          )}/${actualElementId(deviation.osm_element_type, deviation.osm_element_id)}`
        : "https://openstreetmap.org/";
    const centerSWEREF = map.getView().getCenter();
    if (!centerSWEREF) {
      return;
    }
    const centerWGS84 = toLonLat([centerSWEREF[0], centerSWEREF[1]], "EPSG:3857");
    const url = `${urlBase}#map=${map.getView().getZoom()}/${centerWGS84[1]}/${centerWGS84[0]}`;
    window.open(url, "_blank");
  }, [map, deviation]);
  return (
    <RControl.RCustom className="open-in-osm">
      <button type="button" title="Öppna i OSM" onClick={open} style={{ padding: "2px" }}>
        <img src={osmLogo} style={{ width: "100%", height: "100%" }} />
      </button>
    </RControl.RCustom>
  );
};
