# Mix task wrapper for running the evaluation with `mix langtest`.
defmodule Mix.Tasks.Langtest do
  use Mix.Task

  @shortdoc "Runs the trading strategy evaluation"
  @moduledoc "Runs the Elixir trading strategy evaluation. Pass `--data PATH` to override the data directory."

  # Starts the application and delegates to the CLI entry point.
  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    Langtest.CLI.main(args)
  end
end
