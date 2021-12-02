
use strict;

use lib 't/lib';
use Test::More qw | no_plan |;
use SGN::Test::WWW::Mechanize;
use SGN::Test::Fixture;
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
$sl1->location_code('box1');
$sl1->breeding_program_id(134);
$sl1->store();

my $sl2 = CXGN::Stock::Seedlot->new( schema => $schema);
$sl2->uniquename('boff');
$sl2->location_code('box2');
$sl2->breeding_program_id(134);
$sl2->store();

my $sl3 = CXGN::Stock::Seedlot->new( schema => $schema );
$sl3->uniquename('asdf');
$sl3->location_code('box3');
$sl3->breeding_program_id(134);
$sl3->store();

# add a corresponding list
#
my $list_id = CXGN::List::create_list($schema->storage->dbh(), 'seedlot list for test', 'description', 41 );

my $list = CXGN::List->new( { dbh => $schema->storage->dbh(), list_id => $list_id });

$list->type('seedlots');

$list->add_bulk( [ 'blabla', 'boff', 'asdf' ]);

$mech->get_ok("http://localhost:3010/ajax/seedlots/verify_delete_by_list?list_id=$list_id");

my $content = $mech->content();
like($content, qr/"blabla","boff","asdf"/, "check seedlot deletion validation");

$mech->get_ok("http://localhost:3010/ajax/seedlots/confirm_delete_by_list?list_id=$list_id");

$content = $mech->content();

like($content, qr/\"total_count\":3/, "check total count");
like($content, qr/"success":1/, "check success bit");
like($content, qr/"delete_count":3/, "check delete_count ok");

# delete what has been created
#
CXGN::List::delete_list($schema->storage->dbh(), $list_id);

done_testing();
