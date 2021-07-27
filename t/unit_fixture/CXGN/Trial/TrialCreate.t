
use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use JSON::Any;
use Data::Dumper;
use Test::WWW::Mechanize;
use JSON;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLayoutDownload');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);

# create a location for the trial
ok(my $trial_location = "test_location_for_trial");
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
    push(@stock_names, "test_stock_for_trial".$i);
}

#create stocks for genotyping plate
my @genotyping_stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@genotyping_stock_names, "test_stock_for_genotyping_trial".$i);
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
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_name",
    trial_type=>$ayt_cvterm_id,
    design_type => "RCBD",
    operator => "janedoe"
						    }), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_name",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names1");

my %stocks = map { $_ => 1 } @stock_names;

foreach my $acc (@$accession_names) {
    ok(exists($stocks{$acc->{accession_name}}), "check accession names $acc->{accession_name}");
}

#create RCBD trial with one accession

@stock_names;
push @stock_names, "test_stock_for_trial1";

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("new_test_trial_name_single"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_reps(2), "set rep number");
ok($trial_design->set_design_type("CRD"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_name_single",
    design_type => "RCBD",
    operator => "janedoe"
						    }), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_name_single",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names2");

my %stocks = map { $_ => 1 } @stock_names;

foreach my $acc (@$accession_names) {
    ok(exists($stocks{$acc->{accession_name}}), "check accession names $acc->{accession_name}");
}


# layout for genotyping experiment
# use data structure returned by brapi call for GDF:
# plates:[ { 'project_id' : 'project x',
#            'plate_name' : 'required',
#            'plate_format': 'Plate_96' | 'tubes',
#            'sample_type' : 'DNA' | 'RNA' | 'Tissue'
#            'samples':[
# {
#    		'name': 'sample_name1',
#     		'well': 'optional'
#               'concentration:
#'              'volume':
#               'taxomony_id' :
#               'tissue_type' :
#               }
# ]

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

#print STDERR Dumper $geno_design;
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
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    program => "test",
    trial_location => "test_location_for_trial",
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
    schema => $chado_schema,
    trial_name => "test_genotyping_trial_name",
}), "lookup genotyping plate");
ok(my $genotyping_trial = $genotyping_trial_lookup->get_trial(), "retrieve genotyping plate");
ok(my $genotyping_trial_id = $genotyping_trial->project_id(), "retrive genotyping plate id");
ok(my $genotyping_trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $genotyping_trial_id,
    experiment_type => 'genotyping_layout'
}), "create trial layout object for genotyping plate");
ok(my $genotyping_accession_names = $genotyping_trial_layout->get_accession_names(), "retrieve accession names3");
my %genotyping_stocks = map { $_ => 1 } @genotyping_stock_names;
$genotyping_stocks{'BLANK'} = 1;
foreach my $acc (@$genotyping_accession_names) {
    ok(exists($genotyping_stocks{$acc->{accession_name}}), "check existence of accession names $acc->{accession_name}");
}

my $mech = Test::WWW::Mechanize->new;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$save->{'trial_id'}.'/design');
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is(scalar(keys %{$response->{design}}), 11);

#create westcott trial design_type

my @stock_names_westcott;
for (my $i = 1; $i <= 100; $i++) {
    push(@stock_names_westcott, "test_stock_for_westcott_trial".$i);
}
foreach my $stock_name (@stock_names_westcott) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
		 });
};
ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("test_westcott_trial"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names_westcott), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_westcott_check_1("test_stock_for_trial1"), "set check 1");
ok($trial_design->set_westcott_check_2("test_stock_for_trial2"), "set check 2");
ok($trial_design->set_westcott_col(20), "set column number");
ok($trial_design->set_design_type("Westcott"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

$ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_name_westcott",
    trial_type=>$ayt_cvterm_id,
    design_type => "Westcott",
    operator => "janedoe"
						    }), "create trial object");

$save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_name_westcott",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names1");

%stocks = map { $_ => 1 } @stock_names_westcott;
my @accessions;
for (my $i=0; $i<scalar(@stock_names_westcott); $i++){
    foreach my $acc (@$accession_names) {
        if ($acc->{accession_name} eq $stock_names_westcott[$i]){
            push @accessions, $acc->{accession_name};
        }
    }
}
ok(scalar(@accessions) == 100, "check accession names");

#create splitplot trial design_type

my @stock_names_splitplot;
for (my $i = 1; $i <= 100; $i++) {
    push(@stock_names_splitplot, "test_stock_for_splitplot_trial".$i);
}
foreach my $stock_name (@stock_names_splitplot) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
		 });
};
ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("test_splitplot_trial_1"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names_splitplot), "set stock list");
ok($trial_design->set_treatments(["management_factor_1", "management_factor_2"]), "set treatment/management_factor list");
ok($trial_design->set_number_of_blocks(2), "set number of blocks");
ok($trial_design->set_plot_layout_format("serpentine"), "set serpentine");
ok($trial_design->set_design_type("splitplot"), "set design type");
ok($trial_design->set_num_plants_per_plot(4), "set num plants per plot");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

#print STDERR Dumper $design;

$ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "test_splitplot_trial_1",
    trial_type=>$ayt_cvterm_id,
    design_type => "splitplot",
    trial_has_subplot_entries => 2,
    trial_has_plant_entries => 4,
    operator => "janedoe"
						    }), "create trial object");

$save = $trial_create->save_trial();
print STDERR "TRIAL ID = ".$save->{trial_id}."\n";
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "test_splitplot_trial_1",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());

my $trial_obj = CXGN::Trial->new({bcs_schema=>$chado_schema, trial_id=>$trial_id});
ok(my $trial_management_factors = $trial_obj->get_treatments());
#print STDERR Dumper $trial_management_factors;
is(scalar(@$trial_management_factors), 2);
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names1");

%stocks = map { $_ => 1 } @stock_names_splitplot;
my @accessions;
for (my $i=0; $i<scalar(@stock_names_splitplot); $i++){
    foreach my $acc (@$accession_names) {
        if ($acc->{accession_name} eq $stock_names_splitplot[$i]){
            push @accessions, $acc->{accession_name};
        }
    }
}
ok(scalar(@accessions) == 100, "check accession names");

my @splitplot_management_factors;
foreach (@$trial_management_factors) {
    push @splitplot_management_factors, $_->[0];
    my $trial = CXGN::Trial->new({bcs_schema=>$chado_schema, trial_id=>$_->[0]});
    my $plant_entries = $trial->get_observation_units_direct('plant', ['treatment_experiment']);
    my $subplot_entries = $trial->get_observation_units_direct('subplot', ['treatment_experiment']);
    is(scalar(@$plant_entries), 400);
    is(scalar(@$subplot_entries), 200);
}

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    data_level => 'subplots',
    treatment_project_ids => \@splitplot_management_factors,
    selected_columns => {"subplot_name"=>1,"plot_name"=>1,"plot_number"=>1,"block_number"=>1}
});
my $output = $trial_layout_download->get_layout_output();
#print STDERR Dumper $output;
is(scalar(@{$output->{output}}), 401);

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    data_level => 'plants',
    treatment_project_ids => \@splitplot_management_factors,
    selected_columns => {"plant_name"=>1,"plot_name"=>1,"plot_number"=>1,"block_number"=>1}
});
my $output = $trial_layout_download->get_layout_output();
#print STDERR Dumper $output;
is(scalar(@{$output->{output}}), 801);

done_testing();
