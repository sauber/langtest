# Command-line entry point for loading data, simulating, and printing results.
defmodule Langtest.CLI do
  alias Langtest.{MarketData, Metrics, Report, Simulator, Strategy}

  # Parses options, runs the evaluation, and prints the report.
  def main(args) do
    {options, _positional, _invalid} =
      OptionParser.parse(args, strict: [data: :string], aliases: [d: :data])

    data_dir = options[:data] || find_data_dir()
    dataset = MarketData.load!(data_dir, Strategy.RSI)
    result = Simulator.run(dataset)
    metrics = Metrics.compute(result, dataset)

    Report.render(metrics, result, dataset)
    |> Enum.each(&IO.puts/1)
  end

  # Finds the data directory when run from the repo root or from elixir/.
  defp find_data_dir do
    candidates = ["data", Path.join("..", "data")]

    case Enum.find(candidates, fn dir -> File.exists?(Path.join(dir, "meta.json")) end) do
      nil -> raise ArgumentError, "could not find data/meta.json; pass --data PATH"
      dir -> dir
    end
  end
end
