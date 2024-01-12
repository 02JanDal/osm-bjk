import { FC, useMemo } from "react";
import postgrest, { DatasetRow, DeviationRow, ProviderRow, ReportInsertRow } from "../postgrest.ts";
import { useMutation, useQuery } from "@tanstack/react-query";
import {
  ActionIcon,
  Alert,
  Anchor,
  Button,
  Flex,
  Grid,
  Group,
  Loader,
  Modal,
  Table,
  Text,
  Textarea,
  TextInput,
} from "@mantine/core";
import { Link } from "wouter";
import { actualElementId, actualElementType, getElement } from "../lib/osm.ts";
import { RFeature, RLayerVector, RMap, ROSM, RPopup, RStyle } from "rlayers";
import { GeoJSON } from "ol/format";
import { buffer, getCenter } from "ol/extent";
import TimeAgo from "../components/TimeAgo.tsx";
import makeLink from "../lib/id.ts";
import Disclaimer from "../components/Disclaimer.tsx";
import classes from "./deviation.module.css";
import { LineString } from "ol/geom";
import Markdown from "react-markdown";
import { addNode, loadAndZoom } from "../lib/josm.ts";
import { fromExtent } from "ol/geom/Polygon";
import { IconArrowBack, IconBug, IconExclamationCircle } from "@tabler/icons-react";
import { useDisclosure } from "@mantine/hooks";
import { useForm } from "@mantine/form";
import { notifications } from "@mantine/notifications";
import { getDAGs } from "../lib/airflow.ts";
import { useDAGStatus, useTriggerDAG } from "../hooks/dags.tsx";
import { TagKeyLink } from "../components/TagKeyLink.tsx";
import { TagValueLink } from "../components/TagValueLink.tsx";

const geojson = new GeoJSON();

