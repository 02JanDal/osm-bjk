import { FC, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ArrayParam, useQueryParams } from "use-query-params";
import { Button, Grid, MultiSelect, Stack } from "@mantine/core";
import { useQuery, useSuspenseQueries } from "@tanstack/react-query";
import postgrest, { MunicipalityRow } from "../postgrest";
import _ from "lodash";
import { RLayerVectorTile, RMap, ROSM, RStyle, useOL } from "rlayers";
import { GeoJSON, MVT } from "ol/format";
import { boundingExtent } from "ol/extent";
import classes from "./deviations.module.css";
import { Link, useLocation } from "wouter";
import { Feature, Overlay } from "ol";
import { importUrl } from "../lib/josm.ts";
import { swedenExtent, swedenInitial } from "../lib/map.ts";

const geojson = new GeoJSON();

const Zoomer: FC<{ selected: string[]; municipalities: Pick<MunicipalityRow, "code" | "extent">[] }> = ({
  selected,
  municipalities,
}) => {
  const { map } = useOL();

  const selectedExtent = useMemo(
    () =>
      selected.length > 0
        ? boundingExtent(
            municipalities
              .filter((m) => selected.includes(m.code))
              .map((m) => geojson.readGeometry(m.extent).transform("EPSG:3006", "EPSG:3857").getExtent())
              .flatMap(([minx, miny, maxx, maxy]) => [
                [minx, miny],
                [maxx, maxy],
              ]),
          )
        : undefined,
    [selected, municipalities],
  );

  useEffect(() => {
    map.getView().fit(selectedExtent ?? swedenExtent);
  }, [map, selectedExtent]);

  return null;
};

