use v6.d;

# Metadata model for the downloaded KuCoin market data
unit module LangTest::Metadata;

use LangTest::Json;

# Description of one downloaded coin file
class CoinInfo is export {
    has Str $.symbol;
    has Str $.file;
    has Int $.rows;
    has Int $.first-timestamp;
    has Int $.last-timestamp;
}

# Everything the evaluator needs from data/meta.json
class Metadata is export {
    has Int $.steps;
    has Int $.first-timestamp;
    has Int $.last-timestamp;
    has CoinInfo @.coins;
    has num @.index-values;

    # Read and decode the metadata document from disk
    method load(Str:D $path --> Metadata) {
        my $doc = from-json(slurp $path);
        my CoinInfo @coins = $doc<coins>.map({
            CoinInfo.new(
                symbol => $_<symbol>,
                file => $_<file>,
                rows => $_<rows>.Int,
                first-timestamp => $_<firstTimestamp>.Int,
                last-timestamp => $_<lastTimestamp>.Int,
            );
        }).Array;
        my num @values = $doc<marketIndex><values>.map({ $_.Num }).Array;
        Metadata.new(
            steps => $doc<timeline><steps>.Int,
            first-timestamp => $doc<timeline><firstTimestamp>.Int,
            last-timestamp => $doc<timeline><lastTimestamp>.Int,
            :@coins,
            index-values => @values,
        );
    }
}
