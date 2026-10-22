use v6.d;

# Two-series terminal line chart using soft box-drawing characters
unit module LangTest::Chart;

# ANSI colours distinguishing the strategy curve from the index curve
constant STRATEGY-COLOR = "\e[32m";
constant INDEX-COLOR    = "\e[36m";
constant RESET          = "\e[0m";

# Plot width between the frame borders
constant PLOT-WIDTH = 68;

# Plot height between the frame borders
constant PLOT-HEIGHT = 10;

# Compact human-readable scale label for the vertical axis
sub compact(Num $value --> Str) {
    my Num $size = $value.abs;
    return sprintf('%.2fB', $value / 1e9) if $size >= 1e9;
    return sprintf('%.2fM', $value / 1e6) if $size >= 1e6;
    return sprintf('%.1fK', $value / 1e3) if $size >= 1e3;
    sprintf('%.0f', $value);
}

# Render a legend and a framed two-line chart as terminal output lines
our sub render-chart(@strategy, @index --> List) is export {
    my Num $maximum = -Inf;
    my Num $minimum = Inf;
    for @strategy -> $value {
        my Num $v = $value.Num;
        $maximum = $v if $v > $maximum;
        $minimum = $v if $v < $minimum;
    }
    for @index -> $value {
        my Num $v = $value.Num;
        $maximum = $v if $v > $maximum;
        $minimum = $v if $v < $minimum;
    }
    $maximum = $minimum + 1e0 if $maximum == $minimum;

    my @chars = ' ' xx (PLOT-WIDTH * PLOT-HEIGHT);
    my @hues = 0 xx (PLOT-WIDTH * PLOT-HEIGHT);

    my @series = (
        (@index.item, 1),
        (@strategy.item, 2),
    );
    for @series -> $series {
        my $values = $series[0];
        my Int $hue = $series[1];
        my Int $n = $values.elems;
        my Int $previous = -1;
        my Int $column = 0;
        while $column < PLOT-WIDTH {
            my Int $sample = $n <= 1
                ?? 0
                !! (($column * ($n - 1)).Num / (PLOT-WIDTH - 1)).floor.Int;
            my Num $value = $values[$sample].Num;
            my Num $ratio = ($value - $minimum) / ($maximum - $minimum);
            my Int $row = PLOT-HEIGHT - 1 - ($ratio * (PLOT-HEIGHT - 1)).floor.Int;
            $row = 0 if $row < 0;
            $row = PLOT-HEIGHT - 1 if $row >= PLOT-HEIGHT;
            if $previous < 0 {
                my Int $pos = $row * PLOT-WIDTH + $column;
                @chars[$pos] = '─';
                @hues[$pos] = $hue;
            } else {
                my Int $low = $previous < $row ?? $previous !! $row;
                my Int $high = $previous > $row ?? $previous !! $row;
                my Int $r = $low;
                while $r <= $high {
                    my Int $pos = $r * PLOT-WIDTH + $column;
                    @chars[$pos] = '│';
                    @hues[$pos] = $hue;
                    $r++;
                }
                my Int $pos = $row * PLOT-WIDTH + $column;
                @chars[$pos] = '─';
                @hues[$pos] = $hue;
            }
            $previous = $row;
            $column++;
        }
    }

    my @lines;
    @lines.push(
        'strategy ' ~ STRATEGY-COLOR ~ '────' ~ RESET
        ~ '   index ' ~ INDEX-COLOR ~ '────' ~ RESET
    );
    @lines.push(' ' x 7 ~ '╭' ~ '─' x PLOT-WIDTH ~ '╮');
    my Int $row = 0;
    while $row < PLOT-HEIGHT {
        my Str $body = '';
        my Int $current = 0;
        my Int $column = 0;
        while $column < PLOT-WIDTH {
            my Int $pos = $row * PLOT-WIDTH + $column;
            my Int $hue = @hues[$pos];
            if $hue != $current {
                $body ~= RESET if $current != 0;
                $body ~= STRATEGY-COLOR if $hue == 2;
                $body ~= INDEX-COLOR if $hue == 1;
                $current = $hue;
            }
            $body ~= @chars[$pos];
            $column++;
        }
        $body ~= RESET if $current != 0;
        my Str $label = $row == 0
            ?? compact($maximum)
            !! $row == PLOT-HEIGHT - 1
                ?? compact($minimum)
                !! '';
        @lines.push(sprintf('%7s', $label) ~ '│' ~ $body ~ '│');
        $row++;
    }
    @lines.push(' ' x 7 ~ '╰' ~ '─' x PLOT-WIDTH ~ '╯');
    @lines;
}
