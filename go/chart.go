// chart.go renders a text line chart.
package main

import (
	"math"
)

// cell is a grid position with a character and color.
type cell struct {
	ch    rune
	color int
}

// RenderChart prints a two-series line chart.
func RenderChart(account, index []float64, w, h int) string {
	// Guard small inputs.
	if w < 10 || h < 4 {
		return ""
	}
	if len(account) == 0 || len(index) == 0 {
		return ""
	}
	// Sample both series to width columns.
	sa := sampleSeries(account, w)
	si := sampleSeries(index, w)
	// Determine shared y range.
	yMin := math.Inf(1)
	yMax := math.Inf(-1)
	for i := 0; i < w; i++ {
		for _, v := range []float64{sa[i], si[i]} {
			if v < yMin {
				yMin = v
			}
			if v > yMax {
				yMax = v
			}
		}
	}
	if yMax == yMin {
		yMax = yMin + 1
	}
	// Map values to rows (0 top).
	rowA := make([]int, w)
	rowI := make([]int, w)
	for i := 0; i < w; i++ {
		rowA[i] = h - 1 - int(math.Round((sa[i]-yMin)/(yMax-yMin)*float64(h-1)))
		rowI[i] = h - 1 - int(math.Round((si[i]-yMin)/(yMax-yMin)*float64(h-1)))
		if rowA[i] < 0 {
			rowA[i] = 0
		}
		if rowA[i] > h-1 {
			rowA[i] = h - 1
		}
		if rowI[i] < 0 {
			rowI[i] = 0
		}
		if rowI[i] > h-1 {
			rowI[i] = h - 1
		}
	}
	// Grid cells: char + color (1=green account, 2=cyan index).
	grid := make([][]cell, h)
	for r := 0; r < h; r++ {
		grid[r] = make([]cell, w)
		for c := 0; c < w; c++ {
			grid[r][c] = cell{ch: ' ', color: 0}
		}
	}
	// Draw series A (account) in green.
	drawSeries(grid, rowA, 1)
	// Draw series I (index) in cyan.
	drawSeries(grid, rowI, 2)

	// Render.
	out := ""
	for r := 0; r < h; r++ {
		line := ""
		for c := 0; c < w; c++ {
			cell := grid[r][c]
			if cell.color == 1 {
				line += "\033[32m" + string(cell.ch) + "\033[0m"
			} else if cell.color == 2 {
				line += "\033[36m" + string(cell.ch) + "\033[0m"
			} else {
				line += string(cell.ch)
			}
		}
		out += line + "\n"
	}
	// Legend.
	out += "\033[32m\u2500\u2500\033[0m account  \033[36m\u2500\u2500\033[0m index\n"
	return out
}

// drawSeries draws a polyline for a row sequence into the grid.
func drawSeries(grid [][]cell, rows []int, color int) {
	w := len(rows)
	for i := 0; i < w; i++ {
		r := rows[i]
		if grid[r][i].color == 0 {
			grid[r][i] = cell{ch: '\u25cf', color: color}
		}
	}
	for i := 0; i < w-1; i++ {
		r0, r1 := rows[i], rows[i+1]
		if r0 == r1 {
			if grid[r0][i].color == 0 || grid[r0][i].color == color {
				grid[r0][i] = cell{ch: '\u2500', color: color}
			}
		} else {
			lo, hi := r0, r1
			if lo > hi {
				lo, hi = hi, lo
			}
			for r := lo + 1; r < hi; r++ {
				if grid[r][i].color == 0 {
					grid[r][i] = cell{ch: '\u2502', color: color}
				}
			}
		}
	}
}

// sampleSeries down-samples a series to n points.
func sampleSeries(s []float64, n int) []float64 {
	out := make([]float64, n)
	ln := len(s)
	for i := 0; i < n; i++ {
		idx := i * ln / n
		if idx >= ln {
			idx = ln - 1
		}
		out[i] = s[idx]
	}
	return out
}
