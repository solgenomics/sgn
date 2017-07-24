#This script should test all functions in CXGN::Trial, CXGN::Trial::TrialLayout, CXGN::Trial::TrialDesign, CXGN::Trial::TrialCreate

use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SimulateC;

use Data::Dumper;

use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::Folder;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Trial::Search;
use SGN::Model::Cvterm;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $trial_search = CXGN::Trial::Search->new({
    bcs_schema=>$schema,
});
my $result = $trial_search->search();
print STDERR Dumper $result;
is_deeply($result, [
          {
            'folder_name' => undef,
            'breeding_program_name' => 'test',
            'description' => 'Copy of trial with postcomposed phenotypes from cassbase.',
            'trial_name' => 'CASS_6Genotypes_Sampling_2015',
            'location_id' => '23',
            'trial_id' => 165,
            'year' => '2017',
            'project_harvest_date' => undef,
            'breeding_program_id' => 134,
            'design' => 'RCBD',
            'location_name' => 'test_location',
            'folder_id' => undef,
            'trial_type' => 'Preliminary Yield Trial',
            'project_planting_date' => undef
          },
          {
            'design' => 'Alpha',
            'location_name' => 'test_location',
            'folder_id' => undef,
            'project_planting_date' => undef,
            'trial_type' => 'Clonal Evaluation',
            'project_harvest_date' => undef,
            'breeding_program_id' => 134,
            'trial_name' => 'Kasese solgs trial',
            'location_id' => '23',
            'trial_id' => 139,
            'year' => '2014',
            'folder_name' => undef,
            'breeding_program_name' => 'test',
            'description' => 'This trial was loaded into the fixture to test solgs.'
          },
          {
            'trial_name' => 'new_test_cross',
            'trial_id' => 135,
            'location_id' => undef,
            'year' => undef,
            'folder_name' => undef,
            'breeding_program_name' => 'test',
            'description' => 'new_test_cross',
            'location_name' => undef,
            'design' => undef,
            'folder_id' => undef,
            'trial_type' => undef,
            'project_planting_date' => undef,
            'project_harvest_date' => undef,
            'breeding_program_id' => 134
          },
          {
            'breeding_program_id' => undef,
            'project_harvest_date' => undef,
            'trial_type' => undef,
            'project_planting_date' => undef,
            'folder_id' => undef,
            'location_name' => undef,
            'design' => undef,
            'description' => 'selection_population',
            'breeding_program_name' => undef,
            'folder_name' => undef,
            'year' => '2015',
            'location_id' => undef,
            'trial_id' => 143,
            'trial_name' => 'selection_population'
          },
          {
            'trial_id' => 140,
            'location_id' => undef,
            'year' => '2015',
            'trial_name' => 'test_genotyping_project',
            'description' => 'test_genotyping_project',
            'folder_name' => undef,
            'breeding_program_name' => undef,
            'project_planting_date' => undef,
            'trial_type' => undef,
            'location_name' => undef,
            'design' => undef,
            'folder_id' => undef,
            'breeding_program_id' => undef,
            'project_harvest_date' => undef
          },
          {
            'trial_type' => undef,
            'project_planting_date' => undef,
            'location_name' => undef,
            'design' => undef,
            'folder_id' => undef,
            'breeding_program_id' => undef,
            'project_harvest_date' => undef,
            'trial_id' => 142,
            'location_id' => undef,
            'year' => '2015',
            'trial_name' => 'test_population2',
            'description' => 'test_population2',
            'folder_name' => undef,
            'breeding_program_name' => undef
          },
          {
            'breeding_program_name' => 'test',
            'folder_name' => undef,
            'description' => 'test tets',
            'trial_name' => 'test_t',
            'year' => '2016',
            'location_id' => '23',
            'trial_id' => 144,
            'project_harvest_date' => undef,
            'breeding_program_id' => 134,
            'folder_id' => undef,
            'design' => 'CRD',
            'location_name' => 'test_location',
            'project_planting_date' => undef,
            'trial_type' => undef
          },
          {
            'year' => '2014',
            'trial_id' => 137,
            'location_id' => '23',
            'trial_name' => 'test_trial',
            'description' => 'test trial',
            'breeding_program_name' => 'test',
            'folder_name' => undef,
            'trial_type' => undef,
            'project_planting_date' => '2017-July-04',
            'folder_id' => undef,
            'location_name' => 'test_location',
            'design' => 'CRD',
            'breeding_program_id' => 134,
            'project_harvest_date' => '2017-July-21'
          },
          {
            'breeding_program_id' => 134,
            'project_harvest_date' => undef,
            'project_planting_date' => undef,
            'trial_type' => undef,
            'folder_id' => undef,
            'design' => 'CRD',
            'location_name' => 'test_location',
            'description' => 'another trial for solGS',
            'breeding_program_name' => 'test',
            'folder_name' => undef,
            'year' => '2014',
            'location_id' => '23',
            'trial_id' => 141,
            'trial_name' => 'trial2 NaCRRI'
          }
        ], 'trial search test 1');

