use v6.d;

# Make the project modules visible to the test runner
use lib $?FILE.IO.parent.parent.add('lib').Str;

use Test;
use LangTest::Num;

plan 6;

# Whole numbers are parsed without a fractional part
is-approx parse-decimal('4307'), 4307e0, 1e-12, 'integer text';

# Leading zeros in the fraction are handled by digit scaling
is-approx parse-decimal('0.00001234'), 0.00001234e0, 1e-12, 'small fraction';

# A minus sign is applied after the magnitude is decoded
is-approx parse-decimal('-12.5'), -12.5e0, 1e-12, 'negative decimal';

# A trailing dot without digits yields the whole part
is-approx parse-decimal('42.'), 42e0, 1e-12, 'empty fraction';

# Zero parses as an exact Num zero
is-approx parse-decimal('0.0'), 0e0, 1e-12, 'zero';

# Long fractions keep full double precision
is-approx parse-decimal('5699.999999'), 5699.999999e0, 1e-9, 'six decimals';

done-testing;
