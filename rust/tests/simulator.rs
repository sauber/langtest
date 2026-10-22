//! The simulator: the execution rules of the evaluation.

// The shared helpers of the tests.
mod common;

use common::{FixedStrategy, market, signals};
use langtest::domain::SignalKind;
use langtest::sim::{Simulation, Simulator};

/// Runs a fixed strategy over a small market.
fn run(
    coins: &[(&str, &[Option<f64>])],
    entries: &[(usize, usize, SignalKind, f64)],
) -> Simulation {
    let market = market(coins);
    let grid = signals(coins.len(), market.timestamps.len(), entries);
    Simulator::new(&market, &FixedStrategy::new(grid)).run()
}

/// The buy and the sell each take a fee of one tenth of a percent.
#[test]
fn the_fees_are_taken_on_the_buy_and_on_the_sell() {
    let simulation = run(
        &[("AAA-USDT", &[Some(100.0), Some(110.0)])],
        &[(0, 0, SignalKind::Buy, 1.0), (0, 1, SignalKind::Sell, 0.0)],
    );
    assert_eq!(simulation.trades.len(), 1);
    let trade = simulation.trades[0];
    assert!((trade.proceeds.get() - 10_978.021978021978).abs() < 1e-9);
    assert!((trade.net_return - 0.09780219780219768).abs() < 1e-12);
    assert!((trade.entry_cost.get() - 10_000.0).abs() < 1e-12);
    assert!((simulation.equity[0] - 9_990.00999000999).abs() < 1e-9);
    assert!((simulation.equity[1] - 10_978.021978021978).abs() < 1e-9);
}

/// The account holds at most one coin, so a second buy signal changes nothing.
#[test]
fn only_one_coin_is_held_at_a_time() {
    let simulation = run(
        &[
            ("AAA-USDT", &[Some(100.0), Some(100.0)]),
            ("BBB-USDT", &[Some(50.0), Some(55.0)]),
        ],
        &[
            (0, 0, SignalKind::Buy, 1.0),
            (1, 0, SignalKind::Buy, 5.0),
            (1, 1, SignalKind::Buy, 5.0),
        ],
    );
    assert_eq!(simulation.trades.len(), 0);
    assert!((simulation.equity[1] - 10_989.010989010989).abs() < 1e-9);
}

/// The deepest oversold coin is bought.
#[test]
fn the_strongest_buy_signal_wins() {
    let simulation = run(
        &[
            ("AAA-USDT", &[Some(100.0), Some(100.0)]),
            ("BBB-USDT", &[Some(50.0), Some(55.0)]),
        ],
        &[(0, 0, SignalKind::Buy, 1.0), (1, 0, SignalKind::Buy, 5.0)],
    );
    assert!((simulation.equity[1] - 10_989.010989010989).abs() < 1e-9);
}

/// Coins of the same strength are broken by the alphabetical order of their symbol.
#[test]
fn an_equal_strength_buys_the_alphabetically_first_coin() {
    let simulation = run(
        &[
            ("AAA-USDT", &[Some(100.0), Some(100.0)]),
            ("BBB-USDT", &[Some(50.0), Some(55.0)]),
        ],
        &[(0, 0, SignalKind::Buy, 5.0), (1, 0, SignalKind::Buy, 5.0)],
    );
    assert!((simulation.equity[1] - 9_990.00999000999).abs() < 1e-9);
}

/// A position is carried across a data gap and is valued at the last known close.
#[test]
fn a_position_is_carried_across_a_data_gap() {
    let simulation = run(
        &[("AAA-USDT", &[Some(100.0), None, Some(120.0)])],
        &[(0, 0, SignalKind::Buy, 1.0), (0, 2, SignalKind::Sell, 0.0)],
    );
    assert!((simulation.equity[0] - 9_990.00999000999).abs() < 1e-9);
    assert!((simulation.equity[1] - 9_990.00999000999).abs() < 1e-9);
    assert!((simulation.equity[2] - 11_976.023976023977).abs() < 1e-9);
    assert_eq!(simulation.trades[0].holding_steps(), 2);
}

/// A coin can be bought in the same step another coin is sold.
#[test]
fn a_coin_can_be_bought_in_the_same_step_it_is_sold() {
    let simulation = run(
        &[
            ("AAA-USDT", &[Some(100.0), Some(100.0)]),
            ("BBB-USDT", &[Some(50.0), Some(50.0)]),
        ],
        &[
            (0, 0, SignalKind::Buy, 1.0),
            (0, 1, SignalKind::Sell, 0.0),
            (1, 1, SignalKind::Buy, 1.0),
        ],
    );
    assert_eq!(simulation.trades.len(), 1);
    assert!((simulation.trades[0].proceeds.get() - 9_980.01998001998).abs() < 1e-9);
    assert!((simulation.equity[1] - 9_970.049930089892).abs() < 1e-9);
}

/// Only the coin of the position is watched for a sell signal.
#[test]
fn a_sell_signal_of_another_coin_does_not_close_the_position() {
    let simulation = run(
        &[
            ("AAA-USDT", &[Some(100.0), Some(100.0)]),
            ("BBB-USDT", &[Some(50.0), Some(50.0)]),
        ],
        &[(0, 0, SignalKind::Buy, 1.0), (1, 1, SignalKind::Sell, 0.0)],
    );
    assert_eq!(simulation.trades.len(), 0);
    assert!((simulation.equity[1] - 9_990.00999000999).abs() < 1e-9);
}

/// Without a buy signal the account keeps its cash.
#[test]
fn an_idle_account_keeps_its_cash() {
    let simulation = run(&[("AAA-USDT", &[Some(100.0), Some(110.0)])], &[]);
    assert_eq!(simulation.trades.len(), 0);
    assert_eq!(simulation.equity[0], 10_000.0);
    assert_eq!(simulation.equity[1], 10_000.0);
}

/// The whole cash is spent on the buy, the coin may be fractional.
#[test]
fn the_buy_spends_the_whole_cash() {
    let simulation = run(
        &[("AAA-USDT", &[Some(333.0), Some(333.0)])],
        &[(0, 0, SignalKind::Buy, 1.0)],
    );
    assert!((simulation.equity[0] - 9_990.00999000999).abs() < 1e-9);
}
