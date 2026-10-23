module Rsi exposing (State, initial, period, series, step)

{-| 14-period Relative Strength Index using Wilder's smoothing.
-}


-- Canonical RSI lookback used by the strategy
period : Int
period =
    14


-- Wilder's running averages for one coin
type alias State =
    { previous : Float
    , changes : Int
    , avgGain : Float
    , avgLoss : Float
    }


-- RSI level for one average gain and average loss pair
level : Float -> Float -> Float
level avgGain avgLoss =
    if avgLoss == 0 then
        100

    else
        100 - 100 / (1 + avgGain / avgLoss)


-- Start smoothing after the first available close
initial : Float -> State
initial close =
    { previous = close
    , changes = 0
    , avgGain = 0
    , avgLoss = 0
    }


-- Fold one close into the averages, returning the next state and optional RSI
step : Int -> Float -> State -> ( State, Maybe Float )
step lookback close state =
    let
        change =
            close - state.previous

        gain =
            if change > 0 then change else 0

        loss =
            if change < 0 then -change else 0

        changes =
            state.changes + 1

        avgGain =
            if changes <= lookback then
                state.avgGain + gain / toFloat lookback

            else
                (state.avgGain * toFloat (lookback - 1) + gain) / toFloat lookback

        avgLoss =
            if changes <= lookback then
                state.avgLoss + loss / toFloat lookback

            else
                (state.avgLoss * toFloat (lookback - 1) + loss) / toFloat lookback

        value =
            if changes >= lookback then
                Just (level avgGain avgLoss)

            else
                Nothing
    in
    ( { previous = close
      , changes = changes
      , avgGain = avgGain
      , avgLoss = avgLoss
      }
    , value
    )


-- RSI series aligned with closes: Nothing until the first full lookback
series : Int -> List Float -> List (Maybe Float)
series lookback closes =
    case closes of
        [] ->
            []

        first :: rest ->
            let
                ( _, reversed ) =
                    List.foldl
                        (\close ( state, acc ) ->
                            let
                                ( next, value ) =
                                    step lookback close state
                            in
                            ( next, value :: acc )
                        )
                        ( initial first, [ Nothing ] )
                        rest
            in
            List.reverse reversed
