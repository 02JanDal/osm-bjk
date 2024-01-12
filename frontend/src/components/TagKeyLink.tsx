import { FC } from "react";
import { Anchor } from "@mantine/core";

export const TagKeyLink: FC<{ keyString: string }> = (props) => (
  <Anchor href={`https://wiki.openstreetmap.org/wiki/Key:${props.keyString}`} target="_blank">
    {props.keyString}
  </Anchor>
);
