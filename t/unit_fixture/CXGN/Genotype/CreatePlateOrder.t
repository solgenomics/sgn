use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Genotype;
use CXGN::Genotype::CreatePlateOrder;
use CXGN::Dataset;
local $Data::Dumper::Indent = 0;

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLayoutDownload');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}

my $t = SGN::Test::Fixture->new();
my $schema = $t->bcs_schema;
$schema->txn_begin();
my $dbh = $schema->storage->dbh();

# create stocks for the trial
ok(my $accession_cvterm = $schema->resultset("Cv::Cvterm")
   ->create_with({
       name   => 'accession',
       cv     => 'stock_type',
    }));

my @genotyping_stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@genotyping_stock_names, "test_stock_for_genotyping_trial".$i);
}

ok(my $organism = $schema->resultset("Organism::Organism")
   ->find_or_create( {
       genus => 'Test_genus',
       species => 'Test_genus test_species',
             }, ));


# create some genotyping test stocks
foreach my $stock_name (@genotyping_stock_names) {
    my $accession_stock = $schema->resultset('Stock::Stock')
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

my $gd = CXGN::Trial::TrialDesign->new( { schema => $schema } );
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
                     'stock_name' => 'test_stock_for_genotyping_trial8',
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
                     'stock_name' => 'test_stock_for_genotyping_trial6'
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
                     'stock_name' => 'test_stock_for_genotyping_trial4',
                     'col_number' => 5
                   },
          'A08' => {
                     'plot_name' => 'test_genotyping_trial_name_A08',
                     'row_number' => 'A',
                     'col_number' => 8,
                     'stock_name' => 'test_stock_for_genotyping_trial7',
                     'is_blank' => 0,
                     'plot_number' => 'A08'
                   },
          'A04' => {
                     'plot_name' => 'test_genotyping_trial_name_A04',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_for_genotyping_trial3',
                     'col_number' => 4,
                     'is_blank' => 0,
                     'plot_number' => 'A04'
                   },
          'A01' => {
                     'is_blank' => 0,
                     'plot_number' => 'A01',
                     'plot_name' => 'test_genotyping_trial_name_A01',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_for_genotyping_trial1',
                     'col_number' => 1
                   },
          'A11' => {
                     'plot_name' => 'test_genotyping_trial_name_A11',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_for_genotyping_trial10',
                     'col_number' => 11,
                     'is_blank' => 0,
                     'plot_number' => 'A11'
                   },
          'A06' => {
                     'plot_number' => 'A06',
                     'is_blank' => 0,
                     'stock_name' => 'test_stock_for_genotyping_trial5',
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
                     'stock_name' => 'test_stock_for_genotyping_trial9'
                   },
          'A03' => {
                     'plot_name' => 'test_genotyping_trial_name_A03',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_for_genotyping_trial2',
                     'col_number' => 3,
                     'is_blank' => 0,
                     'plot_number' => 'A03'
                   }
        }, 'check genotyping plate design');

my $genotyping_trial_create;
ok($genotyping_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema,
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
    is_genotyping => 1,
    genotyping_user_id => 41,
    genotyping_project_name => $plate_info->{project_name},
    genotyping_facility_submitted => $plate_info->{genotyping_facility_submit},
    genotyping_facility => $plate_info->{genotyping_facility},
    genotyping_plate_format => $plate_info->{plate_format},
    genotyping_plate_sample_type => $plate_info->{sample_type},
}), "create genotyping plate");

my $save = $genotyping_trial_create->save_trial();
ok($save->{'trial_id'}, "save genotyping plate");

ok(my $genotyping_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $schema,
    trial_name => "test_genotyping_trial_name",
}), "lookup genotyping plate");
ok(my $genotyping_trial = $genotyping_trial_lookup->get_trial(), "retrieve genotyping plate");
ok(my $genotyping_trial_id = $genotyping_trial->project_id(), "retrive genotyping plate id");
print STDERR Dumper \$genotyping_trial_id;


my $client_id = 'client_id1';
my $service_id_list = [1,2];
my $plate_id = $genotyping_trial_id;
my $add_requirements = {};
my $organism_name = 'Cassava';


my $create_order = CXGN::Genotype::CreatePlateOrder->new({
    bcs_schema=>$schema,
    client_id=>$client_id,
    service_id_list=>$service_id_list,
    plate_id => $plate_id,
    requeriments => $add_requirements,
    organism_name => $organism_name
});

my $order = $create_order->create();


