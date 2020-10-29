use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Genotype;
use CXGN::Genotype::CreatePlateOrder;
use CXGN::Dataset;
local $Data::Dumper::Indent = 0;

my $t = SGN::Test::Fixture->new();
my $schema = $t->bcs_schema;
my $people_schema = $t->people_schema;

my $client_id = 'client_id1';
my $service_id_list = [1,2];
my $plate_id = 176;
my $add_requirements = {};


my $create_order = CXGN::Genotype::CreatePlateOrder->new({
    bcs_schema=>$schema,
    client_id=>$client_id,
    service_id_list=>$service_id_list,
    plate_id => $plate_id,
    requeriments => $add_requirements,
});

my $order = $create_order->create();

# print STDERR Dumper \$order;

my $expected_order = {'serviceIds' => [1,2],'sampleType' => 'DNA','clientId' => 'client_id1','numberOfSamples' => 10,'plates' => [{'clientPlateId' => 176,'clientPlateBarcode' => 'test_genotyping_trial_name','sampleSubmissionFormat' => 'PLATE_96','samples' => [{'taxonomyOntologyReference' => {},'well' => 'A1','comments' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A01','volume' => {'value' => '0','units' => 'ul'},'organismName' => '','column' => 1,'tissueType' => '','row' => 'A','clientSampleId' => '42125','speciesName' => '','concentration' => {'units' => 'ng','value' => '0'},'tissueTypeOntologyReference' => {}},{'concentration' => {'value' => '0','units' => 'ng'},'tissueTypeOntologyReference' => {},'clientSampleId' => '42118','speciesName' => '','row' => 'A','tissueType' => '','column' => 3,'organismName' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A03','volume' => {'value' => '0','units' => 'ul'},'taxonomyOntologyReference' => {},'comments' => '','well' => 'A3'},{'tissueType' => '','column' => 4,'organismName' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A04','volume' => {'value' => '0','units' => 'ul'},'taxonomyOntologyReference' => {},'comments' => '','well' => 'A4','concentration' => {'units' => 'ng','value' => '0'},'tissueTypeOntologyReference' => {},'speciesName' => '','clientSampleId' => '42117','row' => 'A'},{'well' => 'A5','comments' => '','taxonomyOntologyReference' => {},'volume' => {'units' => 'ul','value' => '0'},'clientSampleBarCode' => 'test_genotyping_trial_name_A05','organismName' => '','column' => 5,'tissueType' => '','row' => 'A','speciesName' => '','clientSampleId' => '42115','tissueTypeOntologyReference' => {},'concentration' => {'value' => '0','units' => 'ng'}},{'row' => 'A','clientSampleId' => '42123','speciesName' => '','tissueTypeOntologyReference' => {},'concentration' => {'units' => 'ng','value' => '0'},'taxonomyOntologyReference' => {},'well' => 'A6','comments' => '','column' => 6,'tissueType' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A06','volume' => {'units' => 'ul','value' => '0'},'organismName' => ''},{'row' => 'A','clientSampleId' => '42119','speciesName' => '','tissueTypeOntologyReference' => {},'concentration' => {'value' => '0','units' => 'ng'},'taxonomyOntologyReference' => {},'comments' => '','well' => 'A7','clientSampleBarCode' => 'test_genotyping_trial_name_A07','volume' => {'value' => '0','units' => 'ul'},'organismName' => '','column' => 7,'tissueType' => ''},{'tissueType' => '','column' => 8,'organismName' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A08','volume' => {'units' => 'ul','value' => '0'},'taxonomyOntologyReference' => {},'well' => 'A8','comments' => '','tissueTypeOntologyReference' => {},'concentration' => {'value' => '0','units' => 'ng'},'speciesName' => '','clientSampleId' => '42121','row' => 'A'},{'clientSampleId' => '42120','speciesName' => '','tissueTypeOntologyReference' => {},'concentration' => {'units' => 'ng','value' => '0'},'row' => 'A','column' => 9,'tissueType' => '','volume' => {'units' => 'ul','value' => '0'},'clientSampleBarCode' => 'test_genotyping_trial_name_A09','organismName' => '','comments' => '','well' => 'A9','taxonomyOntologyReference' => {}},{'concentration' => {'units' => 'ng','value' => '0'},'tissueTypeOntologyReference' => {},'speciesName' => '','clientSampleId' => '42116','row' => 'A','organismName' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A10','volume' => {'value' => '0','units' => 'ul'},'tissueType' => '','column' => 10,'taxonomyOntologyReference' => {},'well' => 'A10','comments' => ''},{'clientSampleId' => '42122','speciesName' => '','concentration' => {'value' => '0','units' => 'ng'},'tissueTypeOntologyReference' => {},'row' => 'A','column' => 11,'tissueType' => '','clientSampleBarCode' => 'test_genotyping_trial_name_A11','volume' => {'value' => '0','units' => 'ul'},'organismName' => '','taxonomyOntologyReference' => {},'comments' => '','well' => 'A11'}]}],'requiredServiceInfo' => {}};
is_deeply($order->{plates}[0]->{clientPlateBarcode},$expected_order->{plates}[0]->{clientPlateBarcode}, 'test create plate order');

is_deeply(scalar(@{$order->{plates}[0]->{samples}}),scalar(@{$expected_order->{plates}[0]->{samples}}), 'test create plate order samples');

done_testing();
