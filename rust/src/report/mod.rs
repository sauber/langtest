//! The terminal report: the header, the metrics and the chart.

pub mod chart;
pub mod format;

use std::time::Duration;

use crate::data::Market;
use crate::metrics::Metrics;
use crate::report::chart::ChartOptions;

/// The width of the label column of the metric lines.
const LABEL_WIDTH: usize = 20;

/// Builds the lines of the report: the header, the metrics and the chart.
pub fn build(
    market: &Market,
    metrics: &Metrics,
    equity: &[f64],
    elapsed: Duration,
    period: usize,
    options: &ChartOptions,
) -> Vec<String> {
    let mut lines = Vec::with_capacity(24);
    lines.push(header(market, period));
    lines.push(metric("equity / index", &equity_index(metrics)));
    lines.push(metric("sharpe (hourly)", &sharpe(metrics)));
    lines.push(metric("win / loss", &win_loss(metrics)));
    lines.push(metric("avg gain / trade", &average_gain(metrics)));
    lines.push(metric("avg holding time", &average_holding(metrics)));
    lines.push(format!("sim time: {:.3} s", elapsed.as_secs_f64()));
    lines.push(String::new());
    lines.extend(chart::render(
        equity,
        &market.index,
        &market.timestamps,
        options,
    ));
    lines
}

/// The header line: what was evaluated and over which period.
fn header(market: &Market, period: usize) -> String {
    let first = market
        .timestamps
        .first()
        .map(|stamp| stamp.date())
        .unwrap_or_default();
    let last = market
        .timestamps
        .last()
        .map(|stamp| stamp.date())
        .unwrap_or_default();
    format!(
        "RSI({period}) · {} coins · {} steps · {first} → {last}",
        market.coins.len(),
        market.timestamps.len(),
    )
}

/// One metric line: a label and its value.
fn metric(label: &str, value: &str) -> String {
    format!("{label:<LABEL_WIDTH$}{value}")
}

/// The account value against the market index.
fn equity_index(metrics: &Metrics) -> String {
    format!(
        "{}x  (equity {} · index {})",
        format::ratio(metrics.equity_ratio),
        format::money(metrics.equity_final),
        format::money(metrics.index_final),
    )
}

/// The annualised Sharpe ratio of the hourly returns.
fn sharpe(metrics: &Metrics) -> String {
    match metrics.sharpe {
        Some(value) => format!("{value:.4}"),
        None => "N/A".to_string(),
    }
}

/// The ratio of winning trades to losing trades.
fn win_loss(metrics: &Metrics) -> String {
    let ratio = metrics.win_loss.unwrap_or(f64::INFINITY);
    format!(
        "{}  ({} W / {} L / {} trades)",
        format::ratio(ratio),
        metrics.wins,
        metrics.losses,
        metrics.trades,
    )
}

/// The mean net return of a closed trade.
fn average_gain(metrics: &Metrics) -> String {
    match metrics.average_gain {
        Some(value) => format::percent(value),
        None => "N/A".to_string(),
    }
}

/// The mean number of steps a closed trade was held.
fn average_holding(metrics: &Metrics) -> String {
    match metrics.average_holding {
        Some(value) => format!("{value:.2} steps"),
        None => "N/A".to_string(),
    }
}
