defmodule Langtest.MixProject do
  use Mix.Project

  # Project configuration for the Langtest Elixir evaluation.
  def project do
    [
      app: :langtest,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Langtest.CLI, name: "langtest"],
      deps: []
    ]
  end

  # Runtime applications required by the project (none beyond Erlang/Elixir).
  def application do
    [extra_applications: []]
  end
end
