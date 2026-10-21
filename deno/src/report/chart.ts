// The number of plot columns inside the chart frame.
const PLOT_WIDTH = 66;

// The number of plot rows inside the chart frame.
const PLOT_HEIGHT = 13;

// The width of the left gutter that carries the axis labels.
const GUTTER = 7;

// The inner width of the chart frame, excluding the border characters.
const INNER_WIDTH = GUTTER + PLOT_WIDTH + 3;

// The ANSI colour of the strategy equity line.
const EQUITY_COLOR = "96";

// The ANSI colour of the market index line.
const INDEX_COLOR = "95";

// Down-samples a value series into the given number of columns by averaging buckets.
function downsample(series: Float64Array, width: number): Float64Array {
  const buckets = new Float64Array(width);
  const count = series.length;
  for (let column = 0; column < width; column++) {
    const from = Math.floor((column * count) / width);
    const to = Math.max(from + 1, Math.floor(((column + 1) * count) / width));
    let sum = 0;
    for (let index = from; index < to; index++) sum += series[index];
    buckets[column] = sum / (to - from);
  }
  return buckets;
}

// Converts a value into a row index on a shared linear axis.
function toRow(value: number, min: number, max: number, height: number): number {
  if (max <= min) return height - 1;
  const row = Math.round(((max - value) / (max - min)) * (height - 1));
  return Math.min(height - 1, Math.max(0, row));
}

// Rasterises one polyline into a character grid using soft line-drawing characters.
function rasterize(rows: Float64Array, height: number): string[][] {
  const grid: string[][] = [];
  for (let row = 0; row < height; row++) grid.push(new Array<string>(rows.length).fill(" "));
  const first = Math.round(rows[0]);
  const rising = rows.length > 1 && Math.round(rows[1]) < first;
  grid[first][0] = rising ? "╰" : "╭";
  for (let column = 1; column < rows.length; column++) {
    const from = Math.round(rows[column - 1]);
    const to = Math.round(rows[column]);
    if (from === to) {
      grid[from][column] = "─";
      continue;
    }
    const low = Math.min(from, to);
    const high = Math.max(from, to);
    for (let row = low; row <= high; row++) grid[row][column] = "│";
    grid[from][column] = to < from ? "╯" : "╮";
    grid[to][column] = "╰";
  }
  return grid;
}

// Formats a large number compactly for the narrow axis gutter.
function formatCompact(value: number): string {
  const absolute = Math.abs(value);
  if (absolute >= 1e9) return `${(value / 1e9).toFixed(2)}B`;
  if (absolute >= 1e6) return `${(value / 1e6).toFixed(2)}M`;
  if (absolute >= 1e3) return `${(value / 1e3).toFixed(1)}k`;
  return value.toFixed(0);
}

// Formats a timestamp as a plain calendar date.
function formatDate(timestamp: number): string {
  return new Date(timestamp * 1000).toISOString().slice(0, 10);
}

// Merges the two plot rows into one coloured terminal row.
function buildRow(equityRow: readonly string[], indexRow: readonly string[]): string {
  const parts: string[] = [];
  let run = "";
  let color = "";
  for (let column = 0; column < PLOT_WIDTH; column++) {
    const equityChar = equityRow[column];
    const indexChar = indexRow[column];
    let char = " ";
    let charColor = "";
    if (equityChar !== " ") {
      char = equityChar;
      charColor = EQUITY_COLOR;
    } else if (indexChar !== " ") {
      char = indexChar;
      charColor = INDEX_COLOR;
    }
    if (charColor !== color) {
      if (run !== "") parts.push(color === "" ? run : `\x1b[${color}m${run}\x1b[0m`);
      run = "";
      color = charColor;
    }
    run += char;
  }
  if (run !== "") parts.push(color === "" ? run : `\x1b[${color}m${run}\x1b[0m`);
  return parts.join("");
}

// Draws the equity curve and the market index as two polylines on one shared linear axis.
export function renderChart(
  equity: Float64Array,
  index: Float64Array,
  firstTimestamp: number,
  lastTimestamp: number,
): string[] {
  const equityColumns = downsample(equity, PLOT_WIDTH);
  const indexColumns = downsample(index, PLOT_WIDTH);
  let min = Infinity;
  let max = -Infinity;
  for (const value of equityColumns) {
    if (value < min) min = value;
    if (value > max) max = value;
  }
  for (const value of indexColumns) {
    if (value < min) min = value;
    if (value > max) max = value;
  }
  const equityRows = Float64Array.from(
    equityColumns,
    (value) => toRow(value, min, max, PLOT_HEIGHT),
  );
  const indexRows = Float64Array.from(indexColumns, (value) => toRow(value, min, max, PLOT_HEIGHT));
  const equityGrid = rasterize(equityRows, PLOT_HEIGHT);
  const indexGrid = rasterize(indexRows, PLOT_HEIGHT);
  const lines: string[] = [`╭${"─".repeat(INNER_WIDTH)}╮`];
  for (let row = 0; row < PLOT_HEIGHT; row++) {
    const label = row === 0
      ? formatCompact(max)
      : row === PLOT_HEIGHT - 1
      ? formatCompact(min)
      : row === Math.floor(PLOT_HEIGHT / 2)
      ? formatCompact((max + min) / 2)
      : "";
    lines.push(`│ ${label.padStart(GUTTER)}┤${buildRow(equityGrid[row], indexGrid[row])} │`);
  }
  const start = `─ ${formatDate(firstTimestamp)} `;
  const end = ` ${formatDate(lastTimestamp)} `;
  const dashes = Math.max(0, INNER_WIDTH - start.length - end.length);
  lines.push(`╰${start}${"─".repeat(dashes)}${end}╯`);
  return lines;
}
