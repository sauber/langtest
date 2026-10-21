defmodule Langtest.StatsTest do
  use ExUnit.Case, async: true

  alias Langtest.Metrics.Stats

  # Builds a synthetic closed trade for the metric tests.
  defp trade(net_return, entry_step \\ 0, exit_step \\ 1) do
    %Langtest.Domain.Trade{
      symbol: "AAA-USDT",
      entry_step: entry_step,
      exit_step: exit_step,
      quantity: 1.0,
      cost_basis: 100.0,
      proceeds: 100.0 * (1 + net_return),
      net_return: net_return
    }
  end

  # A symmetric return series has a Sharpe ratio of zero.
  test "sharpe ratio is zero for symmetric hourly returns" do
    sharpe = Stats.sharpe_ratio([100, 110, 99])
    assert_in_delta(sharpe, 0, 1.0e-12)
  end

  # A constant return series has no variation and Sharpe is undefined.
  test "sharpe ratio is undefined when the returns do not vary" do
    assert Stats.sharpe_ratio([100, 110, 121]) == nil
  end

  # Sharpe needs at least two returns.
  test "sharpe ratio needs at least two returns" do
    assert Stats.sharpe_ratio([100]) == nil
  end

  # A trade with a net return above zero is a win.
  test "a positive net return is counted as a win" do
    summary = Stats.win_loss_ratio([trade(0.1)])
    assert summary.wins == 1
    assert summary.losses == 0
    assert summary.ratio == :infinity
  end

  # A trade with a net return below zero is a loss.
  test "a negative net return is counted as a loss" do
    summary = Stats.win_loss_ratio([trade(-0.1)])
    assert summary.wins == 0
    assert summary.losses == 1
    assert summary.ratio == 0
  end

  # A trade with a net return of zero counts as neither a win nor a loss.
  test "a zero net return counts as neither a win nor a loss" do
    summary = Stats.win_loss_ratio([trade(0.0)])
    assert summary.wins == 0
    assert summary.losses == 0
    assert summary.ratio == :infinity
  end

  # With no losing trades the win/loss ratio is infinity.
  test "the win/loss ratio is infinity when there are no losses" do
    summary = Stats.win_loss_ratio([trade(0.1), trade(0.2)])
    assert summary.ratio == :infinity
  end

  # The average gain is the mean net return across all closed trades.
  test "the average gain is the mean net return across all closed trades" do
    gain = Stats.average_gain([trade(0.1), trade(-0.1)])
    assert_in_delta(gain, 0, 1.0e-12)
  end

  # The average holding time is the mean number of steps between entry and exit.
  test "the average holding time is the mean number of steps between entry and exit" do
    holding = Stats.average_holding_steps([trade(0.1, 0, 10), trade(-0.1, 5, 5)])
    assert_in_delta(holding, 5, 1.0e-12)
  end
end
