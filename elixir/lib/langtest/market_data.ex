# Loads CSV candles and builds the precomputed, step-indexed dataset.
defmodule Langtest.MarketData do
  alias Langtest.{CSV, Dataset, Meta, RSI, Strategy}

  # Loads meta, all coin CSVs in parallel, and returns a precomputed dataset.
  def load!(data_dir, strategy \\ Strategy.RSI) do
    meta = Meta.load!(Path.join(data_dir, "meta.json"))

    coin_bars =
      meta.coins
      |> Task.async_stream(
        fn coin -> {coin.symbol, read_bars!(Path.join(data_dir, coin.file))} end,
        ordered: true,
        timeout: :infinity
      )
      |> Enum.map(fn
        {:ok, coin_bar} -> coin_bar
        {:exit, reason} -> exit(reason)
      end)

    build(coin_bars, meta.index, strategy)
  end

  # Builds the dataset from per-coin bars and the precomputed market index.
  def build(coin_bars, index_values, strategy \\ Strategy.RSI) do
    coin_bars = Enum.sort_by(coin_bars, fn {symbol, _bars} -> symbol end)
    {rows_by_coin, symbols, first_timestamp, last_timestamp} = prepare(coin_bars, strategy)
    cursors = List.to_tuple(rows_by_coin)
    count = tuple_size(cursors)
    {steps_reversed, step_count} = merge_steps(cursors, count, [], 0)

    if step_count != length(index_values) do
      raise ArgumentError,
            "timeline has #{step_count} steps but the market index has #{length(index_values)}"
    end

    {closes, signals, best_buys} = split_steps(steps_reversed)

    %Dataset{
      coins: symbols,
      steps: step_count,
      closes: closes,
      signals: signals,
      best_buys: best_buys,
      index: List.to_tuple(index_values),
      first_timestamp: first_timestamp,
      last_timestamp: last_timestamp
    }
  end

  # Converts bars to RSI rows and extracts dataset metadata, releasing raw bars.
  defp prepare(coin_bars, strategy) do
    rows = Enum.map(coin_bars, fn {_symbol, bars} -> rsi_rows(bars, strategy) end)
    symbols = Enum.map(coin_bars, fn {symbol, _bars} -> symbol end)

    {rows, symbols, first_timestamp(coin_bars), last_timestamp(coin_bars)}
  end

  # Reads one CSV file and returns its sorted {timestamp, close} rows.
  defp read_bars!(path) do
    [_header | lines] = path |> File.read!() |> String.split("\n", trim: true)
    Enum.map(lines, &CSV.timestamp_and_close/1)
  end

  # Computes RSI and strategy output once per bar, before the timed loop.
  defp rsi_rows(bars, strategy) do
    {rows, _state} =
      Enum.reduce(bars, {[], RSI.new()}, fn {timestamp, close}, {acc, state} ->
        {state, rsi} = RSI.update(state, close)
        signal = strategy.signal(rsi)
        strength = if signal == :buy, do: strategy.strength(rsi), else: :undefined
        {[{timestamp, close, signal, strength} | acc], state}
      end)

    :lists.reverse(rows)
  end

  # Merges the sorted per-coin bar lists into the union simulation timeline.
  defp merge_steps(cursors, count, acc, step) do
    case min_timestamp(cursors, 0, nil) do
      nil ->
        {acc, step}

      timestamp ->
        {gathered_reversed, cursors} = gather(cursors, timestamp, 0, [], count)
        gathered = :lists.reverse(gathered_reversed)
        {closes, signals, best} = build_step(gathered, count)

        best =
          case best do
            nil -> nil
            {coin, close, _strength} -> {coin, close}
          end

        merge_steps(cursors, count, [{closes, signals, best} | acc], step + 1)
    end
  end

  # Finds the smallest timestamp among the current head of every coin list.
  defp min_timestamp(cursors, index, minimum) when index == tuple_size(cursors), do: minimum

  # Advances the scan past an empty list or compares the next head timestamp.
  defp min_timestamp(cursors, index, minimum) do
    case elem(cursors, index) do
      [] ->
        min_timestamp(cursors, index + 1, minimum)

      [{timestamp, _close, _signal, _strength} | _rest] ->
        minimum = if minimum == nil or timestamp < minimum, do: timestamp, else: minimum
        min_timestamp(cursors, index + 1, minimum)
    end
  end

  # Collects every coin bar matching the timestamp and advances those cursors.
  defp gather(cursors, _timestamp, index, acc, count) when index == count, do: {acc, cursors}

  # Takes a matching head, advances that coin cursor, and keeps scanning.
  defp gather(cursors, timestamp, index, acc, count) do
    case elem(cursors, index) do
      [{^timestamp, close, signal, strength} | rest] ->
        cursors = put_elem(cursors, index, rest)
        gather(cursors, timestamp, index + 1, [{index, close, signal, strength} | acc], count)

      _other ->
        gather(cursors, timestamp, index + 1, acc, count)
    end
  end

  # Builds the per-step close tuple, signal tuple, and best buy candidate.
  defp build_step(gathered, count) do
    closes = :erlang.make_tuple(count, :undefined)
    signals = :erlang.make_tuple(count, 0)
    fill_step(gathered, closes, signals, nil)
  end

  # Fills one step from bars already ordered by coin index (alphabetical).
  defp fill_step([], closes, signals, best), do: {closes, signals, best}

  # Stores a bar and keeps the highest-strength buy, preferring lower coin indices.
  defp fill_step([{coin, close, signal, strength} | rest], closes, signals, best) do
    closes = put_elem(closes, coin, close)
    signals = put_elem(signals, coin, signal_tag(signal))

    best =
      case signal do
        :buy ->
          case best do
            nil ->
              {coin, close, strength}

            {_coin, _close, best_strength} when strength > best_strength ->
              {coin, close, strength}

            _other ->
              best
          end

        _other ->
          best
      end

    fill_step(rest, closes, signals, best)
  end

  # Maps atoms to the compact integer signal representation used in the loop.
  defp signal_tag(:buy), do: 1
  defp signal_tag(:sell), do: -1
  defp signal_tag(:pass), do: 0

  # Converts the reverse-chronological step triples into three ordered tuples.
  defp split_steps(steps_reversed) do
    {closes, signals, best_buys} =
      Enum.reduce(steps_reversed, {[], [], []}, fn {closes, signals, best},
                                                   {closes_acc, signals_acc, best_acc} ->
        {[closes | closes_acc], [signals | signals_acc], [best | best_acc]}
      end)

    {List.to_tuple(closes), List.to_tuple(signals), List.to_tuple(best_buys)}
  end

  # Returns the earliest bar timestamp across all coins.
  defp first_timestamp(coin_bars) do
    coin_bars
    |> Enum.map(fn {_symbol, [{timestamp, _close} | _rest]} -> timestamp end)
    |> Enum.min()
  end

  # Returns the latest bar timestamp across all coins.
  defp last_timestamp(coin_bars) do
    coin_bars
    |> Enum.map(fn {_symbol, bars} -> bars |> List.last() |> elem(0) end)
    |> Enum.max()
  end
end
