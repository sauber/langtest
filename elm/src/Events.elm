-- The candles of the market with their signals, ordered by the steps of the timeline.

module Events exposing (events)

import Domain exposing (Bar, Coin, Event, Market, Signal(..))
import Strategy exposing (Applied)

-- A coin of the market and the candles it still has to report.
type alias Cursor =
    { symbol : String
    , bars : List Bar
    , signals : List Signal
    }

-- Collects the events of every coin of the market, ordered by step.
events : Applied -> Market -> List Event
events applied market =
    let
        cursors = List.map (makeCursor applied) market.coins
        steps = List.length market.steps
    in
    collect steps 0 cursors []

-- Prepares the cursor of one coin of the market.
makeCursor : Applied -> Coin -> Cursor
makeCursor applied coin =
    { symbol = coin.symbol
    , bars = coin.bars
    , signals = signalsOf applied coin.symbol
    }

-- Finds the signals of one coin in the applied strategy.
signalsOf : Applied -> String -> List Signal
signalsOf applied symbol =
    case List.filter (\( name, _ ) -> name == symbol) applied.signalsOf of
        ( _, values ) :: _ ->
            values

        [] ->
            []

-- Collects the events of every step of the timeline.
collect : Int -> Int -> List Cursor -> List Event -> List Event
collect steps step cursors collected =
    if step >= steps then
        List.reverse collected

    else
        let
            ( reported, advanced ) = stepEvents step cursors
        in
        collect steps (step + 1) advanced (List.foldl (\event acc -> event :: acc) collected reported)

-- Collects the events the coins report at the given step.
stepEvents : Int -> List Cursor -> ( List Event, List Cursor )
stepEvents step cursors =
    case cursors of
        [] ->
            ( [], [] )

        cursor :: others ->
            case cursor.bars of
                bar :: remainingBars ->
                    if bar.step == step then
                        let
                            ( reported, advanced ) = stepEvents step others
                        in
                        ( Event bar.step cursor.symbol bar.close (headSignal cursor.signals) :: reported
                        , advanceCursor cursor remainingBars :: advanced
                        )

                    else
                        let
                            ( reported, advanced ) = stepEvents step others
                        in
                        ( reported, cursor :: advanced )

                [] ->
                    let
                        ( reported, advanced ) = stepEvents step others
                    in
                    ( reported, cursor :: advanced )

-- Advances a cursor past the candle it reported.
advanceCursor : Cursor -> List Bar -> Cursor
advanceCursor cursor remainingBars =
    { cursor | bars = remainingBars, signals = tailSignals cursor.signals }

-- Reads the signal of the candle a coin reports.
headSignal : List Signal -> Signal
headSignal signals =
    case signals of
        signal :: _ ->
            signal

        [] ->
            NoSignal

-- Drops the signal of the candle a coin reported.
tailSignals : List Signal -> List Signal
tailSignals signals =
    case signals of
        _ :: rest ->
            rest

        [] ->
            []
