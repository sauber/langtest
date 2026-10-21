defmodule Langtest.CLI do
  @moduledoc "The escript entry point for the evaluator."

  # Runs the evaluation and prints the report to the terminal.
  def main(args) do
    data_dir = parse_args(args)
    Langtest.run(data_dir) |> Enum.each(fn line -> IO.binwrite([line, "\n"]) end)
  end

  # Extracts the data directory from the command line flags.
  defp parse_args(args) do
    args
    |> Enum.find(&String.starts_with?(&1, "--data="))
    |> case do
      nil -> nil
      flag -> String.replace_prefix(flag, "--data=", "")
    end
  end
end
