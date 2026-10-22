use v6.d;

# Signal generation for the mean-reversion trading strategy
unit module LangTest::Strategy;

# Single-bar trading decision produced by a strategy
enum Signal is export (Pass => 0, Buy => 1, Sell => 2);

# Per-bar decision vectors produced once before the simulation starts
class Analysis is export {
    has int @.signal;
    has num @.strength;
}

# Contract every swappable trading strategy implements
role Strategy is export {
    # Produce signal and strength vectors for every close in the series
    method analyse(num @close --> Analysis) { ... }
}

# RSI mean-reversion strategy: buy oversold closes, sell overbought closes
class RsiStrategy does Strategy is export {
    has Int $.period = 14;
    has Num $.buy-level = 30e0;
    has Num $.sell-level = 70e0;

    # Wilder-smoothed RSI series where NaN marks bars without a value yet
    method rsi-series(num @close --> Positional) {
        my Int $n = @close.elems;
        my num @rsi = (NaN) xx $n;
        my Int $period = $!period;
        return @rsi if $n < $period;
        my num $gain = 0e0;
        my num $loss = 0e0;
        my Int $i = 1;
        while $i < $period {
            my num $delta = @close[$i] - @close[$i - 1];
            if $delta > 0e0 { $gain += $delta } else { $loss -= $delta }
            $i++;
        }
        my num $avg-gain = $gain / ($period - 1e0);
        my num $avg-loss = $loss / ($period - 1e0);
        $i = $period - 1;
        @rsi[$i] = $avg-loss == 0e0 ?? 100e0 !! 100e0 - 100e0 / (1e0 + $avg-gain / $avg-loss);
        $i = $period;
        my num $prior = ($period - 1).Num;
        my num $scale = $period.Num;
        while $i < $n {
            my num $delta = @close[$i] - @close[$i - 1];
            if $delta > 0e0 {
                $avg-gain = ($avg-gain * $prior + $delta) / $scale;
                $avg-loss = $avg-loss * $prior / $scale;
            } else {
                $avg-gain = $avg-gain * $prior / $scale;
                $avg-loss = ($avg-loss * $prior - $delta) / $scale;
            }
            @rsi[$i] = $avg-loss == 0e0 ?? 100e0 !! 100e0 - 100e0 / (1e0 + $avg-gain / $avg-loss);
            $i++;
        }
        @rsi;
    }

    # Convert a close series into signal and buy-strength vectors
    method analyse(num @close --> Analysis) {
        my Int $n = @close.elems;
        my int @signal = (0) xx $n;
        my num @strength = (0e0) xx $n;
        my @rsi = self.rsi-series(@close);
        my Num $buy = $!buy-level;
        my Num $sell = $!sell-level;
        my Int $i = $!period - 1;
        while $i < $n {
            my num $rsi = @rsi[$i];
            if $rsi <= $buy {
                @signal[$i] = 1;
                @strength[$i] = $buy - $rsi;
            } elsif $rsi >= $sell {
                @signal[$i] = 2;
            }
            $i++;
        }
        Analysis.new(:@signal, :@strength);
    }
}
