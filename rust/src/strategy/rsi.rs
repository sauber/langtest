//! Wilder's Relative Strength Index.

/// The number of periods the RSI is computed over.
pub const PERIOD: usize = 14;

/// Computes the RSI of a close price series with Wilder's smoothing.
///
/// The series is the coin's own bars aligned to the shared timeline: a missing bar is `NaN` and
/// is skipped, so a data gap never counts as a flat bar. The first value needs `period` changes
/// and therefore `period + 1` closes; every earlier step has no value.
pub fn wilder_rsi(closes: &[f64], period: usize) -> Vec<f64> {
    let mut values = vec![f64::NAN; closes.len()];
    let mut average_gain = 0.0;
    let mut average_loss = 0.0;
    let mut changes = 0usize;
    let mut previous: Option<f64> = None;

    for (index, &close) in closes.iter().enumerate() {
        if close.is_nan() {
            continue;
        }
        let Some(previous_close) = previous else {
            previous = Some(close);
            continue;
        };
        previous = Some(close);

        let change = close - previous_close;
        let gain = change.max(0.0);
        let loss = (-change).max(0.0);
        if changes < period {
            average_gain += gain;
            average_loss += loss;
            changes += 1;
            if changes == period {
                average_gain /= period as f64;
                average_loss /= period as f64;
                values[index] = rsi_of(average_gain, average_loss);
            }
        } else {
            average_gain = (average_gain * (period as f64 - 1.0) + gain) / period as f64;
            average_loss = (average_loss * (period as f64 - 1.0) + loss) / period as f64;
            values[index] = rsi_of(average_gain, average_loss);
        }
    }
    values
}

/// Turns the smoothed average gain and loss into an RSI value.
fn rsi_of(average_gain: f64, average_loss: f64) -> f64 {
    if average_loss == 0.0 {
        return 100.0;
    }
    if average_gain == 0.0 {
        return 0.0;
    }
    let relative_strength = average_gain / average_loss;
    100.0 - 100.0 / (1.0 + relative_strength)
}
