
use strict;
use Test::More;

use lib 't/lib';

use TestProp;
use Data::Dumper;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::JSONProp;

my $f = SGN::Test::Fixture->new();

my $jp = TestProp->new( { bcs_schema => $f->bcs_schema() });

is($jp->prop_table(), 'projectprop');
is($jp->prop_namespace(), 'Project::Projectprop');
is($jp->prop_type(), 'analysis_metadata_json');
is($jp->prop_primary_key(), 'projectprop_id');

$jp->info_field1("blabla");
$jp->info_field2("hello world");
$jp->parent_id(134);

my $prop_id = $jp->store();

my $prop_primary_key = $jp->prop_primary_key();
#my $prop_id = $jp->$prop_primary_id();
print STDERR "Retrieved prop_id $prop_id\n";
my $db_jp = TestProp->new( { bcs_schema => $f->bcs_schema(), prop_id => $prop_id });

is($db_jp->parent_id(), 134, "parent id test");
is($db_jp->info_field1(), "blabla", "info_field1 test");
is($db_jp->prop_type(), 'analysis_metadata_json', "analysis metadata test");

done_testing();


