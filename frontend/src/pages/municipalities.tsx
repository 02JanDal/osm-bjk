import { FC } from "react";
import { useSuspenseQueries } from "@tanstack/react-query";
import postgrest, { DatasetRow, LayerRow, MunicipalityRow, ProviderRow } from "../postgrest.ts";
import { ActionIcon, Badge, Table, Tooltip } from "@mantine/core";
import { differenceInMonths } from "date-fns";

import classes from "./municipalities.module.css";
import {
  IconClockCheck,
  IconClockExclamation,
  IconClockQuestion,
  IconClockX,
  IconDatabase,
  IconDatabaseCog,
  IconDatabaseStar,
} from "@tabler/icons-react";
import { Link } from "wouter";
import { colorForDeviationCount } from "../lib/colors.ts";

const MunicipalityLayer: FC<{
  layer: LayerRow;
  dataset?:
    | (Omit<DatasetRow, "provider_id" | "url" | "license" | "fetched_at"> & {
        provider: Pick<ProviderRow, "name"> | null;
      })
    | null;
  datasetType?: "advisory" | "complete" | "automatic" | null;
  lastChecked?: string | null;
  municipality: Pick<MunicipalityRow, "name" | "code">;
  deviations: number;
}> = ({ lastChecked, datasetType, dataset, municipality, layer, deviations }) => {
  const monthsSinceCheck = lastChecked ? differenceInMonths(new Date(), new Date(lastChecked)) : undefined;

  return (
    <>
      <ActionIcon.Group>
        <Tooltip
          label={
            lastChecked
              ? `${layer.name} i ${municipality.name} kommun kontrollerades senast ${new Date(
                  lastChecked,
                ).toLocaleDateString()}`
              : `${layer.name} i ${municipality.name} kommun har aldrig kontrollerats (enligt detta system)`
          }
        >
          <ActionIcon variant="transparent" color="black">
            {monthsSinceCheck === undefined ? (
              <IconClockX style={{ width: "70%", height: "70%", color: "lightgrey" }} />
            ) : monthsSinceCheck < 6 ? (
              <IconClockCheck style={{ width: "70%", height: "70%", color: "darkgreen" }} />
            ) : monthsSinceCheck < 24 ? (
              <IconClockQuestion style={{ width: "70%", height: "70%", color: "lime" }} />
            ) : (
              <IconClockExclamation style={{ width: "70%", height: "70%", color: "orange" }} />
            )}
          </ActionIcon>
        </Tooltip>
        {datasetType === undefined || !dataset ? null : (
          <Tooltip label={`${dataset.name} från ${dataset.provider!.name}`}>
            <Link to={`/datasets/${dataset.id}?municipality=${municipality.code}`}>
              <ActionIcon variant="transparent" color="black">
                {datasetType === "advisory" ? (
                  <IconDatabase style={{ width: "70%", height: "70%", color: "lime" }} />
                ) : datasetType === "complete" ? (
                  <IconDatabaseStar style={{ width: "70%", height: "70%", color: "darkgreen" }} />
                ) : (
                  <IconDatabaseCog style={{ width: "70%", height: "70%", color: "blue" }} />
                )}
              </ActionIcon>
            </Link>
          </Tooltip>
        )}
        {deviations > 0 ? (
          <Link to={`/deviations?municipality=${municipality.code}&layer=${layer.id}`}>
            <ActionIcon variant="transparent">
              <Badge
                color={colorForDeviationCount(deviations)}
                style={{
                  display: "block",
                  overflow: "initial",
                  marginLeft: 10,
                  marginRight: 10,
                  paddingLeft: 5,
                  paddingRight: 5,
                }}
                radius="md"
              >
                {deviations}
              </Badge>
            </ActionIcon>
          </Link>
        ) : null}
      </ActionIcon.Group>
    </>
  );
};

const Page: FC = () => {
  const [{ data: municipalities }, { data: layers }] = useSuspenseQueries({
    queries: [
      {
        queryKey: ["municipality"],
        queryFn: async () =>
          await postgrest
            .from("municipality")
            .select(
              "code,name,region_name,deviation_title(layer_id,count),municipality_layer(datasetType:dataset_type,projectLink:project_link,lastChecked:last_checked,layer_id,dataset(id,name,provider(name)))",
            )
            .order("code")
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
    ],
  });

  return (
    <div style={{ overflow: "auto", position: "relative" }}>
      <Table>
        <Table.Thead>
          <Table.Tr>
            <Table.Th style={{ position: "sticky" }} />
            <Table.Th style={{ position: "sticky" }} />
            {layers?.data?.map((l) => (
              <Table.Th
                key={l.id}
                style={{
                  fontWeight: l.is_major ? undefined : "normal",
                }}
                className={classes.slanted}
                title={l.description}
              >
                <div>
                  <span>{l.name}</span>
                </div>
              </Table.Th>
            ))}
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {municipalities.data!.map((m, idx) => (
            <Table.Tr key={m.code}>
              {municipalities.data!.findIndex((m_) => m_.region_name === m.region_name) === idx ? (
                <Table.Th
                  rowSpan={municipalities.data!.filter((m_) => m_.region_name === m.region_name).length}
                  style={{
                    writingMode: "vertical-lr",
                    transform: "rotate(180deg)",
                    textAlign: "center",
                  }}
                >
                  {m.region_name}
                </Table.Th>
              ) : null}
              <Table.Td style={{ position: "sticky", left: 0, backgroundColor: "white" }}>
                <Link to={`/municipalities/${m.code}`}>{m.name}</Link>
              </Table.Td>
              {layers?.data?.map((l) => (
                <Table.Td key={l.id} style={{ borderLeft: "1px dashed var(--_table-border-color)" }}>
                  <MunicipalityLayer
                    {...m.municipality_layer.find((ml) => ml.layer_id === l.id)}
                    municipality={m}
                    layer={l}
                    deviations={
                      m.deviation_title
                        ?.filter((d) => d.layer_id === l.id)
                        .map((d) => d.count)
                        .reduce((prev, cur) => prev + cur, 0) || 0
                    }
                  />
                </Table.Td>
              ))}
            </Table.Tr>
          ))}
        </Table.Tbody>
      </Table>
    </div>
  );
};
export default Page;
