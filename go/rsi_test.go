// rsi_test.go covers RSI computation.
package main

import (
	"math"
	"testing"
)

func TestComputeRSIFirstValueAtPeriod(t *testing.T) {
	// RSI should be NaN for the first `period` bars.
	closes := make([]float64, 20)
	for i := range closes {
		closes[i] = 100 + float64(i)
	}
	rsi := ComputeRSI(closes, 14)
	for i := 0; i < 14; i++ {
		if !math.IsNaN(rsi[i]) {
			t.Fatalf("expected NaN at index %d, got %v", i, rsi[i])
		}
	}
	if math.IsNaN(rsi[14]) {
		t.Fatal("expected RSI at index 14")
	}
}

func TestComputeRSIAllRisingIs100(t *testing.T) {
	// Strictly rising prices yield RSI of 100.
	closes := make([]float64, 20)
	for i := range closes {
		closes[i] = 100 + float64(i)*2
	}
	rsi := ComputeRSI(closes, 14)
	if math.Abs(rsi[19]-100) > 1e-9 {
		t.Fatalf("expected 100, got %v", rsi[19])
	}
}

func TestSignalsFromRSI(t *testing.T) {
	// Buy when RSI <= 30, sell when >= 70.
	rsi := []float64{25, 50, 75, math.NaN()}
	signals, strengths := SignalsFromRSI(rsi)
	if signals[0] != SignalBuy || strengths[0] != 5 {
		t.Fatalf("buy signal wrong: %v %v", signals[0], strengths[0])
	}
	if signals[1] != SignalPass {
		t.Fatalf("pass expected")
	}
	if signals[2] != SignalSell {
		t.Fatalf("sell expected")
	}
	if signals[3] != SignalPass {
		t.Fatalf("nan pass expected")
	}
}
