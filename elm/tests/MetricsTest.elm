module MetricsTest exposing (tests)

import Domain exposing (Trade)
import Expect
import Metrics
import Test exposing (Test, describe, test)

{-| Unit tests for performance metrics.
-}


tests : Test
tests =
    describe "Metrics"
        [ test "computes Sharpe with sample standard deviation and annualization" <|
            \_ ->
                let
                    equities =
                        [ 100, 110, 99, 108.9 ]

                    sharpeResult =
                        Metrics.sharpe equities
                in
                case sharpeResult of
                    Just value ->
                        Expect.within (Expect.Absolute 0.01) 27.02 value

                    Nothing ->
                        Expect.fail "expected sharpe"
        , test "win/loss ratio excludes zero-return trades" <|
            \_ ->
                let
                    trades =
                        [ { netReturn = 0.1, holdingSteps = 5 }
                        , { netReturn = -0.05, holdingSteps = 3 }
                        , { netReturn = 0, holdingSteps = 2 }
                        ]

                    result =
                        Metrics.winLoss trades
                in
                case result of
                    Metrics.Ratio ratio ->
                        Expect.within (Expect.Absolute 0.0001) 1 ratio

                    _ ->
                        Expect.fail "expected a 1:1 ratio"
        , test "computes average gain and average holding time across closed trades" <|
            \_ ->
                let
                    trades =
                        [ { netReturn = 0.1, holdingSteps = 4 }
                        , { netReturn = -0.02, holdingSteps = 2 }
                        , { netReturn = 0.03, holdingSteps = 6 }
                        ]

                    avgGain =
                        Metrics.averageGain trades

                    avgHold =
                        Metrics.averageHold trades
                in
                case ( avgGain, avgHold ) of
                    ( Just gain, Just hold ) ->
                        if abs (gain - 0.0366666667) < 0.0001 then
                            Expect.within (Expect.Absolute 0.01) 4 hold

                        else
                            Expect.fail "expected average gain"

                    _ ->
                        Expect.fail "expected metrics"
        , test "reports N/A when sharpe deviation is zero" <|
            \_ ->
                Expect.equal Nothing (Metrics.sharpe [ 100, 100, 100 ])
        , test "returns inf when no losses" <|
            \_ ->
                let
                    trades =
                        [ { netReturn = 0.01, holdingSteps = 1 }
                        , { netReturn = 0.02, holdingSteps = 1 }
                        ]
                in
                case Metrics.winLoss trades of
                    Metrics.Infinite ->
                        Expect.pass

                    _ ->
                        Expect.fail "expected inf"
        ]
