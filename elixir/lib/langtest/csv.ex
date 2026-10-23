# Fast, allocation-light extraction of the timestamp and close CSV columns.
defmodule Langtest.CSV do
  # Returns {timestamp, close} from one data row, ignoring other columns.
  def timestamp_and_close(line) do
    [timestamp, _datetime, _open, _high, _low, close | _rest] =
      :binary.split(line, ",", [:global])

    {:erlang.binary_to_integer(timestamp), to_float(close)}
  end

  # Converts a numeric field to a float, accepting integer-formatted prices.
  def to_float(field) do
    case :binary.match(field, ".") do
      :nomatch -> :erlang.binary_to_integer(field) * 1.0
      _period -> :erlang.binary_to_float(field)
    end
  end
end
