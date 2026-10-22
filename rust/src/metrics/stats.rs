//! The performance metrics of a finished simulation.

use crate::domain::BARS_PER_YEAR;
use crate::sim::{Simulation, Trade};

/// Every metric the evaluation reports.
#[derive(Clone, Debug)]
pub struct Metrics {
    /// The account value at the last step.
    pub equity_final: f64,
    /// The value of the market index at the last step.
    pub index_final: f64,
    /// The account value divided by the market index.
    pub equity_ratio: f64,
    /// The annualised Sharpe ratio of the hourly returns.
    pub sharpe: Option<f64>,
    /// The ratio of winning trades to losing trades.
    pub win_loss: Option<f64>,
    /// The mean net return of every closed trade.
    pub average_gain: Option<f64>,
    /// The mean number of steps a closed trade was held.
    pub average_holding: Option<f64>,
    /// The number of closed trades.
    pub trades: usize,
    /// The number of closed trades that made money.
    pub wins: usize,
    /// The number of closed trades that lost money.
    pub losses: usize,
}

/// Computes every metric of a simulation against the market index.
pub fn compute(simulation: &Simulation, index: &[f64]) -> Metrics {
    let equity_final = simulation.equity.last().copied().unwrap_or(0.0);
    let index_final = index.last().copied().unwrap_or(0.0);
    let (wins, losses) = win_loss_counts(&simulation.trades);

    Metrics {
        equity_final,
        index_final,
        equity_ratio: if index_final == 0.0 {
            0.0
        } else {
            equity_final / index_final
        },
        sharpe: sharpe(&simulation.equity),
        win_loss: Some(win_loss_ratio(wins, losses)),
        average_gain: average_gain(&simulation.trades),
        average_holding: average_holding(&simulation.trades),
        trades: simulation.trades.len(),
        wins,
        losses,
    }
}

/// The annualised Sharpe ratio of the hourly returns of the account value.
///
/// `None` when there are fewer than two returns or when the returns have no spread.
pub fn sharpe(equity: &[f64]) -> Option<f64> {
    let returns: Vec<f64> = equity
        .windows(2)
        .map(|pair| {
            if pair[0] == 0.0 {
                0.0
            } else {
                pair[1] / pair[0] - 1.0
            }
        })
        .filter(|value| value.is_finite())
        .collect();
    if returns.len() < 2 {
        return None;
    }
    let count = returns.len() as f64;
    let mean = returns.iter().sum::<f64>() / count;
    let variance = returns
        .iter()
        .map(|value| (value - mean).powi(2))
        .sum::<f64>()
        / (count - 1.0);
    let deviation = variance.sqrt();
    if deviation == 0.0 {
        return None;
    }
    Some(mean / deviation * BARS_PER_YEAR.sqrt())
}

/// The number of winning and losing trades; trades with no return count as neither.
pub fn win_loss_counts(trades: &[Trade]) -> (usize, usize) {
    let mut wins = 0;
    let mut losses = 0;
    for trade in trades {
        if trade.net_return > 0.0 {
            wins += 1;
        } else if trade.net_return < 0.0 {
            losses += 1;
        }
    }
    (wins, losses)
}

/// The ratio of winning trades to losing trades; `None` when no trade lost money.
pub fn win_loss_ratio(wins: usize, losses: usize) -> f64 {
    if losses == 0 {
        f64::INFINITY
    } else {
        wins as f64 / losses as f64
    }
}

/// The mean net return of every closed trade.
pub fn average_gain(trades: &[Trade]) -> Option<f64> {
    if trades.is_empty() {
        return None;
    }
    Some(trades.iter().map(|trade| trade.net_return).sum::<f64>() / trades.len() as f64)
}

/// The mean number of steps a closed trade was held.
pub fn average_holding(trades: &[Trade]) -> Option<f64> {
    if trades.is_empty() {
        return None;
    }
    Some(
        trades
            .iter()
            .map(|trade| trade.holding_steps() as f64)
            .sum::<f64>()
            / trades.len() as f64,
    )
}
