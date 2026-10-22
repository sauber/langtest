-- The equal weighted buy and hold market index of the simulation timeline.

module Index exposing (Index, compute)

import Domain exposing (Bar, Coin, Config, Market)

-- The value of the market index over the simulation timeline.
type alias Index =
    { curve : List Float
    , final : Float
    }

-- One coin of the index and the candles it still has to report.
type alias Cursor =
    { bars : List Bar
    , lastClose : Float
    , units : Float
    , started : Bool
    }

-- The running state of the index computation.
type alias State =
    { step : Int
    , value : Float
    , curve : List Float
    , cursors : List Cursor
    }

-- Computes the value of the market index at every step of the timeline.
compute : Config -> Market -> Index
compute config market =
    let
        budget = config.indexBudget / toFloat config.indexWeight
        cursors = List.map makeCursor market.coins
        final = List.foldl (\_ state -> advance budget state) (State 0 0 [] cursors) market.steps
    in
    { curve = List.reverse final.curve
    , final = Maybe.withDefault 0 (List.head final.curve)
    }

-- Prepares the cursor of one coin of the index.
makeCursor : Coin -> Cursor
makeCursor coin =
    { bars = coin.bars
    , lastClose = 0
    , units = 0
    , started = False
    }

-- Adds the changes of the current step to the market index.
advance : Float -> State -> State
advance budget state =
    let
        ( change, cursors ) = report budget state.step state.cursors
        value = state.value + change
    in
    { state
        | step = state.step + 1
        , value = value
        , curve = value :: state.curve
        , cursors = cursors
    }

-- Collects the changes of the coins that report at the given step.
report : Float -> Int -> List Cursor -> ( Float, List Cursor )
report budget step cursors =
    case cursors of
        [] ->
            ( 0, [] )

        cursor :: others ->
            case cursor.bars of
                bar :: remaining ->
                    if bar.step == step then
                        let
                            ( change, advanced ) = report budget step others
                        in
                        ( change + barChange budget cursor bar
                        , advanceCursor budget cursor bar remaining :: advanced
                        )

                    else
                        let
                            ( change, advanced ) = report budget step others
                        in
                        ( change, cursor :: advanced )

                [] ->
                    let
                        ( change, advanced ) = report budget step others
                    in
                    ( change, cursor :: advanced )

-- Reads the change of the market index that one candle of a coin causes.
barChange : Float -> Cursor -> Bar -> Float
barChange budget cursor bar =
    if cursor.started then
        cursor.units * (bar.close - cursor.lastClose)

    else
        budget

-- Advances the cursor of a coin past the candle it reported.
advanceCursor : Float -> Cursor -> Bar -> List Bar -> Cursor
advanceCursor budget cursor bar remaining =
    { cursor
        | bars = remaining
        , lastClose = bar.close
        , units =
            if cursor.started then
                cursor.units

            else
                budget / bar.close
        , started = True
    }
