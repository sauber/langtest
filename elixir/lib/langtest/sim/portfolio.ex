defmodule Langtest.Sim.Portfolio do
  @moduledoc "Tracks the cash, the single open position and the log of closed trades."

  alias Langtest.Domain.{Position, Trade}

  # The state of one portfolio.
  defstruct [:cash, :position, :trades, :fee_rate]

  # Creates a portfolio that starts with the given cash.
  def new(initial_cash, fee_rate) do
    %__MODULE__{cash: initial_cash, position: nil, trades: [], fee_rate: fee_rate}
  end

  # Buys the given coin with all available cash, paying the entry fee.
  def buy(%__MODULE__{} = portfolio, symbol, coin_index, price, step) do
    quantity = portfolio.cash / (price * (1 + portfolio.fee_rate))

    position = %Position{
      symbol: symbol,
      coin_index: coin_index,
      quantity: quantity,
      cost_basis: portfolio.cash,
      entry_step: step
    }

    %{portfolio | cash: 0.0, position: position}
  end

  # Sells nothing when no position is open.
  def sell(%__MODULE__{position: nil} = portfolio, _price, _step), do: {portfolio, nil}

  # Sells the open position at the given price, paying the exit fee.
  def sell(%__MODULE__{} = portfolio, price, step) do
    position = portfolio.position
    proceeds = position.quantity * price * (1 - portfolio.fee_rate)

    trade = %Trade{
      symbol: position.symbol,
      entry_step: position.entry_step,
      exit_step: step,
      quantity: position.quantity,
      cost_basis: position.cost_basis,
      proceeds: proceeds,
      net_return: proceeds / position.cost_basis - 1
    }

    portfolio = %{
      portfolio
      | cash: portfolio.cash + proceeds,
        position: nil,
        trades: [trade | portfolio.trades]
    }

    {portfolio, trade}
  end

  # Values the account at the last known price of the held coin.
  def mark_value(%__MODULE__{position: nil} = portfolio, _last_close), do: portfolio.cash

  # Values the account at the last known price of the held coin.
  def mark_value(%__MODULE__{} = portfolio, last_close) do
    portfolio.cash + portfolio.position.quantity * last_close
  end
end
