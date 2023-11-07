import { FC } from "react";
import postgrest from "../postgrest.ts";
import { useSuspenseQueries, useSuspenseQuery } from "@tanstack/react-query";
import { ActionIcon, Anchor, Grid, Table } from "@mantine/core";
import TimeAgo from "../components/TimeAgo.tsx";
import { Link } from "wouter";
import _ from "lodash";
import { IconBug } from "@tabler/icons-react";
import { getUser } from "../lib/osm.ts";

const UserName: FC<{ userId: number }> = (props) => {
  const { data } = useSuspenseQuery({
    queryKey: ["osm-user", props.userId],
    queryFn: async () => await getUser(props.userId),
  });
  return data.display_name;
};

const Page: FC<{ params: { code: string } }> = ({ params }) => {
  const [{ data: municipalityData }, { data: layersData }, { data: deviationsData }] = useSuspenseQueries({
    queries: [
      {
        queryKey: ["municipality", params.code],
        queryFn: async () =>
          await postgrest
            .from("municipality")
            .select(
              "*,region_name,municipality_layer(datasetType:dataset_type,projectLink:project_link,lastChecked:last_checked,lastCheckedBy:last_checked_by,layer(id),dataset(id,name,provider(name)))",
            )
            .eq("code", params.code)
            .single()
            .throwOnError(),
      },
      {
        queryKey: ["layer"],
        queryFn: async () =>
          await postgrest
            .from("layer")
            .select("*")
            .order("is_major", { ascending: false })
            .order("name")
            .throwOnError(),
      },
      {
        queryKey: ["deviation_title", params.code],
        queryFn: async () =>
          await postgrest.from("deviation_title").select("*").eq("municipality_code", params.code).throwOnError(),
      },
    ],
  });
  const municipality = municipalityData.data!;
  const layers = layersData.data!;
  const deviations = deviationsData.data!;

  return (
    <Grid grow w="100%" styles={{ inner: { height: "100%" } }}>
      <Grid.Col span={{ base: 12, sm: 5, md: 4, xl: 3 }}>
        <h2 style={{ marginTop: 0 }}>{municipality.name}</h2>
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Avvikelse</Table.Th>
              <Table.Th>Antal</Table.Th>
              <Table.Th />
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {Object.entries(_.groupBy(deviations, "title")).map(([title, lyrs]) => (
              <Table.Tr key={title}>
                <Table.Td>{title}</Table.Td>
                <Table.Td>{lyrs.reduce((prev, cur) => prev + cur.count, 0)}</Table.Td>
                <Table.Td>
                  <Link to={`/deviations?municipality=${municipality.code}&deviation=${title}`}>
                    <ActionIcon variant="filled">
                      <IconBug style={{ width: "70%", height: "70%" }} stroke={1.5} />
                    </ActionIcon>
                  </Link>
                </Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      </Grid.Col>
      <Grid.Col span={{ base: 12, sm: 7, md: 8, xl: 9 }}>
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Företeelse</Table.Th>
              <Table.Th>Senast kontrollerad</Table.Th>
              <Table.Th>Avvikelser</Table.Th>
              <Table.Th>Datakälla</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {layers.map((layer) => {
              const ml = municipality.municipality_layer.find((ml) => ml.layer!.id === layer.id);
              const deviationCount = deviations
                .filter((d) => d.layer_id === layer.id)
                .reduce((prev, cur) => prev + cur.count, 0);
              const Component = layer.is_major ? Table.Th : Table.Td;
              return (
                <Table.Tr key={layer.id}>
                  <Component>
                    <abbr title={layer.description}>{layer.name}</abbr>
                  </Component>
                  <Table.Td>
                    {ml && ml.lastChecked ? (
                      <>
                        <TimeAgo date={ml.lastChecked} /> av <UserName userId={ml.lastCheckedBy!} />
                      </>
                    ) : null}
                  </Table.Td>
                  <Table.Td>
                    {deviationCount > 0 ? (
                      <>
                        {deviationCount}{" "}
                        <Link to={`/deviations?municipality=${municipality.code}&layer=${layer.id}`}>
                          <ActionIcon variant="filled">
                            <IconBug style={{ width: "70%", height: "70%" }} stroke={1.5} />
                          </ActionIcon>
                        </Link>
                      </>
                    ) : null}
                  </Table.Td>
                  <Table.Td>
                    {ml && ml.dataset ? (
                      <Anchor component={Link} to={`/datasets/${ml.dataset.id}`}>
                        {ml.dataset.name} ({ml.dataset.provider!.name})
                      </Anchor>
                    ) : null}
                  </Table.Td>
                </Table.Tr>
              );
            })}
          </Table.Tbody>
        </Table>
      </Grid.Col>
    </Grid>
  );
};
export default Page;
