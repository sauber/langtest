import type { Position, Trade } from "../domain/types.ts";

// Tracks cash, the single open position and the log of closed trades.
export class Portfolio {
  private cash: number;
  private position: Position | null = null;
  private readonly closed: Trade[] = [];

  constructor(
    initialCash = 10_000,
    private readonly feeRate = 0.001,
  ) {
    this.cash = initialCash;
  }

  // The cash still available for the next purchase.
  get cashBalance(): number {
    return this.cash;
  }

  // The position currently held, if any.
  get openPosition(): Position | null {
    return this.position;
  }

  // Every trade that has been opened and closed so far.
  get trades(): readonly Trade[] {
    return this.closed;
  }

  // Buys the given coin with all available cash, paying the entry fee.
  buy(symbol: string, coinIndex: number, price: number, step: number): void {
    const quantity = this.cash / (price * (1 + this.feeRate));
    this.position = { symbol, coinIndex, quantity, costBasis: this.cash, entryStep: step };
    this.cash = 0;
  }

  // Sells the open position at the given price, paying the exit fee.
  sell(price: number, step: number): Trade | null {
    const position = this.position;
    if (position === null) return null;
    const proceeds = position.quantity * price * (1 - this.feeRate);
    const trade: Trade = {
      symbol: position.symbol,
      entryStep: position.entryStep,
      exitStep: step,
      quantity: position.quantity,
      costBasis: position.costBasis,
      proceeds,
      netReturn: proceeds / position.costBasis - 1,
    };
    this.cash += proceeds;
    this.position = null;
    this.closed.push(trade);
    return trade;
  }

  // Values the account at the last known price of the held coin.
  markValue(lastClose: number): number {
    if (this.position === null) return this.cash;
    return this.cash + this.position.quantity * lastClose;
  }
}
