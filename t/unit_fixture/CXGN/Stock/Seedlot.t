#test all functions in CXGN::Stock::Seedlot

use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Stock::Seedlot;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $seedlot_uniquename = 'seedlot1';
my $seedlot_location = 'seedlot1_location';
my $seedlot_accession_uniquename = 'test_accession1';
my $seedlot_accession_id = [$schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_accession_uniquename})->stock_id()];
my $seedlot_breeding_program_name = "test";
my $seedlot_breeding_program_id = $schema->resultset('Project::Project')->find({name=>$seedlot_breeding_program_name})->project_id();
my $seedlot_organization = 'bti';
my $seedlot_population_name = 'seedlot1_pop';

my $sl = CXGN::Stock::Seedlot->new(schema=>$schema);
$sl->uniquename($seedlot_uniquename);
$sl->location_code($seedlot_location);
$sl->accession_stock_ids($seedlot_accession_id);
$sl->organization_name($seedlot_organization);
$sl->population_name($seedlot_population_name);
$sl->breeding_program_id($seedlot_breeding_program_id);
#TO DO
#$sl->cross_id($cross_id);
my $seedlot_id = $sl->store();

my $s = CXGN::Stock::Seedlot->new(schema=>$schema, seedlot_id=>$seedlot_id);
is($s->uniquename, $seedlot_uniquename);
is($s->location_code, $seedlot_location);
is($s->organization_name, $seedlot_organization);
is($s->populations->[0], $seedlot_population_name);
is_deeply($s->accession_stock_ids, $seedlot_accession_id);
is($s->breeding_program_name, $seedlot_breeding_program_name);
is($s->breeding_program_id, $seedlot_breeding_program_id);

done_testing();
