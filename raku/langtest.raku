#!/usr/bin/env raku
use v6.d;

# Load the project modules whether started from the repo root or the raku folder
use lib $?FILE.IO.parent.add('lib').Str;

use LangTest::Clock;
use LangTest::Format;
use LangTest::Market;
use LangTest::Metadata;
use LangTest::Metrics;
use LangTest::Simulator;
use LangTest::Strategy;

# Resolve the shared market data directory relative to this script
my IO::Path $data-dir = $?FILE.IO.parent.parent.add('data');
$data-dir = 'data'.IO unless $data-dir.d;

# Decode the dataset description and the precomputed market index
my $metadata = LangTest::Metadata::Metadata.load($data-dir.add('meta.json').Str);

# Load every coin, analyse it and flatten the bars for fast stepping
my $market = LangTest::Market::load-market($data-dir.Str, $metadata, RsiStrategy.new);

# Run the timed hourly simulation with the real monotonic clock
my $result = LangTest::Simulator::Simulator.new(clock => PosixClock.new).run($market);

# Derive all performance metrics from the equity curve and closed trades
my $metrics = LangTest::Metrics::compute-metrics($result, $metadata.index-values[*-1]);

# Print the metrics and the two-series chart within the terminal budget
say LangTest::Format::report-lines($metrics, $result.equity, $metadata.index-values).join("\n");
