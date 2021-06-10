
use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $phenome_schema = $f->phenome_schema();
my $dbh = $f->dbh();

#$schema->storage->debug(1);

BEGIN {
    use_ok('CXGN::List'); 
    use_ok('CXGN::List::Transform'); 
    require_ok('Moose');
};


my $list = CXGN::List->new( { dbh => $dbh, list_id => 12 } );
my $flat_list = $list->elements();
print STDERR Dumper($flat_list);

my $list_validator = CXGN::List::Transform->new();

$flat_list->[0] = uc($flat_list->[0]);
print STDERR Dumper($flat_list);
my $results = $list_validator->transform($schema, 'accessions_2_accession_case', $flat_list);

is($results->{mapping}->{NEW_TEST_CROSSP005}, 'new_test_crossP005', 'identify wrong case');

print STDERR Dumper($results);

done_testing();
