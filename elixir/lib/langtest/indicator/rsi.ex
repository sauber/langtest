defmodule Langtest.Indicator.Rsi do
  @moduledoc "Wilder's Relative Strength Index computed on close prices."

  @default_period 14

  # Computes Wilder's RSI over a close price series, marking bars without a value as nil.
  def wilder_rsi(closes, period \\ @default_period)

  def wilder_rsi(closes, period) when is_list(closes) and is_integer(period) and period > 0 do
    bars = length(closes)

    if bars <= period do
      List.duplicate(nil, bars)
    else
      {gain, loss} = seed(closes, period)
      gain = gain / period
      loss = loss / period
      rest = Enum.drop(closes, period)
      {smoothed, _gain, _loss} = smooth(rest, period, gain, loss, [])
      List.duplicate(nil, period) ++ [rsi_from(gain, loss) | smoothed]
    end
  end

  # Converts an average gain and loss pair into the RSI value it implies.
  defp rsi_from(_gain, loss) when loss == 0.0, do: 100.0
  defp rsi_from(gain, loss), do: 100.0 - 100.0 / (1 + gain / loss)

  # Accumulates the gains and losses of the first period of price changes.
  defp seed(closes, period), do: seed(closes, period, 0.0, 0.0)

  # Accumulates one more price change into the seed averages.
  defp seed(_closes, 0, gain, loss), do: {gain, loss}

  # Accumulates one more price change into the seed averages.
  defp seed([previous, current | rest], remaining, gain, loss) do
    change = current - previous

    if change > 0.0 do
      seed([current | rest], remaining - 1, gain + change, loss)
    else
      seed([current | rest], remaining - 1, gain, loss - change)
    end
  end

  # Stops the smoothing once no further price change is left.
  defp smooth([_last], _period, gain, loss, acc), do: {Enum.reverse(acc), gain, loss}

  # Smooths one more price change with Wilder's formula.
  defp smooth([previous, current | rest], period, gain, loss, acc) do
    change = current - previous
    gain = (gain * (period - 1) + if(change > 0.0, do: change, else: 0.0)) / period
    loss = (loss * (period - 1) + if(change < 0.0, do: -change, else: 0.0)) / period
    smooth([current | rest], period, gain, loss, [rsi_from(gain, loss) | acc])
  end
end
