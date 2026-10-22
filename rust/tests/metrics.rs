//! The metrics: the Sharpe ratio, the win/loss ratio, the gain and the holding time.

use langtest::domain::Usdt;
use langtest::metrics::stats;
use langtest::sim::Trade;

/// Builds a closed trade with the given net return and holding time.
fn trade(net_return: f64, entry_step: usize, exit_step: usize) -> Trade {
    Trade {
        coin: 0,
        entry_step,
        exit_step,
        entry_cost: Usdt(10_000.0),
        proceeds: Usdt(10_000.0 * (1.0 + net_return)),
        net_return,
    }
}

/// The Sharpe ratio of a hand-computed equity curve.
#[test]
fn the_sharpe_ratio_matches_the_hand_computed_value() {
    let equity = [100.0, 110.0, 121.0, 108.9];
    let sharpe = stats::sharpe(&equity).expect("the curve has a spread");
    assert!((sharpe - 27.01851217221264).abs() < 1e-9);
}

/// An equity curve without a spread has no Sharpe ratio.
#[test]
fn a_flat_equity_curve_has_no_sharpe_ratio() {
    let equity = [100.0, 110.0, 121.0];
    assert!(stats::sharpe(&equity).is_none());
}

/// A curve with a single return has no Sharpe ratio either.
#[test]
fn a_single_return_has_no_sharpe_ratio() {
    assert!(stats::sharpe(&[100.0]).is_none());
    assert!(stats::sharpe(&[100.0, 110.0]).is_none());
}

/// Trades without a return are neither wins nor losses.
#[test]
fn a_trade_without_a_return_counts_as_neither() {
    let trades = [trade(0.10, 0, 4), trade(-0.05, 5, 9), trade(0.0, 10, 12)];
    assert_eq!(stats::win_loss_counts(&trades), (1, 1));
}

/// A run without a loss has an infinite win/loss ratio.
#[test]
fn a_run_without_a_loss_has_an_infinite_ratio() {
    assert!(stats::win_loss_ratio(3, 0).is_infinite());
    assert_eq!(stats::win_loss_ratio(3, 2), 1.5);
}

/// The average gain is the mean return of every closed trade, winners and losers alike.
#[test]
fn the_average_gain_covers_every_closed_trade() {
    let trades = [trade(0.10, 0, 4), trade(-0.05, 5, 9), trade(0.0, 10, 12)];
    let gain = stats::average_gain(&trades).expect("there are trades");
    assert!((gain - 0.016666666666666666).abs() < 1e-12);
}

/// The average holding time is the mean number of steps between the buy and the sell.
#[test]
fn the_average_holding_time_counts_the_steps() {
    let trades = [trade(0.10, 0, 4), trade(-0.05, 5, 11)];
    let holding = stats::average_holding(&trades).expect("there are trades");
    assert!((holding - 5.0).abs() < 1e-12);
}

/// Without a trade there is no average to report.
#[test]
fn an_empty_run_has_no_averages() {
    let trades: [Trade; 0] = [];
    assert!(stats::average_gain(&trades).is_none());
    assert!(stats::average_holding(&trades).is_none());
}
