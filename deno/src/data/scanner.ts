import type { Bar } from "../domain/types.ts";
import { parseRow } from "./csv.ts";

// A streaming scanner that extracts the timestamp and close price of CSV data rows.
export class CsvScanner {
  private buffer = "";
  private cursor = 0;

  // Appends a text chunk to the scanner buffer.
  push(chunk: string): void {
    this.buffer = this.cursor === 0 ? this.buffer + chunk : this.buffer.slice(this.cursor) + chunk;
    this.cursor = 0;
  }

  // Extracts the next complete data row, returning null while the buffer holds no complete row.
  next(): Bar | null {
    const text = this.buffer;
    const length = text.length;
    let pos = this.cursor;
    while (pos < length) {
      const end = text.indexOf("\n", pos);
      if (end < 0) break;
      const row = text.slice(pos, end);
      pos = end + 1;
      this.cursor = pos;
      const bar = parseRow(row);
      if (bar !== null) return bar;
    }
    this.cursor = pos;
    return null;
  }
}
