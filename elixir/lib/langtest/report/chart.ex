defmodule Langtest.Report.Chart do
  @moduledoc "Draws the equity curve and the market index as two polylines on one shared axis."

  alias Langtest.Report.Format

  @plot_width 66
  @plot_height 13
  @gutter 7
  @inner_width @gutter + @plot_width + 3
  @equity_color "96"
  @index_color "95"

  # Draws the equity curve and the market index as a character chart.
  def render(equity, index, first_timestamp, last_timestamp) do
    equity_columns = downsample(equity, @plot_width)
    index_columns = downsample(index, @plot_width)
    {min, max} = extent(equity_columns, index_columns)
    equity_grid = rasterize(Enum.map(equity_columns, &to_row(&1, min, max, @plot_height)))
    index_grid = rasterize(Enum.map(index_columns, &to_row(&1, min, max, @plot_height)))

    frame = ["╭" <> String.duplicate("─", @inner_width) <> "╮"]

    rows =
      for row <- 0..(@plot_height - 1) do
        label = label_for(row, min, max)

        "│ " <>
          String.pad_leading(label, @gutter) <>
          "┤" <>
          build_row(Enum.at(equity_grid, row), Enum.at(index_grid, row)) <> " │"
      end

    start = "─ " <> Format.date(first_timestamp) <> " "
    stop = " " <> Format.date(last_timestamp) <> " "
    dashes = max(0, @inner_width - String.length(start) - String.length(stop))

    frame ++ rows ++ ["╰" <> start <> String.duplicate("─", dashes) <> stop <> "╯"]
  end

  # Down-samples a value series into the given number of columns by averaging buckets.
  defp downsample(series, width) do
    count = tuple_size(series)

    for column <- 0..(width - 1) do
      from = div(column * count, width)
      to = max(from + 1, div((column + 1) * count, width))
      sum = Enum.reduce(from..(to - 1), 0, fn index, sum -> sum + elem(series, index) end)
      sum / (to - from)
    end
  end

  # Determines the shared minimum and maximum of both plotted series.
  defp extent(equity_columns, index_columns) do
    values = equity_columns ++ index_columns
    {Enum.min(values), Enum.max(values)}
  end

  # Converts a value into a row index on a shared linear axis.
  defp to_row(value, min, max, height) do
    if max <= min do
      height - 1
    else
      row = trunc(Float.round((max - value) / (max - min) * (height - 1)))
      min(height - 1, max(0, row))
    end
  end

  # Rasterises one polyline into a character grid using soft line-drawing characters.
  defp rasterize(rows) do
    width = length(rows)
    grid = List.duplicate(:binary.copy(" ", width), @plot_height)
    first = round_to_int(hd(rows))
    rising = length(rows) > 1 and round_to_int(Enum.at(rows, 1)) < first
    grid = put_char(grid, first, 0, if(rising, do: "╰", else: "╭"))
    rasterize_columns(grid, rows, 1)
  end

  # Rasterises every column of one polyline into the character grid.
  defp rasterize_columns(grid, rows, column) do
    if column >= length(rows) do
      grid
    else
      from = round_to_int(Enum.at(rows, column - 1))
      to = round_to_int(Enum.at(rows, column))

      grid =
        if from == to do
          put_char(grid, from, column, "─")
        else
          grid = fill_column(grid, min(from, to), max(from, to), column)
          grid = put_char(grid, from, column, if(to < from, do: "╯", else: "╮"))
          put_char(grid, to, column, "╰")
        end

      rasterize_columns(grid, rows, column + 1)
    end
  end

  # Fills the vertical span of one column with the line drawing character.
  defp fill_column(grid, low, high, column) do
    Enum.reduce(low..high, grid, fn row, grid -> put_char(grid, row, column, "│") end)
  end

  # Writes one character into the character grid.
  defp put_char(grid, row, column, char) do
    List.update_at(grid, row, fn line ->
      prefix = binary_part(line, 0, column)
      suffix = binary_part(line, column + 1, byte_size(line) - column - 1)
      prefix <> char <> suffix
    end)
  end

  # Rounds one row index to the nearest integer.
  defp round_to_int(value) when is_integer(value), do: value
  defp round_to_int(value), do: trunc(Float.round(value + 0.0))

  # Merges the two plot rows into one coloured terminal row.
  defp build_row(equity_row, index_row) do
    {parts, run, color} =
      Enum.reduce(0..(@plot_width - 1), {[], "", ""}, fn column, {parts, run, color} ->
        {char, char_color} = column_char(equity_row, index_row, column)

        if char_color != color do
          {flush(parts, color, run), char, char_color}
        else
          {parts, run <> char, color}
        end
      end)

    parts |> flush(color, run) |> Enum.join()
  end

  # Picks the character and the colour of one column of the merged plot row.
  defp column_char(equity_row, index_row, column) do
    equity_char = String.at(equity_row, column)
    index_char = String.at(index_row, column)

    cond do
      equity_char != " " -> {equity_char, @equity_color}
      index_char != " " -> {index_char, @index_color}
      true -> {" ", ""}
    end
  end

  # Appends the coloured run of characters to the parts of a terminal row.
  defp flush(parts, _color, ""), do: parts
  defp flush(parts, "", run), do: parts ++ [run]
  defp flush(parts, color, run), do: parts ++ ["\e[#{color}m#{run}\e[0m"]

  # Formats a large number compactly for the narrow axis gutter.
  defp format_compact(value) do
    absolute = abs(value)

    cond do
      absolute >= 1.0e9 -> Format.fixed(value / 1.0e9, 2) <> "B"
      absolute >= 1.0e6 -> Format.fixed(value / 1.0e6, 2) <> "M"
      absolute >= 1.0e3 -> Format.fixed(value / 1.0e3, 1) <> "k"
      true -> Format.fixed(value, 0)
    end
  end

  # Formats the axis label of one plot row.
  defp label_for(row, min, max) do
    cond do
      row == 0 -> format_compact(max)
      row == @plot_height - 1 -> format_compact(min)
      row == div(@plot_height, 2) -> format_compact((max + min) / 2)
      true -> ""
    end
  end
end
