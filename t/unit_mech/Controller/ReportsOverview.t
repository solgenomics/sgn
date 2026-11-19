use strict;
use warnings;

use lib 't/lib';
use Test::More;
use Test::WWW::Mechanize;
use SGN::Test::Fixture;

# /reports/overview (linked from /reports) looked up the accession type in the
# stock_property cv, where it does not exist, and failed with an internal
# server error. It shows the number of accessions.

my $f = SGN::Test::Fixture->new();
my $base = $ENV{SGN_TEST_SERVER} || 'http://localhost:3010';
my ($accessions) = $f->dbh->selectrow_array(q{
    SELECT count(*) FROM stock JOIN cvterm ON cvterm.cvterm_id = stock.type_id
      JOIN cv USING (cv_id) WHERE cvterm.name = 'accession' AND cv.name = 'stock_type'});
ok($accessions > 0, 'the fixture has accessions');

my $mech = Test::WWW::Mechanize->new(autocheck => 0);
$mech->post("$base/ajax/user/login", { username => 'janedoe', password => 'secretpw' });
is($mech->status, 200, 'janedoe logs in');

$mech->get("$base/reports/overview");
is($mech->status, 200, '/reports/overview opens');
like($mech->content, qr{<td>Accessions</td><td>\Q$accessions\E</td>}, "the overview shows the $accessions accessions");

done_testing();
