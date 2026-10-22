-- The helpers of the numeric comparisons of the tests.

module Helpers exposing (closeTo, closeToList, tolerance)

import Expect


-- The tolerance of the numeric comparisons.
tolerance : Expect.FloatingPointTolerance
tolerance =
    Expect.Absolute 1e-9


-- Compares two numbers with a tolerance.
closeTo : Float -> Float -> Expect.Expectation
closeTo expected actual =
    Expect.within tolerance expected actual


-- Compares two lists of numbers with a tolerance.
closeToList : List Float -> List Float -> Expect.Expectation
closeToList expected actual =
    if List.length expected /= List.length actual then
        Expect.fail "the two lists do not hold the same number of values"

    else
        Expect.all
            (List.map2
                (\expectedValue actualValue -> \_ -> closeTo expectedValue actualValue)
                expected
                actual
            )
            ()
