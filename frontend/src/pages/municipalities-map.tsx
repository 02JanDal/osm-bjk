import { FC, useCallback, useMemo } from "react";
import { useSuspenseQueries } from "@tanstack/react-query";
import postgrest from "../postgrest.ts";
import { ActionIcon, Popover, SegmentedControl, Select, rgba, useMantineTheme } from "@mantine/core";
import { differenceInMonths } from "date-fns";

import { IconPalette } from "@tabler/icons-react";
import {
  bestDatasetType,
  colorForDatasetUsage,
  colorForDeviationCount,
  colorForMonthsSinceCheck,
} from "../lib/colors.ts";
import { RLayerVectorTile, RMap, ROSM, RStyle } from "rlayers";
import { swedenInitial } from "../lib/map.ts";
import { MVT } from "ol/format";
import { Feature } from "ol";
import { createEnumParam, StringParam, useQueryParams } from "use-query-params";
import _ from "lodash";
import { useLocation } from "wouter";

const Page: FC = () => {
  const [query, setQuery] = useQueryParams({
    layer: StringParam,
    style: createEnumParam(["checked", "dataset", "deviations"]),
  });

  const [{ data: municipalities }, { data: layers }] = useSuspenseQueries({
    queries: [
      {
        queryKey: ["municipality"],
        queryFn: async () =>
          await postgrest
            .from("municipality")
            .select(
              "code,deviation_title(layer_id,count),municipality_dataset(datasetType:dataset_type,layer_id),municipality_layer(lastChecked:last_checked,layer_id)",
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
        <RLayerVectorTile
          url="https://osm.jandal.se/tiles/api.municipality/{z}/{x}/{y}.pbf"
          format={new MVT()}
          zIndex={20}
          onClick={(evt) => {
            const features = evt.map.getFeaturesAtPixel(evt.pixel, {
              layerFilter: (layer) => layer.getZIndex() === 20,
            });
            if (features.length > 0) {
              const code = features[0].get("code");
              setLocation(`/municipalities/${code}`);
            }
          }}
        >
          <RStyle.RStyle
            cacheSize={300}
            cacheId={(feature) => feature.get("code")}
            render={useCallback(
              (f: Feature) => {
                const currentStats = stats[f.get("code")];
                return query.style === "checked" ? (
                  <RStyle.RFill
                    color={rgba(
                      theme.colors[
                        colorForMonthsSinceCheck(
                          currentStats.lastChecked
                            ? differenceInMonths(new Date(), new Date(currentStats.lastChecked))
                            : undefined,
                        )
                      ][5],
                      0.7,
                    )}
                  />
                ) : query.style === "deviations" ? (
                  <RStyle.RFill
                    color={rgba(
                      currentStats.deviationsCount
                        ? theme.colors[colorForDeviationCount(currentStats.deviationsCount)][5]
                        : "#D3D3D3",
                      0.7,
                    )}
                  />
                ) : (
                  <RStyle.RFill color={rgba(theme.colors[colorForDatasetUsage(currentStats.datasetType)][5], 0.7)} />
                );
              },
              [stats, query.style, theme.colors],
            )}
          />
        </RLayerVectorTile>
      </RMap>
      <Popover width={200} position="left-start" withArrow arrowPosition="center" shadow="sm" defaultOpened>
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
            onChange={(v) => setQuery({ layer: v })}
            data={_.sortBy(layers.data!, "name").map((d) => ({
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
        </Popover.Dropdown>
      </Popover>
    </div>
  );
};
export default Page;
