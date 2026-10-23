module Report exposing (render)

import Chart
import Domain exposing (Simulation)
import Format exposing (fixed)
import Metrics exposing (Metrics, WinLoss(..))

{-| The complete <=80x25 terminal report.
-}


-- Render every metric, the timed loop duration, and the two-series chart
render : Float -> Metrics -> Simulation -> List Float -> String
render seconds metrics simulation indexValues =
    let
        header =
            [ "langtest · Elm — RSI(14) mean reversion"
            , field "strategy" (fixed 2 metrics.finalEquity ++ " USDT")
            , field "market index" (fixed 2 metrics.marketFinal ++ " USDT")
            , field "beat market" (fixed 4 metrics.beatMarket ++ " x")
            , field "sharpe" (maybeFixed 2 metrics.sharpe)
            , field "win / loss" (winLossText metrics)
            , field "avg gain" (maybePercent metrics.avgGain)
            , field "avg hold" (maybeHours metrics.avgHold)
            , field "sim time" (fixed 3 seconds ++ " s")
            , "  " ++ Chart.legend
            ]

        chart =
            Chart.render 64 12 simulation.equities indexValues
    in
    String.join "\n" (header ++ chart)


-- Align a label in the left column
field : String -> String -> String
field label value =
    String.padRight 15 ' ' ("  " ++ label) ++ value


-- Fixed-point number or N/A
maybeFixed : Int -> Maybe Float -> String
maybeFixed decimals maybeValue =
    case maybeValue of
        Just value ->
            fixed decimals value

        Nothing ->
            "N/A"


-- Percentage with two decimals or N/A
maybePercent : Maybe Float -> String
maybePercent maybeValue =
    case maybeValue of
        Just value ->
            fixed 2 (value * 100) ++ " %"

        Nothing ->
            "N/A"


-- Holding time with one decimal or N/A
maybeHours : Maybe Float -> String
maybeHours maybeValue =
    case maybeValue of
        Just value ->
            fixed 1 value ++ " h"

        Nothing ->
            "N/A"


-- Win/loss ratio including the raw win and loss counts
winLossText : Metrics -> String
winLossText metrics =
    let
        counts =
            "  (" ++ String.fromInt metrics.wins ++ "W / " ++ String.fromInt metrics.losses ++ "L)"
    in
    case metrics.winLoss of
        Ratio value ->
            fixed 2 value ++ counts

        Infinite ->
            "inf" ++ counts

        NoTrades ->
            "n/a"
