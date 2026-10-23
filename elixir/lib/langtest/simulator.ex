# Executes the single-position trading simulation over precomputed steps.
defmodule Langtest.Simulator do
  alias Langtest.Dataset

  # All available capital starts in cash.
  @initial_cash 10_000.0

  # Fee charged on both entries and exits.
  @fee 0.001

  # One completed round trip with its fee-adjusted cost basis and proceeds.
  defmodule Trade do
    defstruct buy_step: 0, sell_step: 0, cost: 0.0, proceeds: 0.0
  end

  # Simulation output: final equity, hourly equity series, trades, and timing.
  defmodule Result do
    defstruct final_equity: 0.0, equity: [], trades: [], seconds: 0.0
  end

  # Exposes the fixed starting capital to callers and tests.
  def initial_cash, do: @initial_cash

  # Exposes the fixed fee rate to callers and tests.
  def fee, do: @fee

  # Runs the timed hourly loop and returns the collected result.
  def run(%Dataset{steps: steps} = dataset) when steps > 0 do
    started = System.monotonic_time(:microsecond)

    {final_equity, equities_reversed, trades_reversed} =
      step(0, steps, dataset, @initial_cash, 0.0, nil, 0.0, nil, nil, [], [])

    finished = System.monotonic_time(:microsecond)

    %Result{
      final_equity: final_equity,
      equity: :lists.reverse(equities_reversed),
      trades: :lists.reverse(trades_reversed),
      seconds: (finished - started) / 1_000_000.0
    }
  end

  # Stops the recursion once every simulation step has been processed.
  defp step(
         index,
         steps,
         _dataset,
         _cash,
         _quantity,
         _coin,
         _last_close,
         _entry_step,
         _entry_cost,
         [final | _] = equities,
         trades
       )
       when index == steps do
    {final, equities, trades}
  end

  # Handles a flat account: buys the strongest candidate when one exists.
  defp step(
         index,
         steps,
         dataset,
         cash,
         _quantity,
         nil,
         last_close,
         _entry_step,
         _entry_cost,
         equities,
         trades
       ) do
    {cash, quantity, coin, last_close, entry_step, entry_cost, trades} =
      case Dataset.best_buy(dataset, index) do
        nil ->
          {cash, 0.0, nil, last_close, nil, nil, trades}

        {coin, close} ->
          quantity = cash / (close * (1.0 + @fee))
          {0.0, quantity, coin, close, index, cash, trades}
      end

    record(
      index,
      steps,
      dataset,
      cash,
      quantity,
      coin,
      last_close,
      entry_step,
      entry_cost,
      equities,
      trades
    )
  end

  # Handles a held position: checks its bar for an exit, then allows re-entry.
  defp step(
         index,
         steps,
         dataset,
         cash,
         quantity,
         coin,
         last_close,
         entry_step,
         entry_cost,
         equities,
         trades
       ) do
    case Dataset.close(dataset, index, coin) do
      :undefined ->
        record(
          index,
          steps,
          dataset,
          cash,
          quantity,
          coin,
          last_close,
          entry_step,
          entry_cost,
          equities,
          trades
        )

      close ->
        if Dataset.signal(dataset, index, coin) == -1 do
          proceeds = quantity * close * (1.0 - @fee)

          trade = %Trade{
            buy_step: entry_step,
            sell_step: index,
            cost: entry_cost,
            proceeds: proceeds
          }

          {cash, quantity, coin, last_close, entry_step, entry_cost, trades} =
            case Dataset.best_buy(dataset, index) do
              nil ->
                {proceeds, 0.0, nil, close, nil, nil, [trade | trades]}

              {next_coin, next_close} ->
                next_quantity = proceeds / (next_close * (1.0 + @fee))
                {0.0, next_quantity, next_coin, next_close, index, proceeds, [trade | trades]}
            end

          record(
            index,
            steps,
            dataset,
            cash,
            quantity,
            coin,
            last_close,
            entry_step,
            entry_cost,
            equities,
            trades
          )
        else
          record(
            index,
            steps,
            dataset,
            cash,
            quantity,
            coin,
            close,
            entry_step,
            entry_cost,
            equities,
            trades
          )
        end
    end
  end

  # Records equity for a flat account and advances to the next step.
  defp record(
         index,
         steps,
         dataset,
         cash,
         _quantity,
         nil,
         last_close,
         entry_step,
         entry_cost,
         equities,
         trades
       ) do
    step(
      index + 1,
      steps,
      dataset,
      cash,
      0.0,
      nil,
      last_close,
      entry_step,
      entry_cost,
      [cash | equities],
      trades
    )
  end

  # Records equity at the last known close and advances to the next step.
  defp record(
         index,
         steps,
         dataset,
         cash,
         quantity,
         coin,
         last_close,
         entry_step,
         entry_cost,
         equities,
         trades
       ) do
    equity = cash + quantity * last_close

    step(
      index + 1,
      steps,
      dataset,
      cash,
      quantity,
      coin,
      last_close,
      entry_step,
      entry_cost,
      [
        equity | equities
      ],
      trades
    )
  end
end
