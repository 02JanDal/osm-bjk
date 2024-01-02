import { FC } from "react";
import postgrest, { DeviationRow } from "../postgrest.ts";
import { useMutation, useQuery, useQueryClient, useSuspenseQuery } from "@tanstack/react-query";
import { Anchor, Button, Grid, Loader, Table, Tooltip } from "@mantine/core";
import { Link } from "wouter";
import { actualElementId, actualElementType, getElement } from "../lib/osm.ts";
import { RFeature, RLayerVector, RMap, ROSM, RPopup, RStyle } from "rlayers";
import { GeoJSON } from "ol/format";
import { getCenter } from "ol/extent";
import TimeAgo from "../components/TimeAgo.tsx";
import makeLink from "../lib/id.ts";
import Disclaimer from "../components/Disclaimer.tsx";
import classes from "./deviation.module.css";
import { LineString } from "ol/geom";
import Markdown from "react-markdown";

const TagKeyLink: FC<{ keyString: string }> = (props) => (
  <Anchor href={`https://wiki.openstreetmap.org/wiki/Key:${props.keyString}`} target="_blank">
    {props.keyString}
  </Anchor>
);

const TagValueLink: FC<{ keyString: string; value: string }> = (props) => (
  <>
    {["amenity", "building", "landuse"].includes(props.keyString) ? (
      <Anchor href={`https://wiki.openstreetmap.org/wiki/Tag:${props.keyString}%3D${props.value}`} target="_blank">
        {props.value}
      </Anchor>
    ) : props.keyString.endsWith("wikidata") ? (
      <Anchor href={`https://www.wikidata.org/wiki/${props.value}`} target="_blank">
        {props.value}
      </Anchor>
    ) : ["url", "website", "contact:website"].includes(props.keyString) ? (
      <Anchor href={props.value} target="_blank">
        {props.value}
      </Anchor>
    ) : (
      props.value
    )}
  </>
);

const geojson = new GeoJSON();

