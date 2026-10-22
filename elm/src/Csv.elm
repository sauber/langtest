-- The parser of the market data files.

module Csv exposing (columns, parseQuotes)

import Domain exposing (Quote)

-- The number of columns of every row of a market data file.
columns : Int
columns =
    8

-- The position of the close price inside a row.
closeColumn : Int
closeColumn =
    5

-- The header line every market data file starts with.
header : List String
header =
    [ "timestamp", "datetime", "open", "high", "low", "close", "volume", "turnover" ]

-- Parses the text of a market data file into the quotes of one coin.
parseQuotes : String -> Result String (List Quote)
parseQuotes text =
    case String.lines (String.trimRight (String.replace "\r" "" text)) of
        [] ->
            Err "the file holds no data row"

        first :: rows ->
            if String.isEmpty first then
                Err "the file holds no data row"

            else if String.split "," first /= header then
                Err "the file does not start with the expected header"

            else
                quotesFromRows rows []

-- Collects the quotes of the rows of a file into an accumulator.
quotesFromRows : List String -> List Quote -> Result String (List Quote)
quotesFromRows rows collected =
    case rows of
        [] ->
            Ok (List.reverse collected)

        row :: rest ->
            case quoteOfRow row of
                Err problem ->
                    Err problem

                Ok quote ->
                    quotesFromRows rest (quote :: collected)

-- Reads the quote of one row of a market data file.
quoteOfRow : String -> Result String Quote
quoteOfRow row =
    case String.split "," row of
        timestamp :: _ :: _ :: _ :: _ :: close :: _ :: _ :: [] ->
            case ( String.toInt timestamp, String.toFloat close ) of
                ( Just moment, Just price ) ->
                    Ok { timestamp = moment, close = price }

                _ ->
                    Err "a row holds a malformed timestamp or close price"

        _ ->
            Err "a row does not hold eight columns"
