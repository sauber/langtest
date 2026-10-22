-- The tests of the hourly simulator.

module SimulatorTest exposing (suite)

import Domain exposing (Bar, Config, Event, Market, Signal(..))
import Expect
import Helpers exposing (closeTo, closeToList)
import Simulator exposing (Simulation, simulate)
import Test exposing (Test, describe, test)

-- The trading account of the tests.
config : Config
config =
    { initialCapital = 10000
    , feeRate = 0.001
    , indexBudget = 10000
    , indexWeight = 20
    }

-- Builds a market of one coin with the given timeline and candles.
market : List Int -> List ( Int, Float ) -> Market
market steps candles =
    { steps = steps
    , coins = [ { symbol = "AAA", bars = List.map toBar candles } ]
    }

-- Turns a step and a close price into a candle.
toBar : ( Int, Float ) -> Bar
toBar ( step, close ) =
    { timestamp = step
    , step = step
    , close = close
    }

-- Builds the event of a coin at a step of the timeline.
event : Int -> String -> Float -> Signal -> Event
event step symbol close signal =
    { step = step
    , symbol = symbol
    , close = close
    , signal = signal
    }

-- Runs a simulation of one coin with the given timeline, candles and events.
run : List Int -> List ( Int, Float ) -> List Event -> Simulation
run steps candles events =
    simulate config (market steps candles) events

-- The tests of the hourly simulator.
suite : Test
suite =
    describe "the hourly simulator"
        [ test "the fees are paid on the buy and on the sell" <|
            \_ ->
                run [ 0, 1 ]
                    [ ( 0, 100 ), ( 1, 110 ) ]
                    [ event 0 "AAA" 100 (Buy 5)
                    , event 1 "AAA" 110 Sell
                    ]
                    |> .equity
                    |> closeToList [ 9990.00999000999, 10978.021978021978 ]

        , test "a closed trade books its net return and its holding time" <|
            \_ ->
                let
                    simulation =
                        run [ 0, 1 ]
                            [ ( 0, 100 ), ( 1, 110 ) ]
                            [ event 0 "AAA" 100 (Buy 5)
                            , event 1 "AAA" 110 Sell
                            ]
                in
                case simulation.trades of
                    [ trade ] ->
                        Expect.all
                            [ \booked -> Expect.equal "AAA" booked.symbol
                            , \booked -> Expect.equal 1 booked.holdingSteps
                            , \booked -> closeTo 0.09780219780219768 booked.netReturn
                            ]
                            trade

                    _ ->
                        Expect.fail "the simulation booked exactly one trade"

        , test "the account holds a single coin" <|
            \_ ->
                let
                    simulation =
                        run [ 0, 1, 2 ]
                            [ ( 0, 100 ), ( 1, 100 ), ( 2, 120 ) ]
                            [ event 0 "AAA" 100 (Buy 5)
                            , event 1 "BBB" 50 (Buy 9)
                            , event 2 "AAA" 120 Sell
                            , event 2 "BBB" 50 Sell
                            ]
                in
                Expect.all
                    [ \booked ->
                        closeToList
                            [ 9990.00999000999
                            , 9990.00999000999
                            , 11976.023976023976
                            ]
                            booked.equity
                    , \booked ->
                        case booked.trades of
                            [ trade ] ->
                                Expect.equal "AAA" trade.symbol

                            _ ->
                                Expect.fail "the simulation booked exactly one trade"
                    ]
                    simulation

        , test "the strongest buy signal wins" <|
            \_ ->
                let
                    simulation =
                        run [ 0, 1 ]
                            [ ( 0, 100 ), ( 1, 50 ) ]
                            [ event 0 "AAA" 100 (Buy 3)
                            , event 0 "BBB" 50 (Buy 8)
                            , event 1 "BBB" 50 Sell
                            ]
                in
                case simulation.trades of
                    [ trade ] ->
                        Expect.equal "BBB" trade.symbol

                    _ ->
                        Expect.fail "the simulation booked exactly one trade"

        , test "equal buy strengths are broken alphabetically" <|
            \_ ->
                let
                    simulation =
                        run [ 0, 1 ]
                            [ ( 0, 100 ), ( 1, 100 ) ]
                            [ event 0 "BBB" 200 (Buy 5)
                            , event 0 "AAA" 100 (Buy 5)
                            , event 1 "AAA" 100 Sell
                            ]
                in
                case simulation.trades of
                    [ trade ] ->
                        Expect.equal "AAA" trade.symbol

                    _ ->
                        Expect.fail "the simulation booked exactly one trade"

        , test "a data gap carries the position forward" <|
            \_ ->
                let
                    simulation =
                        run [ 0, 1, 2 ]
                            [ ( 0, 100 ), ( 2, 120 ) ]
                            [ event 0 "AAA" 100 (Buy 5)
                            , event 2 "AAA" 120 Sell
                            ]
                in
                Expect.all
                    [ \booked ->
                        closeToList
                            [ 9990.00999000999
                            , 9990.00999000999
                            , 11976.023976023976
                            ]
                            booked.equity
                    , \booked ->
                        case booked.trades of
                            [ trade ] ->
                                Expect.equal 2 trade.holdingSteps

                            _ ->
                                Expect.fail "the simulation booked exactly one trade"
                    ]
                    simulation

        , test "a sell is followed by a buy inside the same step" <|
            \_ ->
                let
                    simulation =
                        run [ 0, 1 ]
                            [ ( 0, 100 ), ( 1, 110 ) ]
                            [ event 0 "AAA" 100 (Buy 5)
                            , event 1 "AAA" 110 Sell
                            , event 1 "BBB" 50 (Buy 9)
                            ]
                in
                Expect.all
                    [ \booked ->
                        closeToList [ 9990.00999000999, 10967.05492309888 ] booked.equity
                    , \booked ->
                        case booked.trades of
                            [ trade ] ->
                                Expect.equal "AAA" trade.symbol

                            _ ->
                                Expect.fail "the simulation booked exactly one trade"
                    ]
                    simulation

        , test "the account value is recorded for every step" <|
            \_ ->
                run [ 0, 1, 2 ]
                    [ ( 0, 100 ), ( 1, 100 ), ( 2, 100 ) ]
                    [ event 0 "AAA" 100 NoSignal
                    , event 1 "AAA" 100 NoSignal
                    , event 2 "AAA" 100 NoSignal
                    ]
                    |> .equity
                    |> List.length
                    |> Expect.equal 3
        ]
