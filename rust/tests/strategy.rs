//! The default strategy: the RSI thresholds and the buy strength.

// The shared helpers of the tests.
mod common;

use common::market;
use langtest::data::Market;
use langtest::domain::SignalKind;
use langtest::strategy::{RsiStrategy, Strategy};

/// Builds a market with one coin whose closes are given.
fn single_coin(closes: &[f64]) -> Market {
    let steps: Vec<Option<f64>> = closes.iter().copied().map(Some).collect();
    market(&[("AAA-USDT", steps.as_slice())])
}

/// Builds a market with one coin that falls by one unit per bar.
fn falling() -> Market {
    let closes: Vec<f64> = (0..20).map(|index| 100.0 - index as f64).collect();
    single_coin(&closes)
}

/// An oversold coin is a buy whose strength is `30 - rsi`.
#[test]
fn an_oversold_coin_is_a_buy() {
    let market = falling();
    let grid = RsiStrategy::default().prepare(&market);
    assert_eq!(grid.kind(19, 0), SignalKind::Buy);
    assert!((grid.strength(19, 0).get() - 30.0).abs() < 1e-12);
}

/// An overbought coin is a sell.
#[test]
fn an_overbought_coin_is_a_sell() {
    let closes: Vec<f64> = (0..20).map(|index| 100.0 + index as f64).collect();
    let market = single_coin(&closes);
    let grid = RsiStrategy::default().prepare(&market);
    assert_eq!(grid.kind(19, 0), SignalKind::Sell);
}

/// A coin that moves up and down by the same amount neither oversold nor overbought.
#[test]
fn a_neutral_coin_passes() {
    let closes: Vec<f64> = (0..20)
        .map(|index| if index % 2 == 0 { 100.0 } else { 101.0 })
        .collect();
    let market = single_coin(&closes);
    let grid = RsiStrategy::default().prepare(&market);
    assert_eq!(grid.kind(19, 0), SignalKind::Pass);
}

/// The bars before the RSI can be computed carry no signal.
#[test]
fn the_first_fourteen_bars_have_no_signal() {
    let market = falling();
    let grid = RsiStrategy::default().prepare(&market);
    for step in 0..14 {
        assert_eq!(grid.kind(step, 0), SignalKind::Pass);
    }
}

/// A coin without a bar at a step has no signal at that step.
#[test]
fn a_gap_carries_no_signal() {
    let steps = vec![Some(100.0), None, Some(100.0), Some(100.0)];
    let market = market(&[("AAA-USDT", steps.as_slice())]);
    let grid = RsiStrategy::default().prepare(&market);
    assert_eq!(grid.kind(1, 0), SignalKind::Pass);
}
