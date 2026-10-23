# Formats metrics and the chart into the terminal's 80x25 output budget.
defmodule Langtest.Report do
  alias Langtest.{Dataset, Graph, Metrics, Simulator.Result}

  # Renders the complete report as a list of lines.
  def render(%Metrics{} = metrics, %Result{} = result, %Dataset{} = dataset, opts \\ []) do
    color? = Keyword.get(opts, :color, true)

    [
      summary(metrics),
      performance(metrics),
      "Sim time #{format_number(result.seconds, 3)} s"
    ] ++
      Graph.render(result.equity, dataset.index,
        color: color?,
        first_timestamp: dataset.first_timestamp,
        last_timestamp: dataset.last_timestamp
      )
  end

  # Formats final equity, index value, and their ratio on the first line.
  defp summary(metrics) do
    "Strategy #{money(metrics.final_equity)} USDT    " <>
      "Index #{money(metrics.index_final)} USDT    " <>
      "Market ratio #{format_number(metrics.ratio, 3)}"
  end

  # Formats Sharpe, win/loss, average gain, and average holding time.
  defp performance(metrics) do
    "Sharpe #{format_number(metrics.sharpe, 3)}    " <>
      "Win/loss #{format_win_loss(metrics.win_loss)}    " <>
      "Avg gain #{format_percent(metrics.avg_gain)}    " <>
      "Avg hold #{format_holding(metrics.avg_holding)}"
  end

  # Formats a finite number with the requested decimals, or a status marker.
  defp format_number(nil, _decimals), do: "N/A"
  defp format_number(:infinity, _decimals), do: "inf"
  defp format_number(value, decimals), do: :erlang.float_to_binary(value, decimals: decimals)

  # Formats the win/loss ratio with two decimals.
  defp format_win_loss(nil), do: "N/A"
  defp format_win_loss(:infinity), do: "inf"
  defp format_win_loss(value), do: :erlang.float_to_binary(value, decimals: 2)

  # Formats an average trade return as a percentage.
  defp format_percent(nil), do: "N/A"
  defp format_percent(value), do: :erlang.float_to_binary(value * 100.0, decimals: 2) <> "%"

  # Formats an average holding period in simulation steps.
  defp format_holding(nil), do: "N/A"
  defp format_holding(value), do: :erlang.float_to_binary(value, decimals: 1) <> " h"

  # Formats a USDT amount with two decimals and thousands separators.
  defp money(value) do
    [whole, fraction] =
      value |> Kernel.*(1.0) |> :erlang.float_to_binary(decimals: 2) |> String.split(".")

    {sign, digits} = split_sign(whole)

    grouped =
      digits
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(",", &Enum.join/1)
      |> String.reverse()

    sign <> grouped <> "." <> fraction
  end

  # Separates a leading minus sign from the integer digits.
  defp split_sign("-" <> digits), do: {"-", digits}
  defp split_sign(digits), do: {"", digits}
end
