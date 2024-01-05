import { MantineColor } from "@mantine/core";
import { DatasetUsage } from "../postgrest.ts";

export const ABOVE = Symbol("above");

export const COLORS_FOR_DEVIATION_COUNT: [number | typeof ABOVE, MantineColor][] = [
  [0, "green"],
  [10, "yellow"],
  [100, "orange"],
  [ABOVE, "red"],
];
export function colorForDeviationCount(count: number): MantineColor {
  return COLORS_FOR_DEVIATION_COUNT.find(([c, _]) => c === ABOVE || count <= c)![1];
}

export const COLORS_FOR_DATASET_USAGE: [DatasetUsage | typeof ABOVE, MantineColor][] = [
  ["automatic", "blue"],
  ["complete", "green"],
  ["advisory", "lime"],
  [ABOVE, "gray"],
];
export function colorForDatasetUsage(usage: DatasetUsage | undefined): MantineColor {
  return COLORS_FOR_DATASET_USAGE.find(([u, _]) => usage === u || u === ABOVE)![1];
}

export const COLORS_FOR_MONTHS_SINCE_CHECK: [number | typeof ABOVE | null, MantineColor][] = [
  [6, "green"],
  [24, "lime"],
  [36, "yellow"],
  [ABOVE, "orange"],
  [null, "red"],
];
export function colorForMonthsSinceCheck(monthsSinceCheck: number | null): MantineColor {
  return COLORS_FOR_MONTHS_SINCE_CHECK.find(([m, _]) =>
    monthsSinceCheck === null ? m === null : m === ABOVE || (m !== null && monthsSinceCheck <= m),
  )![1];
}

export function bestDatasetType(datasets: { datasetType?: DatasetUsage | null }[]): DatasetUsage | undefined {
  if (datasets.some((d) => d.datasetType === "automatic")) {
    return "automatic";
  } else if (datasets.some((d) => d.datasetType === "complete")) {
    return "complete";
  } else if (datasets.some((d) => d.datasetType === "advisory")) {
    return "advisory";
  } else {
    return undefined;
  }
}
