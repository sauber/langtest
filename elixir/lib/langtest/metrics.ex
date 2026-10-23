# Computes the five required performance metrics from a simulation result.
defmodule Langtest.Metrics do
  alias Langtest.{Dataset, Simulator.Result}

  # Hourly steps in a year used to annualize the Sharpe ratio.
  @hours_per_year 8760.0

  # Metric values plus supporting trade counts.
  defstruct final_equity: 0.0,
            index_final: 0.0,
            ratio: nil,
            sharpe: nil,
            win_loss: nil,
            avg_gain: nil,
            avg_holding: nil,
            wins: 0,
            losses: 0,
            trades: 0

  # Builds the complete metric record for a result and its dataset.
  def compute(%Result{} = result, %Dataset{} = dataset) do
    returns = Enum.map(result.trades, fn trade -> trade.proceeds / trade.cost - 1.0 end)
    wins = Enum.count(returns, &(&1 > 0.0))
    losses = Enum.count(returns, &(&1 < 0.0))

    %__MODULE__{
      final_equity: result.final_equity,
      index_final: Dataset.index_final(dataset),
      ratio: ratio(result.final_equity, Dataset.index_final(dataset)),
      sharpe: sharpe(result.equity),
      win_loss: win_loss(wins, losses),
      avg_gain: mean(returns),
      avg_holding: holding_time(result.trades),
      wins: wins,
      losses: losses,
      trades: length(result.trades)
    }
  end

  # Computes the annualized Sharpe ratio of hourly equity returns.
  def sharpe([_single]), do: nil

  # Uses Welford's algorithm for a stable mean and sample variance.
  def sharpe([first | rest]) do
    {count, mean, squared_deviations, _previous} =
      Enum.reduce(rest, {0, 0.0, 0.0, first}, fn value, {count, mean, m2, previous} ->
        hourly_return = value / previous - 1.0
        count = count + 1
        delta = hourly_return - mean
        mean = mean + delta / count
        m2 = m2 + delta * (hourly_return - mean)
        {count, mean, m2, value}
      end)

    if count < 2 do
      nil
    else
      variance = squared_deviations / (count - 1)

      if variance <= 0.0 do
        nil
      else
        mean / :math.sqrt(variance) * :math.sqrt(@hours_per_year)
      end
    end
  end

  # Divides final equity by the market index, returning nil for a zero index.
  defp ratio(_final, index_final) when index_final == 0, do: nil
  defp ratio(final, index_final), do: final / index_final

  # Reports infinity whenever no closed trade lost, as required by the spec.
  defp win_loss(_wins, 0), do: :infinity

  # Divides wins by losses when at least one trade lost.
  defp win_loss(wins, losses), do: wins / losses

  # Returns the arithmetic mean, or nil for an empty list.
  defp mean([]), do: nil
  defp mean(values), do: Enum.sum(values) / length(values)

  # Returns the mean holding time in simulation steps across closed trades.
  defp holding_time([]), do: nil

  # Averages the step distance between entry and exit over all trades.
  defp holding_time(trades) do
    total = Enum.reduce(trades, 0, fn trade, acc -> acc + (trade.sell_step - trade.buy_step) end)
    total / length(trades)
  end
end
