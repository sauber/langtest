defmodule Langtest.MixProject do
  use Mix.Project

  # Describes the project, its escript entry point and its test paths.
  def project do
    [
      app: :langtest,
      version: "1.0.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Declares the applications the escript needs at runtime.
  def application do
    [extra_applications: [:logger]]
  end

  # Configures the escript so the evaluator can run as a single executable.
  defp escript do
    [
      main_module: Langtest.CLI,
      app: :langtest,
      name: "langtest"
    ]
  end

  # Compiles the test support files only in the test environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_environment), do: ["lib"]

  # The project has no external dependencies.
  defp deps, do: []
end
