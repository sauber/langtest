defmodule Langtest do
  @moduledoc "Runs the trading strategy evaluator from the command line or from tests."

  alias Langtest.Metrics.Index
  alias Langtest.Report
  alias Langtest.Sim.Simulator
  alias Langtest.Strategy.Rsi

  @default_data_dir Path.expand("../../../data", __DIR__)

  # Runs the evaluation against the given data directory and returns the report lines.
  def run(data_dir \\ nil) do
    data_dir = data_dir || resolve_data_dir()
    {:ok, market} = Langtest.Data.Loader.load_market(data_dir)
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

  # Resolves the data directory, falling back to the repository's default data directory.
  defp resolve_data_dir do
    if File.dir?(@default_data_dir) do
      @default_data_dir
    else
      Path.expand("../data", File.cwd!())
    end
  end
end