$trial_search = CXGN::Trial::Search->new({
    bcs_schema=>$schema,
    location_list=>['test_location'],
    program_list=>['test'],
});
$result = $trial_search->search();
print STDERR Dumper $result;
is_deeply($result, [
          {
            'location_name' => 'test_location',
            'design' => 'RCBD',
            'folder_id' => undef,
            'project_planting_date' => undef,
            'trial_type' => 'Preliminary Yield Trial',
            'project_harvest_date' => undef,
            'breeding_program_id' => 134,
            'trial_name' => 'CASS_6Genotypes_Sampling_2015',
            'trial_id' => 165,
            'location_id' => '23',
            'year' => '2017',
            'folder_name' => undef,
            'breeding_program_name' => 'test',
            'description' => 'Copy of trial with postcomposed phenotypes from cassbase.'
          },
          {
            'trial_name' => 'Kasese solgs trial',
            'year' => '2014',
            'location_id' => '23',
            'trial_id' => 139,
            'breeding_program_name' => 'test',
            'folder_name' => undef,
            'description' => 'This trial was loaded into the fixture to test solgs.',
            'folder_id' => undef,
            'location_name' => 'test_location',
            'design' => 'Alpha',
            'trial_type' => 'Clonal Evaluation',
            'project_planting_date' => undef,
            'project_harvest_date' => undef,
            'breeding_program_id' => 134
          },
          {
            'trial_type' => undef,
            'project_planting_date' => undef,
            'design' => 'CRD',
            'location_name' => 'test_location',
            'folder_id' => undef,
            'breeding_program_id' => 134,
            'project_harvest_date' => undef,
            'location_id' => '23',
            'trial_id' => 144,
            'year' => '2016',
            'trial_name' => 'test_t',
            'description' => 'test tets',
            'folder_name' => undef,
            'breeding_program_name' => 'test'
          },
          {
            'breeding_program_id' => 134,
            'project_harvest_date' => '2017-July-21',
            'project_planting_date' => '2017-July-04',
            'trial_type' => undef,
            'design' => 'CRD',
            'location_name' => 'test_location',
            'folder_id' => undef,
            'description' => 'test trial',
            'folder_name' => undef,
            'breeding_program_name' => 'test',
            'trial_id' => 137,
            'location_id' => '23',
            'year' => '2014',
            'trial_name' => 'test_trial'
          },
          {
            'folder_id' => undef,
            'design' => 'CRD',
            'location_name' => 'test_location',
            'trial_type' => undef,
            'project_planting_date' => undef,
            'project_harvest_date' => undef,
            'breeding_program_id' => 134,
            'trial_name' => 'trial2 NaCRRI',
            'year' => '2014',
            'location_id' => '23',
            'trial_id' => 141,
            'breeding_program_name' => 'test',
            'folder_name' => undef,
            'description' => 'another trial for solGS'
          }
        ], 'trial search test 2');



#CXGN::Trial Class METHODS
my $locations = CXGN::Trial::get_all_locations($f->bcs_schema());
#print STDERR Dumper $locations;
my @all_location_names;
foreach (@$locations) {
    push @all_location_names, $_->[1];
}
@all_location_names = sort @all_location_names;
#print STDERR Dumper \@all_location_names;
my %all_location_names = map {$_=>1} @all_location_names;
ok(exists($all_location_names{'Cornell Biotech'}));
ok(exists($all_location_names{'test_location'}));

my @project_types = CXGN::Trial::get_all_project_types($f->bcs_schema());
my @all_project_types;
foreach (@project_types) {
    push @all_project_types, $_->[1];
}
@all_project_types = sort @all_project_types;
#print STDERR Dumper \@all_project_types;
is_deeply(\@all_project_types, [
          'Advanced Yield Trial',
          'Clonal Evaluation',
          'Preliminary Yield Trial',
          'Seedling Nursery',
          'Uniform Yield Trial',
          'Variety Release Trial'
        ], "check get_all_project_types");


