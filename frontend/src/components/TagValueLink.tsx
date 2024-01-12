import { FC } from "react";
import { Anchor } from "@mantine/core";

export const TagValueLink: FC<{ keyString: string; value: string }> = (props) => (
  <>
    {["amenity", "building", "landuse"].includes(props.keyString) ? (
      <Anchor href={`https://wiki.openstreetmap.org/wiki/Tag:${props.keyString}%3D${props.value}`} target="_blank">
        {props.value}
      </Anchor>
    ) : props.keyString.endsWith("wikidata") ? (
      <Anchor href={`https://www.wikidata.org/wiki/${props.value}`} target="_blank">
        {props.value}
      </Anchor>
    ) : ["url", "website", "contact:website"].includes(props.keyString) ? (
      <Anchor href={props.value} target="_blank">
        {props.value}
      </Anchor>
    ) : (
      props.value
    )}
  </>
);
