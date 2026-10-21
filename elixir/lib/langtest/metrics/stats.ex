defmodule Langtest.Metrics.Stats do
  @moduledoc "Computes the performance statistics of a simulation run."

  @hours_per_year 8760

  # Computes the annualised Sharpe ratio of an account value curve.
  def sharpe_ratio(equity) do
    count = length(equity) - 1

    if count < 2 do
      nil
    else
      {sum, returns} = returns(equity, 0.0, [])
      mean = sum / count
      deviation = :math.sqrt(squares(returns, mean, 0.0) / (count - 1))

      if deviation == 0.0 do
        nil
      else
        mean / deviation * :math.sqrt(@hours_per_year)
      end
    end
  end

  # Collects the hourly returns of an account value curve together with their sum.
  defp returns([first, second | rest], sum, acc) do
    value = second / first - 1
    returns([second | rest], sum + value, [value | acc])
  end

  # Collects the hourly returns of an account value curve together with their sum.
  defp returns(_curve, sum, acc), do: {sum, Enum.reverse(acc)}

  # Sums the squared deviations of the hourly returns from their mean.
  defp squares(returns, mean, acc) do
    Enum.reduce(returns, acc, fn value, acc -> acc + (value - mean) * (value - mean) end)
  end

  # Counts the winning and losing closed trades and derives their ratio.
  def win_loss_ratio(trades) do
    {wins, losses} =
      Enum.reduce(trades, {0, 0}, fn trade, {wins, losses} ->
        cond do
          trade.net_return > 0 -> {wins + 1, losses}
          trade.net_return < 0 -> {wins, losses + 1}
          true -> {wins, losses}
        end
      end)

    ratio = if losses == 0, do: :infinity, else: wins / losses
    %{wins: wins, losses: losses, ratio: ratio}
  end

  # Averages the net return over every closed trade.
  def average_gain([]), do: 0.0

  # Averages the net return over every closed trade.
  def average_gain(trades) do
    Enum.reduce(trades, 0.0, fn trade, sum -> sum + trade.net_return end) / length(trades)
  end

  # Averages the number of simulation steps a closed trade was held.
  def average_holding_steps([]), do: 0.0

  # Averages the number of simulation steps a closed trade was held.
  def average_holding_steps(trades) do
    Enum.reduce(trades, 0, fn trade, sum -> sum + (trade.exit_step - trade.entry_step) end) /
      length(trades)
  end
end
