import { FC } from "react";
import { useSuspenseQueries } from "@tanstack/react-query";
import postgrest, { DatasetRow, DatasetUsage, LayerRow, MunicipalityRow, ProviderRow } from "../postgrest.ts";
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
import {
  bestDatasetType,
  colorForDatasetUsage,
  colorForDeviationCount,
  colorForMonthsSinceCheck,
} from "../lib/colors.ts";

const LastCheckIcon: FC<{ monthsSinceCheck: number | null }> = ({ monthsSinceCheck }) =>
  monthsSinceCheck === null ? (
    <IconClockX style={{ width: "70%", height: "70%", color: colorForMonthsSinceCheck(monthsSinceCheck) }} />
  ) : monthsSinceCheck < 6 ? (
    <IconClockCheck style={{ width: "70%", height: "70%", color: colorForMonthsSinceCheck(monthsSinceCheck) }} />
  ) : monthsSinceCheck < 24 ? (
    <IconClockQuestion style={{ width: "70%", height: "70%", color: colorForMonthsSinceCheck(monthsSinceCheck) }} />
  ) : (
    <IconClockExclamation style={{ width: "70%", height: "70%", color: colorForMonthsSinceCheck(monthsSinceCheck) }} />
  );
const DatasetUsageIcon: FC<{ usage: DatasetUsage | undefined }> = ({ usage }) =>
  usage === "advisory" ? (
    <IconDatabase style={{ width: "70%", height: "70%", color: colorForDatasetUsage(usage) }} />
  ) : usage === "complete" ? (
    <IconDatabaseStar style={{ width: "70%", height: "70%", color: colorForDatasetUsage(usage) }} />
  ) : (
    <IconDatabaseCog style={{ width: "70%", height: "70%", color: colorForDatasetUsage(usage) }} />
  );

const MunicipalityLayer: FC<{
  layer: LayerRow;
  datasets: {
    dataset:
      | (Omit<DatasetRow, "provider_id" | "url" | "license" | "fetched_at" | "short_name"> & {
          provider: Pick<ProviderRow, "name"> | null;
        })
      | null;
    datasetType?: DatasetUsage | null;
  }[];
  lastChecked?: string | null;
  municipality: Pick<MunicipalityRow, "name" | "code">;
  deviations: number;
}> = ({ lastChecked, datasets, municipality, layer, deviations }) => {
  const monthsSinceCheck = lastChecked ? differenceInMonths(new Date(), new Date(lastChecked)) : null;

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
            <LastCheckIcon monthsSinceCheck={monthsSinceCheck} />
          </ActionIcon>
        </Tooltip>
        {datasets.length === 0 ? null : datasets.length === 1 ? (
          <Tooltip label={`${datasets[0].dataset!.name} från ${datasets[0].dataset!.provider!.name}`}>
            <Link to={`/datasets/${datasets[0].dataset!.id}?municipality=${municipality.code}`}>
              <ActionIcon variant="transparent" color="black">
                <DatasetUsageIcon usage={datasets[0].datasetType ?? undefined} />
              </ActionIcon>
            </Link>
          </Tooltip>
        ) : (
          <ActionIcon variant="transparent" color="black">
            <DatasetUsageIcon usage={bestDatasetType(datasets)} />
          </ActionIcon>
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
              "code,name,region_name,deviation_title(layer_id,count),municipality_dataset(datasetType:dataset_type,projectLink:project_link,layer_id,dataset(id,name,provider(name))),municipality_layer(lastChecked:last_checked,layer_id)",
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
                    datasets={m.municipality_dataset.filter((ml) => ml.layer_id === l.id)}
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
