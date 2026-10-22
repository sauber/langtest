//! Helpers that build small markets and fixed signal grids for the tests.

#![allow(dead_code)]

use langtest::data::{CoinSeries, Market};
use langtest::domain::{SignalKind, Timestamp};
use langtest::strategy::{SignalGrid, Strategy};

/// The open time of the first step of a test market.
const FIRST_TIMESTAMP: i64 = 1_500_000_000;

/// Builds a market whose coins are given as one optional close per step.
pub fn market(coins: &[(&str, &[Option<f64>])]) -> Market {
    let steps = coins
        .iter()
        .map(|(_, closes)| closes.len())
        .max()
        .unwrap_or(0);
    let timestamps: Vec<Timestamp> = (0..steps)
        .map(|step| Timestamp(FIRST_TIMESTAMP + step as i64 * 3600))
        .collect();
    let series = coins
        .iter()
        .map(|(symbol, closes)| CoinSeries {
            symbol: (*symbol).to_string(),
            close: closes
                .iter()
                .map(|close| close.unwrap_or(f64::NAN))
                .collect(),
        })
        .collect();
    Market {
        coins: series,
        timestamps,
        index: vec![10_000.0; steps],
    }
}

/// A strategy that replays a fixed set of signals.
pub struct FixedStrategy(SignalGrid);

// The helpers of the fixed strategy.
impl FixedStrategy {
    /// Wraps a signal grid into a strategy.
    pub fn new(grid: SignalGrid) -> Self {
        Self(grid)
    }
}

// The strategy replays the fixed signals.
impl Strategy for FixedStrategy {
    /// Hands the fixed signals to the simulator.
    fn prepare(&self, _market: &Market) -> SignalGrid {
        self.0.clone()
    }
}

/// Builds a signal grid from the signals of the given coins and steps.
pub fn signals(
    coins: usize,
    steps: usize,
    entries: &[(usize, usize, SignalKind, f64)],
) -> SignalGrid {
    let mut kinds = vec![SignalKind::Pass; coins * steps];
    let mut strengths = vec![0.0; coins * steps];
    for (coin, step, kind, strength) in entries {
        kinds[step * coins + coin] = *kind;
        strengths[step * coins + coin] = *strength;
    }
    SignalGrid::new(kinds, strengths, coins, steps)
}
