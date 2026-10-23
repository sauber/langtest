# Verifies Sharpe, win/loss, average gain, and holding-time calculations.
defmodule Langtest.MetricsTest do
  use ExUnit.Case, async: true

  alias Langtest.{Dataset, Metrics}
  alias Langtest.Simulator.{Result, Trade}

  # Builds a minimal dataset whose only relevant field is the final index value.
  defp dataset(index_final) do
    %Dataset{
      steps: 5,
      index: {10_000.0, index_final},
      closes: {{0.0}},
      signals: {{0}},
      best_buys: {nil}
    }
  end

  # A hand-computed trade sequence exercises every metric.
  test "computes metrics for a hand-computed trade sequence" do
    result = %Result{
      final_equity: 104.0,
      equity: [100.0, 101.0, 103.0, 102.5, 104.0],
      trades: [
        %Trade{buy_step: 0, sell_step: 4, cost: 1000.0, proceeds: 1100.0},
        %Trade{buy_step: 10, sell_step: 13, cost: 2000.0, proceeds: 1900.0}
      ],
      seconds: 0.1
    }

    metrics = Metrics.compute(result, dataset(100.0))

    assert metrics.ratio == 1.04
    assert_in_delta metrics.sharpe, 87.23382793453264, 0.0000001
    assert metrics.win_loss == 1.0
    assert_in_delta metrics.avg_gain, 0.025, 0.0000001
    assert metrics.avg_holding == 3.5
    assert metrics.wins == 1
    assert metrics.losses == 1
    assert metrics.trades == 2
  end

  # Zero-return trades do not count as wins or losses.
  test "excludes zero-return trades from win and loss counts" do
    result = %Result{
      final_equity: 110.0,
      equity: [100.0, 110.0],
      trades: [
        %Trade{buy_step: 0, sell_step: 2, cost: 100.0, proceeds: 100.0},
        %Trade{buy_step: 0, sell_step: 2, cost: 100.0, proceeds: 120.0}
      ],
      seconds: 0.0
    }

    metrics = Metrics.compute(result, dataset(100.0))

    assert metrics.wins == 1
    assert metrics.losses == 0
    assert metrics.win_loss == :infinity
    assert_in_delta metrics.avg_gain, 0.1, 0.0000001
  end

  # A constant equity series has zero variance and therefore no Sharpe ratio.
  test "returns nil Sharpe when standard deviation is zero" do
    assert Metrics.sharpe([100.0, 100.0, 100.0]) == nil
  end

  # No trades yields not-available values rather than division by zero.
  test "handles an empty trade list" do
    result = %Result{final_equity: 100.0, equity: [100.0], trades: [], seconds: 0.0}
    metrics = Metrics.compute(result, dataset(100.0))

    assert metrics.win_loss == :infinity
    assert metrics.avg_gain == nil
    assert metrics.avg_holding == nil
    assert metrics.sharpe == nil
  end
end
