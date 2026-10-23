module Simulator exposing (Config, defaultConfig, run)

import Array exposing (Array)
import Domain exposing (Position, Simulation, Trade)
import Market exposing (Prepared)

{-| The timed hourly stepping loop of the evaluator.
-}


-- Cash and fee settings for the simulation
type alias Config =
    { initialCapital : Float
    , feeRate : Float
    }


-- Fixed evaluation parameters
defaultConfig : Config
defaultConfig =
    { initialCapital = 10000
    , feeRate = 0.001
    }


-- State threaded through every step
type alias LoopState =
    { cash : Float
    , position : Maybe Position
    , equities : List Float
    , trades : List Trade
    , step : Int
    }


-- Run the simulation once over every prepared step
run : Config -> Prepared -> Simulation
run config prepared =
    let
        initial =
            { cash = config.initialCapital
            , position = Nothing
            , equities = []
            , trades = []
            , step = 0
            }

        final =
            Array.foldl (stepLoop config prepared) initial prepared.bestCoin
    in
    { equities = List.reverse final.equities
    , trades = List.reverse final.trades
    }


-- Apply the rules in order and record the account value for one step
stepLoop : Config -> Prepared -> Int -> LoopState -> LoopState
stepLoop config prepared bestCoin state =
    let
        signedClose =
            case state.position of
                Just position ->
                    case Array.get position.coin prepared.bars of
                        Just bars ->
                            Maybe.withDefault 0 (Array.get state.step bars)

                        Nothing ->
                            0

                Nothing ->
                    0

        afterSell =
            case state.position of
                Just position ->
                    if signedClose < 0 then
                        sellAt config state position (abs signedClose)

                    else if signedClose > 0 then
                        { state | position = Just { position | lastClose = signedClose } }

                    else
                        state

                Nothing ->
                    state

        afterBuy =
            case afterSell.position of
                Just _ ->
                    afterSell

                Nothing ->
                    if bestCoin >= 0 then
                        let
                            close =
                                Maybe.withDefault 0 (Array.get state.step prepared.bestClose)
                        in
                        if close > 0 then
                            buyAt config bestCoin close afterSell

                        else
                            afterSell

                    else
                        afterSell

        equity =
            case afterBuy.position of
                Just position ->
                    position.quantity * position.lastClose

                Nothing ->
                    afterBuy.cash
    in
    { afterBuy
        | equities = equity :: afterBuy.equities
        , step = state.step + 1
    }


-- Rule 2: sell the whole position and record the closed trade
sellAt : Config -> LoopState -> Position -> Float -> LoopState
sellAt config state position close =
    let
        proceeds =
            position.quantity * close * (1 - config.feeRate)

        trade =
            { netReturn = proceeds / position.cashIn - 1
            , holdingSteps = state.step - position.entryStep
            }
    in
    { state
        | cash = state.cash + proceeds
        , position = Nothing
        , trades = trade :: state.trades
    }


-- Rule 3: spend all cash on the strongest oversold coin
buyAt : Config -> Int -> Float -> LoopState -> LoopState
buyAt config coin close state =
    let
        quantity =
            state.cash / (close * (1 + config.feeRate))
    in
    { state
        | cash = 0
        , position =
            Just
                { coin = coin
                , quantity = quantity
                , cashIn = state.cash
                , entryStep = state.step
                , lastClose = close
                }
    }
