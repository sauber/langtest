// data.go handles CSV loading and timeline construction.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// Bar is a single candle's timestamp and close price.
type Bar struct {
	Timestamp int64
	Close     float64
}

// CoinData holds all precomputed information for one coin.
type CoinData struct {
	Symbol      string
	Bars        []Bar
	RSI         []float64
	Signals     []Signal
	BuyStrength []float64
	BarAt       []int
}

// MetaMarketIndex is the market index section of meta.json.
type MetaMarketIndex struct {
	Values []float64 `json:"values"`
}

// MetaFile is the minimal meta.json structure used by the evaluator.
type MetaFile struct {
	MarketIndex MetaMarketIndex `json:"marketIndex"`
}

// LoadMeta reads meta.json and returns market index values.
func LoadMeta(path string) (MetaFile, error) {
	// Read and parse the meta file.
	f, err := os.Open(path)
	if err != nil {
		return MetaFile{}, err
	}
	defer f.Close()
	var m MetaFile
	if err := json.NewDecoder(f).Decode(&m); err != nil {
		return MetaFile{}, err
	}
	return m, nil
}

// LoadCoins reads every *-USDT.csv in dataDir and returns sorted coin data.
func LoadCoins(dataDir string) ([]*CoinData, error) {
	// Discover coin CSV files.
	entries, err := os.ReadDir(dataDir)
	if err != nil {
		return nil, err
	}
	var files []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		if strings.HasSuffix(e.Name(), "-USDT.csv") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)
	coins := make([]*CoinData, 0, len(files))
	for _, name := range files {
		coin, err := loadCoin(filepath.Join(dataDir, name))
		if err != nil {
			return nil, err
		}
		coins = append(coins, coin)
	}
	return coins, nil
}

// loadCoin parses a single coin CSV file.
func loadCoin(path string) (*CoinData, error) {
	// Open and scan the CSV.
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	symbol := strings.TrimSuffix(filepath.Base(path), ".csv")
	coin := &CoinData{Symbol: symbol}
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	header := true
	for scanner.Scan() {
		line := scanner.Text()
		if header {
			header = false
			continue
		}
		if line == "" {
			continue
		}
		fields := strings.Split(line, ",")
		if len(fields) < 7 {
			continue
		}
		ts, err := strconv.ParseInt(strings.TrimSpace(fields[0]), 10, 64)
		if err != nil {
			return nil, fmt.Errorf("bad timestamp: %w", err)
		}
		closePx, err := strconv.ParseFloat(strings.TrimSpace(fields[5]), 64)
		if err != nil {
			return nil, fmt.Errorf("bad close: %w", err)
		}
		coin.Bars = append(coin.Bars, Bar{Timestamp: ts, Close: closePx})
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	// Precompute RSI and signals.
	closes := make([]float64, len(coin.Bars))
	for i, b := range coin.Bars {
		closes[i] = b.Close
	}
	coin.RSI = ComputeRSI(closes, 14)
	coin.Signals, coin.BuyStrength = SignalsFromRSI(coin.RSI)
	return coin, nil
}

// BuildTimeline creates the sorted union of all bar timestamps.
func BuildTimeline(coins []*CoinData) []int64 {
	// Collect unique timestamps.
	set := make(map[int64]struct{})
	for _, c := range coins {
		for _, b := range c.Bars {
			set[b.Timestamp] = struct{}{}
		}
	}
	out := make([]int64, 0, len(set))
	for ts := range set {
		out = append(out, ts)
	}
	sort.Slice(out, func(i, j int) bool { return out[i] < out[j] })
	return out
}

// IndexBarsByTimestamp maps each coin's bars to timeline steps.
func IndexBarsByTimestamp(coins []*CoinData, timeline []int64) {
	// Build a timestamp->step map.
	stepOf := make(map[int64]int, len(timeline))
	for i, ts := range timeline {
		stepOf[ts] = i
	}
	for _, c := range coins {
		c.BarAt = make([]int, len(timeline))
		for i := range c.BarAt {
			c.BarAt[i] = -1
		}
		for bi, b := range c.Bars {
			if idx, ok := stepOf[b.Timestamp]; ok {
				c.BarAt[idx] = bi
			}
		}
	}
}
