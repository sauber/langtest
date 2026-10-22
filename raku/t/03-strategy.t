use v6.d;

# Make the project modules visible to the test runner
use lib $?FILE.IO.parent.parent.add('lib').Str;

use Test;
use LangTest::Strategy;

plan 8;

# Classic Wilder fixture with precomputed expected RSI values
my num @closes = <44.34 44.09 44.15 43.61 44.33 44.83 45.10 45.42 45.84 46.08
    45.89 46.03 45.61 46.28 46.28 46.00 46.03 46.41 46.22 45.64 46.21 46.25
    45.71 46.45 45.78 45.35 44.03 44.18 44.22 44.57 43.42 42.66 43.13>.map(*.Num);

subtest 'Wilder smoothing fixture' => {
    my $strategy = RsiStrategy.new;
    my @rsi = $strategy.rsi-series(@closes);
    ok @rsi[12].isNaN, 'no value before fourteen closes';
    is-approx @rsi[13], 70.46413502109704e0, 1e-9, 'seed value';
    is-approx @rsi[14], 70.46413502109705e0, 1e-9, 'first smoothed value';
    is-approx @rsi[15], 66.24961855355505e0, 1e-9, 'second smoothed value';
    is-approx @rsi[32], 37.78877198205782e0, 1e-9, 'tail value';
};

subtest 'threshold signals and strengths' => {
    my $strategy = RsiStrategy.new;
    my $analysis = $strategy.analyse(@closes);
    is $analysis.signal[12], 0, 'no signal during warmup';
    is $analysis.signal[13], 2, 'overbought bar sells';
    is $analysis.signal[15], 0, 'neutral bar passes';
    is $analysis.strength[13], 0e0, 'sell bars carry no buy strength';
};

subtest 'monotonic rising prices produce sells' => {
    my num @rising = (1..20).map(*.Num);
    my $analysis = RsiStrategy.new.analyse(@rising);
    is $analysis.signal[19], 2, 'streak up is overbought';
    is $analysis.signal[13], 2, 'first valid bar is overbought';
};

subtest 'monotonic falling prices produce buys' => {
    my num @falling = (20, 19 ... 1).map(*.Num);
    my $analysis = RsiStrategy.new.analyse(@falling);
    is $analysis.signal[19], 1, 'streak down is oversold';
    is-approx $analysis.strength[19], 30e0, 1e-9, 'full buy strength';
};

subtest 'custom thresholds' => {
    my $strategy = RsiStrategy.new(buy-level => 40e0, sell-level => 60e0);
    my $analysis = $strategy.analyse(@closes);
    is $analysis.signal[25], 0, 'custom band passes mid range';
    is $analysis.signal[13], 2, 'custom sell level reached';
};

subtest 'short series stays undefined' => {
    my num @short = (1..10).map(*.Num);
    my @rsi = RsiStrategy.new.rsi-series(@short);
    ok @rsi[9].isNaN, 'too few closes';
    my $analysis = RsiStrategy.new.analyse(@short);
    is $analysis.signal[9], 0, 'no signal without RSI';
};

subtest 'analyse vector lengths match input' => {
    my $analysis = RsiStrategy.new.analyse(@closes);
    is $analysis.signal.elems, @closes.elems, 'signal vector length';
    is $analysis.strength.elems, @closes.elems, 'strength vector length';
};

subtest 'period is configurable' => {
    my $strategy = RsiStrategy.new(period => 2);
    my num @prices = (1e0, 2e0, 3e0, 4e0);
    my @rsi = $strategy.rsi-series(@prices);
    ok @rsi[0].isNaN, 'first bar undefined';
    is-approx @rsi[1], 100e0, 1e-12, 'two-price period';
};

done-testing;
