use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Genotype;
use CXGN::Genotype::CreatePlateOrder;
use CXGN::Dataset;
local $Data::Dumper::Indent = 0;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLayoutDownload');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
BEGIN {use_ok('CXGN::TrialStatus');}

ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);
# ok($chado_schema->txn_begin);
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

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("test_trial"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_blocks(2), "set block number");
ok($trial_design->set_design_type("RCBD"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

my $ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location",
    trial_name => "new_test_trial_name",
    trial_type=>$ayt_cvterm_id,
    design_type => "RCBD",
    operator => "janedoe"
                            }), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

my $field_trial_id = $save->{'trial_id'};




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

my $plate_info = {
    elements => \@genotyping_stock_names,
    plate_format => 96,
    blank_well => 'A02',
    name => 'test_genotyping_trial_name',
    description => "test description",
    year => '2015',
    project_name => 'NextGenCassava',
    genotyping_facility_submit => 'no',
    genotyping_facility => 'igd',
    sample_type => 'DNA'
};

my $gd = CXGN::Trial::TrialDesign->new( { schema => $chado_schema } );
$gd->set_stock_list($plate_info->{elements});
$gd->set_block_size($plate_info->{plate_format});
$gd->set_blank($plate_info->{blank_well});
$gd->set_trial_name($plate_info->{name});
$gd->set_design_type("genotyping_plate");
$gd->calculate_design();
my $geno_design = $gd->get_design();

is_deeply($geno_design, {
          'A09' => {
                     'row_number' => 'A',
                     'plot_name' => 'test_genotyping_trial_name_A09',
                     'stock_name' => 'test_stock_4_genotyping_trial8',
                     'col_number' => 9,
                     'is_blank' => 0,
                     'plot_number' => 'A09'
                   },
          'A07' => {
                     'is_blank' => 0,
                     'plot_number' => 'A07',
                     'plot_name' => 'test_genotyping_trial_name_A07',
                     'row_number' => 'A',
                     'col_number' => 7,
                     'stock_name' => 'test_stock_4_genotyping_trial6'
                   },
          'A02' => {
                     'is_blank' => 1,
                     'plot_number' => 'A02',
                     'row_number' => 'A',
                     'plot_name' => 'test_genotyping_trial_name_A02_BLANK',
                     'stock_name' => 'BLANK',
                     'col_number' => 2
                   },
          'A05' => {
                     'is_blank' => 0,
                     'plot_number' => 'A05',
                     'row_number' => 'A',
                     'plot_name' => 'test_genotyping_trial_name_A05',
                     'stock_name' => 'test_stock_4_genotyping_trial4',
                     'col_number' => 5
                   },
          'A08' => {
                     'plot_name' => 'test_genotyping_trial_name_A08',
                     'row_number' => 'A',
                     'col_number' => 8,
                     'stock_name' => 'test_stock_4_genotyping_trial7',
                     'is_blank' => 0,
                     'plot_number' => 'A08'
                   },
          'A04' => {
                     'plot_name' => 'test_genotyping_trial_name_A04',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_4_genotyping_trial3',
                     'col_number' => 4,
                     'is_blank' => 0,
                     'plot_number' => 'A04'
                   },
          'A01' => {
                     'is_blank' => 0,
                     'plot_number' => 'A01',
                     'plot_name' => 'test_genotyping_trial_name_A01',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_4_genotyping_trial1',
                     'col_number' => 1
                   },
          'A11' => {
                     'plot_name' => 'test_genotyping_trial_name_A11',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_4_genotyping_trial10',
                     'col_number' => 11,
                     'is_blank' => 0,
                     'plot_number' => 'A11'
                   },
          'A06' => {
                     'plot_number' => 'A06',
                     'is_blank' => 0,
                     'stock_name' => 'test_stock_4_genotyping_trial5',
                     'col_number' => 6,
                     'row_number' => 'A',
                     'plot_name' => 'test_genotyping_trial_name_A06'
                   },
          'A10' => {
                     'is_blank' => 0,
                     'plot_number' => 'A10',
                     'plot_name' => 'test_genotyping_trial_name_A10',
                     'row_number' => 'A',
                     'col_number' => 10,
                     'stock_name' => 'test_stock_4_genotyping_trial9'
                   },
          'A03' => {
                     'plot_name' => 'test_genotyping_trial_name_A03',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_4_genotyping_trial2',
                     'col_number' => 3,
                     'is_blank' => 0,
                     'plot_number' => 'A03'
                   }
        }, 'check genotyping plate design');

my $genotyping_trial_create;

my $trial_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_trial', 'project_type')->cvterm_id();

ok($genotyping_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    program => "test",
    trial_location => "test_location",
    operator => "janedoe",
    trial_year => $plate_info->{year},
    trial_description => $plate_info->{description},
    design_type => 'genotyping_plate',
    design => $geno_design,
    trial_name => $plate_info->{name},
    trial_type => $trial_type_cvterm_id,
    is_genotyping => 1,
    genotyping_user_id => 41,
    genotyping_project_name => $plate_info->{project_name},
    genotyping_facility_submitted => $plate_info->{genotyping_facility_submit},
    genotyping_facility => $plate_info->{genotyping_facility},
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

ok(my $success = $g_trial->delete_genotyping_plate_from_field_trial_linkage($field_trial_id, 'curator'),'delete linkage');
ok( $success->{success});

print STDERR "Rolling back...\n";

$chado_schema->txn_rollback();

done_testing();
