use strict;
use warnings;
use utf8;

use Test::More;
use Encode;
use JSON;

use CXGN::JSONUtils qw(decode_stored_json);

my $cyrillic = { note => 'Висота рослини', unit => 'см' };
my $latin1 = { note => 'Müller', unit => '°C' };
my $mixed = { note => 'café – Висота', list => [ 'ü', 'é', 1 ] };

# with pg_enable_utf8, DBD::Pg upgrades octet strings on the way in, so a
# value written with encode_json() is stored and read back with one
# character per UTF-8 octet
sub as_read_back_from_encode_json {
    my $data = shift;
    return Encode::decode('iso-8859-1', encode_json($data));
}

is_deeply(decode_stored_json('{"a":1,"b":"x"}'), { a => 1, b => 'x' }, "ASCII JSON");
is_deeply(decode_stored_json('[]'), [], "empty array");

foreach my $case ([ 'Cyrillic', $cyrillic ], [ 'Latin-1 range', $latin1 ], [ 'mixed', $mixed ]) {
    my ($name, $data) = @$case;

    my $characters = JSON->new->encode($data);
    is_deeply(decode_stored_json($characters), $data, "$name: JSON as characters");

    my $octets = encode_json($data);
    is_deeply(decode_stored_json($octets), $data, "$name: JSON as UTF-8 octets");

    my $read_back = as_read_back_from_encode_json($data);
    is_deeply(decode_stored_json($read_back), $data, "$name: encode_json() value read back from the database");
}

eval { decode_stored_json('{"a":') };
ok($@, "invalid JSON dies");

eval { decode_stored_json('{"note":"Висота"') };
ok($@, "invalid non-ASCII JSON dies");

eval { decode_stored_json('') };
ok($@, "empty string dies, like decode_json");

{
    my $line = __LINE__ + 1;
    eval { decode_stored_json('{"a":') };
    like($@, qr/ at \Q$0\E line $line\b/, "decode error is reported at the caller's line, not inside JSONUtils.pm");
}

{
    eval { die "unrelated failure\n" };
    decode_stored_json('{"a":1}');
    is($@, "unrelated failure\n", "a successful decode does not clobber the caller's \$@");
}

done_testing();
