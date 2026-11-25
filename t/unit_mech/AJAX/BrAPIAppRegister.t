
=head1 NAME

t/unit_mech/AJAX/BrAPIAppRegister.t - /brapiapp/register applies the normal signup checks

=cut

use strict;
use warnings;
use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::People::Person;
use JSON;

my $f = SGN::Test::Fixture->new();
my $dbh = $f->dbh();
my $server = 'http://localhost:3010';
my $m = Test::WWW::Mechanize->new(autocheck => 0);

sub reg {
    my %p = @_;
    $m->post("$server/brapiapp/register", { %p });
    return eval { decode_json($m->content) } || {};
}

my $r = reg(username => '<b>x</b>yz', password => 'password12', email => 'ba_markup@example.org', first_name => 'A', last_name => 'B');
ok($r->{error}, 'markup in the user name is refused') or diag explain $r;
ok(!CXGN::People::Person->get_person_by_username($dbh, '<b>x</b>yz'), 'no account for a markup name');

$r = reg(username => 'short', password => 'password12', email => 'ba_short@example.org', first_name => 'A', last_name => 'B');
ok($r->{error}, 'a short user name is refused');

$r = reg(username => 'brapiapptester1', password => 'short', email => 'ba_pw@example.org', first_name => 'A', last_name => 'B');
ok($r->{error}, 'a short password is refused');

$r = reg(username => 'janedoe', password => 'password12', email => 'ba_dupe@example.org', first_name => 'A', last_name => 'B');
ok($r->{error}, 'a duplicate user name is refused');

$r = reg(username => 'brapiapptester2', password => 'password12', email => 'notanemail', first_name => 'A', last_name => 'B');
ok($r->{error}, 'an invalid email is refused');

$r = reg(username => 'brapiapptester3', password => 'password12', email => 'ba_ok@example.org', first_name => 'A', last_name => 'B');
ok($r->{success}, 'a valid registration still works') or diag explain $r;
my $pid = CXGN::People::Person->get_person_by_username($dbh, 'brapiapptester3');
ok($pid, 'the account was created');
CXGN::People::Person->new($dbh, $pid)->hard_delete() if $pid;

done_testing();
