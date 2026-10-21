defmodule Langtest.Test.Fixtures do
  @moduledoc "Builds synthetic markets for the unit tests."

  alias Langtest.Data.Loader
  alias Langtest.Domain.{CoinGrid, CoinSeries, Market}
  alias Langtest.Indicator.Rsi

  # Builds a synthetic market from compact bar lists so the tests need no files on disk.
  def market_of(specs) do
    histories =
      Enum.map(specs, fn spec ->
        %{
          symbol: spec.symbol,
          timestamps: Enum.map(spec.bars, fn [timestamp, _close] -> timestamp end),
          closes: Enum.map(spec.bars, fn [_timestamp, close] -> close end)
        }
      end)

    timeline = Loader.build_timeline(histories)
    %Market{timeline: timeline, coins: Loader.align(timeline, histories)}
  end

  # Exposes the timeline builder for tests.
  def build_timeline(histories), do: Loader.build_timeline(histories)

  # A strategy stub that replays scripted signals so simulator rules can be tested in isolation.
  defmodule ScriptedStrategy do
    @moduledoc "A strategy stub that replays scripted signals so simulator rules can be tested in isolation."

    use Langtest.Strategy

    alias Langtest.Domain.SignalSeries

    # The scripted signals for every coin.
    defstruct [:script]

    # Builds a strategy that replays the given script.
    def new(script), do: %__MODULE__{script: script}

    # Names the strategy for the report header.
    def name(%__MODULE__{}), do: "script"

    # Replays the scripted signals of one coin.
    def evaluate(%__MODULE__{} = strategy, %{symbol: symbol}) do
      entry = strategy.script[symbol] || %{signal: [], strength: []}
      signals = Map.get(entry, :signal, [])
      strengths = Map.get(entry, :strength) || List.duplicate(0.0, length(signals))
      %SignalSeries{signal: signals, strength: strengths}
    end
  end

  # Builds the Wilder RSI fixture values that the tests expect.
  def wilder_rsi_fixture do
    closes = [
      44.34,
      44.09,
      44.15,
      43.61,
      44.33,
      44.83,
      45.1,
      45.42,
      45.84,
      46.08,
      45.89,
      46.03,
      45.61,
      46.28,
      46.28,
      46.0,
      46.03,
      46.41,
      46.22,
      45.64,
      46.21,
      46.25,
      45.71,
      46.45,
      45.78,
      45.35,
      44.03,
      44.18,
      44.22,
      44.57,
      43.42,
      42.66,
      43.13
    ]

    expected = [
      70.46,
      66.25,
      66.48,
      69.35,
      66.29,
      57.92,
      62.88,
      63.21,
      56.01,
      62.34,
      54.67,
      50.39,
      40.02,
      41.49,
      41.9,
      45.5,
      37.32,
      33.09,
      37.79
    ]

    {closes, expected}
  end
end
