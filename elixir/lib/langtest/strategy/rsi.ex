defmodule Langtest.Strategy.Rsi do
  @moduledoc "The RSI mean-reversion strategy: buy oversold, sell overbought."

  use Langtest.Strategy

  alias Langtest.Domain.SignalSeries
  alias Langtest.Indicator.Rsi

  @default_period 14
  @default_oversold 30
  @default_overbought 70

  # The parameters of the RSI strategy.
  defstruct [:period, :oversold, :overbought]

  # Builds the RSI mean-reversion strategy.
  def new(options \\ []) do
    %__MODULE__{
      period: Keyword.get(options, :period, @default_period),
      oversold: Keyword.get(options, :oversold, @default_oversold),
      overbought: Keyword.get(options, :overbought, @default_overbought)
    }
  end

  # Names the strategy for the report header.
  def name(%__MODULE__{}), do: "RSI(14)"

  # Turns the closes of one coin into buy, sell and pass signals with their buy strength.
  def evaluate(%__MODULE__{} = strategy, %{closes: closes}) do
    closes
    |> Rsi.wilder_rsi(strategy.period)
    |> build_signals(strategy.oversold, strategy.overbought)
  end

  # Turns the RSI values of one coin into the signal and the buy strength of every bar.
  defp build_signals(rsi, oversold, overbought) do
    {signals, strengths} =
      Enum.reduce(rsi, {[], []}, fn value, {signals, strengths} ->
        cond do
          is_nil(value) -> {[:none | signals], [0.0 | strengths]}
          value <= oversold -> {[:buy | signals], [oversold - value | strengths]}
          value >= overbought -> {[:sell | signals], [0.0 | strengths]}
          true -> {[:pass | signals], [0.0 | strengths]}
        end
      end)

    %SignalSeries{signal: Enum.reverse(signals), strength: Enum.reverse(strengths)}
  end
end