my $stock_count_rs = $f->bcs_schema()->resultset("Stock::Stock")->search( { } );
my $initial_stock_count = $stock_count_rs->count();

my $number_of_reps = 3;
my $stock_list = [ 'test_accession1', 'test_accession2', 'test_accession3' ];

my $td = CXGN::Trial::TrialDesign->new(
    {
	schema => $f->bcs_schema(),
	trial_name => "anothertrial",
	stock_list => $stock_list,
	number_of_reps => $number_of_reps,
	block_size => 2,
	design_type => 'RCBD',
	number_of_blocks => 3,
    });

my $number_of_plots = $number_of_reps * scalar(@$stock_list);

$td->calculate_design();

my $trial_design = $td->get_design();
#print STDERR Dumper $trial_design;

my $breeding_program_row = $f->bcs_schema->resultset("Project::Project")->find( { name => 'test' });
my $trial_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

my $new_trial = CXGN::Trial::TrialCreate->new(
    {
	dbh => $f->dbh(),
	chado_schema => $f->bcs_schema(),
	user_name => 'janedoe', #not implemented
	program => 'test',
	trial_year => 2014,
	trial_description => 'another test trial...',
	design_type => 'RCBD',
    trial_type => $trial_type_cvterm_id,
	trial_location => 'test_location',
	trial_name => "anothertrial",
	design => $trial_design,
    });

my $message = $new_trial->save_trial();

my $after_design_creation_count = $stock_count_rs->count();

is($number_of_plots + $initial_stock_count, $after_design_creation_count, "check stock table count after trial creation.");

my $trial_rs = $f->bcs_schema->resultset("Project::Project")->search( { name => 'anothertrial' });

my $trial_id = 0;

if ($trial_rs->count() > 0) {
    $trial_id = $trial_rs->first()->project_id();
}

if (!$trial_id) { die "Test failed... could not retrieve trial\n"; }

my $trial = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => $trial_id });

my $breeding_programs = $trial->get_breeding_programs();
#print STDERR Dumper $breeding_programs;
my @breeding_program_names;
foreach (@$breeding_programs){
    push @breeding_program_names, $_->[1];
}
@breeding_program_names = sort @breeding_program_names;
#print STDERR Dumper \@breeding_program_names;
is_deeply(\@breeding_program_names, ['test'], "check breeding_program_names");

my $plot_name = $trial_design->{1}->{plot_name};
my $rs = $f->bcs_schema()->resultset("Stock::Stock")->search( { name => $plot_name });
is($rs->count(), 1, "check that a single plot was saved for a single name.");
is($rs->first->name(), $plot_name, 'check that plot name was saved correctly');

if ($rs->count() > 0) {
    print STDERR "antohertrial1 has id ".$rs->first()->stock_id()."\n";
}
else {
    print STDERR "anothertrial1 does not exist!\n";
}

# Test addition and deletion of phenotypic data
#
my $phenotype_count_before_store = $trial->phenotype_count();

ok($trial->phenotype_count() == 0, "trial has no phenotype data");

my $plotlist_ref = [ $trial_design->{1}->{plot_name}, $trial_design->{2}->{plot_name}, $trial_design->{3}->{plot_name} ];

my $traitlist_ref = [ 'root number|CO:0000011', 'dry yield|CO:0000014' ];

my %plot_trait_value = ( $trial_design->{1}->{plot_name} => { 'root number|CO:0000011'  => [0,''], 'dry yield|CO:0000014' => [30,''] },
			   $trial_design->{2}->{plot_name} => { 'root number|CO:0000011'  => [10,''], 'dry yield|CO:0000014' => [40,''] },
			   $trial_design->{3}->{plot_name} => { 'root number|CO:0000011'  => [20,''], 'dry yield|CO:0000014' => [50,''] },
    );


my %metadata = ( operator => 'johndoe', date => '20141223' );

my $lp = CXGN::Phenotypes::StorePhenotypes->new(
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>$plotlist_ref,
    trait_list=>$traitlist_ref,
    values_hash=>\%plot_trait_value,
    has_timestamps=>0,
    overwrite_values=>0,
    metadata_hash=>\%metadata,
);

$lp->store();

my $total_phenotypes = $trial->total_phenotypes();

