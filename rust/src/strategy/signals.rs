//! The strategy trait, the signal grid it produces and the default RSI strategy.

use crate::data::Market;
use crate::domain::{BuyStrength, SignalKind};
use crate::strategy::rsi::{PERIOD, wilder_rsi};

/// A swappable trading strategy.
///
/// The simulator takes the strategy as input and asks it for the signals of every coin before
/// the stepping loop starts, so the loop itself only reads plain arrays.
pub trait Strategy {
    /// The signals of every coin, aligned to the shared timeline.
    fn prepare(&self, market: &Market) -> SignalGrid;
}

/// The signals of every coin on the shared timeline.
///
/// The grid is stored step-major, so the signals of one step sit next to each other and the
/// stepping loop reads them as one cache line.
#[derive(Clone, Debug)]
pub struct SignalGrid {
    kinds: Vec<SignalKind>,
    strengths: Vec<f64>,
    coins: usize,
    steps: usize,
}

// The helpers of a signal grid.
impl SignalGrid {
    /// Builds a grid from the signal kind and the buy strength of every coin and step.
    pub fn new(kinds: Vec<SignalKind>, strengths: Vec<f64>, coins: usize, steps: usize) -> Self {
        debug_assert_eq!(kinds.len(), coins * steps);
        debug_assert_eq!(strengths.len(), coins * steps);
        Self {
            kinds,
            strengths,
            coins,
            steps,
        }
    }

    /// The number of coins the grid covers.
    pub fn coins(&self) -> usize {
        self.coins
    }

    /// The number of steps the grid covers.
    pub fn steps(&self) -> usize {
        self.steps
    }

    /// The signal kind of one coin at one step.
    pub fn kind(&self, step: usize, coin: usize) -> SignalKind {
        self.kinds[step * self.coins + coin]
    }

    /// The buy strength of one coin at one step.
    pub fn strength(&self, step: usize, coin: usize) -> BuyStrength {
        BuyStrength(self.strengths[step * self.coins + coin])
    }
}

/// The default strategy: buy below an RSI of 30, sell above an RSI of 70.
#[derive(Clone, Debug)]
pub struct RsiStrategy {
    period: usize,
    buy_below: f64,
    sell_above: f64,
}

// The helpers of the RSI strategy.
impl RsiStrategy {
    /// The strategy with the canonical thresholds of 30 and 70.
    pub fn new(period: usize) -> Self {
        Self {
            period,
            buy_below: 30.0,
            sell_above: 70.0,
        }
    }
}

// The default strategy is the canonical RSI(14) strategy.
impl Default for RsiStrategy {
    /// The canonical RSI(14) strategy.
    fn default() -> Self {
        Self::new(PERIOD)
    }
}

// The strategy turns the RSI of every coin into a signal.
impl Strategy for RsiStrategy {
    /// Computes the RSI of every coin and turns it into a signal.
    fn prepare(&self, market: &Market) -> SignalGrid {
        let coins = market.coins.len();
        let steps = market.timestamps.len();
        let mut kinds = vec![SignalKind::Pass; steps * coins];
        let mut strengths = vec![0.0; steps * coins];

        for (coin, series) in market.coins.iter().enumerate() {
            let values = wilder_rsi(&series.close, self.period);
            for (step, &value) in values.iter().enumerate() {
                if value.is_nan() {
                    continue;
                }
                let slot = step * coins + coin;
                if value <= self.buy_below {
                    kinds[slot] = SignalKind::Buy;
                    strengths[slot] = self.buy_below - value;
                } else if value >= self.sell_above {
                    kinds[slot] = SignalKind::Sell;
                }
            }
        }
        SignalGrid::new(kinds, strengths, coins, steps)
    }
}
