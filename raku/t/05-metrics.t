use v6.d;

# Make the project modules visible to the test runner
use lib $?FILE.IO.parent.parent.add('lib').Str;

use Test;
use LangTest::Metrics;
use LangTest::Simulator;

plan 7;

# A hand-computed trade sequence with one win, one loss and one flat trade
sub sample-result(--> SimulationResult) {
    SimulationResult.new(
        final-equity => 108.9e0,
        equity => [100e0, 110e0, 99e0, 108.9e0],
        trades => [
            Trade.new(buy-step => 0, sell-step => 3, cost => 100e0, proceeds => 110e0),
            Trade.new(buy-step => 1, sell-step => 2, cost => 200e0, proceeds => 180e0),
            Trade.new(buy-step => 2, sell-step => 4, cost => 100e0, proceeds => 100e0),
        ],
        elapsed => 0.5e0,
    );
}

subtest 'counts and averages' => {
    my $metrics = compute-metrics(sample-result(), 100e0);
    is $metrics.trade-count, 3, 'closed trades';
    is $metrics.wins, 1, 'winning trades';
    is $metrics.losses, 1, 'losing trades';
    is-approx $metrics.win-loss, 1e0, 1e-12, 'win/loss ratio';
    is-approx $metrics.average-gain, 0e0, 1e-12, 'flat trade included in mean';
    is-approx $metrics.average-holding, 2e0, 1e-12, 'mean holding steps';
    is-approx $metrics.beat-market, 1.089e0, 1e-12, 'final equity versus index';
    is-approx $metrics.elapsed, 0.5e0, 1e-12, 'simulation time propagated';
};

subtest 'Sharpe ratio uses hourly sample deviation' => {
    my $metrics = compute-metrics(sample-result(), 100e0);
    ok $metrics.sharpe-defined, 'Sharpe is defined';
    is-approx $metrics.sharpe, 27.01851217221264e0, 1e-9, 'annualised Sharpe';
};

subtest 'single return has no sample deviation' => {
    my $result = SimulationResult.new(
        final-equity => 110e0,
        equity => [100e0, 110e0],
        trades => [Trade.new(buy-step => 0, sell-step => 1, cost => 100e0, proceeds => 110e0)],
        elapsed => 0e0,
    );
    my $metrics = compute-metrics($result, 100e0);
    ok !$metrics.sharpe-defined, 'Sharpe unavailable';
};

subtest 'zero deviation is reported as N/A' => {
    my $result = SimulationResult.new(
        final-equity => 121e0,
        equity => [100e0, 110e0, 121e0],
        trades => [Trade.new(buy-step => 0, sell-step => 2, cost => 100e0, proceeds => 121e0)],
        elapsed => 0e0,
    );
    my $metrics = compute-metrics($result, 100e0);
    ok !$metrics.sharpe-defined, 'constant return has no deviation';
};

subtest 'all-winning trades report infinite ratio' => {
    my $result = SimulationResult.new(
        final-equity => 110e0,
        equity => [100e0, 110e0, 121e0],
        trades => [
            Trade.new(buy-step => 0, sell-step => 1, cost => 100e0, proceeds => 110e0),
            Trade.new(buy-step => 1, sell-step => 2, cost => 100e0, proceeds => 110e0),
        ],
        elapsed => 0e0,
    );
    my $metrics = compute-metrics($result, 100e0);
    ok $metrics.win-loss == Inf, 'infinite win/loss';
};

subtest 'no trades yields undefined averages' => {
    my $result = SimulationResult.new(
        final-equity => 100e0,
        equity => [100e0, 100e0],
        trades => [],
        elapsed => 0e0,
    );
    my $metrics = compute-metrics($result, 100e0);
    is $metrics.trade-count, 0, 'no closed trades';
    ok $metrics.win-loss.isNaN, 'win/loss undefined';
    ok $metrics.average-gain.isNaN, 'average gain undefined';
    ok $metrics.average-holding.isNaN, 'average holding undefined';
};

subtest 'index ratio below one signals underperformance' => {
    my $metrics = compute-metrics(sample-result(), 200e0);
    ok $metrics.beat-market < 1e0, 'strategy trailed the index';
    is-approx $metrics.beat-market, 108.9e0 / 200e0, 1e-12, 'exact ratio';
};

done-testing;
