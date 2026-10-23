# Verifies chart framing, width limits, and the complete report budget.
defmodule Langtest.GraphTest do
  use ExUnit.Case, async: true

  alias Langtest.{Dataset, Graph, Metrics, Report}
  alias Langtest.Simulator.Result

  # Removes ANSI escape sequences before measuring visible width.
  defp visible(line), do: String.replace(line, ~r/\e\[[0-9;]*m/, "")

  # The chart uses the soft frame characters and fits the 80-column budget.
  test "renders a framed two-series chart within 80 columns" do
    equity = [10_000.0, 10_500.0, 11_000.0, 10_800.0, 12_000.0]
    index = [10_000.0, 10_200.0, 10_400.0, 10_300.0, 10_600.0]

    lines =
      Graph.render(equity, index,
        color: true,
        first_timestamp: 1_507_089_600,
        last_timestamp: 1_792_666_800
      )

    assert String.starts_with?(hd(lines), "╭")
    assert String.starts_with?(List.last(lines), "2017-10-04")
    assert length(lines) == 18
    assert Enum.all?(lines, fn line -> String.length(visible(line)) <= 80 end)
  end

  # The full report stays within the 25-line terminal budget.
  test "keeps the full report within 25 lines" do
    dataset = %Dataset{
      steps: 5,
      index: {10_000.0, 10_600.0},
      first_timestamp: 1_507_089_600,
      last_timestamp: 1_792_666_800
    }

    metrics = %Metrics{
      final_equity: 12_345.67,
      index_final: 10_600.0,
      ratio: 1.164686,
      sharpe: 0.842,
      win_loss: :infinity,
      avg_gain: 0.0321,
      avg_holding: 42.5
    }

    result = %Result{
      final_equity: 12_345.67,
      equity: [10_000.0, 10_500.0, 11_000.0, 10_800.0, 12_345.67],
      trades: [],
      seconds: 0.123
    }

    lines = Report.render(metrics, result, dataset, color: false)

    assert length(lines) <= 25
    assert Enum.all?(lines, fn line -> String.length(visible(line)) <= 80 end)
    assert Enum.any?(lines, &String.contains?(&1, "Sim time 0.123 s"))
  end
end
