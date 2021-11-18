
use strict;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use SGN::Test::Fixture;
use Test::More;
use LWP::UserAgent;
use CXGN::List;
use CXGN::Stock::Seedlot;
use Data::Dumper;
use JSON::XS;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $mech = Test::WWW::Mechanize->new();

# login
#
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login with brapi call');

# add seedlots to delete
#
my $sl1 = CXGN::Stock::Seedlot->new( schema => $schema);
$sl1->uniquename('blabla');
$sl1->store();

my $sl2 = CXGN::Stock::Seedlot->new( schema => $schema);
$sl2->uniquename('boff');
$sl2->store();

my $sl3 = CXGN::Stock::Seedlot->new( schema => $schema );
$sl3->uniquename('asdf');
$sl3->store();


# add a corresponding list
#
my $list_id = CXGN::List::create_list($schema->storage->dbh(), 'seedlot list for test', 'description', 41 );

my $list = CXGN::List->new( { dbh => $schema->storage->dbh(), list_id => $list_id });

$list->type('seedlots');

$list->add_bulk( [ 'blabla', 'boff', 'asdf' ]);

$mech->get_ok("http://localhost:3010/ajax/seedlots/verify_delete_by_list?list_id=$list_id");

print STDERR "CONTENT: ".$mech->content();


# delete what has been created
#

CXGN::List::delete_list($schema->storage->dbh(), $list_id);


done_testing();
