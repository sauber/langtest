-- The hourly simulator of the trading strategy.

module Simulator exposing (Simulation, simulate)

import Domain exposing (Config, Event, Market, Signal(..), Trade)

-- The result of the simulation: the equity curve and the closed trades.
type alias Simulation =
    { equity : List Float
    , trades : List Trade
    , finalEquity : Float
    }

-- The open position of the account.
type alias Position =
    { symbol : String
    , quantity : Float
    , costBasis : Float
    , entryStep : Int
    , lastClose : Float
    }

-- The cash and the position of the account.
type alias Account =
    { cash : Float
    , position : Maybe Position
    }

-- The state of the stepping loop.
type alias State =
    { step : Int
    , events : List Event
    , account : Account
    , equityCurve : List Float
    , trades : List Trade
    }

-- Runs the hourly stepping loop of the market with the events of the strategy.
simulate : Config -> Market -> List Event -> Simulation
simulate config market events =
    let
        initial =
            { step = 0
            , events = events
            , account = { cash = config.initialCapital, position = Nothing }
            , equityCurve = []
            , trades = []
            }
        final = List.foldl (\_ state -> advance config state) initial market.steps
    in
    { equity = List.reverse final.equityCurve
    , trades = List.reverse final.trades
    , finalEquity = headOrZero final.equityCurve
    }

-- Applies one hour of the timeline: the events, the trades and the account value.
advance : Config -> State -> State
advance config state =
    let
        ( events, remaining ) = takeEvents state.step state.events
        ( account, closed ) = applyTrades config state.step events state.account
    in
    { state
        | step = state.step + 1
        , events = remaining
        , account = account
        , equityCurve = valueOf account :: state.equityCurve
        , trades =
            case closed of
                Just trade ->
                    trade :: state.trades

                Nothing ->
                    state.trades
    }

-- Takes the events the coins report at the given step.
takeEvents : Int -> List Event -> ( List Event, List Event )
takeEvents step events =
    case events of
        event :: rest ->
            if event.step == step then
                let
                    ( taken, remaining ) = takeEvents step rest
                in
                ( event :: taken, remaining )

            else
                ( [], events )

        [] ->
            ( [], [] )

-- Sells the held coin on a sell signal and buys the strongest buy signal when nothing is held.
applyTrades : Config -> Int -> List Event -> Account -> ( Account, Maybe Trade )
applyTrades config step events account =
    let
        refreshed = refresh account events
        ( afterSell, closed ) = sellHeld config step events refreshed
    in
    case afterSell.position of
        Nothing ->
            ( buy config step events afterSell, closed )

        Just _ ->
            ( afterSell, closed )

-- Updates the last known close of the held coin.
refresh : Account -> List Event -> Account
refresh account events =
    case account.position of
        Nothing ->
            account

        Just position ->
            case eventOf position.symbol events of
                Just event ->
                    { account | position = Just { position | lastClose = event.close } }

                Nothing ->
                    account

-- Sells the held coin when it reports a sell signal.
sellHeld : Config -> Int -> List Event -> Account -> ( Account, Maybe Trade )
sellHeld config step events account =
    case ( account.position, sellEvent account.position events ) of
        ( Just position, Just event ) ->
            let
                ( cash, trade ) = sell config step event position account.cash
            in
            ( { cash = cash, position = Nothing }, Just trade )

        _ ->
            ( account, Nothing )

-- Finds the event of the held coin when it carries a sell signal.
sellEvent : Maybe Position -> List Event -> Maybe Event
sellEvent position events =
    case position of
        Nothing ->
            Nothing

        Just held ->
            case eventOf held.symbol events of
                Just event ->
                    if event.signal == Sell then
                        Just event

                    else
                        Nothing

                Nothing ->
                    Nothing

-- Searches the event of one coin in the events of a step.
eventOf : String -> List Event -> Maybe Event
eventOf symbol events =
    case events of
        [] ->
            Nothing

        event :: rest ->
            if event.symbol == symbol then
                Just event

            else
                eventOf symbol rest

-- Sells the open position at the close price of the sell signal and books the trade.
sell : Config -> Int -> Event -> Position -> Float -> ( Float, Trade )
sell config step event position cash =
    let
        proceeds = position.quantity * event.close * (1 - config.feeRate)
    in
    ( cash + proceeds
    , { symbol = position.symbol
      , netReturn = proceeds / position.costBasis - 1
      , holdingSteps = step - position.entryStep
      }
    )

-- Buys the coin with the strongest buy signal using all available cash.
buy : Config -> Int -> List Event -> Account -> Account
buy config step events account =
    case strongest events of
        Nothing ->
            account

        Just event ->
            if account.cash <= 0 then
                account

            else
                { cash = 0
                , position =
                    Just
                        { symbol = event.symbol
                        , quantity = account.cash / (event.close * (1 + config.feeRate))
                        , costBasis = account.cash
                        , entryStep = step
                        , lastClose = event.close
                        }
                }

-- Picks the buy signal with the highest strength; ties are broken alphabetically.
strongest : List Event -> Maybe Event
strongest events =
    List.foldl
        (\event best ->
            case ( event.signal, best ) of
                ( Buy strength, Nothing ) ->
                    Just event

                ( Buy strength, Just current ) ->
                    case current.signal of
                        Buy bestStrength ->
                            if strength > bestStrength then
                                Just event

                            else if strength == bestStrength && event.symbol < current.symbol then
                                Just event

                            else
                                Just current

                        _ ->
                            Just event

                _ ->
                    best
        )
        Nothing
        events

-- Values the account at the last known close of the held coin.
valueOf : Account -> Float
valueOf account =
    case account.position of
        Nothing ->
            account.cash

        Just position ->
            account.cash + position.quantity * position.lastClose

-- Reads the first value of a curve, or zero when the curve is empty.
headOrZero : List Float -> Float
headOrZero values =
    Maybe.withDefault 0 (List.head values)
