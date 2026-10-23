// main.go wires loading, simulation, metrics, and output.
package main

import (
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	// Resolve data directory relative to working dir.
	dataDir := "data"
	if _, err := os.Stat(dataDir); err != nil {
		dataDir = filepath.Join("..", "data")
	}
	coins, err := LoadCoins(dataDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	timeline := BuildTimeline(coins)
	IndexBarsByTimestamp(coins, timeline)
	meta, err := LoadMeta(filepath.Join(dataDir, "meta.json"))
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	indexValues := meta.MarketIndex.Values

	result := RunSimulation(coins, timeline)
	metrics := ComputeMetrics(result, indexValues)

	// Print metrics.
	fmt.Printf("Strategy final equity: %.2f\n", metrics.StrategyFinal)
	fmt.Printf("Market index final:    %.2f\n", metrics.IndexFinal)
	fmt.Printf("Strategy / Index:      %.4f\n", metrics.Ratio)
	if metrics.SharpeValid {
		fmt.Printf("Sharpe ratio:          %.3f\n", metrics.Sharpe)
	} else {
		fmt.Printf("Sharpe ratio:          N/A\n")
	}
	if metrics.WinLossInf {
		fmt.Printf("Win/Loss ratio:        inf (%d/%d)\n", metrics.Wins, metrics.Losses)
	} else {
		fmt.Printf("Win/Loss ratio:        %.2f (%d/%d)\n", metrics.WinLossRatio, metrics.Wins, metrics.Losses)
	}
	fmt.Printf("Avg gain per trade:    %.4f\n", metrics.AvgGain)
	fmt.Printf("Avg holding time:      %.2f steps\n", metrics.AvgHold)
	fmt.Printf("sim time: %.3f s\n", result.SimDuration.Seconds())

	// Print chart.
	chart := RenderChart(result.AccountValues, indexValues, 72, 12)
	fmt.Print(chart)
}
