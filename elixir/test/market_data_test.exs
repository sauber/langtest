# Verifies timeline merging, gap handling, and buy-strength tie-breaking.
defmodule Langtest.MarketDataTest do
  use ExUnit.Case, async: true

  alias Langtest.{Dataset, MarketData}

  # Test strategy that always buys and uses RSI itself as the ranking strength.
  defmodule StrengthStrategy do
    @behaviour Langtest.Strategy

    # Always emits a buy so simultaneous candidates reach the ranking step.
    @impl true
    def signal(_rsi), do: :buy

    # Uses RSI directly as strength, with zero during the warm-up.
    @impl true
    def strength(nil), do: 0.0
    def strength(rsi), do: rsi
  end

  # Builds hourly bars from a list of closes.
  defp bars(closes, base) do
    closes
    |> Enum.with_index()
    |> Enum.map(fn {close, index} -> {base + index * 3600, close} end)
  end

  # The union timeline keeps gaps and aligns each coin's bars to its steps.
  test "merges coin bars into the union timeline with gaps intact" do
    coin_a = {"AAA-USDT", [{1000, 100.0}, {3000, 110.0}, {4000, 120.0}]}
    coin_b = {"BBB-USDT", [{2000, 50.0}, {4000, 55.0}]}
    dataset = MarketData.build([coin_a, coin_b], List.duplicate(10_000.0, 4))

    assert dataset.steps == 4
    assert dataset.first_timestamp == 1000
    assert dataset.last_timestamp == 4000
    assert Dataset.close(dataset, 0, 0) == 100.0
    assert Dataset.close(dataset, 1, 0) == :undefined
    assert Dataset.close(dataset, 1, 1) == 50.0
    assert Dataset.close(dataset, 3, 0) == 120.0
    assert Dataset.close(dataset, 3, 1) == 55.0
    assert Tuple.to_list(dataset.best_buys) == [nil, nil, nil, nil]
  end

  # Equal buy strengths resolve to the alphabetically first coin.
  test "breaks equal buy-strength ties by coin order" do
    closes = Enum.map(0..15, fn index -> 100.0 - index end)
    coin_a = {"AAA-USDT", bars(closes, 1_000_000)}
    coin_b = {"BBB-USDT", bars(Enum.map(closes, &(&1 * 2.0)), 1_000_000)}

    dataset = MarketData.build([coin_b, coin_a], List.duplicate(10_000.0, 16))

    assert dataset.coins == ["AAA-USDT", "BBB-USDT"]
    assert Dataset.best_buy(dataset, 14) == {0, 86.0}
    assert Dataset.close(dataset, 14, 1) == 172.0
  end

  # The strongest simultaneous buy wins regardless of coin ordering.
  test "ranks simultaneous buys by highest strength" do
    falling = Enum.map(0..15, fn index -> 100.0 - index end)
    rising = Enum.map(0..15, fn index -> 100.0 + index end)

    dataset =
      MarketData.build(
        [{"AAA-USDT", bars(falling, 1_000_000)}, {"BBB-USDT", bars(rising, 1_000_000)}],
        List.duplicate(10_000.0, 16),
        StrengthStrategy
      )

    assert Dataset.best_buy(dataset, 14) == {1, 114.0}
  end

  # A mismatch between the merged timeline and the index is rejected.
  test "validates timeline length against the market index" do
    assert_raise ArgumentError, fn ->
      MarketData.build([{"AAA-USDT", [{1000, 100.0}]}], [10_000.0, 10_000.0])
    end
  end
end
