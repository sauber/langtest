//! Formatting helpers for the metric lines.

/// Formats an amount of USDT with a thousands separator, for example `19,295`.
pub fn money(value: f64) -> String {
    let rounded = value.round() as i64;
    let sign = if rounded < 0 { "-" } else { "" };
    let digits = rounded.unsigned_abs().to_string();
    let mut out = String::with_capacity(digits.len() + digits.len() / 3 + 1);
    out.push_str(sign);
    for (index, character) in digits.chars().enumerate() {
        if index > 0 && (digits.len() - index).is_multiple_of(3) {
            out.push(',');
        }
        out.push(character);
    }
    out
}

/// Formats a value in a compact way for the axis of the chart, for example `273.8k`.
pub fn compact(value: f64) -> String {
    let magnitude = value.abs();
    if magnitude >= 1_000_000.0 {
        format!("{:.1}M", value / 1_000_000.0)
    } else if magnitude >= 1_000.0 {
        format!("{:.1}k", value / 1_000.0)
    } else if magnitude >= 100.0 {
        format!("{:.0}", value)
    } else {
        format!("{:.1}", value)
    }
}

/// Formats a ratio that may be infinite.
pub fn ratio(value: f64) -> String {
    if value.is_infinite() {
        "inf".to_string()
    } else {
        format!("{value:.4}")
    }
}

/// Formats a share of the capital, for example `+0.7751%`.
pub fn percent(value: f64) -> String {
    format!("{:+.4}%", value * 100.0)
}
