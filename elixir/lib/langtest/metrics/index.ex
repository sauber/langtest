defmodule Langtest.Metrics.Index do
  @moduledoc "Builds the equal-weight buy-and-hold index of all coins over the simulation window."

  @default_initial_capital 10_000

  # Builds the equal-weight buy-and-hold index of all coins.
  def build(market, initial_capital \\ @default_initial_capital) do
    steps = length(market.timeline)
    coins = length(market.coins)

    if coins == 0 do
      List.duplicate(0.0, steps)
    else
      allocation = initial_capital / coins
      entries = entries(market, allocation)
      build_index(entries, 0, steps, [])
    end
  end

  # Builds the unit holdings of every coin that reports at least one bar.
  defp entries(market, allocation) do
    market.coins
    |> Enum.map(fn coin ->
      if tuple_size(coin.grid.bar_steps) == 0 do
        nil
      else
        {elem(coin.grid.bar_steps, 0), allocation / hd(coin.closes), coin.grid.last_close}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Accumulates the value of every coin holding at each step of the timeline.
  defp build_index(entries, step, steps, acc) do
    if step >= steps do
      Enum.reverse(acc)
    else
      total =
        Enum.reduce(entries, 0.0, fn {first_step, units, last_close}, total ->
          if step >= first_step do
            total + units * elem(last_close, step)
          else
            total
          end
        end)

      build_index(entries, step + 1, steps, [total | acc])
    end
  end
end
