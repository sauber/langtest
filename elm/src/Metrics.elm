-- The performance metrics of a finished simulation.

module Metrics exposing
    ( Metrics
    , averageGain
    , averageHolding
    , compute
    , hourlyReturns
    , mean
    , sampleStdDev
    , sharpe
    , winLossRatio
    , wins
    , losses
    )

import Domain exposing (Ratio(..), Trade)
import Index exposing (Index)
import Simulator exposing (Simulation)

-- The five performance metrics of the simulation.
type alias Metrics =
    { equityIndexRatio : Float
    , sharpe : Maybe Float
    , winLoss : Ratio
    , wins : Int
    , losses : Int
    , tradeCount : Int
    , averageGain : Float
    , averageHolding : Float
    }

-- Computes the performance metrics of a finished simulation.
compute : Simulation -> Index -> Metrics
compute simulation index =
    { equityIndexRatio = simulation.finalEquity / index.final
    , sharpe = sharpe (hourlyReturns simulation.equity)
    , winLoss = winLossRatio simulation.trades
    , wins = wins simulation.trades
    , losses = losses simulation.trades
    , tradeCount = List.length simulation.trades
    , averageGain = averageGain simulation.trades
    , averageHolding = averageHolding simulation.trades
    }

-- Computes the simple hourly returns of an equity curve.
hourlyReturns : List Float -> List Float
hourlyReturns values =
    case values of
        [] ->
            []

        first :: rest ->
            returnsOf rest first []

-- Collects the hourly returns of a curve into an accumulator.
returnsOf : List Float -> Float -> List Float -> List Float
returnsOf values previous collected =
    case values of
        [] ->
            List.reverse collected

        value :: rest ->
            returnsOf rest value ((value / previous - 1) :: collected)

-- Computes the annualised Sharpe ratio of the hourly equity returns.
sharpe : List Float -> Maybe Float
sharpe returns =
    let
        deviation = sampleStdDev returns
    in
    if deviation == 0 then
        Nothing

    else
        Just (mean returns / deviation * sqrt 8760)

-- Computes the arithmetic mean of a list of numbers.
mean : List Float -> Float
mean values =
    case values of
        [] ->
            0

        _ ->
            List.sum values / toFloat (List.length values)

-- Computes the sample standard deviation of a list of numbers.
sampleStdDev : List Float -> Float
sampleStdDev values =
    case values of
        [] ->
            0

        [ _ ] ->
            0

        _ ->
            let
                average = mean values
                count = toFloat (List.length values)
                squared =
                    List.map
                        (\value ->
                            let
                                difference = value - average
                            in
                            difference * difference
                        )
                        values
            in
            sqrt (List.sum squared / (count - 1))

-- Counts the trades that closed with a profit.
wins : List Trade -> Int
wins trades =
    List.length (List.filter (\trade -> trade.netReturn > 0) trades)

-- Counts the trades that closed with a loss.
losses : List Trade -> Int
losses trades =
    List.length (List.filter (\trade -> trade.netReturn < 0) trades)

-- Computes the ratio of the winning trades to the losing trades.
winLossRatio : List Trade -> Ratio
winLossRatio trades =
    let
        losing = losses trades
    in
    if losing == 0 then
        Infinite

    else
        Finite (toFloat (wins trades) / toFloat losing)

-- Computes the mean net return of all closed trades.
averageGain : List Trade -> Float
averageGain trades =
    case trades of
        [] ->
            0

        _ ->
            mean (List.map .netReturn trades)

-- Computes the mean holding time of all closed trades in steps.
averageHolding : List Trade -> Float
averageHolding trades =
    case trades of
        [] ->
            0

        _ ->
            mean (List.map (\trade -> toFloat trade.holdingSteps) trades)
