import { FC } from "react";
import postgrest from "../postgrest.ts";
import { useSuspenseQuery } from "@tanstack/react-query";
import { Anchor, Box, Button, Grid, Group, Stack, Table, Text } from "@mantine/core";
import { Link } from "wouter";
import { IconBug } from "@tabler/icons-react";
import { RFeature, RLayerVector, RLayerVectorTile, RMap, ROSM } from "rlayers";
import { GeoJSON, MVT } from "ol/format";
import { boundingExtent, getCenter } from "ol/extent";
import { fromLonLat } from "ol/proj";
import { Circle, Fill, Icon, Stroke, Style } from "ol/style";
import { FeatureLike } from "ol/Feature";
import { Point } from "ol/geom";

import arrow from "../assets/arrow-33-xxl.png";

const geojson = new GeoJSON();

function matchStyle(f: FeatureLike, resolution: number) {
  const state = f.get("state") as "not-in-osm" | "not-in-upstream" | "in-both";
  if (state === "not-in-osm") {
    return new Style({
      image: new Circle({
        stroke: new Stroke({ width: 2, color: "green" }),
        fill: new Fill({ color: "rgba(0, 255, 0, 0.7)" }),
        radius: 5,
      }),
    });
  } else if (state === "not-in-upstream") {
    return new Style({
      image: new Circle({
        stroke: new Stroke({ width: 2, color: "red" }),
        fill: new Fill({ color: "rgba(255, 0, 0, 0.7)" }),
        radius: 5,
      }),
    });
  } else {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const [xStart, yStart, xEnd, yEnd] = (f.getGeometry() as any).getFlatCoordinates();
    if (resolution < 10) {
      return [
        new Style({ stroke: new Stroke({ width: 2, color: "blue" }) }),
        new Style({
          geometry: new Point([xEnd, yEnd]),
          image: new Icon({
            src: arrow,
            anchor: [0.75, 0.5],
            rotateWithView: true,
            rotation: -Math.atan2(yEnd - yStart, xEnd - xStart),
            scale: 0.1,
          }),
        }),
      ];
    } else {
      return new Style({
        geometry: new Point([xEnd, yEnd]),
        image: new Circle({
          stroke: new Stroke({ width: 2, color: "blue" }),
          fill: new Fill({ color: "rgba(0, 0, 255, 0.7)" }),
          radius: 5,
        }),
      });
    }
  }
}

const Page: FC<{ params: { id: string } }> = ({ params }) => {
  const id = parseInt(params.id);

  const { data: dataset } = useSuspenseQuery({
    queryKey: ["dataset", id],
    queryFn: async () =>
      await postgrest.from("dataset").select("*,provider(name),extent").eq("id", id).single().throwOnError(),
  });

  const extent = dataset.data?.extent
    ? geojson.readGeometry(dataset.data!.extent).transform("EPSG:3006", "EPSG:3857")
    : null;

  return (
    <Grid grow w="100%" styles={{ inner: { height: "100%" } }}>
      <Grid.Col span={{ base: 12, sm: 5, md: 4, xl: 3 }}>
        <Stack h="100%" justify="space-between">
          <Stack>
            <Table>
              <Table.Tbody>
                <Table.Tr>
                  <Table.Th>Källa:</Table.Th>
                  <Table.Td>{dataset.data!.provider?.name}</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Th>Namn:</Table.Th>
                  <Table.Td>{dataset.data!.name}</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Th>Mer information:</Table.Th>
                  <Table.Td>
                    <Anchor href={dataset.data!.url}>{new URL(dataset.data!.url).host.replace("www.", "")}</Anchor>
                  </Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Th>Licens:</Table.Th>
                  <Table.Td>
                    <Anchor href={dataset.data!.license}>
                      {dataset.data!.license === "https://creativecommons.org/publicdomain/zero/1.0/" ? "CC 0" : null}
                    </Anchor>
                  </Table.Td>
                </Table.Tr>
              </Table.Tbody>
            </Table>
            <Link to={`/deviations?dataset=${dataset.data!.id}`}>
              <Button variant="filled" justify="center" fullWidth leftSection={<IconBug />}>
                Visa avvikelser
              </Button>
            </Link>
          </Stack>
          <Stack gap={0}>
            <Group style={{ flexWrap: "nowrap" }} gap="xs">
              <Box w={15} h={15} bg="green" style={{ border: "2px solid green", borderRadius: "100%" }} />
              <div>Saknas i OpenStreetMap</div>
            </Group>
            <Group style={{ flexWrap: "nowrap" }} gap="xs">
              <Box w={15} h={15} bg="red" style={{ border: "2px solid red", borderRadius: "100%" }} />
              <div>Saknas i datakällan</div>
            </Group>
            <Group style={{ flexWrap: "nowrap", alignItems: "flex-start" }} gap="xs">
              <Box w={15} h={15} bg="blue" style={{ border: "2px solid blue", borderRadius: "100%", marginTop: 5 }} />
              <div>
                Matchning hittad
                <br />
                <Text fz="sm" c="dimmed">
                  Pil pekar från objekt i datakällan till objekt i OSM
                </Text>
              </div>
            </Group>
          </Stack>
        </Stack>
      </Grid.Col>
      <Grid.Col span={{ base: 12, sm: 7, md: 8, xl: 9 }}>
        <div
          style={{
            position: "fixed",
            top: "var(--app-shell-header-height)",
            left: "calc(var(--grid-gutter) + (100% - var(--col-flex-basis)))",
            right: 0,
            bottom: 0,
          }}
        >
          <RMap
            width="100%"
            height="100%"
            initial={{
              center: getCenter(
                extent ? extent.getExtent() : boundingExtent([fromLonLat([10.03, 54.96]), fromLonLat([24.17, 69.07])]),
              ),
              zoom: 5,
            }}
          >
            <ROSM />
            {extent ? (
              <RLayerVector zIndex={10}>
                <RFeature geometry={extent} />
              </RLayerVector>
            ) : null}
            {dataset.data?.view_name ? (
              <RLayerVectorTile
                url={`https://osm.jandal.se/tiles/api.tile_match_${dataset.data.view_name}/{z}/{x}/{y}.pbf`}
                format={new MVT()}
                zIndex={20}
                minZoom={10}
                style={matchStyle}
              />
            ) : null}
          </RMap>
        </div>
      </Grid.Col>
    </Grid>
  );
};
export default Page;
