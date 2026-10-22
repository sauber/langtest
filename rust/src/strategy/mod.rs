//! The strategy: a swappable component that turns prices into signals.

pub mod rsi;
pub mod signals;

pub use rsi::{PERIOD, wilder_rsi};
pub use signals::{RsiStrategy, SignalGrid, Strategy};
