
use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use Data::Dumper;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::BreedersToolbox::DeriveTrait;
use SGN::Model::Cvterm;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);

# create a location for the trial
ok(my $trial_location = "test_location_for_trial_derive_trait");
ok(my $location = $chado_schema->resultset('NaturalDiversity::NdGeolocation')
   ->new({
    description => $trial_location,
	 }));
ok($location->insert());

# create stocks for the trial
ok(my $accession_cvterm = $chado_schema->resultset("Cv::Cvterm")
   ->create_with({
       name   => 'accession',
       cv     => 'stock_type',
}));
my @stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@stock_names, "test_stock_for_trial_derive_trait".$i);
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
ok($trial_design->set_trial_name("test_trial_derive_trait"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_blocks(2), "set block number");
ok($trial_design->set_design_type("RCBD"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

print STDERR Dumper $design;

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2016",
    trial_description => "test_trial_derive_trait description",
    trial_location => "test_location_for_trial_derive_trait",
    trial_name => "test_trial_derive_trait",
    design_type => "RCBD",
    operator => "janedoe"
}), "create trial object");

ok(my $save = $trial_create->save_trial(), "save trial");
my $trial_id = $save->{'trial_id'};
my $trial = CXGN::Trial->new({ bcs_schema => $fix->bcs_schema(), trial_id => $trial_id });

my $trial_plots = $trial->get_plots();
my @trial_plot_names;
foreach (@$trial_plots){
    push @trial_plot_names, $_->[1];
}
@trial_plot_names = sort @trial_plot_names;
is(scalar(@trial_plot_names), 20, "check num plots saved");

my $num_plants_add = 2;
$trial->create_plant_entities($num_plants_add);

my %phenotype_metadata;
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2017-02-16_01:10:56";
my @plots = sort ( $trial_plot_names[0], $trial_plot_names[1], $trial_plot_names[2] );
my @plants = sort ( $trial_plot_names[0]."_plant_2", $trial_plot_names[1]."_plant_2", $trial_plot_names[2]."_plant_2" );
print STDERR Dumper \@plots;

my $parsed_data = {
            $plants[0] => {
                                'dry matter content|CO_334:0000092' => [
                                                                     '23',
                                                                     '2017-02-11 11:12:20-0500'
                                                                   ]
                                                   },
            $plants[1] => {
                               'dry matter content|CO_334:0000092' => [
                                                                    '28',
                                                                    '2017-02-11 11:13:20-0500'
                                                                  ]
                                                  },
            $plants[2] => {
                              'dry matter content|CO_334:0000092' => [
                                                                   '30',
                                                                   '2017-02-11 11:15:20-0500'
                                                                 ]
                                                 },
            };

my @traits = ( 'dry matter content|CO_334:0000092' );

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$fix->config->{basepath},
    dbhost=>$fix->config->{dbhost},
    dbname=>$fix->config->{dbname},
    dbuser=>$fix->config->{dbuser},
    dbpass=>$fix->config->{dbpass},
    temp_file_nd_experiment_id=>$fix->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$fix->bcs_schema,
    metadata_schema=>$fix->metadata_schema,
    phenome_schema=>$fix->phenome_schema,
    user_id=>41,
    stock_list=>\@plants,
    trait_list=>\@traits,
    values_hash=>$parsed_data,
    has_timestamps=>1,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata
);

my ($stored_phenotype_error_msg, $stored_phenotype_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store pheno spreadsheet works");

my $tn = CXGN::Trial->new( { bcs_schema => $fix->bcs_schema(),
				trial_id => $trial_id });
my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR Dumper \@traits_assayed_sorted;
is_deeply(\@traits_assayed_sorted, [
          [
            70741,
            'dry matter content percentage|CO_334:0000092', [], 3, undef, undef
          ]
        ], "check upload worked");


my $method = 'arithmetic_mean';
my $rounding = 'round';
my $trait_name = 'dry matter content|CO_334:0000092';
my $derive_trait = CXGN::BreedersToolbox::DeriveTrait->new({bcs_schema=>$fix->bcs_schema, trait_name=>$trait_name, trial_id=>$trial_id, method=>$method, rounding=>$rounding});
my ($info, $plots_ret, $traits, $store_hash) = $derive_trait->generate_plot_phenotypes();
#print STDERR Dumper $info;

my @sorted_plots_ret = sort @$plots_ret;
is_deeply(\@plots, \@sorted_plots_ret, 'check generated plots');

my @values_to_store;
foreach my $info_n (@$info) {
    push @values_to_store, $info_n->{'value_to_store'};
}
@values_to_store = sort @values_to_store;
print STDERR Dumper \@values_to_store;
is_deeply(\@values_to_store, [23,28,30], "check returned values");

print STDERR Dumper $store_hash;

my %phenotype_metadata;
$phenotype_metadata{'operator'}='janedoe';
$phenotype_metadata{'date'}="2017-02-16_03:10:59";
my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$fix->config->{basepath},
    dbhost=>$fix->config->{dbhost},
    dbname=>$fix->config->{dbname},
    dbuser=>$fix->config->{dbuser},
    dbpass=>$fix->config->{dbpass},
    temp_file_nd_experiment_id=>$fix->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$fix->bcs_schema,
    metadata_schema=>$fix->metadata_schema,
    phenome_schema=>$fix->phenome_schema,
    user_id=>41,
    stock_list=>$plots_ret,
    trait_list=>$traits,
    values_hash=>$store_hash,
    has_timestamps=>0,
    overwrite_values=>1,
    metadata_hash=>\%phenotype_metadata
);

my ($store_error, $store_success) = $store_phenotypes->store();
ok(!$store_error, "check that store pheno spreadsheet works");

my $trait_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($fix->bcs_schema, 'dry matter content|CO_334:0000092')->cvterm_id();
my $all_stock_phenotypes_for_dry_matter_content = $tn->get_stock_phenotypes_for_traits([$trait_id], 'all', ['plot_of','plant_of'], 'accession', 'subject');
#print STDERR Dumper $all_stock_phenotypes_for_dry_matter_content;
ok(scalar(@$all_stock_phenotypes_for_dry_matter_content) == 6, "check if num phenotype saved is correct");
my $plant_phenotypes_for_dry_matter_content = $tn->get_stock_phenotypes_for_traits([$trait_id], 'plant', ['plant_of'], 'accession', 'subject');
#print STDERR Dumper $plant_phenotypes_for_dry_matter_content;
ok(scalar(@$plant_phenotypes_for_dry_matter_content) == 3, "check num phenotype for plant is correct");
my $plot_phenotypes_for_dry_matter_content = $tn->get_stock_phenotypes_for_traits([$trait_id], 'plot', ['plot_of'], 'accession', 'subject');
#print STDERR Dumper $plot_phenotypes_for_dry_matter_content;
ok(scalar(@$plot_phenotypes_for_dry_matter_content) == 3, "check num phenotype for plot is correct");

done_testing();
