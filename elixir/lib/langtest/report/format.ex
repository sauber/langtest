defmodule Langtest.Report.Format do
  @moduledoc "Formats the numbers and the dates of the terminal report."

  # Formats a number with a fixed number of decimals.
  def fixed(value, decimals) do
    :erlang.float_to_binary(value, decimals: decimals)
  end

  # Formats a number with thousands separators and no decimals.
  def integer(value) do
    rounded = round_float(value)
    Integer.to_string(rounded) |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  # Rounds a float to the nearest integer.
  defp round_float(value) when is_float(value), do: trunc(Float.round(value))
  defp round_float(value) when is_integer(value), do: value
  defp round_float(value), do: trunc(Float.round(value + 0.0))

  # Formats a timestamp as a plain calendar date.
  def date(timestamp) do
    timestamp
    |> DateTime.from_unix!(:second)
    |> DateTime.to_date()
    |> Date.to_iso8601()
  end
end
