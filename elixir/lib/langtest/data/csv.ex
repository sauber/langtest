defmodule Langtest.Data.CSV do
  @moduledoc "Reads the market CSV files of one coin."

  alias Langtest.Domain.Bar

  @newline "\n"
  @comma ","

  # Reads one CSV file and returns the bars of one coin in chronological order.
  def read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, parse(content)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Parses the content of one CSV file into the bars of one coin.
  def parse(content) do
    content
    |> :binary.split(@newline, [:global])
    |> Enum.drop(1)
    |> Enum.map(&parse_row/1)
    |> Enum.reject(&is_nil/1)
  end

  # Parses one CSV data row into the timestamp and close price the evaluator needs.
  def parse_row(row) do
    case :binary.split(row, @comma, [:global]) do
      [timestamp, _datetime, _open, _high, _low, close | _rest] ->
        with {:ok, timestamp} <- parse_integer(timestamp),
             {:ok, close} <- parse_float(close) do
          %Bar{timestamp: timestamp, close: close}
        end

      _fields ->
        nil
    end
  end

  # Parses one integer field of a CSV row.
  defp parse_integer(field) do
    case Integer.parse(field) do
      {value, ""} -> {:ok, value}
      _invalid -> :error
    end
  end

  # Parses one floating point field of a CSV row, accepting plain integers as well.
  defp parse_float(field) do
    case :binary.match(field, ".") do
      :nomatch ->
        case Integer.parse(field) do
          {value, ""} -> {:ok, value * 1.0}
          _invalid -> :error
        end

      _dot ->
        {:ok, :erlang.binary_to_float(field)}
    end
  end
end
