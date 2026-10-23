module Strategy exposing (buyThreshold, sellThreshold, signal, strength)

import Domain exposing (Signal(..))

{-| Swappable strategy: oversold buys, overbought sells, otherwise pass.
-}


-- RSI at or below this level is a buy
buyThreshold : Float
buyThreshold =
    30


-- RSI at or above this level is a sell
sellThreshold : Float
sellThreshold =
    70


-- Turn one RSI reading into a signal
signal : Float -> Signal
signal rsi =
    if rsi <= buyThreshold then
        Buy

    else if rsi >= sellThreshold then
        Sell

    else
        Pass


-- Numeric buy strength: bigger means more oversold
strength : Float -> Float
strength rsi =
    buyThreshold - rsi
