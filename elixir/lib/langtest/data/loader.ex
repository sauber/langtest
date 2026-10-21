defmodule Langtest.Data.Loader do
  @moduledoc "Loads the market CSVs and aligns every coin to the shared simulation timeline."

  alias Langtest.Domain.{CoinGrid, CoinSeries, Market}

  @extension ".csv"

  # Loads every coin CSV of a directory and aligns all coins to one simulation timeline.
  def load_market(data_dir) do
    with {:ok, symbols} <- list_symbols(data_dir),
         {:ok, histories} <- read_histories(data_dir, symbols) do
      timeline = build_timeline(histories)
      {:ok, %Market{timeline: timeline, coins: align(timeline, histories)}}
    end
  end

  # Lists the symbols of every CSV file in the data directory, sorted alphabetically.
  def list_symbols(data_dir) do
    case File.ls(data_dir) do
      {:ok, entries} ->
        {:ok,
         entries
         |> Enum.filter(&String.ends_with?(&1, @extension))
         |> Enum.map(&String.replace_suffix(&1, @extension, ""))
         |> Enum.sort()}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Reads every coin CSV of the data directory in parallel.
  defp read_histories(data_dir, symbols) do
    symbols
    |> Task.async_stream(
      fn symbol ->
        path = Path.join(data_dir, symbol <> @extension)

        case Langtest.Data.CSV.read_file(path) do
          {:ok, bars} -> {:ok, {symbol, bars}}
          {:error, reason} -> {:error, {symbol, reason}}
        end
      end,
      timeout: :infinity,
      ordered: true
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, {symbol, bars}}}, {:ok, histories} ->
        {:cont, {:ok, [history_of(symbol, bars) | histories]}}

      {:ok, {:error, {_symbol, reason}}}, _acc ->
        {:halt, {:error, reason}}

      {:exit, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, histories} -> {:ok, Enum.reverse(histories)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Builds the bar history of one coin from its parsed bars.
  defp history_of(symbol, bars) do
    %{
      symbol: symbol,
      timestamps: Enum.map(bars, & &1.timestamp),
      closes: Enum.map(bars, & &1.close)
    }
  end

  # Builds the shared simulation timeline as the sorted union of every coin's timestamps.
  def build_timeline(histories) do
    histories
    |> Enum.map(& &1.timestamps)
    |> Enum.concat()
    |> :lists.usort()
  end

  # Aligns every coin's bar history to the shared simulation timeline.
  def align(timeline, histories) do
    Enum.map(histories, fn history ->
      grid = align_coin(timeline, history)
      %CoinSeries{symbol: history.symbol, closes: history.closes, grid: grid}
    end)
  end

  # Builds the step-indexed price grid of one coin from its bar history.
  defp align_coin(timeline, history) do
    steps = length(timeline)
    bar_steps = bar_step_indices(timeline, history.timestamps)
    close = scatter_closes(bar_steps, history.closes, steps)

    %CoinGrid{
      close: List.to_tuple(close),
      last_close: List.to_tuple(forward_fill(close)),
      bar_steps: List.to_tuple(bar_steps)
    }
  end

  # Computes the timeline step index of every bar of one coin.
  defp bar_step_indices(timeline, timestamps) do
    walk_timeline(timeline, timestamps, 0, [])
  end

  # Walks the shared timeline and collects the step index of every bar of one coin.
  defp walk_timeline([], _timestamps, _step, acc), do: Enum.reverse(acc)

  defp walk_timeline([timestamp | rest_timeline], timestamps, step, acc) do
    case timestamps do
      [bar_timestamp | _rest] when bar_timestamp == timestamp ->
        walk_timeline(rest_timeline, tl(timestamps), step + 1, [step | acc])

      _timestamps ->
        walk_timeline(rest_timeline, timestamps, step + 1, acc)
    end
  end

  # Scatters the closes of one coin onto the shared simulation timeline.
  defp scatter_closes(bar_steps, closes, steps) do
    {scattered, last_step} = scatter(Enum.zip(bar_steps, closes), 0, [])
    scattered ++ List.duplicate(nil, steps - last_step)
  end

  # Emits the gaps and the closes of one coin in timeline order.
  defp scatter([], last_step, acc), do: {Enum.concat(Enum.reverse(acc)), last_step}

  defp scatter([{step, close} | rest], previous, acc) do
    acc = [List.duplicate(nil, step - previous) ++ [close] | acc]
    scatter(rest, step + 1, acc)
  end

  # Fills the gaps of one price series with the last known close.
  defp forward_fill(closes) do
    {_previous, filled} =
      Enum.reduce(closes, {nil, []}, fn close, {previous, acc} ->
        value = if is_nil(close), do: previous, else: close
        {value, [value | acc]}
      end)

    Enum.reverse(filled)
  end
end
