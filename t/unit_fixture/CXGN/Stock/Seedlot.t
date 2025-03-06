
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
my $seedlot_material_type = 'root';
my $seedlot_location = 'seedlot1_location';
my $seedlot_box_name = 'box1';
my $seedlot_accession_uniquename = 'test_accession1';
my $seedlot_accession_id = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_accession_uniquename})->stock_id();
my $seedlot_breeding_program_name = "test";
my $seedlot_breeding_program_id = $schema->resultset('Project::Project')->find({name=>$seedlot_breeding_program_name})->project_id();
my $seedlot_organization = 'bti';
my $seedlot_population_name = 'seedlot1_pop';

my $sl = CXGN::Stock::Seedlot->new( schema=>$schema );
$sl->uniquename($seedlot_uniquename);
$sl->material_type($seedlot_material_type);
$sl->location_code($seedlot_location);
$sl->box_name($seedlot_box_name);
$sl->accession_stock_id($seedlot_accession_id);
$sl->organization_name($seedlot_organization);
$sl->population_name($seedlot_population_name);
$sl->breeding_program_id($seedlot_breeding_program_id);
$sl->quality('MOLD');


#TO DO
#$sl->cross_id($cross_id);
my $return = $sl->store();
my $seedlot_id = $return->{seedlot_id};

my $s = CXGN::Stock::Seedlot->new(schema=>$schema, seedlot_id=>$seedlot_id);
is($s->uniquename, $seedlot_uniquename);
is($s->location_code, $seedlot_location);
is($s->organization_name, $seedlot_organization);
is($s->population_name, $seedlot_population_name);
is_deeply($s->accession, [$seedlot_accession_id, $seedlot_accession_uniquename] );
is_deeply($s->accession_stock_id, $seedlot_accession_id);
is($s->breeding_program_name, $seedlot_breeding_program_name);
is($s->breeding_program_id, $seedlot_breeding_program_id);
is($s->box_name, $seedlot_box_name);
is($s->quality, 'MOLD', 'set/get quality test');
is($s->material_type, $seedlot_material_type);

$s->quality('ROT');
is($s->quality(), 'ROT', 'quality update test');

$f->clean_up_db();

done_testing();
