use v6.d;

# Minimal recursive-descent JSON reader for the downloaded metadata
unit module LangTest::Json;

use LangTest::Num;

# Cursor-based JSON parser over one immutable document string
class Parser {
    has Str $.text;
    has Int $!pos = 0;

    # Consume the next value and advance the cursor
    method parse(--> Any) {
        self!skip-ws;
        my Str $c = $!text.substr($!pos, 1);
        return self!object if $c eq '{';
        return self!array if $c eq '[';
        return self!string if $c eq '"';
        if $c eq 't' { $!pos += 4; return True }
        if $c eq 'f' { $!pos += 5; return False }
        if $c eq 'n' { $!pos += 4; return Any }
        self!number;
    }

    # Skip insignificant whitespace between tokens
    method !skip-ws() {
        my Str $s = $!text;
        my Int $n = $s.chars;
        my Int $i = $!pos;
        while $i < $n {
            my Str $c = $s.substr($i, 1);
            last unless $c eq ' ' || $c eq "\n" || $c eq "\t" || $c eq "\r";
            $i++;
        }
        $!pos = $i;
    }

    # Parse an object into a hash of decoded keys and values
    method !object(--> Hash) {
        $!pos++;
        my %out;
        self!skip-ws;
        if $!text.substr($!pos, 1) eq '}' { $!pos++; return %out }
        loop {
            self!skip-ws;
            my Str $key = self!string;
            self!skip-ws;
            $!pos++;
            %out{$key} = self.parse;
            self!skip-ws;
            my Str $c = $!text.substr($!pos, 1);
            $!pos++;
            last if $c eq '}';
        }
        %out;
    }

    # Parse an array into a list of decoded values
    method !array(--> Array) {
        $!pos++;
        my @out;
        self!skip-ws;
        if $!text.substr($!pos, 1) eq ']' { $!pos++; return @out }
        loop {
            @out.push(self.parse);
            self!skip-ws;
            my Str $c = $!text.substr($!pos, 1);
            $!pos++;
            last if $c eq ']';
        }
        @out;
    }

    # Parse a quoted string, decoding escape sequences when present
    method !string(--> Str) {
        $!pos++;
        my Int $start = $!pos;
        my Int $end = $!text.index('"', $start) // die "Unterminated JSON string";
        my Str $raw = $!text.substr($start, $end - $start);
        $!pos = $end + 1;
        return $raw if ($raw.index('\\') // -1) < 0;
        self!unescape($raw);
    }

    # Decode the standard JSON backslash escapes inside a raw string body
    method !unescape(Str:D $raw --> Str) {
        my Str $out = '';
        my Int $i = 0;
        my Int $n = $raw.chars;
        while $i < $n {
            my Str $c = $raw.substr($i, 1);
            unless $c eq '\\' { $out ~= $c; $i++; next }
            my Str $e = $raw.substr($i + 1, 1);
            $out ~= do given $e {
                when '"'  { '"' }
                when '\\' { '\\' }
                when '/'  { '/' }
                when 'n'  { "\n" }
                when 't'  { "\t" }
                when 'r'  { "\r" }
                when 'b'  { "\b" }
                when 'f'  { "\f" }
                when 'u'  { $raw.substr($i + 2, 4).parse-base(16).chr }
                default   { $e }
            };
            $i += $e eq 'u' ?? 6 !! 2;
        }
        $out;
    }

    # Parse a JSON number, delegating plain decimals to the fast parser
    method !number(--> Num) {
        my Str $s = $!text;
        my Int $n = $s.chars;
        my Int $start = $!pos;
        my Int $i = $start;
        my Bool $exponent = False;
        while $i < $n {
            my Str $c = $s.substr($i, 1);
            if $c eq '.' || $c eq '-' || $c eq '+' { $i++; next }
            if $c eq 'e' || $c eq 'E' { $exponent = True; $i++; next }
            my Int $code = $c.ord;
            last if $code < 48 || $code > 57;
            $i++;
        }
        $!pos = $i;
        my Str $raw = $s.substr($start, $i - $start);
        $exponent ?? $raw.Num !! parse-decimal($raw);
    }
}

# Parse a complete JSON document into hashes, arrays and scalar values
our sub from-json(Str:D $text --> Any) is export {
    Parser.new(:$text).parse;
}
