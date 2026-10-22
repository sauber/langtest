use v6.d;

# Make the project modules visible to the test runner
use lib $?FILE.IO.parent.parent.add('lib').Str;

use Test;
use LangTest::Clock;
use LangTest::Market;
use LangTest::Simulator;

plan 8;

# Deterministic clock returning preset monotonic readings in order
class FakeClock does MonotonicClock {
    has Num @.ticks;
    method now(--> Num) { @!ticks.shift }
}

# Build a small in-memory market from flat bar quadruples grouped per coin
sub make-market(Int $steps, :@symbols!, :@bar-data!, :@coin-bars! --> Market) {
    my int @coin-first;
    my int @coin-after;
    my int @bar-step;
    my int @bar-coin;
    my num @bar-close;
    my int @bar-signal;
    my num @bar-strength;
    my int @count = (0) xx $steps;
    my Int $offset = 0;
    for @symbols.kv -> $ci, $symbol {
        @coin-first.push(@bar-step.elems);
        my Int $end = $offset + @coin-bars[$ci] * 4;
        while $offset < $end {
            my int $step = @bar-data[$offset];
            @bar-step.push($step);
            @bar-coin.push($ci);
            @bar-close.push(@bar-data[$offset + 1]);
            @bar-signal.push(@bar-data[$offset + 2]);
            @bar-strength.push(@bar-data[$offset + 3]);
            @count[$step] = @count[$step] + 1;
            $offset += 4;
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
        symbols => @symbols,
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

subtest 'fees and holding valuation' => {
    my $market = make-market(3,
        symbols => ['AAA'],
        bar-data => [0, 100e0, 1, 5e0, 1, 110e0, 0, 0e0, 2, 120e0, 2, 0e0],
        coin-bars => [3],
    );
    my $clock = FakeClock.new(ticks => [0e0, 0.25e0]);
    my $result = Simulator.new(clock => $clock).run($market);
    my Num $quantity = 10_000e0 / (100e0 * 1.001e0);
    my Num $proceeds = $quantity * 120e0 * 0.999e0;
    is-approx $result.final-equity, $proceeds, 1e-6, 'buy and sell fees applied';
    is-approx $result.equity[0], $quantity * 100e0, 1e-9, 'entry fee reduces equity';
    is $result.trades.elems, 1, 'one closed trade';
    is-approx $result.trades[0].net-return, $proceeds / 10_000e0 - 1e0, 1e-12, 'net trade return';
    is $result.trades[0].holding-steps, 2, 'holding time in steps';
    is-approx $result.elapsed, 0.25e0, 1e-12, 'monotonic clock reading';
};

subtest 'highest buy strength wins' => {
    my $market = make-market(2,
        symbols => ['AAA', 'BBB'],
        bar-data => [
            0, 100e0, 1, 5e0, 1, 90e0, 2, 0e0,
            0, 200e0, 1, 6e0, 1, 250e0, 2, 0e0,
        ],
        coin-bars => [2, 2],
    );
    my $result = Simulator.new(clock => FakeClock.new(ticks => [0e0, 0e0])).run($market);
    my Num $quantity = 10_000e0 / (200e0 * 1.001e0);
    is-approx $result.final-equity, $quantity * 250e0 * 0.999e0, 1e-6, 'stronger coin bought';
    is $result.trades.elems, 1, 'only one position opened';
};

subtest 'alphabetical tie break' => {
    my $market = make-market(2,
        symbols => ['AAA', 'BBB'],
        bar-data => [
            0, 100e0, 1, 5e0, 1, 90e0, 2, 0e0,
            0, 200e0, 1, 5e0, 1, 250e0, 2, 0e0,
        ],
        coin-bars => [2, 2],
    );
    my $result = Simulator.new(clock => FakeClock.new(ticks => [0e0, 0e0])).run($market);
    my Num $quantity = 10_000e0 / (100e0 * 1.001e0);
    is-approx $result.final-equity, $quantity * 90e0 * 0.999e0, 1e-6, 'AAA wins equal strength';
};

subtest 'data gap carries the position' => {
    my $market = make-market(4,
        symbols => ['AAA', 'BBB'],
        bar-data => [
            0, 100e0, 1, 5e0, 1, 110e0, 0, 0e0, 3, 130e0, 2, 0e0,
            2, 50e0, 1, 9e0,
        ],
        coin-bars => [3, 1],
    );
    my $result = Simulator.new(clock => FakeClock.new(ticks => [0e0, 0e0])).run($market);
    my Num $quantity = 10_000e0 / (100e0 * 1.001e0);
    is-approx $result.equity[2], $quantity * 110e0, 1e-9, 'valued at last known close';
    is-approx $result.final-equity, $quantity * 130e0 * 0.999e0, 1e-6, 'sell after gap';
    is $result.trades.elems, 1, 'no second purchase while holding';
};

subtest 'single position blocks other coins' => {
    my $market = make-market(3,
        symbols => ['AAA', 'BBB'],
        bar-data => [
            0, 100e0, 1, 5e0, 2, 100e0, 2, 0e0,
            1, 50e0, 1, 9e0, 2, 60e0, 2, 0e0,
        ],
        coin-bars => [2, 2],
    );
    my $result = Simulator.new(clock => FakeClock.new(ticks => [0e0, 0e0])).run($market);
    is $result.trades.elems, 1, 'only the original position trades';
    is-approx $result.final-equity, 10_000e0 / 1.001e0 * 0.999e0, 1e-6, 'cash never switched coins';
};

subtest 're-entry in the same step is allowed' => {
    my $market = make-market(3,
        symbols => ['AAA', 'BBB'],
        bar-data => [
            0, 100e0, 1, 5e0, 1, 110e0, 2, 0e0,
            0, 50e0, 0, 0e0, 1, 60e0, 1, 4e0, 2, 70e0, 2, 0e0,
        ],
        coin-bars => [2, 3],
    );
    my $result = Simulator.new(clock => FakeClock.new(ticks => [0e0, 0e0])).run($market);
    my Num $first = 10_000e0 / (100e0 * 1.001e0) * 110e0 * 0.999e0;
    my Num $second = $first / (60e0 * 1.001e0) * 70e0 * 0.999e0;
    is $result.trades.elems, 2, 'sell then buy in one step';
    is-approx $result.final-equity, $second, 1e-6, 'second position valued correctly';
};

subtest 'no signal leaves capital idle' => {
    my $market = make-market(2,
        symbols => ['AAA'],
        bar-data => [0, 100e0, 0, 0e0, 1, 120e0, 0, 0e0],
        coin-bars => [2],
    );
    my $result = Simulator.new(clock => FakeClock.new(ticks => [0e0, 0e0])).run($market);
    is $result.trades.elems, 0, 'no trades';
    is-approx $result.final-equity, 10_000e0, 1e-12, 'capital unchanged';
};

subtest 'empty market returns initial capital' => {
    my $market = make-market(0, symbols => [], bar-data => [], coin-bars => []);
    my $result = Simulator.new(clock => FakeClock.new(ticks => [0e0, 0e0])).run($market);
    is-approx $result.final-equity, 10_000e0, 1e-12, 'initial capital';
    is $result.equity.elems, 0, 'empty equity curve';
};

done-testing;