my $trial_phenotype_count = $trial->phenotype_count();

print STDERR "Total phentoypes: $total_phenotypes\n";
print STDERR "Trial phentoypes: $trial_phenotype_count\n";
is($total_phenotypes, 3508, "total phenotype data");
is($trial_phenotype_count, 6, "trial has phenotype data");

my $tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => $trial_id });

my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_names;
#print STDERR Dumper $traits_assayed;
foreach (@$traits_assayed) {
    push @traits_assayed_names, $_->[1];
}
@traits_assayed_names = sort @traits_assayed_names;
#print STDERR Dumper \@traits_assayed_names;
is_deeply(\@traits_assayed_names, ['dry yield|CO:0000014', 'root number counting|CO:0000011'], 'check traits assayed' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70727);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper \@pheno_for_trait_sorted;
is_deeply(\@pheno_for_trait_sorted, ['30','40','50'], 'check traits assayed' );

my $plot_pheno_for_trait = $tn->get_stock_phenotypes_for_traits([70727], 'all', ['plot_of','plant_of'], 'accession', 'subject');
#print STDERR Dumper $plot_pheno_for_trait;
my @phenotyped_stocks;
my @phenotyped_stocks_values;
foreach (@$plot_pheno_for_trait) {
    push @phenotyped_stocks, $_->[1];
    push @phenotyped_stocks_values, $_->[7];
}
@phenotyped_stocks = sort @phenotyped_stocks;
@phenotyped_stocks_values = sort @phenotyped_stocks_values;
my @expected_sorted_stocks = sort ($trial_design->{1}->{plot_name}, $trial_design->{2}->{plot_name}, $trial_design->{3}->{plot_name});
print STDERR Dumper \@phenotyped_stocks;
print STDERR Dumper \@expected_sorted_stocks;
is_deeply(\@phenotyped_stocks, \@expected_sorted_stocks, "check phenotyped stocks");
is_deeply(\@phenotyped_stocks_values, ['30', '40', '50'], "check phenotyped stocks");

my $trial_experiment_count = $trial->get_experiment_count();
#print STDERR $trial_experiment_count."\n";
is($trial_experiment_count, 7, "check get_experiment_count");

my $location_type_id = $trial->get_location_type_id();
#print STDERR $location_type_id."\n";
is($location_type_id, 76462, "check get_location_type_id");

my $year_type_id = $trial->get_year_type_id();
#print STDERR $year_type_id."\n";
is($year_type_id, 76395, "check get_year_type_id");

my $bp_trial_rel_cvterm_id = $trial->get_breeding_program_trial_relationship_cvterm_id();
#print STDERR $bp_trial_rel_cvterm_id,"\n";
is($bp_trial_rel_cvterm_id, 76448, "check get_breeding_program_trial_relationship_cvterm_id");

my $bp_cvterm_id = $trial->get_breeding_program_cvterm_id();
#print STDERR $bp_cvterm_id."\n";
is($bp_cvterm_id, 76440, "check get_breeding_program_cvterm_id");

my $folder = $trial->get_folder();
#print STDERR $folder->name."\n";
is($folder->name, 'test', 'check get_folder when no folder associated. should return bp name');

my $folder = CXGN::Trial::Folder->create({
  bcs_schema => $f->bcs_schema(),
  parent_folder_id => 0,
  name => 'F1',
  breeding_program_id => $breeding_program_row->project_id(),
});
my $folder_id = $folder->folder_id();

my $folder = CXGN::Trial::Folder->new({
    bcs_schema => $f->bcs_schema(),
    folder_id => $trial_id
});

$folder->associate_parent($folder_id);

my $folder = $trial->get_folder();
#print STDERR $folder->name."\n";
is($folder->name, 'F1', 'check get_folder after folder associated');

my $harvest_date_cvterm_id = $trial->get_harvest_date_cvterm_id();
#print STDERR $harvest_date_cvterm_id."\n";
is($harvest_date_cvterm_id, 76495, "check get_harvest_date_cvterm_id");

my $planting_date_cvterm_id = $trial->get_planting_date_cvterm_id();
#print STDERR $planting_date_cvterm_id."\n";
is($planting_date_cvterm_id, 76496, "check get_planting_date_cvterm_id");

my $design_type = $trial->get_design_type();
#print STDERR $design_type."\n";
is($design_type, 'RCBD', 'check get_design_type');

