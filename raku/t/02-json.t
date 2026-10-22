use v6.d;

# Make the project modules visible to the test runner
use lib $?FILE.IO.parent.parent.add('lib').Str;

use Test;
use LangTest::Json;

plan 10;

# Parse a nested document covering every JSON value kind
my Str $raw = '{"n":1,"list":[true,false,null,-2.5,1e2],"obj":{"deep":"ok"},"s":"line\\ntab\\there"}';
my $doc = from-json($raw);

# Numbers decode into Num values
is-approx $doc<n>, 1e0, 1e-12, 'object number';

# Array order and scalar types are preserved
is $doc<list>[0], True, 'true literal';
is $doc<list>[1], False, 'false literal';
ok !$doc<list>[2].defined, 'null literal';
is-approx $doc<list>[3], -2.5e0, 1e-12, 'negative array number';
is-approx $doc<list>[4], 100e0, 1e-12, 'exponent number';

# Nested objects remain addressable
is $doc<obj><deep>, 'ok', 'nested object';

# Backslash escapes are decoded into real control characters
is $doc<s>, "line\ntab\there", 'string escapes';

# An empty array is valid
is from-json('[]').elems, 0, 'empty array';

# An empty object is valid
is from-json('{}').elems, 0, 'empty object';

done-testing;
