import { MantineColor } from "@mantine/core";
import { DatasetUsage } from "../postgrest.ts";

export function colorForDeviationCount(count: number): MantineColor {
  if (count === 0) {
    return "green";
  } else if (count < 10) {
    return "yellow";
  } else if (count < 100) {
    return "orange";
  } else {
    return "red";
  }
}

export function colorForDatasetUsage(usage: DatasetUsage | undefined): MantineColor {
  if (usage === "advisory") {
    return "lime";
  } else if (usage === "complete") {
    return "green";
  } else if (usage === "automatic") {
    return "blue";
  } else {
    return "gray";
  }
}

export function colorForMonthsSinceCheck(monthsSinceCheck: number | undefined): MantineColor {
  if (monthsSinceCheck === undefined) {
    return "red";
  } else if (monthsSinceCheck < 6) {
    return "green";
  } else if (monthsSinceCheck < 24) {
    return "lime";
  } else if (monthsSinceCheck < 36) {
    return "yellow";
  } else {
    return "orange";
  }
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
