
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use File::Temp qw | tempfile |;
use CXGN::Genotype::Search;
use CXGN::Genotype::StoreGenotypingProject;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $metadata_schema = $f->metadata_schema;
my $phenome_schema = $f->phenome_schema;
my $people_schema = $f->people_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

#
# Build a small field trial with plots, subplots, and plants, so that we
# have real stock uniquenames of each of those types to genotype, each
# related back to a known accession via a stock_relationship
# (plot_of/subplot_of/plant_of).
#

my $ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

my @stock_names = ('test_accession1', 'test_accession2', 'test_accession3', 'test_accession4', 'test_accession5');

my $trial_design = CXGN::Trial::TrialDesign->new();
$trial_design->set_trial_name("mixed_stock_type_test_trial");
$trial_design->set_stock_list(\@stock_names);
$trial_design->set_plot_start_number(1);
$trial_design->set_plot_number_increment(1);
$trial_design->set_plot_layout_format("zigzag");
$trial_design->set_number_of_blocks(1);
$trial_design->set_design_type("RCBD");
$trial_design->calculate_design();
ok(my $design = $trial_design->get_design(), "create trial design");

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "mixed stock type test trial",
    trial_location => "test_location",
    trial_name => "mixed_stock_type_test_trial",
    trial_type=>$ayt_cvterm_id,
    design_type => "RCBD",
    operator => "janedoe"
}), "create trial object");

my $save = $trial_create->save_trial();
ok(my $trial_id = $save->{'trial_id'}, "save trial");

my $trial = CXGN::Trial->new({
    bcs_schema => $schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $trial_id
});
$trial->create_subplot_entities('2');
$trial->create_plant_subplot_entities(2);

my $tl = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $trial_id, experiment_type => 'field_layout' });
my $d = $tl->get_design();

my ($first_plot_num) = sort keys %$d;
my $plot_name = $d->{$first_plot_num}->{'plot_name'};
my $expected_accession_name = $d->{$first_plot_num}->{'accession_name'};
my $subplot_name = $d->{$first_plot_num}->{'subplot_names'}->[0];
my $plant_name = $d->{$first_plot_num}->{'plant_names'}->[0];

ok($plot_name, "found a plot name ($plot_name)");
ok($expected_accession_name, "found the plot's accession name ($expected_accession_name)");
ok($subplot_name, "found a subplot name ($subplot_name)");
ok($plant_name, "found a plant name ($plant_name)");

#
# Upload genotype data for a mix of accession, plot, subplot, and plant
# stocks in a single protocol, using observation_unit_type_name "stocks".
#

my $add_genotyping_project = CXGN::Genotype::StoreGenotypingProject->new({
    chado_schema        => $schema,
    dbh                 => $f->dbh(),
    project_name        => 'mixed_stock_type_genotyping_project',
    breeding_program_id => $breeding_program_id,
    project_facility    => 'intertek',
    data_type           => 'snp',
    year                => '2023',
    project_description => 'genotyping project for mixed stock type test',
    nd_geolocation_id   => $location_id,
    owner_id            => 41
});
ok($add_genotyping_project->store_genotyping_project(), "store genotyping project");

my $gp_rs = $schema->resultset('Project::Project')->find({ name => 'mixed_stock_type_genotyping_project' });
my $genotyping_project_id = $gp_rs->project_id();

my ($marker_fh, $marker_info_file) = tempfile(SUFFIX => '.csv', UNLINK => 1);
print $marker_fh "MarkerName,Xallele,Yallele,Chromosome,Position,Sequence\n";
print $marker_fh "S01_0001,T,G,S01,7926132,AAAAACATTAAAATT[T/G]TAGGCCGGAGCAAG\n";
close($marker_fh);

my ($results_fh, $results_file) = tempfile(SUFFIX => '.csv', UNLINK => 1);
print $results_fh "MarkerName,SampleName,SNPcall,Xvalue,Yvalue\n";
print $results_fh "S01_0001,test_accession1,T:T,1.36,.58\n";
print $results_fh "S01_0001,$plot_name,T:G,1.25,.49\n";
print $results_fh "S01_0001,$subplot_name,T:G,1.22,1.41\n";
print $results_fh "S01_0001,$plant_name,T:T,1.11,1.27\n";
close($results_fh);

my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_data_kasp_file_input => [ $results_file, 'kasp_data_upload' ],
        upload_genotype_kasp_marker_info_file_input => [ $marker_info_file, 'kasp_marker_info_upload' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_project_id"=>$genotyping_project_id,
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_year_select"=>"2023",
        "upload_genotype_breeding_program_select"=>$breeding_program_id,
        "upload_genotype_vcf_observation_type"=>"stocks",
        "upload_genotype_vcf_facility_select"=>"intertek",
        "upload_genotype_vcf_project_description"=>"test",
        "upload_genotype_vcf_protocol_name"=>"mixed_stock_type_protocol",
        "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
        "upload_genotype_add_new_accessions"=>0,
        "assay_type"=>"KASP",
    ]
);

my $message = $response->decoded_content;
my $message_hash = decode_json $message;
ok($message_hash->{nd_protocol_id}, "mixed accession/plot/subplot/plant upload succeeds") or diag(Dumper($message_hash));
my $protocol_id = $message_hash->{nd_protocol_id};

#
# CXGN::Genotype::Search used to only resolve germplasmName/germplasmDbId
# for stock_type_name eq 'accession' or 'tissue_sample'; plot/plant/subplot
# rows got blank germplasm fields. Confirm all four resolve correctly now.
#

my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$protocol_id],
});
my ($total_count, $data) = $genotypes_search->get_genotype_info();
is($total_count, 4, "four genotyped stocks found");

my %by_stock_name = map { $_->{stock_name} => $_ } @$data;

is($by_stock_name{'test_accession1'}->{stock_type_name}, 'accession', "accession row has stock_type_name accession");
is($by_stock_name{'test_accession1'}->{germplasmName}, 'test_accession1', "accession row resolves germplasmName to itself");
ok($by_stock_name{'test_accession1'}->{germplasmDbId}, "accession row has a germplasmDbId");

is($by_stock_name{$plot_name}->{stock_type_name}, 'plot', "plot row has stock_type_name plot");
is($by_stock_name{$plot_name}->{germplasmName}, $expected_accession_name, "plot row resolves germplasmName to its owning accession");
ok($by_stock_name{$plot_name}->{germplasmDbId}, "plot row has a germplasmDbId");

is($by_stock_name{$subplot_name}->{stock_type_name}, 'subplot', "subplot row has stock_type_name subplot");
is($by_stock_name{$subplot_name}->{germplasmName}, $expected_accession_name, "subplot row resolves germplasmName to its owning accession");
ok($by_stock_name{$subplot_name}->{germplasmDbId}, "subplot row has a germplasmDbId");

is($by_stock_name{$plant_name}->{stock_type_name}, 'plant', "plant row has stock_type_name plant");
is($by_stock_name{$plant_name}->{germplasmName}, $expected_accession_name, "plant row resolves germplasmName to its owning accession");
ok($by_stock_name{$plant_name}->{germplasmDbId}, "plant row has a germplasmDbId");

#
# Clean up
#

$mech->get_ok("http://localhost:3010/ajax/genotyping_protocol/delete/$protocol_id?sgn_session_id=$sgn_session_id");
$response = decode_json $mech->content;
is_deeply($response, {success=>1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$genotyping_project_id.'/delete/genotyping_project');
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$trial->delete_metadata();
$trial->delete_field_layout();
$trial->delete_project_entry();

done_testing();
