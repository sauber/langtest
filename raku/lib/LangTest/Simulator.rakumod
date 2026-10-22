use v6.d;

# Hourly single-position trading simulator driven by precomputed signals
unit module LangTest::Simulator;

use LangTest::Clock;
use LangTest::Market;

# One completed round trip with its entry and exit values
class Trade is export {
    has Int $.buy-step;
    has Int $.sell-step;
    has Num $.cost;
    has Num $.proceeds;

    # Net return after both trading fees
    method net-return(--> Num) { $!proceeds / $!cost - 1e0 }

    # Number of hourly simulation steps the position stayed open
    method holding-steps(--> Int) { $!sell-step - $!buy-step }
}

# Outcome of one simulation run, including the full equity curve
class SimulationResult is export {
    has Num $.final-equity;
    has num @.equity;
    has Trade @.trades;
    has Num $.elapsed;
}

# Fixed-fee, single-position simulator with an injectable monotonic clock
class Simulator is export {
    has Num $.initial-capital = 10_000e0;
    has Num $.fee = 0.001e0;
    has MonotonicClock $.clock is required;

    # Step once through the timeline and return equity plus closed trades
    method run(Market:D $market --> SimulationResult) {
        my $coin-after := $market.coin-after;
        my $bar-step := $market.bar-step;
        my $bar-coin := $market.bar-coin;
        my $bar-close := $market.bar-close;
        my $bar-signal := $market.bar-signal;
        my $bar-strength := $market.bar-strength;
        my $step-first := $market.step-first;
        my $step-bars := $market.step-bars;

        my int @cursor;
        my Int $coins = $market.symbols.elems;
        my Int $ci = 0;
        while $ci < $coins {
            @cursor.push($market.coin-first[$ci]);
            $ci++;
        }

        my Int $steps = $market.step-count;
        my num $sell-factor = 1e0 - $!fee;
        my num $buy-factor = 1e0 + $!fee;
        my Num $cash = $!initial-capital;
        my Int $held = -1;
        my Num $quantity = 0e0;
        my Num $last = 0e0;
        my Int $entry-step = 0;
        my Num $entry-cost = 0e0;
        my num @equity = (0e0) xx $steps;
        my Trade @trades;

        my Num $started = $!clock.now;
        my Int $step = 0;
        while $step < $steps {
            if $held >= 0 {
                my int $cursor = @cursor[$held];
                my int $after = $coin-after[$held];
                while $cursor < $after && $bar-step[$cursor] < $step { $cursor++ }
                @cursor[$held] = $cursor;
                if $cursor < $after && $bar-step[$cursor] == $step {
                    my num $close = $bar-close[$cursor];
                    if $bar-signal[$cursor] == 2 {
                        my num $proceeds = $quantity * $close * $sell-factor;
                        $cash += $proceeds;
                        @trades.push(Trade.new(
                            buy-step => $entry-step,
                            sell-step => $step,
                            cost => $entry-cost,
                            proceeds => $proceeds,
                        ));
                        $held = -1;
                        $quantity = 0e0;
                    } else {
                        $last = $close;
                    }
                }
            }
            if $held < 0 {
                my int $at = $step-first[$step];
                my int $until = $step-first[$step + 1];
                my int $best = -1;
                my num $best-strength = -1e0;
                while $at < $until {
                    my int $bar = $step-bars[$at];
                    if $bar-signal[$bar] == 1 {
                        my num $strength = $bar-strength[$bar];
                        if $strength > $best-strength {
                            $best-strength = $strength;
                            $best = $bar;
                        }
                    }
                    $at++;
                }
                if $best >= 0 {
                    my num $close = $bar-close[$best];
                    $quantity = $cash / ($close * $buy-factor);
                    $entry-cost = $cash;
                    $entry-step = $step;
                    $cash = 0e0;
                    $held = $bar-coin[$best];
                    $last = $close;
                }
            }
            @equity[$step] = $cash + $quantity * $last;
            $step++;
        }
        my Num $elapsed = $!clock.now - $started;

        SimulationResult.new(
            final-equity => $steps > 0 ?? @equity[$steps - 1] !! $!initial-capital,
            :@equity,
            :@trades,
            :$elapsed,
        );
    }
}
