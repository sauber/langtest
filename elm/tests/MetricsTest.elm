-- The tests of the performance metrics.

module MetricsTest exposing (suite)

import Domain exposing (Ratio(..), Trade)
import Expect
import Helpers exposing (closeTo, closeToList)
import Metrics exposing (averageGain, averageHolding, hourlyReturns, losses, sampleStdDev, sharpe, winLossRatio, wins)
import Test exposing (Test, describe, test)

-- A winning trade.
winner : Trade
winner =
    { symbol = "AAA"
    , netReturn = 0.1
    , holdingSteps = 5
    }

-- A losing trade.
loser : Trade
loser =
    { symbol = "BBB"
    , netReturn = -0.05
    , holdingSteps = 15
    }

-- A trade that closed without a gain and without a loss.
flat : Trade
flat =
    { symbol = "CCC"
    , netReturn = 0
    , holdingSteps = 25
    }

-- The tests of the performance metrics.
suite : Test
suite =
    describe "the performance metrics"
        [ test "the hourly returns compare a value with its predecessor" <|
            \_ ->
                hourlyReturns [ 100, 110, 121 ]
                    |> closeToList [ 0.1, 0.1 ]

        , test "a curve without a deviation has no sharpe ratio" <|
            \_ ->
                sharpe (hourlyReturns [ 100, 110, 121 ])
                    |> Expect.equal Nothing

        , test "the sharpe ratio of a rising curve is known" <|
            \_ ->
                case sharpe (hourlyReturns [ 100, 110, 120 ]) of
                    Nothing ->
                        Expect.fail "the sharpe ratio is known"

                    Just value ->
                        closeTo 1389.812937053015 value

        , test "the sample deviation of a curve uses the unbiased divisor" <|
            \_ ->
                sampleStdDev [ 2, 4, 4, 4, 5, 5, 7, 9 ]
                    |> closeTo 2.13808993529939

        , test "the win loss ratio counts the winners and the losers" <|
            \_ ->
                let
                    trades =
                        [ winner, loser, flat ]
                in
                trades
                    |> Expect.all
                        [ \subject -> Expect.equal (Finite 1) (winLossRatio subject)
                        , \subject -> Expect.equal 1 (wins subject)
                        , \subject -> Expect.equal 1 (losses subject)
                        ]

        , test "the win loss ratio is infinite without a losing trade" <|
            \_ ->
                winLossRatio [ winner, flat ]
                    |> Expect.equal Infinite

        , test "the average gain is the mean of the net returns" <|
            \_ ->
                averageGain [ winner, loser, flat ]
                    |> closeTo 0.016666666666666666

        , test "the average holding time is the mean of the holding times" <|
            \_ ->
                averageHolding [ winner, loser, flat ]
                    |> closeTo 15
        ]
