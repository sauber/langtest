defmodule Langtest.SimulatorTest do
  use ExUnit.Case, async: true

  alias Langtest.Sim.Simulator
  alias Langtest.Test.Fixtures
  alias Langtest.Test.Fixtures.ScriptedStrategy

  # Runs a scripted simulation and returns its result.
  defp run(specs, script) do
    market = Fixtures.market_of(specs)
    simulator = Simulator.new(market, ScriptedStrategy.new(script))
    Simulator.run(simulator)
  end

  # A buy spends all cash and pays the entry fee.
  test "a buy spends all cash and pays the entry fee" do
    result =
      run([%{symbol: "AAA-USDT", bars: [[0, 100], [1, 110]]}], %{
        "AAA-USDT" => %{signal: [:buy, :pass]}
      })

    assert_in_delta(Enum.at(result.equity, 0), 10000 / 1.001, 1.0e-9)
    assert result.trades == []
  end

  # A sell closes the position and pays the exit fee.
  test "a sell closes the position and pays the exit fee" do
    result =
      run(
        [%{symbol: "AAA-USDT", bars: [[0, 100], [1, 110], [2, 120]]}],
        %{"AAA-USDT" => %{signal: [:buy, :pass, :sell]}}
      )

    assert result.trades |> length() == 1
    trade = hd(result.trades)
    assert_in_delta(trade.quantity, 10000 / (100.0 * 1.001), 1.0e-9)
    assert_in_delta(trade.proceeds, trade.quantity * 120 * 0.999, 1.0e-9)
    assert_in_delta(trade.net_return, trade.proceeds / trade.cost_basis - 1, 1.0e-9)
  end

  # Only one coin can be held at a time.
  test "only one position may be held at a time" do
    result =
      run(
        [
          %{symbol: "AAA-USDT", bars: [[0, 100], [1, 100]]},
          %{symbol: "BBB-USDT", bars: [[0, 50], [1, 50]]}
        ],
        %{"AAA-USDT" => %{signal: [:buy, :pass]}, "BBB-USDT" => %{signal: [:buy, :buy]}}
      )

    assert result.trades == []
    assert_in_delta(Enum.at(result.equity, 0), 10000 / 1.001, 1.0e-9)
  end

  # The coin with the highest buy strength is bought first.
  test "the coin with the highest buy strength is bought first" do
    result =
      run(
        [
          %{symbol: "AAA-USDT", bars: [[0, 100]]},
          %{symbol: "BBB-USDT", bars: [[0, 100]]}
        ],
        %{
          "AAA-USDT" => %{signal: [:buy], strength: [1.0]},
          "BBB-USDT" => %{signal: [:buy], strength: [2.0]}
        }
      )

    assert_in_delta(Enum.at(result.equity, 0), 10000 / 1.001, 1.0e-9)
  end

  # Ties in buy strength are broken alphabetically.
  test "ties in buy strength are broken alphabetically" do
    result =
      run(
        [
          %{symbol: "BBB-USDT", bars: [[0, 100]]},
          %{symbol: "AAA-USDT", bars: [[0, 100]]}
        ],
        %{
          "BBB-USDT" => %{signal: [:buy], strength: [1.0]},
          "AAA-USDT" => %{signal: [:buy], strength: [1.0]}
        }
      )

    assert_in_delta(Enum.at(result.equity, 0), 10000 / 1.001, 1.0e-9)
  end

  # A coin with no bar at the current timestamp cannot be traded and carries its position forward.
  test "a gap carries the position forward without a trade" do
    result =
      run(
        [
          %{symbol: "AAA-USDT", bars: [[0, 100], [2, 120]]},
          %{symbol: "BBB-USDT", bars: [[1, 10]]}
        ],
        %{"AAA-USDT" => %{signal: [:buy, :sell]}, "BBB-USDT" => %{signal: [:buy]}}
      )

    assert result.trades |> length() == 1
    assert hd(result.trades).symbol == "AAA-USDT"
    assert Enum.at(result.equity, 1) > 0
  end

  # A sell may be followed by a new purchase in the same step.
  test "a sell may be followed by a new purchase in the same step" do
    result =
      run(
        [
          %{symbol: "AAA-USDT", bars: [[0, 100]]},
          %{symbol: "BBB-USDT", bars: [[0, 50]]}
        ],
        %{"AAA-USDT" => %{signal: [:sell]}, "BBB-USDT" => %{signal: [:buy], strength: [1.0]}}
      )

    assert result.trades |> length() == 0
    assert_in_delta(Enum.at(result.equity, 0), 10000 / 1.001, 1.0e-9)
  end
end
