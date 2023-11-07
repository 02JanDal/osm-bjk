import { MantineColor } from "@mantine/core";

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
