use v6.d;

# Make the project modules visible to the test runner
use lib $?FILE.IO.parent.parent.add('lib').Str;

use Test;
use LangTest::Chart;

plan 6;

# Strip ANSI colour sequences to measure visible terminal width
sub visible(Str:D $line --> Str) {
    $line.subst(/\x1b\[\d+m/, '', :g);
}

my @lines = render-chart(
    [10000e0, 12000e0, 11000e0, 13000e0, 12500e0],
    [10000e0, 10100e0, 10200e0, 10300e0, 10400e0],
);

subtest 'chart shape' => {
    is @lines.elems, 13, 'legend plus framed ten-row plot';
};

subtest 'frame characters' => {
    is @lines[1].substr(7, 1), '╭', 'top-left corner';
    is @lines[1].substr(@lines[1].chars - 1, 1), '╮', 'top-right corner';
    is @lines[12].substr(7, 1), '╰', 'bottom-left corner';
    is @lines[12].substr(@lines[12].chars - 1, 1), '╯', 'bottom-right corner';
    is @lines[2].substr(7, 1), '│', 'left border';
};

subtest 'two coloured series' => {
    ok @lines[0].contains("\e[32m"), 'strategy colour in legend';
    ok @lines[0].contains("\e[36m"), 'index colour in legend';
    is @lines[0].subst(/\x1b\[\d+m/, '', :g), 'strategy ────   index ────', 'legend text';
};

subtest 'terminal width budget' => {
    for @lines -> $line {
        ok visible($line).chars <= 80, 'line fits in eighty columns';
    }
};

subtest 'flat series do not divide by zero' => {
    my @flat = render-chart([100e0, 100e0, 100e0], [100e0, 100e0, 100e0]);
    is @flat.elems, 13, 'flat chart still renders';
};

subtest 'single sample is safe' => {
    my @single = render-chart([100e0], [50e0]);
    is @single.elems, 13, 'one-point series renders';
    ok @single[0].contains('strategy'), 'legend present';
};

done-testing;
