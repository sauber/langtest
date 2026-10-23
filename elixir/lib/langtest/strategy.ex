# Behaviour contract for swappable trading strategies.
defmodule Langtest.Strategy do
  # Derives a trading signal from the current RSI value.
  @callback signal(rsi :: float | nil) :: :buy | :sell | :pass

  # Returns the buy strength used to rank simultaneous buy signals.
  @callback strength(rsi :: float | nil) :: float | :undefined
end
