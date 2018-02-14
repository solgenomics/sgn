# A test for Desynonymizing stock lists
use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::People::Person;

use Data::Dumper;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $phenome_schema = $f->phenome_schema();
my $dbh = $f->dbh();
$schema->storage->debug(1);

BEGIN {use_ok('CXGN::List');}
BEGIN {use_ok('CXGN::List::Desynonymize');}
BEGIN {require_ok('Moose');}

my $list = CXGN::List->new( { dbh => $dbh, list_id => 12 } );
my $flat_list = $list->retrieve_elements_with_ids(12);
my @name_list = map {@{$_}[1]} @{$flat_list};
print STDERR Dumper @name_list;
my $dsyner = CXGN::List::Desynonymize->new();
print STDERR Dumper $list->type();
ok(my $results = $dsyner->desynonymize($schema,$list->type(),\@name_list),
"run list desynonymize");
print STDERR Dumper $results;


done_testing();
