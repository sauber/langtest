module Metrics exposing (Metrics, WinLoss(..), averageGain, averageHold, sharpe, summarize, winLoss)

import Domain exposing (Trade)

{-| Performance statistics derived from the simulation output.
-}


-- Win/loss ratio states: a number, no losses, or no closed trades
type WinLoss
    = Ratio Float
    | Infinite
    | NoTrades


-- All five reported metrics plus the raw final values
type alias Metrics =
    { finalEquity : Float
    , marketFinal : Float
    , beatMarket : Float
    , sharpe : Maybe Float
    , wins : Int
    , losses : Int
    , winLoss : WinLoss
    , avgGain : Maybe Float
    , avgHold : Maybe Float
    }


-- Hourly simple returns between consecutive account values
returns : List Float -> List Float
returns values =
    case values of
        [] ->
            []

        _ :: rest ->
            List.map2 (\previous current -> current / previous - 1) values rest


-- Annualised Sharpe ratio using the sample standard deviation
sharpe : List Float -> Maybe Float
sharpe values =
    let
        hourly =
            returns values

        count =
            List.length hourly
    in
    if count < 2 then
        Nothing

    else
        let
            mean =
                List.sum hourly / toFloat count

            variance =
                List.sum (List.map (\value -> (value - mean) ^ 2) hourly) / toFloat (count - 1)

            deviation =
                sqrt variance
        in
        if deviation == 0 then
            Nothing

        else
            Just (mean / deviation * sqrt 8760)


-- Number of trades with a strictly positive net return
countWins : List Trade -> Int
countWins trades =
    List.length (List.filter (\trade -> trade.netReturn > 0) trades)


-- Number of trades with a strictly negative net return
countLosses : List Trade -> Int
countLosses trades =
    List.length (List.filter (\trade -> trade.netReturn < 0) trades)


-- Wins divided by losses, with zero-return trades already excluded
winLoss : List Trade -> WinLoss
winLoss trades =
    if List.isEmpty trades then
        NoTrades

    else
        let
            wins =
                countWins trades

            losses =
                countLosses trades
        in
        if losses == 0 then
            Infinite

        else
            Ratio (toFloat wins / toFloat losses)


-- Mean net return across every closed trade
averageGain : List Trade -> Maybe Float
averageGain trades =
    if List.isEmpty trades then
        Nothing

    else
        Just (List.sum (List.map .netReturn trades) / toFloat (List.length trades))


-- Mean holding time in simulation steps across every closed trade
averageHold : List Trade -> Maybe Float
averageHold trades =
    if List.isEmpty trades then
        Nothing

    else
        Just (toFloat (List.sum (List.map .holdingSteps trades)) / toFloat (List.length trades))


-- Last value of a non-empty series, or zero
lastValue : List Float -> Float
lastValue values =
    List.foldl (\value _ -> value) 0 values


-- Combine all statistics for the report
summarize : List Float -> Float -> List Trade -> Metrics
summarize equities marketFinal trades =
    let
        finalEquity =
            lastValue equities
    in
    { finalEquity = finalEquity
    , marketFinal = marketFinal
    , beatMarket =
        if marketFinal == 0 then
            0

        else
            finalEquity / marketFinal
    , sharpe = sharpe equities
    , wins = countWins trades
    , losses = countLosses trades
    , winLoss = winLoss trades
    , avgGain = averageGain trades
    , avgHold = averageHold trades
    }
