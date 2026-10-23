// metrics_test.go covers metric computations.
package main

import (
	"math"
	"testing"
)

func TestMetricsSharpe(t *testing.T) {
	// Simple increasing values.
	vals := []float64{100, 102, 101, 103}
	res := SimResult{AccountValues: vals}
	m := ComputeMetrics(res, []float64{100, 100, 100, 100})
	if !m.SharpeValid {
		t.Fatal("sharpe should be valid")
	}
	// manual
	returns := []float64{0.02, -0.0098039216, 0.0198019802}
	var sum float64
	for _, r := range returns {
		sum += r
	}
	mean := sum / 3
	var sq float64
	for _, r := range returns {
		d := r - mean
		sq += d * d
	}
	std := math.Sqrt(sq / 2)
	exp := mean / std * math.Sqrt(8760)
	if math.Abs(m.Sharpe-exp) > 1e-6 {
		t.Fatalf("sharpe mismatch: %v vs %v", m.Sharpe, exp)
	}
}

func TestMetricsWinLoss(t *testing.T) {
	res := SimResult{
		AccountValues: []float64{10000},
		Trades: []Trade{
			{Cost: 100, Proceeds: 110},
			{Cost: 100, Proceeds: 90},
			{Cost: 100, Proceeds: 100},
		},
	}
	m := ComputeMetrics(res, []float64{10000})
	if m.Wins != 1 || m.Losses != 1 {
		t.Fatalf("wins/losses wrong: %d/%d", m.Wins, m.Losses)
	}
	if math.Abs(m.WinLossRatio-1) > 1e-9 {
		t.Fatalf("ratio wrong")
	}
	if math.Abs(m.AvgGain-((0.1-0.1)/3)) > 1e-9 {
		// (0.1 + -0.1 + 0)/3 = 0
		if math.Abs(m.AvgGain) > 1e-9 {
			t.Fatalf("avg gain wrong: %v", m.AvgGain)
		}
	}
}

func TestMetricsInf(t *testing.T) {
	res := SimResult{
		AccountValues: []float64{10000, 10100},
		Trades:        []Trade{{Cost: 100, Proceeds: 110}},
	}
	m := ComputeMetrics(res, []float64{10000, 10000})
	if !m.WinLossInf {
		t.Fatal("expected inf")
	}
}

func TestMetricsHoldingTime(t *testing.T) {
	res := SimResult{
		AccountValues: []float64{10000, 10000},
		Trades: []Trade{
			{BuyStep: 0, SellStep: 5, Cost: 100, Proceeds: 110},
			{BuyStep: 2, SellStep: 4, Cost: 100, Proceeds: 90},
		},
	}
	m := ComputeMetrics(res, []float64{10000, 10000})
	if math.Abs(m.AvgHold-((5+2)/2.0)) > 1e-9 {
		t.Fatalf("avg hold wrong: %v", m.AvgHold)
	}
}
