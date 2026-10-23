port module Main exposing (main)

import Domain exposing (Coin, Dataset, Simulation)
import Json.Decode as Decode
import Market
import Metrics
import Report
import Simulator

{-| Headless Elm worker driven by the Node host through ports.
-}


-- Host to Elm: raw market data
port dataset : (Decode.Value -> msg) -> Sub msg


-- Host to Elm: start the timed simulation
port run : (Int -> msg) -> Sub msg


-- Host to Elm: monotonic duration measured around the simulation
port simTime : (Float -> msg) -> Sub msg


-- Elm to host: the timed section finished
port finished : Int -> Cmd msg


-- Elm to host: final terminal report
port output : String -> Cmd msg


-- State after decoding and preparing the market data
type alias Loaded =
    { indexValues : List Float
    , prepared : Market.Prepared
    }


-- Worker lifecycle states
type Model
    = Loading
    | Ready Loaded
    | Complete Loaded Simulation
    | Done


-- Messages arriving from the host
type Msg
    = DatasetReceived Decode.Value
    | RunRequested Int
    | TimeReceived Float


-- Decode one coin's symbol, timestamps, and closes
coinDecoder : Decode.Decoder Coin
coinDecoder =
    Decode.map3 Coin
        (Decode.field "symbol" Decode.string)
        (Decode.field "ts" (Decode.array Decode.int))
        (Decode.field "closes" (Decode.array Decode.float))


-- Decode the whole host payload
datasetDecoder : Decode.Decoder Dataset
datasetDecoder =
    Decode.map2 Dataset
        (Decode.field "coins" (Decode.list coinDecoder))
        (Decode.field "index" (Decode.list Decode.float))


-- Last value of a non-empty series
lastValue : List Float -> Float
lastValue values =
    List.foldl (\value _ -> value) 0 values


-- Prepare the market, run the timed loop, then format the report
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( DatasetReceived value, Loading ) ->
            case Decode.decodeValue datasetDecoder value of
                Ok data ->
                    ( Ready
                        { indexValues = data.indexValues
                        , prepared = Market.prepare data.coins
                        }
                    , Cmd.none
                    )

                Err decodeError ->
                    ( Done, output ("error: " ++ Decode.errorToString decodeError) )

        ( RunRequested _, Ready ready ) ->
            let
                simulation =
                    Simulator.run Simulator.defaultConfig ready.prepared
            in
            ( Complete ready simulation, finished 0 )

        ( TimeReceived seconds, Complete ready simulation ) ->
            let
                marketFinal =
                    lastValue ready.indexValues

                metrics =
                    Metrics.summarize simulation.equities marketFinal simulation.trades

                report =
                    Report.render seconds metrics simulation ready.indexValues
            in
            ( Done, output report )

        _ ->
            ( model, Cmd.none )


-- Keep listening so late host messages never crash the worker
subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ dataset DatasetReceived
        , run RunRequested
        , simTime TimeReceived
        ]


-- Headless program entry point
main : Program () Model Msg
main =
    Platform.worker
        { init = \_ -> ( Loading, Cmd.none )
        , update = update
        , subscriptions = subscriptions
        }
