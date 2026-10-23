// Package tradingeval implements the RSI trading strategy evaluator.
package main

import "math"

// Signal represents the strategy output for one bar.
type Signal int8

const (
	// SignalPass means no actionable signal.
	SignalPass Signal = iota
	// SignalBuy means RSI is at or below 30.
	SignalBuy
	// SignalSell means RSI is at or above 70.
	SignalSell
)

// ComputeRSI returns Wilder-smoothed 14-period RSI values aligned with closes.
func ComputeRSI(closes []float64, period int) []float64 {
	// Allocate the output slice filled with NaN for non-computable bars.
	n := len(closes)
	out := make([]float64, n)
	for i := range out {
		out[i] = math.NaN()
	}
	if n <= period || period <= 0 {
		return out
	}
	// Seed the averages with the first `period` price changes.
	var gain, loss float64
	for i := 1; i <= period; i++ {
		delta := closes[i] - closes[i-1]
		if delta > 0 {
			gain += delta
		} else {
			loss -= delta
		}
	}
	avgGain := gain / float64(period)
	avgLoss := loss / float64(period)
	// Record the first computable RSI at index `period`.
	if avgLoss == 0 {
		out[period] = 100
	} else {
		rs := avgGain / avgLoss
		out[period] = 100 - 100/(1+rs)
	}
	// Smooth subsequent values with Wilder's method.
	for i := period + 1; i < n; i++ {
		delta := closes[i] - closes[i-1]
		g, l := 0.0, 0.0
		if delta > 0 {
			g = delta
		} else {
			l = -delta
		}
		avgGain = (avgGain*float64(period-1) + g) / float64(period)
		avgLoss = (avgLoss*float64(period-1) + l) / float64(period)
		if avgLoss == 0 {
			out[i] = 100
		} else {
			rs := avgGain / avgLoss
			out[i] = 100 - 100/(1+rs)
		}
	}
	return out
}

// SignalsFromRSI converts RSI values into buy/sell/pass signals.
func SignalsFromRSI(rsi []float64) ([]Signal, []float64) {
	// Produce one signal and buy strength per bar.
	n := len(rsi)
	signals := make([]Signal, n)
	strengths := make([]float64, n)
	for i := 0; i < n; i++ {
		if math.IsNaN(rsi[i]) {
			signals[i] = SignalPass
			strengths[i] = 0
			continue
		}
		if rsi[i] <= 30 {
			signals[i] = SignalBuy
			strengths[i] = 30 - rsi[i]
		} else if rsi[i] >= 70 {
			signals[i] = SignalSell
			strengths[i] = 0
		} else {
			signals[i] = SignalPass
			strengths[i] = 0
		}
	}
	return signals, strengths
}
