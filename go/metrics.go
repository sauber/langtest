// metrics.go computes performance statistics.
package main

import "math"

// Metrics holds computed performance numbers.
type Metrics struct {
	StrategyFinal float64
	IndexFinal    float64
	Ratio         float64
	Sharpe        float64
	SharpeValid   bool
	Wins          int
	Losses        int
	WinLossRatio  float64
	WinLossInf    bool
	AvgGain       float64
	AvgHold       float64
	TradeCount    int
}

// ComputeMetrics derives all performance metrics.
func ComputeMetrics(result SimResult, indexValues []float64) Metrics {
	// Final equity comparison.
	m := Metrics{}
	steps := len(result.AccountValues)
	if steps == 0 {
		return m
	}
	m.StrategyFinal = result.AccountValues[steps-1]
	if len(indexValues) > 0 {
		m.IndexFinal = indexValues[len(indexValues)-1]
	}
	if m.IndexFinal != 0 {
		m.Ratio = m.StrategyFinal / m.IndexFinal
	}
	// Sharpe ratio.
	if steps >= 2 {
		returns := make([]float64, steps-1)
		for i := 1; i < steps; i++ {
			prev := result.AccountValues[i-1]
			if prev != 0 {
				returns[i-1] = result.AccountValues[i]/prev - 1
			}
		}
		n := len(returns)
		var sum float64
		for _, r := range returns {
			sum += r
		}
		mean := sum / float64(n)
		var sq float64
		for _, r := range returns {
			d := r - mean
			sq += d * d
		}
		variance := sq / float64(n-1)
		std := math.Sqrt(variance)
		if std != 0 {
			m.Sharpe = mean / std * math.Sqrt(8760)
			m.SharpeValid = true
		}
	}
	// Trade statistics.
	m.TradeCount = len(result.Trades)
	var gainSum, holdSum float64
	for _, t := range result.Trades {
		if t.Cost == 0 {
			continue
		}
		ret := t.Proceeds/t.Cost - 1
		gainSum += ret
		holdSum += float64(t.SellStep - t.BuyStep)
		if ret > 0 {
			m.Wins++
		} else if ret < 0 {
			m.Losses++
		}
	}
	if m.TradeCount > 0 {
		m.AvgGain = gainSum / float64(m.TradeCount)
		m.AvgHold = holdSum / float64(m.TradeCount)
	}
	if m.Losses == 0 && m.Wins > 0 {
		m.WinLossInf = true
	} else if m.Losses > 0 {
		m.WinLossRatio = float64(m.Wins) / float64(m.Losses)
	}
	return m
}