my $expected_order = {'serviceIds' => [1,2],'sampleType' => 'DNA','clientId' => 'client_id1','numberOfSamples' => 10,'plates' => [{'clientPlateId' => 176,'clientPlateBarcode' => 'test_genotyping_trial_name','sampleSubmissionFormat' => 'PLATE_96','samples' => [{'taxonomyOntologyReference' => {},'well' => 'A1','comments' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A01','volume' => {'value' => '0','units' => 'ul'},'organismName' => 'Cassava','column' => 1,'tissueType' => '','row' => 'A','clientSampleId' => '42125','speciesName' => '','concentration' => {'units' => 'ng','value' => '0'},'tissueTypeOntologyReference' => {}},{'concentration' => {'value' => '0','units' => 'ng'},'tissueTypeOntologyReference' => {},'clientSampleId' => '42118','speciesName' => '','row' => 'A','tissueType' => '','column' => 3,'organismName' => 'Cassava','clientSampleBarCode' => 'test_genotyping_trial_name_A03','volume' => {'value' => '0','units' => 'ul'},'taxonomyOntologyReference' => {},'comments' => '','well' => 'A3'},{'tissueType' => '','column' => 4,'organismName' => 'Cassava','clientSampleBarCode' => 'test_genotyping_trial_name_A04','volume' => {'value' => '0','units' => 'ul'},'taxonomyOntologyReference' => {},'comments' => '','well' => 'A4','concentration' => {'units' => 'ng','value' => '0'},'tissueTypeOntologyReference' => {},'speciesName' => '','clientSampleId' => '42117','row' => 'A'},{'well' => 'A5','comments' => '','taxonomyOntologyReference' => {},'volume' => {'units' => 'ul','value' => '0'},'clientSampleBarCode' => 'test_genotyping_trial_name_A05','organismName' => 'Cassava','column' => 5,'tissueType' => '','row' => 'A','speciesName' => '','clientSampleId' => '42115','tissueTypeOntologyReference' => {},'concentration' => {'value' => '0','units' => 'ng'}},{'row' => 'A','clientSampleId' => '42123','speciesName' => '','tissueTypeOntologyReference' => {},'concentration' => {'units' => 'ng','value' => '0'},'taxonomyOntologyReference' => {},'well' => 'A6','comments' => '','column' => 6,'tissueType' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A06','volume' => {'units' => 'ul','value' => '0'},'organismName' => 'Cassava'},{'row' => 'A','clientSampleId' => '42119','speciesName' => '','tissueTypeOntologyReference' => {},'concentration' => {'value' => '0','units' => 'ng'},'taxonomyOntologyReference' => {},'comments' => '','well' => 'A7','clientSampleBarCode' => 'test_genotyping_trial_name_A07','volume' => {'value' => '0','units' => 'ul'},'organismName' => 'Cassava','column' => 7,'tissueType' => ''},{'tissueType' => '','column' => 8,'organismName' => 'Cassava','clientSampleBarCode' => 'test_genotyping_trial_name_A08','volume' => {'units' => 'ul','value' => '0'},'taxonomyOntologyReference' => {},'well' => 'A8','comments' => '','tissueTypeOntologyReference' => {},'concentration' => {'value' => '0','units' => 'ng'},'speciesName' => '','clientSampleId' => '42121','row' => 'A'},{'clientSampleId' => '42120','speciesName' => '','tissueTypeOntologyReference' => {},'concentration' => {'units' => 'ng','value' => '0'},'row' => 'A','column' => 9,'tissueType' => '','volume' => {'units' => 'ul','value' => '0'},'clientSampleBarCode' => 'test_genotyping_trial_name_A09','organismName' => 'Cassava','comments' => '','well' => 'A9','taxonomyOntologyReference' => {}},{'concentration' => {'units' => 'ng','value' => '0'},'tissueTypeOntologyReference' => {},'speciesName' => '','clientSampleId' => '42116','row' => 'A','organismName' => 'Cassava','clientSampleBarCode' => 'test_genotyping_trial_name_A10','volume' => {'value' => '0','units' => 'ul'},'tissueType' => '','column' => 10,'taxonomyOntologyReference' => {},'well' => 'A10','comments' => ''},{'clientSampleId' => '42122','speciesName' => '','concentration' => {'value' => '0','units' => 'ng'},'tissueTypeOntologyReference' => {},'row' => 'A','column' => 11,'tissueType' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A11','volume' => {'value' => '0','units' => 'ul'},'organismName' => 'Cassava','taxonomyOntologyReference' => {},'comments' => '','well' => 'A11'}]}],'requiredServiceInfo' => {}};
is_deeply($order->{plates}[0]->{clientPlateBarcode},$expected_order->{plates}[0]->{clientPlateBarcode}, 'test create plate order');

is_deeply(scalar(@{$order->{plates}[0]->{samples}}),scalar(@{$expected_order->{plates}[0]->{samples}}), 'test create plate order samples');

# print STDERR "Rolling back...\n";

# $schema->txn_rollback();

done_testing();
