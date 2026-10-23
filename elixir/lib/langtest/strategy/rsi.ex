# RSI threshold strategy: buy at 30 or below, sell at 70 or above.
defmodule Langtest.Strategy.RSI do
  @behaviour Langtest.Strategy

  # RSI at or below this level is an oversold buy.
  @buy_threshold 30.0

  # RSI at or above this level is an overbought sell.
  @sell_threshold 70.0

  # Maps the current RSI to a discrete trading signal.
  @impl true
  def signal(nil), do: :pass
  def signal(rsi) when rsi <= @buy_threshold, do: :buy
  def signal(rsi) when rsi >= @sell_threshold, do: :sell
  def signal(_rsi), do: :pass

  # Uses distance below 30 as the buy strength for ranking candidates.
  @impl true
  def strength(nil), do: :undefined
  def strength(rsi), do: @buy_threshold - rsi
end
