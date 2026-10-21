defmodule Langtest.ChartTest do
  use ExUnit.Case, async: true

  alias Langtest.Metrics.Index
  alias Langtest.Report
  alias Langtest.Sim.Simulator
  alias Langtest.Strategy.Rsi
  alias Langtest.Test.Fixtures

  @max_width 80
  @max_lines 25

  # Removes the ANSI colour escapes so the visible width of a line can be measured.
  defp strip_ansi(text) do
    Regex.replace(~r/\e\[[0-9;]*m/, text, "")
  end

  # Builds a small market whose simulation produces a report.
  defp sample_report do
    market =
      Fixtures.market_of([
        %{symbol: "AAA-USDT", bars: [[0, 10], [3600, 11], [7200, 12], [10_800, 11]]},
        %{symbol: "BBB-USDT", bars: [[0, 5], [3600, 4], [7200, 6], [10_800, 7]]}
      ])

    strategy = Rsi.new()
    result = Simulator.new(market, strategy) |> Simulator.run()
    index = Index.build(market)

    Report.render(%{
      market: market,
      strategy_name: strategy.__struct__.name(strategy),
      equity: result.equity,
      index: index,
      trades: result.trades,
      sim_seconds: result.sim_seconds
    })
  end

  # Every line of the report fits within 80 visible columns.
  test "every report line fits within 80 visible columns" do
    sample_report()
    |> Enum.each(fn line -> assert String.length(strip_ansi(line)) <= @max_width end)
  end

  # The complete report fits within 25 lines.
  test "the complete report fits within 25 lines" do
    assert length(sample_report()) <= @max_lines
  end

  # The report contains all required metric labels.
  test "the report contains all required metric labels" do
    report = Enum.join(sample_report(), "\n")
    assert report =~ "equity / index"
    assert report =~ "sharpe"
    assert report =~ "win / loss"
    assert report =~ "avg gain"
    assert report =~ "avg holding"
    assert report =~ "sim time:"
  end
end
