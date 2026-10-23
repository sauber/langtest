module Domain exposing (Coin, Dataset, Position, Signal(..), Simulation, Trade)

import Array exposing (Array)

{-| Shared domain vocabulary for the evaluator.
-}


-- A strategy verdict for a single bar
type Signal
    = Buy
    | Sell
    | Pass


-- A coin symbol with its ascending timestamps and matching closes
type alias Coin =
    { symbol : String
    , timestamps : Array Int
    , closes : Array Float
    }


-- Everything the host sends: coin history and the precomputed market index
type alias Dataset =
    { coins : List Coin
    , indexValues : List Float
    }


-- An open long position
type alias Position =
    { coin : Int
    , quantity : Float
    , cashIn : Float
    , entryStep : Int
    , lastClose : Float
    }


-- A closed round trip with its net return and lifetime in steps
type alias Trade =
    { netReturn : Float
    , holdingSteps : Int
    }


-- The simulation output consumed by the metrics and the chart
type alias Simulation =
    { equities : List Float
    , trades : List Trade
    }
