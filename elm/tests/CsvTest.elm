-- The tests of the parser of the market data files.

module CsvTest exposing (suite)

import Csv
import Expect
import Test exposing (Test, describe, test)

-- A market data file with two rows.
sample : String
sample =
    "timestamp,datetime,open,high,low,close,volume,turnover\n"
        ++ "1507089600,2017-10-04T04:00:00Z,4307,4308,4306,4307.5,0.001,4.307\n"
        ++ "1507093200,2017-10-04T05:00:00Z,4307,4309,4307,4308.25,0.002,8.616\n"

-- The tests of the parser of the market data files.
suite : Test
suite =
    describe "the parser of the market data files"
        [ test "the timestamp and the close of every row are read" <|
            \_ ->
                Csv.parseQuotes sample
                    |> Expect.equal
                        (Ok
                            [ { timestamp = 1507089600, close = 4307.5 }
                            , { timestamp = 1507093200, close = 4308.25 }
                            ]
                        )

        , test "a file without the expected header is refused" <|
            \_ ->
                Csv.parseQuotes "a,b,c\n1,2,3\n"
                    |> Expect.equal (Err "the file does not start with the expected header")

        , test "a file without a row is refused" <|
            \_ ->
                Csv.parseQuotes ""
                    |> Expect.equal (Err "the file holds no data row")

        , test "a short row is refused" <|
            \_ ->
                Csv.parseQuotes
                    ("timestamp,datetime,open,high,low,close,volume,turnover\n1,2,3\n")
                    |> Expect.equal (Err "a row does not hold eight columns")

        , test "a malformed close price is refused" <|
            \_ ->
                Csv.parseQuotes
                    ("timestamp,datetime,open,high,low,close,volume,turnover\n1,2,3,4,5,x,7,8\n")
                    |> Expect.equal (Err "a row holds a malformed timestamp or close price")
        ]
