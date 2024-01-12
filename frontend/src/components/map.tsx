import { MVT } from "ol/format";
import React, { FC } from "react";
import { RLayerVectorTile, RStyle, RLayerVectorTileProps } from "rlayers";
import { Feature } from "ol";
import Geometry from "ol/geom/Geometry";

export const MunicipalityVectorTiles: FC<
  { style: (feature: Feature<Geometry>, resolution: number) => React.ReactElement } & Omit<
    RLayerVectorTileProps,
    "url" | "format" | "style"
  >
> = ({ style, ...rest }) => {
  return (
    <RLayerVectorTile
      url="https://osm.jandal.se/tiles/api.municipality/{z}/{x}/{y}.pbf"
      format={new MVT()}
      zIndex={20}
      {...rest}
    >
      <RStyle.RStyle cacheSize={300} cacheId={(feature) => feature.get("code")} render={style} />{" "}
    </RLayerVectorTile>
  );
};
