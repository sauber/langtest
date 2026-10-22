//! The simulation: the account state and the hourly stepping loop.

pub mod portfolio;
pub mod simulator;

pub use portfolio::{FEE, INITIAL_CAPITAL, Position, Trade};
pub use simulator::{Simulation, Simulator};
