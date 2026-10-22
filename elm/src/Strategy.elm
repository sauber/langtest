-- The trading strategy of the evaluator; the simulator takes a strategy as its input.

module Strategy exposing (Applied, Strategy, apply, rsiStrategy, signalOfRsi)

import Domain exposing (Market, Signal(..))
import Rsi exposing (rsiSeries)

-- A strategy turns the close prices of a coin into one signal per bar.
type alias Strategy =
    { name : String
    , signals : List Float -> List Signal
    }

-- A strategy that was applied to the coins of a market.
type alias Applied =
    { name : String
    , signalsOf : List ( String, List Signal )
    }

-- The RSI strategy: buy when the index is at most 30, sell when it is at least 70.
rsiStrategy : Strategy
rsiStrategy =
    { name = "RSI(14)"
    , signals =
        \closes ->
            closes
                |> rsiSeries
                |> List.map signalOfRsi
    }

-- Applies a strategy to every coin of a market.
apply : Strategy -> Market -> Applied
apply strategy market =
    { name = strategy.name
    , signalsOf =
        List.map
            (\coin -> ( coin.symbol, strategy.signals (List.map .close coin.bars) ))
            market.coins
    }

-- Maps an index value to a trading signal; the buy strength is 30 minus the index.
signalOfRsi : Maybe Float -> Signal
signalOfRsi maybeRsi =
    case maybeRsi of
        Nothing ->
            NoSignal

        Just value ->
            if value <= 30 then
                Buy (30 - value)

            else if value >= 70 then
                Sell

            else
                NoSignal
