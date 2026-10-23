// sim.go implements the trading simulator.
package main

import "time"

// Trade is a closed position.
type Trade struct {
	BuyStep  int
	SellStep int
	Cost     float64
	Proceeds float64
}

// SimResult holds simulation outputs.
type SimResult struct {
	AccountValues []float64
	Trades        []Trade
	SimDuration   time.Duration
}

// RunSimulation executes the hourly strategy loop.
func RunSimulation(coins []*CoinData, timeline []int64) SimResult {
	// Preallocate outputs.
	nCoins := len(coins)
	steps := len(timeline)
	accountValues := make([]float64, steps)
	trades := make([]Trade, 0, 1024)
	// Precompute the best buy candidate for every step (outside timed loop).
	bestBuy := make([]int, steps)
	for step := 0; step < steps; step++ {
		best := -1
		bestStrength := 0.0
		hasBest := false
		for ci := 0; ci < nCoins; ci++ {
			bi := coins[ci].BarAt[step]
			if bi < 0 {
				continue
			}
			if coins[ci].Signals[bi] != SignalBuy {
				continue
			}
			st := coins[ci].BuyStrength[bi]
			if !hasBest || st > bestStrength {
				bestStrength = st
				best = ci
				hasBest = true
			}
		}
		bestBuy[step] = best
	}

	// State.
	cash := 10000.0
	held := -1
	heldQty := 0.0
	heldLastClose := 0.0
	heldBuyStep := 0
	heldCost := 0.0

	start := time.Now()
	for step := 0; step < steps; step++ {
		// Rule 2: sell if held coin has a sell signal at this step.
		if held >= 0 {
			bi := coins[held].BarAt[step]
			if bi >= 0 && coins[held].Signals[bi] == SignalSell {
				closePx := coins[held].Bars[bi].Close
				proceeds := heldQty * closePx * 0.999
				cash += proceeds
				trades = append(trades, Trade{
					BuyStep:  heldBuyStep,
					SellStep: step,
					Cost:     heldCost,
					Proceeds: proceeds,
				})
				held = -1
				heldQty = 0
				heldLastClose = closePx
			}
		}
		// Rule 3: buy best candidate if flat.
		if held < 0 {
			best := bestBuy[step]
			if best >= 0 {
				bi := coins[best].BarAt[step]
				closePx := coins[best].Bars[bi].Close
				heldCost = cash
				heldQty = cash / (closePx * 1.001)
				cash = 0
				held = best
				heldBuyStep = step
				heldLastClose = closePx
			}
		}
		// Valuation.
		if held >= 0 {
			bi := coins[held].BarAt[step]
			if bi >= 0 {
				heldLastClose = coins[held].Bars[bi].Close
			}
			accountValues[step] = cash + heldQty*heldLastClose
		} else {
			accountValues[step] = cash
		}
	}
	duration := time.Since(start)
	return SimResult{
		AccountValues: accountValues,
		Trades:        trades,
		SimDuration:   duration,
	}
}
