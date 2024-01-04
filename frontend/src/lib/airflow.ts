function getBasicSearch(params?: { limit?: number; offset?: number; orderBy?: string }): URLSearchParams {
  const search = new URLSearchParams();
  if (params?.limit !== undefined) {
    search.set("limit", String(params.limit));
  }
  if (params?.offset !== undefined) {
    search.set("offset", String(params.offset));
  }
  if (params?.orderBy !== undefined) {
    search.set("order_by", params.orderBy);
  }
  return search;
}

interface GetDAGsParameters {
  limit?: number;
  offset?: number;
  orderBy?: keyof DAG | `-${keyof DAG}`;
  tags?: string[];
  onlyActive?: boolean;
  paused?: boolean;
  dagIdPattern?: string;
}
export interface DAG {
  dag_id: string;
  description: string;
  is_active: boolean;
  is_paused: boolean;
  tags: { name: string }[];
  next_dagrun_create_after: string;
  schedule_interval:
    | { __type: "TimeDelta"; days: number; microseconds: number; seconds: number }
    | { __type: "RelativeDelta" }
    | { __type: "CronExpression" };
}
interface GetDAGsResult {
  dags: DAG[];
  total_entries: number;
}

export async function getDAGs(params: GetDAGsParameters): Promise<GetDAGsResult> {
  const search = getBasicSearch(params);
  for (const tag of params.tags ?? []) {
    search.append("tags", tag);
  }
  if (params.onlyActive !== undefined) {
    search.set("only_active", params.onlyActive ? "true" : "false");
  }
  if (params.paused !== undefined) {
    search.set("paused", params.paused ? "true" : "false");
  }
  if (params.dagIdPattern !== undefined) {
    search.set("dag_id_pattern", params.dagIdPattern);
  }

  const res = await fetch(`https://osm.jandal.se/api/airflow/dags?${search.toString()}`);
  if (!res.ok) {
    throw new Error("Couldn't query Airflow API");
  }
  const json = await res.json();
  return json as GetDAGsResult;
}

interface GetDAGRunsParameters {
  limit?: number;
  offset?: number;
  orderBy?: keyof DAGRun | `-${keyof DAGRun}`;
  state?: ("queued" | "running" | "success" | "failed")[];
}
export interface DAGRun {
  dag_id: string;
  dag_run_id: string;
  start_date: string;
  state: "queued" | "running" | "success" | "failed";
}
interface GetDAGRunsResult {
  dag_runs: DAGRun[];
  total_entries: number;
}

export async function getDAGRuns(dagId: string, params?: GetDAGRunsParameters): Promise<GetDAGRunsResult> {
  const search = getBasicSearch(params);
  for (const state of params?.state ?? []) {
    search.append("state", state);
  }
  const res = await fetch(`https://osm.jandal.se/api/airflow/dags/${dagId}/dagRuns?${search.toString()}`);
  if (!res.ok) {
    throw new Error("Couldn't query Airflow API");
  }
  const json = await res.json();
  return json as GetDAGRunsResult;
}

interface GetDatasetsParameters {
  limit?: number;
  offset?: number;
  orderBy?: keyof GetDatasetsResult["datasets"][number] | `-${keyof GetDatasetsResult["datasets"][number]}`;
  uriPattern?: string;
}
interface GetDatasetsResult {
  datasets: {
    consuming_dags: {
      dag_id: string;
      created_at: string;
      updated_at: string;
    }[];
    created_at: string;
    extra: Record<string, unknown>;
    id: string;
    producing_tasks: {
      dag_id: string;
      task_id: string;
      created_at: string;
      updated_at: string;
    }[];
    updated_at: string;
    uri: string;
  }[];
  total_entries: number;
}
export async function getDatasets(params?: GetDatasetsParameters): Promise<GetDatasetsResult> {
  const search = getBasicSearch(params);
  if (params?.uriPattern !== undefined) {
    search.set("uri_pattern", params.uriPattern);
  }
  const res = await fetch(`https://osm.jandal.se/api/airflow/datasets?${search.toString()}`);
  if (!res.ok) {
    throw new Error("Couldn't query Airflow API");
  }
  const json = await res.json();
  return json as GetDatasetsResult;
}

interface TriggerDAGRunParameters {
  dag_run_id?: string;
  logical_date?: string;
  note?: string;
}

export async function triggerDAGRun(dagId: string, params?: TriggerDAGRunParameters): Promise<void> {
  const res = await fetch(`https://osm.jandal.se/api/airflow/trigger/${dagId}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ ...params, conf: {} }),
  });
  if (!res.ok) {
    throw new Error("Couldn't query Airflow API");
  }
}
