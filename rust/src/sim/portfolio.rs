//! The account state: the fee model, the open position and the closed trades.

use crate::domain::{Price, Quantity, Usdt};

/// The fee applied to every buy and every sell.
pub const FEE: f64 = 0.001;

/// The cash the account starts with.
pub const INITIAL_CAPITAL: f64 = 10_000.0;

/// The open position of the account: at most one coin at a time.
#[derive(Clone, Copy, Debug)]
pub struct Position {
    /// The index of the held coin.
    pub coin: usize,
    /// The quantity of the coin that is held.
    pub quantity: Quantity,
    /// The step the position was opened at.
    pub entry_step: usize,
    /// The cash the position was bought with, the buy fee included.
    pub entry_cost: Usdt,
}

/// One closed trade.
#[derive(Clone, Copy, Debug)]
pub struct Trade {
    /// The index of the traded coin.
    pub coin: usize,
    /// The step the position was opened at.
    pub entry_step: usize,
    /// The step the position was closed at.
    pub exit_step: usize,
    /// The cash the position was bought with, the buy fee included.
    pub entry_cost: Usdt,
    /// The cash the position was sold for, the sell fee included.
    pub proceeds: Usdt,
    /// The net return of the trade, as a fraction of the capital that was deployed.
    pub net_return: f64,
}

// The helpers of a closed trade.
impl Trade {
    /// The number of steps the position was held.
    pub fn holding_steps(&self) -> usize {
        self.exit_step - self.entry_step
    }
}

/// The quantity a cash amount buys at a price, the buy fee included.
pub fn buy_quantity(cash: Usdt, price: Price) -> Quantity {
    Quantity(cash.get() / (price.get() * (1.0 + FEE)))
}

/// The cash a position is sold for, the sell fee included.
pub fn sell_proceeds(quantity: Quantity, price: Price) -> Usdt {
    Usdt(quantity.get() * price.get() * (1.0 - FEE))
}