const Page: FC<{ params: { id: string } }> = ({ params }) => {
  const id = parseInt(params.id);

  const { data: deviationData } = useSuspenseQuery({
    queryKey: ["deviation", id],
    queryFn: async () =>
      await postgrest
        .from("deviation")
        .select(
          "*,osm_geom,upstream_item(*),dataset(id,name,provider(name),url,license,fetched_at),layer(id,name,description),nearby(id,title,center)",
        )
        .eq("id", id)
        .single()
        .throwOnError(),
  });

  const deviation = deviationData.data!;

  const [osm_element_type, osm_element_id] = deviation
    ? [deviation.osm_element_type, deviation.osm_element_id]
    : [null, null];
  const { data: elementData } = useQuery({
    queryKey: ["osm-element", osm_element_type, osm_element_id],
    enabled: !!osm_element_id,
    queryFn: async () => await getElement(osm_element_type!, osm_element_id!),
  });

  const queryClient = useQueryClient();
  const {
    mutate: performAction,
    isPending: isPerformingAction,
    variables,
  } = useMutation({
    mutationFn: async (action: DeviationRow["action"]) =>
      await postgrest.from("deviation").update({ action }).eq("id", deviation.id).throwOnError(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["deviation"] });
      queryClient.invalidateQueries({ queryKey: ["osm-element"] });
    },
  });

  const osmGeom = deviation.osm_geom
    ? geojson.readGeometry(deviation.osm_geom).transform("EPSG:3006", "EPSG:3857")
    : undefined;
  const suggestedGeom = deviation.suggested_geom
    ? geojson.readGeometry(deviation.suggested_geom).transform("EPSG:3006", "EPSG:3857")
    : undefined;
  const upstreamGeom = deviation.upstream_item.map((i) =>
    geojson.readGeometry(i.geometry).transform("EPSG:3006", "EPSG:3857"),
  );

  return (
    <Grid grow w="100%" styles={{ inner: { height: "100%" } }}>
      <Grid.Col span={{ base: 12, sm: 6, md: 5, xl: 3 }}>
        <h2 style={{ marginTop: 0 }}>{deviation.title}</h2>
        <p>{deviation.description}</p>

        <Disclaimer />

        <Button.Group w="100%">
          <Button
            fullWidth
            component="a"
            href={makeLink({
              source: `${deviation.dataset!.provider!.name} ${deviation.dataset!.name}`,
              hashtags: ["bastajavlakartan"],
              comment: deviation.title,
              id: deviation.osm_element_id
                ? [
                    actualElementType(deviation.osm_element_type, deviation.osm_element_id),
                    actualElementId(deviation.osm_element_type, deviation.osm_element_id),
                  ]
                : undefined,
              gpx: deviation.suggested_geom
                ? `https://osm.jandal.se/api/rpc/gpx?deviation_id=${deviation.id}`
                : undefined,
            })}
            target="_blank"
          >
            Öppna i iD
          </Button>
          <Tooltip label="Under arbete">
            <Button fullWidth disabled>
              Öppna i JOSM
            </Button>
          </Tooltip>
        </Button.Group>
        <Button.Group w="100%" mt={10}>
          <Button
            fullWidth
            loading={isPerformingAction && variables === "fixed"}
            disabled={isPerformingAction}
            onClick={() => performAction("fixed")}
          >
            Fixad nu
          </Button>
          <Tooltip label="T.ex. om någon annan hunnit åtgärda avvikelsen som inte använt denna sida" withArrow>
            <Button
              fullWidth
              loading={isPerformingAction && variables === "already-fixed"}
              disabled={isPerformingAction}
              onClick={() => performAction("already-fixed")}
            >
              Var redan fixad
            </Button>
          </Tooltip>
        </Button.Group>
        <Button.Group w="100%" mt={2}>
          <Tooltip
            label="T.ex. om felet ligger hos datakällan eller av annan anledning denna avvikelse inte bör åtgärdas i OSM"
            withArrow
            position="bottom"
          >
            <Button
              fullWidth
              loading={isPerformingAction && variables === "not-an-issue"}
              disabled={isPerformingAction}
              onClick={() => performAction("not-an-issue")}
            >
              Inte ett problem
            </Button>
          </Tooltip>
          <Tooltip
            label="T.ex. om korrekt ändring inte kan avgöras än för att det saknas aktuella flygbilder, men att avvikelsen möjligen ska åtgärdas senare"
            withArrow
            position="bottom"
          >
            <Button
              fullWidth
              loading={isPerformingAction && variables === "deferred"}
              disabled={isPerformingAction}
              onClick={() => performAction("deferred")}
            >
              Avvaktas med
            </Button>
          </Tooltip>
        </Button.Group>

        {deviation.action ? (
          <p>
            Markerades som{" "}
            {
              {
                fixed: "fixad",
                "already-fixed": "redan fixad",
                "not-an-issue": "inte ett problem",
                deferred: "avvaktas med",
              }[deviation.action]
            }{" "}
            <TimeAgo date={deviation.action_at!} />
          </p>
        ) : null}

        {deviation.note.trim().length > 0 ? (
          <>
            <h3>Information till åtgärd</h3>
            <Markdown>{deviation.note.trim()}</Markdown>
          </>
        ) : null}

        {deviation.suggested_tags ? (
          <>
            <h3>Föreslagna taggar</h3>
            <Table>
              <Table.Tbody>
                {Object.entries(deviation.suggested_tags).map(([key, value]) => (
                  <Table.Tr key={key}>
                    <Table.Th>
                      <TagKeyLink keyString={key} />
                    </Table.Th>
                    <Table.Td>
                      <TagValueLink keyString={key} value={value} />
                    </Table.Td>
                  </Table.Tr>
                ))}
              </Table.Tbody>
            </Table>
          </>
        ) : null}
        {deviation.osm_element_id ? (
          <>
            <h3>
              Befintligt element i OSM (
              <span
                style={{
                  border: "1px solid blue",
                  background: "rgba(0 0 128 / 0.2)",
                  width: 15,
                  height: 15,
                  borderRadius: 7.5,
                  display: "inline-block",
                }}
              />
              )
            </h3>
            {!elementData ? (
              <Loader />
            ) : (
              <>
                <Anchor
                  href={`https://openstreetmap.org/${actualElementType(
                    deviation.osm_element_type,
                    deviation.osm_element_id,
                  )}/${actualElementId(deviation.osm_element_type, deviation.osm_element_id)}`}
                >
                  {deviation.osm_element_type}
                  {actualElementId(deviation.osm_element_type, deviation.osm_element_id)}
                </Anchor>
                <br />
                Uppdaterades senast <TimeAgo date={elementData.timestamp} /> av {elementData.user}
                <Table>
                  <Table.Tbody>
                    {Object.entries(elementData.tags || {}).map(([key, value]) => (
                      <Table.Tr key={key}>
                        <Table.Th>
                          <TagKeyLink keyString={key} />
                        </Table.Th>
                        <Table.Td>
                          <TagValueLink keyString={key} value={value} />
                        </Table.Td>
                      </Table.Tr>
                    ))}
                  </Table.Tbody>
                </Table>
              </>
            )}
          </>
        ) : null}

        <h3>Mer information</h3>
        <Table>
          <Table.Tbody>
            <Table.Tr>
              <Table.Th>Källa:</Table.Th>
              <Table.Td>
                <Link to={`/datasets/${deviation.dataset?.id}`}>
                  {deviation.dataset?.name} (från {deviation.dataset?.provider?.name})
                </Link>
              </Table.Td>
            </Table.Tr>
            <Table.Tr>
              <Table.Th>Senaste hämtning från källa:</Table.Th>
              <Table.Td>
                <TimeAgo date={deviation.dataset!.fetched_at} />
              </Table.Td>
            </Table.Tr>
            {deviation.upstream_item.some((i) => i.updated_at) ? (
              <Table.Tr>
                <Table.Th rowSpan={deviation.upstream_item.filter((i) => i.updated_at).length}>
                  Källobjekt{" "}
                  {deviation.upstream_item.filter((i) => i.updated_at).length > 1 ? "uppdaterade" : "uppdaterat"}:
                </Table.Th>
                {deviation.upstream_item
                  .filter((i) => i.updated_at)
                  .map((i) => (
                    <Table.Td key={i.id}>
                      <TimeAgo date={i.updated_at!} />
                    </Table.Td>
                  ))}
              </Table.Tr>
            ) : null}
            {deviation.upstream_item.some((i) => i.url) ? (
              <Table.Tr>
                <Table.Th rowSpan={deviation.upstream_item.filter((i) => i.url).length}>Länk till källobjekt:</Table.Th>
                {deviation.upstream_item
                  .filter((i) => i.url)
                  .map((i) => (
                    <Table.Td key={i.id}>{i.url}</Table.Td>
                  ))}
              </Table.Tr>
            ) : null}
          </Table.Tbody>
        </Table>

        {deviation.nearby.length > 0 ? (
          <>
            <h3>
              Andra närliggande avvikelser (<span style={{ color: "magenta" }}>&#x2715;</span>)
            </h3>
            <Table>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Avvikelse</Table.Th>
                  <Table.Th>Avstånd</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {deviation.nearby.map((d) => (
                  <Table.Tr key={d.id}>
                    <Table.Td>
                      <Link to={`/deviations/${d.id}`}>{d.title}</Link>
                    </Table.Td>
                    <Table.Td>
                      {new LineString([
                        geojson.readGeometry(deviation.center).getExtent().slice(0, 2),
                        geojson.readGeometry(d.center).getExtent().slice(0, 2),
                      ])
                        .getLength()
                        .toFixed(0)}{" "}
                      m
                    </Table.Td>
                  </Table.Tr>
                ))}
              </Table.Tbody>
            </Table>
          </>
        ) : null}
      </Grid.Col>
      <Grid.Col span={{ base: 12, sm: 6, md: 7, xl: 9 }}>
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
              center: getCenter(geojson.readGeometry(deviation.center).transform("EPSG:3006", "EPSG:3857").getExtent()),
              zoom: 16,
            }}
          >
            <ROSM />
            {osmGeom ? (
              <RLayerVector zIndex={10}>
                <RStyle.RStyle>
                  {osmGeom.getType() === "Point" ? (
                    <RStyle.RCircle radius={8}>
                      <RStyle.RStroke color="blue" width={1} />
                      <RStyle.RFill color="rgb(0 0 128 / 0.2)" />
                    </RStyle.RCircle>
                  ) : (
                    <RStyle.RStroke color="blue" width={1} />
                  )}
                </RStyle.RStyle>
                <RFeature geometry={osmGeom}>
                  <RPopup trigger="hover" className={classes.popup}>
                    Geometri i OSM
                  </RPopup>
                </RFeature>
              </RLayerVector>
            ) : null}
            {suggestedGeom ? (
              <RLayerVector zIndex={20}>
                <RStyle.RStyle>
                  {suggestedGeom.getType() === "Point" ? (
                    <RStyle.RCircle radius={8}>
                      <RStyle.RStroke color="green" width={1} />
                      <RStyle.RFill color="rgb(0 128 0 / 0.2)" />
                    </RStyle.RCircle>
                  ) : (
                    <RStyle.RStroke color="green" width={1} />
                  )}
                </RStyle.RStyle>
                <RFeature geometry={suggestedGeom}>
                  <RPopup trigger="hover" className={classes.popup}>
                    Föreslagen ny geometri
                  </RPopup>
                </RFeature>
              </RLayerVector>
            ) : upstreamGeom ? (
              <RLayerVector zIndex={20}>
                {upstreamGeom.map((geom, index) => (
                  <RFeature key={index} geometry={geom}>
                    <RPopup trigger="hover" className={classes.popup}>
                      Geometri från datakälla
                    </RPopup>
                    <RStyle.RStyle>
                      {geom.getType() === "Point" ? (
                        <RStyle.RCircle radius={8}>
                          <RStyle.RStroke color="red" width={1} />
                          <RStyle.RFill color="rgb(128 0 0 / 0.2)" />
                        </RStyle.RCircle>
                      ) : (
                        <RStyle.RStroke color="red" width={1} />
                      )}
                    </RStyle.RStyle>
                  </RFeature>
                ))}
              </RLayerVector>
            ) : null}
            <RLayerVector zIndex={10}>
              <RStyle.RStyle>
                <RStyle.RText text="&#x2715;">
                  <RStyle.RFill color="magenta" />
                </RStyle.RText>
              </RStyle.RStyle>
              {deviation.nearby.map((d) => (
                <RFeature
                  key={d.id}
                  properties={d}
                  geometry={geojson.readGeometry(d.center).transform("EPSG:3006", "EPSG:3857")}
                >
                  <RPopup trigger="hover" className={classes.popup}>
                    {d.title}
                  </RPopup>
                </RFeature>
              ))}
            </RLayerVector>
          </RMap>
        </div>
      </Grid.Col>
    </Grid>
  );
};
export default Page;
