defmodule Langtest.Sim.Simulator do
  @moduledoc "Steps the market hour by hour and applies the strategy's signals to a single position."

  alias Langtest.Domain.SimulationResult
  alias Langtest.Sim.Portfolio

  @default_initial_cash 10_000
  @default_fee_rate 0.001

  # The state of one simulator.
  defstruct [:market, :strategy, :initial_cash, :fee_rate, :signals, :strengths]

  # Prepares the simulator by evaluating the strategy for every coin of the market.
  def new(market, strategy, options \\ []) do
    steps = length(market.timeline)
    {signals, strengths} = signal_tables(market, strategy, steps)

    %__MODULE__{
      market: market,
      strategy: strategy,
      initial_cash: Keyword.get(options, :initial_cash, @default_initial_cash),
      fee_rate: Keyword.get(options, :fee_rate, @default_fee_rate),
      signals: signals,
      strengths: strengths
    }
  end

  # Runs the hourly stepping loop and returns the equity curve with the closed trades.
  def run(%__MODULE__{} = simulator) do
    market = simulator.market
    steps = length(market.timeline)
    symbols = market.coins |> Enum.map(& &1.symbol) |> List.to_tuple()
    closes = market.coins |> Enum.map(& &1.grid.close) |> List.to_tuple()
    last_closes = market.coins |> Enum.map(& &1.grid.last_close) |> List.to_tuple()
    portfolio = Portfolio.new(simulator.initial_cash, simulator.fee_rate)

    loop = fn loop, step, portfolio, equity ->
      if step >= steps do
        {portfolio, equity}
      else
        portfolio = sell_held(portfolio, step, simulator.signals, closes)

        portfolio =
          buy_free(portfolio, step, simulator.signals, simulator.strengths, closes, symbols)

        value = Portfolio.mark_value(portfolio, last_close_of(portfolio, step, last_closes))
        loop.(loop, step + 1, portfolio, [value | equity])
      end
    end

    started = System.monotonic_time(:microsecond)
    {portfolio, equity} = loop.(loop, 0, portfolio, [])
    elapsed = System.monotonic_time(:microsecond) - started

    equity = Enum.reverse(equity)
    final_equity = if steps > 0, do: List.last(equity), else: simulator.initial_cash

    %SimulationResult{
      equity: equity,
      trades: Enum.reverse(portfolio.trades),
      final_equity: final_equity,
      sim_seconds: elapsed / 1_000_000
    }
  end

  # Evaluates the strategy for every coin and scatters the signals onto the shared timeline.
  defp signal_tables(market, strategy, steps) do
    module = strategy.__struct__

    {signals, strengths} =
      market.coins
      |> Enum.map(fn coin ->
        series = module.evaluate(strategy, coin)
        scatter_signals(Tuple.to_list(coin.grid.bar_steps), series.signal, series.strength, steps)
      end)
      |> Enum.unzip()

    {List.to_tuple(signals), List.to_tuple(strengths)}
  end

  # Scatters the per-bar signals of one coin onto the shared simulation timeline.
  defp scatter_signals(bar_steps, signals, strengths, steps) do
    bars = Enum.zip([bar_steps, signals, strengths])
    {signal, strength, last_step} = scatter(bars, 0, [], [])
    pad = steps - last_step

    signal = Enum.concat(Enum.reverse(signal)) ++ List.duplicate(:none, pad)
    strength = Enum.concat(Enum.reverse(strength)) ++ List.duplicate(0.0, pad)

    {List.to_tuple(signal), List.to_tuple(strength)}
  end

  # Emits the gaps and the signals of one coin in timeline order.
  defp scatter([], last_step, signal, strength) do
    {signal, strength, last_step}
  end

  # Emits the gaps and the signals of one coin in timeline order.
  defp scatter([{step, coin_signal, coin_strength} | rest], previous, signal, strength) do
    gap = step - previous
    signal = [List.duplicate(:none, gap) ++ [coin_signal] | signal]
    strength = [List.duplicate(0.0, gap) ++ [coin_strength] | strength]
    scatter(rest, step + 1, signal, strength)
  end

  # Sells the held coin when it emits a sell signal at the given step.
  defp sell_held(portfolio, step, signals, closes) do
    case portfolio.position do
      nil ->
        portfolio

      position ->
        if elem(elem(signals, position.coin_index), step) == :sell do
          price = elem(elem(closes, position.coin_index), step)
          {portfolio, _trade} = Portfolio.sell(portfolio, price, step)
          portfolio
        else
          portfolio
        end
    end
  end

  # Buys the strongest buy signal of the given step when no coin is held.
  defp buy_free(portfolio, step, signals, strengths, closes, symbols) do
    case portfolio.position do
      nil ->
        case select_buy(step, signals, strengths, symbols) do
          nil ->
            portfolio

          index ->
            price = elem(elem(closes, index), step)
            Portfolio.buy(portfolio, elem(symbols, index), index, price, step)
        end

      _position ->
        portfolio
    end
  end

  # Picks the coin with the strongest buy signal, breaking ties alphabetically.
  defp select_buy(step, signals, strengths, symbols) do
    count = tuple_size(signals)

    if count == 0 do
      nil
    else
      best =
        Enum.reduce(0..(count - 1), nil, fn index, best ->
          if elem(elem(signals, index), step) == :buy do
            strength = elem(elem(strengths, index), step)
            symbol = elem(symbols, index)

            case best do
              nil ->
                {index, strength, symbol}

              {_index, best_strength, best_symbol} ->
                if strength > best_strength or (strength == best_strength and symbol < best_symbol) do
                  {index, strength, symbol}
                else
                  best
                end
            end
          else
            best
          end
        end)

      case best do
        nil -> nil
        {index, _strength, _symbol} -> index
      end
    end
  end

  # Reads the last known close of the held coin at the given step.
  defp last_close_of(portfolio, step, last_closes) do
    case portfolio.position do
      nil ->
        0.0

      position ->
        case elem(elem(last_closes, position.coin_index), step) do
          nil -> 0.0
          last_close -> last_close
        end
    end
  end
end