const OpenInJOSMButton: FC<{
  deviation: Pick<
    DeviationRow,
    "osm_element_id" | "osm_element_type" | "suggested_tags" | "suggested_geom" | "title" | "center"
  > & { dataset: { provider: { name: string } | null; short_name: string } | null };
}> = ({ deviation }) => {
  const [opened, { open, close }] = useDisclosure();
  const geom = geojson.readGeometry(deviation.center);
  return (
    <>
      <Button
        fullWidth
        onClick={() => {
          open();
          const josmExtent = fromExtent(buffer(geom.getExtent(), 500)).transform("EPSG:3006", "EPSG:4326").getExtent();
          loadAndZoom(
            josmExtent[0],
            josmExtent[1],
            josmExtent[2],
            josmExtent[3],
            {
              select: deviation.osm_element_id
                ? [
                    [
                      actualElementType(deviation.osm_element_type, deviation.osm_element_id),
                      actualElementId(deviation.osm_element_type, deviation.osm_element_id),
                    ],
                  ]
                : undefined,
              addTags: deviation.osm_element_id ? deviation.suggested_tags : undefined,
              changesetSource: `${deviation.dataset!.provider!.name} ${deviation.dataset!.short_name}`,
              changesetHashtags: ["bastajavlakartan"],
              changesetComment: deviation.title,
            },
            () => {
              const suggested = geojson.readGeometry(deviation.suggested_geom);
              if (suggested.getType() === "Point" && !deviation.osm_element_id) {
                const center = getCenter(suggested.transform("EPSG:3006", "EPSG:4326").getExtent());
                setTimeout(
                  () => addNode(center[1], center[0], deviation.suggested_tags as Record<string, string>),
                  1000, // not sure why, but JOSM gives a 400 if calling add_node to quickly
                );
              }
            },
          );
        }}
      >
        Öppna i JOSM
      </Button>
      <Modal opened={opened} onClose={close} title="Arbeta i JOSM" centered>
        <p>Avvikelsen öppnas nu i JOSM. Kom ihåg att ange datakälla och gärna även hashtag:</p>
        <code>
          source={deviation.dataset!.provider!.name} {deviation.dataset!.short_name}
          <br />
          hashtags=#bastajavlakartan
        </code>
      </Modal>
    </>
  );
};
const OpenInID: FC<{
  deviation: Pick<
    DeviationRow,
    "id" | "osm_element_id" | "osm_element_type" | "suggested_geom" | "title" | "center"
  > & { dataset: { provider: { name: string } | null; short_name: string } | null };
}> = ({ deviation }) => {
  const geom = geojson.readGeometry(deviation.center);
  const center4326 = getCenter(geom.transform("EPSG:3006", "EPSG:4326").getExtent());
  return (
    <Button
      fullWidth
      component="a"
      href={makeLink({
        source: `${deviation.dataset!.provider!.name} ${deviation.dataset!.short_name}`,
        hashtags: ["bastajavlakartan"],
        comment: deviation.title,
        id: deviation.osm_element_id
          ? [
              actualElementType(deviation.osm_element_type, deviation.osm_element_id),
              actualElementId(deviation.osm_element_type, deviation.osm_element_id),
            ]
          : undefined,
        gpx: deviation.suggested_geom ? `https://osm.jandal.se/api/rpc/gpx?deviation_id=${deviation.id}` : undefined,
        map: !deviation.osm_element_id ? [16, center4326[1], center4326[0]] : undefined,
      })}
      target="_blank"
    >
      Öppna i iD
    </Button>
  );
};
const ReportButton: FC<{ deviationId: number }> = ({ deviationId }) => {
  const [reportOpened, { open, close }] = useDisclosure(false);
  const reportForm = useForm({
    initialValues: {
      contact: "",
      description: "",
    },
    validate: {
      description: (value) => (value.length > 5 ? null : "Måste vara längre än 5 täcken"),
    },
  });

  const { mutate, isPending } = useMutation({
    mutationFn: async (report: ReportInsertRow) => await postgrest.from("report").insert(report).throwOnError(),
    onMutate: () => {
      return notifications.show({
        title: "Skickar rapport...",
        message: "Skickar in din rapport...",
        autoClose: false,
        withCloseButton: false,
        loading: true,
      });
    },
    onSuccess: (_1, _2, notification) => {
      notifications.update({
        id: notification,
        title: "Rapport skickad",
        message: "Din rapport har skickats och kommer tittas på inom kort!",
        color: "green",
        autoClose: 5000,
        withCloseButton: true,
        loading: false,
      });
    },
    onError: (_1, _2, notification) => {
      notifications.update({
        id: notification,
        title: "Något gick fel",
        message: "Din rapport kunde inte skickas, prova igen senare",
        color: "red",
        autoClose: false,
        withCloseButton: false,
        loading: false,
      });
    },
  });
  return (
    <>
      <Button
        fullWidth
        loading={isPending}
        disabled={isPending}
        onClick={open}
        mt="xs"
        color="red"
        variant="light"
        size="compact-xs"
      >
        Rapportera felaktig avvikelse
      </Button>
      <Modal opened={reportOpened} onClose={close} centered title="Rapportera felaktig avvikelse">
        <form
          onSubmit={reportForm.onSubmit((values) => {
            close();
            mutate({ ...values, deviation_id: deviationId });
            reportForm.reset();
          })}
        >
          <p>
            Beräkningen av avvikelser är ofta komplex och kan ibland gå fel. Och ibland (oftare än man skulle önska) så
            är det underliggande datat faktiskt fel.
          </p>
          <p>
            Använd detta formulär om du hittat en avvikelse som du anser vara fel på något vis, så tittar jag om det
            behöver justeras något i systemet.
          </p>
          <Textarea
            label="Beskrivning"
            description="Beskriv vad du anser vara fel med denna avvikelse, ange gärna t.ex. länkar till relevanta källor"
            withAsterisk
            {...reportForm.getInputProps("description")}
            mt="md"
          />
          <TextInput
            label="Kontaktuppgifter"
            placeholder="@Anvandare eller din@mail.se"
            description="Ange ditt användarnamn på OSM-forumet eller din mailadress om du vill få återkoppling på din rapport"
            {...reportForm.getInputProps("contact")}
          />
          <Group justify="flex-end" mt="md">
            <Button type="submit">Skicka</Button>
          </Group>
        </form>
      </Modal>
    </>
  );
};