const Page: FC = () => {
  const [query, setQuery] = useQueryParams({
    dataset: ArrayParam,
    municipality: ArrayParam,
    layer: ArrayParam,
    deviation: ArrayParam,
  });

  const [{ data: datasets }, { data: municipalities }, { data: layers }] = useSuspenseQueries({
    queries: [
      {
        queryKey: ["dataset"],
        queryFn: async () => await postgrest.from("dataset").select("*,provider(name)").throwOnError(),
        staleTime: 1000 * 60 * 60,
      },
      {
        queryKey: ["municipality-extent"],
        queryFn: async () => await postgrest.from("municipality").select("name,code,extent,region_name").throwOnError(),
        staleTime: 1000 * 60 * 60,
      },
      {
        queryKey: ["layer"],
        queryFn: async () => await postgrest.from("layer").select("*").throwOnError(),
        staleTime: 1000 * 60 * 60,
      },
    ],
  });

  const { data: deviationTitlesData } = useQuery({
    queryKey: ["deviation_title"],
    queryFn: async () => postgrest.from("deviation_title").select("*"),
    staleTime: 1000 * 60 * 15, // 15min
  });
  const deviationTitles =
    deviationTitlesData?.data?.filter(
      (d) =>
        (!query.municipality?.length || query.municipality.includes(d.municipality_code)) &&
        (!query.dataset?.length || query.dataset.includes(String(d.dataset_id))) &&
        (!query.layer?.length || query.layer.includes(String(d.layer_id))) &&
        (!query.deviation?.length || query.deviation.includes(d.title)),
    ) || [];
  const colors = useMemo(
    () =>
      Object.fromEntries(
        _.uniq(deviationTitlesData?.data?.map((d) => d.title) || []).map((title, idx, list) => [
          title,
          [`hsl(${(idx * 360) / list.length}deg 80% 50%)`, `hsl(${(idx * 360) / list.length}deg 80% 40%)`],
        ]),
      ),
    [deviationTitlesData?.data],
  );

  const countResults = deviationTitles.reduce((prev, cur) => prev + cur.count, 0);
  const cql = [
    query.municipality?.length
      ? `municipality_code IN (${query.municipality.map((code) => `'${code}'`).join(",")})`
      : undefined,
    query.dataset?.length ? `dataset_id IN (${query.dataset.map((code) => `${code}`).join(",")})` : undefined,
    query.layer?.length ? `layer_id IN (${query.layer.map((code) => `${code}`).join(",")})` : undefined,
    query.deviation?.length ? `title IN (${query.deviation.map((code) => `'${code}'`).join(",")})` : undefined,
  ]
    .filter((v) => v)
    .join(" AND ");

  const [_loc, navigate] = useLocation();

  const popupRef = useRef<Overlay | undefined>();
  const popupElementRef = useRef<HTMLDivElement>(null);
  const [selectedFeatures, setSelectedFeatures] = useState<Feature[]>([]);

  const osmChangeUrl = useMemo(() => {
    const search = new URLSearchParams();
    if (query.municipality?.length) {
      search.set("municipalities", `{${query.municipality.join(",")}}`);
    }
    if (query.dataset?.length) {
      search.set("dataset_ids", `{${query.dataset.join(",")}}`);
    }
    if (query.layer?.length) {
      search.set("layer_ids", `{${query.layer.join(",")}}`);
    }
    if (query.deviation?.length) {
      search.set("titles", `{${query.deviation.join(",")}}`);
    }
    return `https://osm.jandal.se/api/rpc/osmchange?${search.toString()}`;
  }, [query]);

  return (
    <Grid grow w="100%" styles={{ inner: { height: "100%" } }}>
      <Grid.Col span={{ base: 0, sm: 4, md: 3, lg: 3, xl: 2 }}>
        <Stack h="100%">
          <MultiSelect
            value={(query.dataset as string[]) || []}
            onChange={(v) => setQuery({ dataset: v.length === 0 ? undefined : v })}
            data={_.sortBy(
              Object.entries(_.groupBy(datasets.data!, "provider.name")).map(([group, items]) => ({
                group,
                items: _.sortBy(
                  items.map((d) => ({
                    value: String(d.id),
                    label: d.name,
                    disabled: !deviationTitles.some((d_) => d_.dataset_id === d.id),
                  })),
                  "disabled",
                ),
              })),
              ({ items }) => items.every((i) => i.disabled),
              "group",
            )}
            clearable
            searchable
            label="Datakällor"
          />
          <MultiSelect
            value={(query.municipality as string[]) || []}
            onChange={(v) => setQuery({ municipality: v.length === 0 ? undefined : v })}
            data={Object.entries(_.groupBy(municipalities.data!, "region_name")).map(([group, items]) => ({
              group,
              items: items.map((d) => ({
                value: d.code,
                label: d.name,
                disabled: !deviationTitles.some((d_) => d_.municipality_code === d.code),
              })),
            }))}
            clearable
            searchable
            label="Kommuner"
          />
          <MultiSelect
            value={(query.layer as string[]) || []}
            onChange={(v) => setQuery({ layer: v.length === 0 ? undefined : v })}
            data={layers.data!.map((d) => ({
              value: String(d.id),
              label: d.name,
              disabled: !deviationTitles.some((d_) => d_.layer_id === d.id),
            }))}
            clearable
            searchable
            label="Företeelser"
          />
          <MultiSelect
            value={(query.deviation as string[]) || []}
            onChange={(v) => setQuery({ deviation: v.length === 0 ? undefined : v })}
            data={deviationTitles
              ?.filter((d, idx, all) => all.findIndex((d_) => d.title === d_.title) == idx)
              .map((d) => ({ value: d.title, label: d.title }))}
            clearable
            searchable
            label="Typ"
          />
          <hr
            style={{ margin: 0, border: "none", borderBottom: "1px solid var(--mantine-color-gray-4)", width: "100%" }}
          />
          <Button.Group orientation="vertical">
            <Button variant="light" component="a" href={osmChangeUrl}>
              Hämta osmChange
            </Button>
            <Button
              variant="light"
              onClick={() => {
                importUrl(osmChangeUrl, {
                  changesetTags: {
                    hashtags: "#bastajavlakartan",
                  },
                });
              }}
            >
              Öppna alla i JOSM
            </Button>
          </Button.Group>
          <p style={{ marginTop: "auto", marginBottom: "calc(-1 * var(--grid-gutter)/2)" }}>
            Hittade {countResults} avvikelser
          </p>
        </Stack>
      </Grid.Col>
      <Grid.Col span={{ base: 12, sm: 8, md: 9, lg: 9, xl: 10 }}>
        <div
          style={{
            position: "fixed",
            top: "var(--app-shell-header-height)",
            left: "calc(var(--grid-gutter) + (100% - var(--col-flex-basis)))",
            right: 0,
            bottom: 0,
          }}
        >
          <RMap width="100%" height="100%" initial={swedenInitial}>
            <Zoomer selected={(query.municipality as string[]) || []} municipalities={municipalities.data!} />
            <ROSM />
            <RLayerVectorTile
              url="https://osm.jandal.se/tiles/api.municipality/{z}/{x}/{y}.pbf"
              format={new MVT()}
              zIndex={20}
            >
              <RStyle.RStyle
                cacheSize={300}
                cacheId={(feature) => feature.get("code")}
                render={useCallback(
                  (f: Feature) => (
                    <RStyle.RStroke
                      width={query.municipality?.includes(f.get("code")) === false ? 1 : 2}
                      color={
                        query.municipality?.includes(f.get("code")) === false
                          ? "rgba(0, 0, 255, 0.5)"
                          : "rgba(0, 0, 255, 1.0)"
                      }
                    />
                  ),
                  [query.municipality],
                )}
              />
            </RLayerVectorTile>
            <RLayerVectorTile
              url={`https://osm.jandal.se/tiles/api.deviation/{z}/{x}/{y}.pbf?filter=${encodeURIComponent(cql)}`}
              format={new MVT()}
              zIndex={20}
              onClick={(evt) => {
                const features = evt.map.getFeaturesAtPixel(evt.pixel, {
                  layerFilter: (layer) => layer.getZIndex() === 20,
                });
                if (features.length === 1) {
                  navigate(`/deviations/${features[0].getId()}`);
                  setSelectedFeatures([]);
                } else {
                  setSelectedFeatures(features as Feature[]);
                }

                if (!popupRef.current) {
                  popupRef.current = new Overlay({
                    element: popupElementRef.current!,
                  });
                  evt.map.addOverlay(popupRef.current!);
                }

                popupRef.current!.setPosition(evt.coordinate);
              }}
            >
              <RStyle.RStyle
                cacheSize={100}
                cacheId={(feature) => feature.get("title")}
                render={useCallback(
                  (f: Feature) => (
                    <RStyle.RCircle radius={5}>
                      <RStyle.RStroke width={2} color={colors[f.get("title")][0]} />
                      <RStyle.RFill color={colors[f.get("title")][1]} />
                    </RStyle.RCircle>
                  ),
                  [colors],
                )}
              ></RStyle.RStyle>
            </RLayerVectorTile>
          </RMap>
          <div
            ref={popupElementRef}
            className={classes.olPopup}
            style={{ display: selectedFeatures.length > 0 ? undefined : "none" }}
          >
            <a href="#" className={classes.olPopupCloser} onClick={() => setSelectedFeatures([])}></a>
            <div>
              {selectedFeatures.length > 1 ? (
                <ul>
                  {selectedFeatures.map((f) => (
                    <li key={f.getId()}>
                      <Link to={`/deviations/${f.getId()}`}>{f.get("title")}</Link>
                    </li>
                  ))}
                </ul>
              ) : null}
            </div>
          </div>
        </div>
      </Grid.Col>
    </Grid>
  );
};
export default Page;
