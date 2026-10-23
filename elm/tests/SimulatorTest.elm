module SimulatorTest exposing (tests)

import Array
import Domain exposing (Signal(..))
import Expect
import Market exposing (Prepared)
import Simulator
import Test exposing (Test, describe, test)

{-| Unit tests for the simulator rules.
-}


coinCount : Int
coinCount =
    2


type alias Fixture =
    { coin : Int
    , close : Float
    , signal : Signal
    , strength : Float
    }


-- Build a prepared structure with explicit bars per step and coin
preparedFrom : List (List Fixture) -> Prepared
preparedFrom steps =
    let
        stepCount =
            List.length steps

        bestCoin =
            List.map bestCoinAt steps
                |> Array.fromList

        bestClose =
            List.map bestCloseAt steps
                |> Array.fromList

        bars =
            List.range 0 (coinCount - 1)
                |> List.map (\coin -> signedColumn coin steps |> Array.fromList)
                |> Array.fromList
    in
    { stepCount = stepCount
    , bestCoin = bestCoin
    , bestClose = bestClose
    , bars = bars
    }


bestAt : List Fixture -> Maybe Fixture
bestAt bars =
    List.filter (\bar -> bar.signal == Buy) bars
        |> List.sortBy (\bar -> ( -bar.strength, bar.coin ))
        |> List.head


bestCoinAt : List Fixture -> Int
bestCoinAt bars =
    case bestAt bars of
        Just bar ->
            bar.coin

        Nothing ->
            -1


bestCloseAt : List Fixture -> Float
bestCloseAt bars =
    case bestAt bars of
        Just bar ->
            bar.close

        Nothing ->
            0


signedColumn : Int -> List (List Fixture) -> List Float
signedColumn coin steps =
    List.map (signedFor coin) steps


signedFor : Int -> List Fixture -> Float
signedFor coin bars =
    case List.filter (\bar -> bar.coin == coin) bars |> List.head of
        Nothing ->
            0

        Just bar ->
            if bar.signal == Sell then
                -bar.close

            else
                bar.close


tests : Test
tests =
    describe "Simulator"
        [ test "applies fees on buy and sell" <|
            \_ ->
                let
                    steps =
                        [ [ { coin = 0, close = 100, signal = Buy, strength = 10 } ]
                        , [ { coin = 0, close = 110, signal = Sell, strength = 0 } ]
                        ]

                    prepared =
                        preparedFrom steps

                    sim =
                        Simulator.run { initialCapital = 10000, feeRate = 0.001 } prepared
                in
                Expect.within (Expect.Absolute 0.01) 10978.02 (Maybe.withDefault 0 (List.head (List.reverse sim.equities)))
        , test "enforces single position and ignores other buys" <|
            \_ ->
                let
                    steps =
                        [ [ { coin = 0, close = 100, signal = Buy, strength = 10 } ]
                        , [ { coin = 0, close = 100, signal = Pass, strength = 0 }, { coin = 1, close = 50, signal = Buy, strength = 20 } ]
                        ]

                    prepared =
                        preparedFrom steps

                    sim =
                        Simulator.run { initialCapital = 10000, feeRate = 0.001 } prepared
                in
                Expect.equal Nothing (List.drop 1 sim.trades |> List.head)
        , test "buys the coin with the highest buy strength" <|
            \_ ->
                let
                    steps =
                        [ [ { coin = 0, close = 100, signal = Buy, strength = 5 }, { coin = 1, close = 100, signal = Buy, strength = 10 } ]
                        , [ { coin = 0, close = 100, signal = Sell, strength = 0 }, { coin = 1, close = 200, signal = Sell, strength = 0 } ]
                        ]

                    prepared =
                        preparedFrom steps

                    sim =
                        Simulator.run { initialCapital = 10000, feeRate = 0.001 } prepared
                in
                Expect.within (Expect.Absolute 1) 19960 (Maybe.withDefault 0 (List.head (List.reverse sim.equities)))
        , test "equal buy strengths fall back to the alphabetically first coin" <|
            \_ ->
                let
                    steps =
                        [ [ { coin = 0, close = 100, signal = Buy, strength = 5 }, { coin = 1, close = 100, signal = Buy, strength = 5 } ]
                        , [ { coin = 0, close = 100, signal = Sell, strength = 0 }, { coin = 1, close = 200, signal = Sell, strength = 0 } ]
                        ]

                    prepared =
                        preparedFrom steps

                    sim =
                        Simulator.run { initialCapital = 10000, feeRate = 0.001 } prepared
                in
                Expect.within (Expect.Absolute 0.1) 9980.02 (Maybe.withDefault 0 (List.head (List.reverse sim.equities)))
        , test "carries a position forward across a data gap and uses the last known close" <|
            \_ ->
                let
                    steps =
                        [ [ { coin = 0, close = 100, signal = Buy, strength = 10 } ]
                        , []
                        , [ { coin = 0, close = 120, signal = Sell, strength = 0 } ]
                        ]

                    prepared =
                        preparedFrom steps

                    sim =
                        Simulator.run { initialCapital = 10000, feeRate = 0.001 } prepared
                in
                Expect.within (Expect.Absolute 0.01) 11976.02 (Maybe.withDefault 0 (List.head (List.reverse sim.equities)))
        , test "sells then allows re-entry in the same step" <|
            \_ ->
                let
                    steps =
                        [ [ { coin = 0, close = 100, signal = Buy, strength = 10 } ]
                        , [ { coin = 0, close = 110, signal = Sell, strength = 0 }, { coin = 1, close = 50, signal = Buy, strength = 15 } ]
                        ]

                    prepared =
                        preparedFrom steps

                    sim =
                        Simulator.run { initialCapital = 10000, feeRate = 0.001 } prepared
                in
                Expect.equal 1 (List.length sim.trades)
        ]
