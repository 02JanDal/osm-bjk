import { FC, useState } from "react";
import postgrest from "../postgrest.ts";
import { useSuspenseQueries } from "@tanstack/react-query";
import { ActionIcon, Anchor, Box, Group, MultiSelect, Table, TextInput } from "@mantine/core";
import { Link } from "wouter";
import { IconBug, IconExternalLink, IconMap } from "@tabler/icons-react";

const Page: FC = () => {
  const [{ data: datasets }, { data: providers }] = useSuspenseQueries({
    queries: [
      {
        queryKey: ["dataset"],
        queryFn: async () => await postgrest.from("dataset").select("*,provider(name)").throwOnError(),
      },
      {
        queryKey: ["provider"],
        queryFn: async () => await postgrest.from("provider").select("*").throwOnError(),
      },
    ],
  });

  const [search, setSearch] = useState("");
  const [filterProviders, setFilterProviders] = useState<string[]>([]);
  const filteredDatasets = datasets.data!.filter(
    (d) =>
      (d.name.toLowerCase().includes(search.toLowerCase()) ||
        (!Array.isArray(d.provider) && d.provider?.name.toLowerCase().includes(search.toLowerCase()))) &&
      (filterProviders.length === 0 || filterProviders.includes(String(d.provider_id))),
  );

  return (
    <Box w="100%">
      <Group grow mb={16}>
        <MultiSelect
          value={filterProviders}
          onChange={setFilterProviders}
          data={providers.data?.map((p) => ({ value: String(p.id), label: p.name }))}
          clearable
          label="Källor"
        />
        <TextInput value={search} onChange={(evt) => setSearch(evt.target.value)} label="Sök" />
      </Group>
      <Table>
        <Table.Thead>
          <Table.Tr>
            <Table.Th>Källa</Table.Th>
            <Table.Th>Namn</Table.Th>
            <Table.Th />
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {filteredDatasets.map((d) => (
            <Table.Tr key={d.id}>
              <Table.Td>{d.provider?.name}</Table.Td>
              <Table.Td>
                <Link to={`/datasets/${d.id}`}>
                  <Anchor>{d.name}</Anchor>
                </Link>
              </Table.Td>
              <Table.Td>
                <ActionIcon.Group>
                  <Link to={`/datasets/${d.id}`}>
                    <ActionIcon>
                      <IconMap style={{ width: "70%", height: "70%" }} />
                    </ActionIcon>
                  </Link>
                  <ActionIcon component={"a"} href={d.url} target="_blank">
                    <IconExternalLink style={{ width: "70%", height: "70%" }} />
                  </ActionIcon>
                  <Link to={`/deviations?dataset=${d.id}`}>
                    <ActionIcon>
                      <IconBug style={{ width: "70%", height: "70%" }} />
                    </ActionIcon>
                  </Link>
                </ActionIcon.Group>
              </Table.Td>
            </Table.Tr>
          ))}
        </Table.Tbody>
      </Table>
    </Box>
  );
};
export default Page;
