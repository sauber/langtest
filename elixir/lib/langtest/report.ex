defmodule Langtest.Report do
  @moduledoc "Renders the metrics, the simulation time and the character chart of one evaluation run."

  alias Langtest.Metrics.Stats
  alias Langtest.Report.{Chart, Format}

  @label_width 18
  @value_width 10
  @equity_color "96"
  @index_color "95"

  # Renders the complete report as a list of terminal lines.
  def render(input) do
    market = input.market
    steps = length(market.timeline)
    first = hd(market.timeline)
    last = List.last(market.timeline)
    ratio = Enum.at(input.equity, steps - 1) / Enum.at(input.index, steps - 1)
    sharpe = Stats.sharpe_ratio(input.equity)
    win_loss = Stats.win_loss_ratio(input.trades)

    header =
      input.strategy_name <>
        " · " <>
        Integer.to_string(length(market.coins)) <>
        " coins · " <>
        Format.integer(steps) <>
        " hourly steps · " <> Format.date(first) <> " → " <> Format.date(last)

    [
      header,
      metric(
        "equity / index",
        Format.fixed(ratio, 4) <> "x",
        "  (equity " <>
          Format.integer(Enum.at(input.equity, steps - 1)) <>
          " · index " <> Format.integer(Enum.at(input.index, steps - 1)) <> ")"
      ),
      metric("sharpe (hourly)", if(sharpe, do: Format.fixed(sharpe, 4), else: "N/A")),
      metric(
        "win / loss",
        win_loss_ratio_value(input.trades, win_loss),
        "  (" <>
          Integer.to_string(win_loss.wins) <>
          " W / " <>
          Integer.to_string(win_loss.losses) <>
          " L / " <> Integer.to_string(length(input.trades)) <> " trades)"
      ),
      metric(
        "avg gain / trade",
        if(length(input.trades) == 0,
          do: "N/A",
          else: format_percent(Stats.average_gain(input.trades))
        )
      ),
      metric(
        "avg holding time",
        if(length(input.trades) == 0,
          do: "N/A",
          else: Format.fixed(Stats.average_holding_steps(input.trades), 2) <> " h"
        )
      ),
      "sim time: " <> Format.fixed(input.sim_seconds, 3) <> " s"
    ] ++
      Chart.render(List.to_tuple(input.equity), List.to_tuple(input.index), first, last) ++
      [
        "\e[" <>
          @equity_color <>
          "m●\e[0m strategy equity (cyan)   " <>
          "\e[" <> @index_color <> "m●\e[0m market index (magenta, shared axis)"
      ]
  end

  # Formats one aligned row of the metrics block.
  defp metric(label, value, detail \\ "") do
    String.pad_trailing(label, @label_width) <> String.pad_leading(value, @value_width) <> detail
  end

  # Formats the win/loss ratio value of one simulation run.
  defp win_loss_ratio_value([], _win_loss), do: "N/A"
  defp win_loss_ratio_value(_trades, %{ratio: :infinity}), do: "inf"
  defp win_loss_ratio_value(_trades, %{ratio: ratio}), do: Format.fixed(ratio, 4)

  # Formats a fraction as a signed percentage.
  defp format_percent(value) do
    sign = if value >= 0, do: "+", else: ""
    sign <> Format.fixed(value * 100, 4) <> "%"
  end
end
