# Immutable, precomputed simulation input with O(1) step lookups.
defmodule Langtest.Dataset do
  # Step-indexed bar data, signals, trade candidates, and the market index.
  defstruct coins: [],
            steps: 0,
            closes: {},
            signals: {},
            best_buys: {},
            index: {},
            first_timestamp: 0,
            last_timestamp: 0

  # Returns the number of coins represented in every step tuple.
  def coin_count(%__MODULE__{closes: closes}), do: tuple_size(elem(closes, 0))

  # Looks up the close for a coin at a step, or :undefined when no bar exists.
  def close(%__MODULE__{closes: closes}, step, coin), do: elem(elem(closes, step), coin)

  # Looks up the numeric signal for a coin at a step (1 buy, -1 sell, 0 none).
  def signal(%__MODULE__{signals: signals}, step, coin), do: elem(elem(signals, step), coin)

  # Returns the strongest buy candidate at a step, or nil when there is none.
  def best_buy(%__MODULE__{best_buys: best_buys}, step), do: elem(best_buys, step)

  # Returns the final value of the precomputed equal-weight market index.
  def index_final(%__MODULE__{index: index}) do
    elem(index, tuple_size(index) - 1)
  end
end
