-- The tests of the relative strength index.

module RsiTest exposing (suite)

import Expect
import Helpers exposing (closeTo, closeToList)
import Rsi exposing (period, rsi, rsiSeries)
import Test exposing (Test, describe, test)

-- The closing prices of the classic example of the relative strength index.
fixture : List Float
fixture =
    [ 44.3389
    , 44.0902
    , 44.1497
    , 43.6124
    , 44.3278
    , 44.8264
    , 45.0955
    , 45.4245
    , 45.8433
    , 46.0826
    , 45.8931
    , 46.0328
    , 45.614
    , 46.282
    , 46.282
    , 46.0028
    , 46.0328
    , 46.4116
    , 46.2222
    , 45.6439
    , 46.2122
    , 46.2521
    , 45.7137
    , 46.4515
    , 45.7835
    , 45.3548
    , 44.0288
    , 44.1783
    , 44.2181
    , 44.5672
    , 43.4205
    , 42.6628
    , 43.1314
    ]

-- The index values that the fixture produces.
expected : List Float
expected =
    [ 70.53278948369497
    , 66.31856180517232
    , 66.54982993552764
    , 69.40630533884433
    , 66.3551690562718
    , 57.97485571430819
    , 62.929606754597
    , 63.25714756254528
    , 56.05929871526324
    , 62.37707144318042
    , 54.70757308126129
    , 50.4227744114564
    , 39.989823145376604
    , 41.46048197570564
    , 41.86891609254328
    , 45.46321244528675
    , 37.30404208985967
    , 33.07952299438848
    , 37.77295211443486
    ]

-- The tests of the relative strength index.
suite : Test
suite =
    describe "the relative strength index"
        [ test "the index needs fourteen price changes" <|
            \_ ->
                rsiSeries fixture
                    |> List.take period
                    |> List.all (\value -> value == Nothing)
                    |> Expect.equal True

        , test "the index holds one value per close" <|
            \_ ->
                rsiSeries fixture
                    |> List.length
                    |> Expect.equal (List.length fixture)

        , test "the index of the fixture is known" <|
            \_ ->
                rsiSeries fixture
                    |> List.drop period
                    |> List.map (Maybe.withDefault 0)
                    |> closeToList expected

        , test "a market without losses reaches a hundred" <|
            \_ ->
                rsi 1 0
                    |> Expect.equal 100

        , test "a market without gains stays at zero" <|
            \_ ->
                rsi 0 1
                    |> Expect.equal 0

        , test "a short series has no index at all" <|
            \_ ->
                rsiSeries [ 1, 2, 3 ]
                    |> List.all (\value -> value == Nothing)
                    |> Expect.equal True
        ]
