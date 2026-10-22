-- The tests of the market model and of the market index.

module MarketTest exposing (suite)

import Domain exposing (Config, Market, Quote)
import Expect
import Helpers exposing (closeTo, closeToList)
import Index
import Market
import Test exposing (Test, concat, describe, test)

-- The account of the tests.
config : Config
config =
    { initialCapital = 10000
    , feeRate = 0.001
    , indexBudget = 10000
    , indexWeight = 20
    }

-- Builds a market of the given coins.
market : List ( String, List Quote ) -> Market
market coinQuotes =
    Market.build coinQuotes

-- Builds a quote of a coin.
quote : Int -> Float -> Quote
quote timestamp close =
    { timestamp = timestamp
    , close = close
    }

-- Reads the steps of the candles of one coin.
stepsOf : Market -> String -> List Int
stepsOf built symbol =
    case List.filter (\coin -> coin.symbol == symbol) built.coins of
        coin :: _ ->
            List.map .step coin.bars

        [] ->
            []

-- The tests of the market model and of the market index.
suite : Test
suite =
    concat
        [ describe "the market model"
            [ test "the timeline is the sorted union of the timestamps" <|
                \_ ->
                    market
                        [ ( "AAA", [ quote 300 3, quote 100 1 ] )
                        , ( "BBB", [ quote 200 2, quote 100 1 ] )
                        ]
                        |> .steps
                        |> Expect.equal [ 100, 200, 300 ]

            , test "every candle knows its step of the timeline" <|
                \_ ->
                    let
                        built =
                            market
                                [ ( "AAA", [ quote 300 3, quote 100 1 ] )
                                , ( "BBB", [ quote 200 2, quote 100 1 ] )
                                ]
                    in
                    Expect.all
                        [ \_ -> Expect.equal [ 0, 2 ] (stepsOf built "AAA")
                        , \_ -> Expect.equal [ 0, 1 ] (stepsOf built "BBB")
                        ]
                        built

            , test "the coins of the market are sorted by their symbol" <|
                \_ ->
                    market
                        [ ( "BBB", [ quote 100 1 ] )
                        , ( "AAA", [ quote 100 1 ] )
                        ]
                        |> .coins
                        |> List.map .symbol
                        |> Expect.equal [ "AAA", "BBB" ]
            ]

        , describe "the market index"
            [ test "every coin starts with the same share of the budget" <|
                \_ ->
                    Index.compute config
                        (market
                            [ ( "AAA", [ quote 100 10, quote 200 20 ] )
                            , ( "BBB", [ quote 100 5, quote 200 5 ] )
                            ]
                        )
                        |> .curve
                        |> closeToList [ 1000, 1500 ]

            , test "the index follows the close prices of the coins" <|
                \_ ->
                    let
                        index =
                            Index.compute config
                                (market
                                    [ ( "AAA", [ quote 100 10, quote 200 20 ] )
                                    , ( "BBB", [ quote 100 5, quote 200 5 ] )
                                    ]
                                )
                    in
                    closeTo 1500 index.final
            ]
        ]
