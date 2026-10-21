defmodule Langtest.Domain do
  @moduledoc "Shared data types of the trading strategy evaluator."

  # The trading signals a strategy can emit for a single bar.
  defmodule Signal do
    @moduledoc "The trading signals a strategy can emit for a single bar."

    @type t :: :none | :pass | :buy | :sell
  end

  # One raw market bar reduced to the fields the strategy and simulator need.
  defmodule Bar do
    @moduledoc "One raw market bar reduced to the fields the strategy and simulator need."

    # The fields of one raw market bar.
    @enforce_keys [:timestamp, :close]
    defstruct [:timestamp, :close]

    @type t :: %__MODULE__{timestamp: integer(), close: float()}
  end

  # The price grid of one coin aligned to the shared simulation timeline.
  defmodule CoinGrid do
    @moduledoc "The price grid of one coin aligned to the shared simulation timeline."

    # The fields of one timeline aligned price grid.
    @enforce_keys [:close, :last_close, :bar_steps]
    defstruct [:close, :last_close, :bar_steps]

    @type t :: %__MODULE__{close: tuple(), last_close: tuple(), bar_steps: tuple()}
  end

  # One coin's close prices together with its timeline aligned price grid.
  defmodule CoinSeries do
    @moduledoc "One coin's close prices together with its timeline aligned price grid."

    # The fields of one coin series.
    @enforce_keys [:symbol, :closes]
    defstruct [:symbol, :closes, :grid]

    @type t :: %__MODULE__{symbol: String.t(), closes: [float()], grid: CoinGrid.t()}
  end

  # The shared market: one simulation timeline and every aligned coin.
  defmodule Market do
    @moduledoc "The shared market: one simulation timeline and every aligned coin."

    # The fields of the shared market.
    @enforce_keys [:timeline, :coins]
    defstruct [:timeline, :coins]

    @type t :: %__MODULE__{timeline: [integer()], coins: [CoinSeries.t()]}
  end

  # The single open position of the portfolio.
  defmodule Position do
    @moduledoc "The single open position of the portfolio."

    # The fields of one open position.
    @enforce_keys [:symbol, :coin_index, :quantity, :cost_basis, :entry_step]
    defstruct [:symbol, :coin_index, :quantity, :cost_basis, :entry_step]

    @type t :: %__MODULE__{
            symbol: String.t(),
            coin_index: non_neg_integer(),
            quantity: float(),
            cost_basis: float(),
            entry_step: non_neg_integer()
          }
  end

  # One closed trade with its net return.
  defmodule Trade do
    @moduledoc "One closed trade with its net return."

    # The fields of one closed trade.
    @enforce_keys [:symbol, :entry_step, :exit_step, :quantity, :cost_basis, :proceeds, :net_return]
    defstruct [:symbol, :entry_step, :exit_step, :quantity, :cost_basis, :proceeds, :net_return]

    @type t :: %__MODULE__{
            symbol: String.t(),
            entry_step: non_neg_integer(),
            exit_step: non_neg_integer(),
            quantity: float(),
            cost_basis: float(),
            proceeds: float(),
            net_return: float()
          }
  end

  # The per-bar signals a strategy derives from one coin's price history.
  defmodule SignalSeries do
    @moduledoc "The per-bar signals a strategy derives from one coin's price history."

    # The fields of one signal series.
    @enforce_keys [:signal, :strength]
    defstruct [:signal, :strength]

    @type t :: %__MODULE__{signal: [Signal.t()], strength: [float()]}
  end

  # The outcome of one simulation run.
  defmodule SimulationResult do
    @moduledoc "The outcome of one simulation run."

    # The fields of one simulation result.
    @enforce_keys [:equity, :trades, :final_equity, :sim_seconds]
    defstruct [:equity, :trades, :final_equity, :sim_seconds]

    @type t :: %__MODULE__{
            equity: [float()],
            trades: [Trade.t()],
            final_equity: float(),
            sim_seconds: float()
          }
  end
end
