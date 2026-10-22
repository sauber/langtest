use v6.d;

# CSV loading and flat, step-indexed market representation
unit module LangTest::Market;

use LangTest::Metadata;
use LangTest::Num;
use LangTest::Strategy;

# Raw timestamp and close series for one downloaded coin
class CoinData is export {
    has Str $.symbol;
    has int @.timestamps;
    has num @.closes;
}

# Immutable flat bar store shared by the simulator and the chart
class Market is export {
    has Int $.step-count;
    has Int $.bar-count;
    has Str @.symbols;
    has int @.coin-first;
    has int @.coin-after;
    has int @.bar-step;
    has int @.bar-coin;
    has num @.bar-close;
    has int @.bar-signal;
    has num @.bar-strength;
    has int @.step-first;
    has int @.step-bars;
}

# Read one CSV file into parallel timestamp and close arrays
our sub load-coin(Str:D $path, Str:D $symbol --> CoinData) is export {
    my int @timestamps;
    my num @closes;
    my Str $text = slurp $path;
    my Str @lines = $text.split("\n");
    my Int $n = @lines.elems;
    my Int $i = 1;
    while $i < $n {
        my Str $line = @lines[$i];
        $i++;
        if $i == $n && $line.chars == 0 {
            next;
        }
        my int $ts = $line.substr(0, 10).Int;
        my int $c1 = $line.index(',', 36) // -1;
        my int $c2 = $line.index(',', $c1 + 1) // -1;
        my int $c3 = $line.index(',', $c2 + 1) // -1;
        my int $c4 = $line.index(',', $c3 + 1) // -1;
        @timestamps.push($ts);
        @closes.push(parse-decimal($line.substr($c3 + 1, $c4 - $c3 - 1)));
    }
    CoinData.new(:$symbol, :@timestamps, :@closes);
}

# Sorted distinct union of every bar timestamp in the data set
our sub timeline-of(CoinData @coins --> Array) is export {
    my %seen;
    for @coins -> $coin {
        for $coin.timestamps -> int $ts { %seen{$ts} = 1 }
    }
    %seen.keys.map(*.Int).sort.Array;
}

# Map every timeline timestamp to its zero-based simulation step
our sub step-map(@timeline --> Hash) is export {
    my %of;
    my int $i = 0;
    for @timeline -> $ts { %of{$ts.Int} = $i; $i++ }
    %of;
}

# Load every coin, run the strategy and flatten all bars for fast stepping
our sub load-market(Str:D $dir, Metadata:D $meta, Strategy:D $strategy --> Market) is export {
    my CoinData @coins = $meta.coins.sort(*.symbol).map({
        load-coin($dir ~ '/' ~ .file, .symbol);
    }).Array;

    my @timeline = timeline-of(@coins);
    my %step-of = step-map(@timeline);
    my Int $steps = @timeline.elems;

    my int @coin-first;
    my int @coin-after;
    my int @bar-step;
    my int @bar-coin;
    my num @bar-close;
    my int @bar-signal;
    my num @bar-strength;
    my int @count = (0) xx $steps;

    for @coins.kv -> $ci, $coin {
        @coin-first.push(@bar-step.elems);
        my $closes := $coin.closes;
        my $timestamps := $coin.timestamps;
        my $analysis = $strategy.analyse($closes);
        my int @signal = $analysis.signal;
        my num @strength = $analysis.strength;
        my Int $nb = $timestamps.elems;
        my Int $bi = 0;
        while $bi < $nb {
            my int $step = %step-of{$timestamps[$bi]};
            @bar-step.push($step);
            @bar-coin.push($ci);
            @bar-close.push($closes[$bi]);
            @bar-signal.push(@signal[$bi]);
            @bar-strength.push(@strength[$bi]);
            @count[$step] = @count[$step] + 1;
            $bi++;
        }
        @coin-after.push(@bar-step.elems);
    }

    my Int $bars = @bar-step.elems;
    my int @step-first = (0) xx ($steps + 1);
    my Int $total = 0;
    my Int $step = 0;
    while $step < $steps {
        @step-first[$step] = $total;
        $total += @count[$step];
        $step++;
    }
    @step-first[$steps] = $total;

    my int @step-bars = (0) xx $bars;
    my int @cursor = (0) xx $steps;
    $step = 0;
    while $step < $steps {
        @cursor[$step] = @step-first[$step];
        $step++;
    }
    my Int $bar = 0;
    while $bar < $bars {
        my int $owner = @bar-step[$bar];
        @step-bars[@cursor[$owner]] = $bar;
        @cursor[$owner] = @cursor[$owner] + 1;
        $bar++;
    }

    Market.new(
        step-count => $steps,
        bar-count => $bars,
        symbols => @coins».symbol,
        :@coin-first,
        :@coin-after,
        :@bar-step,
        :@bar-coin,
        :@bar-close,
        :@bar-signal,
        :@bar-strength,
        :@step-first,
        :@step-bars,
    );
}
