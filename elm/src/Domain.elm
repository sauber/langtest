-- The shared data types of the trading strategy evaluator.

module Domain exposing
    ( Bar
    , Coin
    , Config
    , Event
    , Market
    , Quote
    , Ratio(..)
    , Signal(..)
    , Trade
    )

-- The configuration of the trading account and of the market index.
type alias Config =
    { initialCapital : Float
    , feeRate : Float
    , indexBudget : Float
    , indexWeight : Int
    }

-- A candle as read from a market data file, before it is aligned to the timeline.
type alias Quote =
    { timestamp : Int
    , close : Float
    }

-- A candle of one coin, aligned to a step of the simulation timeline.
type alias Bar =
    { timestamp : Int
    , step : Int
    , close : Float
    }

-- A candle of one coin with its signal, aligned to a step of the timeline.
type alias Event =
    { step : Int
    , symbol : String
    , close : Float
    , signal : Signal
    }

-- The trading signal of one bar; a buy carries the strength of the signal.
type Signal
    = NoSignal
    | Buy Float
    | Sell

-- One coin with its bars in ascending time order.
type alias Coin =
    { symbol : String
    , bars : List Bar
    }

-- The shared simulation timeline together with every coin aligned to it.
type alias Market =
    { steps : List Int
    , coins : List Coin
    }

-- A closed trade with its net return and its holding duration in steps.
type alias Trade =
    { symbol : String
    , netReturn : Float
    , holdingSteps : Int
    }

-- A ratio that is infinite when its denominator is zero.
type Ratio
    = Finite Float
    | Infinite
