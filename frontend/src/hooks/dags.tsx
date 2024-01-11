import { DAG, getDAGRuns, triggerDAGRun } from "../lib/airflow.ts";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useRef } from "react";
import { differenceInMilliseconds } from "date-fns";
import { sleep } from "../lib/util.ts";
import { notifications } from "@mantine/notifications";

export function useDAGStatus(dag?: DAG) {
  const dagId = dag?.dag_id;
  const dagRun = useQuery({
    queryKey: ["airflow", "dags", dagId, "runs"],
    queryFn: () =>
      getDAGRuns(dagId!, { limit: 5, orderBy: "-start_date", state: ["queued", "running", "success", "failed"] }),
    retry: false,
    refetchOnWindowFocus: false,
    enabled: dag && !dag.is_paused,
  });
  const queryClient = useQueryClient();

  /* The code here is for some rather intricate refetching logic.
   *
   * While running, we will refetch once a second, since we know we'll change state back to not running soon (while also
   * not being able to know how soon exactly).
   *
   * While not running, we use the next run date for regularly scheduled DAGs, but once that point in time is reached
   * we might have to refetch for a bit until it actually starts (since Airflow makes no guarantees of the task actually
   * starting on time).
   *
   * For tasks not regularly scheduled we can't really know when it'll run, and should guess, so we just leave it up to
   * the user to refresh their browser as they see fit.
   */

  const refetch = useCallback(() => dagRun.refetch(), [dagRun]);
  const latest = useMemo(() => dagRun.data?.dag_runs[0], [dagRun]);
  const latestState = useMemo(() => latest?.state, [latest]);
  const latestRunId = useMemo(() => latest?.dag_run_id, [latest]);
  useEffect(() => {
    if (latestState === undefined || dag === undefined) {
      return;
    }
    if (latestState !== "success") {
      // currently running, retry regularly
      const timer = setInterval(() => refetch(), 5 * 1000);
      return () => clearInterval(timer);
    }
    if (dag.next_dagrun_create_after && !dag.is_paused) {
      // not currently running, retry once it might have been scheduled
      const diff = differenceInMilliseconds(dag.next_dagrun_create_after, new Date());
      if (diff > 24 * 60 * 60 * 1000) {
        // don't schedule a timer when more than 24h away, as we otherwise might run into integer overflows
        return;
      }
      const timer = setTimeout(async () => {
        // refetch regularly until it gets started
        while ((await refetch()).data?.dag_runs[0].state === "success") {
          await sleep(5 * 1000);
        }
      }, diff);
      return () => clearTimeout(timer);
    }
  }, [dag, latestState, refetch]);

  const firstRunRef = useRef(true);
  useEffect(() => {
    if (latestState === undefined) {
      return;
    }
    // don't run on mount
    if (firstRunRef.current) {
      firstRunRef.current = false;
      return;
    }
    // when the latest run changes to being success we should refetch the list of DAGs, which also gives us a new next run date
    if (latestState === "success") {
      queryClient.refetchQueries({
        queryKey: ["airflow", "dags"],
        exact: true,
      });
    }
  }, [latestRunId, latestState, queryClient]);

  return { dagRun, latest };
}

export function useTriggerDAG() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (dag: DAG) => {
      await triggerDAGRun(dag.dag_id, { note: "Triggered by user on osm-bjk.jandal.se" });
    },
    onMutate: (d) => {
      return notifications.show({
        title: "Köar process...",
        message: `Köar processen ${d.dag_id}...`,
        loading: true,
        autoClose: false,
        withCloseButton: false,
      });
    },
    onSuccess: async (_, d, notification) => {
      notifications.update({
        id: notification,
        title: "Process köad",
        message: `Processen ${d.dag_id} har köats och kommer startas inom kort`,
        autoClose: 5000,
        color: "green",
        loading: false,
      });
      await queryClient.invalidateQueries({ queryKey: ["airflow", "dags", d.dag_id, "runs"] });
    },
    onError: (_, d, notification) => {
      notifications.update({
        id: notification,
        title: "Något gick fel",
        message: `Kunde inte köa proccessen ${d.dag_id}, försök igen senare`,
        color: "red",
      });
    },
  });
}
