import { PostgrestClient } from "@supabase/postgrest-js";
import { APISERVER } from "./config.ts";

export type MunicipalityRow = {
  code: string;
  name: string;
  geom: object;
  region_name: string;
  extent: object;
};

export type MunicipalityLayerRow = {
  id: number;
  municipality_code: string;
  layer_id: number;
  last_checked: string | null;
  last_checked_by: number | null;
};

export type DatasetUsage = "advisory" | "complete" | "automatic";
export type MunicipalityDatasetRow = {
  id: number;
  municipality_code: string;
  layer_id: number;
  dataset_id: number | null;
  dataset_type: DatasetUsage | null;
  project_link: string | null;
};

export type LayerRow = {
  id: number;
  name: string;
  is_major: boolean;
  description: string;
};

export type DatasetRow = {
  id: number;
  name: string;
  short_name: string;
  provider_id: number;
  url: string;
  license: string;
  extent?: object;
  fetched_at?: string;
  view_name?: string;
};
export type ProviderRow = {
  id: number;
  name: string;
  url: string;
};
export type ReportInsertRow = {
  deviation_id: number;
  contact?: string;
  description: string;
};

export type DeviationRow = {
  id: number;
  dataset_id: number;
  layer_id: number;
  upstream_item_id: number;
  suggested_geom: object;
  osm_element_id: number;
  osm_element_type: "n" | "w" | "a" | "r";
  suggested_tags: Record<string, string | null>;
  title: string;
  description: string;
  center: object;
  municipality_code: string;
  action?: "fixed" | "already-fixed" | "not-an-issue" | "deferred";
  action_at?: string;
  note: string;

  osm_geom?: object;
  upstream_item?: UpstreamItemRow[];
  nearby?: DeviationRow[];
};
export type UpstreamItemRow = {
  id: number;
  dataset_id: number;
  url?: string;
  original_id?: string;
  geometry: object;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  original_attributes: Record<string, any>;
  updated_at?: string;
};

interface ApiSchema {
  Tables: {
    report: {
      Row: Record<string, never>;
      Insert: ReportInsertRow;
      Update: Record<string, never>;
    };
    municipality: {
      Row: MunicipalityRow;
      Insert: Record<string, never>;
      Update: Record<string, never>;
    };
    municipality_layer: {
      Row: MunicipalityLayerRow;
      Insert: Record<string, never>;
      Update: Record<string, never>;
      Relationships: [
        {
          foreignKeyName: "municipality_layer_layer_id_fkey";
          columns: ["layer_id"];
          referencedRelation: "layer";
          referencedColumns: ["id"];
        },
        {
          foreignKeyName: "municipality_layer_municipality_code_fkey";
          columns: ["municipality_code"];
          referencedRelation: "municipality";
          referencedColumns: ["code"];
        },
      ];
    };
    municipality_dataset: {
      Row: MunicipalityDatasetRow;
      Insert: Record<string, never>;
      Update: Record<string, never>;
      Relationships: [
        {
          foreignKeyName: "municipality_layer_dataset_id_fkey";
          columns: ["dataset_id"];
          referencedRelation: "dataset";
          referencedColumns: ["id"];
        },
        {
          foreignKeyName: "municipality_layer_layer_id_fkey";
          columns: ["layer_id"];
          referencedRelation: "layer";
          referencedColumns: ["id"];
        },
        {
          foreignKeyName: "municipality_layer_municipality_code_fkey";
          columns: ["municipality_code"];
          referencedRelation: "municipality";
          referencedColumns: ["code"];
        },
      ];
    };
    layer: {
      Row: LayerRow;
      Insert: Record<string, never>;
      Update: Record<string, never>;
    };
    deviation: {
      Row: DeviationRow;
      Insert: Record<string, never>;
      Update: { action: DeviationRow["action"] };
      Relationships: [
        {
          foreignKeyName: "municipality_layer_dataset_id_fkey";
          columns: ["dataset_id"];
          referencedRelation: "dataset";
          referencedColumns: ["id"];
        },
        {
          foreignKeyName: "";
          columns: ["layer_id"];
          referencedRelation: "layer";
          referencedColumns: ["id"];
        },
        {
          foreignKeyName: "";
          columns: ["municipality_code"];
          referencedRelation: "municipality";
          referencedColumns: ["code"];
        },
      ];
    };
  };
  Views: {
    dataset: {
      Row: DatasetRow;
      Relationships: [
        {
          foreignKeyName: "";
          columns: ["provider_id"];
          referencedRelation: "provider";
          referencedColumns: ["id"];
        },
      ];
    };
    provider: {
      Row: ProviderRow;
    };
    deviation_title: {
      Row: { title: string; layer_id: number; dataset_id: number; municipality_code: string; count: number };
      Relationships: [
        {
          foreignKeyName: "municipality_layer_dataset_id_fkey";
          columns: ["dataset_id"];
          referencedRelation: "dataset";
          referencedColumns: ["id"];
        },
        {
          foreignKeyName: "";
          columns: ["layer_id"];
          referencedRelation: "layer";
          referencedColumns: ["id"];
        },
        {
          foreignKeyName: "";
          columns: ["dataset_id"];
          referencedRelation: "dataset";
          referencedColumns: ["id"];
        },
        {
          foreignKeyName: "";
          columns: ["municipality_code"];
          referencedRelation: "municipality";
          referencedColumns: ["code"];
        },
      ];
    };
    upstream_item: {
      Row: UpstreamItemRow;
    };
  };
  Functions: Record<string, never>;
}
export interface Database {
  api: ApiSchema;
}

const postgrest = new PostgrestClient<Database>(APISERVER, {
  schema: "api",
});
export default postgrest;

postgrest.from("layer");
