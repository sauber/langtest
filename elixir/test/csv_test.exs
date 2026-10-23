# Verifies CSV field extraction for integer and decimal price formats.
defmodule Langtest.CSVTest do
  use ExUnit.Case, async: true

  alias Langtest.CSV

  # A normal KuCoin row is parsed into Unix seconds and a float close.
  test "extracts timestamp and close from a data row" do
    row = "1507089600,2017-10-04T04:00:00.000Z,4307,4307,4307,4307,0.001,4.307"
    assert CSV.timestamp_and_close(row) == {1_507_089_600, 4307.0}
  end

  # Decimal closes keep their fractional part.
  test "parses decimal closes" do
    row = "1600000000,2020-09-13T12:26:40.000Z,1,2,0.5,44.34,10,443.4"
    assert CSV.timestamp_and_close(row) == {1_600_000_000, 44.34}
  end
end
