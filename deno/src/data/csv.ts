import type { Bar } from "../domain/types.ts";

// The number of leading CSV fields that precede the closing price column.
const CLOSE_FIELD_INDEX = 5;

// Parses one CSV data row into the timestamp and close price the evaluator needs.
export function parseRow(row: string): Bar | null {
  if (row.length === 0) return null;
  const timestamp = Number(row.slice(0, row.indexOf(",")));
  if (!Number.isFinite(timestamp)) return null;
  let start = 0;
  for (let field = 0; field < CLOSE_FIELD_INDEX; field++) {
    start = row.indexOf(",", start) + 1;
  }
  const comma = row.indexOf(",", start);
  const close = Number(comma < 0 ? row.slice(start) : row.slice(start, comma));
  return { timestamp, close };
}
