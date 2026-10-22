use v6.d;

# Make the project modules visible to the test runner
use lib $?FILE.IO.parent.parent.add('lib').Str;

use Test;
use LangTest::Format;
use LangTest::Metrics;

plan 5;

# Strip ANSI colour sequences to measure visible terminal width
sub visible(Str:D $line --> Str) {
    $line.subst(/\x1b\[\d+m/, '', :g);
}

# Representative metrics used to exercise every report label
my $metrics = Metrics.new(
    trade-count => 10,
    wins => 7,
    losses => 3,
    win-loss => 7e0 / 3e0,
    average-gain => 0.0215e0,
    average-holding => 12.5e0,
    sharpe => 1.25e0,
    sharpe-defined => True,
    final-equity => 123456.789e0,
    market-final => 100000e0,
    beat-market => 1.2345e0,
    elapsed => 0.123e0,
);

my @lines = report-lines($metrics, [10000e0, 11000e0, 12000e0], [10000e0, 10200e0, 10400e0]);

subtest 'report fits the terminal height' => {
    ok @lines.elems <= 25, 'at most twenty-five lines';
    is @lines.elems, 20, 'seven metrics plus thirteen chart lines';
};

subtest 'metric labels are present' => {
    ok @lines[0].starts-with('final equity'), 'final equity label';
    ok @lines[1].starts-with('vs market'), 'market ratio label';
    ok @lines[2].starts-with('sharpe ratio'), 'Sharpe label';
    ok @lines[3].starts-with('win/loss'), 'win/loss label';
    ok @lines[4].starts-with('avg gain'), 'average gain label';
    ok @lines[5].starts-with('avg hold'), 'holding time label';
};

subtest 'simulation time has three decimals' => {
    ok @lines[6] ~~ /^ 'sim' \s+ 'time' \s* ':' \s* \d+ \. \d ** 3 \s+ 's'$/, 'formatted seconds';
};

subtest 'values are formatted for humans' => {
    ok @lines[0].contains('123,456.79'), 'grouped equity';
    is @lines[3], 'win/loss     : 2.33 (10 trades)', 'ratio and trade count';
};

subtest 'every line fits the width budget' => {
    for @lines -> $line {
        ok visible($line).chars <= 80, 'line fits in eighty columns';
    }
};

done-testing;
