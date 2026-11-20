use strict;
use warnings;

# /brapi/v1/variables-search?observationVariableDbId=<id> filtered on a
# column that does not exist (cvterm.id), so every search by variable id
# failed with a database error instead of returning the variable.

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $dbh = $f->dbh();

# a real observation variable of the fixture
my ($variable_id, $variable_name) = $dbh->selectrow_array(q{
    SELECT cvterm.cvterm_id, cvterm.name
      FROM cvterm
      JOIN cvterm_relationship rel ON rel.subject_id = cvterm.cvterm_id
      JOIN cvterm reltype ON reltype.cvterm_id = rel.type_id AND reltype.name = 'VARIABLE_OF'
     ORDER BY cvterm.cvterm_id LIMIT 1});
ok($variable_id, 'the fixture has an observation variable');

my $mech = Test::WWW::Mechanize->new(autocheck => 0);
$mech->get("http://localhost:3010/brapi/v1/variables-search?observationVariableDbId=$variable_id");
is($mech->status, 200, 'search by variable id answers');
my $response = eval { decode_json($mech->content) };
ok($response, 'search by variable id returns JSON') or diag $mech->content;
my @ids = map { $_->{observationVariableDbId} } @{ $response->{result}{data} || [] };
is_deeply(\@ids, [ $variable_id ], 'search by variable id returns exactly that variable');

done_testing();
