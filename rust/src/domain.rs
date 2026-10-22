//! The typed values every layer of the evaluation speaks in.

use core::fmt;
use core::ops::{Add, Div, Mul, Sub};

/// The number of seconds in one bar of the shared timeline.
pub const BAR_SECONDS: i64 = 3600;

/// The number of bars in a year, used to annualise the Sharpe ratio.
pub const BARS_PER_YEAR: f64 = 8760.0;

/// The open time of a candle, in Unix seconds.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Timestamp(pub i64);

// The helpers of a timestamp.
impl Timestamp {
    /// The UTC date of the timestamp, formatted as `YYYY-MM-DD`.
    pub fn date(&self) -> String {
        let (year, month, day) = civil_from_days(self.0.div_euclid(86_400));
        format!("{year:04}-{month:02}-{day:02}")
    }
}

// A timestamp prints as its date.
impl fmt::Display for Timestamp {
    /// Writes the timestamp as its UTC date.
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}", self.date())
    }
}

/// Converts a count of days since the Unix epoch into a civil UTC date.
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let shifted = days + 719_468;
    let era = if shifted >= 0 {
        shifted
    } else {
        shifted - 146_096
    } / 146_097;
    let day_of_era = (shifted - era * 146_097) as u64;
    let year_of_era =
        (day_of_era - day_of_era / 1460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let year = year_of_era as i64 + era * 400;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_position = (5 * day_of_year + 2) / 153;
    let day = (day_of_year - (153 * month_position + 2) / 5 + 1) as u32;
    let month = if month_position < 10 {
        month_position + 3
    } else {
        month_position - 9
    } as u32;
    (if month <= 2 { year + 1 } else { year }, month, day)
}

/// A price in USDT.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct Price(pub f64);

// The helpers of a price.
impl Price {
    /// The price as a plain number.
    pub fn get(&self) -> f64 {
        self.0
    }
}

// A quantity of a coin has a value at a price.
impl Mul<Price> for Quantity {
    /// The value of a quantity of a coin at a price.
    type Output = Usdt;

    /// Multiplies the quantity by the price.
    fn mul(self, price: Price) -> Usdt {
        Usdt(self.0 * price.0)
    }
}

// A quantity scales by a plain factor.
impl Mul<f64> for Quantity {
    /// Scales a quantity by a plain factor.
    type Output = Quantity;

    /// Multiplies the quantity by the factor.
    fn mul(self, factor: f64) -> Quantity {
        Quantity(self.0 * factor)
    }
}

/// An amount of USDT.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct Usdt(pub f64);

// The helpers of an amount of USDT.
impl Usdt {
    /// The amount as a plain number.
    pub fn get(&self) -> f64 {
        self.0
    }
}

// Two amounts add up.
impl Add<Usdt> for Usdt {
    /// The sum of two amounts.
    type Output = Usdt;

    /// Adds the amounts.
    fn add(self, other: Usdt) -> Usdt {
        Usdt(self.0 + other.0)
    }
}

// Two amounts differ by their difference.
impl Sub<Usdt> for Usdt {
    /// The difference of two amounts.
    type Output = Usdt;

    /// Subtracts the other amount.
    fn sub(self, other: Usdt) -> Usdt {
        Usdt(self.0 - other.0)
    }
}

// An amount scales by a plain factor.
impl Mul<f64> for Usdt {
    /// Scales an amount by a plain factor.
    type Output = Usdt;

    /// Multiplies the amount by the factor.
    fn mul(self, factor: f64) -> Usdt {
        Usdt(self.0 * factor)
    }
}

// An amount buys a quantity of a coin at a price.
impl Div<Price> for Usdt {
    /// The quantity of a coin an amount buys at a price.
    type Output = Quantity;

    /// Divides the amount by the price.
    fn div(self, price: Price) -> Quantity {
        Quantity(self.0 / price.0)
    }
}

/// A quantity of a coin.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct Quantity(pub f64);

// The helpers of a quantity.
impl Quantity {
    /// The quantity as a plain number.
    pub fn get(&self) -> f64 {
        self.0
    }
}

/// How oversold a coin is: `30 - rsi`, so a larger strength is a deeper oversold reading.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct BuyStrength(pub f64);

// The helpers of a buy strength.
impl BuyStrength {
    /// The strength as a plain number.
    pub fn get(&self) -> f64 {
        self.0
    }
}

/// The action the strategy takes at one bar.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SignalKind {
    /// Do nothing.
    Pass,
    /// Buy the coin.
    Buy,
    /// Sell the whole position in the coin.
    Sell,
}
