use v6.d;

# Console report layout constrained to an 80x25 terminal
unit module LangTest::Format;

use LangTest::Chart;
use LangTest::Metrics;

# Insert thousands separators into an integer digit string
sub grouped(Str:D $digits --> Str) {
    my Str $out = '';
    my Int $n = $digits.chars;
    my Int $i = 0;
    while $i < $n {
        $out ~= ',' if $i > 0 && ($n - $i) % 3 == 0;
        $out ~= $digits.substr($i, 1);
        $i++;
    }
    $out;
}

# Format a Num with fixed decimals and grouped thousands
sub grouped-num(Num $value, Int $decimals --> Str) {
    my Str $fixed = sprintf("%.{$decimals}f", $value);
    my Int $dot = $fixed.index('.') // -1;
    my Str $whole = $dot >= 0 ?? $fixed.substr(0, $dot) !! $fixed;
    my Str $fraction = $dot >= 0 ?? $fixed.substr($dot) !! '';
    my Bool $negative = $whole.starts-with('-');
    $whole = $whole.substr(1) if $negative;
    ($negative ?? '-' !! '') ~ grouped($whole) ~ $fraction;
}

# Build the complete report as lines no wider than 80 characters
our sub report-lines(Metrics:D $metrics, @strategy, @index --> List) is export {
    my @lines;
    @lines.push('final equity : ' ~ grouped-num($metrics.final-equity, 2) ~ ' USDT');
    my Str $beat = $metrics.beat-market.isNaN
        ?? 'N/A'
        !! sprintf('%.3f', $metrics.beat-market);
    @lines.push('vs market    : ' ~ $beat);
    my Str $sharpe = $metrics.sharpe-defined
        ?? sprintf('%.3f', $metrics.sharpe)
        !! 'N/A';
    @lines.push('sharpe ratio : ' ~ $sharpe);
    my Str $ratio;
    if $metrics.trade-count == 0 {
        $ratio = 'N/A';
    } elsif $metrics.win-loss == Inf {
        $ratio = 'inf';
    } else {
        $ratio = sprintf('%.2f', $metrics.win-loss);
    }
    @lines.push('win/loss     : ' ~ $ratio ~ ' (' ~ $metrics.trade-count ~ ' trades)');
    my Str $gain = $metrics.average-gain.isNaN
        ?? 'N/A'
        !! sprintf('%.3f %%', $metrics.average-gain * 100e0);
    @lines.push('avg gain     : ' ~ $gain);
    my Str $holding = $metrics.average-holding.isNaN
        ?? 'N/A'
        !! sprintf('%.1f h', $metrics.average-holding);
    @lines.push('avg hold     : ' ~ $holding);
    @lines.push('sim time     : ' ~ sprintf('%.3f s', $metrics.elapsed));
    @lines.append(render-chart(@strategy, @index));
    @lines;
}
