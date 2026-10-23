module Market exposing (Prepared, prepare)

import Array exposing (Array)
import Domain exposing (Coin, Signal(..))
import Rsi
import Strategy

{-| Turn raw candle histories into per-step arrays the simulator can index.
-}


-- Per-step best buy plus one signed-close column per coin
type alias Prepared =
    { stepCount : Int
    , bestCoin : Array Int
    , bestClose : Array Float
    , bars : Array (Array Float)
    }


-- Accumulator while every coin is folded into the prepared arrays
type alias Build =
    { bars : List (Array Float)
    , bestCoin : Array Int
    , bestClose : Array Float
    , bestStrength : Array Float
    }


-- Result of walking one coin through the timeline
type alias WalkResult =
    { bars : Array Float
    , bestCoin : Array Int
    , bestClose : Array Float
    , bestStrength : Array Float
    }


-- Build the timeline and index every bar by its simulation step
prepare : List Coin -> Prepared
prepare coins =
    let
        ordered =
            List.sortBy .symbol coins

        timeline =
            unionArrays (List.map .timestamps ordered)

        stepCount =
            Array.length timeline

        seeded =
            { bars = []
            , bestCoin = Array.repeat stepCount -1
            , bestClose = Array.repeat stepCount 0
            , bestStrength = Array.repeat stepCount -1
            }

        built =
            List.indexedMap Tuple.pair ordered
                |> List.foldl (addCoin timeline stepCount) seeded
    in
    { stepCount = stepCount
    , bestCoin = built.bestCoin
    , bestClose = built.bestClose
    , bars = Array.fromList (List.reverse built.bars)
    }


-- Run one coin through the timeline and collect its signed-close column
addCoin : Array Int -> Int -> ( Int, Coin ) -> Build -> Build
addCoin timeline stepCount ( coinIndex, coin ) build =
    let
        result =
            walk timeline stepCount coinIndex coin 0 0 Nothing build.bestCoin build.bestClose build.bestStrength []
    in
    { bars = result.bars :: build.bars
    , bestCoin = result.bestCoin
    , bestClose = result.bestClose
    , bestStrength = result.bestStrength
    }


-- Walk the shared timeline and the coin's bars together, one step at a time
walk : Array Int -> Int -> Int -> Coin -> Int -> Int -> Maybe Rsi.State -> Array Int -> Array Float -> Array Float -> List Float -> WalkResult
walk timeline stepCount coinIndex coin step barIndex rsiState bestCoin bestClose bestStrength acc =
    if step >= stepCount then
        { bars = Array.fromList (List.reverse acc)
        , bestCoin = bestCoin
        , bestClose = bestClose
        , bestStrength = bestStrength
        }

    else
        let
            stepTs =
                Maybe.withDefault 0 (Array.get step timeline)

            present =
                case Array.get barIndex coin.timestamps of
                    Just barTs ->
                        barTs == stepTs

                    Nothing ->
                        False
        in
        if not present then
            walk timeline stepCount coinIndex coin (step + 1) barIndex rsiState bestCoin bestClose bestStrength (0 :: acc)

        else
            let
                close =
                    Maybe.withDefault 0 (Array.get barIndex coin.closes)

                ( nextRsi, maybeRsi ) =
                    advance Rsi.period close rsiState

                ( nextBestCoin, nextBestClose, nextBestStrength ) =
                    case maybeRsi of
                        Just rsi ->
                            if Strategy.signal rsi == Buy then
                                let
                                    buyStrength =
                                        Strategy.strength rsi
                                in
                                if buyStrength > Maybe.withDefault -1 (Array.get step bestStrength) then
                                    ( Array.set step coinIndex bestCoin
                                    , Array.set step close bestClose
                                    , Array.set step buyStrength bestStrength
                                    )

                                else
                                    ( bestCoin, bestClose, bestStrength )

                            else
                                ( bestCoin, bestClose, bestStrength )

                        Nothing ->
                            ( bestCoin, bestClose, bestStrength )

                signedClose =
                    case maybeRsi of
                        Just rsi ->
                            if Strategy.signal rsi == Sell then
                                -close

                            else
                                close

                        Nothing ->
                            close
            in
            walk timeline stepCount coinIndex coin (step + 1) (barIndex + 1) (Just nextRsi) nextBestCoin nextBestClose nextBestStrength (signedClose :: acc)


-- Feed one close through Wilder's smoothing, seeding the state on the first bar
advance : Int -> Float -> Maybe Rsi.State -> ( Rsi.State, Maybe Float )
advance lookback close rsiState =
    case rsiState of
        Nothing ->
            ( Rsi.initial close, Nothing )

        Just state ->
            Rsi.step lookback close state


-- Merge every coin's sorted timestamp array into one sorted unique timeline
unionArrays : List (Array Int) -> Array Int
unionArrays arrays =
    List.foldl mergeOne Array.empty arrays


-- Merge one sorted array into the accumulated timeline
mergeOne : Array Int -> Array Int -> Array Int
mergeOne fresh merged =
    Array.fromList (List.reverse (mergeLoop fresh merged 0 0 []))


-- Tail-recursive index merge with de-duplication
mergeLoop : Array Int -> Array Int -> Int -> Int -> List Int -> List Int
mergeLoop fresh merged freshIndex mergedIndex acc =
    case ( Array.get freshIndex fresh, Array.get mergedIndex merged ) of
        ( Nothing, Nothing ) ->
            acc

        ( Nothing, Just value ) ->
            mergeLoop fresh merged freshIndex (mergedIndex + 1) (value :: acc)

        ( Just value, Nothing ) ->
            mergeLoop fresh merged (freshIndex + 1) mergedIndex (value :: acc)

        ( Just left, Just right ) ->
            if left < right then
                mergeLoop fresh merged (freshIndex + 1) mergedIndex (left :: acc)

            else if left > right then
                mergeLoop fresh merged freshIndex (mergedIndex + 1) (right :: acc)

            else
                mergeLoop fresh merged (freshIndex + 1) (mergedIndex + 1) (left :: acc)
