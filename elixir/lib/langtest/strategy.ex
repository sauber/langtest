defmodule Langtest.Strategy do
  @moduledoc "The contract every trading strategy implements for the simulator."

  alias Langtest.Domain.{CoinSeries, SignalSeries}

  @doc "The display name of the strategy."
  @callback name(strategy :: struct()) :: String.t()

  @doc "Turns the price history of one coin into its per-bar signals."
  @callback evaluate(strategy :: struct(), coin :: CoinSeries.t()) :: SignalSeries.t()

  # Injects the strategy behaviour and a default display name into the using module.
  defmacro __using__(_options) do
    quote do
      @behaviour Langtest.Strategy

      # Names the strategy for the report header.
      def name(_strategy), do: "strategy"

      defoverridable name: 1
    end
  end
end