my $trial_accessions = $trial->get_accessions();
#print STDERR Dumper $trial_accessions;
my @trial_accession_names;
foreach (@$trial_accessions) {
    push @trial_accession_names, $_->{'accession_name'};
}
@trial_accession_names = sort @trial_accession_names;
is_deeply(\@trial_accession_names, ['test_accession1', 'test_accession2', 'test_accession3'], "check get_accessions");

my $trial_plots = $trial->get_plots();
my @trial_plot_names;
foreach (@$trial_plots){
    push @trial_plot_names, $_->[1];
}
@trial_plot_names = sort @trial_plot_names;
print STDERR "Num plots: ".scalar(@trial_plot_names)."\n";
is(scalar(@trial_plot_names), 9, 'check number of plots');
my @expected_sorted_plots = sort ($trial_design->{1}->{plot_name}, $trial_design->{2}->{plot_name}, $trial_design->{3}->{plot_name}, $trial_design->{4}->{plot_name}, $trial_design->{5}->{plot_name}, $trial_design->{6}->{plot_name}, $trial_design->{7}->{plot_name}, $trial_design->{8}->{plot_name}, $trial_design->{9}->{plot_name});
print STDERR Dumper \@trial_plot_names;
print STDERR Dumper \@expected_sorted_plots;
is_deeply(\@trial_plot_names, \@expected_sorted_plots, 'Check get_plots');

my $trial_controls = $trial->get_controls();
#print STDERR Dumper $trial_controls;
is_deeply($trial_controls, [], "check get_controls");



#add plant entries
my $num_plants_add = 3;
$trial->create_plant_entities($num_plants_add);

ok($trial->has_plant_entries(), "check if plant entries created.");

my $trial = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),	trial_id => $trial_id });
my $plants = $trial->get_plants();
#print STDERR Dumper $plants;
is(scalar(@$plants), $number_of_plots*3, "check if the right number of plants was created");

my $plantlist_ref = [ $trial_design->{1}->{plot_name}.'_plant_2', $trial_design->{2}->{plot_name}.'_plant_2', $trial_design->{3}->{plot_name}.'_plant_1' ];

my $traitlist_ref = [ 'root number|CO:0000011', 'dry yield|CO:0000014', 'harvest index|CO:0000015' ];

my %plant_trait_value = ( $trial_design->{1}->{plot_name}.'_plant_2' => { 'root number|CO:0000011'  => [12,''], 'dry yield|CO:0000014' => [30,''], 'harvest index|CO:0000015' => [2,''] },
    $trial_design->{2}->{plot_name}.'_plant_2' => { 'root number|CO:0000011'  => [10,''], 'dry yield|CO:0000014' => [40,''], 'harvest index|CO:0000015' => [3,''] },
    $trial_design->{3}->{plot_name}.'_plant_1' => { 'root number|CO:0000011'  => [20,''], 'dry yield|CO:0000014' => [50,''], 'harvest index|CO:0000015' => [7,''] },
);

my %metadata = ( operator => 'johndoe', date => '20141225' );

my $lp = CXGN::Phenotypes::StorePhenotypes->new(
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>$plantlist_ref,
    trait_list=>$traitlist_ref,
    values_hash=>\%plant_trait_value,
    has_timestamps=>0,
    overwrite_values=>0,
    metadata_hash=>\%metadata,
);
$lp->store();

my $total_phenotypes = $trial->total_phenotypes();

my $trial_phenotype_count = $trial->phenotype_count();

print STDERR "Total phentoypes: $total_phenotypes\n";
print STDERR "Trial phentoypes: $trial_phenotype_count\n";
is($total_phenotypes, 3517, "total phenotype data");
is($trial_phenotype_count, 15, "trial has phenotype data");

my $tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => $trial_id });

my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper \@traits_assayed_sorted;

my @traits_assayed_check = (['70668','Harvest index variable'],['70706','Root number counting'],['70727','Dry yield']);

#is_deeply(\@traits_assayed_sorted, \@traits_assayed_check, 'check traits assayed' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70706);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper \@pheno_for_trait_sorted;
my @pheno_for_trait_check = (0, 10, 10, 12, 20, 20);
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check traits assayed' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70668);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper \@pheno_for_trait_sorted;
my @pheno_for_trait_check = (2,3,7);
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check traits assayed' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70727);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper \@pheno_for_trait_sorted;
my @pheno_for_trait_check = (30,30,40,40,50,50);
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check traits assayed' );


