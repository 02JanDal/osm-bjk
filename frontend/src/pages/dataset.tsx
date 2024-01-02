import { FC } from "react";
import postgrest from "../postgrest.ts";
import { useSuspenseQuery } from "@tanstack/react-query";
import { Anchor, Button, Grid, Table } from "@mantine/core";
import { Link } from "wouter";
import { IconBug } from "@tabler/icons-react";
import { RFeature, RLayerVector, RMap, ROSM } from "rlayers";
import { GeoJSON } from "ol/format";
import { boundingExtent, getCenter } from "ol/extent";
import { fromLonLat } from "ol/proj";

const geojson = new GeoJSON();

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
          </RMap>
        </div>
      </Grid.Col>
    </Grid>
  );
};
export default Page;
