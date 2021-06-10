
use strict;
use warnings;

use lib 't/lib';

use Test::More qw | no_plan |;
use SGN::Test::Fixture;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $phenome_schema = $f->phenome_schema();
my $dbh = $f->dbh();

#$schema->storage->debug(1);

BEGIN {
    use_ok('CXGN::List'); 
    use_ok('CXGN::List::Validate'); 
    require_ok('Moose');
};


my $list = CXGN::List->new( { dbh => $dbh, list_id => 12 } );
my $flat_list = $list->elements();
print STDERR Dumper($flat_list);

my $list_validator = CXGN::List::Validate->new();

$flat_list->[0] = uc($flat_list->[0]);
print STDERR Dumper($flat_list);
my $results = $list_validator->validate($schema, 'accessions', $flat_list);


print STDERR Dumper($results);

is($results->{missing}->[0], 'NEW_TEST_CROSSP005', 'check first missing stock');
is($results->{missing}->[2], 'test_accession3_synonym1', 'check third missing stock');
is($results->{wrong_case}->[0]->[0], 'NEW_TEST_CROSSP005', 'check wrong case');
is($results->{synonyms}->[0]->{synonym}, 'test_accession2_synonym1', 'check synonym');

done_testing();
