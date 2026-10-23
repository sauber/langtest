module RsiTest exposing (tests)

import Expect
import Rsi
import Test exposing (Test, describe, test)

{-| Unit tests for Wilder's RSI-14.
-}


closes : List Float
closes =
    [ 44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.1, 45.42, 45.84, 46.08, 45.89, 46.03, 45.61, 46.28, 46.28, 46.5 ]


tests : Test
tests =
    describe "Rsi"
        [ test "produces Nothing until the first full lookback" <|
            \_ ->
                let
                    values =
                        Rsi.series 14 closes
                in
                Expect.equal [ Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing ] (List.take 14 values)
        , test "computes the first RSI with Wilder smoothing" <|
            \_ ->
                let
                    values =
                        Rsi.series 14 closes

                    first =
                        List.drop 14 values |> List.head
                in
                case first of
                    Just (Just value) ->
                        Expect.within (Expect.Absolute 0.01) 70.46 value

                    _ ->
                        Expect.fail "expected the first RSI value"
        , test "rsi reaches 100 when average loss goes to zero" <|
            \_ ->
                let
                    rising =
                        [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 ]

                    values =
                        Rsi.series 14 rising

                    last =
                        List.reverse values |> List.head
                in
                case last of
                    Just (Just value) ->
                        Expect.within (Expect.Absolute 0.001) 100 value

                    _ ->
                        Expect.fail "expected rsi 100"
        ]
