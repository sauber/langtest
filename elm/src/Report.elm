-- The report that is printed to the terminal.

module Report exposing (render)

import Chart exposing (Chart)
import Domain exposing (Market, Ratio(..))
import Format
import Index exposing (Index)
import Metrics exposing (Metrics)
import Simulator exposing (Simulation)
import Strategy exposing (Applied)
import Time

-- The width of the label column of the metric lines.
labelWidth : Int
labelWidth =
    19

-- Renders the complete report: header, metrics, timing, chart and legend.
render : Applied -> Market -> Simulation -> Index -> Metrics -> Float -> String
render applied market simulation index metrics elapsed =
    String.join "\n"
        (headerLines applied market
            ++ metricLines simulation index metrics elapsed
            ++ Chart.render (chart market simulation index)
        )

-- The chart of the equity curve and the market index.
chart : Market -> Simulation -> Index -> Chart
chart market simulation index =
    { equity = simulation.equity
    , index = index.curve
    , fromLabel = date (firstTimestamp market)
    , toLabel = date (lastTimestamp market)
    }

-- Builds the header line of the report.
headerLines : Applied -> Market -> List String
headerLines applied market =
    [ applied.name
        ++ " · "
        ++ String.fromInt (List.length market.coins)
        ++ " coins · "
        ++ String.fromInt (List.length market.steps)
        ++ " hourly steps · "
        ++ date (firstTimestamp market)
        ++ " → "
        ++ date (lastTimestamp market)
    ]

-- Builds the metric lines of the report.
metricLines : Simulation -> Index -> Metrics -> Float -> List String
metricLines simulation index metrics elapsed =
    [ labeled "equity / index" (equityIndexValue simulation index metrics)
    , labeled "sharpe (hourly)" (sharpeValue metrics.sharpe)
    , labeled "win / loss" (winLossValue metrics)
    , labeled "avg gain / trade" (Format.percent metrics.averageGain)
    , labeled "avg holding time" (Format.fixed 2 metrics.averageHolding ++ " h")
    , "sim time: " ++ Format.fixed 3 elapsed ++ " s"
    ]

-- Builds a metric line with a fixed label width.
labeled : String -> String -> String
labeled label value =
    String.padRight labelWidth ' ' label ++ value

-- Formats the ratio between the final equity and the final market index.
equityIndexValue : Simulation -> Index -> Metrics -> String
equityIndexValue simulation index metrics =
    Format.fixed 4 metrics.equityIndexRatio
        ++ "x  (equity "
        ++ Format.group (String.fromInt (round simulation.finalEquity))
        ++ " · index "
        ++ Format.group (String.fromInt (round index.final))
        ++ ")"

-- Formats the Sharpe ratio of the report.
sharpeValue : Maybe Float -> String
sharpeValue maybeSharpe =
    case maybeSharpe of
        Nothing ->
            "N/A"

        Just value ->
            Format.fixed 4 value

-- Formats the win / loss ratio of the report.
winLossValue : Metrics -> String
winLossValue metrics =
    let
        ratio =
            case metrics.winLoss of
                Infinite ->
                    "inf"

                Finite value ->
                    Format.fixed 4 value
    in
    ratio
        ++ "  ("
        ++ String.fromInt metrics.wins
        ++ " W / "
        ++ String.fromInt metrics.losses
        ++ " L / "
        ++ String.fromInt metrics.tradeCount
        ++ " trades)"

-- Reads the timestamp of the first step of the timeline.
firstTimestamp : Market -> Int
firstTimestamp market =
    Maybe.withDefault 0 (List.head market.steps)

-- Reads the timestamp of the last step of the timeline.
lastTimestamp : Market -> Int
lastTimestamp market =
    Maybe.withDefault 0 (last market.steps)

-- Reads the last value of a list.
last : List a -> Maybe a
last values =
    List.foldl (\value _ -> Just value) Nothing values

-- Formats a Unix timestamp as a UTC date.
date : Int -> String
date timestamp =
    let
        posix = Time.millisToPosix (timestamp * 1000)
        year = Time.toYear Time.utc posix
        month = Time.toMonth Time.utc posix |> monthNumber
        day = Time.toDay Time.utc posix
    in
    String.fromInt year
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt month)
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt day)

-- Converts a month into its number.
monthNumber : Time.Month -> Int
monthNumber month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12
