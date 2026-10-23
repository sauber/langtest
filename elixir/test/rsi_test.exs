# Verifies Wilder RSI values and the RSI threshold strategy.
defmodule Langtest.RSITest do
  use ExUnit.Case, async: true

  alias Langtest.RSI
  alias Langtest.Strategy.RSI, as: Strategy

  # Classic 20-close fixture used by RSI documentation examples.
  @closes [
    44.34,
    44.09,
    44.15,
    43.61,
    44.33,
    44.83,
    45.10,
    45.42,
    45.84,
    46.08,
    45.89,
    46.03,
    45.61,
    46.28,
    46.28,
    46.00,
    46.03,
    46.41,
    46.22,
    45.64
  ]

  # First six computable RSI values for the fixture, using Wilder smoothing.
  @expected [70.464135, 66.249619, 66.480942, 69.346853, 66.294713, 57.915021]

  # Runs the incremental indicator over the fixture closes.
  defp series(closes) do
    {values, _state} =
      Enum.reduce(closes, {[], RSI.new()}, fn close, {acc, state} ->
        {state, rsi} = RSI.update(state, close)
        {[rsi | acc], state}
      end)

    :lists.reverse(values)
  end

  # Bars before the warm-up completes must not produce a signal.
  test "returns nil until fourteen changes have been observed" do
    values = series(@closes)
    assert Enum.take(values, 14) == List.duplicate(nil, 14)
    assert Enum.at(values, 14) != nil
  end

  # Known fixture values pin down warm-up and Wilder smoothing arithmetic.
  test "matches expected RSI values for the fixed fixture" do
    values = series(@closes) |> Enum.drop(14)

    Enum.zip(values, @expected)
    |> Enum.each(fn {actual, expected} ->
      assert_in_delta actual, expected, 0.000001
    end)
  end

  # Flat prices produce a neutral RSI instead of dividing by zero.
  test "returns neutral RSI for a completely flat series" do
    values = series(List.duplicate(10.0, 20))
    assert Enum.at(values, 14) == 50.0
  end

  # The strategy maps RSI thresholds and raw strength as specified.
  test "maps thresholds to signals and strengths" do
    assert Strategy.signal(nil) == :pass
    assert Strategy.signal(29.9) == :buy
    assert Strategy.signal(30.0) == :buy
    assert Strategy.signal(50.0) == :pass
    assert Strategy.signal(70.0) == :sell
    assert Strategy.signal(70.1) == :sell
    assert Strategy.strength(25.0) == 5.0
  end
end
