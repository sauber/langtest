-- The market model: the shared timeline and every coin aligned to it.

module Market exposing (build, timeline)

import Domain exposing (Bar, Coin, Market, Quote)

-- A coin with its quotes, before the shared timeline is known.
type alias RawCoin =
    { symbol : String
    , quotes : List Quote
    }

-- Builds the simulation market from the quotes of every coin.
build : List ( String, List Quote ) -> Market
build coinQuotes =
    let
        raw = List.map toRawCoin coinQuotes
        steps = timeline raw
    in
    { steps = steps, coins = List.map (align steps) (List.sortBy .symbol raw) }

-- Builds the sorted union of every candle timestamp.
timeline : List RawCoin -> List Int
timeline raw =
    raw
        |> List.concatMap (\coin -> List.map .timestamp coin.quotes)
        |> List.sort
        |> unique

-- Puts the quotes of one coin into a coin that waits for the timeline.
toRawCoin : ( String, List Quote ) -> RawCoin
toRawCoin ( symbol, quotes ) =
    { symbol = symbol, quotes = sortedQuotes quotes }

-- Sorts the quotes of a coin by their timestamp when they are out of order.
sortedQuotes : List Quote -> List Quote
sortedQuotes quotes =
    if ascending quotes then
        quotes

    else
        List.sortBy .timestamp quotes

-- Tells whether the timestamps of the quotes are ascending.
ascending : List Quote -> Bool
ascending quotes =
    ascendingFrom Nothing quotes

-- Tells whether the timestamps of the remaining quotes are ascending.
ascendingFrom : Maybe Int -> List Quote -> Bool
ascendingFrom previous quotes =
    case quotes of
        [] ->
            True

        quote :: rest ->
            case previous of
                Just value ->
                    if value <= quote.timestamp then
                        ascendingFrom (Just quote.timestamp) rest

                    else
                        False

                Nothing ->
                    ascendingFrom (Just quote.timestamp) rest

-- Adds the timeline step to every candle of a coin.
align : List Int -> RawCoin -> Coin
align steps raw =
    { symbol = raw.symbol
    , bars = alignQuotes 0 steps raw.quotes []
    }

-- Pairs every quote of a coin with the step it takes on the timeline.
alignQuotes : Int -> List Int -> List Quote -> List Bar -> List Bar
alignQuotes index steps quotes collected =
    case ( steps, quotes ) of
        ( _, [] ) ->
            List.reverse collected

        ( [], quote :: _ ) ->
            List.reverse (toBar index quote :: collected)

        ( step :: remainingSteps, quote :: remainingQuotes ) ->
            if step == quote.timestamp then
                alignQuotes (index + 1) remainingSteps remainingQuotes (toBar index quote :: collected)

            else if step < quote.timestamp then
                alignQuotes (index + 1) remainingSteps quotes collected

            else
                alignQuotes index steps remainingQuotes (toBar index quote :: collected)

-- Turns a quote into a candle of the given timeline step.
toBar : Int -> Quote -> Bar
toBar step quote =
    { timestamp = quote.timestamp
    , step = step
    , close = quote.close
    }

-- Removes consecutive duplicates from an ascending list.
unique : List Int -> List Int
unique timestamps =
    uniqueFrom Nothing timestamps []

-- Removes the repetitions of the previous timestamp from an ascending list.
uniqueFrom : Maybe Int -> List Int -> List Int -> List Int
uniqueFrom previous timestamps collected =
    case timestamps of
        [] ->
            List.reverse collected

        timestamp :: rest ->
            case previous of
                Just value ->
                    if value == timestamp then
                        uniqueFrom previous rest collected

                    else
                        uniqueFrom (Just timestamp) rest (timestamp :: collected)

                Nothing ->
                    uniqueFrom (Just timestamp) rest (timestamp :: collected)
