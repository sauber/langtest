//! The report: the metric lines and the chart fit the terminal.

// The shared helpers of the tests.
mod common;

use common::market;
use langtest::metrics::stats;
use langtest::report::{build, chart::ChartOptions};
use langtest::sim::Simulator;
use langtest::strategy::RsiStrategy;

/// The number of visible columns of a line, without the colour escapes.
fn visible_width(line: &str) -> usize {
    let mut width = 0;
    let mut characters = line.chars();
    while let Some(character) = characters.next() {
        if character == '\u{1b}' {
            for escape in characters.by_ref() {
                if escape == 'm' {
                    break;
                }
            }
        } else {
            width += 1;
        }
    }
    width
}

/// Builds the report of a small market.
fn report(color: bool) -> Vec<String> {
    let market = market(&[
        (
            "AAA-USDT",
            &[Some(100.0), Some(110.0), Some(90.0), Some(120.0)],
        ),
        (
            "BBB-USDT",
            &[Some(50.0), Some(45.0), Some(60.0), Some(55.0)],
        ),
    ]);
    let simulation = Simulator::new(&market, &RsiStrategy::default()).run();
    let metrics = stats::compute(&simulation, &market.index);
    let options = ChartOptions {
        color,
        ..ChartOptions::default()
    };
    build(
        &market,
        &metrics,
        &simulation.equity,
        simulation.elapsed,
        14,
        &options,
    )
}

/// The whole report fits into eighty columns and twenty-five lines.
#[test]
fn the_report_fits_the_terminal() {
    for color in [true, false] {
        let lines = report(color);
        assert!(lines.len() <= 25, "the report has {} lines", lines.len());
        for line in &lines {
            assert!(visible_width(line) <= 80, "the line is too wide: {line}");
        }
    }
}

/// The chart draws both series and uses the soft line drawing characters.
#[test]
fn the_chart_draws_both_series() {
    let lines = report(false);
    let chart = lines.join("\n");
    for character in ['╭', '╮', '╰', '╯', '─', '│', '═'] {
        assert!(chart.contains(character), "the chart misses `{character}`");
    }
}

/// The chart paints the two series in different colours.
#[test]
fn the_chart_paints_the_two_series_in_colour() {
    let lines = report(true);
    assert!(
        lines.iter().any(|line| line.contains("\u{1b}[96m")),
        "no strategy colour"
    );
    assert!(
        lines.iter().any(|line| line.contains("\u{1b}[93m")),
        "no index colour"
    );
}

/// The report names every metric and the time of the simulation.
#[test]
fn the_report_names_every_metric() {
    let lines = report(false);
    let text = lines.join("\n");
    for label in [
        "equity / index",
        "sharpe",
        "win / loss",
        "avg gain / trade",
        "avg holding time",
        "sim time:",
    ] {
        assert!(text.contains(label), "the report misses `{label}`");
    }
}
