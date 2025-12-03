use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Genotype;
use CXGN::Dataset;
local $Data::Dumper::Indent = 0;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
BEGIN {use_ok('CXGN::TrialStatus');}
BEGIN {use_ok('CXGN::BreedersToolbox::Projects');}
BEGIN {use_ok('CXGN::Genotype::StoreGenotypingProject');}

ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);
$chado_schema->txn_begin();

# create stocks for the trial
ok(my $accession_cvterm = $chado_schema->resultset("Cv::Cvterm")
   ->create_with({
       name   => 'accession',
       cv     => 'stock_type',

         }));
my @stock_names;
for (my $i = 1; $i <= 5; $i++) {
    push(@stock_names, "test_stock_4_trial".$i);
}


ok(my $organism = $chado_schema->resultset("Organism::Organism")
   ->find_or_create( {
       genus => 'Test_genus',
       species => 'Test_genus test_species',
             }, ));

# create some test stocks
foreach my $stock_name (@stock_names) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
    ->create({
        organism_id => $organism->organism_id,
        name       => $stock_name,
        uniquename => $stock_name,
        type_id     => $accession_cvterm->cvterm_id,
         });
};

#genotyping project for genotyping plate
my $location_rs = $chado_schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $chado_schema->resultset('Project::Project')->find({name => 'test'});
my $breeding_program_id = $bp_rs->project_id();

my $add_genotyping_project = CXGN::Genotype::StoreGenotypingProject->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    project_name => 'test_genotyping_project_3',
    breeding_program_id => $breeding_program_id,
    project_facility => 'igd',
    data_type => 'snp',
    year => '2022',
    project_description => 'genotyping project for test',
    nd_geolocation_id => $location_id,
    owner_id => 41
});
ok(my $store_return = $add_genotyping_project->store_genotyping_project(), "store genotyping project");

my $gp_rs = $chado_schema->resultset('Project::Project')->find({name => 'test_genotyping_project_3'});
my $genotyping_project_id = $gp_rs->project_id();
my $trial = CXGN::Trial->new( { bcs_schema => $chado_schema, trial_id => $genotyping_project_id });
my $location_data = $trial->get_location();
my $location_name = $location_data->[1];
my $description = $trial->get_description();
my $genotyping_facility = $trial->get_genotyping_facility();
my $project_year = $trial->get_year();

my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $chado_schema });
my $breeding_program_data = $program_object->get_breeding_programs_by_trial($genotyping_project_id);
my $breeding_program_name = $breeding_program_data->[0]->[1];


# create stocks for the genotyping trial

my @genotyping_stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@genotyping_stock_names, "test_stock_4_genotyping_trial".$i);
}


# create some genotyping test stocks
foreach my $stock_name (@genotyping_stock_names) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
    ->create({
        organism_id => $organism->organism_id,
        name       => $stock_name,
        uniquename => $stock_name,
        type_id     => $accession_cvterm->cvterm_id,
         });
};


my $genotyping_trial_create;

my $trial_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_trial', 'project_type')->cvterm_id();

ok($genotyping_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    program => $breeding_program_name,
    trial_location => $location_name,
    operator => "janedoe",
    trial_year => $project_year,
    trial_description => $description,
    design_type => 'genotyping_plate',
    design => $geno_design,
    trial_name => $plate_info->{name},
    trial_type => $trial_type_cvterm_id,
    is_genotyping => 1,
    genotyping_user_id => 41,
    genotyping_project_id => $plate_info->{genotyping_project_id},
    genotyping_facility_submitted => $plate_info->{genotyping_facility_submit},
    genotyping_facility => $genotyping_facility,
    genotyping_plate_format => $plate_info->{plate_format},
    genotyping_plate_sample_type => $plate_info->{sample_type},
    genotyping_trial_from_field_trial=> [$field_trial_id],
}), "create genotyping plate");

my $gd_save = $genotyping_trial_create->save_trial();
ok($gd_save->{'trial_id'}, "save genotyping plate");

ok(my $genotyping_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "test_genotyping_trial_name",
}), "lookup genotyping plate");
ok(my $genotyping_trial = $genotyping_trial_lookup->get_trial(), "retrieve genotyping plate");
ok(my $genotyping_trial_id = $genotyping_trial->project_id(), "retrive genotyping plate id");

ok(my $g_trial = CXGN::Trial->new({bcs_schema => $chado_schema, trial_id => $genotyping_trial_id}),"get plate by id");

ok(my $success = $g_trial->delete_genotyping_project($field_trial_id, 'curator'),'delete linkage');
ok( $success->{success});

print STDERR "Rolling back...\n";

$chado_schema->txn_rollback();

done_testing();
