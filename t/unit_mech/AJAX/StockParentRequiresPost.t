
=head1 NAME

t/unit_mech/AJAX/StockParentRequiresPost.t - pedigree edits are not done on a GET

=cut

use strict; use warnings;
use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $server = 'http://localhost:3010';
my $m = Test::WWW::Mechanize->new(autocheck => 0);
$m->post("$server/ajax/user/login", { username => 'janedoe', password => 'secretpw' });

$m->get("$server/ajax/stock/parent/remove?stock_id=38840&parent_id=38839");
my $r = eval { decode_json($m->content) } || {};
like($r->{error} || '', qr/POST/i, 'remove parent on GET is refused and asks for POST');

done_testing();
