//! The RSI: Wilder's smoothing checked against a fixed price fixture.

use langtest::strategy::rsi::{PERIOD, wilder_rsi};

/// The classic Wilder fixture: twenty closes of a falling then rising market.
const FIXTURE: [f64; 20] = [
    44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08, 45.89, 46.03, 45.61,
    46.28, 46.28, 46.00, 46.03, 46.41, 46.22, 45.64,
];

/// The values the fixture must produce; the first fourteen closes have no value yet.
const EXPECTED: [Option<f64>; 20] = [
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    Some(70.46413502109705),
    Some(66.24961855355505),
    Some(66.48094183471265),
    Some(69.34685316290866),
    Some(66.29471265892624),
    Some(57.91502067008556),
];

/// The RSI of the fixture matches the reference values of every bar.
#[test]
fn the_fixture_matches_the_reference_values() {
    let values = wilder_rsi(&FIXTURE, PERIOD);
    for (index, expected) in EXPECTED.iter().enumerate() {
        match expected {
            None => assert!(values[index].is_nan(), "bar {index} should have no value"),
            Some(expected) => assert!(
                (values[index] - expected).abs() < 1e-9,
                "bar {index}: {} != {expected}",
                values[index]
            ),
        }
    }
}

/// The first RSI value needs fourteen changes and therefore fifteen closes.
#[test]
fn the_first_value_needs_fifteen_closes() {
    let values = wilder_rsi(&FIXTURE, PERIOD);
    assert!(values[13].is_nan());
    assert!(!values[14].is_nan());
}

/// A missing bar is skipped and never counted as a flat bar.
#[test]
fn a_gap_does_not_change_the_values() {
    let mut gapped = FIXTURE.to_vec();
    gapped.insert(5, f64::NAN);
    let values = wilder_rsi(&gapped, PERIOD);
    let plain = wilder_rsi(&FIXTURE, PERIOD);
    for (index, expected) in plain.iter().enumerate() {
        let actual = values[index + 1];
        if expected.is_nan() {
            assert!(
                actual.is_nan(),
                "bar {index}: {actual} should have no value"
            );
        } else {
            assert!(
                (actual - expected).abs() < 1e-12,
                "bar {index}: {actual} != {expected}"
            );
        }
    }
}

/// A market that only rises has no losses and therefore an RSI of 100.
#[test]
fn a_rising_market_has_an_rsi_of_100() {
    let closes: Vec<f64> = (0..20).map(|index| 100.0 + index as f64).collect();
    let values = wilder_rsi(&closes, PERIOD);
    assert_eq!(values[19], 100.0);
}

/// A market that only falls has no gains and therefore an RSI of 0.
#[test]
fn a_falling_market_has_an_rsi_of_0() {
    let closes: Vec<f64> = (0..20).map(|index| 100.0 - index as f64).collect();
    let values = wilder_rsi(&closes, PERIOD);
    assert_eq!(values[19], 0.0);
}

/// A flat market has no losses and therefore an RSI of 100.
#[test]
fn a_flat_market_has_an_rsi_of_100() {
    let closes = vec![50.0; 20];
    let values = wilder_rsi(&closes, PERIOD);
    assert_eq!(values[19], 100.0);
}

/// A period of one gives the RSI of every single change.
#[test]
fn a_period_of_one_follows_every_change() {
    let closes = [10.0, 11.0, 10.0];
    let values = wilder_rsi(&closes, 1);
    assert!((values[1] - 100.0).abs() < 1e-12);
    assert!((values[2] - 0.0).abs() < 1e-12);
}
