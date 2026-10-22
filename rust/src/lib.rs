//! The trading-strategy evaluation: load the market, run the simulation, report the metrics.
//!
//! The crate is split into layers that only depend downwards:
//!
//! - [`domain`] holds the typed values every layer speaks in.
//! - [`data`] reads the coin CSV files and the meta file into a [`data::Market`].
//! - [`strategy`] turns prices into signals behind the swappable [`strategy::Strategy`] trait.
//! - [`sim`] runs the hourly stepping loop over the shared timeline.
//! - [`metrics`] turns a finished simulation into the five performance metrics.
//! - [`report`] renders the metrics and the chart for an 80x25 terminal.

pub mod data;
pub mod domain;
pub mod metrics;
pub mod report;
pub mod sim;
pub mod strategy;

pub use data::Market;
pub use domain::{BuyStrength, Price, Quantity, SignalKind, Timestamp, Usdt};
pub use metrics::Metrics;
pub use sim::{Simulation, Simulator};
pub use strategy::{RsiStrategy, SignalGrid, Strategy};
