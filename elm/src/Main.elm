-- The entry point of the Elm trading strategy evaluator.

port module Main exposing (main)

import Csv
import Domain exposing (Config, Event, Market, Quote)
import Events
import Index
import Market as MarketModel
import Metrics
import Platform
import Report
import Simulator exposing (Simulation)
import Strategy exposing (Applied, Strategy)

-- The names of the market data files the host has to load.
port namesIn : (List String -> msg) -> Sub msg

-- One market data file: the raw text of the file that was asked for.
port fileIn : (String -> msg) -> Sub msg

-- Asks the host for a monotonic timestamp in seconds.
port requestClock : () -> Cmd msg

-- Receives a monotonic timestamp of the host in seconds.
port clockIn : (Float -> msg) -> Sub msg

-- Asks the host for one market data file.
port requestFile : String -> Cmd msg

-- Sends the finished report to the host.
port out : String -> Cmd msg

-- The phase of the evaluation.
type Phase
    = Loading
    | Timing
    | Finished
    | Failed

-- The state of the evaluation.
type alias Model =
    { config : Config
    , strategy : Strategy
    , applied : Applied
    , events : List Event
    , phase : Phase
    , pending : List String
    , quotes : List ( String, List Quote )
    , market : Maybe Market
    , simulation : Maybe Simulation
    , startedAt : Float
    }

-- The messages of the evaluation.
type Msg
    = NamesIn (List String)
    | FileIn String
    | ClockIn Float

-- The fixed configuration of the simulation.
defaultConfig : Config
defaultConfig =
    { initialCapital = 10000
    , feeRate = 0.001
    , indexBudget = 10000
    , indexWeight = 20
    }

-- Starts the evaluation.
init : () -> ( Model, Cmd Msg )
init _ =
    ( { config = defaultConfig
      , strategy = Strategy.rsiStrategy
      , applied = { name = Strategy.rsiStrategy.name, signalsOf = [] }
      , events = []
      , phase = Loading
      , pending = []
      , quotes = []
      , market = Nothing
      , simulation = Nothing
      , startedAt = 0
      }
    , Cmd.none
    )

-- Advances the evaluation by one message.
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NamesIn names ->
            case names of
                [] ->
                    fail model "no market data file found"

                name :: _ ->
                    ( { model | pending = names }, requestFile name )

        FileIn text ->
            case model.pending of
                name :: _ ->
                    case Csv.parseQuotes text of
                        Err problem ->
                            fail model problem

                        Ok quotes ->
                            loadQuotes (symbolOf name) quotes model

                [] ->
                    fail model "the host sent an unexpected file"

        ClockIn timestamp ->
            case model.phase of
                Failed ->
                    ( model, Cmd.none )

                _ ->
                    tick timestamp model

-- Stores the quotes of a coin and asks the host for the next file.
loadQuotes : String -> List Quote -> Model -> ( Model, Cmd Msg )
loadQuotes symbol quotes model =
    let
        collected = model.quotes ++ [ ( symbol, quotes ) ]
        remaining = List.drop 1 model.pending
    in
    case remaining of
        name :: _ ->
            ( { model | quotes = collected, pending = remaining }, requestFile name )

        [] ->
            let
                market = MarketModel.build collected
                applied = Strategy.apply model.strategy market
            in
            ( { model | quotes = collected
              , pending = []
              , market = Just market
              , applied = applied
              , events = Events.events applied market
              , phase = Timing
              }
            , requestClock ()
            )

-- Handles a timestamp of the host: the first one opens the measured window, the second one closes it.
tick : Float -> Model -> ( Model, Cmd Msg )
tick timestamp model =
    case ( model.market, model.simulation ) of
        ( Just market, Nothing ) ->
            let
                simulation = Simulator.simulate model.config market model.events
            in
            ( { model | simulation = Just simulation, startedAt = timestamp }, requestClock () )

        ( Just market, Just simulation ) ->
            let
                elapsed = timestamp - model.startedAt
                index = Index.compute model.config market
                metrics = Metrics.compute simulation index
                report = Report.render model.applied market simulation index metrics elapsed
            in
            ( { model | phase = Finished }, out report )

        _ ->
            ( model, Cmd.none )

-- Reads the coin symbol out of a market data file name.
symbolOf : String -> String
symbolOf name =
    if String.endsWith ".csv" name then
        String.dropRight 4 name

    else
        name

-- Reports a fatal problem to the host.
fail : Model -> String -> ( Model, Cmd Msg )
fail model problem =
    ( { model | phase = Failed }, out ("error: " ++ problem) )

-- Subscribes to the messages of the host.
subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ namesIn NamesIn
        , fileIn FileIn
        , clockIn ClockIn
        ]

-- Runs the evaluation inside a Node process.
main : Program () Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }
