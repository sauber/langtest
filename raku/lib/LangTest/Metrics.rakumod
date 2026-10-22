use v6.d;

# Performance statistics computed from a finished simulation
unit module LangTest::Metrics;

use LangTest::Simulator;

# Reported metrics including the timings needed by the console report
class Metrics is export {
    has Int $.trade-count;
    has Int $.wins;
    has Int $.losses;
    has Num $.win-loss;
    has Num $.average-gain;
    has Num $.average-holding;
    has Num $.sharpe;
    has Bool $.sharpe-defined;
    has Num $.final-equity;
    has Num $.market-final;
    has Num $.beat-market;
    has Num $.elapsed;
}

# Derive every performance metric from the equity curve and closed trades
our sub compute-metrics(SimulationResult:D $result, Num:D $market-final --> Metrics) is export {
    my $equity := $result.equity;
    my Int $n = $equity.elems;
    my Num $sharpe = 0e0;
    my Bool $defined = False;
    if $n > 1 {
        my num @returns;
        my num $sum = 0e0;
        my num $previous = $equity[0];
        my Int $i = 1;
        while $i < $n {
            my num $value = $equity[$i];
            my num $return = $value / $previous - 1e0;
            @returns.push($return);
            $sum += $return;
            $previous = $value;
            $i++;
        }
        my num $count = @returns.elems.Num;
        my num $mean = $sum / $count;
        my num $squares = 0e0;
        for @returns -> num $return { $squares += ($return - $mean) ** 2 }
        if @returns.elems > 1 {
            my num $deviation = ($squares / ($count - 1e0)).sqrt;
            if $deviation > 0e0 {
                $sharpe = $mean / $deviation * 8760e0.sqrt;
                $defined = True;
            }
        }
    }

    my $trades := $result.trades;
    my Int $wins = 0;
    my Int $losses = 0;
    my num $gain-total = 0e0;
    my num $hold-total = 0e0;
    my Int $count = $trades.elems;
    for @$trades -> $trade {
        my num $return = $trade.net-return;
        if $return > 0e0 { $wins++ } elsif $return < 0e0 { $losses++ }
        $gain-total += $return;
        $hold-total += $trade.holding-steps;
    }

    my Num $win-loss;
    my Num $average-gain;
    my Num $average-holding;
    if $count == 0 {
        $win-loss = NaN;
        $average-gain = NaN;
        $average-holding = NaN;
    } else {
        $win-loss = $losses == 0 ?? Inf !! $wins / $losses.Num;
        $average-gain = $gain-total / $count.Num;
        $average-holding = $hold-total / $count.Num;
    }

    my Num $final = $result.final-equity;
    Metrics.new(
        trade-count => $count,
        :$wins,
        :$losses,
        :$win-loss,
        :$average-gain,
        :$average-holding,
        :$sharpe,
        sharpe-defined => $defined,
        final-equity => $final,
        market-final => $market-final,
        beat-market => $final / $market-final,
        elapsed => $result.elapsed,
    );
}
