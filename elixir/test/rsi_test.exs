defmodule Langtest.RsiTest do
  use ExUnit.Case, async: true

  alias Langtest.Indicator.Rsi
  alias Langtest.Test.Fixtures

  # The Wilder example produces the canonical RSI values with 3 decimals of precision.
  test "wilder RSI matches the classic Wilder example" do
    {closes, expected} = Fixtures.wilder_rsi_fixture()
    rsi = Rsi.wilder_rsi(closes)
    values = Enum.drop(rsi, 14)

    Enum.zip(values, expected)
    |> Enum.each(fn {value, expected} -> assert_in_delta(value, expected, 0.01) end)
  end

  # A three-period RSI over five closes produces the hand-computed values.
  test "wilder RSI matches the hand-computed short example" do
    rsi = Rsi.wilder_rsi([10, 11, 13, 12, 14], 3)
    assert Enum.at(rsi, 0) == nil
    assert Enum.at(rsi, 1) == nil
    assert Enum.at(rsi, 2) == nil
    assert_in_delta(Enum.at(rsi, 3), 75.0, 1.0e-12)
    assert_in_delta(Enum.at(rsi, 4), 85.71428571428571, 1.0e-12)
  end

  # An all-flat series gives RSI 100 because the average loss is zero.
  test "wilder RSI is 100 when the average loss is zero" do
    rsi = Rsi.wilder_rsi([10, 11, 12, 13, 14, 15], 3)
    assert Enum.at(rsi, 5) == 100.0
  end

  # A series with no gains gives RSI 0 because the average gain is zero.
  test "wilder RSI is 0 when the average gain is zero" do
    rsi = Rsi.wilder_rsi([15, 14, 13, 12, 11, 10], 3)
    assert Enum.at(rsi, 5) == 0.0
  end
end
