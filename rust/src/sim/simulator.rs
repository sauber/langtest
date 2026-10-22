//! The hourly stepping loop: the hot path of the evaluation.

use std::time::{Duration, Instant};

use crate::data::Market;
use crate::domain::{Price, SignalKind, Usdt};
use crate::sim::portfolio::{self, INITIAL_CAPITAL, Position, Trade};
use crate::strategy::Strategy;

/// The result of one simulation.
#[derive(Clone, Debug)]
pub struct Simulation {
    /// The account value at every step of the shared timeline.
    pub equity: Vec<f64>,
    /// The closed trades, in the order they were closed.
    pub trades: Vec<Trade>,
    /// The wall-clock duration of the stepping loop.
    pub elapsed: Duration,
}

/// Runs a strategy over the shared timeline of a market.
pub struct Simulator<'a> {
    market: &'a Market,
    strategy: &'a dyn Strategy,
}

// The simulator runs a strategy over a market.
impl<'a> Simulator<'a> {
    /// Binds the simulator to a market and a strategy.
    pub fn new(market: &'a Market, strategy: &'a dyn Strategy) -> Self {
        Self { market, strategy }
    }

    /// Runs the stepping loop and returns the account value and the closed trades.
    ///
    /// The signals are computed before the loop starts; only the loop itself is timed.
    pub fn run(&self) -> Simulation {
        let signals = self.strategy.prepare(self.market);
        let coins = self.market.coins.len();
        let steps = self.market.timestamps.len();
        let closes: Vec<&[f64]> = self
            .market
            .coins
            .iter()
            .map(|coin| coin.close.as_slice())
            .collect();
        let mut equity = vec![0.0; steps];
        let mut trades: Vec<Trade> = Vec::new();
        let mut cash = Usdt(INITIAL_CAPITAL);
        let mut position: Option<Position> = None;
        let mut last_close = 0.0;

        let started = Instant::now();
        for step in 0..steps {
            // 1. sell the held position when its own bar carries a sell signal
            if let Some(open) = position
                && signals.kind(step, open.coin) == SignalKind::Sell
            {
                let price = Price(closes[open.coin][step]);
                let proceeds = portfolio::sell_proceeds(open.quantity, price);
                cash = cash + proceeds;
                trades.push(Trade {
                    coin: open.coin,
                    entry_step: open.entry_step,
                    exit_step: step,
                    entry_cost: open.entry_cost,
                    proceeds,
                    net_return: proceeds.get() / open.entry_cost.get() - 1.0,
                });
                position = None;
            }

            // 2. buy the deepest oversold coin while the account holds nothing
            if position.is_none() {
                let mut best: Option<(usize, f64)> = None;
                for coin in 0..coins {
                    if signals.kind(step, coin) == SignalKind::Buy {
                        let strength = signals.strength(step, coin).get();
                        if best.is_none_or(|(_, best_strength)| strength > best_strength) {
                            best = Some((coin, strength));
                        }
                    }
                }
                if let Some((coin, _)) = best {
                    let price = Price(closes[coin][step]);
                    position = Some(Position {
                        coin,
                        quantity: portfolio::buy_quantity(cash, price),
                        entry_step: step,
                        entry_cost: cash,
                    });
                    cash = Usdt(0.0);
                }
            }

            // 3. mark the open position to the last close its coin reported
            if let Some(open) = position {
                let close = closes[open.coin][step];
                if !close.is_nan() {
                    last_close = close;
                }
            }

            // 4. record the account value of the step
            equity[step] = match position {
                Some(open) => cash.get() + open.quantity.get() * last_close,
                None => cash.get(),
            };
        }
        let elapsed = started.elapsed();

        Simulation {
            equity,
            trades,
            elapsed,
        }
    }
}