const Page: FC<{
  deviation: {
    id: number;
    dataset_id: number;
    layer_id: number;
    upstream_item_id: number;
    suggested_geom: object;
    osm_element_id: number;
    osm_element_type: "w" | "a" | "n" | "r";

    suggested_tags: Record<string, string | null>;
    title: string;
    description: string;
    center: object;
    municipality_code: string;
    action?: "fixed" | "already-fixed" | "not-an-issue" | "deferred";
    action_at?: string;
    note: string;

    osm_geom?: object;
    dataset:
      | (Pick<DatasetRow, "id" | "name" | "short_name" | "url" | "license" | "fetched_at" | "view_name"> & {
          provider: Pick<ProviderRow, "name"> | null;
        })
      | null;
    nearby: Pick<DeviationRow, "id" | "title" | "center">[];
  };
}> = ({ deviation }) => {
  const [osm_element_type, osm_element_id] = deviation
    ? [deviation.osm_element_type, deviation.osm_element_id]
    : [null, null];
  const { data: elementData } = useQuery({
    queryKey: ["osm-element", osm_element_type, osm_element_id],
    enabled: !!osm_element_id,
    queryFn: async () => await getElement(osm_element_type!, osm_element_id!),
  });
  const { status, data: upstreamData } = useQuery({
    queryKey: ["deviation", deviation.id, "upstream_item"],
    queryFn: async () =>
      await postgrest
        .from("deviation")
        .select("id,upstream_item(id,url,geometry,updated_at)")
        .eq("id", deviation.id)
        .single()
        .throwOnError(),
  });

  const osmGeom = deviation.osm_geom
    ? geojson.readGeometry(deviation.osm_geom).transform("EPSG:3006", "EPSG:3857")
    : undefined;
  const suggestedGeom = deviation.suggested_geom
    ? geojson.readGeometry(deviation.suggested_geom).transform("EPSG:3006", "EPSG:3857")
    : undefined;
  const upstreamGeom = upstreamData?.data?.upstream_item.map((i) =>
    geojson.readGeometry(i.geometry).transform("EPSG:3006", "EPSG:3857"),
  );

  const geom = geojson.readGeometry(deviation.center);
  const extent = geom.clone().transform("EPSG:3006", "EPSG:3857").getExtent();

  const { data: dagData } = useQuery({
    queryKey: ["airflow", "dags", `deviations-${deviation.dataset?.view_name}`],
    queryFn: async () => await getDAGs({ dagIdPattern: `deviations-${deviation.dataset?.view_name}` }),
    enabled: deviation.dataset?.view_name !== undefined,
  });
  const dag = useMemo(
    () => dagData?.dags.find((d) => d.dag_id === `deviations-${deviation.dataset?.view_name}`),
    [dagData, deviation.dataset?.view_name],
  );
  const { dagRun: dagRuns, latest: latestDag } = useDAGStatus(dag);
  const latestSuccess = dagRuns.data?.dag_runs.find((dr) => dr.state === "success");
  const trigger = useTriggerDAG();

  return (
    <Grid grow w="100%" styles={{ inner: { height: "100%" } }}>
      <Grid.Col span={{ base: 12, sm: 6, md: 5, xl: 3 }} style={{ maxWidth: "var(--col-flex-basis)" }}>
        <h2 style={{ marginTop: 0 }}>{deviation.title}</h2>
        <p>{deviation.description}</p>

        <Disclaimer />

        <Button.Group w="100%">
          <OpenInID deviation={deviation} />
          <OpenInJOSMButton deviation={deviation} />
        </Button.Group>

        <ReportButton deviationId={deviation.id} />

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
                {Object.entries(deviation.suggested_tags).map(([key, value]) =>
                  value === null ? (
                    <Table.Tr key={key}>
                      <Table.Th>
                        <TagKeyLink keyString={key} />
                      </Table.Th>
                      <Table.Td style={{ color: "red", fontStyle: "italic" }}>Felaktig/inte längre aktuell</Table.Td>
                    </Table.Tr>
                  ) : (
                    <Table.Tr key={key}>
                      <Table.Th>
                        <TagKeyLink keyString={key} />
                      </Table.Th>
                      <Table.Td>
                        <TagValueLink keyString={key} value={value} />
                      </Table.Td>
                    </Table.Tr>
                  ),
                )}
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
            {deviation.dataset!.fetched_at ? (
              <Table.Tr>
                <Table.Th>Senaste hämtning från källa:</Table.Th>
                <Table.Td>
                  <TimeAgo date={deviation.dataset!.fetched_at} />
                </Table.Td>
              </Table.Tr>
            ) : null}
            {status === "success" ? (
              <>
                {upstreamData?.data?.upstream_item.some((i) => i.updated_at) ? (
                  <Table.Tr>
                    <Table.Th rowSpan={upstreamData?.data?.upstream_item.filter((i) => i.updated_at).length}>
                      Källobjekt{" "}
                      {upstreamData?.data?.upstream_item.filter((i) => i.updated_at).length > 1
                        ? "uppdaterade"
                        : "uppdaterat"}
                      :
                    </Table.Th>
                    {upstreamData?.data?.upstream_item
                      .filter((i) => i.updated_at)
                      .map((i) => (
                        <Table.Td key={i.id}>
                          <TimeAgo date={i.updated_at!} />
                        </Table.Td>
                      ))}
                  </Table.Tr>
                ) : null}
                {upstreamData?.data?.upstream_item.some((i) => i.url) ? (
                  <Table.Tr>
                    <Table.Th rowSpan={upstreamData?.data?.upstream_item.filter((i) => i.url).length}>
                      Länk till källobjekt:
                    </Table.Th>
                    {upstreamData?.data?.upstream_item
                      .filter((i) => i.url)
                      .map((i) => <Table.Td key={i.id}>{i.url}</Table.Td>)}
                  </Table.Tr>
                ) : null}
              </>
            ) : status === "pending" ? (
              <Table.Tr>
                <Table.Td colSpan={2}>
                  <Group w="100%" justify="center" mt="sm">
                    <Loader size="xs" />
                  </Group>
                </Table.Td>
              </Table.Tr>
            ) : null}
            {dag ? (
              <Table.Tr>
                <Table.Th>Avvikelse beräknad:</Table.Th>
                <Table.Td style={{ display: "flex", flexDirection: "row", justifyContent: "space-between" }}>
                  <p style={{ marginTop: 0, marginBottom: 0 }}>
                    {dagRuns.isPending ? (
                      <Loader size="xs" />
                    ) : latestSuccess ? (
                      <TimeAgo date={latestSuccess.start_date} />
                    ) : null}
                  </p>
                  <ActionIcon
                    size="xs"
                    radius="xl"
                    loading={trigger.isPending}
                    disabled={trigger.isPending || latestDag?.state === "queued" || latestDag?.state === "running"}
                    title="Beräkna om avvikelser"
                    onClick={() => trigger.mutate(dag)}
                  >
                    <IconBug size="90%" style={{ marginTop: "-10%" }} />
                  </ActionIcon>
                </Table.Td>
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
              center: getCenter(extent),
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
                    <>
                      <RStyle.RStroke color="blue" width={1} />
                      <RStyle.RFill color="rgb(0 0 128 / 0.1)" />
                    </>
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
const PageOuter: FC<{ params: { id: string } }> = ({ params }) => {
  const id = parseInt(params.id);

  const { data, status, error, refetch } = useQuery({
    queryKey: ["deviation", id],
    queryFn: async () =>
      await postgrest
        .from("deviation")
        .select(
          "*,osm_geom,dataset(id,name,short_name,provider(name),url,license,fetched_at,view_name),layer(id,name,description),nearby(id,title,center)",
        )
        .eq("id", id)
        .single()
        .throwOnError(),
    retry: (failureCount, error) => {
      if ("code" in error && error.code === "PGRST116") {
        return false;
      }
      return failureCount < 3;
    },
  });

  if (status === "pending") {
    return (
      <Flex align="center" justify="center" w="100%">
        <Loader size="xl" type="dots" />
      </Flex>
    );
  } else if (status === "error") {
    if ("code" in error && error.code === "PGRST116") {
      return (
        <Flex align="center" justify="center" w="100%">
          <div>
            <Text fz="lg" fw="bold">
              Kunde inte hitta avvikelse
            </Text>
            <Text mt="md">Detta beror troligen på att den inte längre är relevant</Text>
            <Button onClick={() => history.back()} leftSection={<IconArrowBack size={14} />} variant="subtle" mt="xl">
              Gå tillbaka
            </Button>
          </div>
        </Flex>
      );
    }
    return (
      <Alert variant="filled" color="red" icon={<IconExclamationCircle />} w="100%">
        <p style={{ marginTop: 0 }}>{"message" in error ? error.message : "Något gick fel"}</p>
        <Button onClick={() => refetch()} color="red" variant="white">
          Försök igen
        </Button>
      </Alert>
    );
  } else {
    return <Page deviation={data.data!} />;
  }
};

export default PageOuter;
