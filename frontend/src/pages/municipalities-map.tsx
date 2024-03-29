import { FC, useCallback, useMemo } from "react";
import { useSuspenseQueries } from "@tanstack/react-query";
import postgrest from "../postgrest.ts";
import {
  ActionIcon,
  Popover,
  SegmentedControl,
  Select,
  rgba,
  useMantineTheme,
  Title,
  Stack,
  Group,
  Box,
} from "@mantine/core";
import { differenceInMonths } from "date-fns";

import { IconPalette } from "@tabler/icons-react";
import {
  ABOVE,
  bestDatasetType,
  colorForDatasetUsage,
  colorForDeviationCount,
  colorForMonthsSinceCheck,
  COLORS_FOR_DATASET_USAGE,
  COLORS_FOR_DEVIATION_COUNT,
  COLORS_FOR_MONTHS_SINCE_CHECK,
} from "../lib/colors.ts";
import { RMap, ROSM, RStyle } from "rlayers";
import { swedenInitial } from "../lib/map.ts";
import { Feature } from "ol";
import { createEnumParam, StringParam, useQueryParams, withDefault } from "use-query-params";
import _ from "lodash";
import { useLocation } from "wouter";
import { MunicipalityVectorTiles } from "../components/map.tsx";

const CheckedLegend: FC = () => (
  <Stack gap={0}>
    {COLORS_FOR_MONTHS_SINCE_CHECK.map(([count, color], idx) => (
      <Group key={idx}>
        <Box w={10} h={10} bg={color} />
        {count === null
          ? "Aldrig kontrollerat"
          : count === ABOVE
            ? `Mer än ${COLORS_FOR_MONTHS_SINCE_CHECK.slice(-3, -2)[0][0] as number} månader sedan`
            : `${count} eller färre månader sedan`}
      </Group>
    ))}
  </Stack>
);
const DatasetUsageLegend: FC = () => (
  <Stack gap={0}>
    {COLORS_FOR_DATASET_USAGE.map(([dataset, color], idx) => (
      <Group key={idx}>
        <Box w={10} h={10} bg={color} />
        {dataset === ABOVE
          ? "Datakälla saknas"
          : dataset === "advisory"
            ? "Vägledande"
            : dataset === "complete"
              ? "Fullständig"
              : "Automatisk"}
      </Group>
    ))}
  </Stack>
);
const DeviationCountLegend: FC = () => (
  <Stack gap={0}>
    {COLORS_FOR_DEVIATION_COUNT.map(([count, color], idx) => (
      <Group key={idx}>
        <Box w={10} h={10} bg={color} />
        {count === ABOVE
          ? `Fler än ${COLORS_FOR_DEVIATION_COUNT.slice(-2, -1)[0][0] as number}`
          : count === 0
            ? "Inga avvikelser"
            : `${count} eller färre`}
      </Group>
    ))}
  </Stack>
);

const Page: FC = () => {
  const [query, setQuery] = useQueryParams({
    layer: withDefault(StringParam, "1"),
    style: withDefault(createEnumParam(["checked", "dataset", "deviations"]), "checked"),
  });

  const [{ data: municipalities }, { data: layers }] = useSuspenseQueries({
    queries: [
      {
        queryKey: ["municipality-for-map"],
        queryFn: async () =>
          await postgrest
            .from("municipality")
            .select(
              "code,deviation_title(layer_id,count),municipality_dataset(datasetType:dataset_type,layer_id),municipality_layer(lastChecked:last_checked,layer_id)",
            )
            .throwOnError(),
      },
      {
        queryKey: ["layer"],
        queryFn: async () => await postgrest.from("layer").select("*").throwOnError(),
      },
    ],
  });

  const stats = useMemo(() => {
    return Object.fromEntries(
      municipalities.data!.map((m) => [
        m.code,
        {
          deviationsCount: m.deviation_title
            .filter((d) => String(d.layer_id) === query.layer)
            .reduce((a, b) => a + b.count, 0),
          lastChecked: m.municipality_layer.find((l) => String(l.layer_id) === query.layer)?.lastChecked,
          datasetType: bestDatasetType(m.municipality_dataset.filter((d) => String(d.layer_id) === query.layer)),
        },
      ]),
    );
  }, [municipalities.data, query.layer]);

  const theme = useMantineTheme();
  const [_l, setLocation] = useLocation();

  return (
    <div
      style={{
        position: "fixed",
        top: "var(--app-shell-header-height)",
        left: 0,
        right: 0,
        bottom: 0,
      }}
    >
      <RMap width="100%" height="100%" initial={swedenInitial}>
        <ROSM />
        <MunicipalityVectorTiles
          onClick={(evt) => {
            const features = evt.map.getFeaturesAtPixel(evt.pixel, {
              layerFilter: (layer) => layer.getZIndex() === 20,
            });
            if (features.length > 0) {
              const code = features[0].get("code");
              setLocation(`/municipalities/${code}`);
            }
          }}
          style={useCallback(
            (f: Feature) => {
              const currentStats = stats[f.get("code")];
              return query.style === "checked" ? (
                <RStyle.RFill
                  color={rgba(
                    theme.colors[
                      colorForMonthsSinceCheck(
                        currentStats.lastChecked
                          ? differenceInMonths(new Date(), new Date(currentStats.lastChecked))
                          : null,
                      )
                    ][5],
                    0.7,
                  )}
                />
              ) : query.style === "deviations" ? (
                <RStyle.RFill
                  color={rgba(theme.colors[colorForDeviationCount(currentStats.deviationsCount)][5], 0.7)}
                />
              ) : (
                <RStyle.RFill color={rgba(theme.colors[colorForDatasetUsage(currentStats.datasetType)][5], 0.7)} />
              );
            },
            [stats, query.style, theme.colors],
          )}
        />
      </RMap>
      <Popover
        width={query.style === "checked" ? 300 : 200}
        position="left-start"
        withArrow
        arrowPosition="center"
        shadow="sm"
        defaultOpened
      >
        <Popover.Target>
          <ActionIcon
            style={{
              position: "fixed",
              top: "calc(var(--app-shell-header-height) + var(--mantine-spacing-xs))",
              right: "var(--mantine-spacing-xs)",
            }}
            variant="default"
            size="xl"
          >
            <IconPalette />
          </ActionIcon>
        </Popover.Target>
        <Popover.Dropdown>
          <Select
            value={query.layer}
            onChange={(v) => setQuery({ layer: v || "checked" })}
            data={_.sortBy(layers.data!, "is_major", "name").map((d) => ({
              value: String(d.id),
              label: d.name,
            }))}
            searchable
            label="Företeelser"
            comboboxProps={{ withinPortal: false }}
          />
          <SegmentedControl
            value={query.style ?? "checked"}
            onChange={(v) => setQuery({ style: v as "checked" | "dataset" | "deviations" })}
            fullWidth
            data={[
              { value: "checked", label: "Senaste kontroll" },
              { value: "dataset", label: "Datakälla tillgänglig" },
              { value: "deviations", label: "Avvikelser" },
            ]}
            orientation="vertical"
            style={{ marginTop: "var(--mantine-spacing-xs)" }}
            disabled={!query.layer}
          />

          <Title order={5} mt="sm">
            Färgförklaring
          </Title>
          {query.style === "checked" ? (
            <CheckedLegend />
          ) : query.style === "dataset" ? (
            <DatasetUsageLegend />
          ) : (
            <DeviationCountLegend />
          )}
        </Popover.Dropdown>
      </Popover>
    </div>
  );
};
export default Page;
