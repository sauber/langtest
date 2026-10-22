use v6.d;

# Fast numeric parsing shared by the market and metadata loaders
unit module LangTest::Num;

# Powers of ten used to scale fractions without repeated exponentiation
my num @scale = (0..18).map({ 10e0 ** $_ });

# Parse a plain decimal string into a Num without generic string-to-number dispatch
our sub parse-decimal(Str:D $s --> Num) is export {
    my Bool $negative = $s.starts-with('-');
    my Str $body = $negative ?? $s.substr(1) !! $s;
    my Int $dot = $body.index('.') // -1;
    my Num $value;
    if $dot < 0 {
        $value = $body.Int.Num;
    } else {
        my Int $whole = $body.substr(0, $dot).Int;
        my Str $fraction = $body.substr($dot + 1);
        my Int $length = $fraction.chars;
        if $length == 0 {
            $value = $whole.Num;
        } elsif $length < @scale.elems {
            $value = $whole.Num + $fraction.Int.Num / @scale[$length];
        } else {
            $value = $whole.Num + $fraction.Int.Num / 10 ** $length;
        }
    }
    $negative ?? -$value !! $value;
}
