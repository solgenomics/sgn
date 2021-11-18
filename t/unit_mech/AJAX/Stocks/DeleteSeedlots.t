
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
my $list = CXGN::List->create_list($schema->storage->dbh(), 'seedlot list for test', 'description', 1 );



my $list_id = $list->store();
$list->add_bulk( [ 'blabla', 'boff', 'asdf' ]);




$mech->get_ok('/ajax/seedlots/verify_deletion?list_id=$list_id');

$mech->contents();


# delete what has been created
#

$list->delete();


done_testing();
