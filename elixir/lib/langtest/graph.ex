# Renders the strategy and index series as a colored terminal line chart.
defmodule Langtest.Graph do
  @strategy_color "\e[36m"
  @index_color "\e[35m"
  @both_color "\e[33m"
  @reset "\e[0m"
  @chart_width 76

  # Builds the framed chart lines plus a legend/date footer.
  def render(equity, index, opts \\ []) do
    width = Keyword.get(opts, :width, @chart_width)
    height = Keyword.get(opts, :height, 15)
    color? = Keyword.get(opts, :color, true)
    strategy = samples(equity, width)
    benchmark = samples(index, width)
    {minimum, maximum} = value_range(strategy ++ benchmark)

    grid =
      %{}
      |> overlay(benchmark, :index, width, height, minimum, maximum)
      |> overlay(strategy, :strategy, width, height, minimum, maximum)

    frame(width, height, grid, color?) ++
      [footer(Keyword.get(opts, :first_timestamp), Keyword.get(opts, :last_timestamp), color?)]
  end

  # Downsamples a series to one value per chart column.
  defp samples(values, width) do
    tuple = values |> normalize() |> List.to_tuple()
    count = tuple_size(tuple)

    if count == 0 do
      List.duplicate(0.0, width)
    else
      Enum.map(0..(width - 1), fn column ->
        position = round(column * (count - 1) / (width - 1))
        elem(tuple, position)
      end)
    end
  end

  # Accepts either a tuple (dataset index) or list (equity series).
  defp normalize(values) when is_tuple(values), do: Tuple.to_list(values)
  defp normalize(values) when is_list(values), do: values

  # Computes a shared y-range, padding a flat series so it remains visible.
  defp value_range(values) do
    minimum = Enum.min(values)
    maximum = Enum.max(values)

    if minimum == maximum do
      {minimum - 0.5, maximum + 0.5}
    else
      {minimum, maximum}
    end
  end

  # Draws one series into the grid, connecting vertical transitions.
  defp overlay(grid, series, tag, width, height, minimum, maximum) do
    {grid, _previous} =
      Enum.reduce(0..(width - 1), {grid, nil}, fn column, {grid, previous} ->
        row = row_for(Enum.at(series, column), minimum, maximum, height)

        grid =
          if previous == nil or previous == row do
            grid
          else
            connect(grid, previous, row, column, tag)
          end

        {put_cell(grid, row, column, tag, "─"), row}
      end)

    grid
  end

  # Maps a value onto a zero-based row from the top of the chart.
  defp row_for(value, minimum, maximum, height) do
    fraction = (value - minimum) / (maximum - minimum)
    round((1.0 - fraction) * (height - 1))
  end

  # Fills the vertical gap between the previous and current sample.
  defp connect(grid, previous, row, column, tag) do
    step = if row > previous, do: 1, else: -1
    fill_vertical(grid, previous + step, row, column, tag, step)
  end

  # Stops the vertical fill when it reaches the current sample row.
  defp fill_vertical(grid, row, stop, _column, _tag, _step) when row == stop, do: grid

  # Adds one colored connector cell and continues toward the sample row.
  defp fill_vertical(grid, row, stop, column, tag, step) do
    fill_vertical(put_cell(grid, row, column, tag, "│"), row + step, stop, column, tag, step)
  end

  # Stores a cell, resolving overlaps between the two colored series.
  defp put_cell(grid, row, column, tag, char) do
    key = {row, column}

    case Map.get(grid, key) do
      nil ->
        Map.put(grid, key, {tag, char})

      {:both, existing} ->
        Map.put(grid, key, {:both, merge_chars(existing, char)})

      {^tag, existing} ->
        Map.put(grid, key, {tag, merge_chars(existing, char)})

      _other ->
        Map.put(grid, key, {:both, "╋"})
    end
  end

  # Prefers a horizontal marker when two markers share a cell.
  defp merge_chars("─", _char), do: "─"
  defp merge_chars(_char, "─"), do: "─"
  defp merge_chars(_first, _second), do: "│"

  # Renders the border and all chart rows.
  defp frame(width, height, grid, color?) do
    top = "╭" <> String.duplicate("─", width) <> "╮"

    rows =
      for row <- 0..(height - 1) do
        cells = for column <- 0..(width - 1), into: "", do: cell(grid, row, column, color?)
        "│" <> cells <> "│"
      end

    bottom = "╰" <> String.duplicate("─", width) <> "╯"
    [top | rows] ++ [bottom]
  end

  # Renders one grid cell with its series color.
  defp cell(grid, row, column, color?) do
    case Map.get(grid, {row, column}) do
      nil -> " "
      {tag, char} -> paint(tag, char, color?)
    end
  end

  # Leaves characters uncolored when color output is disabled.
  defp paint(_tag, char, false), do: char

  # Applies the configured ANSI color for a series.
  defp paint(:strategy, char, true), do: @strategy_color <> char <> @reset
  defp paint(:index, char, true), do: @index_color <> char <> @reset
  defp paint(:both, char, true), do: @both_color <> char <> @reset

  # Aligns the date range with a colored legend under the chart.
  defp footer(first_timestamp, last_timestamp, color?) do
    left = format_date(first_timestamp)
    right = format_date(last_timestamp)
    legend = paint(:strategy, "── Strategy", color?) <> "  " <> paint(:index, "── Index", color?)

    gap =
      max(
        1,
        @chart_width + 2 - String.length(left) - visible_length(legend) - String.length(right) - 2
      )

    left <> "  " <> legend <> String.duplicate(" ", gap) <> right
  end

  # Formats a Unix timestamp as a UTC calendar date.
  defp format_date(nil), do: ""

  # Converts seconds since the Unix epoch to an ISO-8601 date.
  defp format_date(timestamp) do
    timestamp
    |> DateTime.from_unix!()
    |> DateTime.to_date()
    |> Date.to_iso8601()
  end

  # Counts visible characters after removing ANSI escape sequences.
  defp visible_length(text) do
    text
    |> String.replace(~r/\e\[[0-9;]*m/, "")
    |> String.length()
  end
end