my $retrieve_accessions = $trial->get_accessions();
#print STDERR Dumper $retrieve_accessions;
my @get_accessions_names;
foreach (@$retrieve_accessions){
    push @get_accessions_names, $_->{'accession_name'};
}
@get_accessions_names = sort @get_accessions_names;
#print STDERR Dumper \@get_accessions_names;
is_deeply(\@get_accessions_names, [
          'test_accession1',
          'test_accession2',
          'test_accession3'
        ], 'check get_accessions');

my $retrieve_plots = $trial->get_plots();
#print STDERR Dumper $retrieve_plots;
my @get_plot_names;
foreach (@$retrieve_plots){
    push @get_plot_names, $_->[1];
}
@get_plot_names = sort @get_plot_names;
#print STDERR Dumper \@get_plot_names;
is_deeply(\@get_plot_names, \@expected_sorted_plots, "check get_plots");

my @expected_plants;
foreach (@expected_sorted_plots) {
    for my $i (1..$num_plants_add){
        push @expected_plants, $_."_plant_".$i;
    }
}
my @expected_sorted_plants = sort @expected_plants;

my $retrieve_plants = $trial->get_plants();
#print STDERR Dumper $retrieve_plants;
my @get_plant_names;
foreach (@$retrieve_plants){
    push @get_plant_names, $_->[1];
}
@get_plant_names = sort @get_plant_names;
print STDERR Dumper \@get_plant_names;
is_deeply(\@get_plant_names, \@expected_sorted_plants, "check get_plants()");


# check trial deletion - first, delete associated phenotypes
#
$trial->delete_phenotype_data();

ok($trial->phenotype_count() ==0, "phenotype data deleted");

is($trial->total_phenotypes(), $total_phenotypes - $trial_phenotype_count, "check total phenotypes");

# check trial layout deletion
#
my $error = $trial->delete_field_layout();

ok(! $error, "no error upon layout deletion");

my $after_design_deletion_count = $stock_count_rs->count();

is( $after_design_deletion_count, $initial_stock_count, "check that stock counts before layout creation and after deletion match");

# test name accessors
#
is($trial->get_name(), "anothertrial");
$trial->set_name("anothertrial modified");
is($trial->get_name(), "anothertrial modified");

# test description accessors
#
my $desc = $trial->get_description();

ok($desc == "test_trial", "another test trial...");

$trial->set_description("blablabla");

is($trial->get_description(), "blablabla", "description setter test");

# test harvest_date accessors
#
$trial->set_harvest_date('2016/01/01 12:20:10');
my $harvest_date = $trial->get_harvest_date();
#print STDERR Dumper $harvest_date;
is($harvest_date, '2016-January-01 12:20:10', "set harvest_date test");
$trial->remove_harvest_date('2016/01/01 12:20:10');
$harvest_date = $trial->get_harvest_date();
ok(!$harvest_date, "test remove harvest_date");

# test planting_date accessors
#
$trial->set_planting_date('2016/01/01 12:20:10');
my $planting_date = $trial->get_planting_date();
#print STDERR Dumper $planting_date;
is($planting_date, '2016-January-01 12:20:10', "set harvest_date test");
$trial->remove_planting_date('2016/01/01 12:20:10');
$planting_date = $trial->get_planting_date();
ok(!$planting_date, "test remove planting_date");

# test year accessors
#
is($trial->get_year(), 2014, "get year test");

$trial->set_year(2013);
is($trial->get_year(), 2013, "set year test");

# test breeding program accessors
#
is($trial->get_breeding_program(), 'test', "get breeding program test");

$trial->set_breeding_program($breeding_program_row->project_id());
is($trial->get_breeding_program(), 'test', "set breeding program test");

# test location accessors
#
is_deeply($trial->get_location(), [ 23, 'test_location' ], "get location");

$trial->set_location(23);
is_deeply($trial->get_location(), [ 23, 'test_location' ], "set location");

# test project type accessors
#
is($trial->get_project_type()->[1], "Advanced Yield Trial", "get type test");

my $error = $trial->set_project_type("77106");

is($trial->get_project_type()->[1], "Clonal Evaluation", "set type test");

$trial->delete_project_entry();

my $deleted_trial;
eval {
     $deleted_trial = CXGN::Trial->new( { bcs_schema => $f->bcs_schema, trial_id=>$trial_id });
};

ok($@, "deleted trial id");


done_testing();
