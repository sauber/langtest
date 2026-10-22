-- Wilder's relative strength index computed on closing prices.

module Rsi exposing (period, rsi, rsiSeries)

-- The number of price changes the index is built from.
period : Int
period =
    14

-- Computes the RSI of every close; the first value appears after fourteen price changes.
rsiSeries : List Float -> List (Maybe Float)
rsiSeries closes =
    case seedOf (priceChanges closes) of
        Nothing ->
            List.map (\_ -> Nothing) closes

        Just ( remaining, averageGain, averageLoss ) ->
            List.append
                (List.repeat period Nothing)
                (Just (rsi averageGain averageLoss) :: smoothedOf remaining averageGain averageLoss [])

-- Splits the seed of the index from the price changes that follow it.
seedOf : List Float -> Maybe ( List Float, Float, Float )
seedOf changes =
    case changes of
        [] ->
            Nothing

        _ ->
            let
                ( seed, remaining ) = splitAt period changes
            in
            if List.length seed < period then
                Nothing

            else
                let
                    gains = List.map (\change -> max 0 change) seed
                    losses = List.map (\change -> max 0 (-change)) seed
                in
                Just
                    ( remaining
                    , List.sum gains / toFloat period
                    , List.sum losses / toFloat period
                    )

-- Splits a list at the given position.
splitAt : Int -> List a -> ( List a, List a )
splitAt position values =
    ( List.take position values, List.drop position values )

-- Turns a close series into the series of its consecutive price changes.
priceChanges : List Float -> List Float
priceChanges closes =
    changesOf closes Nothing []

-- Collects the consecutive price changes into an accumulator.
changesOf : List Float -> Maybe Float -> List Float -> List Float
changesOf closes previous collected =
    case closes of
        [] ->
            List.reverse collected

        close :: rest ->
            case previous of
                Just value ->
                    changesOf rest (Just close) ((close - value) :: collected)

                Nothing ->
                    changesOf rest (Just close) collected

-- Collects the smoothed index values into an accumulator.
smoothedOf : List Float -> Float -> Float -> List (Maybe Float) -> List (Maybe Float)
smoothedOf changes averageGain averageLoss collected =
    case changes of
        [] ->
            List.reverse collected

        change :: rest ->
            let
                gain = max 0 change
                loss = max 0 (-change)
                nextGain = (averageGain * (toFloat period - 1) + gain) / toFloat period
                nextLoss = (averageLoss * (toFloat period - 1) + loss) / toFloat period
            in
            smoothedOf rest nextGain nextLoss (Just (rsi nextGain nextLoss) :: collected)

-- Converts a smoothed average gain and loss into an RSI value.
rsi : Float -> Float -> Float
rsi averageGain averageLoss =
    if averageLoss == 0 then
        100

    else if averageGain == 0 then
        0

    else
        100 - (100 / (1 + averageGain / averageLoss))
