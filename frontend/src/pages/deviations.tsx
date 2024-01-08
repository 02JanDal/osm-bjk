import { FC, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ArrayParam, useQueryParams } from "use-query-params";
import { Button, Grid, Group, Modal, MultiSelect, Stack, Switch, Title } from "@mantine/core";
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
import { useLocalStorage, useSessionStorage, useDisclosure } from "@mantine/hooks";
import { Box } from "@mantine/core";
import { Coordinate } from "ol/coordinate";

const geojson = new GeoJSON();

// for some reason not properly exported from rlayers, so we redefine it here
interface RView {
  center: Coordinate;
  zoom: number;
  resolution?: number;
}
function useSessionStorageMapView(key: string, initial: RView): [RView, (view: RView) => void] {
  const [stored, setStored] = useSessionStorage<RView>({ key, defaultValue: initial });

  return [stored, setStored];
}

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
  const [query, setQuery] = useQueryParams(
    {
      dataset: ArrayParam,
      municipality: ArrayParam,
      layer: ArrayParam,
      deviation: ArrayParam,
    },
    { removeDefaultsFromUrl: true },
  );

  const [openSingle, setOpenSingle] = useLocalStorage({ key: "deviations.openSingle", defaultValue: true });
  const [openNewTab, setOpenNewTab] = useLocalStorage({ key: "deviations.openNewTab", defaultValue: false });
  const [view, setView] = useSessionStorageMapView("deviations.mapView", swedenInitial);

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
        _.uniq(deviationTitlesData?.data?.map((d) => d.title) || [])
          .sort()
          .map((title, idx, list) => [
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

  const osmChangeUrl = useCallback(
    (josm: boolean) => {
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
      return `https://osm.jandal.se/api/rpc/${josm ? "josmchange" : "osmchange"}?${search.toString()}`;
    },
    [query],
  );

  const [infoOpened, { open: infoOpen, close: infoClose }] = useDisclosure(false);

  return (
    <Grid grow w="100%" styles={{ inner: { height: "100%" } }}>
      <Grid.Col span={{ base: 0, sm: 4, md: 3, lg: 3, xl: 2 }} style={{ maxWidth: "var(--col-flex-basis)" }}>
        <Stack h="100%" gap="sm">
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
          <Switch
            checked={!openSingle}
            onChange={(event) => setOpenSingle(!event.currentTarget.checked)}
            label="Öppna alltid popup"
          />
          <Switch
            checked={openNewTab}
            onChange={(event) => setOpenNewTab(event.currentTarget.checked)}
            label="Öppna avvikelser i ny flik"
          />
          <hr
            style={{ margin: 0, border: "none", borderBottom: "1px solid var(--mantine-color-gray-4)", width: "100%" }}
          />
          <p style={{ marginTop: 0, marginBottom: "calc(-1 * var(--grid-gutter)/2)" }}>
            Hittade {countResults} avvikelser
          </p>
          <Button.Group orientation="vertical">
            <Button variant="light" component="a" href={osmChangeUrl(false)} onClick={infoOpen}>
              Hämta osmChange
            </Button>
            <Button
              variant="light"
              onClick={() => {
                infoOpen();
                importUrl(osmChangeUrl(true), {
                  changesetTags: {
                    hashtags: "#bastajavlakartan",
                  },
                });
              }}
            >
              Öppna alla i JOSM
            </Button>
            <Modal opened={infoOpened} onClose={infoClose} title="Jobba med avvikelser" centered>
              <p>Kom ihåg att ange datakälla/-or och gärna även hashtag:</p>
              <code>
                source=
                {_.uniq(
                  deviationTitles
                    .map(({ dataset_id }) => datasets.data!.find((d) => d.id === dataset_id)!)
                    .map((dataset) => `${dataset.provider!.name} ${dataset.short_name}`),
                )
                  .sort()
                  .join(",")}
                <br />
                hashtags=#bastajavlakartan
              </code>

              <p>
                Kom ihåg att inte alla datakällor är tillförlitliga, även om den kan tillhandahållas från en i övrigt
                officiell och tillförlitlig organisation som en myndighet.
              </p>
              <p>
                Denna sida tar inget ansvar för korrektheten på det data som visas här. Fundera alltid på om det som
                anges är rimligt och stämmer med t.ex. flygfoton. Ändra inget i OSM om du är osäker.
              </p>
            </Modal>
          </Button.Group>
          <hr
            style={{ margin: 0, border: "none", borderBottom: "1px solid var(--mantine-color-gray-4)", width: "100%" }}
          />
          <Title order={4}>Färgförklaring</Title>
          <Stack gap={0}>
            {_.sortBy(Object.entries(colors), ([title, _]) => title)
              .filter(([title, _]) => deviationTitles.some((dt) => dt.title === title))
              .map(([title, [ca, cb]]) => (
                <Group key={title} style={{ flexWrap: "nowrap" }} gap="xs">
                  <Box w={15} h={15} bg={cb} style={{ border: `2px solid ${ca}`, borderRadius: "100%" }} />
                  <div style={{ overflow: "hidden", whiteSpace: "nowrap", textOverflow: "ellipsis" }}>{title}</div>
                  <div>({deviationTitles.filter((dt) => dt.title === title).reduce((a, b) => a + b.count, 0)})</div>
                </Group>
              ))}
          </Stack>
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
          <RMap width="100%" height="100%" initial={view} view={[view, setView]}>
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
                if (features.length === 1 && openSingle) {
                  if (openNewTab) {
                    window.open(`/deviations/${features[0].getId()}`, "_blank");
                  } else {
                    navigate(`/deviations/${features[0].getId()}`);
                  }
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
              {selectedFeatures.length > 0 ? (
                <ul>
                  {selectedFeatures.map((f) => (
                    <li key={f.getId()}>
                      {openNewTab ? (
                        <a href={`/deviations/${f.getId()}`} target="_blank">
                          {f.get("title")}
                        </a>
                      ) : (
                        <Link to={`/deviations/${f.getId()}`}>{f.get("title")}</Link>
                      )}
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
