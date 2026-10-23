# Verifies execution rules, fees, position limits, and data-gap behavior.
defmodule Langtest.SimulatorTest do
  use ExUnit.Case, async: true

  alias Langtest.{Dataset, Simulator}
  alias Langtest.Simulator.Trade

  # Builds a dataset directly from explicit per-step rows and candidates.
  defp dataset(closes, signals, best_buys) do
    steps = length(closes)
    coin_count = length(hd(closes))
    index = List.duplicate(10_000.0, steps)

    %Dataset{
      coins: Enum.map(0..(coin_count - 1), fn index -> "C#{index}-USDT" end),
      steps: steps,
      closes: closes |> Enum.map(&List.to_tuple/1) |> List.to_tuple(),
      signals: signals |> Enum.map(&List.to_tuple/1) |> List.to_tuple(),
      best_buys: List.to_tuple(best_buys),
      index: List.to_tuple(index),
      first_timestamp: 0,
      last_timestamp: steps - 1
    }
  end

  # A round trip deducts 0.1% on both the entry and the exit.
  test "applies fees on buy and sell" do
    result = Simulator.run(dataset([[100.0], [110.0]], [[1], [-1]], [{0, 100.0}, nil]))

    assert length(result.trades) == 1
    assert_in_delta result.final_equity, 10_978.021978021978, 0.0000001
    assert_in_delta Enum.at(result.equity, 0), 9_990.00999000999, 0.0000001

    %Trade{} = trade = hd(result.trades)
    assert trade.buy_step == 0
    assert trade.sell_step == 1
    assert trade.cost == 10_000.0
    assert_in_delta trade.proceeds, 10_978.021978021978, 0.0000001
  end

  # A held coin blocks buying another signal, even a stronger one.
  test "enforces the single-position rule" do
    closes = [[100.0, 50.0], [101.0, 49.0], [102.0, 48.0], [103.0, 47.0]]
    signals = [[1, 0], [0, 1], [-1, 1], [0, -1]]
    best_buys = [{0, 100.0}, {1, 49.0}, {1, 48.0}, nil]

    result = Simulator.run(dataset(closes, signals, best_buys))

    assert length(result.trades) == 2
    [first, second] = result.trades
    assert first.buy_step == 0
    assert first.sell_step == 2
    assert second.buy_step == 2
    assert second.sell_step == 3
    assert_in_delta Enum.at(result.equity, 1), 10_000.0 / 100.1 * 101.0, 0.0000001
  end

  # A missing bar carries the position and values it at the last known close.
  test "carries positions across data gaps" do
    closes = [[100.0], [:undefined], [110.0]]
    signals = [[1], [0], [-1]]
    best_buys = [{0, 100.0}, nil, nil]

    result = Simulator.run(dataset(closes, signals, best_buys))

    assert length(result.trades) == 1
    assert hd(result.trades).sell_step == 2
    assert Enum.at(result.equity, 1) == Enum.at(result.equity, 0)
    assert_in_delta result.final_equity, 10_000.0 / 100.1 * 110.0 * 0.999, 0.0000001
  end

  # Selling and re-entering in the same step is allowed.
  test "allows re-entry immediately after a sell" do
    closes = [[100.0, 20.0], [105.0, 21.0], [106.0, 22.0]]
    signals = [[1, 0], [-1, 1], [0, -1]]
    best_buys = [{0, 100.0}, {1, 21.0}, nil]

    result = Simulator.run(dataset(closes, signals, best_buys))

    assert length(result.trades) == 2
    [first, second] = result.trades
    assert first.sell_step == 1
    assert second.buy_step == 1
    assert second.sell_step == 2
    assert_in_delta second.cost, first.proceeds, 0.0000001
  end
end
