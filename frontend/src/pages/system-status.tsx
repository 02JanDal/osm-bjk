import { FC } from "react";
import {
  ActionIcon,
  Badge,
  Card,
  Grid,
  Group,
  Loader,
  MantineSize,
  Progress,
  Stack,
  Text,
  ThemeIcon,
  Tooltip,
} from "@mantine/core";
import { Icon, IconBug, IconClockPlay, IconDownload, IconHourglassEmpty } from "@tabler/icons-react";
import TimeAgo from "../components/TimeAgo.tsx";
import { useSuspenseQueries } from "@tanstack/react-query";
import { DAG, DAGRun, getDAGs, getDatasets } from "../lib/airflow.ts";
import { differenceInMilliseconds } from "date-fns";
import { useDAGStatus, useTriggerDAG } from "../hooks/dags.tsx";

const DAGIcon: FC<{ dag: DAG; latest: DAGRun | undefined; size: MantineSize; icon: Icon; triggerable: boolean }> = ({
  dag,
  latest,
  size,
  icon,
  triggerable,
}) => {
  const mutation = useTriggerDAG();

  const IconComponent = icon;
  if (triggerable && !dag.is_paused && latest?.state !== "queued" && latest?.state !== "running") {
    return (
      <ActionIcon
        radius="xl"
        size={size}
        color={dag.is_paused ? "gray" : latest?.state === "failed" ? "red" : "blue"}
        onClick={() => mutation.mutateAsync(dag)}
        loading={mutation.isPending}
      >
        <IconComponent size={size === "sm" ? "80%" : "70%"} style={{ marginTop: "-10%" }} />
      </ActionIcon>
    );
  } else {
    return (
      <ThemeIcon radius="xl" size={size} color={dag.is_paused ? "gray" : latest?.state === "failed" ? "red" : "blue"}>
        <IconComponent size={size === "sm" ? "80%" : "70%"} style={{ marginTop: "-10%" }} />
      </ThemeIcon>
    );
  }
};

const ProcessRow: FC<{ dag: DAG }> = ({ dag }) => {
  const { latest } = useDAGStatus(dag);

  return (
    <Group justify="space-between" gap="xs" style={{ flexWrap: "nowrap" }}>
      <Group gap="xs" style={{ flexWrap: "nowrap" }}>
        <DAGIcon dag={dag} latest={latest} size="sm" icon={IconBug} triggerable={true} />
        <Text fz="sm" c="dimmed">
          {dag.tags.find((t) => t.name.startsWith("name:"))?.name.replace("name:", "") ?? "Omräkning av avvikelser"}
        </Text>
      </Group>
      {latest?.state === "queued" || latest?.state === "running" ? (
        <Tooltip
          label={
            <span>
              Kör <TimeAgo date={latest.start_date} />
            </span>
          }
          position="left"
          withArrow
        >
          <Loader color="blue" size="sm" />
        </Tooltip>
      ) : dag.next_dagrun_create_after ? (
        <Tooltip
          label={
            <span>
              Schemalagd att köra <TimeAgo date={dag.next_dagrun_create_after} />
            </span>
          }
          position="left"
          withArrow
        >
          <IconClockPlay />
        </Tooltip>
      ) : (
        <Tooltip label="Schemalagd att köras när nya data har hämtats" position="left" withArrow>
          <ThemeIcon variant="white" color="gray" mt={-20} mb={-20}>
            <IconHourglassEmpty size="70%" />
          </ThemeIcon>
        </Tooltip>
      )}
    </Group>
  );
};

const ProcessCard: FC<{ dag: DAG; title: string; description: string; children?: DAG[]; triggerable: boolean }> = ({
  dag,
  title,
  description,
  children,
  triggerable,
}) => {
  const { dagRun, latest } = useDAGStatus(dag);

  const latestSuccess = dagRun.data?.dag_runs.find((dr) => dr.state === "success");

  return (
    <Card withBorder padding="lg" radius="md" h="100%">
      <Stack gap={0} justify="space-between" h="100%" mb="sm">
        <Stack gap={0}>
          <Group justify="space-between">
            <DAGIcon dag={dag} latest={latest} size="lg" icon={IconDownload} triggerable={triggerable} />
            {latestSuccess ? (
              <Badge color={dag.is_paused ? "gray" : latest?.state === "failed" ? "red" : "blue"}>
                <TimeAgo date={latestSuccess.start_date} />
              </Badge>
            ) : null}
          </Group>

          <Text fz="lg" fw={500} mt="md" c={dag.is_paused ? "dimmed" : undefined}>
            {title}
          </Text>
          <Text fz="sm" c="dimmed" mt={5}>
            {description}
          </Text>
        </Stack>

        {dag.is_paused ? null : (
          <Stack gap={0}>
            <Text
              c="dimmed"
              fz="sm"
              mt="md"
              style={{
                visibility:
                  latest?.state === "queued" ||
                  latest?.state === "running" ||
                  (dag.schedule_interval?.__type === "TimeDelta" && dag.next_dagrun_create_after)
                    ? undefined
                    : "hidden",
              }}
            >
              {latest?.state === "queued" ? (
                "Startar..."
              ) : latest?.state === "running" ? (
                "Kör..."
              ) : differenceInMilliseconds(dag.next_dagrun_create_after, new Date()) > 0 ? (
                <>
                  Nästa körning <TimeAgo date={dag.next_dagrun_create_after} />
                </>
              ) : (
                "Nästa körning snarast"
              )}
            </Text>
            <Progress
              value={latest?.state === "queued" || latest?.state === "running" ? 100 : 0}
              size="xl"
              mt="xs"
              striped
              animated
            />
          </Stack>
        )}
      </Stack>
      {children?.map((c) => (
        <Card.Section withBorder key={c.dag_id} p="xs">
          <ProcessRow dag={c} />
        </Card.Section>
      ))}
    </Card>
  );
};

const Page: FC = () => {
  const [{ data: dags }, { data: datasets }] = useSuspenseQueries({
    queries: [
      {
        queryKey: ["airflow", "dags"],
        queryFn: () => getDAGs({ onlyActive: true, limit: 500 }),
      },
      {
        queryKey: ["airflow", "datasets"],
        queryFn: () => getDatasets({ limit: 500 }),
      },
    ],
  });

  return (
    <Stack w="100%">
      <Grid style={{ borderBottom: "1px solid lightgrey" }} pb="md">
        <Grid.Col>
          <ProcessCard
            dag={dags.dags.find((d) => d.dag_id === "osm-replication")!}
            title="OpenStreetMap Replication"
            description="Hämtar senaste OpenStreetMap-datat"
            triggerable={false}
          />
        </Grid.Col>
      </Grid>
      <Grid align="stretch">
        {dags.dags
          .filter(
            (d) =>
              !["osm-replication", "osm-init", "lm-topografi50-init"].includes(d.dag_id) &&
              !d.tags.some((t) => t.name === "type:Deviations"),
          )
          .map((d) => (
            <Grid.Col key={d.dag_id} span={{ base: 12, xs: 6, sm: 4, md: 4, lg: 3, xl: 2 }}>
              <ProcessCard
                dag={d}
                title={d.dag_id}
                description={d.description}
                children={dags.dags.filter((dag) =>
                  datasets.datasets.some(
                    (ds) =>
                      ds.producing_tasks.some((t) => t.dag_id === d.dag_id) &&
                      ds.consuming_dags.some((t) => t.dag_id === dag.dag_id),
                  ),
                )}
                triggerable={true}
              />
            </Grid.Col>
          ))}
      </Grid>
    </Stack>
  );
};
export default Page;
