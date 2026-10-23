// sim_test.go covers simulator rules.
package main

import (
	"math"
	"testing"
)

func makeCoin(symbol string, bars []Bar, signals []Signal, strengths []float64) *CoinData {
	// Build a coin with explicit signals for testing.
	c := &CoinData{Symbol: symbol, Bars: bars, Signals: signals, BuyStrength: strengths}
	c.RSI = make([]float64, len(bars))
	return c
}

func TestSimFeesAndSingleTrade(t *testing.T) {
	// One coin bought then sold; verify fees.
	bars := []Bar{{Timestamp: 1, Close: 100}, {Timestamp: 2, Close: 110}}
	signals := []Signal{SignalBuy, SignalSell}
	strengths := []float64{10, 0}
	coin := makeCoin("A-USDT", bars, signals, strengths)
	coin.BarAt = []int{0, 1}
	coins := []*CoinData{coin}
	timeline := []int64{1, 2}
	IndexBarsByTimestamp(coins, timeline)
	res := RunSimulation(coins, timeline)
	if len(res.Trades) != 1 {
		t.Fatalf("expected 1 trade, got %d", len(res.Trades))
	}
	tr := res.Trades[0]
	qty := 10000.0 / (100 * 1.001)
	proceeds := qty * 110 * 0.999
	if math.Abs(tr.Proceeds-proceeds) > 1e-6 {
		t.Fatalf("proceeds mismatch: %v vs %v", tr.Proceeds, proceeds)
	}
	if math.Abs(res.AccountValues[1]-proceeds) > 1e-6 {
		t.Fatalf("final equity mismatch: %v", res.AccountValues[1])
	}
}

func TestSimSinglePositionEnforcement(t *testing.T) {
	// Two buy candidates at same step; highest strength wins.
	barsA := []Bar{{Timestamp: 1, Close: 100}, {Timestamp: 2, Close: 105}}
	barsB := []Bar{{Timestamp: 1, Close: 50}, {Timestamp: 2, Close: 55}}
	sigA := []Signal{SignalBuy, SignalPass}
	sigB := []Signal{SignalBuy, SignalSell}
	strA := []float64{5, 0}
	strB := []float64{10, 0}
	coinA := makeCoin("A-USDT", barsA, sigA, strA)
	coinB := makeCoin("B-USDT", barsB, sigB, strB)
	coins := []*CoinData{coinA, coinB}
	timeline := []int64{1, 2}
	IndexBarsByTimestamp(coins, timeline)
	res := RunSimulation(coins, timeline)
	// B has higher strength, should be bought then sold at step1.
	if len(res.Trades) != 1 {
		t.Fatalf("expected 1 trade, got %d", len(res.Trades))
	}
	// Proceeds based on B.
	qty := 10000.0 / (50 * 1.001)
	proceeds := qty * 55 * 0.999
	if math.Abs(res.Trades[0].Proceeds-proceeds) > 1e-6 {
		t.Fatalf("wrong coin traded")
	}
}

func TestSimTieBreakAlphabetical(t *testing.T) {
	// Equal strengths: alphabetically first symbol wins.
	barsA := []Bar{{Timestamp: 1, Close: 100}, {Timestamp: 2, Close: 101}}
	barsB := []Bar{{Timestamp: 1, Close: 100}, {Timestamp: 2, Close: 101}}
	sig := []Signal{SignalBuy, SignalSell}
	str := []float64{5, 0}
	coinA := makeCoin("A-USDT", barsA, sig, str)
	coinB := makeCoin("B-USDT", barsB, sig, str)
	coins := []*CoinData{coinA, coinB} // already sorted A,B
	timeline := []int64{1, 2}
	IndexBarsByTimestamp(coins, timeline)
	res := RunSimulation(coins, timeline)
	qty := 10000.0 / (100 * 1.001)
	proceeds := qty * 101 * 0.999
	if math.Abs(res.Trades[0].Proceeds-proceeds) > 1e-6 {
		t.Fatalf("tie-break failed")
	}
}

func TestSimDataGapNoSell(t *testing.T) {
	// Held coin missing at step1, sells at step2.
	bars := []Bar{{Timestamp: 1, Close: 100}, {Timestamp: 3, Close: 90}}
	signals := []Signal{SignalBuy, SignalSell}
	strengths := []float64{10, 0}
	coin := makeCoin("A-USDT", bars, signals, strengths)
	coins := []*CoinData{coin}
	timeline := []int64{1, 2, 3}
	IndexBarsByTimestamp(coins, timeline)
	res := RunSimulation(coins, timeline)
	if len(res.Trades) != 1 {
		t.Fatalf("expected 1 trade, got %d", len(res.Trades))
	}
	if res.Trades[0].SellStep != 2 {
		t.Fatalf("expected sell at step 2, got %d", res.Trades[0].SellStep)
	}
	// At step1 (gap), value carried at last known close 100.
	if math.Abs(res.AccountValues[1]-10000.0/(100*1.001)*100) > 1e-6 {
		t.Fatalf("gap valuation wrong: %v", res.AccountValues[1])
	}
}

func TestSimReentrySameStep(t *testing.T) {
	// Sell then buy another coin in same step.
	barsA := []Bar{{Timestamp: 1, Close: 100}, {Timestamp: 2, Close: 90}}
	barsB := []Bar{{Timestamp: 2, Close: 50}}
	sigA := []Signal{SignalBuy, SignalSell}
	sigB := []Signal{SignalBuy}
	strA := []float64{5, 0}
	strB := []float64{10}
	coinA := makeCoin("A-USDT", barsA, sigA, strA)
	coinB := makeCoin("B-USDT", barsB, sigB, strB)
	coins := []*CoinData{coinA, coinB}
	timeline := []int64{1, 2}
	IndexBarsByTimestamp(coins, timeline)
	res := RunSimulation(coins, timeline)
	// Should sell A and buy B at step1.
	if len(res.Trades) != 1 {
		t.Fatalf("expected 1 closed trade, got %d", len(res.Trades))
	}
	// Final held B, value at close 50.
	qtyB := (10000.0/(100*1.001)*90*0.999) / (50 * 1.001)
	if math.Abs(res.AccountValues[1]-qtyB*50) > 1e-6 {
		t.Fatalf("reentry valuation wrong: %v", res.AccountValues[1])
	}
}
